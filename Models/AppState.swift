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
    // ✅ なかよし度メーター上限（0..(max-1)）
    static let friendshipMaxMeter: Int = 100

    // MARK: - Currency (kcal)
    var walletKcal: Int
    var pendingKcal: Int

    // MARK: - Health Sync
    var lastSyncedAt: Date?

    // MARK: - Goal
    var dailyGoalKcal: Int

    // 日跨ぎ判定用（yyyyMMdd）
    var lastDayKey: String

    // MARK: - Today Cache (Offline / Protect Zero)
    var cachedTodaySteps: Int
    var cachedTodayKcal: Int

    // ✅ なかよし度（0..99）＆カード
    var friendshipPoint: Int
    var friendshipCardCount: Int

    // MARK: - ✅ Satisfaction
    var satisfactionLevel: Int
    var satisfactionLastUpdatedAt: Date?

    // ✅ お風呂
    var bathFlagAt: Date?
    var bathLastRaisedAt: Date?
    var bathNextSpawnAt: Date?

    // ✅ トイレ
    var toiletFlagAt: Date?
    var toiletLastRaisedAt: Date?
    var toiletNextSpawnAt: Date?

    // ✅ 卵（ショップ）
    var eggOwned: Bool
    var eggHatchAt: Date?
    var eggAdUsedToday: Bool

    // ✅ デイリーショップ（MVP）
    var shopDayKey: String
    var shopItemsData: Data?
    var shopRewardResetsToday: Int

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

    // MARK: - ✅ Moja (NEW)
    var mojaCount: Int = 0
    var mojaFusionIsRunning: Bool = false
    var mojaFusionEndAt: Date? = nil

    // MARK: - Step Enjoy
    var stepEnjoyLastCheckedAt: Date? = nil
    var stepEnjoyTotalSteps: Int = 0
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
        dailyGoalKcal: Int = 0,
        lastDayKey: String = AppState.makeDayKey(Date()),

        cachedTodaySteps: Int = 0,
        cachedTodayKcal: Int = 0,

        friendshipPoint: Int = 0,
        friendshipCardCount: Int = 0,

        satisfactionLevel: Int = 0,
        satisfactionLastUpdatedAt: Date? = nil,

        bathFlagAt: Date? = nil,
        bathLastRaisedAt: Date? = nil,
        bathNextSpawnAt: Date? = nil,

        toiletFlagAt: Date? = nil,
        toiletLastRaisedAt: Date? = nil,
        toiletNextSpawnAt: Date? = nil,

        eggOwned: Bool = false,
        eggHatchAt: Date? = nil,
        eggAdUsedToday: Bool = false,

        shopDayKey: String = AppState.makeDayKey(Date()),
        shopItemsData: Data? = nil,
        shopRewardResetsToday: Int = 0,

        currentPetID: String = "pet_000",
        ownedPetIDsData: Data? = nil,

        notifyFeed: Bool = true,
        notifyBath: Bool = true,
        notifyToilet: Bool = true,

        ownedFoodCountsData: Data? = nil,

        superFavoriteRevealedData: Data? = nil,

        mojaCount: Int = 0,
        mojaFusionIsRunning: Bool = false,
        mojaFusionEndAt: Date? = nil,

        stepEnjoyLastCheckedAt: Date? = nil,
        stepEnjoyTotalSteps: Int = 0,
        stepEnjoyLastDeltaSteps: Int = 0,
        stepEnjoyLogsData: Data? = nil,
        stepEnjoyDailyCycleStart: Date = Date(),
        stepEnjoyDailyRewardCount: Int = 0,
        stepEnjoyDailyRewardStepBank: Int = 0,
        stepEnjoyLastRewardAt: Date? = nil
    ) {
        self.walletKcal = walletKcal
        self.pendingKcal = pendingKcal

        self.lastSyncedAt = lastSyncedAt

        self.dailyGoalKcal = dailyGoalKcal
        self.lastDayKey = lastDayKey

        self.cachedTodaySteps = cachedTodaySteps
        self.cachedTodayKcal = cachedTodayKcal

        self.friendshipPoint = friendshipPoint
        self.friendshipCardCount = friendshipCardCount

        self.satisfactionLevel = satisfactionLevel
        self.satisfactionLastUpdatedAt = satisfactionLastUpdatedAt

        self.bathFlagAt = bathFlagAt
        self.bathLastRaisedAt = bathLastRaisedAt
        self.bathNextSpawnAt = bathNextSpawnAt

        self.toiletFlagAt = toiletFlagAt
        self.toiletLastRaisedAt = toiletLastRaisedAt
        self.toiletNextSpawnAt = toiletNextSpawnAt

        self.eggOwned = eggOwned
        self.eggHatchAt = eggHatchAt
        self.eggAdUsedToday = eggAdUsedToday

        self.shopDayKey = shopDayKey
        self.shopItemsData = shopItemsData
        self.shopRewardResetsToday = shopRewardResetsToday

        self.currentPetID = currentPetID
        self.ownedPetIDsData = ownedPetIDsData

        self.notifyFeed = notifyFeed
        self.notifyBath = notifyBath
        self.notifyToilet = notifyToilet

        self.ownedFoodCountsData = ownedFoodCountsData

        self.superFavoriteRevealedData = superFavoriteRevealedData

        self.mojaCount = mojaCount
        self.mojaFusionIsRunning = mojaFusionIsRunning
        self.mojaFusionEndAt = mojaFusionEndAt

        self.stepEnjoyLastCheckedAt = stepEnjoyLastCheckedAt
        self.stepEnjoyTotalSteps = stepEnjoyTotalSteps
        self.stepEnjoyLastDeltaSteps = stepEnjoyLastDeltaSteps
        self.stepEnjoyLogsData = stepEnjoyLogsData
        self.stepEnjoyDailyCycleStart = stepEnjoyDailyCycleStart
        self.stepEnjoyDailyRewardCount = stepEnjoyDailyRewardCount
        self.stepEnjoyDailyRewardStepBank = stepEnjoyDailyRewardStepBank
        self.stepEnjoyLastRewardAt = stepEnjoyLastRewardAt
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

// MARK: - Widget Support
extension AppState {
    struct WidgetStateSnapshot: Equatable {
        let toiletFlag: Bool
        let bathFlag: Bool
        let currentPetID: String
        let todaySteps: Int

        // ✅ 追加：Widget側で未起動中の状態判定に使える時刻情報
        let toiletFlagAt: Date?
        let bathFlagAt: Date?
        let toiletNextSpawnAt: Date?
        let bathNextSpawnAt: Date?
        let lastDayKey: String
    }

    var hasToiletFlag: Bool {
        toiletFlagAt != nil
    }

    var normalizedCurrentPetID: String {
        let trimmed = currentPetID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "pet_000" : trimmed
    }

    /// ✅ Widget に渡す currentPetID は常に安全な値に正規化
    var widgetCurrentPetID: String {
        normalizedCurrentPetID
    }

    /// ✅ Widget に渡す歩数は負数を防ぎつつキャッシュ値を利用
    var widgetTodaySteps: Int {
        max(0, cachedTodaySteps)
    }

    /// ✅ 呼び出し側がより新しい歩数を持っている場合に上書き可能
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
    func drainPendingKcalToWallet() -> Int {
        let delta = max(0, pendingKcal)
        guard delta > 0 else { return 0 }
        walletKcal += delta
        pendingKcal = 0
        return delta
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
        for id in ids {
            if foodCount(foodId: id) > 0 { return id }
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

// MARK: - Day Reset
extension AppState {
    func ensureDailyResetIfNeeded(now: Date = Date()) {
        let todayKey = AppState.makeDayKey(now)
        guard lastDayKey != todayKey else { return }

        if satisfactionLastUpdatedAt == nil, satisfactionLevel > 0 {
            satisfactionLastUpdatedAt = now
        }

        // ✅ 発生中フラグ・次回予定時刻は日跨ぎでも維持
        lastDayKey = todayKey
    }
}

// MARK: - Today Cache helpers
extension AppState {
    struct CacheUpdateResult: Equatable {
        let stepsToUse: Int
        let kcalToUse: Int
        let didUpdateStepsCache: Bool
        let didUpdateKcalCache: Bool
    }

    func updateTodayCacheProtectingZero(
        fetchedSteps: Int,
        fetchedKcal: Int,
        todayKey: String
    ) -> CacheUpdateResult {
        if lastDayKey != todayKey {
            cachedTodaySteps = 0
            cachedTodayKcal = 0
        }

        let prevSteps = cachedTodaySteps
        let prevKcal = cachedTodayKcal

        let protectSteps = (fetchedSteps == 0 && prevSteps > 0)
        let protectKcal  = (fetchedKcal == 0 && prevKcal > 0)

        let stepsToUse = protectSteps ? prevSteps : fetchedSteps
        let kcalToUse  = protectKcal  ? prevKcal  : fetchedKcal

        var didUpdateStepsCache = false
        var didUpdateKcalCache = false

        if !protectSteps {
            cachedTodaySteps = stepsToUse
            didUpdateStepsCache = true
        }
        if !protectKcal {
            cachedTodayKcal = kcalToUse
            didUpdateKcalCache = true
        }

        return .init(
            stepsToUse: stepsToUse,
            kcalToUse: kcalToUse,
            didUpdateStepsCache: didUpdateStepsCache,
            didUpdateKcalCache: didUpdateKcalCache
        )
    }
}

// MARK: - Friendship
extension AppState {
    struct FriendshipGainResult: Equatable {
        let beforePoint: Int
        let afterPoint: Int
        let gainedCards: Int
        let didWrap: Bool
        let didReachMax: Bool
    }

    @discardableResult
    func addFriendship(points: Int, maxMeter: Int = AppState.friendshipMaxMeter) -> FriendshipGainResult {
        let before = friendshipPoint
        let gain = max(0, points)
        let total = friendshipPoint + gain
        let didReachMax = (before < maxMeter) && (total >= maxMeter)

        if total >= maxMeter {
            let cards = total / maxMeter
            friendshipCardCount += cards
            friendshipPoint = total % maxMeter

            return .init(
                beforePoint: before,
                afterPoint: friendshipPoint,
                gainedCards: cards,
                didWrap: true,
                didReachMax: didReachMax
            )
        } else {
            friendshipPoint = total
            return .init(
                beforePoint: before,
                afterPoint: friendshipPoint,
                gainedCards: 0,
                didWrap: false,
                didReachMax: didReachMax
            )
        }
    }
}

// MARK: - ✅ Satisfaction
extension AppState {
    private static let satisfactionDecayUnitSeconds: TimeInterval = 60 * 60
    private static let satisfactionMax: Int = 3

    private func clampSatisfaction(_ v: Int) -> Int {
        min(AppState.satisfactionMax, max(0, v))
    }

    private func computedSatisfaction(now: Date = Date()) -> (level: Int, effectiveLastUpdatedAt: Date?) {
        let current = clampSatisfaction(satisfactionLevel)

        guard current > 0 else {
            return (0, nil)
        }

        guard let last = satisfactionLastUpdatedAt else {
            return (current, nil)
        }

        let elapsed = now.timeIntervalSince(last)
        if elapsed <= 0 {
            return (current, last)
        }

        let steps = Int(floor(elapsed / AppState.satisfactionDecayUnitSeconds))
        if steps <= 0 {
            return (current, last)
        }

        let after = clampSatisfaction(current - steps)
        if after <= 0 {
            return (0, nil)
        }

        let advanced = TimeInterval(steps) * AppState.satisfactionDecayUnitSeconds
        let effLast = last.addingTimeInterval(advanced)

        return (after, effLast)
    }

    func currentSatisfaction(now: Date = Date()) -> Int {
        computedSatisfaction(now: now).level
    }

    func canFeedNow(now: Date = Date()) -> (can: Bool, reason: String?) {
        let level = computedSatisfaction(now: now).level
        if level >= AppState.satisfactionMax {
            return (false, "満足度が最大のためご飯をあげられません")
        }
        return (true, nil)
    }

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
            return AppState.satisfactionDecayUnitSeconds
        }

        let elapsed = max(0, now.timeIntervalSince(referenceDate))
        let remaining = AppState.satisfactionDecayUnitSeconds - elapsed
        return max(0, remaining)
    }

    @discardableResult
    func applySatisfactionDecayIfNeeded(now: Date = Date()) -> Int {
        ensureDailyResetIfNeeded(now: now)

        satisfactionLevel = clampSatisfaction(satisfactionLevel)

        guard satisfactionLevel > 0 else {
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

        if let eff = computed.effectiveLastUpdatedAt {
            satisfactionLastUpdatedAt = eff
        }

        return satisfactionLevel
    }

    @discardableResult
    func feedOnce(now: Date = Date()) -> (didFeed: Bool, before: Int, after: Int, reason: String?) {
        _ = applySatisfactionDecayIfNeeded(now: now)

        let before = satisfactionLevel
        guard before < AppState.satisfactionMax else {
            return (false, before, before, "満足度が最大のためご飯をあげられません")
        }

        let after = clampSatisfaction(before + 1)
        satisfactionLevel = after

        // ✅ 満足度 0 → 1 へ回復した瞬間を必ず新しい起点にする
        if before == 0 {
            satisfactionLastUpdatedAt = now
        } else if satisfactionLastUpdatedAt == nil {
            satisfactionLastUpdatedAt = now
        }

        return (true, before, after, nil)
    }

    @discardableResult
    func decreaseSatisfaction(by amount: Int, now: Date = Date()) -> Int {
        _ = applySatisfactionDecayIfNeeded(now: now)
        let dec = max(0, amount)
        guard dec > 0 else { return satisfactionLevel }

        satisfactionLevel = max(0, satisfactionLevel - dec)

        if satisfactionLevel == 0 {
            satisfactionLastUpdatedAt = nil
        } else if satisfactionLastUpdatedAt == nil {
            satisfactionLastUpdatedAt = now
        }

        return satisfactionLevel
    }
}

// MARK: - Care (Bath / Toilet)
extension AppState {
    private static let careMinIntervalSeconds: TimeInterval = 60 * 60
    private static let careMaxIntervalSeconds: TimeInterval = 2 * 60 * 60
    private static let toiletBonusWindowSeconds: TimeInterval = 60 * 60

    private func randomCareInterval() -> TimeInterval {
        TimeInterval.random(in: AppState.careMinIntervalSeconds...AppState.careMaxIntervalSeconds)
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

        toiletFlagAt = now
        toiletLastRaisedAt = now
        return true
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

// MARK: - ✅ Moja helpers
extension AppState {
    @discardableResult
    func addMoja(_ count: Int = 1) -> Bool {
        let add = max(0, count)
        guard add > 0 else { return false }
        mojaCount += add
        return true
    }

    @discardableResult
    func consumeMoja(_ count: Int = 1) -> Bool {
        let use = max(0, count)
        // ✅ 0個消費は成功扱い
        if use == 0 {
            return true
        }
        guard mojaCount >= use else { return false }
        mojaCount -= use
        return true
    }

    @discardableResult
    func startMojaFusion(cost: Int = 1, now: Date = Date()) -> Bool {
        guard mojaFusionIsRunning == false else { return false }
        guard consumeMoja(cost) else { return false }

        mojaFusionIsRunning = true
        mojaFusionEndAt = now.addingTimeInterval(6 * 60 * 60)
        return true
    }

    func mojaFusionRemainingSeconds(now: Date = Date()) -> TimeInterval? {
        guard mojaFusionIsRunning, let end = mojaFusionEndAt else { return nil }
        return max(0, end.timeIntervalSince(now))
    }

    @discardableResult
    func finalizeMojaFusionIfNeeded(now: Date = Date()) -> Bool {
        guard mojaFusionIsRunning, let end = mojaFusionEndAt else { return false }
        guard now >= end else { return false }

        mojaFusionIsRunning = false
        mojaFusionEndAt = nil
        return true
    }

    func reduceMojaFusion(seconds: TimeInterval) {
        guard mojaFusionIsRunning, let end = mojaFusionEndAt else { return }
        let reduce = max(0, seconds)
        guard reduce > 0 else { return }
        mojaFusionEndAt = end.addingTimeInterval(-reduce)
    }
}
