//
//  AppState+Onboarding.swift
//  MeMo
//
//  Onboarding flags are kept in UserDefaults so the SwiftData @Model shape stays stable.
//  iOS 18.6+
//

import Foundation

struct MemoTutorialGachaRewardModel: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let imageName: String
    let isCharacter: Bool

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        imageName: String,
        isCharacter: Bool
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.imageName = imageName
        self.isCharacter = isCharacter
    }
}

extension AppState {
    private enum MemoOnboardingStorageKeys {
        static let screenPrefix = "memo.onboarding.seen.screen."
        static let mandatoryStarted = "memo.onboarding.mandatory.started"
        static let mandatoryCompleted = "memo.onboarding.mandatory.completed"
        static let mandatoryCurrentStep = "memo.onboarding.mandatory.currentStep"
        static let tutorialGachaPetID = "memo.onboarding.gacha.tutorialPetID"
        static let tutorialCharacterSwitched = "memo.onboarding.zukan.characterSwitched"
        static let firstVisitFreeTenDrawConsumed = "memo.onboarding.gacha.firstVisitFreeTenDrawConsumed"
        static let firstVisitFreeTenDrawOffered = "memo.onboarding.gacha.firstVisitFreeTenDrawOffered"
        static let firstVisitFreeTenDrawCompleted = "memo.onboarding.gacha.firstVisitFreeTenDrawCompleted"
        static let foodTutorialPrepared = "memo.onboarding.food.prepared"
        static let foodTutorialNormalFoodID = "memo.onboarding.food.normalFoodID"
        static let foodTutorialRareFoodID = "memo.onboarding.food.rareFoodID"
        static let foodTutorialNormalPreparedCount = "memo.onboarding.food.normalPreparedCount"
        static let foodTutorialRarePreparedCount = "memo.onboarding.food.rarePreparedCount"
        static let foodTutorialNormalFed = "memo.onboarding.food.normalFed"
        static let foodTutorialRareFed = "memo.onboarding.food.rareFed"
        static let foodTutorialCompleted = "memo.onboarding.food.completed"
        static let toiletTutorialPrepared = "memo.onboarding.toilet.prepared"
        static let toiletTutorialScratchShown = "memo.onboarding.toilet.scratchShown"
        static let toiletTutorialCompleted = "memo.onboarding.toilet.completed"
    }

    private var memoOnboardingDefaults: UserDefaults { .standard }

    // MARK: - Mandatory first-run tutorial

    var memoMandatoryOnboardingStarted: Bool {
        memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.mandatoryStarted)
    }

    var memoMandatoryOnboardingCompleted: Bool {
        memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.mandatoryCompleted)
    }

    var memoMandatoryOnboardingCurrentStep: MemoOnboardingScreen? {
        get {
            guard let rawValue = memoOnboardingDefaults.string(forKey: MemoOnboardingStorageKeys.mandatoryCurrentStep) else {
                return nil
            }
            return MemoOnboardingScreen(rawValue: rawValue)
        }
        set {
            if let newValue {
                memoOnboardingDefaults.set(newValue.rawValue, forKey: MemoOnboardingStorageKeys.mandatoryCurrentStep)
            } else {
                memoOnboardingDefaults.removeObject(forKey: MemoOnboardingStorageKeys.mandatoryCurrentStep)
            }
        }
    }

    var memoShouldRunMandatoryOnboarding: Bool {
        memoMandatoryOnboardingCompleted == false
    }

    @discardableResult
    func memoStartMandatoryOnboardingIfNeeded(now: Date = Date()) -> Bool {
        guard memoMandatoryOnboardingCompleted == false else { return false }

        var didChange = false
        if memoMandatoryOnboardingStarted == false {
            memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.mandatoryStarted)
            memoMandatoryOnboardingCurrentStep = .appPurpose
            didChange = true

            // 初回は「お腹が減っている」状態から始める。
            satisfactionLevel = 0
            satisfactionLastUpdatedAt = nil
        }

        if foodFlagAt == nil {
            foodFlagAt = now
            foodLastRaisedAt = now
            foodNextSpawnAt = nil
            didChange = true
        }

        if memoPrepareFoodTutorialItemsIfNeeded(now: now) {
            didChange = true
        }

        return didChange
    }

    func memoSaveMandatoryOnboardingStep(_ step: MemoOnboardingScreen) {
        guard step.isMandatoryTutorialStep else { return }
        memoMandatoryOnboardingCurrentStep = step
    }

    @discardableResult
    func memoMarkMandatoryOnboardingCompleted() -> Bool {
        guard memoMandatoryOnboardingCompleted == false else { return false }
        memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.mandatoryCompleted)
        memoMandatoryOnboardingCurrentStep = nil
        _ = memoMarkFoodTutorialCompleted()
        return true
    }

    @discardableResult
    func memoSkipAllOnboardingForIPadIfNeeded() -> Bool {
        guard MemoDevice.isIPad else { return false }

        var didChange = false

        @discardableResult
        func setTrueIfNeeded(_ key: String) -> Bool {
            guard memoOnboardingDefaults.bool(forKey: key) == false else { return false }
            memoOnboardingDefaults.set(true, forKey: key)
            return true
        }

        if memoMandatoryOnboardingCurrentStep != nil {
            memoMandatoryOnboardingCurrentStep = nil
            didChange = true
        }

        didChange = setTrueIfNeeded(MemoOnboardingStorageKeys.mandatoryStarted) || didChange
        didChange = setTrueIfNeeded(MemoOnboardingStorageKeys.mandatoryCompleted) || didChange
        didChange = setTrueIfNeeded(MemoOnboardingStorageKeys.foodTutorialCompleted) || didChange
        didChange = setTrueIfNeeded(MemoOnboardingStorageKeys.toiletTutorialCompleted) || didChange

        for screen in MemoOnboardingScreen.allCases where screen.shouldRememberAsScreenVisit {
            let key = MemoOnboardingStorageKeys.screenPrefix + screen.rawValue
            didChange = setTrueIfNeeded(key) || didChange
        }

        return didChange
    }

    // MARK: - Screen visit flags

    func memoOnboardingHasSeen(_ screen: MemoOnboardingScreen) -> Bool {
        memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.screenPrefix + screen.rawValue)
    }

    func memoOnboardingShouldPresent(_ screen: MemoOnboardingScreen) -> Bool {
        if memoMandatoryOnboardingCompleted == false {
            return screen.isMandatoryTutorialStep
        }
        return screen.shouldRememberAsScreenVisit ? !memoOnboardingHasSeen(screen) : true
    }

    @discardableResult
    func memoOnboardingMarkSeen(_ screen: MemoOnboardingScreen) -> Bool {
        guard screen.shouldRememberAsScreenVisit else { return false }
        let key = MemoOnboardingStorageKeys.screenPrefix + screen.rawValue
        guard memoOnboardingDefaults.bool(forKey: key) == false else { return false }
        memoOnboardingDefaults.set(true, forKey: key)
        return true
    }

    // MARK: - First visit free gacha

    var memoCanUseFirstVisitFreeTenDraw: Bool {
        memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.firstVisitFreeTenDrawConsumed) == false
    }

    var memoHasOfferedFirstVisitFreeTenDraw: Bool {
        memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.firstVisitFreeTenDrawOffered)
    }

    var memoHasCompletedFirstVisitFreeTenDraw: Bool {
        memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.firstVisitFreeTenDrawCompleted)
    }

    @discardableResult
    func memoMarkFirstVisitFreeTenDrawOffered() -> Bool {
        guard memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.firstVisitFreeTenDrawOffered) == false else { return false }
        memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.firstVisitFreeTenDrawOffered)
        return true
    }

    @discardableResult
    func memoConsumeFirstVisitFreeTenDraw() -> Bool {
        guard memoCanUseFirstVisitFreeTenDraw else { return false }
        memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.firstVisitFreeTenDrawConsumed)
        memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.firstVisitFreeTenDrawOffered)
        return true
    }

    @discardableResult
    func memoMarkFirstVisitFreeTenDrawCompleted() -> Bool {
        guard memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.firstVisitFreeTenDrawCompleted) == false else { return false }
        memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.firstVisitFreeTenDrawCompleted)
        return true
    }

    func memoShouldGuaranteeCharacterForFirstVisitFreeTenDraw(
        drawIndex: Int,
        totalDrawCount: Int,
        hasAlreadyGeneratedCharacter: Bool
    ) -> Bool {
        memoCanUseFirstVisitFreeTenDraw == false
            && memoHasCompletedFirstVisitFreeTenDraw == false
            && totalDrawCount >= 10
            && drawIndex == totalDrawCount - 1
            && hasAlreadyGeneratedCharacter == false
    }

    // MARK: - Tutorial gacha character

    var memoTutorialGachaCharacterPetID: String {
        if let stored = memoOnboardingDefaults.string(forKey: MemoOnboardingStorageKeys.tutorialGachaPetID),
           PetMaster.all.contains(where: { $0.id == stored }) {
            return stored
        }

        let owned = Set(ownedPetIDs())
        let candidates = PetMaster.all.filter {
            !owned.contains($0.id)
            && !PetMaster.isHappinessRewardPetID($0.id)
            && $0.id != normalizedCurrentPetID
        }
        let fallbackCandidates = PetMaster.all.filter {
            !PetMaster.isHappinessRewardPetID($0.id)
            && $0.id != normalizedCurrentPetID
        }

        let selected = candidates.randomElement()?.id
            ?? fallbackCandidates.randomElement()?.id
            ?? "pet_001"
        memoOnboardingDefaults.set(selected, forKey: MemoOnboardingStorageKeys.tutorialGachaPetID)
        return selected
    }

    var memoTutorialGachaCharacterName: String {
        PetMaster.all.first(where: { $0.id == memoTutorialGachaCharacterPetID })?.name ?? "新しいキャラクター"
    }

    var memoTutorialGachaCharacterAssetName: String {
        PetMaster.assetName(for: memoTutorialGachaCharacterPetID)
    }

    @discardableResult
    func memoAwardTutorialGachaCharacterIfNeeded() -> String {
        let petID = memoTutorialGachaCharacterPetID
        var owned = ownedPetIDs()
        if owned.contains(petID) == false {
            owned.append(petID)
            setOwnedPetIDs(owned)
        }
        return petID
    }

    @discardableResult
    func memoAwardTutorialFreeTenGachaRewards() -> [MemoTutorialGachaRewardModel] {
        _ = memoMarkFirstVisitFreeTenDrawOffered()
        _ = memoConsumeFirstVisitFreeTenDraw()

        let petID = memoAwardTutorialGachaCharacterIfNeeded()
        let petName = PetMaster.all.first(where: { $0.id == petID })?.name ?? "新しいキャラクター"
        let characterReward = MemoTutorialGachaRewardModel(
            title: petName,
            subtitle: "キャラクター / SR",
            imageName: PetMaster.assetName(for: petID),
            isCharacter: true
        )

        let foods = (0..<9).compactMap { _ -> FoodCatalog.FoodItem? in
            FoodCatalog.all.randomElement()
        }
        foods.forEach { food in
            _ = addFood(foodId: food.id, count: 1)
        }

        let foodRewards = foods.map { food in
            MemoTutorialGachaRewardModel(
                title: food.name,
                subtitle: food.isShopEligible ? "ごはん / N" : "ごはん / R",
                imageName: food.assetName,
                isCharacter: false
            )
        }

        _ = memoMarkFirstVisitFreeTenDrawCompleted()
        return ([characterReward] + foodRewards).shuffled()
    }

    var memoTutorialCharacterSwitched: Bool {
        memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.tutorialCharacterSwitched)
    }

    @discardableResult
    func memoSwitchToTutorialGachaCharacter() -> Bool {
        let petID = memoAwardTutorialGachaCharacterIfNeeded()
        let didChange = currentPetID != petID
        currentPetID = petID
        memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.tutorialCharacterSwitched)
        return didChange
    }

    // MARK: - Food tutorial

    var memoFoodTutorialPrepared: Bool {
        memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.foodTutorialPrepared)
    }

    var memoFoodTutorialNormalFed: Bool {
        memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.foodTutorialNormalFed)
    }

    var memoFoodTutorialRareFed: Bool {
        memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.foodTutorialRareFed)
    }

    var memoFoodTutorialCompleted: Bool {
        memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.foodTutorialCompleted)
    }

    var memoTutorialNormalFoodID: String {
        if let stored = memoOnboardingDefaults.string(forKey: MemoOnboardingStorageKeys.foodTutorialNormalFoodID),
           let item = FoodCatalog.byId(stored),
           item.isShopEligible {
            return stored
        }

        let candidates = FoodCatalog.all.filter { $0.isShopEligible }
        let selected = candidates.randomElement()?.id
            ?? FoodCatalog.all.first(where: { $0.isShopEligible })?.id
            ?? "onigiri"
        memoOnboardingDefaults.set(selected, forKey: MemoOnboardingStorageKeys.foodTutorialNormalFoodID)
        return selected
    }

    var memoTutorialRareFoodID: String {
        if let stored = memoOnboardingDefaults.string(forKey: MemoOnboardingStorageKeys.foodTutorialRareFoodID),
           let item = FoodCatalog.byId(stored),
           item.isShopEligible == false {
            return stored
        }

        let candidates = FoodCatalog.happinessRewardEligibleItems
        let selected = candidates.randomElement()?.id
            ?? FoodCatalog.all.first(where: { !$0.isShopEligible })?.id
            ?? "matsuzakaBeef"
        memoOnboardingDefaults.set(selected, forKey: MemoOnboardingStorageKeys.foodTutorialRareFoodID)
        return selected
    }

    var memoTutorialNormalFood: FoodCatalog.FoodItem? {
        FoodCatalog.byId(memoTutorialNormalFoodID)
    }

    var memoTutorialRareFood: FoodCatalog.FoodItem? {
        FoodCatalog.byId(memoTutorialRareFoodID)
    }

    var memoTutorialNormalFoodName: String {
        memoTutorialNormalFood?.name ?? "Nのごはん"
    }

    var memoTutorialRareFoodName: String {
        memoTutorialRareFood?.name ?? "Rのごはん"
    }

    var memoTutorialNormalFoodPreparedCount: Int {
        max(0, memoOnboardingDefaults.integer(forKey: MemoOnboardingStorageKeys.foodTutorialNormalPreparedCount))
    }

    var memoTutorialRareFoodPreparedCount: Int {
        max(0, memoOnboardingDefaults.integer(forKey: MemoOnboardingStorageKeys.foodTutorialRarePreparedCount))
    }

    var memoHasTutorialNormalFoodActuallyBeenFed: Bool {
        if memoFoodTutorialNormalFed { return true }
        let baseline = memoTutorialNormalFoodPreparedCount
        guard baseline > 0 else { return false }
        return foodCount(foodId: memoTutorialNormalFoodID) < baseline
    }

    var memoHasTutorialRareFoodActuallyBeenFed: Bool {
        if memoFoodTutorialRareFed { return true }
        let baseline = memoTutorialRareFoodPreparedCount
        guard baseline > 0 else { return false }
        return foodCount(foodId: memoTutorialRareFoodID) < baseline
    }

    @discardableResult
    func memoPrepareFoodTutorialItemsIfNeeded(now: Date = Date()) -> Bool {
        var didChange = false

        let normalID = memoTutorialNormalFoodID
        let rareID = memoTutorialRareFoodID

        if memoFoodTutorialNormalFed == false, foodCount(foodId: normalID) <= 0 {
            _ = addFood(foodId: normalID, count: 1)
            didChange = true
        }

        if memoFoodTutorialRareFed == false, foodCount(foodId: rareID) <= 0 {
            _ = addFood(foodId: rareID, count: 1)
            didChange = true
        }

        let normalPreparedCount = max(1, foodCount(foodId: normalID))
        let rarePreparedCount = max(1, foodCount(foodId: rareID))

        if memoOnboardingDefaults.object(forKey: MemoOnboardingStorageKeys.foodTutorialNormalPreparedCount) == nil {
            memoOnboardingDefaults.set(normalPreparedCount, forKey: MemoOnboardingStorageKeys.foodTutorialNormalPreparedCount)
            didChange = true
        }

        if memoOnboardingDefaults.object(forKey: MemoOnboardingStorageKeys.foodTutorialRarePreparedCount) == nil {
            memoOnboardingDefaults.set(rarePreparedCount, forKey: MemoOnboardingStorageKeys.foodTutorialRarePreparedCount)
            didChange = true
        }

        if foodFlagAt == nil {
            foodFlagAt = now
            foodLastRaisedAt = now
            foodNextSpawnAt = nil
            didChange = true
        }

        if memoFoodTutorialPrepared == false {
            memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.foodTutorialPrepared)
            didChange = true
        }

        return didChange
    }

    @discardableResult
    func memoApplyTutorialFood(foodID: String, now: Date = Date()) -> Bool {
        guard FoodCatalog.byId(foodID) != nil else { return false }
        if foodCount(foodId: foodID) <= 0 {
            _ = addFood(foodId: foodID, count: 1)
        }
        guard consumeFood(foodId: foodID, count: 1) else { return false }

        let currentLevel = currentSatisfaction(now: now)
        satisfactionLevel = min(AppState.fullnessMaxLevel, max(0, currentLevel) + 1)
        satisfactionLastUpdatedAt = now

        let bonus = FoodCatalog.byId(foodID)?.happinessBonusPoints ?? happinessBonusPoints(forFoodID: foodID)
        if bonus > 0 {
            _ = addHappinessPoints(bonus, now: now)
        }

        refreshHappinessDecayTracking(fullnessLevel: satisfactionLevel, now: now)
        return true
    }

    @discardableResult
    func memoApplyTutorialNormalFood(now: Date = Date()) -> Bool {
        let didApply = memoApplyTutorialFood(foodID: memoTutorialNormalFoodID, now: now)
        if didApply {
            memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.foodTutorialNormalFed)
        }
        return didApply
    }

    @discardableResult
    func memoApplyTutorialRareFood(now: Date = Date()) -> Bool {
        let didApply = memoApplyTutorialFood(foodID: memoTutorialRareFoodID, now: now)
        if didApply {
            memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.foodTutorialRareFed)
        }
        return didApply
    }

    @discardableResult
    func memoMarkTutorialFoodFed(foodID: String) -> MemoOnboardingScreen? {
        if foodID == memoTutorialNormalFoodID,
           memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.foodTutorialNormalFed) == false {
            memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.foodTutorialNormalFed)
            return .foodTutorialNormalResult
        }

        if foodID == memoTutorialRareFoodID,
           memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.foodTutorialRareFed) == false {
            memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.foodTutorialRareFed)
            return .foodTutorialRareResult
        }

        if memoFoodTutorialNormalFed && memoFoodTutorialRareFed && memoFoodTutorialCompleted == false {
            memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.foodTutorialCompleted)
            return .foodTutorialDone
        }

        return nil
    }

    @discardableResult
    func memoMarkFoodTutorialCompleted() -> Bool {
        guard memoFoodTutorialCompleted == false else { return false }
        memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.foodTutorialCompleted)
        return true
    }

    func memoFoodTutorialMessage(for screen: MemoOnboardingScreen) -> String {
        switch screen {
        case .foodButton:
            return "おや？お腹が減っているみたい！\n光っている「ごはんボタン」をタップしてみよう。"
        case .foodGiveNormal:
            return "\(memoTutorialNormalFoodName)をタップしてあげてみよう。\nN（ノーマル）のごはんだよ。"
        case .foodNormalResult:
            return "上手！\(memoTutorialNormalFoodName)をあげたことで満腹度が上がったみたい！\nここが満腹度メーターだよ。"
        case .foodButtonForRare:
            return "次はR（レア）のごはんだよ！\nもう一度「ごはんボタン」をタップしてみよう。"
        case .foodRareTab:
            return "R（レア）のごはんに切り替えてみよう！\n光っている切り替え部分をタップしてね。"
        case .foodGiveRare:
            return "\(memoTutorialRareFoodName)をタップしてあげてみよう。\nR（レア）のごはんだよ。"
        case .foodRareResult:
            return "覚えておこう！\n\(memoTutorialRareFoodName)で満腹度と幸せ度が上がったよ。\n💡R（レア）のご飯をあげると「満腹度」と一緒に「幸せ度」も増加するみたい！"
        default:
            return screen.message
        }
    }

    // MARK: - Toilet tutorial

    var memoToiletTutorialPrepared: Bool {
        memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.toiletTutorialPrepared)
    }

    var memoToiletTutorialScratchShown: Bool {
        memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.toiletTutorialScratchShown)
    }

    var memoToiletTutorialCompleted: Bool {
        memoOnboardingDefaults.bool(forKey: MemoOnboardingStorageKeys.toiletTutorialCompleted)
    }

    @discardableResult
    func memoPrepareToiletTutorialFlagIfNeeded(now: Date = Date()) -> Bool {
        guard memoToiletTutorialCompleted == false else { return false }

        var changed = false
        if toiletFlagAt == nil {
            toiletFlagAt = now
            toiletLastRaisedAt = now
            toiletNextSpawnAt = nil
            changed = true
        }

        if toiletPoops().filter({ !$0.isCleared }).isEmpty {
            let newPoops = generateToiletPoops(count: AppState.toiletPoopInitialCount)
            setToiletPoops(newPoops)
            toiletPoopLastSpawnAt = now
            changed = true
        }

        if memoToiletTutorialPrepared == false {
            memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.toiletTutorialPrepared)
            changed = true
        }

        return changed
    }

    @discardableResult
    func memoMarkToiletTutorialScratchShown() -> Bool {
        guard memoToiletTutorialScratchShown == false else { return false }
        memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.toiletTutorialScratchShown)
        return true
    }

    @discardableResult
    func memoMarkToiletTutorialCompletedIfNeeded() -> Bool {
        guard memoToiletTutorialCompleted == false else { return false }
        guard toiletPoops().contains(where: { !$0.isCleared }) == false else { return false }
        memoOnboardingDefaults.set(true, forKey: MemoOnboardingStorageKeys.toiletTutorialCompleted)
        return true
    }

    // MARK: - Debug support

    func memoResetOnboardingForDebug() {
        let keys: [String] = MemoOnboardingScreen.allCases.map { MemoOnboardingStorageKeys.screenPrefix + $0.rawValue } + [
            MemoOnboardingStorageKeys.mandatoryStarted,
            MemoOnboardingStorageKeys.mandatoryCompleted,
            MemoOnboardingStorageKeys.mandatoryCurrentStep,
            MemoOnboardingStorageKeys.tutorialGachaPetID,
            MemoOnboardingStorageKeys.tutorialCharacterSwitched,
            MemoOnboardingStorageKeys.firstVisitFreeTenDrawConsumed,
            MemoOnboardingStorageKeys.firstVisitFreeTenDrawOffered,
            MemoOnboardingStorageKeys.firstVisitFreeTenDrawCompleted,
            MemoOnboardingStorageKeys.foodTutorialPrepared,
            MemoOnboardingStorageKeys.foodTutorialNormalFoodID,
            MemoOnboardingStorageKeys.foodTutorialRareFoodID,
            MemoOnboardingStorageKeys.foodTutorialNormalPreparedCount,
            MemoOnboardingStorageKeys.foodTutorialRarePreparedCount,
            MemoOnboardingStorageKeys.foodTutorialNormalFed,
            MemoOnboardingStorageKeys.foodTutorialRareFed,
            MemoOnboardingStorageKeys.foodTutorialCompleted,
            MemoOnboardingStorageKeys.toiletTutorialPrepared,
            MemoOnboardingStorageKeys.toiletTutorialScratchShown,
            MemoOnboardingStorageKeys.toiletTutorialCompleted
        ]

        for key in keys {
            memoOnboardingDefaults.removeObject(forKey: key)
        }
    }
}
