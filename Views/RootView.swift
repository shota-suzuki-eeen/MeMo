//
//  RootView.swift
//  MeMo
//
//  Full RootView with the global mandatory onboarding presenter attached.
//  Based on the current main branch structure.
//  iOS 18.6+
//  お散歩機能の開始ポップアップ・全画面お散歩画面・グローバルリザルト表示を追加。
//

import SwiftUI
import SwiftData
import UIKit

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var appStates: [AppState]

    @StateObject private var hk = HealthKitManager()
    @StateObject private var viewModel = RootViewModel()
    @State private var onboardingViewModel = MemoOnboardingViewModel()

    @EnvironmentObject private var bgmManager: BGMManager

    @ObservedObject private var walkStore = WalkChallengeStore.shared
    @ObservedObject private var walkWeatherManager = WalkWeatherManager.shared
    @ObservedObject private var walkStartAd = AdMobManager.shared.rewardWalkStart

    @State private var isHomeBannerHiddenByChildScreen: Bool = false
    @State private var isHomeNavigationDestinationVisible: Bool = false
    @State private var showWalkStartPopup: Bool = false
    @State private var showWalkView: Bool = false
    @State private var walkStartMessage: String?
    @State private var stepGainPopup: StepGainPopupItem?
    @State private var stepGainPopupDismissTask: Task<Void, Never>?
    @State private var lastObservedWalletSteps: Int?

    private enum HomeBannerLayout {
        static let height: CGFloat = 50
        static let maxWidth: CGFloat = 320
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

                        HomeNavigationDepthReader { depth in
                            let nextValue = depth > 1

                            DispatchQueue.main.async {
                                guard isHomeNavigationDestinationVisible != nextValue else { return }
                                isHomeNavigationDestinationVisible = nextValue
                            }
                        }
                        .frame(width: 0, height: 0)
                        .allowsHitTesting(false)

                        if !isHomeBannerHiddenByChildScreen && !isHomeNavigationDestinationVisible {
                            AdBannerView(
                                placement: .home,
                                height: HomeBannerLayout.height,
                                maxBannerWidth: HomeBannerLayout.maxWidth,
                                contentHeight: HomeBannerLayout.height,
                                topOffset: 0
                            )
                            .allowsHitTesting(false)
                            .zIndex(10_000)
                            .transition(.opacity)
                        }

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
                    .memoOnboardingRoot(
                        state: sharedState,
                        viewModel: onboardingViewModel
                    )
                    .onAppear {
                        isHomeBannerHiddenByChildScreen = false
                        lastObservedWalletSteps = sharedState.walletSteps
                        walkStore.bootstrap()
                        walkStore.refresh()
                        AdMobManager.shared.prepareRewardWalkStart()
                        AdMobManager.shared.prepareRewardWalkDouble()
                        Task { await walkWeatherManager.refreshRainStatus() }
                        AdMobManager.shared.prepareInterstitialGetIfNeeded(
                            isRewardClaimable: sharedState.nextClaimableHappinessRewardLevel() != nil
                        )
                    }
                    .onDisappear {
                        cancelStepGainPopupDismissTask()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .memoShowWalkStart)) { _ in
                        handleWalkMenuRequest()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .memoHideHomeBannerAd)) { _ in
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isHomeBannerHiddenByChildScreen = true
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .memoShowHomeBannerAd)) { _ in
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isHomeBannerHiddenByChildScreen = false
                        }
                    }
                    .onChange(of: sharedState.walletSteps) { oldValue, newValue in
                        handleWalletStepsChange(oldValue: oldValue, newValue: newValue)
                    }
                    .onChange(of: sharedState.happinessLevel) { _, _ in
                        AdMobManager.shared.prepareInterstitialGetIfNeeded(
                            isRewardClaimable: sharedState.nextClaimableHappinessRewardLevel() != nil
                        )
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
                .padding(.top, 210)
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
        withAnimation(.spring(response: 0.26, dampingFraction: 0.68)) {
            stepGainPopup = item
        }

        stepGainPopupDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            guard stepGainPopup?.id == item.id else { return }

            withAnimation(.easeOut(duration: 0.35)) {
                stepGainPopup = nil
            }
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

// MARK: - Home Banner / Walk Notifications

extension Notification.Name {
    /// HomeView上部のバナー広告を、Home配下の遷移先画面で一時的に非表示にするための通知。
    static let memoHideHomeBannerAd = Notification.Name("memo.hideHomeBannerAd")

    /// HomeViewへ戻ったタイミングで、HomeView上部のバナー広告を再表示するための通知。
    static let memoShowHomeBannerAd = Notification.Name("memo.showHomeBannerAd")

    /// HomeView の menu_button 内 walk_button から、お散歩開始ポップアップを表示するための通知。
    static let memoShowWalkStart = Notification.Name("memo.showWalkStart")
}

// MARK: - Navigation Depth Reader

private struct HomeNavigationDepthReader: UIViewControllerRepresentable {
    var onDepthChange: (Int) -> Void

    func makeUIViewController(context: Context) -> ObserverViewController {
        let controller = ObserverViewController()
        controller.onDepthChange = onDepthChange
        return controller
    }

    func updateUIViewController(_ uiViewController: ObserverViewController, context: Context) {
        uiViewController.onDepthChange = onDepthChange
        uiViewController.startMonitoringIfNeeded()
    }

    final class ObserverViewController: UIViewController {
        var onDepthChange: ((Int) -> Void)?

        private var timer: Timer?
        private var lastDepth: Int?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            startMonitoringIfNeeded()
            publishDepthIfNeeded()
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            stopMonitoring()
        }

        deinit {
            stopMonitoring()
        }

        func startMonitoringIfNeeded() {
            guard timer == nil else { return }

            let newTimer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
                self?.publishDepthIfNeeded()
            }
            timer = newTimer
            RunLoop.main.add(newTimer, forMode: .common)
            publishDepthIfNeeded()
        }

        private func stopMonitoring() {
            timer?.invalidate()
            timer = nil
        }

        private func publishDepthIfNeeded() {
            let depth = currentMaximumNavigationDepth()
            guard depth != lastDepth else { return }
            lastDepth = depth
            onDepthChange?(depth)
        }

        private func currentMaximumNavigationDepth() -> Int {
            var depths: [Int] = []

            if let navigationController {
                depths.append(navigationController.viewControllers.count)
            }

            if let nearestNavigationController = nearestNavigationController() {
                depths.append(nearestNavigationController.viewControllers.count)
            }

            if let root = activeRootViewController() {
                let globalDepths = collectNavigationControllers(from: root).map { $0.viewControllers.count }
                depths.append(contentsOf: globalDepths)
            }

            return max(depths.max() ?? 1, 1)
        }

        private func nearestNavigationController() -> UINavigationController? {
            if let navigationController {
                return navigationController
            }

            var current: UIViewController? = parent
            while let controller = current {
                if let navigationController = controller as? UINavigationController {
                    return navigationController
                }
                if let navigationController = controller.navigationController {
                    return navigationController
                }
                current = controller.parent
            }

            return nil
        }

        private func activeRootViewController() -> UIViewController? {
            let activeScenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive }

            let keyWindow = activeScenes
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }

            return keyWindow?.rootViewController
        }

        private func collectNavigationControllers(from controller: UIViewController) -> [UINavigationController] {
            var result: [UINavigationController] = []

            if let navigationController = controller as? UINavigationController {
                result.append(navigationController)
            }

            if let navigationController = controller.navigationController {
                result.append(navigationController)
            }

            if let presentedViewController = controller.presentedViewController {
                result.append(contentsOf: collectNavigationControllers(from: presentedViewController))
            }

            for child in controller.children {
                result.append(contentsOf: collectNavigationControllers(from: child))
            }

            var seen = Set<ObjectIdentifier>()
            return result.filter { navigationController in
                let identifier = ObjectIdentifier(navigationController)
                guard !seen.contains(identifier) else { return false }
                seen.insert(identifier)
                return true
            }
        }
    }
}
