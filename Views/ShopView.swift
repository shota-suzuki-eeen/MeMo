//
//  ShopView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import SwiftUI
import SwiftData
import UIKit

struct ShopView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var bgmManager: BGMManager
    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false

    let state: AppState
    @StateObject private var viewModel = ShopViewModel()

    // ✅ 購入ポップアップ制御
    @State private var popup: PurchasePopupState = .none

    // ✅ 不足表示の自動消し
    @State private var dismissInsufficientTask: Task<Void, Never>?

    // ✅ Reward_food 用 Rewarded 管理
    // 一旦 AdMob 周りを止めるためコメントアウト
    // @StateObject private var rewardFoodAd = RewardedAdManager(adUnitID: AdUnitID.rewardFood)

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {

                    DailyShopCard(
                        items: viewModel.decodeShopItems(from: state) ?? [],
                        rewardResetsToday: state.shopRewardResetsToday,
                        maxRewardResetsPerDay: 2,
                        isDeveloperMode: isDeveloperMode,
                        ownedCountProvider: { itemID in
                            viewModel.ownedCount(for: itemID, state: state)
                        },
                        onBuyTap: { item in
                            onTapBuy(item)
                        },
                        onRewardReset: {
                            requestRewardResetByAd()
                        }
                    )
                }
                .padding()
                .padding(.top, 6)
            }
            .safeAreaInset(edge: .top) {
                ShopWalletHeader(walletKcal: viewModel.displayedWalletKcal)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .background(.ultraThinMaterial)
            }

            if popup.isPresented {
                PurchasePopupOverlay(
                    popup: $popup,
                    onConfirmBuy: { item in
                        bgmManager.playSE(.buy)
                        viewModel.buyFood(itemID: item.id, state: state)
                        save()
                        popup = .none
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .background(
            ZStack {
                Image("Shop_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.25)
                    .ignoresSafeArea()
            }
        )
        .navigationTitle("ショップ")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.onAppear(state: state)
            save()

            // ✅ AdMob の広告ロードは一旦停止
            // rewardFoodAd.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            viewModel.onAppear(state: state)
            save()

            // ✅ 復帰時の広告再ロードも一旦停止
            // if !rewardFoodAd.isReady {
            //     rewardFoodAd.load()
            // }
        }
        .overlay(alignment: .bottom) {
            if viewModel.showToast, let toastMessage = viewModel.toastMessage {
                ToastView(message: toastMessage)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onDisappear {
            dismissInsufficientTask?.cancel()
            dismissInsufficientTask = nil
        }
    }

    private func onTapBuy(_ item: ShopFoodItem) {
        guard item.stock > 0 else { return }

        bgmManager.playSE(.push)

        guard state.walletKcal >= item.kcal else {
            dismissInsufficientTask?.cancel()
            popup = .insufficient

            dismissInsufficientTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                if case .insufficient = popup {
                    popup = .none
                }
            }

            Haptics.rattle(duration: 0.12, style: .light)
            return
        }

        dismissInsufficientTask?.cancel()
        dismissInsufficientTask = nil
        popup = .confirm(item)
        Haptics.tap(style: .light)
    }

    // ✅ 広告視聴でリセット
    // AdMob を一旦無効化し、開発者モード時のみ広告報酬相当を実行
    private func requestRewardResetByAd() {
        bgmManager.playSE(.push)
        Haptics.tap(style: .light)

        // もう上限なら何もしない（UIでもdisabledだが保険）
        guard state.shopRewardResetsToday < 2 else { return }

        // ✅ 開発者モード中は広告なしで即報酬
        if isDeveloperMode {
            viewModel.rewardResetShopByAd(state: state, maxPerDay: 2)
            save()

            viewModel.toastMessage = "開発者モード: 広告なしでリセットしました！"
            viewModel.showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                viewModel.showToast = false
            }

            Haptics.rattle(duration: 0.18, style: .medium)
            return
        }

        // ✅ AdMob停止中
        viewModel.toastMessage = "広告機能は現在停止中です"
        viewModel.showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            viewModel.showToast = false
        }
    }

    private func save() {
        do { try modelContext.save() } catch { }
    }
}

// MARK: - Popup state

private enum PurchasePopupState: Equatable {
    case none
    case insufficient
    case confirm(ShopFoodItem)

    var isPresented: Bool {
        switch self {
        case .none: return false
        default: return true
        }
    }
}

// MARK: - Fixed wallet header

private struct ShopWalletHeader: View {
    let walletKcal: Int

    var body: some View {
        HStack(spacing: 12) {
            Image("coin_Icon")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)

            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.85))
                    .frame(height: 34)

                Text("\(walletKcal)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.horizontal, 18)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Popup overlay

private struct PurchasePopupOverlay: View {
    @EnvironmentObject private var bgmManager: BGMManager

    @Binding var popup: PurchasePopupState
    let onConfirmBuy: (ShopFoodItem) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    bgmManager.playSE(.push)
                    popup = .none
                }

            switch popup {
            case .none:
                EmptyView()

            case .insufficient:
                Text("所持Kcalが不足しています")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .onTapGesture {
                        bgmManager.playSE(.push)
                        popup = .none
                    }

            case .confirm(let item):
                VStack(spacing: 14) {
                    Text("\(item.name) を購入しますか？")
                        .font(.system(size: 18, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        Button("キャンセル") {
                            bgmManager.playSE(.push)
                            popup = .none
                            Haptics.tap(style: .light)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white.opacity(0.85))

                        Button("購入") {
                            bgmManager.playSE(.push)
                            onConfirmBuy(item)
                            Haptics.tap(style: .medium)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(18)
                .background(Color.black.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 28)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: popup.isPresented)
    }
}

// MARK: - Daily shop UI

private struct DailyShopCard: View {
    let items: [ShopFoodItem]
    let rewardResetsToday: Int
    let maxRewardResetsPerDay: Int
    let isDeveloperMode: Bool

    let ownedCountProvider: (String) -> Int
    let onBuyTap: (ShopFoodItem) -> Void
    let onRewardReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("デイリーショップ").font(.headline)
                Spacer()
                Text("リセット \(rewardResetsToday)/\(maxRewardResetsPerDay)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("毎日 00:00 更新 / 6品")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if items.isEmpty {
                Text("ラインナップを生成中...")
                    .font(.title3).bold()
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            let asset = FoodCatalog.byId(item.id)?.assetName
                            if let asset {
                                Image(asset)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 34, height: 34)
                                    .padding(6)
                                    .background(Color.white.opacity(0.18))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.black.opacity(0.35), lineWidth: 1)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name).font(.headline)
                                Text("\(item.kcal) kcal")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            let owned = ownedCountProvider(item.id)
                            Text("所持\(owned)")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())

                            Button("購入") {
                                onBuyTap(item)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(item.stock == 0)
                            .opacity(item.stock == 0 ? 0.6 : 1.0)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }

            HStack(spacing: 10) {
                Button(isDeveloperMode ? "開発者モードでリセット" : "広告でリセット") {
                    onRewardReset()
                }
                .buttonStyle(.bordered)
                .disabled(rewardResetsToday >= maxRewardResetsPerDay)
            }

            Text("※ リセットで「再抽選＋全在庫1に戻す」")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Toast view

private struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .shadow(radius: 8)
    }
}
