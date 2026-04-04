//
//  HealthKitManager.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation
import HealthKit
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif

@MainActor
final class HealthKitManager: ObservableObject {
    enum AuthState: Equatable { case unknown, denied, authorized }

    @Published private(set) var authState: AuthState = .unknown

    // 今日の歩数
    @Published private(set) var todaySteps: Int = 0

    // NOTE:
    // 仕様変更により消費カロリーは使わないが、
    // 既存コード互換のため公開プロパティは残す。
    @Published private(set) var todayActiveEnergyKcal: Int = 0
    @Published private(set) var todayBasalEnergyKcal: Int = 0

    // NOTE:
    // 既存の totalKcal 参照箇所を壊しにくくするため残す。
    // 実体は「今日の歩数」を入れて扱う。
    @Published private(set) var todayTotalEnergyKcal: Int = 0

    @Published private(set) var errorMessage: String?

    private let store = HKHealthStore()

    // ✅ 同日内で「一時的に0が返る」ケースの保護
    private var lastGoodDayKey: String = ""
    private var lastGoodSteps: Int = 0

    // ✅ 追加：歩数更新監視
    private var stepObserverQuery: HKObserverQuery?
    private var isStepObservationStarted: Bool = false
    private var isRefreshingTodaySteps: Bool = false

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        return types
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authState = .denied
            errorMessage = "この端末ではHealthデータを利用できません。"
            return
        }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            authState = .authorized

            // ✅ 許可取得後に歩数監視を開始
            await startStepUpdatesIfNeeded()
            await refreshTodayStepsForWidget()
        } catch {
            authState = .denied
            errorMessage = "HealthKitの許可取得に失敗: \(error.localizedDescription)"
        }
    }

    /// ✅ Widget 用に今日の歩数を即時更新
    func refreshTodayStepsForWidget(now: Date = Date()) async {
        guard authState == .authorized else { return }
        guard !isRefreshingTodaySteps else { return }

        isRefreshingTodaySteps = true
        defer { isRefreshingTodaySteps = false }

        _ = await fetchTodayStepTotal(now: now)
    }

    /// ✅ 歩数の変更監視を開始
    func startStepUpdatesIfNeeded() async {
        guard authState == .authorized else { return }
        guard !isStepObservationStarted else { return }
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            defer { completionHandler() }

            guard let self else { return }

            if let error {
                Task { @MainActor in
                    self.errorMessage = "歩数監視に失敗: \(error.localizedDescription)"
                }
                return
            }

            Task { @MainActor in
                await self.refreshTodayStepsForWidget()
            }
        }

        stepObserverQuery = query
        store.execute(query)
        isStepObservationStarted = true

        do {
            try await enableBackgroundDelivery(for: stepType)
        } catch {
            errorMessage = "歩数のバックグラウンド更新設定に失敗: \(error.localizedDescription)"
        }
    }

    /// ✅ HKHealthStore のコールバックAPIを async 化
    private func enableBackgroundDelivery(for type: HKQuantityType) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            store.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }

                if success {
                    cont.resume(returning: ())
                } else {
                    cont.resume(throwing: NSError(
                        domain: "HealthKitManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "歩数のバックグラウンド更新を有効化できませんでした。"]
                    ))
                }
            }
        }
    }

    /// ✅ 新仕様：start（前回同期）〜 now の歩数差分を返す
    /// - Returns: (deltaSteps, newLastSyncedAt)
    func syncAndGetDeltaSteps(lastSyncedAt: Date?) async -> (deltaSteps: Int, newLastSyncedAt: Date?) {
        guard authState == .authorized else { return (0, lastSyncedAt) }

        do {
            let now = Date()
            let todayStart = Calendar.current.startOfDay(for: now)

            // ✅ lastSyncedAt が昨日以前でも「今日の0:00」に丸める
            let rawStart = lastSyncedAt ?? todayStart
            let start = max(rawStart, todayStart)

            let todayKey = Self.makeDayKey(now)
            if lastGoodDayKey != todayKey {
                lastGoodDayKey = todayKey
                lastGoodSteps = 0
            }

            async let todayStepsRaw = fetchSteps(from: todayStart, to: now)
            async let deltaStepsRaw = fetchSteps(from: start, to: now)

            let (todayFetched, deltaFetched) = try await (todayStepsRaw, deltaStepsRaw)

            // ✅ 同日内で一時的に0になった場合は、直近の良い値を優先
            let protectedTodaySteps: Int =
                (todayFetched == 0 && lastGoodSteps > 0) ? lastGoodSteps : max(0, todayFetched)

            todaySteps = protectedTodaySteps

            // 互換プロパティ
            todayActiveEnergyKcal = 0
            todayBasalEnergyKcal = 0
            todayTotalEnergyKcal = protectedTodaySteps

            if protectedTodaySteps > 0 {
                lastGoodSteps = protectedTodaySteps
            }

            // ✅ 歩数だけでも Widget へ早めに反映
            pushTodayStepsToWidgetIfNeeded(protectedTodaySteps)

            return (max(0, deltaFetched), now)
        } catch {
            errorMessage = "同期に失敗: \(error.localizedDescription)"
            return (0, lastSyncedAt)
        }
    }

    /// ✅ 互換用
    /// 旧コードが残っていてもコンパイルを壊しにくくするため残す。
    /// 実体は「歩数差分」を返す。
    func syncAndGetDeltaKcal(lastSyncedAt: Date?) async -> (deltaKcal: Int, newLastSyncedAt: Date?) {
        let result = await syncAndGetDeltaSteps(lastSyncedAt: lastSyncedAt)
        return (deltaKcal: result.deltaSteps, newLastSyncedAt: result.newLastSyncedAt)
    }

    // MARK: - Fetchers

    private func predicate(from: Date, to: Date) -> NSPredicate {
        HKQuery.predicateForSamples(withStart: from, end: to, options: .strictStartDate)
    }

    private func fetchSteps(from: Date, to: Date) async throws -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let pred = predicate(from: from, to: to)

        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: pred,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                let sum = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                cont.resume(returning: Int(sum))
            }
            store.execute(q)
        }
    }

    // MARK: - Step totals for Step Enjoy

    public func fetchStepCount(from: Date, to: Date) async -> Int {
        guard authState == .authorized else { return 0 }

        do {
            return max(0, try await fetchSteps(from: from, to: to))
        } catch {
            errorMessage = "歩数取得に失敗: \(error.localizedDescription)"
            return 0
        }
    }

    public func fetchTodayStepTotal(now: Date = Date()) async -> Int {
        let start = Calendar.current.startOfDay(for: now)
        let fetched = await fetchStepCount(from: start, to: now)

        let todayKey = Self.makeDayKey(now)
        if lastGoodDayKey != todayKey {
            lastGoodDayKey = todayKey
            lastGoodSteps = 0
        }

        let protectedSteps = (fetched == 0 && lastGoodSteps > 0) ? lastGoodSteps : fetched

        todaySteps = protectedSteps

        // 互換プロパティ
        todayActiveEnergyKcal = 0
        todayBasalEnergyKcal = 0
        todayTotalEnergyKcal = protectedSteps

        if protectedSteps > 0 {
            lastGoodSteps = protectedSteps
        }

        // ✅ StepEnjoy 系の取得でも Widget 側へ反映
        pushTodayStepsToWidgetIfNeeded(protectedSteps)

        return protectedSteps
    }

    public func fetchWeekStepTotal(now: Date = Date()) async -> Int {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        return await fetchStepCount(from: start, to: now)
    }

    // MARK: - Widget Bridge

    private func pushTodayStepsToWidgetIfNeeded(_ steps: Int) {
        let safeSteps = max(0, steps)
        let changed = HealthKitWidgetBridge.saveTodaySteps(safeSteps)

        #if canImport(WidgetKit)
        if changed {
            WidgetCenter.shared.reloadTimelines(ofKind: HealthKitWidgetBridge.widgetKind)
        }
        #endif
    }

    // MARK: - DayKey

    private static func makeDayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }
}

// MARK: - Widget Bridge

private enum HealthKitWidgetBridge {
    static let appGroupID = "group.com.shota.CalPet"
    static let widgetKind = "CalPetMediumWidget"

    private static let todayStepsKey = "todaySteps"
    private static let lastStepsSignatureKey = "healthKitWidgetLastTodaySteps"

    static func saveTodaySteps(_ todaySteps: Int) -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return false }

        let safeSteps = max(0, todaySteps)
        let previousSteps = defaults.object(forKey: lastStepsSignatureKey) as? Int

        defaults.set(safeSteps, forKey: todayStepsKey)
        defaults.set(safeSteps, forKey: lastStepsSignatureKey)

        return previousSteps != safeSteps
    }
}
