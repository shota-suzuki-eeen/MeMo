//
//  WalkChallengeStore.swift
//  MeMo
//
//  お散歩機能のセッション・タップ数・リザルトを永続管理するストア。
//  タイマーは画面滞在に依存せず、保存済みの終了時刻と現在時刻の差分で判定する。
//
//  2026/09 performance update:
//  - 常時0.25秒tickerを廃止。
//  - activeSessionが存在するときだけ1秒tickerを起動。
//  - ticker中はUserDefaults / JSONDecoderを毎回読まない。
//  - Halloweenランゲーム中はtickerを完全停止し、終了後に現在時刻から復元する。
//

import Foundation
import Combine

struct WalkChallengeSession: Identifiable, Codable, Equatable {
    let id: UUID
    let startedAt: Date
    let endsAt: Date
    var tapCount: Int
    let isRainFreeStart: Bool

    var durationSeconds: Int {
        max(0, Int(endsAt.timeIntervalSince(startedAt).rounded(.down)))
    }

    func remainingSeconds(now: Date = Date()) -> Int {
        max(0, Int(ceil(endsAt.timeIntervalSince(now))))
    }

    func isActive(now: Date = Date()) -> Bool {
        remainingSeconds(now: now) > 0
    }
}

struct WalkChallengeResult: Identifiable, Codable, Equatable {
    let id: UUID
    let sessionID: UUID
    let baseSteps: Int
    let startedAt: Date
    let endedAt: Date
    let isRainFreeStart: Bool

    var doubledSteps: Int { baseSteps * 2 }
}

final class WalkChallengeStore: ObservableObject {
    static let shared = WalkChallengeStore()

    static let sessionDurationSeconds: TimeInterval = 5 * 60

    /// 残り時間表示は秒単位なので、1秒更新で十分。
    private static let tickerIntervalNanoseconds: UInt64 = 1_000_000_000

    @Published private(set) var activeSession: WalkChallengeSession?
    @Published private(set) var pendingResult: WalkChallengeResult?
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var currentTapCount: Int = 0

    private enum DefaultsKey {
        static let activeSession = "memo.walk.activeSession"
        static let pendingResult = "memo.walk.pendingResult"
        static let rainyFreeUsedDayKey = "memo.walk.rainyFreeUsedDayKey"
    }

    private let defaults: UserDefaults
    private var tickerTask: Task<Void, Never>?

    /// ランゲームなど、メインスレッドを優先したい画面ではtrueにする。
    /// お散歩時間はendsAtで管理しているため、tickerを止めても時間そのものは止まらない。
    private var isTickerSuspendedForExclusiveGameplay = false

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        loadFromDefaults()
        refreshInMemory(now: Date())
        startTickerIfNeeded()
    }

    deinit {
        tickerTask?.cancel()
    }

    var isSessionActive: Bool {
        activeSession?.isActive(now: Date()) == true
    }

    var formattedRemainingTime: String {
        let safeSeconds = max(0, remainingSeconds)
        let minutes = safeSeconds / 60
        let seconds = safeSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Lifecycle

    /// アプリ起動時・お散歩画面表示時など、保存済み状態と同期したいタイミングで呼ぶ。
    ///
    /// UserDefaults / JSONDecoderを読むのはこのような明示的タイミングだけ。
    func bootstrap(now: Date = Date()) {
        loadFromDefaults()
        refreshInMemory(now: now)
        startTickerIfNeeded()
    }

    /// Halloweenランゲーム中など、リアルタイム描画を最優先したいときに呼ぶ。
    ///
    /// activeSessionが存在していてもtickerを停止する。
    /// endsAtは保持されるため、お散歩の終了時刻には影響しない。
    func pauseUpdatesForExclusiveGameplay() {
        guard !isTickerSuspendedForExclusiveGameplay else { return }

        isTickerSuspendedForExclusiveGameplay = true
        stopTicker()
    }

    /// Exclusive gameplay終了後に呼ぶ。
    ///
    /// 保存データを1回だけ読み直し、現在時刻から残り時間を再計算する。
    /// ゲーム中にお散歩が終了していた場合は、この時点でpendingResultへ変換される。
    func resumeUpdatesAfterExclusiveGameplay(now: Date = Date()) {
        guard isTickerSuspendedForExclusiveGameplay else {
            startTickerIfNeeded()
            return
        }

        isTickerSuspendedForExclusiveGameplay = false

        loadFromDefaults()
        refreshInMemory(now: now)
        startTickerIfNeeded()
    }

    // MARK: - Session

    func canUseRainFreeStart(isRainy: Bool, now: Date = Date()) -> Bool {
        guard isRainy else { return false }
        return defaults.string(forKey: DefaultsKey.rainyFreeUsedDayKey)
            != Self.dayKey(now)
    }

    @discardableResult
    func startSession(
        isRainFreeStart: Bool,
        now: Date = Date()
    ) -> Bool {
        refreshInMemory(now: now)

        guard activeSession?.isActive(now: now) != true else {
            return false
        }

        let session = WalkChallengeSession(
            id: UUID(),
            startedAt: now,
            endsAt: now.addingTimeInterval(Self.sessionDurationSeconds),
            tapCount: 0,
            isRainFreeStart: isRainFreeStart
        )

        if isRainFreeStart {
            defaults.set(
                Self.dayKey(now),
                forKey: DefaultsKey.rainyFreeUsedDayKey
            )
        }

        setActiveSession(session)
        setPendingResult(nil)
        setRemainingSeconds(session.remainingSeconds(now: now))
        setCurrentTapCount(0)

        persistSession(session)
        clearPendingResult()

        startTickerIfNeeded()
        return true
    }

    func registerTap(now: Date = Date()) {
        refreshInMemory(now: now)

        guard var session = activeSession,
              session.isActive(now: now) else {
            return
        }

        session.tapCount += 1

        setActiveSession(session)
        setCurrentTapCount(session.tapCount)
        persistSession(session)
    }

    /// メモリ上に保持しているセッションを現在時刻に追従させる。
    ///
    /// 旧実装と異なり、ここではUserDefaults / JSONDecoderを読まない。
    func refresh(now: Date = Date()) {
        refreshInMemory(now: now)
    }

    @discardableResult
    func finishActiveSessionNow(
        now: Date = Date()
    ) -> WalkChallengeResult? {
        refreshInMemory(now: now)

        guard let session = activeSession else {
            return pendingResult
        }

        if !session.isActive(now: now) {
            finishExpiredSession(session, now: now)
            return pendingResult
        }

        let result = WalkChallengeResult(
            id: UUID(),
            sessionID: session.id,
            baseSteps: max(0, session.tapCount),
            startedAt: session.startedAt,
            endedAt: now,
            isRainFreeStart: session.isRainFreeStart
        )

        setActiveSession(nil)
        setPendingResult(result)
        setRemainingSeconds(0)
        setCurrentTapCount(0)

        stopTicker()
        clearSession()
        persistPendingResult(result)

        return result
    }

    @discardableResult
    func claimPendingResult(
        multiplier: Int,
        state: AppState
    ) -> Int {
        guard let result = pendingResult else { return 0 }

        let safeMultiplier = max(1, multiplier)
        let grantedSteps = max(0, result.baseSteps * safeMultiplier)

        if grantedSteps > 0 {
            _ = state.addWalletSteps(grantedSteps)
        }

        setPendingResult(nil)
        clearPendingResult()

        return grantedSteps
    }

    func dismissPendingResultWithoutClaim() {
        setPendingResult(nil)
        clearPendingResult()
    }

    // MARK: - In-memory refresh

    private func refreshInMemory(now: Date) {
        guard let session = activeSession else {
            setRemainingSeconds(0)
            setCurrentTapCount(0)
            stopTickerIfSessionIsInactive()
            return
        }

        if session.isActive(now: now) {
            setRemainingSeconds(session.remainingSeconds(now: now))
            setCurrentTapCount(session.tapCount)
            return
        }

        finishExpiredSession(session, now: now)
    }

    private func finishExpiredSession(
        _ session: WalkChallengeSession,
        now: Date
    ) {
        let result = WalkChallengeResult(
            id: UUID(),
            sessionID: session.id,
            baseSteps: max(0, session.tapCount),
            startedAt: session.startedAt,
            endedAt: session.endsAt,
            isRainFreeStart: session.isRainFreeStart
        )

        setActiveSession(nil)
        setPendingResult(result)
        setRemainingSeconds(0)
        setCurrentTapCount(0)

        stopTicker()
        clearSession()
        persistPendingResult(result)
    }

    // MARK: - Ticker

    private func startTickerIfNeeded() {
        guard !isTickerSuspendedForExclusiveGameplay else { return }
        guard tickerTask == nil else { return }
        guard activeSession?.isActive(now: Date()) == true else { return }

        tickerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(
                        nanoseconds: Self.tickerIntervalNanoseconds
                    )
                } catch {
                    break
                }

                guard !Task.isCancelled else { break }
                guard let self else { break }

                if self.isTickerSuspendedForExclusiveGameplay {
                    break
                }

                self.refreshInMemory(now: Date())

                guard self.activeSession?.isActive(now: Date()) == true else {
                    break
                }
            }

            // stopTicker()経由ですでにnilの場合も問題ない。
            self?.tickerTask = nil
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func stopTickerIfSessionIsInactive() {
        guard activeSession?.isActive(now: Date()) != true else { return }
        stopTicker()
    }

    // MARK: - Persistence

    private func loadFromDefaults() {
        let loadedSession: WalkChallengeSession?

        if let data = defaults.data(forKey: DefaultsKey.activeSession),
           let decoded = try? JSONDecoder().decode(
               WalkChallengeSession.self,
               from: data
           ) {
            loadedSession = decoded
        } else {
            loadedSession = nil
        }

        let loadedPendingResult: WalkChallengeResult?

        if let data = defaults.data(forKey: DefaultsKey.pendingResult),
           let decoded = try? JSONDecoder().decode(
               WalkChallengeResult.self,
               from: data
           ) {
            loadedPendingResult = decoded
        } else {
            loadedPendingResult = nil
        }

        setActiveSession(loadedSession)
        setPendingResult(loadedPendingResult)

        if let loadedSession {
            setCurrentTapCount(loadedSession.tapCount)
        } else {
            setCurrentTapCount(0)
        }
    }

    private func persistSession(_ session: WalkChallengeSession) {
        if let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: DefaultsKey.activeSession)
        }
    }

    private func clearSession() {
        defaults.removeObject(forKey: DefaultsKey.activeSession)
    }

    private func persistPendingResult(_ result: WalkChallengeResult) {
        if let data = try? JSONEncoder().encode(result) {
            defaults.set(data, forKey: DefaultsKey.pendingResult)
        }
    }

    private func clearPendingResult() {
        defaults.removeObject(forKey: DefaultsKey.pendingResult)
    }

    // MARK: - Published value guards
    //
    // 同じ値を毎秒Publishedへ再代入すると、不要なSwiftUI再評価を発生させる。
    // 値が変化した場合だけpublishする。

    private func setActiveSession(_ value: WalkChallengeSession?) {
        guard activeSession != value else { return }
        activeSession = value
    }

    private func setPendingResult(_ value: WalkChallengeResult?) {
        guard pendingResult != value else { return }
        pendingResult = value
    }

    private func setRemainingSeconds(_ value: Int) {
        let safeValue = max(0, value)
        guard remainingSeconds != safeValue else { return }
        remainingSeconds = safeValue
    }

    private func setCurrentTapCount(_ value: Int) {
        let safeValue = max(0, value)
        guard currentTapCount != safeValue else { return }
        currentTapCount = safeValue
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}
