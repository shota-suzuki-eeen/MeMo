import Foundation
import SwiftData

@MainActor
enum Halloween2026GachaGranting {
    static func inventory(state: AppState, fishing: FishingStore) -> HalloweenGachaInventory {
        HalloweenGachaInventory(
            foods: Dictionary(uniqueKeysWithValues: (HalloweenGachaCatalog.normalFoodIDs + HalloweenGachaCatalog.rareFoodIDs + ["yakiniku"]).map { ($0, state.foodCount(foodId: $0)) }),
            items: Dictionary(uniqueKeysWithValues: ["wc", "gachaTicket_nomal"].map { ($0, state.gachaSpecialItemCount(id: $0)) }),
            fishingPoints: fishing.pointBalance, ownedPetIDs: Set(state.ownedPetIDs()))
    }

    /// Always finish the same journal before exposing inventory or accepting another draw.
    @discardableResult
    static func recover(state: AppState, store: Halloween2026EventStore,
                        context: ModelContext, fishing: FishingStore? = nil) throws -> HalloweenGachaBatch? {
        guard let batch = store.pendingGachaBatch else { return nil }
        let fishing = fishing ?? FishingStore.shared
        for (id, target) in batch.foodTargets {
            let amount = max(0, max(0, target) - state.foodCount(foodId: id))
            if amount > 0 { _ = state.addFood(foodId: id, count: amount) }
        }
        for (id, target) in batch.itemTargets {
            let amount = max(0, max(0, target) - state.gachaSpecialItemCount(id: id))
            if amount > 0 { _ = state.gachaAddSpecialItem(id: id, count: amount) }
        }
        var owned = state.ownedPetIDs()
        for id in batch.petIDs.sorted() where !owned.contains(id) { owned.append(id) }
        if !batch.petIDs.isEmpty { state.setOwnedPetIDs(owned) }
        if let target = batch.fishingPointTarget { fishing.ensureEventRewardPointBalance(atLeast: target) }
        try context.save()
        store.completeGachaDelivery(id: batch.id)
        return batch
    }

    static func draw(id: String, count: Int, state: AppState, store: Halloween2026EventStore,
                     context: ModelContext, adClaim: HalloweenGachaAdClaim? = nil) throws -> HalloweenGachaBatch? {
        guard store.pendingGachaBatch == nil else { return try recover(state: state, store: store, context: context) }
        // The snapshot must already exist on disk before writing the delivery journal.
        try context.save()
        guard store.prepareGachaBatch(id: id, count: count, inventory: inventory(state: state, fishing: .shared), adClaim: adClaim) != nil else { return nil }
        return try recover(state: state, store: store, context: context)
    }
}
