//
//  AppState+MeMoWidget.swift
//  MeMo
//
//  App-side bridge for the interactive home-screen widget.
//  Add this file to the MeMo app target only.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

private enum MeMoHomeWidgetBridgeConstants {
    static let appGroupID = "group.com.shota.CalPet"
    static let widgetKind = "CalPetMediumWidget"
    static let snapshotKey = "memo.homeWidget.snapshot.v1"
    static let snapshotSignatureKey = "memo.homeWidget.snapshot.signature.v1"
    static let pendingActionsKey = "memo.homeWidget.pendingActions.v1"
}

private struct MeMoHomeWidgetBridgeFood: Codable, Hashable {
    let id: String
    let assetName: String
    var count: Int
}

private struct MeMoHomeWidgetBridgeSnapshot: Codable, Equatable {
    var generatedAt: Date
    var petID: String
    var petName: String
    var petImageName: String
    var wallpaperAssetName: String

    var todaySteps: Int
    var walletSteps: Int
    var tenGachaCost: Int

    var fullnessLevel: Int
    var fullnessMaxLevel: Int
    var fullnessLastUpdatedAt: Date?
    var fullnessDecayUnitSeconds: TimeInterval
    var fullnessZeroAt: Date?

    var foodFlagAt: Date?
    var foodNextSpawnAt: Date?
    var desiredFoodID: String?
    var desiredFoodAssetName: String?
    var foods: [MeMoHomeWidgetBridgeFood]

    var toiletFlagAt: Date?
    var toiletNextSpawnAt: Date?
    var toiletItemCount: Int

    var signature: String {
        let foodSignature = foods
            .map { "\($0.id):\(max(0, $0.count))" }
            .joined(separator: ",")

        return [
            petID,
            petName,
            petImageName,
            wallpaperAssetName,
            String(max(0, todaySteps)),
            String(max(0, walletSteps)),
            String(max(1, tenGachaCost)),
            String(max(0, fullnessLevel)),
            String(max(1, fullnessMaxLevel)),
            dateSignature(fullnessLastUpdatedAt),
            String(max(1, fullnessDecayUnitSeconds)),
            dateSignature(fullnessZeroAt),
            dateSignature(foodFlagAt),
            dateSignature(foodNextSpawnAt),
            desiredFoodID ?? "nil",
            desiredFoodAssetName ?? "nil",
            foodSignature,
            dateSignature(toiletFlagAt),
            dateSignature(toiletNextSpawnAt),
            String(max(0, toiletItemCount))
        ].joined(separator: "|")
    }

    private func dateSignature(_ date: Date?) -> String {
        guard let date else { return "nil" }
        return String(Int64(date.timeIntervalSince1970))
    }
}

private struct MeMoHomeWidgetPendingAction: Codable, Identifiable {
    enum Kind: String, Codable {
        case feed
        case toilet
    }

    let id: UUID
    let kind: Kind
    let foodID: String?
    let createdAt: Date
}

@MainActor
enum MeMoWidgetAppBridge {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: MeMoHomeWidgetBridgeConstants.appGroupID)
    }

    @discardableResult
    static func applyPendingActions(to state: AppState, now: Date = .now) -> Bool {
        guard let defaults,
              let data = defaults.data(forKey: MeMoHomeWidgetBridgeConstants.pendingActionsKey),
              let actions = try? JSONDecoder().decode([MeMoHomeWidgetPendingAction].self, from: data),
              !actions.isEmpty else {
            return false
        }

        // キューを先に退避解除し、同じ操作が次回起動時に二重適用されることを防ぐ。
        defaults.removeObject(forKey: MeMoHomeWidgetBridgeConstants.pendingActionsKey)

        var didChange = false
        for action in actions.sorted(by: { $0.createdAt < $1.createdAt }) {
            switch action.kind {
            case .feed:
                if applyFeedAction(action, to: state, now: action.createdAt) {
                    didChange = true
                }

            case .toilet:
                if applyToiletAction(to: state, now: action.createdAt) {
                    didChange = true
                }
            }
        }

        return didChange
    }

    @discardableResult
    static func saveSnapshot(from state: AppState, now: Date = .now, forceReload: Bool = false) -> Bool {
        guard let defaults else { return false }

        let desiredFood = state.ensureDesiredFoodIfNeeded()
        let safeFullnessLevel = min(max(0, state.satisfactionLevel), AppState.fullnessMaxLevel)
        let fullnessZeroAt: Date? = {
            guard safeFullnessLevel > 0 else { return nil }
            let baseDate = state.satisfactionLastUpdatedAt ?? now
            return baseDate.addingTimeInterval(
                Double(safeFullnessLevel) * max(1, AppState.fullnessDecayUnitSeconds)
            )
        }()

        let foods = FoodCatalog.all.map { item in
            MeMoHomeWidgetBridgeFood(
                id: item.id,
                assetName: item.assetName,
                count: state.foodCount(foodId: item.id)
            )
        }

        let snapshot = MeMoHomeWidgetBridgeSnapshot(
            generatedAt: now,
            petID: state.normalizedCurrentPetID,
            petName: state.liveActivityPetName,
            petImageName: PetMaster.assetName(for: state.normalizedCurrentPetID),
            wallpaperAssetName: state.liveActivityWallpaperAssetName,
            todaySteps: state.widgetTodaySteps,
            walletSteps: state.walletSteps,
            tenGachaCost: AppState.liveActivityTenGachaCost,
            fullnessLevel: safeFullnessLevel,
            fullnessMaxLevel: AppState.fullnessMaxLevel,
            fullnessLastUpdatedAt: state.satisfactionLastUpdatedAt,
            fullnessDecayUnitSeconds: AppState.fullnessDecayUnitSeconds,
            fullnessZeroAt: fullnessZeroAt,
            foodFlagAt: state.foodFlagAt,
            foodNextSpawnAt: state.foodNextSpawnAt,
            desiredFoodID: desiredFood?.id,
            desiredFoodAssetName: desiredFood?.assetName,
            foods: foods,
            toiletFlagAt: state.liveActivityEffectiveToiletFlagAt(now: now),
            toiletNextSpawnAt: state.toiletNextSpawnAt,
            toiletItemCount: state.gachaSpecialItemCount(id: "wc")
        )

        guard let encoded = try? JSONEncoder().encode(snapshot) else { return false }

        let previousSignature = defaults.string(forKey: MeMoHomeWidgetBridgeConstants.snapshotSignatureKey)
        let changed = previousSignature != snapshot.signature

        defaults.set(encoded, forKey: MeMoHomeWidgetBridgeConstants.snapshotKey)
        defaults.set(snapshot.signature, forKey: MeMoHomeWidgetBridgeConstants.snapshotSignatureKey)

        // 既存HomeWidgetBridge / HealthKitWidgetBridgeとの互換用キーも同期する。
        defaults.set(snapshot.todaySteps, forKey: "todaySteps")
        defaults.set(snapshot.petID, forKey: "currentPetID")
        defaults.set(snapshot.toiletFlagAt != nil, forKey: "toiletFlag")

        #if canImport(WidgetKit)
        if forceReload || changed {
            WidgetCenter.shared.reloadTimelines(ofKind: MeMoHomeWidgetBridgeConstants.widgetKind)
        }
        #endif

        return changed
    }

    private static func applyFeedAction(
        _ action: MeMoHomeWidgetPendingAction,
        to state: AppState,
        now: Date
    ) -> Bool {
        let canFeed = state.canFeedNow(now: now)
        guard canFeed.can else { return false }

        let selectedFoodID: String? = {
            if let requestedFoodID = action.foodID,
               state.foodCount(foodId: requestedFoodID) > 0 {
                return requestedFoodID
            }

            if let desiredFoodID = state.desiredFoodID,
               state.foodCount(foodId: desiredFoodID) > 0 {
                return desiredFoodID
            }

            return FoodCatalog.all
                .enumerated()
                .filter { state.foodCount(foodId: $0.element.id) > 0 }
                .max { lhs, rhs in
                    let lhsCount = state.foodCount(foodId: lhs.element.id)
                    let rhsCount = state.foodCount(foodId: rhs.element.id)
                    if lhsCount == rhsCount {
                        return lhs.offset > rhs.offset
                    }
                    return lhsCount < rhsCount
                }?
                .element.id
        }()

        guard let foodID = selectedFoodID else { return false }
        guard state.consumeFood(foodId: foodID, count: 1) else { return false }

        let feedResult = state.feedOnce(now: now)
        guard feedResult.didFeed else {
            _ = state.addFood(foodId: foodID, count: 1)
            return false
        }

        let catalogBonus = FoodCatalog.byId(foodID)?.happinessBonusPoints ?? 0
        let desiredFoodBonus = state.desiredFoodAdditionalHappinessBonus(forFoodID: foodID)
        let totalBonus = max(0, catalogBonus + desiredFoodBonus)
        if totalBonus > 0 {
            _ = state.addHappinessPoints(totalBonus, now: now)
        }

        _ = state.resolveFood(now: now)
        _ = state.registerDesiredFoodFeedingResult(foodID: foodID)
        return true
    }

    private static func applyToiletAction(to state: AppState, now: Date) -> Bool {
        _ = state.raiseToiletFlagIfNeeded(now: now)
        guard state.hasToiletFlag else { return false }
        guard state.gachaSpecialItemCount(id: "wc") > 0 else { return false }
        guard state.gachaConsumeSpecialItem(id: "wc", count: 1) else { return false }

        let result = state.resolveToilet(now: now)
        guard result.didResolve else {
            _ = state.gachaAddSpecialItem(id: "wc", count: 1)
            return false
        }

        _ = state.addHappinessPoints(10, now: now)
        return true
    }
}
