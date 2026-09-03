//
//  RootView.swift
//  MeMo
//
//  Full RootView with the global mandatory onboarding presenter attached.
//  Based on the current main branch structure.
//  iOS 18.6+
//  お散歩機能の開始ポップアップ・全画面お散歩画面・グローバルリザルト表示を追加。
//  2026/06 update: 起動時の rewardWalkStart / rewardWalkDouble プリロードを廃止.
//  2026/06 update: Home画面上部バナーを廃止し、歩数獲得表示は上部メーターへ吸い込まれる演出に変更。
//  2026/09 update: 期間限定Halloweenイベント入口・報酬通知バッジ・イベント全画面遷移を追加。
//

import SwiftUI
import SwiftData
import UIKit

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var appStates: [AppState]

    @AppStorage(WallpaperCatalog.selectedHomeWallpaperAssetNameKey)
    private var selectedHomeWallpaperAssetName: String =
        WallpaperCatalog.defaultWallpaper.assetName

    @StateObject private var hk = HealthKitManager()
    @StateObject private var viewModel = RootViewModel()
    @State private var onboardingViewModel = MemoOnboardingViewModel()

    @EnvironmentObject private var bgmManager: BGMManager

    @ObservedObject private var walkStore = WalkChallengeStore.shared
    @ObservedObject private var walkWeatherManager = WalkWeatherManager.shared
    @ObservedObject private var walkStartAd = AdMobManager.shared.rewardWalkStart
    @ObservedObject private var halloweenEventStore = Halloween2026EventStore.shared

    @State private var showWalkStartPopup: Bool = false
    @State private var showWalkView: Bool = false
    @State private var showHalloweenEvent: Bool = false
    @State private var walkStartMessage: String?
    @State private var stepGainPopup: StepGainPopupItem?
    @State private var isStepGainPopupAbsorbing: Bool = false
    @State private var stepGainPopupDismissTask: Task<Void, Never>?
    @State private var lastObservedWalletSteps: Int?

    private enum StepGainPopupLayout {
        static let initialTopPadding: CGFloat = 210
        static let absorbOffsetY: CGFloat = -178
        static let absorbScale: CGFloat = 0.22
        static let absorbDelayNanoseconds: UInt64 = 1_350_000_000
        static let absorbDurationNanoseconds: UInt64 = 560_000_000
    }

    private enum HalloweenEntryLayout {
        // HomeViewの既存BottomButtonsと同じ寸法を使用して、4番目（釣り）の真上に置く。
        static let buttonBackgroundSize: CGFloat = 76
        static let buttonSpacing: CGFloat = 16
        static let barHorizontalPadding: CGFloat = 14
        static let outerHorizontalPadding: CGFloat = 18
        static let bottomPadding: CGFloat = 170
    }

    private var isIPadWalkAdFallbackAvailable: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && !walkStartAd.isReady
    }

    var body: some View {
        Group {
            switch hk.authState {
            case .unknown:
                AuthRequestView(
                    onAuthorize: {
                        Task { await viewModel.startAuthorizationIfNeeded(hk: hk) }
                    },
                    errorMessage: hk.errorMessage
                )

            case .denied:
                DeniedView()

            case .authorized:
                if let sharedState = viewModel.sharedState {
                    ZStack(alignment: .top) {
                        HomeView(state: sharedState, hk: hk)

                        halloweenEventHomeEntryLayer

                        MeMoLiveActivityStateObserver(state: sharedState)
                            .frame(width: 0, height: 0)
                            .allowsHitTesting(false)

                        walkStartPopupLayer

                        if let pendingResult = walkStore.pendingResult {
                            WalkResultOverlayView(result: pendingResult) { multiplier in
                                _ = walkStore.claimPendingResult(
                                    multiplier: multiplier,
                                    state: sharedState
                                )
                                saveRootState()
                            }
                            .environmentObject(bgmManager)
                            .zIndex(20_000)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }

                        stepGainPopupLayer
                    }
                    .fullScreenCover(isPresented: $showWalkView) {
                        WalkView(
                            state: sharedState,
                            onSave: { saveRootState() }
                        )
                        .environmentObject(bgmManager)
                        .memoIPadPresentedPhoneCanvas()
                    }
                    .fullScreenCover(isPresented: $showHalloweenEvent) {
                        Halloween2026EventView(
                            state: sharedState,
                            store: halloweenEventStore
                        )
                        .environmentObject(bgmManager)
                        .memoIPadPresentedPhoneCanvas()
                    }
                    .memoOnboardingRoot(
                        state: sharedState,
                        viewModel: onboardingViewModel
                    )
                    .installMeMoWatchBridge(
                        appState: sharedState,
                        healthKitManager: hk,
                        backgroundAssetName: selectedHomeWallpaperAssetName
                    )
                    .onAppear {
                        lastObservedWalletSteps = sharedState.walletSteps
                        walkStore.bootstrap()
                        walkStore.refresh()
                        Task { await walkWeatherManager.refreshRainStatus() }
                        AdMobManager.shared.prepareInterstitialGetIfNeeded(
                            isRewardClaimable: sharedState.nextClaimableHappinessRewardLevel() != nil
                        )
                        Task { @MainActor in
                            await MeMoLiveActivityManager.shared.updateIfNeeded(from: sharedState, force: true)
                        }
                    }
                    .onDisappear {
                        cancelStepGainPopupDismissTask()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .memoShowWalkStart)) { _ in
                        handleWalkMenuRequest()
                    }
                    .onChange(of: sharedState.walletSteps) { oldValue, newValue in
                        handleWalletStepsChange(oldValue: oldValue, newValue: newValue)
                        Task { @MainActor in
                            await MeMoLiveActivityManager.shared.updateImmediately(from: sharedState)
                        }
                    }
                    .onChange(of: sharedState.happinessLevel) { _, _ in
                        AdMobManager.shared.prepareInterstitialGetIfNeeded(
                            isRewardClaimable: sharedState.nextClaimableHappinessRewardLevel() != nil
                        )
                        Task { @MainActor in
                            await MeMoLiveActivityManager.shared.updateImmediately(from: sharedState)
                        }
                    }
                } else {
                    ProgressView()
                }
            }
        }
        .task {
            await viewModel.bootIfNeeded(
                appStates: appStates,
                modelContext: modelContext,
                hk: hk,
                bgmManager: bgmManager
            )
        }
    }

    @ViewBuilder
    private var halloweenEventHomeEntryLayer: some View {
        TimelineView(.periodic(from: Date(), by: 15)) { timeline in
            if EventManager.isActive(.halloween2026, at: timeline.date) {
                HStack(spacing: HalloweenEntryLayout.buttonSpacing) {
                    Color.clear
                        .frame(
                            width: HalloweenEntryLayout.buttonBackgroundSize,
                            height: HalloweenEntryLayout.buttonBackgroundSize
                        )
                        .allowsHitTesting(false)
                    Color.clear
                        .frame(
                            width: HalloweenEntryLayout.buttonBackgroundSize,
                            height: HalloweenEntryLayout.buttonBackgroundSize
                        )
                        .allowsHitTesting(false)
                    Color.clear
                        .frame(
                            width: HalloweenEntryLayout.buttonBackgroundSize,
                            height: HalloweenEntryLayout.buttonBackgroundSize
                        )
                        .allowsHitTesting(false)

                    HalloweenHomeEntryButton(
                        showsNotificationBadge: halloweenEventStore.hasClaimableReward,
                        action: {
                            bgmManager.playSE(.push)
                            guard EventManager.isActive(.halloween2026) else { return }
                            showHalloweenEvent = true
                        }
                    )
                }
                .padding(.horizontal, HalloweenEntryLayout.barHorizontalPadding)
                .padding(.horizontal, HalloweenEntryLayout.outerHorizontalPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, HalloweenEntryLayout.bottomPadding)
                .zIndex(9_000)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
    }

    @ViewBuilder
    private var walkStartPopupLayer: some View {
        if showWalkStartPopup {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(15_000)
                .onTapGesture { closeWalkStartPopup() }

            VStack(spacing: 10) {
                WalkStartPopupView(
                    isRainy: walkWeatherManager.isRainyToday,
                    canUseRainFreeStart: walkStore.canUseRainFreeStart(isRainy: walkWeatherManager.isRainyToday),
                    isAdReady: walkStartAd.isReady,
                    isAdLoading: walkStartAd.isLoading,
                    onLater: { closeWalkStartPopup() },
                    onStartWithAd: { startWalkWithAd() },
                    onStartRainFree: { startWalkRainFree() }
                )

                if let walkStartMessage {
                    Text(walkStartMessage)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.42))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 18)
            .ignoresSafeArea()
            .zIndex(15_001)
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var stepGainPopupLayer: some View {
        if let stepGainPopup {
            StepGainPopupView(amount: stepGainPopup.amount)
                .id(stepGainPopup.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, StepGainPopupLayout.initialTopPadding)
                .offset(y: isStepGainPopupAbsorbing ? StepGainPopupLayout.absorbOffsetY : 0)
                .scaleEffect(isStepGainPopupAbsorbing ? StepGainPopupLayout.absorbScale : 1.0)
                .opacity(isStepGainPopupAbsorbing ? 0.0 : 1.0)
                .allowsHitTesting(false)
                .zIndex(30_000)
                .transition(.scale(scale: 0.82).combined(with: .opacity))
        }
    }

    private func handleWalletStepsChange(oldValue: Int, newValue: Int) {
        let previousValue = lastObservedWalletSteps ?? oldValue
        lastObservedWalletSteps = newValue

        let addedSteps = newValue - previousValue
        guard addedSteps > 0 else { return }

        showStepGainPopup(amount: addedSteps)
    }

    private func showStepGainPopup(amount: Int) {
        let safeAmount = max(0, amount)
        guard safeAmount > 0 else { return }

        cancelStepGainPopupDismissTask()

        let item = StepGainPopupItem(amount: safeAmount)
        isStepGainPopupAbsorbing = false

        withAnimation(.spring(response: 0.26, dampingFraction: 0.68)) {
            stepGainPopup = item
        }

        stepGainPopupDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: StepGainPopupLayout.absorbDelayNanoseconds)
            guard !Task.isCancelled else { return }
            guard stepGainPopup?.id == item.id else { return }

            withAnimation(.easeInOut(duration: 0.56)) {
                isStepGainPopupAbsorbing = true
            }

            try? await Task.sleep(nanoseconds: StepGainPopupLayout.absorbDurationNanoseconds)
            guard !Task.isCancelled else { return }
            guard stepGainPopup?.id == item.id else { return }

            stepGainPopup = nil
            isStepGainPopupAbsorbing = false
            stepGainPopupDismissTask = nil
        }
    }

    private func cancelStepGainPopupDismissTask() {
        stepGainPopupDismissTask?.cancel()
        stepGainPopupDismissTask = nil
    }

    private func handleWalkMenuRequest() {
        walkStore.bootstrap()
        walkStore.refresh()
        walkStartMessage = nil

        if walkStore.isSessionActive {
            closeWalkStartPopup()
            showWalkView = true
            return
        }

        // 2026/06 update: お散歩メニューを開いた時点で rewardWalkStart だけロード。
        AdMobManager.shared.prepareRewardWalkStart()
        Task { await walkWeatherManager.refreshRainStatus() }

        withAnimation(.easeInOut(duration: 0.18)) {
            showWalkStartPopup = true
        }
    }

    private func closeWalkStartPopup() {
        walkStartMessage = nil
        withAnimation(.easeInOut(duration: 0.18)) {
            showWalkStartPopup = false
        }
    }

    private func startWalkRainFree() {
        walkStartMessage = nil
        guard walkStore.startSession(isRainFreeStart: true) else {
            walkStartMessage = "今日はすでに雨の日チャレンジを使用済みです。"
            return
        }

        closeWalkStartPopup()
        showWalkView = true
    }

    private func startWalkWithAd() {
        walkStartMessage = nil

        if isIPadWalkAdFallbackAvailable {
            startWalkWithoutAdForIPadFallback()
            return
        }

        AdMobManager.shared.prepareRewardWalkStart()

        walkStartAd.show(
            onReward: {
                guard walkStore.startSession(isRainFreeStart: false) else {
                    walkStartMessage = "すでにお散歩中です。"
                    showWalkView = true
                    return
                }

                closeWalkStartPopup()
                showWalkView = true
            },
            onUnavailable: {
                walkStartMessage = "広告の準備ができませんでした。少し時間をおいて再度お試しください。"
                AdMobManager.shared.prepareRewardWalkStart()
            }
        )
    }

    private func startWalkWithoutAdForIPadFallback() {
        guard walkStore.startSession(isRainFreeStart: false) else {
            walkStartMessage = "すでにお散歩中です。"
            showWalkView = true
            return
        }

        closeWalkStartPopup()
        showWalkView = true
    }

    private func saveRootState() {
        do {
            try modelContext.save()
        } catch {
            print("RootView save failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Shared views

private struct AuthRequestView: View {
    let onAuthorize: () -> Void
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Health連動が必要です")
                .font(.title2)
                .bold()

            Text("歩数を取得します。\n許可しない場合は利用できません。")
                .multilineTextAlignment(.center)

            Button("許可してはじめる") {
                onAuthorize()
            }
            .buttonStyle(.borderedProminent)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

private struct DeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            Text("Healthの許可が必要です")
                .font(.title2)
                .bold()

            Text("設定アプリで歩数のHealthアクセスを許可してください。\n許可されない場合、このアプリは利用できません。")
                .multilineTextAlignment(.center)

            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

private struct HalloweenHomeEntryButton: View {
    let showsNotificationBadge: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Image("clay_block")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 76, height: 76)

                    VStack(spacing: 1) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 31, weight: .black))
                            .foregroundStyle(Color.orange)

                        Text("EVENT")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                }
                .frame(width: 76, height: 76)

                if showsNotificationBadge {
                    EventNotificationBadge()
                        .offset(x: 3, y: -3)
                }
            }
            .frame(width: 76, height: 76)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
        .accessibilityLabel(
            showsNotificationBadge
                ? "期間限定イベント、受け取り可能な報酬があります"
                : "期間限定イベント"
        )
    }
}

// MARK: - Home Banner / Walk Notifications

extension Notification.Name {
    /// HomeView上部のバナー広告を、Home配下の遷移先画面で一時的に非表示にするための通知。
    /// Home上部バナーは廃止済みのため、既存の遷移先コードとの互換目的で通知名のみ残す。
    static let memoHideHomeBannerAd = Notification.Name("memo.hideHomeBannerAd")

    /// HomeViewへ戻ったタイミングで、HomeView上部のバナー広告を再表示するための通知。
    /// Home上部バナーは廃止済みのため、既存の遷移先コードとの互換目的で通知名のみ残す。
    static let memoShowHomeBannerAd = Notification.Name("memo.showHomeBannerAd")

    /// Homeメニューの「お散歩」ボタンからRootView側の開始ポップアップを開く。
    static let memoShowWalkStart = Notification.Name("memo.showWalkStart")
}
