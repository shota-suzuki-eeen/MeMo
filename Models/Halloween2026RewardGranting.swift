//
//  Halloween2026RewardGranting.swift
//  MeMo
//
//  イベント報酬・交換所の付与処理を、既存AppStateの付与APIへ集約する。
//

import Foundation

enum Halloween2026RewardGranting {
    @discardableResult
    static func claim(
        reward: HalloweenDistanceReward,
        state: AppState,
        store: Halloween2026EventStore
    ) -> Bool {
        guard EventManager.isActive(.halloween2026) else { return false }
        guard reward.isReached(in: store) else { return false }
        guard !reward.isClaimed(in: store) else { return false }
        guard grant(content: reward.reward, state: state, store: store) else { return false }

        store.markRewardClaimed(id: reward.id)
        return true
    }

    @discardableResult
    static func exchange(
        offer: HalloweenExchangeOffer,
        quantity: Int,
        state: AppState,
        store: Halloween2026EventStore
    ) -> Bool {
        guard EventManager.isActive(.halloween2026) else { return false }

        let safeQuantity = max(1, quantity)
        let maximumQuantity = store.maximumExchangeQuantity(for: offer)
        guard safeQuantity <= maximumQuantity else { return false }

        let (totalPrice, priceOverflow) = offer.candyPrice.multipliedReportingOverflow(by: safeQuantity)
        guard !priceOverflow, totalPrice > 0 else { return false }

        guard let multipliedReward = offer.reward.multiplied(by: safeQuantity) else { return false }
        guard store.spendCandy(totalPrice) else { return false }

        guard grant(content: multipliedReward, state: state, store: store) else {
            // AppState側の付与に失敗した場合はキャンディだけ戻す。
            store.addCandy(totalPrice)
            return false
        }

        store.registerExchange(offerID: offer.id, quantity: safeQuantity)
        return true
    }

    @discardableResult
    static func grant(
        content: HalloweenRewardContent,
        state: AppState,
        store: Halloween2026EventStore
    ) -> Bool {
        switch content {
        case .candy(let count):
            guard count > 0 else { return false }
            store.addCandy(count)
            return true

        case .food(let foodID, let count):
            guard FoodCatalog.byId(foodID) != nil else { return false }
            return state.addFood(foodId: foodID, count: count)

        case .toilet(let count):
            return state.gachaAddSpecialItem(id: "wc", count: count)

        case .steps(let amount):
            guard amount > 0 else { return false }
            return state.addWalletSteps(amount) == amount
        }
    }
}
