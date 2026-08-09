//
//  ShopView.swift
//  MeMo
//
//  釣り具の強化と、フィッシュポイントによるアイテム・壁紙交換を提供するショップ画面。
//

import SwiftUI
import SwiftData
import UIKit

struct ShopView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var bgmManager: BGMManager

    @Query private var appStates: [AppState]
    @ObservedObject private var fishingStore = FishingStore.shared

    @AppStorage(WallpaperCatalog.selectedHomeWallpaperAssetNameKey)
    private var selectedHomeWallpaperAssetName: String = WallpaperCatalog.defaultWallpaper.assetName

    @State private var selectedCategory: FishingShopCategory = .gear
    @State private var presentedExchangeModal: FishingShopExchangeModal?
    @State private var presentedGearUpgradeModal: FishingGearUpgradeModal?

    private let itemOffers = FishingItemOffer.defaultOffers
    private let wallpaperOffers = FishingWallpaperOffer.defaultOffers

    private var appState: AppState? {
        appStates.first
    }

    private var isModalPresented: Bool {
        presentedExchangeModal != nil || presentedGearUpgradeModal != nil
    }

    var body: some View {
        GeometryReader { geo in
            let windowSafeAreaTop = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: { $0.isKeyWindow })?
                .safeAreaInsets.top ?? 0
            let resolvedSafeAreaTop = max(geo.safeAreaInsets.top, windowSafeAreaTop)

            ZStack {
                FishingExchangeBackground()

                VStack(spacing: 14) {
                    header
                        .padding(.horizontal, 18)

                    shopBackgroundImage

                    categoryPicker
                        .padding(.horizontal, 18)

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            switch selectedCategory {
                            case .gear:
                                ForEach(FishingGearKind.allCases) { gear in
                                    gearCard(gear)
                                }

                            case .item:
                                ForEach(itemOffers) { offer in
                                    itemCard(offer)
                                }

                            case .wallpaper:
                                ForEach(wallpaperOffers) { offer in
                                    wallpaperCard(offer)
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 2)
                        .padding(.bottom, 12)
                    }
                }
                .padding(.top, max(resolvedSafeAreaTop, 54) + 22)
                .padding(.bottom, max(geo.safeAreaInsets.bottom, 18))
                .allowsHitTesting(!isModalPresented)

                if let presentedExchangeModal {
                    exchangeModalOverlay(presentedExchangeModal)
                        .zIndex(10_000)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }

                if let presentedGearUpgradeModal {
                    gearUpgradeModalOverlay(presentedGearUpgradeModal)
                        .zIndex(10_000)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.easeInOut(duration: 0.18), value: presentedExchangeModal?.id)
            .animation(.easeInOut(duration: 0.18), value: presentedGearUpgradeModal?.id)
        }
        .ignoresSafeArea()
        .onAppear {
            bgmManager.switchBackground(to: .main)
            fishingStore.refresh(now: Date())
        }
        .onDisappear {
            bgmManager.restoreDefaultBackground()
        }
    }

    private var header: some View {
        ZStack {
            HStack(spacing: 12) {
                Button {
                    bgmManager.playSE(.push)
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.42), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("釣り画面へ戻る")

                Spacer()

                balancePill
            }

            Text("ショップ")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .shadow(color: .black.opacity(0.38), radius: 4, x: 0, y: 2)
                .allowsHitTesting(false)
        }
        .frame(minHeight: 48)
    }

    @ViewBuilder
    private var balancePill: some View {
        if selectedCategory == .gear {
            stepBalancePill
        } else {
            pointBalancePill
        }
    }

    private var stepBalancePill: some View {
        let steps = max(0, appState?.walletSteps ?? 0)

        return HStack(spacing: 7) {
            Image(systemName: "figure.walk")
                .font(.system(size: 15, weight: .black))

            Text("\(steps)歩")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background(Color.black.opacity(0.48), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.32), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("所持歩数 \(steps)歩")
    }

    private var pointBalancePill: some View {
        HStack(spacing: 7) {
            Image(systemName: "fish.fill")
                .font(.system(size: 15, weight: .black))

            Text("\(fishingStore.pointBalance) pt")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background(Color.black.opacity(0.48), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.32), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("所持フィッシュポイント \(fishingStore.pointBalance)ポイント")
    }

    private var shopBackgroundImage: some View {
        Image("shop_background")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .frame(height: 176)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.48)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .overlay {
                Rectangle()
                    .stroke(Color.white.opacity(0.34), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 7)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var categoryPicker: some View {
        HStack(spacing: 10) {
            ForEach(FishingShopCategory.allCases) { category in
                Button {
                    guard selectedCategory != category else { return }
                    bgmManager.playSE(.push)

                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedCategory = category
                    }
                } label: {
                    Text(category.title)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(selectedCategory == category ? Color.white : Color.primary)
                        .frame(minWidth: 82, minHeight: 36)
                        .padding(.horizontal, 4)
                        .background(
                            selectedCategory == category
                                ? Color(red: 0.10, green: 0.63, blue: 0.88)
                                : Color.white.opacity(0.78),
                            in: Capsule()
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Fishing gear

    private func gearCard(_ gear: FishingGearKind) -> some View {
        let level = fishingStore.level(for: gear)
        let nextLevel = level + 1
        let price = fishingStore.nextUpgradeCost(for: gear)
        let isMaximum = fishingStore.isMaximumLevel(gear)
        let canAfford = price.map { (appState?.walletSteps ?? 0) >= $0 } ?? false

        return HStack(spacing: 14) {
            Image(gear.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 86, height: 86)
                .padding(8)
                .background(Color.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(gear.displayName)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("Lv.\(level)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.56), in: Capsule())
                        .monospacedDigit()
                }

                Text(gearStatusText(gear, level: level))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                if !isMaximum {
                    HStack(spacing: 4) {
                        Text("次のLv:")

                        Text(gearStatusText(gear, level: nextLevel))
                            .monospacedDigit()
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                } else {
                    Text("強化完了")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)

            Button {
                requestGearUpgrade(gear)
            } label: {
                VStack(spacing: 3) {
                    if let price {
                        Text("Lvアップ")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                        Text("\(price)歩")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .monospacedDigit()
                    } else {
                        Text("完了")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                    }
                }
                .foregroundStyle(.white)
                .frame(minWidth: 78, minHeight: 48)
                .background(
                    isMaximum
                        ? Color.gray
                        : (canAfford ? Color(red: 0.10, green: 0.63, blue: 0.88) : Color.gray),
                    in: Capsule()
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isMaximum)
            .accessibilityLabel(
                isMaximum
                    ? "\(gear.displayName)は強化完了"
                    : "\(gear.displayName)を\(price ?? 0)歩で強化"
            )
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.30), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 6)
    }

    private func gearStatusText(_ gear: FishingGearKind, level: Int) -> String {
        switch gear {
        case .rod:
            return "1タップ  -\(fishingStore.tapShortenSeconds(at: level))秒"

        case .bobber:
            return String(format: "毎秒  -%.2f秒", fishingStore.timeProgressMultiplier(at: level))

        case .basket:
            return "最大  \(fishingStore.basketCapacity(at: level))匹"
        }
    }

    private func requestGearUpgrade(_ gear: FishingGearKind) {
        bgmManager.playSE(.push)

        guard let price = fishingStore.nextUpgradeCost(for: gear) else {
            presentedGearUpgradeModal = .maximum(gear)
            return
        }

        guard let appState else {
            presentedGearUpgradeModal = .failed(gear)
            return
        }

        let shortage = max(0, price - max(0, appState.walletSteps))
        guard shortage == 0 else {
            presentedGearUpgradeModal = .insufficient(gear, shortage: shortage)
            return
        }

        presentedGearUpgradeModal = .confirmation(
            gear,
            price: price,
            remainingSteps: max(0, appState.walletSteps - price)
        )
    }

    private func completeGearUpgrade(_ gear: FishingGearKind, expectedPrice: Int) {
        guard let appState else {
            presentedGearUpgradeModal = .failed(gear)
            return
        }

        guard let currentPrice = fishingStore.nextUpgradeCost(for: gear),
              currentPrice == expectedPrice
        else {
            presentedGearUpgradeModal = fishingStore.isMaximumLevel(gear) ? .maximum(gear) : .failed(gear)
            return
        }

        let shortage = max(0, currentPrice - max(0, appState.walletSteps))
        guard shortage == 0 else {
            presentedGearUpgradeModal = .insufficient(gear, shortage: shortage)
            return
        }

        // SwiftData側の歩数を先に確定し、保存に失敗した場合は釣り具レベルを上げない。
        appState.walletSteps = max(0, appState.walletSteps - currentPrice)

        do {
            try modelContext.save()
        } catch {
            appState.walletSteps += currentPrice
            try? modelContext.save()
            presentedGearUpgradeModal = .failed(gear)
            return
        }

        guard fishingStore.upgrade(gear, now: Date()) else {
            appState.walletSteps += currentPrice
            try? modelContext.save()
            presentedGearUpgradeModal = .failed(gear)
            return
        }

        bgmManager.playSE(.push)
        presentedGearUpgradeModal = .upgraded(
            gear,
            level: fishingStore.level(for: gear),
            remainingSteps: max(0, appState.walletSteps)
        )
    }

    // MARK: - Item cards

    private func itemCard(_ offer: FishingItemOffer) -> some View {
        let canAfford = fishingStore.pointBalance >= offer.price

        return HStack(spacing: 14) {
            Image(offer.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 86, height: 86)
                .padding(8)
                .background(Color.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 6) {
                Text(offer.name)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Text(offer.detailText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Image(systemName: "fish.fill")
                    Text("\(offer.price) pt")
                        .monospacedDigit()
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.secondary)

                Text("現在の所持数：\(currentOwnedText(for: offer))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)

            VStack(spacing: 10) {
                Button {
                    bgmManager.playSE(.push)
                    presentedExchangeModal = .information(offer)
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.secondary.opacity(0.72))
                        .frame(width: 34, height: 34)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(offer.name)の情報を表示")

                Spacer(minLength: 2)

                Button {
                    requestExchange(.item(offer))
                } label: {
                    Text("交換")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white)
                        .frame(minWidth: 74, minHeight: 42)
                        .background(
                            canAfford
                                ? Color(red: 0.10, green: 0.63, blue: 0.88)
                                : Color.gray,
                            in: Capsule()
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(offer.name)を\(offer.price)ポイントで交換")
                .accessibilityHint(
                    canAfford
                        ? "交換内容を確認します"
                        : "不足しているポイント数を表示します"
                )
            }
            .frame(minHeight: 102)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.30), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 6)
    }

    private func currentOwnedText(for offer: FishingItemOffer) -> String {
        guard let appState else {
            switch offer.reward {
            case .steps:
                return "0歩"
            case .food, .toilet:
                return "0個"
            }
        }

        switch offer.reward {
        case .food(let foodID, _):
            return "\(appState.foodCount(foodId: foodID))個"

        case .toilet:
            return "\(appState.gachaSpecialItemCount(id: "wc"))個"

        case .steps:
            return "\(max(0, appState.walletSteps))歩"
        }
    }

    // MARK: - Wallpaper cards

    private func wallpaperCard(_ offer: FishingWallpaperOffer) -> some View {
        let isUnlocked = fishingStore.isWallpaperUnlocked(assetName: offer.wallpaper.assetName)
        let isSelected = selectedHomeWallpaperAssetName == offer.wallpaper.assetName
        let canAfford = fishingStore.pointBalance >= offer.price

        return VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Image(offer.wallpaper.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 190)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .allowsHitTesting(false)

                if isUnlocked {
                    Text(isSelected ? "使用中" : "取得済み")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.green : Color.black.opacity(0.64), in: Capsule())
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(offer.wallpaper.name)
                        .font(.system(size: 19, weight: .black, design: .rounded))

                    HStack(spacing: 6) {
                        Image(systemName: "fish.fill")
                        Text("\(offer.price) pt")
                            .monospacedDigit()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                }
                .allowsHitTesting(false)

                Spacer(minLength: 8)

                if isUnlocked {
                    Button {
                        bgmManager.playSE(.push)
                        selectedHomeWallpaperAssetName = offer.wallpaper.assetName
                    } label: {
                        Text(isSelected ? "設定中" : "設定する")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.white)
                            .frame(minWidth: 84, minHeight: 42)
                            .background(isSelected ? Color.gray : Color.green, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSelected)
                    .accessibilityLabel(
                        isSelected
                            ? "\(offer.wallpaper.name)を設定中"
                            : "\(offer.wallpaper.name)を壁紙に設定"
                    )
                } else {
                    Button {
                        requestExchange(.wallpaper(offer))
                    } label: {
                        Text("交換")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.white)
                            .frame(minWidth: 84, minHeight: 42)
                            .background(
                                canAfford
                                    ? Color(red: 0.10, green: 0.63, blue: 0.88)
                                    : Color.gray,
                                in: Capsule()
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(offer.wallpaper.name)を\(offer.price)ポイントで交換")
                    .accessibilityHint(
                        canAfford
                            ? "交換内容を確認します"
                            : "不足しているポイント数を表示します"
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.30), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.17), radius: 10, x: 0, y: 6)
    }

    // MARK: - Existing fish-point exchange

    private func requestExchange(_ target: FishingShopExchangeTarget) {
        bgmManager.playSE(.push)

        if case .wallpaper(let offer) = target,
           fishingStore.isWallpaperUnlocked(assetName: offer.wallpaper.assetName) {
            presentedExchangeModal = .alreadyOwned(offer)
            return
        }

        let shortage = max(0, target.price - fishingStore.pointBalance)
        guard shortage == 0 else {
            presentedExchangeModal = .insufficient(target, shortage: shortage)
            return
        }

        if case .item = target, appState == nil {
            presentedExchangeModal = .failed(target)
            return
        }

        presentedExchangeModal = .confirmation(
            target,
            remainingBalance: max(0, fishingStore.pointBalance - target.price)
        )
    }

    private func completeExchange(_ target: FishingShopExchangeTarget) {
        switch target {
        case .wallpaper(let offer):
            completeWallpaperExchange(offer)

        case .item(let offer):
            completeItemExchange(offer)
        }
    }

    private func completeWallpaperExchange(_ offer: FishingWallpaperOffer) {
        guard !fishingStore.isWallpaperUnlocked(assetName: offer.wallpaper.assetName) else {
            presentedExchangeModal = .alreadyOwned(offer)
            return
        }

        let shortage = max(0, offer.price - fishingStore.pointBalance)
        guard shortage == 0 else {
            presentedExchangeModal = .insufficient(.wallpaper(offer), shortage: shortage)
            return
        }

        guard fishingStore.exchangeWallpaper(
            assetName: offer.wallpaper.assetName,
            price: offer.price
        ) else {
            presentedExchangeModal = .failed(.wallpaper(offer))
            return
        }

        bgmManager.playSE(.push)
        presentedExchangeModal = .exchanged(
            .wallpaper(offer),
            remainingBalance: fishingStore.pointBalance
        )
    }

    private func completeItemExchange(_ offer: FishingItemOffer) {
        guard let appState else {
            presentedExchangeModal = .failed(.item(offer))
            return
        }

        let shortage = max(0, offer.price - fishingStore.pointBalance)
        guard shortage == 0 else {
            presentedExchangeModal = .insufficient(.item(offer), shortage: shortage)
            return
        }

        guard consumeFishingPointsForItem(price: offer.price) else {
            presentedExchangeModal = .failed(.item(offer))
            return
        }

        let didGrantReward: Bool

        switch offer.reward {
        case .food(let foodID, let count):
            didGrantReward = appState.addFood(foodId: foodID, count: count)

        case .toilet(let count):
            didGrantReward = appState.gachaAddSpecialItem(id: "wc", count: count)

        case .steps(let amount):
            didGrantReward = appState.addWalletSteps(amount) == amount
        }

        guard didGrantReward else {
            presentedExchangeModal = .failed(.item(offer))
            return
        }

        try? modelContext.save()

        bgmManager.playSE(.push)
        presentedExchangeModal = .exchanged(
            .item(offer),
            remainingBalance: fishingStore.pointBalance
        )
    }

    /// FishingStoreの既存APIでは壁紙交換のみがポイント消費を担当しているため、
    /// 一意な一時IDで消費処理を通し、直後に壁紙解放リストから一時IDを除去する。
    /// pointBalanceのPublished更新と永続化はFishingStore側で一貫して行われる。
    private func consumeFishingPointsForItem(price: Int) -> Bool {
        let safePrice = max(0, price)
        guard safePrice > 0 else { return false }

        let temporaryAssetName = "__memo_shop_item_transaction__\(UUID().uuidString)"

        guard fishingStore.exchangeWallpaper(
            assetName: temporaryAssetName,
            price: safePrice
        ) else {
            return false
        }

        let defaults = UserDefaults.standard
        let key = WallpaperCatalog.focusUnlockedRewardAssetNamesKey
        var unlockedAssetNames = Set(defaults.stringArray(forKey: key) ?? [])
        unlockedAssetNames.remove(temporaryAssetName)
        defaults.set(Array(unlockedAssetNames).sorted(), forKey: key)

        return true
    }

    // MARK: - Gear upgrade modal

    @ViewBuilder
    private func gearUpgradeModalOverlay(_ modal: FishingGearUpgradeModal) -> some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    presentedGearUpgradeModal = nil
                }

            VStack(spacing: 18) {
                Image(systemName: modal.iconName)
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(modal.iconTint)

                VStack(spacing: 8) {
                    Text(modal.title)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(modal.message)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                gearUpgradeModalButtons(modal)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.38), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 14)
            .padding(.horizontal, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func gearUpgradeModalButtons(_ modal: FishingGearUpgradeModal) -> some View {
        switch modal {
        case .confirmation(let gear, let price, _):
            VStack(spacing: 10) {
                Button {
                    completeGearUpgrade(gear, expectedPrice: price)
                } label: {
                    Text("\(price)歩で強化")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color(red: 0.10, green: 0.63, blue: 0.88), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    presentedGearUpgradeModal = nil
                } label: {
                    Text("キャンセル")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }

        case .upgraded, .insufficient, .maximum, .failed:
            Button {
                presentedGearUpgradeModal = nil
            } label: {
                Text("閉じる")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color.secondary, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Existing exchange modal

    @ViewBuilder
    private func exchangeModalOverlay(_ modal: FishingShopExchangeModal) -> some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    presentedExchangeModal = nil
                }

            VStack(spacing: 18) {
                modalIcon(modal)

                VStack(spacing: 8) {
                    Text(modal.title)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(modal.message)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                modalButtons(modal)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.38), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 14)
            .padding(.horizontal, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func modalIcon(_ modal: FishingShopExchangeModal) -> some View {
        let iconName: String
        let tint: Color

        switch modal {
        case .information:
            iconName = "info.circle.fill"
            tint = Color(red: 0.10, green: 0.63, blue: 0.88)

        case .confirmation:
            iconName = "arrow.left.arrow.right.circle.fill"
            tint = Color(red: 0.10, green: 0.63, blue: 0.88)

        case .exchanged:
            iconName = "checkmark.circle.fill"
            tint = .green

        case .insufficient:
            iconName = "exclamationmark.circle.fill"
            tint = .orange

        case .alreadyOwned:
            iconName = "checkmark.seal.fill"
            tint = .green

        case .failed:
            iconName = "xmark.circle.fill"
            tint = .red
        }

        return Image(systemName: iconName)
            .font(.system(size: 46, weight: .bold))
            .foregroundStyle(tint)
    }

    @ViewBuilder
    private func modalButtons(_ modal: FishingShopExchangeModal) -> some View {
        switch modal {
        case .information:
            closeModalButton

        case .confirmation(let target, _):
            VStack(spacing: 10) {
                Button {
                    completeExchange(target)
                } label: {
                    Text("\(target.price) ptで交換")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color(red: 0.10, green: 0.63, blue: 0.88), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    presentedExchangeModal = nil
                } label: {
                    Text("キャンセル")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }

        case .exchanged(let target, _):
            switch target {
            case .wallpaper(let offer):
                VStack(spacing: 10) {
                    Button {
                        selectedHomeWallpaperAssetName = offer.wallpaper.assetName
                        presentedExchangeModal = nil
                    } label: {
                        Text("この壁紙にする")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.green, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        presentedExchangeModal = nil
                    } label: {
                        Text("あとで設定")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }

            case .item:
                closeModalButton
            }

        case .alreadyOwned(let offer):
            VStack(spacing: 10) {
                Button {
                    selectedHomeWallpaperAssetName = offer.wallpaper.assetName
                    presentedExchangeModal = nil
                } label: {
                    Text("この壁紙にする")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.green, in: Capsule())
                }
                .buttonStyle(.plain)

                closeModalButton
            }

        case .insufficient, .failed:
            closeModalButton
        }
    }

    private var closeModalButton: some View {
        Button {
            presentedExchangeModal = nil
        } label: {
            Text("閉じる")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color.secondary, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private enum FishingShopCategory: String, CaseIterable, Identifiable {
    case gear
    case item
    case wallpaper

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gear:
            return "釣り具"
        case .item:
            return "アイテム"
        case .wallpaper:
            return "壁紙"
        }
    }
}

private enum FishingGearUpgradeModal: Identifiable {
    case confirmation(FishingGearKind, price: Int, remainingSteps: Int)
    case upgraded(FishingGearKind, level: Int, remainingSteps: Int)
    case insufficient(FishingGearKind, shortage: Int)
    case maximum(FishingGearKind)
    case failed(FishingGearKind)

    var id: String {
        switch self {
        case .confirmation(let gear, let price, _):
            return "gear.confirmation.\(gear.id).\(price)"
        case .upgraded(let gear, let level, _):
            return "gear.upgraded.\(gear.id).\(level)"
        case .insufficient(let gear, let shortage):
            return "gear.insufficient.\(gear.id).\(shortage)"
        case .maximum(let gear):
            return "gear.maximum.\(gear.id)"
        case .failed(let gear):
            return "gear.failed.\(gear.id)"
        }
    }

    var title: String {
        switch self {
        case .confirmation(let gear, _, _):
            return "\(gear.displayName)を強化しますか？"
        case .upgraded(let gear, _, _):
            return "\(gear.displayName)を強化しました"
        case .insufficient:
            return "歩数が足りません"
        case .maximum(let gear):
            return "\(gear.displayName)は強化完了です"
        case .failed:
            return "強化できませんでした"
        }
    }

    var message: String {
        switch self {
        case .confirmation(let gear, let price, let remainingSteps):
            return "\(price)歩を消費して\(gear.displayName)を1レベル強化します。\n強化後の所持歩数：\(remainingSteps)歩"

        case .upgraded(let gear, let level, let remainingSteps):
            return "\(gear.displayName)がLv.\(level)になりました。\n残りの所持歩数：\(remainingSteps)歩"

        case .insufficient(let gear, let shortage):
            return "\(gear.displayName)の強化には、あと\(shortage)歩必要です。"

        case .maximum:
            return "これ以上は強化できません。"

        case .failed(let gear):
            return "\(gear.displayName)の強化処理を完了できませんでした。所持歩数を確認して、もう一度お試しください。"
        }
    }

    var iconName: String {
        switch self {
        case .confirmation:
            return "arrow.up.circle.fill"
        case .upgraded:
            return "checkmark.circle.fill"
        case .insufficient:
            return "exclamationmark.circle.fill"
        case .maximum:
            return "checkmark.seal.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }

    var iconTint: Color {
        switch self {
        case .confirmation:
            return Color(red: 0.10, green: 0.63, blue: 0.88)
        case .upgraded, .maximum:
            return .green
        case .insufficient:
            return .orange
        case .failed:
            return .red
        }
    }
}

private enum FishingShopReward: Hashable {
    case food(foodID: String, count: Int)
    case toilet(count: Int)
    case steps(amount: Int)
}

private struct FishingItemOffer: Identifiable, Hashable {
    let id: String
    let name: String
    let assetName: String
    let detailText: String
    let informationText: String
    let price: Int
    let reward: FishingShopReward

    static let defaultOffers: [FishingItemOffer] = [
        FishingItemOffer(
            id: "yakiniku",
            name: "焼肉定食",
            assetName: "food_yakiniku",
            detailText: "SPの焼肉定食を1個獲得します。",
            informationText: "お腹が空いている時に食べさせてあげると一個で満腹になり、幸せ度を25pt獲得できるスペシャルなご飯。月一で食べたくなるよね...",
            price: 150,
            reward: .food(foodID: "yakiniku", count: 1)
        ),
        FishingItemOffer(
            id: "wc",
            name: "トイレ",
            assetName: "wc",
            detailText: "既存のトイレアイテムを1個獲得します。",
            informationText: "消費することで一発でうんちを掃除してくれる必需品。現実にも欲しすぎる。",
            price: 50,
            reward: .toilet(count: 1)
        ),
        FishingItemOffer(
            id: "steps500",
            name: "歩数",
            assetName: "shoes",
            detailText: "所持歩数を500歩追加します。",
            informationText: "500歩分の歩数を獲得できる。今日はご褒美で楽してガチャしよう！",
            price: 100,
            reward: .steps(amount: 500)
        )
    ]
}

private enum FishingShopExchangeTarget: Identifiable, Hashable {
    case item(FishingItemOffer)
    case wallpaper(FishingWallpaperOffer)

    var id: String {
        switch self {
        case .item(let offer):
            return "item.\(offer.id)"
        case .wallpaper(let offer):
            return "wallpaper.\(offer.id)"
        }
    }

    var name: String {
        switch self {
        case .item(let offer):
            return offer.name
        case .wallpaper(let offer):
            return offer.wallpaper.name
        }
    }

    var price: Int {
        switch self {
        case .item(let offer):
            return offer.price
        case .wallpaper(let offer):
            return offer.price
        }
    }

    var exchangeNoun: String {
        switch self {
        case .item:
            return "アイテム"
        case .wallpaper:
            return "壁紙"
        }
    }
}

private enum FishingShopExchangeModal: Identifiable {
    case information(FishingItemOffer)
    case confirmation(FishingShopExchangeTarget, remainingBalance: Int)
    case exchanged(FishingShopExchangeTarget, remainingBalance: Int)
    case insufficient(FishingShopExchangeTarget, shortage: Int)
    case alreadyOwned(FishingWallpaperOffer)
    case failed(FishingShopExchangeTarget)

    var id: String {
        switch self {
        case .information(let offer):
            return "information.\(offer.id)"
        case .confirmation(let target, _):
            return "confirmation.\(target.id)"
        case .exchanged(let target, _):
            return "exchanged.\(target.id)"
        case .insufficient(let target, _):
            return "insufficient.\(target.id)"
        case .alreadyOwned(let offer):
            return "alreadyOwned.\(offer.id)"
        case .failed(let target):
            return "failed.\(target.id)"
        }
    }

    var title: String {
        switch self {
        case .information(let offer):
            return offer.name
        case .confirmation(let target, _):
            return "\(target.exchangeNoun)と交換しますか？"
        case .exchanged(let target, _):
            return "\(target.exchangeNoun)と交換しました"
        case .insufficient:
            return "ポイントが足りません"
        case .alreadyOwned:
            return "取得済みの壁紙です"
        case .failed:
            return "交換できませんでした"
        }
    }

    var message: String {
        switch self {
        case .information(let offer):
            return offer.informationText
                .replacingOccurrences(of: "。", with: "。\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

        case .confirmation(let target, let remainingBalance):
            return "「\(target.name)」と交換します。\n交換後の残高は\(remainingBalance) ptです。"

        case .exchanged(let target, let remainingBalance):
            return "「\(target.name)」を取得しました。\n残りのフィッシュポイント：\(remainingBalance) pt"

        case .insufficient(let target, let shortage):
            return "「\(target.name)」との交換には、あと\(shortage) pt必要です。"

        case .alreadyOwned(let offer):
            return "「\(offer.wallpaper.name)」はすでに取得しています。"

        case .failed(let target):
            return "「\(target.name)」との交換処理を完了できませんでした。ポイント残高を確認して、もう一度お試しください。"
        }
    }
}

struct FishingWallpaperOffer: Identifiable, Hashable {
    let wallpaper: WallpaperCatalog.WallpaperItem
    let price: Int

    var id: String { wallpaper.id }

    static let defaultOffers: [FishingWallpaperOffer] = [
        make(assetName: "field_background", price: 100),
        make(assetName: "concrete_background", price: 250),
        make(assetName: "japanese_background", price: 450),
        make(assetName: "office_background", price: 700),
        make(assetName: "bath_background", price: 1_000),
        make(assetName: "beach_background", price: 1_500)
    ].compactMap { $0 }

    private static func make(assetName: String, price: Int) -> FishingWallpaperOffer? {
        guard let wallpaper = WallpaperCatalog.item(for: assetName) else { return nil }
        return FishingWallpaperOffer(wallpaper: wallpaper, price: max(0, price))
    }
}

private struct FishingExchangeBackground: View {
    var body: some View {
        ZStack {
            Image("fishing_background")
                .resizable()
                .scaledToFill()
                .blur(radius: 3)
                .scaleEffect(1.02)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.20),
                    Color.black.opacity(0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
