//
//  AdMobManager.swift
//  MeMo
//
//  Updated for AdMob production IDs.
//  Prepared for future subscription-based passive ad hiding.
//  お散歩機能のリワード広告IDを追加。
//  おやすみモード用のリワード広告管理を追加。
//  2026/06 update: 全広告を停止。広告ID・既存広告処理は再開できるように残す。
//  2026/06 update: リワード広告の起動時一括ロードを廃止し、画面単位プリロードへ変更。
//  2026/06 update: AdMob規約リスク低減のため、開発者モード時の広告SDK停止、
//  広告リクエスト60秒制限、インタースティシャル広告の頻度制御を追加。
//

import Foundation
import SwiftUI
import UIKit
import Combine

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - Ad Unit IDs

enum AdUnitID {
    static let appID: String = "ca-app-pub-1093843343402854~4339169050"

    // Production
    static let bannerHomeProd: String = "ca-app-pub-1093843343402854/3010924298"
    static let bannerWorkProd: String = "ca-app-pub-1093843343402854/3745421460"
    static let rewardGachaProd: String = "ca-app-pub-1093843343402854/4440075552"
    static let rewardWalkStartProd: String = "ca-app-pub-1093843343402854/2648339519"
    static let rewardWalkDoubleProd: String = "ca-app-pub-1093843343402854/2456767829"
    static let rewardSleepModeProd: String = "ca-app-pub-1093843343402854/7266688481"
    static let interstitialCharacterSetProd: String = "ca-app-pub-1093843343402854/1430768838"
    static let interstitialGetProd: String = "ca-app-pub-1093843343402854/1732045372"

    // Google official test IDs
    static let bannerTest: String = "ca-app-pub-3940256099942544/2934735716"
    static let rewardedTest: String = "ca-app-pub-3940256099942544/1712485313"
    static let interstitialTest: String = "ca-app-pub-3940256099942544/4411468910"

    static var bannerHome: String {
        #if DEBUG
        return bannerTest
        #else
        return bannerHomeProd
        #endif
    }

    static var bannerWork: String {
        #if DEBUG
        return bannerTest
        #else
        return bannerWorkProd
        #endif
    }

    static var rewardGacha: String {
        #if DEBUG
        return rewardedTest
        #else
        return rewardGachaProd
        #endif
    }

    static var rewardWalkStart: String {
        #if DEBUG
        return rewardedTest
        #else
        return rewardWalkStartProd
        #endif
    }

    static var rewardWalkDouble: String {
        #if DEBUG
        return rewardedTest
        #else
        return rewardWalkDoubleProd
        #endif
    }

    static var rewardSleepMode: String {
        #if DEBUG
        return rewardedTest
        #else
        return rewardSleepModeProd
        #endif
    }

    static var interstitialCharacterSet: String {
        #if DEBUG
        return interstitialTest
        #else
        return interstitialCharacterSetProd
        #endif
    }

    static var interstitialGet: String {
        #if DEBUG
        return interstitialTest
        #else
        return interstitialGetProd
        #endif
    }
}

// MARK: - Developer Mode

enum DeveloperModeStore {
    static let key = "isDeveloperMode"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: key)
    }
}

// MARK: - Ad runtime policy

private enum AdRuntimePolicy {
    static var isAdvertisingPaused: Bool {
        MonetizationPolicy.isAdvertisingPaused
    }

    static var isDeveloperMode: Bool {
        DeveloperModeStore.isEnabled
    }

    static var canTouchAdvertisingSDK: Bool {
        MonetizationPolicy.canTouchAdvertisingSDK(isDeveloperMode: isDeveloperMode)
    }

    static var minimumAdRequestInterval: TimeInterval {
        MonetizationPolicy.minimumAdRequestInterval
    }

    static var minimumInterstitialUserActions: Int {
        max(1, MonetizationPolicy.minimumInterstitialUserActions)
    }

    static var minimumInterstitialPresentationInterval: TimeInterval {
        MonetizationPolicy.minimumInterstitialPresentationInterval
    }
}

// MARK: - Ad request throttling

private final class AdRequestRateLimiter {
    static let shared = AdRequestRateLimiter()

    private var lastRequestAtByKey: [String: Date] = [:]

    private init() {}

    func canRequest(key: String, now: Date = Date()) -> Bool {
        guard let lastRequestAt = lastRequestAtByKey[key] else { return true }
        return now.timeIntervalSince(lastRequestAt) >= AdRuntimePolicy.minimumAdRequestInterval
    }

    func recordRequest(key: String, now: Date = Date()) {
        lastRequestAtByKey[key] = now
    }

    func reset(key: String) {
        lastRequestAtByKey[key] = nil
    }

    func resetAll() {
        lastRequestAtByKey.removeAll()
    }
}

// MARK: - Full-screen ad BGM mute bridge

private enum AdPlaybackAudioMuteController {
    static func begin() {
        NotificationCenter.default.post(
            name: BGMManager.adPlaybackDidBeginNotification,
            object: nil
        )
    }

    static func end() {
        NotificationCenter.default.post(
            name: BGMManager.adPlaybackDidEndNotification,
            object: nil
        )
    }
}

// MARK: - App-level Manager

@MainActor
final class AdMobManager: ObservableObject {
    static let shared = AdMobManager()

    @Published private(set) var didStart: Bool = false

    let rewardGacha = RewardedAdManager(adUnitID: AdUnitID.rewardGacha)
    let rewardWalkStart = RewardedAdManager(adUnitID: AdUnitID.rewardWalkStart)
    let rewardWalkDouble = RewardedAdManager(adUnitID: AdUnitID.rewardWalkDouble)
    let rewardSleepMode = RewardedAdManager(adUnitID: AdUnitID.rewardSleepMode)
    let interstitialCharacterSet = InterstitialAdManager(adUnitID: AdUnitID.interstitialCharacterSet)
    let interstitialGet = InterstitialAdManager(adUnitID: AdUnitID.interstitialGet)

    private var defaultsObserver: NSObjectProtocol?
    private var lastClaimedWorkRewardIDs: Set<String> = []
    private var lastClaimedHappinessRewardLevels: Set<Int> = []
    private var isShowingGetInterstitial: Bool = false
    private var didStartMobileAdsSDK: Bool = false

    private init() {}

    private var shouldUsePassiveAds: Bool {
        MonetizationPolicy.shouldShowPassiveAdvertising(
            isDeveloperMode: DeveloperModeStore.isEnabled,
            hasPremiumAccess: SubscriptionAccessManager.shared.hasPremiumAccess
        )
    }

    private var shouldUseRewardedAds: Bool {
        MonetizationPolicy.shouldUseRewardedAdvertising(
            isDeveloperMode: DeveloperModeStore.isEnabled,
            hasPremiumAccess: SubscriptionAccessManager.shared.hasPremiumAccess
        )
    }

    private var shouldUseAnyAdvertisingSDKFeature: Bool {
        AdRuntimePolicy.canTouchAdvertisingSDK && (shouldUsePassiveAds || shouldUseRewardedAds)
    }

    func start() {
        guard !didStart else { return }
        didStart = true

        lastClaimedWorkRewardIDs = currentClaimedWorkRewardIDs()
        lastClaimedHappinessRewardLevels = currentClaimedHappinessRewardLevels()
        observeRewardDefaultChanges()

        guard shouldUseAnyAdvertisingSDKFeature else {
            applyAdvertisingDisabledState()
            return
        }

        startMobileAdsSDKIfNeeded()

        // 2026/06 update:
        // リワード広告は起動時に一括ロードしない。
        // rewardGacha: ガチャ画面に入った時点で prepareRewardGacha()
        // rewardWalkStart: お散歩メニューを開いた時点で prepareRewardWalkStart()
        // rewardWalkDouble: リザルト画面表示時点で prepareRewardWalkDouble()
        // rewardSleepMode: おやすみモードポップアップ表示時点で prepareRewardSleepMode()
        if !shouldUseRewardedAds {
            markRewardedAdsAvailableWithoutAd()
        }

        guard shouldUsePassiveAds else { return }
        interstitialCharacterSet.loadIfNeeded()
        evaluateInterstitialGetPreload()
    }

    func prepareRewardGacha() {
        guard shouldUseRewardedAds else {
            rewardGacha.markAvailableWithoutAd()
            return
        }
        startMobileAdsSDKIfNeeded()
        rewardGacha.loadIfNeeded()
    }

    func prepareRewardWalkStart() {
        guard shouldUseRewardedAds else {
            rewardWalkStart.markAvailableWithoutAd()
            return
        }
        startMobileAdsSDKIfNeeded()
        rewardWalkStart.loadIfNeeded()
    }

    func prepareRewardWalkDouble() {
        guard shouldUseRewardedAds else {
            rewardWalkDouble.markAvailableWithoutAd()
            return
        }
        startMobileAdsSDKIfNeeded()
        rewardWalkDouble.loadIfNeeded()
    }

    func prepareRewardSleepMode() {
        guard shouldUseRewardedAds else {
            rewardSleepMode.markAvailableWithoutAd()
            return
        }
        startMobileAdsSDKIfNeeded()
        rewardSleepMode.loadIfNeeded()
    }

    func prepareInterstitialCharacterSet() {
        guard shouldUsePassiveAds else {
            interstitialCharacterSet.clearLoadedAd()
            return
        }
        startMobileAdsSDKIfNeeded()
        interstitialCharacterSet.loadIfNeeded()
    }

    func prepareInterstitialGetIfNeeded(isRewardClaimable: Bool) {
        guard shouldUsePassiveAds else {
            interstitialGet.clearLoadedAd()
            return
        }
        guard isRewardClaimable else { return }
        startMobileAdsSDKIfNeeded()
        interstitialGet.loadIfNeeded()
    }

    func showInterstitialCharacterSetThenRun(_ action: @escaping () -> Void) {
        guard shouldUsePassiveAds else {
            action()
            return
        }

        startMobileAdsSDKIfNeeded()
        prepareInterstitialCharacterSet()
        interstitialCharacterSet.show(onDismiss: action)
    }

    func showInterstitialGetThenRun(_ action: @escaping () -> Void = {}) {
        guard shouldUsePassiveAds else {
            action()
            return
        }

        guard !isShowingGetInterstitial else {
            action()
            return
        }

        startMobileAdsSDKIfNeeded()
        isShowingGetInterstitial = true
        interstitialGet.show { [weak self] in
            guard let manager = self else {
                action()
                return
            }

            Task { @MainActor [manager] in
                manager.isShowingGetInterstitial = false
                action()
                manager.evaluateInterstitialGetPreload()
            }
        }
    }

    private func startMobileAdsSDKIfNeeded() {
        guard shouldUseAnyAdvertisingSDKFeature else { return }
        guard !didStartMobileAdsSDK else { return }

        #if canImport(GoogleMobileAds)
        MobileAds.shared.start()
        #endif

        didStartMobileAdsSDK = true
    }

    private func applyAdvertisingDisabledState() {
        isShowingGetInterstitial = false
        markRewardedAdsAvailableWithoutAd()
        interstitialCharacterSet.clearLoadedAd()
        interstitialGet.clearLoadedAd()
        AdRequestRateLimiter.shared.resetAll()
    }

    private func markRewardedAdsAvailableWithoutAd() {
        rewardGacha.markAvailableWithoutAd()
        rewardWalkStart.markAvailableWithoutAd()
        rewardWalkDouble.markAvailableWithoutAd()
        rewardSleepMode.markAvailableWithoutAd()
    }

    private func observeRewardDefaultChanges() {
        guard defaultsObserver == nil else { return }

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let manager = self else { return }

            Task { @MainActor [manager] in
                manager.handleRewardDefaultChanges()
            }
        }
    }

    private func handleRewardDefaultChanges() {
        guard shouldUseAnyAdvertisingSDKFeature else {
            applyAdvertisingDisabledState()
            return
        }

        startMobileAdsSDKIfNeeded()
        evaluateInterstitialGetPreload()

        let nextWorkIDs = currentClaimedWorkRewardIDs()
        let didClaimWorkReward = nextWorkIDs.count > lastClaimedWorkRewardIDs.count
        lastClaimedWorkRewardIDs = nextWorkIDs

        let nextHappinessLevels = currentClaimedHappinessRewardLevels()
        let didClaimHappinessReward = nextHappinessLevels.count > lastClaimedHappinessRewardLevels.count
        lastClaimedHappinessRewardLevels = nextHappinessLevels

        if didClaimWorkReward || didClaimHappinessReward {
            showInterstitialGetThenRun()
        }
    }

    private func evaluateInterstitialGetPreload() {
        guard shouldUsePassiveAds else { return }

        let hasWorkReward = hasClaimableWorkFocusReward()
        let hasHappinessReward = hasClaimableHappinessReward()
        prepareInterstitialGetIfNeeded(isRewardClaimable: hasWorkReward || hasHappinessReward)
    }

    private func currentClaimedWorkRewardIDs() -> Set<String> {
        let values = UserDefaults.standard.stringArray(forKey: "memo.work.focus.claimedRewardIDs") ?? []
        return Set(values)
    }

    private func currentClaimedHappinessRewardLevels() -> Set<Int> {
        guard let data = UserDefaults.standard.data(forKey: "memo.happiness.claimedRewardLevels"),
              let values = try? JSONDecoder().decode([Int].self, from: data) else {
            return []
        }
        return Set(values)
    }

    private func hasClaimableHappinessReward() -> Bool {
        let happinessLevel = min(AppState.happinessMaxLevel, max(0, UserDefaults.standard.integer(forKey: "memo.happiness.level")))
        let claimed = currentClaimedHappinessRewardLevels()
        return AppState.happinessRewardDefinitions.contains { reward in
            happinessLevel >= reward.level && !claimed.contains(reward.level)
        }
    }

    private func hasClaimableWorkFocusReward() -> Bool {
        let totalSeconds = max(0, UserDefaults.standard.integer(forKey: "memo.work.focus.totalSeconds"))
        let claimed = currentClaimedWorkRewardIDs()
        let milestoneHours = [5, 10, 15, 20, 25, 30]

        return milestoneHours.contains { hour in
            let id = "work.reward.\(hour)h"
            return totalSeconds >= hour * 60 * 60 && !claimed.contains(id)
        }
    }
}

// MARK: - Root VC helper

private extension UIApplication {
    static func activeScreen() -> UIScreen? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        let window = windowScene?.windows.first { $0.isKeyWindow }
        return window?.windowScene?.screen ?? windowScene?.screen
    }

    func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC: UIViewController? = {
            if let base { return base }
            let scenes = connectedScenes
            let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
            let window = windowScene?.windows.first { $0.isKeyWindow }
            return window?.rootViewController
        }()

        if let nav = baseVC as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = baseVC as? UITabBarController {
            return topMostViewController(base: tab.selectedViewController)
        }
        if let presented = baseVC?.presentedViewController {
            return topMostViewController(base: presented)
        }
        return baseVC
    }
}

// MARK: - Banner (SwiftUI)

struct AdMobBannerView: UIViewRepresentable {
    let adUnitID: String
    let width: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    private var shouldUsePassiveAds: Bool {
        MonetizationPolicy.shouldShowPassiveAdvertising(
            isDeveloperMode: DeveloperModeStore.isEnabled,
            hasPremiumAccess: SubscriptionAccessManager.shared.hasPremiumAccess
        )
    }

    #if canImport(GoogleMobileAds)
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.backgroundColor = .clear

        guard shouldUsePassiveAds else {
            context.coordinator.lastLoadedAdUnitID = nil
            return banner
        }

        guard AdRequestRateLimiter.shared.canRequest(key: adUnitID) else {
            context.coordinator.lastLoadedAdUnitID = adUnitID
            return banner
        }

        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.topMostViewController()
        banner.load(Request())

        AdRequestRateLimiter.shared.recordRequest(key: adUnitID)
        context.coordinator.lastLoadedAdUnitID = adUnitID
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        uiView.backgroundColor = .clear

        guard shouldUsePassiveAds else {
            uiView.rootViewController = nil
            context.coordinator.lastLoadedAdUnitID = nil
            return
        }

        uiView.rootViewController = UIApplication.shared.topMostViewController()

        if context.coordinator.lastLoadedAdUnitID != adUnitID {
            guard AdRequestRateLimiter.shared.canRequest(key: adUnitID) else {
                context.coordinator.lastLoadedAdUnitID = adUnitID
                return
            }

            uiView.adUnitID = adUnitID
            uiView.load(Request())
            AdRequestRateLimiter.shared.recordRequest(key: adUnitID)
            context.coordinator.lastLoadedAdUnitID = adUnitID
        }
    }
    #else
    func makeUIView(context: Context) -> UIView {
        UIView(frame: .zero)
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
    #endif

    final class Coordinator {
        var lastLoadedAdUnitID: String?
    }
}

struct BannerArea: View {
    let height: CGFloat
    let adUnitID: String
    var maxWidth: CGFloat? = nil
    var contentHeight: CGFloat = 50
    var topOffset: CGFloat = 10

    @ObservedObject private var subscriptionAccessManager = SubscriptionAccessManager.shared

    private var shouldUsePassiveAds: Bool {
        MonetizationPolicy.shouldShowPassiveAdvertising(
            isDeveloperMode: DeveloperModeStore.isEnabled,
            hasPremiumAccess: subscriptionAccessManager.hasPremiumAccess
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let rawW = max(1, proxy.size.width)
            let w = normalizeBannerWidth(rawW)
            let adH = min(max(1, contentHeight), height)

            ZStack {
                Color.clear

                if shouldUsePassiveAds {
                    AdMobBannerView(adUnitID: adUnitID, width: w)
                        .frame(width: w, height: adH)
                        .clipped()
                        .padding(.top, topOffset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .frame(height: shouldUsePassiveAds ? height : 0)
    }

    private func normalizeBannerWidth(_ rawW: CGFloat) -> CGFloat {
        let screen = UIApplication.activeScreen()
        let screenW = screen?.bounds.width ?? rawW
        let scale = screen?.scale ?? 1.0

        var w = maxWidth.map { min(rawW, $0) } ?? rawW
        w = min(w, screenW)

        if w > screenW * 1.15 {
            w = w / scale
            w = min(w, screenW)
        }

        return max(1, w)
    }
}

// MARK: - Rewarded

@MainActor
final class RewardedAdManager: NSObject, ObservableObject {
    @Published private(set) var isReady: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastErrorMessage: String? = nil

    private let adUnitID: String
    private var pendingReward: (() -> Void)?
    private var pendingUnavailable: (() -> Void)?
    private var didEarnRewardDuringPresentation: Bool = false
    private var isPresentingAd: Bool = false
    private var lastLoadAt: Date?

    #if canImport(GoogleMobileAds)
    private var rewardedAd: RewardedAd?
    #endif

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init()

        if !AdRuntimePolicy.canTouchAdvertisingSDK {
            self.isReady = true
        }
    }

    func markAvailableWithoutAd() {
        isReady = true
        isLoading = false
        lastErrorMessage = nil
        pendingReward = nil
        pendingUnavailable = nil
        didEarnRewardDuringPresentation = false
        isPresentingAd = false
        lastLoadAt = nil
        AdRequestRateLimiter.shared.reset(key: adUnitID)
        #if canImport(GoogleMobileAds)
        rewardedAd = nil
        #endif
    }

    func loadIfNeeded() {
        guard AdRuntimePolicy.canTouchAdvertisingSDK else {
            markAvailableWithoutAd()
            return
        }
        guard !isReady, !isLoading else { return }
        guard canRequestNewAd() else { return }
        load()
    }

    private func canRequestNewAd(now: Date = Date()) -> Bool {
        guard let lastLoadAt else { return true }
        return now.timeIntervalSince(lastLoadAt) >= AdRuntimePolicy.minimumAdRequestInterval
    }

    private func recordLoadRequest(now: Date = Date()) {
        lastLoadAt = now
        AdRequestRateLimiter.shared.recordRequest(key: adUnitID, now: now)
    }

    func load() {
        guard AdRuntimePolicy.canTouchAdvertisingSDK else {
            markAvailableWithoutAd()
            return
        }

        #if canImport(GoogleMobileAds)
        guard !isLoading else { return }
        guard canRequestNewAd() else { return }

        isReady = false
        isLoading = true
        lastErrorMessage = nil
        rewardedAd = nil
        recordLoadRequest()

        RewardedAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            guard let manager = self else { return }

            Task { @MainActor [manager, ad, error] in
                manager.isLoading = false

                if let error {
                    manager.lastErrorMessage = error.localizedDescription
                    manager.isReady = false
                    manager.rewardedAd = nil
                    return
                }

                manager.rewardedAd = ad
                manager.rewardedAd?.fullScreenContentDelegate = manager
                manager.isReady = (ad != nil)
            }
        }
        #else
        isReady = false
        isLoading = false
        lastErrorMessage = "GoogleMobileAds がリンクされていません"
        #endif
    }

    func show(
        onReward: @escaping () -> Void,
        onUnavailable: (() -> Void)? = nil
    ) {
        guard AdRuntimePolicy.canTouchAdvertisingSDK else {
            markAvailableWithoutAd()
            onReward()
            return
        }

        #if canImport(GoogleMobileAds)
        guard !isPresentingAd else {
            onUnavailable?()
            return
        }

        guard let ad = rewardedAd else {
            isReady = false
            loadIfNeeded()
            onUnavailable?()
            return
        }

        guard let root = UIApplication.shared.topMostViewController() else {
            isReady = false
            loadIfNeeded()
            onUnavailable?()
            return
        }

        pendingReward = onReward
        pendingUnavailable = onUnavailable
        didEarnRewardDuringPresentation = false
        isPresentingAd = true

        ad.fullScreenContentDelegate = self
        AdPlaybackAudioMuteController.begin()

        ad.present(from: root) { [weak self] in
            guard let manager = self else { return }

            Task { @MainActor [manager] in
                manager.didEarnRewardDuringPresentation = true
            }
        }

        isReady = false
        rewardedAd = nil
        #else
        lastErrorMessage = "GoogleMobileAds がリンクされていません"
        isReady = false
        onUnavailable?()
        #endif
    }

    private func finishPresentation(
        shouldRunReward: Bool,
        shouldRunUnavailable: Bool
    ) {
        let reward = pendingReward
        let unavailable = pendingUnavailable

        pendingReward = nil
        pendingUnavailable = nil
        didEarnRewardDuringPresentation = false
        isPresentingAd = false

        AdPlaybackAudioMuteController.end()

        if shouldRunReward {
            reward?()
        } else if shouldRunUnavailable {
            unavailable?()
        }

        loadIfNeeded()
    }
}

// MARK: - Interstitial

@MainActor
final class InterstitialAdManager: NSObject, ObservableObject {
    @Published private(set) var isReady: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastErrorMessage: String? = nil

    private let adUnitID: String
    private var onDismiss: (() -> Void)?
    private var isPresentingAd: Bool = false
    private var userActionsSinceLastPresentation: Int = 0
    private var lastPresentedAt: Date?
    private var lastLoadAt: Date?

    #if canImport(GoogleMobileAds)
    private var interstitialAd: InterstitialAd?
    #endif

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init()
    }

    func clearLoadedAd() {
        isReady = false
        isLoading = false
        lastErrorMessage = nil
        onDismiss = nil
        isPresentingAd = false
        userActionsSinceLastPresentation = 0
        lastPresentedAt = nil
        lastLoadAt = nil
        AdRequestRateLimiter.shared.reset(key: adUnitID)
        #if canImport(GoogleMobileAds)
        interstitialAd = nil
        #endif
    }

    func loadIfNeeded() {
        guard AdRuntimePolicy.canTouchAdvertisingSDK else {
            clearLoadedAd()
            return
        }
        guard !isReady, !isLoading else { return }
        guard canRequestNewAd() else { return }
        load()
    }

    private func canRequestNewAd(now: Date = Date()) -> Bool {
        guard let lastLoadAt else { return true }
        return now.timeIntervalSince(lastLoadAt) >= AdRuntimePolicy.minimumAdRequestInterval
    }

    private func recordLoadRequest(now: Date = Date()) {
        lastLoadAt = now
        AdRequestRateLimiter.shared.recordRequest(key: adUnitID, now: now)
    }

    func load() {
        guard AdRuntimePolicy.canTouchAdvertisingSDK else {
            clearLoadedAd()
            return
        }

        #if canImport(GoogleMobileAds)
        guard !isLoading else { return }
        guard canRequestNewAd() else { return }

        isReady = false
        isLoading = true
        lastErrorMessage = nil
        interstitialAd = nil
        recordLoadRequest()

        InterstitialAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            guard let manager = self else { return }

            Task { @MainActor [manager, ad, error] in
                manager.isLoading = false

                if let error {
                    manager.lastErrorMessage = error.localizedDescription
                    manager.isReady = false
                    manager.interstitialAd = nil
                    return
                }

                manager.interstitialAd = ad
                manager.interstitialAd?.fullScreenContentDelegate = manager
                manager.isReady = (ad != nil)
            }
        }
        #else
        isReady = false
        isLoading = false
        lastErrorMessage = "GoogleMobileAds がリンクされていません"
        #endif
    }

    func show(onDismiss: @escaping () -> Void) {
        guard AdRuntimePolicy.canTouchAdvertisingSDK else {
            onDismiss()
            return
        }

        #if canImport(GoogleMobileAds)
        guard !isPresentingAd else {
            onDismiss()
            return
        }

        userActionsSinceLastPresentation += 1

        guard userActionsSinceLastPresentation >= AdRuntimePolicy.minimumInterstitialUserActions else {
            loadIfNeeded()
            onDismiss()
            return
        }

        if let lastPresentedAt,
           Date().timeIntervalSince(lastPresentedAt) < AdRuntimePolicy.minimumInterstitialPresentationInterval {
            loadIfNeeded()
            onDismiss()
            return
        }

        guard let ad = interstitialAd else {
            isReady = false
            loadIfNeeded()
            onDismiss()
            return
        }

        guard let root = UIApplication.shared.topMostViewController() else {
            isReady = false
            loadIfNeeded()
            onDismiss()
            return
        }

        self.onDismiss = onDismiss
        isPresentingAd = true
        userActionsSinceLastPresentation = 0
        lastPresentedAt = Date()
        ad.fullScreenContentDelegate = self

        AdPlaybackAudioMuteController.begin()
        ad.present(from: root)

        isReady = false
        interstitialAd = nil
        #else
        lastErrorMessage = "GoogleMobileAds がリンクされていません"
        onDismiss()
        #endif
    }

    private func finishPresentation() {
        let callback = onDismiss
        onDismiss = nil
        isPresentingAd = false

        AdPlaybackAudioMuteController.end()

        callback?()
        loadIfNeeded()
    }
}

#if canImport(GoogleMobileAds)
// MARK: - FullScreenContentDelegate

extension RewardedAdManager: FullScreenContentDelegate {
    @MainActor
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishPresentation(
            shouldRunReward: didEarnRewardDuringPresentation,
            shouldRunUnavailable: false
        )
    }

    @MainActor
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        lastErrorMessage = error.localizedDescription
        finishPresentation(
            shouldRunReward: false,
            shouldRunUnavailable: true
        )
    }
}

extension InterstitialAdManager: FullScreenContentDelegate {
    @MainActor
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishPresentation()
    }

    @MainActor
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        lastErrorMessage = error.localizedDescription
        finishPresentation()
    }
}
#endif
