//
//  WalkChallengeStore.swift
//  MeMo
//
//  お散歩機能のセッション・タップ数・リザルトを永続管理するストア。
//  タイマーは画面滞在に依存せず、保存済みの終了時刻と現在時刻の差分で判定する。
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

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadFromDefaults()
        refresh(now: Date())
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

    func bootstrap() {
        loadFromDefaults()
        refresh(now: Date())
        startTickerIfNeeded()
    }

    func canUseRainFreeStart(isRainy: Bool, now: Date = Date()) -> Bool {
        guard isRainy else { return false }
        return defaults.string(forKey: DefaultsKey.rainyFreeUsedDayKey) != Self.dayKey(now)
    }

    @discardableResult
    func startSession(isRainFreeStart: Bool, now: Date = Date()) -> Bool {
        refresh(now: now)
        guard activeSession?.isActive(now: now) != true else { return false }

        let session = WalkChallengeSession(
            id: UUID(),
            startedAt: now,
            endsAt: now.addingTimeInterval(Self.sessionDurationSeconds),
            tapCount: 0,
            isRainFreeStart: isRainFreeStart
        )

        if isRainFreeStart {
            defaults.set(Self.dayKey(now), forKey: DefaultsKey.rainyFreeUsedDayKey)
        }

        activeSession = session
        pendingResult = nil
        remainingSeconds = session.remainingSeconds(now: now)
        currentTapCount = 0
        persistSession(session)
        clearPendingResult()
        startTickerIfNeeded()
        return true
    }

    func registerTap(now: Date = Date()) {
        refresh(now: now)
        guard var session = activeSession, session.isActive(now: now) else { return }

        session.tapCount += 1
        activeSession = session
        currentTapCount = session.tapCount
        persistSession(session)
    }

    func refresh(now: Date = Date()) {
        loadFromDefaults()

        guard let session = activeSession else {
            remainingSeconds = 0
            currentTapCount = 0
            return
        }

        if session.isActive(now: now) {
            remainingSeconds = session.remainingSeconds(now: now)
            currentTapCount = session.tapCount
            return
        }

        finishExpiredSession(session, now: now)
    }

    @discardableResult
    func finishActiveSessionNow(now: Date = Date()) -> WalkChallengeResult? {
        loadFromDefaults()

        guard let session = activeSession else {
            refresh(now: now)
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

        activeSession = nil
        pendingResult = result
        remainingSeconds = 0
        currentTapCount = 0
        clearSession()
        persistPendingResult(result)
        return result
    }

    @discardableResult
    func claimPendingResult(multiplier: Int, state: AppState) -> Int {
        guard let result = pendingResult else { return 0 }
        let safeMultiplier = max(1, multiplier)
        let grantedSteps = max(0, result.baseSteps * safeMultiplier)

        if grantedSteps > 0 {
            _ = state.addWalletSteps(grantedSteps)
        }

        pendingResult = nil
        clearPendingResult()
        return grantedSteps
    }

    func dismissPendingResultWithoutClaim() {
        pendingResult = nil
        clearPendingResult()
    }

    private func finishExpiredSession(_ session: WalkChallengeSession, now: Date) {
        let result = WalkChallengeResult(
            id: UUID(),
            sessionID: session.id,
            baseSteps: max(0, session.tapCount),
            startedAt: session.startedAt,
            endedAt: session.endsAt,
            isRainFreeStart: session.isRainFreeStart
        )

        activeSession = nil
        pendingResult = result
        remainingSeconds = 0
        currentTapCount = 0
        clearSession()
        persistPendingResult(result)
    }

    private func startTickerIfNeeded() {
        guard tickerTask == nil else { return }

        tickerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refresh(now: Date())
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func loadFromDefaults() {
        if let data = defaults.data(forKey: DefaultsKey.activeSession),
           let decoded = try? JSONDecoder().decode(WalkChallengeSession.self, from: data) {
            activeSession = decoded
            currentTapCount = decoded.tapCount
        } else {
            activeSession = nil
        }

        if let data = defaults.data(forKey: DefaultsKey.pendingResult),
           let decoded = try? JSONDecoder().decode(WalkChallengeResult.self, from: data) {
            pendingResult = decoded
        } else {
            pendingResult = nil
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

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}
