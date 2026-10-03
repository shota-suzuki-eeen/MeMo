//
//  AppState+Happiness.swift
//  MeMo
//
//  Safe version: does not add stored properties to SwiftData @Model.
//  Happiness state is stored in UserDefaults to avoid breaking existing model data.
//

import Foundation

private enum HappinessNotificationName {
    static let heartDidAppear = Notification.Name("BGMManager.happinessHeartDidAppearNotification")
}

extension AppState {
    static let happinessMaxPointsPerLevel: Int = 100
    static let happinessMaxLevel: Int = 75
    static let happinessTouchesPerPoint: Int = 5
    static let happinessDailyPettingPointLimit: Int = 100
    static let happinessDecayIntervalSeconds: TimeInterval = 5 * 60
    static let happinessRewardLevelStep: Int = 5
    static let happinessSleepModeDurationSeconds: TimeInterval = 8 * 60 * 60

    struct HappinessRewardDefinition: Identifiable, Equatable {
        enum Reward: Equatable {
            case character(petID: String)
            case ticket(itemID: String, count: Int)
            case gachaMachine(machineID: String)
        }

        let level: Int
        let reward: Reward
        let assetName: String
        let displayName: String

        var id: Int { level }

        init(level: Int, reward: Reward, assetName: String, displayName: String) {
            self.level = level
            self.reward = reward
            self.assetName = assetName
            self.displayName = displayName
        }

        init(level: Int, petID: String, assetName: String, characterName: String) {
            self.init(
                level: level,
                reward: .character(petID: petID),
                assetName: assetName,
                displayName: characterName
            )
        }
    }

    /// 通常の幸せ度メーター用のV2報酬ラインナップ。
    /// 既存参照互換のため `happinessRewardDefinitions` も同じ値を返す。
    static let standardHappinessRewardDefinitions: [HappinessRewardDefinition] = [
        .init(level: 5, reward: .ticket(itemID: "gachaTicket_nomal", count: 10), assetName: "gachaTicket_nomal", displayName: "ガチャチケット ×10"),
        .init(level: 10, reward: .ticket(itemID: "gachaTicket_special", count: 1), assetName: "gachaTicket_special", displayName: "キャラ確定ガチャチケット ×1"),
        .init(level: 15, reward: .gachaMachine(machineID: "food"), assetName: "gatyaMachine_food", displayName: "フードガチャ解放"),
        .init(level: 20, reward: .ticket(itemID: "gachaTicket_nomal", count: 10), assetName: "gachaTicket_nomal", displayName: "ガチャチケット ×10"),
        .init(level: 25, reward: .ticket(itemID: "gachaTicket_special", count: 1), assetName: "gachaTicket_special", displayName: "キャラ確定ガチャチケット ×1"),
        .init(level: 30, reward: .gachaMachine(machineID: "moja"), assetName: "gatyaMachine_moja", displayName: "もじゃガチャ解放"),
        .init(level: 35, reward: .ticket(itemID: "gachaTicket_nomal", count: 10), assetName: "gachaTicket_nomal", displayName: "ガチャチケット ×10"),
        .init(level: 40, reward: .ticket(itemID: "gachaTicket_special", count: 1), assetName: "gachaTicket_special", displayName: "キャラ確定ガチャチケット ×1"),
        .init(level: 45, reward: .gachaMachine(machineID: "streetAnimals"), assetName: "gatyaMachine_streetAnimals", displayName: "ストリートアニマルズ解放"),
        .init(level: 50, reward: .ticket(itemID: "gachaTicket_nomal", count: 10), assetName: "gachaTicket_nomal", displayName: "ガチャチケット ×10"),
        .init(level: 55, reward: .ticket(itemID: "gachaTicket_special", count: 1), assetName: "gachaTicket_special", displayName: "キャラ確定ガチャチケット ×1"),
        .init(level: 60, reward: .gachaMachine(machineID: "cyberpunkRacers"), assetName: "gatyaMachine_cyberpunkRacers", displayName: "サイバーパンクレーサーズ解放"),
        .init(level: 65, reward: .ticket(itemID: "gachaTicket_nomal", count: 10), assetName: "gachaTicket_nomal", displayName: "ガチャチケット ×10"),
        .init(level: 70, reward: .ticket(itemID: "gachaTicket_special", count: 1), assetName: "gachaTicket_special", displayName: "キャラ確定ガチャチケット ×1"),
        .init(level: 75, reward: .gachaMachine(machineID: "hyakkaryouran"), assetName: "gatyaMachine_hyakkaryouran", displayName: "百花繚乱解放")
    ]

    static let happinessRewardDefinitions: [HappinessRewardDefinition] = standardHappinessRewardDefinitions

    /// 報酬キャラクターお世話中だけ表示する、そのキャラクター専用の幸せ報酬ラインナップ。
    /// キーは「現在お世話中の報酬キャラクターID」。
    private static let happinessRewardDefinitionsByCarePetID: [String: [HappinessRewardDefinition]] = [
        "reward_000": [
            .init(level: 10, petID: "reward_000_casual", assetName: "girl_A_casual", characterName: "ガール / カジュアル（A）")
        ],
        "reward_001": [
            .init(level: 10, petID: "reward_001_casual", assetName: "boy_A_casual", characterName: "ボーイ / カジュアル（A）")
        ],
        "reward_002": [
            .init(level: 10, petID: "reward_002_casual", assetName: "girl_B_casual", characterName: "ガール / カジュアル（B）")
        ],
        "reward_003": [
            .init(level: 10, petID: "reward_003_casual", assetName: "boy_B_casual", characterName: "ボーイ / カジュアル（B）")
        ],
        "reward_004": [
            .init(level: 10, petID: "reward_004_casual", assetName: "girl_C_casual", characterName: "ガール / カジュアル（C）")
        ],
        "reward_005": [
            .init(level: 10, petID: "reward_005_casual", assetName: "boy_C_casual", characterName: "ボーイ / カジュアル（C）")
        ],
        "reward_006": [
            .init(level: 10, petID: "reward_006_casual", assetName: "girl_D_casual", characterName: "ガール / カジュアル（D）")
        ],
        "reward_007": [
            .init(level: 10, petID: "reward_007_casual", assetName: "boy_D_casual", characterName: "ボーイ / カジュアル（D）")
        ]
    ]

    struct HappinessGainResult: Equatable {
        let beforePoint: Int
        let beforeLevel: Int
        let afterPoint: Int
        let afterLevel: Int
        let gainedPoints: Int
    }

    struct HappinessPettingResult: Equatable {
        let gainedPoints: Int
        let afterTouchCount: Int
        let afterTodayPoints: Int
        let afterPoint: Int
        let afterLevel: Int
        let reachedDailyLimit: Bool
    }

    struct HappinessRewardClaimResult: Equatable {
        let level: Int
        let reward: HappinessRewardDefinition.Reward
        let assetName: String
        let displayName: String
    }

    private enum HappinessStorageKeys {
        static let point = "memo.happiness.point"
        static let level = "memo.happiness.level"
        static let reachedCheckpointLevel = "memo.happiness.reachedCheckpointLevel.v1"
        static let lastDecayAt = "memo.happiness.lastDecayAt"
        static let pettingTouchCountToday = "memo.happiness.petting.touchCountToday"
        static let pettingPointsToday = "memo.happiness.petting.pointsToday"
        static let pettingDayKey = "memo.happiness.petting.dayKey"
        static let claimedRewardLevels = "memo.happiness.claimedRewardLevels"
        static let standardV2ClaimedRewardLevels = "memo.happiness.standardRewardV2.claimedLevels"
        static let sleepModeEndsAt = "memo.happiness.sleepMode.endsAt"
    }

    private static let happinessStandardStorageContextKey = "standard"

    private static var happinessAllStorageContextKeys: [String] {
        [happinessStandardStorageContextKey] + PetMaster.happinessRewardPetIDs
    }

    private var happinessDefaults: UserDefaults {
        .standard
    }

    private var happinessStorageContextKey: String {
        let petID = normalizedCurrentPetID
        if let meterOwnerPetID = PetMaster.happinessMeterOwnerPetID(for: petID) {
            return meterOwnerPetID
        }
        return AppState.happinessStandardStorageContextKey
    }

    private func happinessStorageKey(_ key: String, context: String) -> String {
        if context == AppState.happinessStandardStorageContextKey {
            return key
        }
        return "\(key).\(context)"
    }

    private func happinessStorageKey(_ key: String) -> String {
        happinessStorageKey(key, context: happinessStorageContextKey)
    }

    private var happinessSleepModeStorageKey: String {
        HappinessStorageKeys.sleepModeEndsAt
    }

    private var legacyHappinessSleepModeStorageKeys: [String] {
        AppState.happinessAllStorageContextKeys
            .map { happinessStorageKey(HappinessStorageKeys.sleepModeEndsAt, context: $0) }
            .filter { $0 != happinessSleepModeStorageKey }
    }

    private func migrateLegacyHappinessSleepModeEndIfNeeded() -> Date? {
        var candidates: [Date] = []

        if let globalValue = happinessDefaults.object(forKey: happinessSleepModeStorageKey) as? Date {
            candidates.append(globalValue)
        }

        for key in legacyHappinessSleepModeStorageKeys {
            if let legacyValue = happinessDefaults.object(forKey: key) as? Date {
                candidates.append(legacyValue)
            }
        }

        for key in legacyHappinessSleepModeStorageKeys {
            happinessDefaults.removeObject(forKey: key)
        }

        guard let latestValue = candidates.max() else { return nil }
        happinessDefaults.set(latestValue, forKey: happinessSleepModeStorageKey)
        return latestValue
    }

    private func advanceHappinessLastDecayAtForAllContexts(to lowerBound: Date) {
        for context in AppState.happinessAllStorageContextKeys {
            let key = happinessStorageKey(HappinessStorageKeys.lastDecayAt, context: context)
            if let currentValue = happinessDefaults.object(forKey: key) as? Date {
                if currentValue < lowerBound {
                    happinessDefaults.set(lowerBound, forKey: key)
                }
            } else {
                happinessDefaults.set(lowerBound, forKey: key)
            }
        }
    }

    func currentHappinessRewardDefinitions() -> [HappinessRewardDefinition] {
        let petID = normalizedCurrentPetID
        if let meterOwnerPetID = PetMaster.happinessMeterOwnerPetID(for: petID),
           let rewards = AppState.happinessRewardDefinitionsByCarePetID[meterOwnerPetID] {
            return rewards
        }
        return AppState.standardHappinessRewardDefinitions
    }

    private func syncHappinessPettingDayKeyIfNeeded(now: Date = Date()) {
        let todayKey = AppState.makeDayKey(now)
        guard happinessPettingDayKey != todayKey else { return }

        happinessPettingDayKey = todayKey
        happinessDefaults.set(0, forKey: happinessStorageKey(HappinessStorageKeys.pettingTouchCountToday))
        happinessDefaults.set(0, forKey: happinessStorageKey(HappinessStorageKeys.pettingPointsToday))
    }

    /// Initialize old data from its current level, then retain the highest five-level
    /// checkpoint in the existing meter context. Reading never grants a reward.
    private func reconcileHappinessCheckpoint() -> (level: Int, point: Int, checkpoint: Int) {
        let levelKey = happinessStorageKey(HappinessStorageKeys.level)
        let pointKey = happinessStorageKey(HappinessStorageKeys.point)
        let checkpointKey = happinessStorageKey(HappinessStorageKeys.reachedCheckpointLevel)
        let storedLevel = happinessDefaults.integer(forKey: levelKey)
        let storedPoint = happinessDefaults.integer(forKey: pointKey)
        let level = min(AppState.happinessMaxLevel, max(0, storedLevel))
        let point = min(AppState.happinessMaxPointsPerLevel - 1, max(0, storedPoint))
        let storedCheckpoint = happinessDefaults.integer(forKey: checkpointKey)
        let safeCheckpoint = min(AppState.happinessMaxLevel, max(0, storedCheckpoint))
            / AppState.happinessRewardLevelStep * AppState.happinessRewardLevelStep
        let reachedCheckpoint = level / AppState.happinessRewardLevelStep * AppState.happinessRewardLevelStep
        let checkpoint = max(safeCheckpoint, reachedCheckpoint)
        let resolvedLevel = max(level, checkpoint)
        let resolvedPoint = level < checkpoint ? 0 : point

        if happinessDefaults.object(forKey: checkpointKey) == nil || storedCheckpoint != checkpoint {
            happinessDefaults.set(checkpoint, forKey: checkpointKey)
        }
        if storedLevel != resolvedLevel {
            happinessDefaults.set(resolvedLevel, forKey: levelKey)
        }
        if storedPoint != resolvedPoint {
            happinessDefaults.set(resolvedPoint, forKey: pointKey)
        }
        return (resolvedLevel, resolvedPoint, checkpoint)
    }

    var happinessCheckpointLevel: Int {
        reconcileHappinessCheckpoint().checkpoint
    }

    private var happinessUnitsAboveCheckpoint: Int {
        let value = reconcileHappinessCheckpoint()
        return (value.level - value.checkpoint) * AppState.happinessMaxPointsPerLevel + value.point
    }

    var happinessPoint: Int {
        get { reconcileHappinessCheckpoint().point }
        set {
            _ = reconcileHappinessCheckpoint()
            happinessDefaults.set(
                min(AppState.happinessMaxPointsPerLevel - 1, max(0, newValue)),
                forKey: happinessStorageKey(HappinessStorageKeys.point)
            )
        }
    }

    var happinessLevel: Int {
        get { reconcileHappinessCheckpoint().level }
        set {
            let checkpoint = happinessCheckpointLevel
            let requestedLevel = min(AppState.happinessMaxLevel, max(0, newValue))
            happinessDefaults.set(
                max(checkpoint, requestedLevel),
                forKey: happinessStorageKey(HappinessStorageKeys.level)
            )
            if requestedLevel < checkpoint {
                happinessDefaults.set(0, forKey: happinessStorageKey(HappinessStorageKeys.point))
            }
            _ = reconcileHappinessCheckpoint()
        }
    }

    var happinessLastDecayAt: Date? {
        get { happinessDefaults.object(forKey: happinessStorageKey(HappinessStorageKeys.lastDecayAt)) as? Date }
        set {
            let key = happinessStorageKey(HappinessStorageKeys.lastDecayAt)
            if let newValue {
                happinessDefaults.set(newValue, forKey: key)
            } else {
                happinessDefaults.removeObject(forKey: key)
            }
        }
    }

    var happinessSleepModeEndsAt: Date? {
        get { migrateLegacyHappinessSleepModeEndIfNeeded() }
        set {
            if let newValue {
                happinessDefaults.set(newValue, forKey: happinessSleepModeStorageKey)
            } else {
                happinessDefaults.removeObject(forKey: happinessSleepModeStorageKey)
            }

            for key in legacyHappinessSleepModeStorageKeys {
                happinessDefaults.removeObject(forKey: key)
            }
        }
    }

    var happinessPettingTouchCountToday: Int {
        get {
            syncHappinessPettingDayKeyIfNeeded()
            return max(
                0,
                happinessDefaults.integer(forKey: happinessStorageKey(HappinessStorageKeys.pettingTouchCountToday))
            )
        }
        set {
            happinessDefaults.set(
                max(0, newValue),
                forKey: happinessStorageKey(HappinessStorageKeys.pettingTouchCountToday)
            )
        }
    }

    var happinessPettingPointsToday: Int {
        get {
            syncHappinessPettingDayKeyIfNeeded()
            return min(
                AppState.happinessDailyPettingPointLimit,
                max(0, happinessDefaults.integer(forKey: happinessStorageKey(HappinessStorageKeys.pettingPointsToday)))
            )
        }
        set {
            happinessDefaults.set(
                min(AppState.happinessDailyPettingPointLimit, max(0, newValue)),
                forKey: happinessStorageKey(HappinessStorageKeys.pettingPointsToday)
            )
        }
    }

    private var happinessPettingDayKey: String {
        get { happinessDefaults.string(forKey: happinessStorageKey(HappinessStorageKeys.pettingDayKey)) ?? "" }
        set { happinessDefaults.set(newValue, forKey: happinessStorageKey(HappinessStorageKeys.pettingDayKey)) }
    }

    func resetHappinessPettingIfNeeded(now: Date = Date()) {
        syncHappinessPettingDayKeyIfNeeded(now: now)
    }

    private func claimedHappinessRewardLevels() -> Set<Int> {
        let key = happinessStorageContextKey == AppState.happinessStandardStorageContextKey
            ? HappinessStorageKeys.standardV2ClaimedRewardLevels
            : happinessStorageKey(HappinessStorageKeys.claimedRewardLevels)
        guard let data = happinessDefaults.data(forKey: key),
              let values = try? JSONDecoder().decode([Int].self, from: data) else {
            return repairedStandardV2HappinessRewardLevels(from: [])
        }
        return repairedStandardV2HappinessRewardLevels(from: Set(values))
    }

    private func setClaimedHappinessRewardLevels(_ levels: Set<Int>) {
        let sorted = levels.sorted()
        let data = try? JSONEncoder().encode(sorted)
        let key = happinessStorageContextKey == AppState.happinessStandardStorageContextKey
            ? HappinessStorageKeys.standardV2ClaimedRewardLevels
            : happinessStorageKey(HappinessStorageKeys.claimedRewardLevels)
        happinessDefaults.set(data, forKey: key)
    }

    private func standardV2TicketApplicationID(level: Int) -> String {
        "memo.happiness.standardRewardV2.ticketApplied.level.\(level)"
    }

    /// Reconciles the two additive V2 stores after an interrupted claim.
    /// Legacy care-pet reward contexts intentionally bypass this repair path.
    private func repairedStandardV2HappinessRewardLevels(from storedLevels: Set<Int>) -> Set<Int> {
        guard happinessStorageContextKey == AppState.happinessStandardStorageContextKey else {
            return storedLevels
        }

        var repairedLevels = storedLevels

        for definition in AppState.standardHappinessRewardDefinitions {
            switch definition.reward {
            case .character:
                continue
            case .ticket(let itemID, let count):
                let applicationID = standardV2TicketApplicationID(level: definition.level)
                let isClaimed = repairedLevels.contains(definition.level)
                let isApplied = gachaHasSpecialItemRewardApplication(applicationID: applicationID)
                guard isClaimed || isApplied else { continue }

                if gachaApplySpecialItemRewardOnce(
                    id: itemID,
                    count: count,
                    applicationID: applicationID
                ) {
                    repairedLevels.insert(definition.level)
                }
            case .gachaMachine(let machineID):
                let isClaimed = repairedLevels.contains(definition.level)
                let isUnlocked = gachaIsMachineUnlocked(id: machineID)
                guard isClaimed || isUnlocked else { continue }

                if gachaUnlockMachine(id: machineID) {
                    repairedLevels.insert(definition.level)
                }
            }
        }

        if repairedLevels != storedLevels {
            setClaimedHappinessRewardLevels(repairedLevels)
        }
        return repairedLevels
    }

    @discardableResult
    private func activeHappinessSleepModeEnd(now: Date = Date()) -> Date? {
        guard let endsAt = happinessSleepModeEndsAt else { return nil }

        if endsAt > now {
            advanceHappinessLastDecayAtForAllContexts(to: endsAt)
            return endsAt
        }

        happinessSleepModeEndsAt = nil
        advanceHappinessLastDecayAtForAllContexts(to: endsAt)
        return nil
    }

    func isHappinessSleepModeActive(now: Date = Date()) -> Bool {
        activeHappinessSleepModeEnd(now: now) != nil
    }

    func happinessSleepModeRemainingSeconds(now: Date = Date()) -> TimeInterval {
        guard let endsAt = activeHappinessSleepModeEnd(now: now) else { return 0 }
        return max(0, endsAt.timeIntervalSince(now))
    }

    @discardableResult
    func activateHappinessSleepMode(
        now: Date = Date(),
        duration: TimeInterval = AppState.happinessSleepModeDurationSeconds
    ) -> Date {
        let safeDuration = max(0, duration)
        let requestedEnd = now.addingTimeInterval(safeDuration)
        let existingActiveEnd = activeHappinessSleepModeEnd(now: now)
        let nextEnd = Swift.max(existingActiveEnd ?? requestedEnd, requestedEnd)

        happinessSleepModeEndsAt = nextEnd

        // おやすみモード中の低下分を終了後にまとめて発生させないため、
        // 全幸せ度コンテキストの次の低下判定の基準時刻を終了時刻に進めておく。
        advanceHappinessLastDecayAtForAllContexts(to: nextEnd)
        return nextEnd
    }

    func claimedHappinessRewardLevelsSnapshot() -> Set<Int> {
        claimedHappinessRewardLevels()
    }

    func isHappinessRewardClaimed(level: Int) -> Bool {
        claimedHappinessRewardLevels().contains(level)
    }

    func happinessRewardDefinition(for level: Int) -> HappinessRewardDefinition? {
        currentHappinessRewardDefinitions().first(where: { $0.level == level })
    }

    private func happinessTotalUnits(level: Int, point: Int) -> Int {
        let safeLevel = min(AppState.happinessMaxLevel, max(0, level))
        let safePoint = min(AppState.happinessMaxPointsPerLevel - 1, max(0, point))
        return (safeLevel * AppState.happinessMaxPointsPerLevel) + safePoint
    }

    private func increaseHappinessOnePoint() {
        if happinessLevel >= AppState.happinessMaxLevel {
            happinessLevel = AppState.happinessMaxLevel
            happinessPoint = min(AppState.happinessMaxPointsPerLevel - 1, happinessPoint + 1)
            return
        }

        let next = happinessPoint + 1
        if next >= AppState.happinessMaxPointsPerLevel {
            happinessPoint = 0
            happinessLevel = min(AppState.happinessMaxLevel, happinessLevel + 1)
        } else {
            happinessPoint = next
        }
    }

    private func decreaseHappinessOnePoint() {
        if happinessPoint > 0 {
            happinessPoint -= 1
            return
        }

        guard happinessLevel > happinessCheckpointLevel else {
            happinessPoint = 0
            return
        }

        happinessLevel -= 1
        happinessPoint = AppState.happinessMaxPointsPerLevel - 1
    }

    @discardableResult
    func addHappinessPoints(_ points: Int, now: Date = Date()) -> HappinessGainResult {
        resetHappinessPettingIfNeeded(now: now)

        let safePoints = max(0, points)
        let beforePoint = happinessPoint
        let beforeLevel = happinessLevel
        let beforeUnits = happinessTotalUnits(level: beforeLevel, point: beforePoint)

        guard safePoints > 0 else {
            return .init(
                beforePoint: beforePoint,
                beforeLevel: beforeLevel,
                afterPoint: happinessPoint,
                afterLevel: happinessLevel,
                gainedPoints: 0
            )
        }

        for _ in 0..<safePoints {
            let previousLevel = happinessLevel
            let previousPoint = happinessPoint
            increaseHappinessOnePoint()

            if previousLevel == happinessLevel,
               previousPoint == happinessPoint,
               happinessLevel >= AppState.happinessMaxLevel,
               happinessPoint >= AppState.happinessMaxPointsPerLevel - 1 {
                break
            }
        }

        let afterUnits = happinessTotalUnits(level: happinessLevel, point: happinessPoint)
        let actualGainedPoints = max(0, afterUnits - beforeUnits)

        return .init(
            beforePoint: beforePoint,
            beforeLevel: beforeLevel,
            afterPoint: happinessPoint,
            afterLevel: happinessLevel,
            gainedPoints: actualGainedPoints
        )
    }

    @discardableResult
    func registerHappinessPettingTouch(count: Int = 1, now: Date = Date()) -> HappinessPettingResult {
        resetHappinessPettingIfNeeded(now: now)

        let safeCount = max(0, count)
        let availablePoints = max(0, AppState.happinessDailyPettingPointLimit - happinessPettingPointsToday)

        guard safeCount > 0, availablePoints > 0 else {
            happinessPettingTouchCountToday = 0
            return .init(
                gainedPoints: 0,
                afterTouchCount: happinessPettingTouchCountToday,
                afterTodayPoints: happinessPettingPointsToday,
                afterPoint: happinessPoint,
                afterLevel: happinessLevel,
                reachedDailyLimit: happinessPettingPointsToday >= AppState.happinessDailyPettingPointLimit
            )
        }

        let totalTouchCount = happinessPettingTouchCountToday + safeCount
        let requestedPoints = min(availablePoints, totalTouchCount / AppState.happinessTouchesPerPoint)

        for _ in 0..<safeCount {
            NotificationCenter.default.post(name: HappinessNotificationName.heartDidAppear, object: nil)
        }

        var actualGainedPoints = 0
        if requestedPoints > 0 {
            let gainResult = addHappinessPoints(requestedPoints, now: now)
            actualGainedPoints = gainResult.gainedPoints
            happinessPettingPointsToday += actualGainedPoints
        }

        if happinessPettingPointsToday >= AppState.happinessDailyPettingPointLimit {
            happinessPettingTouchCountToday = 0
        } else {
            happinessPettingTouchCountToday = totalTouchCount % AppState.happinessTouchesPerPoint
        }

        return .init(
            gainedPoints: actualGainedPoints,
            afterTouchCount: happinessPettingTouchCountToday,
            afterTodayPoints: happinessPettingPointsToday,
            afterPoint: happinessPoint,
            afterLevel: happinessLevel,
            reachedDailyLimit: happinessPettingPointsToday >= AppState.happinessDailyPettingPointLimit
        )
    }

    func refreshHappinessDecayTracking(fullnessLevel: Int, now: Date = Date()) {
        if let sleepModeEnd = activeHappinessSleepModeEnd(now: now) {
            happinessLastDecayAt = sleepModeEnd
            return
        }

        if fullnessLevel > 0 {
            happinessLastDecayAt = now
            return
        }

        if happinessLastDecayAt == nil {
            happinessLastDecayAt = now
        }

        if happinessUnitsAboveCheckpoint == 0 {
            happinessLastDecayAt = now
        }
    }

    func pendingHappinessDecayCount(fullnessLevel: Int, now: Date = Date()) -> Int {
        resetHappinessPettingIfNeeded(now: now)

        if let sleepModeEnd = activeHappinessSleepModeEnd(now: now) {
            happinessLastDecayAt = sleepModeEnd
            return 0
        }

        guard fullnessLevel <= 0 else { return 0 }
        let availableUnits = happinessUnitsAboveCheckpoint
        guard availableUnits > 0 else {
            happinessLastDecayAt = now
            return 0
        }
        guard let anchor = happinessLastDecayAt else { return 0 }
        let elapsed = now.timeIntervalSince(anchor)
        guard elapsed >= AppState.happinessDecayIntervalSeconds else { return 0 }
        // Bound before converting to Int: very old dates (including +infinity)
        // cannot overflow or queue work below the attained checkpoint.
        if elapsed >= Double(availableUnits) * AppState.happinessDecayIntervalSeconds {
            return availableUnits
        }
        return Int(elapsed / AppState.happinessDecayIntervalSeconds)
    }

    @discardableResult
    func consumeOneHappinessDecayStep(now: Date = Date()) -> Bool {
        if isHappinessSleepModeActive(now: now) {
            return false
        }

        guard happinessUnitsAboveCheckpoint > 0 else {
            happinessLastDecayAt = now
            return false
        }
        decreaseHappinessOnePoint()

        if happinessUnitsAboveCheckpoint == 0 {
            happinessLastDecayAt = now
        } else if let anchor = happinessLastDecayAt {
            happinessLastDecayAt = anchor.addingTimeInterval(AppState.happinessDecayIntervalSeconds)
        } else {
            happinessLastDecayAt = now
        }
        return true
    }

    func nextClaimableHappinessRewardLevel() -> Int? {
        let claimed = claimedHappinessRewardLevels()

        for reward in currentHappinessRewardDefinitions() {
            if happinessLevel >= reward.level, !claimed.contains(reward.level) {
                return reward.level
            }
        }
        return nil
    }

    func nextUpcomingHappinessRewardLevel() -> Int? {
        let claimed = claimedHappinessRewardLevels()

        for reward in currentHappinessRewardDefinitions() {
            if !claimed.contains(reward.level), happinessLevel < reward.level {
                return reward.level
            }
        }
        return nil
    }

    private var happinessRewardRareFoodIDs: [String] {
        [
            "matsuzakaBeef",
            "spinyLobster",
            "shineMuscat",
            "eel",
            "snowCrab",
            "otoro",
            "cantaloupe",
            "matsutake"
        ]
    }

    func happinessBonusPoints(forFoodID foodID: String) -> Int {
        happinessRewardRareFoodIDs.contains(foodID) ? 10 : 0
    }

    func claimHappinessReward(level: Int, now: Date = Date()) -> HappinessRewardClaimResult? {
        resetHappinessPettingIfNeeded(now: now)

        guard let reward = happinessRewardDefinition(for: level),
              level > 0,
              happinessLevel >= level else {
            return nil
        }

        var claimed = claimedHappinessRewardLevels()
        guard !claimed.contains(level) else { return nil }

        switch reward.reward {
        case .character(let petID):
            // Preserve the existing Legacy reward write order and ownership behavior.
            claimed.insert(level)
            setClaimedHappinessRewardLevels(claimed)

            if PetMaster.all.contains(where: { $0.id == petID }) {
                var owned = ownedPetIDs()
                if !owned.contains(petID) {
                    owned.append(petID)
                    setOwnedPetIDs(owned)
                }
            }
        case .ticket(let itemID, let count):
            let applicationID = standardV2TicketApplicationID(level: level)
            guard gachaApplySpecialItemRewardOnce(
                id: itemID,
                count: count,
                applicationID: applicationID
            ) else {
                return nil
            }

            claimed.insert(level)
            setClaimedHappinessRewardLevels(claimed)
        case .gachaMachine(let machineID):
            guard gachaUnlockMachine(id: machineID) else { return nil }

            claimed.insert(level)
            setClaimedHappinessRewardLevels(claimed)
        }

        return .init(
            level: level,
            reward: reward.reward,
            assetName: reward.assetName,
            displayName: reward.displayName
        )
    }
}
