//
//  AppState+DesiredFood.swift
//  MeMo
//
//  Stores and rotates the food the current pet wants to eat.
//  This uses UserDefaults so AppState's SwiftData schema does not need a migration.
//

import Foundation

extension Notification.Name {
    static let memoDesiredFoodDidChange = Notification.Name("memo.desiredFood.didChange")
    static let memoDesiredFoodDidMatch = Notification.Name("memo.desiredFood.didMatch")
}

extension AppState {
    static let desiredFoodMatchBonusPoints: Int = 5

    private enum DesiredFoodStorageKeys {
        static let currentFoodID = "memo.desiredFood.currentFoodID"
        static let previousFoodID = "memo.desiredFood.previousFoodID"
    }

    private var desiredFoodDefaults: UserDefaults {
        .standard
    }

    var desiredFoodID: String? {
        get {
            guard let foodID = desiredFoodDefaults.string(forKey: DesiredFoodStorageKeys.currentFoodID),
                  let food = FoodCatalog.byId(foodID),
                  !food.isSpecial else {
                return nil
            }
            return foodID
        }
        set {
            let previousValue = desiredFoodID

            if let newValue,
               let food = FoodCatalog.byId(newValue),
               !food.isSpecial {
                desiredFoodDefaults.set(newValue, forKey: DesiredFoodStorageKeys.currentFoodID)
            } else {
                desiredFoodDefaults.removeObject(forKey: DesiredFoodStorageKeys.currentFoodID)
            }

            guard previousValue != desiredFoodID else { return }
            NotificationCenter.default.post(name: .memoDesiredFoodDidChange, object: desiredFoodID)
        }
    }

    var desiredFood: FoodCatalog.FoodItem? {
        guard let desiredFoodID else { return nil }
        return FoodCatalog.byId(desiredFoodID)
    }

    /// N / R からランダム選択する。SPは「食べたいご飯」の抽選対象外。
    @discardableResult
    func refreshDesiredFood(excluding excludedFoodID: String? = nil) -> FoodCatalog.FoodItem? {
        let currentID = desiredFoodID
        let allFoods = FoodCatalog.all.filter { !$0.isSpecial }

        guard !allFoods.isEmpty else {
            desiredFoodID = nil
            return nil
        }

        var candidates = allFoods.filter { food in
            food.id != currentID && food.id != excludedFoodID
        }

        if candidates.isEmpty {
            candidates = allFoods.filter { $0.id != currentID }
        }

        if candidates.isEmpty {
            candidates = allFoods
        }

        guard let nextFood = candidates.randomElement() else {
            desiredFoodID = nil
            return nil
        }

        if let currentID {
            desiredFoodDefaults.set(currentID, forKey: DesiredFoodStorageKeys.previousFoodID)
        } else {
            desiredFoodDefaults.removeObject(forKey: DesiredFoodStorageKeys.previousFoodID)
        }

        desiredFoodID = nextFood.id
        return nextFood
    }

    @discardableResult
    func ensureDesiredFoodIfNeeded() -> FoodCatalog.FoodItem? {
        if let desiredFood {
            return desiredFood
        }
        return refreshDesiredFood()
    }

    func isDesiredFood(foodID: String) -> Bool {
        desiredFoodID == foodID
    }

    func desiredFoodAdditionalHappinessBonus(forFoodID foodID: String) -> Int {
        guard let food = FoodCatalog.byId(foodID), !food.isSpecial else {
            return 0
        }
        return isDesiredFood(foodID: foodID) ? AppState.desiredFoodMatchBonusPoints : 0
    }

    @discardableResult
    func registerDesiredFoodFeedingResult(foodID: String) -> Bool {
        guard let food = FoodCatalog.byId(foodID), !food.isSpecial else {
            return false
        }

        let matched = isDesiredFood(foodID: foodID)

        if matched {
            NotificationCenter.default.post(name: .memoDesiredFoodDidMatch, object: foodID)
        }

        _ = refreshDesiredFood(excluding: foodID)
        return matched
    }
}
