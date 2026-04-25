//
//  AppState+Happiness.swift
//  MeMo
//
//  Safe version: does not add stored properties to SwiftData @Model.
//  Happiness state is stored in UserDefaults to avoid breaking existing model data.
//

import Foundation

extension AppState {
    static let happinessMaxPointsPerLevel: Int = 100
    static let happinessMaxLevel: Int = 20
    static let happinessTouchesPerPoint: Int = 5
    static let happinessDailyPettingPointLimit: Int = 100
    static let happinessDecayIntervalSeconds: TimeInterval = 5 * 60
    static let happinessRewardLevelStep: Int = 5

    struct HappinessRewardDefinition: Identifiable, Equatable {
        let level: Int
        let petID: String
        let assetName: String
        let characterName: String

        var id: Int { level }
    }

    static let happinessRewardDefinitions: [HappinessRewardDefinition] = [
        .init(level: 5, petID: "reward_000", assetName: "person_room", characterName: "部屋着"),
        .init(level: 10, petID: "reward_001", assetName: "person_chef", characterName: "シェフ"),
        .init(level: 15, petID: "reward_002", assetName: "girl_onePiece", characterName: "ワンピース"),
        .init(level: 20, petID: "reward_003", assetName: "person_skate", characterName: "スケボー")
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
        let petID: String
        let assetName: String
        let characterName: String
    }

    private enum HappinessStorageKeys {
        static let point = "memo.happiness.point"
        static let level = "memo.happiness.level"
        static let lastDecayAt = "memo.happiness.lastDecayAt"
        static let pettingTouchCountToday = "memo.happiness.petting.touchCountToday"
        static let pettingPointsToday = "memo.happiness.petting.pointsToday"
        static let pettingDayKey = "memo.happiness.petting.dayKey"
        static let claimedRewardLevels = "memo.happiness.claimedRewardLevels"
    }

    private var happinessDefaults: UserDefaults {
        .standard
    }

    private func syncHappinessPettingDayKeyIfNeeded(now: Date = Date()) {
        let todayKey = AppState.makeDayKey(now)
        guard happinessPettingDayKey != todayKey else { return }

        happinessPettingDayKey = todayKey
        happinessDefaults.set(0, forKey: HappinessStorageKeys.pettingTouchCountToday)
        happinessDefaults.set(0, forKey: HappinessStorageKeys.pettingPointsToday)
    }

    var happinessPoint: Int {
        get {
            min(AppState.happinessMaxPointsPerLevel - 1, max(0, happinessDefaults.integer(forKey: HappinessStorageKeys.point)))
        }
        set {
            happinessDefaults.set(
                min(AppState.happinessMaxPointsPerLevel - 1, max(0, newValue)),
                forKey: HappinessStorageKeys.point
            )
        }
    }

    var happinessLevel: Int {
        get {
            min(AppState.happinessMaxLevel, max(0, happinessDefaults.integer(forKey: HappinessStorageKeys.level)))
        }
        set {
            happinessDefaults.set(
                min(AppState.happinessMaxLevel, max(0, newValue)),
                forKey: HappinessStorageKeys.level
            )
        }
    }

    var happinessLastDecayAt: Date? {
        get { happinessDefaults.object(forKey: HappinessStorageKeys.lastDecayAt) as? Date }
        set {
            if let newValue {
                happinessDefaults.set(newValue, forKey: HappinessStorageKeys.lastDecayAt)
            } else {
                happinessDefaults.removeObject(forKey: HappinessStorageKeys.lastDecayAt)
            }
        }
    }

    var happinessPettingTouchCountToday: Int {
        get {
            syncHappinessPettingDayKeyIfNeeded()
            return max(0, happinessDefaults.integer(forKey: HappinessStorageKeys.pettingTouchCountToday))
        }
        set { happinessDefaults.set(max(0, newValue), forKey: HappinessStorageKeys.pettingTouchCountToday) }
    }

    var happinessPettingPointsToday: Int {
        get {
            syncHappinessPettingDayKeyIfNeeded()
            return min(
                AppState.happinessDailyPettingPointLimit,
                max(0, happinessDefaults.integer(forKey: HappinessStorageKeys.pettingPointsToday))
            )
        }
        set {
            happinessDefaults.set(
                min(AppState.happinessDailyPettingPointLimit, max(0, newValue)),
                forKey: HappinessStorageKeys.pettingPointsToday
            )
        }
    }

    private var happinessPettingDayKey: String {
        get { happinessDefaults.string(forKey: HappinessStorageKeys.pettingDayKey) ?? "" }
        set { happinessDefaults.set(newValue, forKey: HappinessStorageKeys.pettingDayKey) }
    }

    func resetHappinessPettingIfNeeded(now: Date = Date()) {
        syncHappinessPettingDayKeyIfNeeded(now: now)
    }

    private func claimedHappinessRewardLevels() -> Set<Int> {
        guard let data = happinessDefaults.data(forKey: HappinessStorageKeys.claimedRewardLevels),
              let values = try? JSONDecoder().decode([Int].self, from: data) else {
            return []
        }
        return Set(values)
    }

    private func setClaimedHappinessRewardLevels(_ levels: Set<Int>) {
        let sorted = levels.sorted()
        let data = try? JSONEncoder().encode(sorted)
        happinessDefaults.set(data, forKey: HappinessStorageKeys.claimedRewardLevels)
    }

    func claimedHappinessRewardLevelsSnapshot() -> Set<Int> {
        claimedHappinessRewardLevels()
    }

    func isHappinessRewardClaimed(level: Int) -> Bool {
        claimedHappinessRewardLevels().contains(level)
    }

    func happinessRewardDefinition(for level: Int) -> HappinessRewardDefinition? {
        AppState.happinessRewardDefinitions.first(where: { $0.level == level })
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

        guard happinessLevel > 0 else {
            happinessPoint = 0
            happinessLevel = 0
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
            NotificationCenter.default.post(name: BGMManager.happinessHeartDidAppearNotification, object: nil)
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
        if fullnessLevel > 0 {
            happinessLastDecayAt = now
            return
        }

        if happinessLastDecayAt == nil {
            happinessLastDecayAt = now
        }

        if happinessLevel <= 0 && happinessPoint <= 0 {
            happinessLastDecayAt = now
        }
    }

    func pendingHappinessDecayCount(fullnessLevel: Int, now: Date = Date()) -> Int {
        resetHappinessPettingIfNeeded(now: now)
        guard fullnessLevel <= 0 else { return 0 }
        guard happinessLevel > 0 || happinessPoint > 0 else { return 0 }
        guard let anchor = happinessLastDecayAt else { return 0 }
        return max(0, Int(now.timeIntervalSince(anchor) / AppState.happinessDecayIntervalSeconds))
    }

    @discardableResult
    func consumeOneHappinessDecayStep() -> Bool {
        guard happinessLevel > 0 || happinessPoint > 0 else { return false }
        decreaseHappinessOnePoint()

        if let anchor = happinessLastDecayAt {
            happinessLastDecayAt = anchor.addingTimeInterval(AppState.happinessDecayIntervalSeconds)
        } else {
            happinessLastDecayAt = Date()
        }
        return true
    }

    func nextClaimableHappinessRewardLevel() -> Int? {
        let claimed = claimedHappinessRewardLevels()

        for reward in AppState.happinessRewardDefinitions {
            if happinessLevel >= reward.level, !claimed.contains(reward.level) {
                return reward.level
            }
        }
        return nil
    }

    func nextUpcomingHappinessRewardLevel() -> Int? {
        let claimed = claimedHappinessRewardLevels()

        for reward in AppState.happinessRewardDefinitions {
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
              level % AppState.happinessRewardLevelStep == 0,
              happinessLevel >= level else {
            return nil
        }

        var claimed = claimedHappinessRewardLevels()
        guard !claimed.contains(level) else { return nil }

        claimed.insert(level)
        setClaimedHappinessRewardLevels(claimed)

        if PetMaster.all.contains(where: { $0.id == reward.petID }) {
            var owned = ownedPetIDs()
            if !owned.contains(reward.petID) {
                owned.append(reward.petID)
                setOwnedPetIDs(owned)
            }
        }

        return .init(
            level: level,
            petID: reward.petID,
            assetName: reward.assetName,
            characterName: reward.characterName
        )
    }
}
