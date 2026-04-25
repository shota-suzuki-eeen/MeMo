//
//  AppState.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation
import SwiftData

@Model
final class AppState {
    // MARK: - Currency (Step)
    // NOTE:
    // SwiftData の既存保存データを壊しにくくするため、
    // backing store のプロパティ名は一旦そのまま維持する。
    // 実際の意味は「歩数通貨」として扱う。
    var walletKcal: Int
    var pendingKcal: Int

    // MARK: - Health Sync
    var lastSyncedAt: Date?

    // MARK: - Goal
    // NOTE:
    // 仕様変更により目標は固定 10,000 歩。
    // 既存保存データ互換のため backing store 名は維持する。
    var dailyGoalKcal: Int

    // 日跨ぎ判定用（yyyyMMdd）
    var lastDayKey: String

    // MARK: - Today Cache (Offline / Protect Zero)
    // cachedTodaySteps      : 実歩数のキャッシュ
    // cachedTodayKcal       : メーター表示用の歩数キャッシュとして再利用
    var cachedTodaySteps: Int
    var cachedTodayKcal: Int

    // MARK: - ✅ Fullness (backing store: satisfaction)
    // NOTE:
    // 既存 SwiftData 互換のためプロパティ名は satisfaction のまま維持するが、
    // 実体は「満腹度」として扱う。
    // 0...5 の5段階。30分ごとに1減少。
    var satisfactionLevel: Int
    var satisfactionLastUpdatedAt: Date?

    // ✅ ごはん（フラグ制）
    // NOTE:
    // 満腹度が MAX 未満のときのみ成立させる。
    var foodFlagAt: Date?
    var foodLastRaisedAt: Date?
    var foodNextSpawnAt: Date?

    // ✅ お風呂
    var bathFlagAt: Date?
    var bathLastRaisedAt: Date?
    var bathNextSpawnAt: Date?

    // ✅ トイレ
    var toiletFlagAt: Date?
    var toiletLastRaisedAt: Date?
    var toiletNextSpawnAt: Date?

    // ✅ トイレ中のpoop配置（同一イベント中のみ保持）
    var toiletPoopsData: Data?

    // ✅ トイレpoopの時間増加基準時刻
    var toiletPoopLastSpawnAt: Date?


    // ✅ キャラ（MVP）
    var currentPetID: String
    var ownedPetIDsData: Data?

    // ✅ 通知設定（MVP：トグル保存のみ）
    var notifyFeed: Bool
    var notifyBath: Bool
    var notifyToilet: Bool

    // ✅ ご飯インベントリ
    var ownedFoodCountsData: Data?

    // MARK: - ✅ Super Favorite Reveal (NEW)
    var superFavoriteRevealedData: Data? = nil


    // MARK: - Step Enjoy
    var stepEnjoyLastCheckedAt: Date? = nil

    // HomeView の「総歩数」表示に使う累計獲得量。
    // 通貨の消費では減らさず、獲得でのみ増やす。
    var stepEnjoyTotalSteps: Int = 0

    // 直近で獲得した差分。補助的な記録用途として保持。
    var stepEnjoyLastDeltaSteps: Int = 0

    var stepEnjoyLogsData: Data? = nil
    var stepEnjoyDailyCycleStart: Date = Date()
    var stepEnjoyDailyRewardCount: Int = 0
    var stepEnjoyDailyRewardStepBank: Int = 0
    var stepEnjoyLastRewardAt: Date? = nil

    init(
        walletKcal: Int = 0,
        pendingKcal: Int = 0,
        lastSyncedAt: Date? = nil,
        dailyGoalKcal: Int = AppState.fixedDailyStepGoal,
        lastDayKey: String = AppState.makeDayKey(Date()),

        cachedTodaySteps: Int = 0,
        cachedTodayKcal: Int = 0,

        satisfactionLevel: Int = 0,
        satisfactionLastUpdatedAt: Date? = nil,

        foodFlagAt: Date? = nil,
        foodLastRaisedAt: Date? = nil,
        foodNextSpawnAt: Date? = nil,

        bathFlagAt: Date? = nil,
        bathLastRaisedAt: Date? = nil,
        bathNextSpawnAt: Date? = nil,

        toiletFlagAt: Date? = nil,
        toiletLastRaisedAt: Date? = nil,
        toiletNextSpawnAt: Date? = nil,
        toiletPoopsData: Data? = nil,
        toiletPoopLastSpawnAt: Date? = nil,


        currentPetID: String = "pet_000",
        ownedPetIDsData: Data? = nil,

        notifyFeed: Bool = true,
        notifyBath: Bool = true,
        notifyToilet: Bool = true,

        ownedFoodCountsData: Data? = nil,

        superFavoriteRevealedData: Data? = nil,


        stepEnjoyLastCheckedAt: Date? = nil,
        stepEnjoyTotalSteps: Int = 0,
        stepEnjoyLastDeltaSteps: Int = 0,
        stepEnjoyLogsData: Data? = nil,
        stepEnjoyDailyCycleStart: Date = Date(),
        stepEnjoyDailyRewardCount: Int = 0,
        stepEnjoyDailyRewardStepBank: Int = 0,
        stepEnjoyLastRewardAt: Date? = nil
    ) {
        self.walletKcal = max(0, walletKcal)
        self.pendingKcal = max(0, pendingKcal)

        self.lastSyncedAt = lastSyncedAt

        self.dailyGoalKcal = dailyGoalKcal
        self.lastDayKey = lastDayKey

        self.cachedTodaySteps = max(0, cachedTodaySteps)
        self.cachedTodayKcal = max(0, cachedTodayKcal)

        let clampedSatisfaction = min(AppState.fullnessMaxLevel, max(0, satisfactionLevel))
        self.satisfactionLevel = clampedSatisfaction
        self.satisfactionLastUpdatedAt = clampedSatisfaction > 0 ? satisfactionLastUpdatedAt : nil

        self.foodFlagAt = foodFlagAt
        self.foodLastRaisedAt = foodLastRaisedAt
        self.foodNextSpawnAt = foodNextSpawnAt

        self.bathFlagAt = bathFlagAt
        self.bathLastRaisedAt = bathLastRaisedAt
        self.bathNextSpawnAt = bathNextSpawnAt

        self.toiletFlagAt = toiletFlagAt
        self.toiletLastRaisedAt = toiletLastRaisedAt
        self.toiletNextSpawnAt = toiletNextSpawnAt
        self.toiletPoopsData = toiletPoopsData
        self.toiletPoopLastSpawnAt = toiletPoopLastSpawnAt


        self.currentPetID = currentPetID
        self.ownedPetIDsData = ownedPetIDsData

        self.notifyFeed = notifyFeed
        self.notifyBath = notifyBath
        self.notifyToilet = notifyToilet

        self.ownedFoodCountsData = ownedFoodCountsData

        self.superFavoriteRevealedData = superFavoriteRevealedData


        self.stepEnjoyLastCheckedAt = stepEnjoyLastCheckedAt
        self.stepEnjoyTotalSteps = max(0, stepEnjoyTotalSteps)
        self.stepEnjoyLastDeltaSteps = max(0, stepEnjoyLastDeltaSteps)
        self.stepEnjoyLogsData = stepEnjoyLogsData
        self.stepEnjoyDailyCycleStart = stepEnjoyDailyCycleStart
        self.stepEnjoyDailyRewardCount = max(0, stepEnjoyDailyRewardCount)
        self.stepEnjoyDailyRewardStepBank = max(0, stepEnjoyDailyRewardStepBank)
        self.stepEnjoyLastRewardAt = stepEnjoyLastRewardAt

        _ = normalizeFixedDailyStepGoal()
    }

    static func makeDayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "ja_JP")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }
}

// MARK: - Step-based aliases / fixed goal
extension AppState {
    static let fixedDailyStepGoal: Int = 10_000

    // ✅ 満腹度仕様
    static let fullnessMaxLevel: Int = 5
    static let fullnessDecayUnitSeconds: TimeInterval = 30 * 60

    // ✅ トイレpoop仕様
    static let toiletPoopInitialCount: Int = 1
    static let toiletPoopMaxCount: Int = 15
    static let toiletPoopSpawnIntervalSeconds: TimeInterval = 15 * 60

    /// 歩数通貨の所持数
    /// 増加したぶんだけ累計獲得歩数にも反映する。
    /// 消費などで減少した場合は累計側を減らさない。
    var walletSteps: Int {
        get { max(0, walletKcal) }
        set {
            let previousValue = max(0, walletKcal)
            let sanitizedNewValue = max(0, newValue)
            walletKcal = sanitizedNewValue

            let gainedSteps = sanitizedNewValue - previousValue
            if gainedSteps > 0 {
                cumulativeEarnedSteps += gainedSteps
                stepEnjoyLastDeltaSteps = gainedSteps
            } else if gainedSteps < 0 {
                stepEnjoyLastDeltaSteps = 0
            }
        }
    }

    /// 未反映の歩数通貨
    var pendingSteps: Int {
        get { max(0, pendingKcal) }
        set { pendingKcal = max(0, newValue) }
    }

    /// HomeView の「総歩数」に表示する累計獲得歩数。
    /// 通貨の残高とは別管理で、消費では減らさない。
    var cumulativeEarnedSteps: Int {
        get { max(0, stepEnjoyTotalSteps) }
        set { stepEnjoyTotalSteps = max(0, newValue) }
    }

    /// 1日の固定目標歩数（変更不可）
    var dailyStepGoal: Int {
        get { AppState.fixedDailyStepGoal }
        set { dailyGoalKcal = AppState.fixedDailyStepGoal }
    }

    /// Home 左上メーター表示用の歩数キャッシュ
    var cachedTodayMeterSteps: Int {
        get { max(0, cachedTodayKcal) }
        set { cachedTodayKcal = max(0, newValue) }
    }

    @discardableResult
    func normalizeFixedDailyStepGoal() -> Bool {
        guard dailyGoalKcal != AppState.fixedDailyStepGoal else { return false }
        dailyGoalKcal = AppState.fixedDailyStepGoal
        return true
    }
}

// MARK: - Widget Support
extension AppState {
    struct WidgetStateSnapshot: Equatable {
        let toiletFlag: Bool
        let bathFlag: Bool
        let currentPetID: String
        let todaySteps: Int

        // ✅ Widget側で未起動中の状態判定に使える時刻情報
        let toiletFlagAt: Date?
        let bathFlagAt: Date?
        let toiletNextSpawnAt: Date?
        let bathNextSpawnAt: Date?
        let lastDayKey: String
    }

    var hasFoodFlag: Bool {
        foodFlagAt != nil
    }

    var hasToiletFlag: Bool {
        toiletFlagAt != nil
    }

    var normalizedCurrentPetID: String {
        let trimmed = currentPetID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "pet_000" : trimmed
    }

    var widgetCurrentPetID: String {
        normalizedCurrentPetID
    }

    var widgetTodaySteps: Int {
        max(0, cachedTodaySteps)
    }

    func resolvedWidgetTodaySteps(_ overrideTodaySteps: Int? = nil) -> Int {
        max(0, overrideTodaySteps ?? cachedTodaySteps)
    }

    func makeWidgetStateSnapshot(todaySteps overrideTodaySteps: Int? = nil) -> WidgetStateSnapshot {
        WidgetStateSnapshot(
            toiletFlag: hasToiletFlag,
            bathFlag: hasBathFlag,
            currentPetID: widgetCurrentPetID,
            todaySteps: resolvedWidgetTodaySteps(overrideTodaySteps),
            toiletFlagAt: toiletFlagAt,
            bathFlagAt: bathFlagAt,
            toiletNextSpawnAt: toiletNextSpawnAt,
            bathNextSpawnAt: bathNextSpawnAt,
            lastDayKey: lastDayKey
        )
    }
}

// MARK: - Currency helpers
extension AppState {
    @discardableResult
    func drainPendingStepsToWallet() -> Int {
        let delta = max(0, pendingSteps)
        guard delta > 0 else { return 0 }
        walletSteps += delta
        pendingSteps = 0
        return delta
    }

    @discardableResult
    func drainPendingKcalToWallet() -> Int {
        drainPendingStepsToWallet()
    }
}

// MARK: - Food Inventory
extension AppState {
    private func ownedFoodCounts() -> [String: Int] {
        guard let data = ownedFoodCountsData,
              let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return dict
    }

    private func setOwnedFoodCounts(_ dict: [String: Int]) {
        ownedFoodCountsData = try? JSONEncoder().encode(dict)
    }

    func foodCount(foodId: String) -> Int {
        let dict = ownedFoodCounts()
        return max(0, dict[foodId] ?? 0)
    }

    func firstOwnedFoodId(from ids: [String]) -> String? {
        for id in ids where foodCount(foodId: id) > 0 {
            return id
        }
        return nil
    }

    @discardableResult
    func addFood(foodId: String, count: Int = 1) -> Bool {
        let add = max(0, count)
        guard add > 0 else { return false }

        var dict = ownedFoodCounts()
        let current = max(0, dict[foodId] ?? 0)
        dict[foodId] = current + add
        setOwnedFoodCounts(dict)
        return true
    }

    @discardableResult
    func consumeFood(foodId: String, count: Int = 1) -> Bool {
        let use = max(0, count)
        guard use > 0 else { return false }

        var dict = ownedFoodCounts()
        let current = max(0, dict[foodId] ?? 0)
        guard current >= use else { return false }

        let next = current - use
        if next <= 0 {
            dict.removeValue(forKey: foodId)
        } else {
            dict[foodId] = next
        }
        setOwnedFoodCounts(dict)
        return true
    }
}

// MARK: - ✅ Super Favorite Reveal helpers
extension AppState {
    private func superFavoriteRevealedMap() -> [String: Bool] {
        guard let data = superFavoriteRevealedData,
              let dict = try? JSONDecoder().decode([String: Bool].self, from: data) else {
            return [:]
        }
        return dict
    }

    private func setSuperFavoriteRevealedMap(_ dict: [String: Bool]) {
        superFavoriteRevealedData = try? JSONEncoder().encode(dict)
    }

    func isSuperFavoriteRevealed(petID: String) -> Bool {
        let dict = superFavoriteRevealedMap()
        return dict[petID] ?? false
    }

    @discardableResult
    func revealSuperFavorite(petID: String) -> Bool {
        if !isValidZukanPetID(petID) { return false }

        var dict = superFavoriteRevealedMap()
        if dict[petID] == true { return false }

        dict[petID] = true
        setSuperFavoriteRevealedMap(dict)
        return true
    }
}

// MARK: - Toilet Poops
extension AppState {
    struct ToiletPoopItem: Codable, Identifiable, Equatable {
        let id: String
        var centerXRatio: Double
        var centerYRatio: Double
        var rotationDegrees: Double
        var isFlippedHorizontally: Bool
        var cleanedProgress: Double
        var isCleared: Bool

        private enum CodingKeys: String, CodingKey {
            case id
            case centerXRatio
            case centerYRatio
            case rotationDegrees
            case isFlippedHorizontally
            case cleanedProgress
            case isCleared
        }

        init(
            id: String = UUID().uuidString,
            centerXRatio: Double,
            centerYRatio: Double,
            rotationDegrees: Double,
            isFlippedHorizontally: Bool,
            cleanedProgress: Double = 0,
            isCleared: Bool = false
        ) {
            self.id = id
            self.centerXRatio = centerXRatio
            self.centerYRatio = centerYRatio
            self.rotationDegrees = rotationDegrees
            self.isFlippedHorizontally = isFlippedHorizontally
            self.cleanedProgress = max(0, min(1, cleanedProgress))
            self.isCleared = isCleared
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
            centerXRatio = try container.decode(Double.self, forKey: .centerXRatio)
            centerYRatio = try container.decode(Double.self, forKey: .centerYRatio)
            rotationDegrees = try container.decode(Double.self, forKey: .rotationDegrees)
            isFlippedHorizontally = try container.decode(Bool.self, forKey: .isFlippedHorizontally)
            cleanedProgress = max(0, min(1, try container.decodeIfPresent(Double.self, forKey: .cleanedProgress) ?? 0))
            isCleared = try container.decodeIfPresent(Bool.self, forKey: .isCleared) ?? false
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(centerXRatio, forKey: .centerXRatio)
            try container.encode(centerYRatio, forKey: .centerYRatio)
            try container.encode(rotationDegrees, forKey: .rotationDegrees)
            try container.encode(isFlippedHorizontally, forKey: .isFlippedHorizontally)
            try container.encode(cleanedProgress, forKey: .cleanedProgress)
            try container.encode(isCleared, forKey: .isCleared)
        }
    }

    func toiletPoops() -> [ToiletPoopItem] {
        guard let data = toiletPoopsData,
              let items = try? JSONDecoder().decode([ToiletPoopItem].self, from: data) else {
            return []
        }
        return items
    }

    func setToiletPoops(_ items: [ToiletPoopItem]) {
        if items.isEmpty {
            toiletPoopsData = nil
        } else {
            toiletPoopsData = try? JSONEncoder().encode(items)
        }
    }

    func clearToiletPoops() {
        toiletPoopsData = nil
    }

    var hasRemainingToiletPoops: Bool {
        toiletPoops().contains(where: { !$0.isCleared })
    }

    @discardableResult
    func updateToiletPoopProgress(id: String, progress: Double) -> Bool {
        var items = toiletPoops()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        guard items[index].isCleared == false else { return false }

        let clamped = max(0, min(1, progress))
        guard abs(items[index].cleanedProgress - clamped) > 0.0001 else { return false }

        items[index].cleanedProgress = clamped
        setToiletPoops(items)
        return true
    }

    @discardableResult
    func markToiletPoopCleared(id: String) -> Bool {
        var items = toiletPoops()
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        guard items[index].isCleared == false else { return false }

        items[index].cleanedProgress = 1
        items[index].isCleared = true
        setToiletPoops(items)
        return true
    }

    private func clampedRatio(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.max(minValue, Swift.min(maxValue, value))
    }

    private func randomToiletPoopItem(existing: [ToiletPoopItem]) -> ToiletPoopItem {
        let xRange: ClosedRange<Double> = 0.15...0.85
        let yRange: ClosedRange<Double> = 0.18...0.82
        let minDistance: Double = 0.16

        for _ in 0..<50 {
            let candidateX = Double.random(in: xRange)
            let candidateY = Double.random(in: yRange)

            let overlaps = existing.contains { item in
                let dx = item.centerXRatio - candidateX
                let dy = item.centerYRatio - candidateY
                return sqrt(dx * dx + dy * dy) < minDistance
            }

            if !overlaps {
                return ToiletPoopItem(
                    centerXRatio: candidateX,
                    centerYRatio: candidateY,
                    rotationDegrees: Double.random(in: -30...30),
                    isFlippedHorizontally: Bool.random()
                )
            }
        }

        return ToiletPoopItem(
            centerXRatio: clampedRatio(Double.random(in: xRange), min: 0.1, max: 0.9),
            centerYRatio: clampedRatio(Double.random(in: yRange), min: 0.1, max: 0.9),
            rotationDegrees: Double.random(in: -30...30),
            isFlippedHorizontally: Bool.random()
        )
    }

    func generateToiletPoops(count: Int, existing: [ToiletPoopItem] = []) -> [ToiletPoopItem] {
        let safeCount = max(0, count)
        guard safeCount > 0 else { return [] }

        var results: [ToiletPoopItem] = []
        let occupied = existing.filter { !$0.isCleared }

        for _ in 0..<safeCount {
            let item = randomToiletPoopItem(existing: occupied + results)
            results.append(item)
        }

        return results
    }

    @discardableResult
    func updateToiletPoopsByTime(now: Date = Date()) -> Bool {
        ensureDailyResetIfNeeded(now: now)

        guard let flagAt = toiletFlagAt else { return false }

        let interval = AppState.toiletPoopSpawnIntervalSeconds
        let initialCount = AppState.toiletPoopInitialCount
        let maxCount = AppState.toiletPoopMaxCount

        var items = toiletPoops()
        let activeItems = items.filter { !$0.isCleared }
        let activeCount = activeItems.count
        var didChange = false

        if activeCount == 0 {
            let elapsedSinceFlag = max(0, now.timeIntervalSince(flagAt))
            let additionalCount = Int(elapsedSinceFlag / interval)
            let totalCount = min(maxCount, initialCount + additionalCount)

            if totalCount > 0 {
                let restoredItems = generateToiletPoops(count: totalCount)
                setToiletPoops(restoredItems)
                didChange = true

                if totalCount >= maxCount {
                    toiletPoopLastSpawnAt = now
                } else {
                    let restoredAdditionalCount = max(0, totalCount - initialCount)
                    toiletPoopLastSpawnAt = flagAt.addingTimeInterval(TimeInterval(restoredAdditionalCount) * interval)
                }
            } else if toiletPoopLastSpawnAt != flagAt {
                toiletPoopLastSpawnAt = flagAt
                didChange = true
            }

            return didChange
        }

        if activeCount >= maxCount {
            let cappedLastSpawnAt: Date = {
                if let existingLastSpawnAt = toiletPoopLastSpawnAt {
                    return existingLastSpawnAt
                }

                let inferredAdditionalCount = max(0, maxCount - initialCount)
                return flagAt.addingTimeInterval(TimeInterval(inferredAdditionalCount) * interval)
            }()

            if toiletPoopLastSpawnAt != cappedLastSpawnAt {
                toiletPoopLastSpawnAt = cappedLastSpawnAt
                didChange = true
            }
            return didChange
        }

        let effectiveLastSpawnAt: Date = {
            if let lastSpawnAt = toiletPoopLastSpawnAt {
                return lastSpawnAt
            }

            let inferredAdditionalCount = max(0, activeCount - initialCount)
            return flagAt.addingTimeInterval(TimeInterval(inferredAdditionalCount) * interval)
        }()

        if toiletPoopLastSpawnAt == nil {
            toiletPoopLastSpawnAt = effectiveLastSpawnAt
            didChange = true
        }

        let elapsed = max(0, now.timeIntervalSince(effectiveLastSpawnAt))
        let addableCount = min(Int(elapsed / interval), maxCount - activeCount)

        guard addableCount > 0 else {
            return didChange
        }

        items.append(contentsOf: generateToiletPoops(count: addableCount, existing: activeItems))
        setToiletPoops(items)
        didChange = true

        if activeCount + addableCount >= maxCount {
            toiletPoopLastSpawnAt = now
        } else {
            toiletPoopLastSpawnAt = effectiveLastSpawnAt.addingTimeInterval(TimeInterval(addableCount) * interval)
        }

        return didChange
    }
}

// MARK: - Day Reset
extension AppState {
    func ensureDailyResetIfNeeded(now: Date = Date()) {
        let todayKey = AppState.makeDayKey(now)
        guard lastDayKey != todayKey else {
            _ = normalizeFixedDailyStepGoal()
            return
        }

        if satisfactionLastUpdatedAt == nil, satisfactionLevel > 0 {
            satisfactionLastUpdatedAt = now
        }

        // ✅ 発生中フラグ・次回予定時刻は日跨ぎでも維持
        lastDayKey = todayKey
        _ = normalizeFixedDailyStepGoal()
    }
}

// MARK: - Today Cache helpers
extension AppState {
    struct CacheUpdateResult: Equatable {
        let stepsToUse: Int
        let kcalToUse: Int
        let didUpdateStepsCache: Bool
        let didUpdateKcalCache: Bool

        var meterStepsToUse: Int { kcalToUse }
        var didUpdateMeterStepsCache: Bool { didUpdateKcalCache }
    }

    func updateTodayStepCacheProtectingZero(
        fetchedSteps: Int,
        todayKey: String
    ) -> CacheUpdateResult {
        updateTodayCacheProtectingZero(
            fetchedSteps: fetchedSteps,
            fetchedKcal: fetchedSteps,
            todayKey: todayKey
        )
    }

    func updateTodayCacheProtectingZero(
        fetchedSteps: Int,
        fetchedKcal: Int,
        todayKey: String
    ) -> CacheUpdateResult {
        _ = normalizeFixedDailyStepGoal()

        if lastDayKey != todayKey {
            cachedTodaySteps = 0
            cachedTodayKcal = 0
        }

        let safeFetchedSteps = max(0, fetchedSteps)
        let safeFetchedMeterSteps = max(0, fetchedKcal)

        let prevSteps = max(0, cachedTodaySteps)
        let prevMeterSteps = max(0, cachedTodayKcal)

        let protectSteps = (safeFetchedSteps == 0 && prevSteps > 0)
        let protectMeterSteps = (safeFetchedMeterSteps == 0 && prevMeterSteps > 0)

        let stepsToUse = protectSteps ? prevSteps : safeFetchedSteps
        let meterStepsToUse = protectMeterSteps ? prevMeterSteps : safeFetchedMeterSteps

        var didUpdateStepsCache = false
        var didUpdateMeterStepsCache = false

        if !protectSteps {
            cachedTodaySteps = stepsToUse
            didUpdateStepsCache = true
        }
        if !protectMeterSteps {
            cachedTodayKcal = meterStepsToUse
            didUpdateMeterStepsCache = true
        }

        return .init(
            stepsToUse: stepsToUse,
            kcalToUse: meterStepsToUse,
            didUpdateStepsCache: didUpdateStepsCache,
            didUpdateKcalCache: didUpdateMeterStepsCache
        )
    }
}

// MARK: - ✅ Fullness (backing store: satisfaction)
extension AppState {
    private func clampSatisfaction(_ value: Int) -> Int {
        min(AppState.fullnessMaxLevel, max(0, value))
    }

    private func computedSatisfaction(now: Date = Date()) -> (level: Int, effectiveLastUpdatedAt: Date?) {
        let current = clampSatisfaction(satisfactionLevel)

        guard current > 0 else {
            return (0, nil)
        }

        guard let last = satisfactionLastUpdatedAt else {
            return (current, nil)
        }

        let elapsed = max(0, now.timeIntervalSince(last))
        let steps = Int(floor(elapsed / AppState.fullnessDecayUnitSeconds))

        guard steps > 0 else {
            return (current, last)
        }

        let after = clampSatisfaction(current - steps)
        if after <= 0 {
            return (0, nil)
        }

        let advanced = TimeInterval(steps) * AppState.fullnessDecayUnitSeconds
        let effectiveLast = last.addingTimeInterval(advanced)
        return (after, effectiveLast)
    }

    /// 現在の満腹度（0...5）
    func currentSatisfaction(now: Date = Date()) -> Int {
        computedSatisfaction(now: now).level
    }

    /// 別名（意味を分かりやすくする用）
    func currentFullness(now: Date = Date()) -> Int {
        currentSatisfaction(now: now)
    }

    /// ご飯をあげられるか
    func canFeedNow(now: Date = Date()) -> (can: Bool, reason: String?) {
        let level = computedSatisfaction(now: now).level
        if level >= AppState.fullnessMaxLevel {
            return (false, "満腹度が最大のためご飯をあげられません")
        }
        return (true, nil)
    }

    /// 次に1段階減るまでの残り秒数
    func satisfactionRemainingSecondsUntilNextDecay(now: Date = Date()) -> TimeInterval? {
        let computed = computedSatisfaction(now: now)
        let level = computed.level

        guard level > 0 else { return nil }

        let referenceDate: Date
        if let effective = computed.effectiveLastUpdatedAt {
            referenceDate = effective
        } else if let last = satisfactionLastUpdatedAt {
            referenceDate = last
        } else {
            return AppState.fullnessDecayUnitSeconds
        }

        let elapsed = max(0, now.timeIntervalSince(referenceDate))
        let remaining = AppState.fullnessDecayUnitSeconds - elapsed
        return max(0, remaining)
    }

    @discardableResult
    func applySatisfactionDecayIfNeeded(now: Date = Date()) -> Int {
        ensureDailyResetIfNeeded(now: now)

        satisfactionLevel = clampSatisfaction(satisfactionLevel)

        guard satisfactionLevel > 0 else {
            satisfactionLevel = 0
            satisfactionLastUpdatedAt = nil
            return 0
        }

        guard satisfactionLastUpdatedAt != nil else {
            satisfactionLastUpdatedAt = now
            return satisfactionLevel
        }

        let computed = computedSatisfaction(now: now)
        satisfactionLevel = clampSatisfaction(computed.level)

        if satisfactionLevel <= 0 {
            satisfactionLevel = 0
            satisfactionLastUpdatedAt = nil
            return 0
        }

        satisfactionLastUpdatedAt = computed.effectiveLastUpdatedAt
        return satisfactionLevel
    }

    /// ご飯を1回あげて満腹度を+1する
    /// 仕様: どのご飯でも現段階では同じ数値増加
    @discardableResult
    func feedOnce(now: Date = Date()) -> (didFeed: Bool, before: Int, after: Int, reason: String?) {
        _ = applySatisfactionDecayIfNeeded(now: now)

        let before = satisfactionLevel
        guard before < AppState.fullnessMaxLevel else {
            return (false, before, before, "満腹度が最大のためご飯をあげられません")
        }

        let after = clampSatisfaction(before + 1)
        satisfactionLevel = after

        // ✅ 給餌した時点から30分カウントを再スタート
        satisfactionLastUpdatedAt = after > 0 ? now : nil

        return (true, before, after, nil)
    }

    @discardableResult
    func decreaseSatisfaction(by amount: Int, now: Date = Date()) -> Int {
        _ = applySatisfactionDecayIfNeeded(now: now)

        let dec = max(0, amount)
        guard dec > 0 else { return satisfactionLevel }

        satisfactionLevel = max(0, satisfactionLevel - dec)
        satisfactionLastUpdatedAt = satisfactionLevel > 0 ? now : nil
        return satisfactionLevel
    }
}

// MARK: - Care (Food / Bath / Toilet)
extension AppState {
    private static let careMinIntervalSeconds: TimeInterval = 60 * 60
    private static let careMaxIntervalSeconds: TimeInterval = 2 * 60 * 60
    private static let toiletBonusWindowSeconds: TimeInterval = 60 * 60

    private func randomCareInterval() -> TimeInterval {
        TimeInterval.random(in: AppState.careMinIntervalSeconds...AppState.careMaxIntervalSeconds)
    }

    // MARK: Food

    func ensureFoodNextSpawnScheduled(now: Date = Date()) {
        _ = applySatisfactionDecayIfNeeded(now: now)

        // ✅ 既存データや旧ロジックで foodFlag が残っていた場合、
        //    満腹度MAXならフラグを成立させない
        if foodFlagAt != nil, currentSatisfaction(now: now) >= AppState.fullnessMaxLevel {
            foodFlagAt = nil

            if let next = foodNextSpawnAt {
                if next <= now {
                    foodNextSpawnAt = now.addingTimeInterval(randomCareInterval())
                }
            } else {
                foodNextSpawnAt = now.addingTimeInterval(randomCareInterval())
            }
        }

        if foodNextSpawnAt == nil {
            foodNextSpawnAt = now.addingTimeInterval(randomCareInterval())
        }
    }

    func canRaiseFoodFlag(now: Date = Date()) -> Bool {
        if foodFlagAt != nil { return false }
        if currentSatisfaction(now: now) >= AppState.fullnessMaxLevel { return false }

        if let next = foodNextSpawnAt {
            return now >= next
        }

        return false
    }

    @discardableResult
    func raiseFoodFlag(now: Date = Date()) -> Bool {
        ensureDailyResetIfNeeded(now: now)
        ensureFoodNextSpawnScheduled(now: now)

        guard canRaiseFoodFlag(now: now) else { return false }

        foodFlagAt = now
        foodLastRaisedAt = now
        return true
    }

    @discardableResult
    func raiseFoodFlagIfNeeded(now: Date = Date()) -> Bool {
        raiseFoodFlag(now: now)
    }

    @discardableResult
    func resolveFood(now: Date = Date()) -> Bool {
        ensureDailyResetIfNeeded(now: now)

        guard foodFlagAt != nil else { return false }

        foodFlagAt = nil
        foodNextSpawnAt = now.addingTimeInterval(randomCareInterval())
        return true
    }

    // MARK: Bath

    var hasBathFlag: Bool {
        bathFlagAt != nil
    }

    func ensureBathNextSpawnScheduled(now: Date = Date()) {
        if bathNextSpawnAt == nil {
            bathNextSpawnAt = now.addingTimeInterval(randomCareInterval())
        }
    }

    func canRaiseBathFlag(now: Date = Date()) -> Bool {
        if bathFlagAt != nil { return false }

        if let next = bathNextSpawnAt {
            return now >= next
        }

        return false
    }

    @discardableResult
    func raiseBathFlag(now: Date = Date()) -> Bool {
        ensureDailyResetIfNeeded(now: now)
        ensureBathNextSpawnScheduled(now: now)

        guard canRaiseBathFlag(now: now) else { return false }

        bathFlagAt = now
        bathLastRaisedAt = now
        return true
    }

    @discardableResult
    func raiseBathFlagIfNeeded(now: Date = Date()) -> Bool {
        raiseBathFlag(now: now)
    }

    func resolveBath(now: Date = Date()) -> Bool {
        ensureDailyResetIfNeeded(now: now)

        guard bathFlagAt != nil else { return false }

        bathFlagAt = nil
        bathNextSpawnAt = now.addingTimeInterval(randomCareInterval())
        return true
    }

    // MARK: Toilet

    func ensureToiletNextSpawnScheduled(now: Date = Date()) {
        if toiletNextSpawnAt == nil {
            toiletNextSpawnAt = now.addingTimeInterval(randomCareInterval())
        }
    }

    func canRaiseToiletFlag(now: Date = Date()) -> Bool {
        if toiletFlagAt != nil { return false }

        if let next = toiletNextSpawnAt {
            return now >= next
        }

        return false
    }

    @discardableResult
    func raiseToiletFlag(now: Date = Date()) -> Bool {
        ensureDailyResetIfNeeded(now: now)
        ensureToiletNextSpawnScheduled(now: now)

        guard canRaiseToiletFlag(now: now) else { return false }

        let effectiveFlagAt: Date = {
            if let scheduledAt = toiletNextSpawnAt, scheduledAt <= now {
                return scheduledAt
            }
            return now
        }()

        toiletFlagAt = effectiveFlagAt
        toiletLastRaisedAt = effectiveFlagAt

        let elapsedSinceFlag = max(0, now.timeIntervalSince(effectiveFlagAt))
        let additionalCount = Int(elapsedSinceFlag / AppState.toiletPoopSpawnIntervalSeconds)
        let totalCount = min(
            AppState.toiletPoopMaxCount,
            AppState.toiletPoopInitialCount + additionalCount
        )

        let initialPoops = generateToiletPoops(count: totalCount)
        setToiletPoops(initialPoops)

        if totalCount >= AppState.toiletPoopMaxCount {
            toiletPoopLastSpawnAt = now
        } else {
            let restoredAdditionalCount = max(0, totalCount - AppState.toiletPoopInitialCount)
            toiletPoopLastSpawnAt = effectiveFlagAt.addingTimeInterval(
                TimeInterval(restoredAdditionalCount) * AppState.toiletPoopSpawnIntervalSeconds
            )
        }

        return true
    }

    @discardableResult
    func raiseToiletFlagIfNeeded(now: Date = Date()) -> Bool {
        raiseToiletFlag(now: now)
    }

    func resolveToilet(now: Date = Date()) -> (didResolve: Bool, isWithin1h: Bool) {
        ensureDailyResetIfNeeded(now: now)

        guard let flagAt = toiletFlagAt else {
            return (false, false)
        }

        let elapsed = now.timeIntervalSince(flagAt)
        let within = elapsed <= AppState.toiletBonusWindowSeconds

        toiletFlagAt = nil
        toiletNextSpawnAt = now.addingTimeInterval(randomCareInterval())
        toiletPoopsData = nil
        toiletPoopLastSpawnAt = nil
        return (true, within)
    }
}

// MARK: - Pets
extension AppState {
    static let initialZukanPetIDs: [String] = (0..<50).map { String(format: "pet_%03d", $0) }

    func ownedPetIDs() -> [String] {
        guard let data = ownedPetIDsData,
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return arr
    }

    func setOwnedPetIDs(_ ids: [String]) {
        ownedPetIDsData = try? JSONEncoder().encode(ids)
    }

    func ensureInitialPetsIfNeeded() {
        var ids = ownedPetIDs()
        if ids.isEmpty {
            ids = ["pet_000"]
            setOwnedPetIDs(ids)
            currentPetID = "pet_000"
            return
        }

        if !ids.contains(normalizedCurrentPetID) {
            currentPetID = ids.first ?? "pet_000"
        }
    }

    @discardableResult
    func acquireRandomPetIfPossible() -> String? {
        var owned = ownedPetIDs()
        let ownedSet = Set(owned)

        let candidates = AppState.initialZukanPetIDs.filter { !ownedSet.contains($0) }
        guard let picked = candidates.randomElement() else { return nil }

        owned.append(picked)
        setOwnedPetIDs(owned)
        return picked
    }

    func isValidZukanPetID(_ id: String) -> Bool {
        AppState.initialZukanPetIDs.contains(id)
    }
}
