//
//  ShopViewModel.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation
import SwiftUI
import Combine

struct ShopFoodItem: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let kcal: Int
    var stock: Int
}

@MainActor
final class ShopViewModel: ObservableObject {
    @Published var displayedWalletKcal: Int = 0
    @Published var toastMessage: String?
    @Published var showToast: Bool = false
    @Published var showHatchAlert: Bool = false
    @Published var hatchMessage: String = ""

    func onAppear(state: AppState) {
        state.ensureInitialPetsIfNeeded()
        handleDayRolloverIfNeeded(state: state)
        ensureDailyShopIfNeeded(state: state)

        _ = state.drainPendingKcalToWallet()   // ✅ 一元化
        displayedWalletKcal = state.walletKcal
    }

    func decodeShopItems(from state: AppState) -> [ShopFoodItem]? {
        guard let data = state.shopItemsData else { return nil }
        return try? JSONDecoder().decode([ShopFoodItem].self, from: data)
    }

    // ✅ 追加：所持数（インベントリ数）を取得するヘルパー
    // - 「在庫（=当日購入可否）」とは別概念なので、stock は触らない
    // - 表示側が「所持数」を出したいときに呼ぶ
    func ownedCount(for itemID: String, state: AppState) -> Int {
        state.foodCount(foodId: itemID)
    }

    func buyFood(itemID: String, state: AppState) {
        handleDayRolloverIfNeeded(state: state)
        ensureDailyShopIfNeeded(state: state)
        _ = state.drainPendingKcalToWallet()   // ✅ 一元化

        guard var items = decodeShopItems(from: state) else { return }
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }

        guard items[idx].stock > 0 else {
            failToast("売り切れです")
            Haptics.rattle(duration: 0.10, style: .light)
            return
        }

        let price = items[idx].kcal
        guard state.walletKcal >= price else {
            failToast("kcalが足りません（必要: \(price)）")
            Haptics.rattle(duration: 0.12, style: .light)
            return
        }

        guard FoodCatalog.byId(itemID) != nil else {
            failToast("不正な商品です")
            Haptics.rattle(duration: 0.12, style: .light)
            return
        }

        let fromDisplayed = displayedWalletKcal
        state.walletKcal -= price
        _ = state.addFood(foodId: itemID, count: 1)

        items[idx].stock = 0
        state.shopItemsData = encodeShopItems(items)

        Task { await animateShopWalletCountDown(from: fromDisplayed, to: state.walletKcal) }

        Haptics.tap(style: .medium)
        toast("\(items[idx].name) を購入しました（-\(price)kcal）")
    }

    /// ✅ Reward_food（広告視聴完了後）に呼ばれる想定
    func rewardResetShopByAd(state: AppState, maxPerDay: Int) {
        handleDayRolloverIfNeeded(state: state)
        ensureDailyShopIfNeeded(state: state)

        guard state.shopRewardResetsToday < maxPerDay else {
            failToast("本日のリセット上限です（\(maxPerDay)回）")
            Haptics.rattle(duration: 0.10, style: .light)
            return
        }

        state.shopRewardResetsToday += 1
        state.shopItemsData = encodeShopItems(drawDailySix())

        Haptics.tap(style: .light)
        toast("ショップをリセットしました")
    }

    // --- 以降は既存のまま（現状の機能を壊さない） ---

    func buyEgg(state: AppState) {
        handleDayRolloverIfNeeded(state: state)
        state.ensureInitialPetsIfNeeded()

        let owned = Set(state.ownedPetIDs())
        if owned.count >= PetMaster.all.count {
            failToast("全キャラコンプ済みです")
            Haptics.rattle(duration: 0.10, style: .light)
            return
        }

        guard !state.eggOwned else {
            failToast("卵はすでに所持しています")
            Haptics.rattle(duration: 0.10, style: .light)
            return
        }

        guard state.friendshipCardCount >= 1 else {
            failToast("なかよしカードが足りません（必要: 1枚）")
            Haptics.rattle(duration: 0.10, style: .light)
            return
        }

        state.friendshipCardCount -= 1
        state.eggOwned = true
        state.eggHatchAt = Date().addingTimeInterval(6 * 60 * 60)

        Haptics.tap(style: .light)
        toast("卵を購入しました（孵化まで6時間）")
    }

    func instantHatchByAd(state: AppState) {
        handleDayRolloverIfNeeded(state: state)

        guard state.eggOwned else { return }
        guard state.eggAdUsedToday == false else {
            failToast("本日の即孵化（広告）は上限です")
            Haptics.rattle(duration: 0.10, style: .light)
            return
        }

        state.eggAdUsedToday = true
        state.eggHatchAt = Date()

        Haptics.tap(style: .medium)
        toast("即孵化が可能になりました")
    }

    func hatchEgg(state: AppState) {
        guard state.eggOwned else { return }
        guard let hatchAt = state.eggHatchAt, Date() >= hatchAt else {
            failToast("まだ孵化できません")
            Haptics.rattle(duration: 0.10, style: .light)
            return
        }

        state.ensureInitialPetsIfNeeded()

        let owned = Set(state.ownedPetIDs())
        let notOwned = PetMaster.all.map(\.id).filter { !owned.contains($0) }

        guard let newID = notOwned.randomElement() else {
            state.eggOwned = false
            state.eggHatchAt = nil
            hatchMessage = "すべてのキャラをコンプリートしています！"
            showHatchAlert = true
            return
        }

        var nextOwned = state.ownedPetIDs()
        nextOwned.append(newID)
        state.setOwnedPetIDs(nextOwned)
        state.currentPetID = newID
        state.eggOwned = false
        state.eggHatchAt = nil

        Haptics.tap(style: .heavy)
        let name = PetMaster.all.first(where: { $0.id == newID })?.name ?? "新キャラ"
        hatchMessage = "\(name) が仲間になりました！"
        showHatchAlert = true
    }

    private func encodeShopItems(_ items: [ShopFoodItem]) -> Data? {
        try? JSONEncoder().encode(items)
    }

    private func ensureDailyShopIfNeeded(state: AppState) {
        let todayKey = AppState.makeDayKey(Date())
        if state.shopDayKey != todayKey {
            state.shopDayKey = todayKey
            state.shopRewardResetsToday = 0
            state.shopItemsData = encodeShopItems(drawDailySix())
            return
        }

        if state.shopItemsData == nil {
            state.shopItemsData = encodeShopItems(drawDailySix())
        }
    }

    private func drawDailySix() -> [ShopFoodItem] {
        let picked = Array(FoodCatalog.all.shuffled().prefix(6))
        return picked.map { .init(id: $0.id, name: $0.name, kcal: $0.priceKcal, stock: 1) }
    }

    private func handleDayRolloverIfNeeded(state: AppState) {
        let now = Date()
        let todayKey = AppState.makeDayKey(now)
        guard state.lastDayKey != todayKey else { return }

        state.ensureDailyResetIfNeeded(now: now)
        state.shopRewardResetsToday = 0
        state.eggAdUsedToday = false
        state.lastSyncedAt = Calendar.current.startOfDay(for: now)
    }

    private func failToast(_ message: String) {
        toast(message)
    }

    private func toast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.2)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.2)) { self.showToast = false }
        }
    }

    private func animateShopWalletCountDown(from: Int, to: Int) async {
        let start = max(0, from)
        let end = max(0, to)
        guard end != start else {
            await MainActor.run { self.displayedWalletKcal = end }
            return
        }

        let diff = abs(end - start)
        let duration = min(0.9, max(0.22, Double(diff) * 0.006))
        let fps: Double = 60
        let frames = max(1, Int(duration * fps))

        for i in 0...frames {
            let t = Double(i) / Double(frames)
            let eased = 1 - pow(1 - t, 3)
            let v = start + Int(Double(end - start) * eased)

            await MainActor.run { self.displayedWalletKcal = v }
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / fps))
        }

        await MainActor.run { self.displayedWalletKcal = end }
    }
}
