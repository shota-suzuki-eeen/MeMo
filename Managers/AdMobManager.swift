//
//  AdMobManager.swift
//  MeMo
//
//  Updated for AdMob production IDs.
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

// MARK: - App-level Manager

@MainActor
final class AdMobManager: ObservableObject {
    static let shared = AdMobManager()

    @Published private(set) var didStart: Bool = false

    let rewardGacha = RewardedAdManager(adUnitID: AdUnitID.rewardGacha)
    let interstitialCharacterSet = InterstitialAdManager(adUnitID: AdUnitID.interstitialCharacterSet)
    let interstitialGet = InterstitialAdManager(adUnitID: AdUnitID.interstitialGet)

    private var defaultsObserver: NSObjectProtocol?
    private var lastClaimedWorkRewardIDs: Set<String> = []
    private var lastClaimedHappinessRewardLevels: Set<Int> = []
    private var isShowingGetInterstitial: Bool = false

    private init() {}

    func start() {
        guard !didStart else { return }
        didStart = true

        lastClaimedWorkRewardIDs = currentClaimedWorkRewardIDs()
        lastClaimedHappinessRewardLevels = currentClaimedHappinessRewardLevels()
        observeRewardDefaultChanges()

        guard !DeveloperModeStore.isEnabled else {
            rewardGacha.load()
            interstitialCharacterSet.load()
            interstitialGet.load()
            return
        }

        #if canImport(GoogleMobileAds)
        MobileAds.shared.start()
        #endif

        rewardGacha.load()
        interstitialCharacterSet.load()
        evaluateInterstitialGetPreload()
    }

    func prepareRewardGacha() {
        rewardGacha.loadIfNeeded()
    }

    func prepareInterstitialCharacterSet() {
        interstitialCharacterSet.loadIfNeeded()
    }

    func prepareInterstitialGetIfNeeded(isRewardClaimable: Bool) {
        guard isRewardClaimable else { return }
        interstitialGet.loadIfNeeded()
    }

    func showInterstitialCharacterSetThenRun(_ action: @escaping () -> Void) {
        prepareInterstitialCharacterSet()
        interstitialCharacterSet.show(onDismiss: action)
    }

    func showInterstitialGetThenRun(_ action: @escaping () -> Void = {}) {
        guard !isShowingGetInterstitial else {
            action()
            return
        }

        isShowingGetInterstitial = true
        interstitialGet.show { [weak self] in
            Task { @MainActor in
                self?.isShowingGetInterstitial = false
                action()
                self?.evaluateInterstitialGetPreload()
            }
        }
    }

    private func observeRewardDefaultChanges() {
        guard defaultsObserver == nil else { return }

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleRewardDefaultChanges()
            }
        }
    }

    private func handleRewardDefaultChanges() {
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

    #if canImport(GoogleMobileAds)
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.backgroundColor = .clear

        guard !DeveloperModeStore.isEnabled else {
            context.coordinator.lastLoadedAdUnitID = nil
            return banner
        }

        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.topMostViewController()
        banner.load(Request())

        context.coordinator.lastLoadedAdUnitID = adUnitID
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        uiView.backgroundColor = .clear

        guard !DeveloperModeStore.isEnabled else {
            uiView.rootViewController = nil
            context.coordinator.lastLoadedAdUnitID = nil
            return
        }

        uiView.rootViewController = UIApplication.shared.topMostViewController()

        if context.coordinator.lastLoadedAdUnitID != adUnitID {
            uiView.adUnitID = adUnitID
            uiView.load(Request())
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

    var body: some View {
        GeometryReader { proxy in
            let rawW = max(1, proxy.size.width)
            let w = normalizeBannerWidth(rawW)
            let adH = min(max(1, contentHeight), height)

            ZStack {
                Color.clear

                if !DeveloperModeStore.isEnabled {
                    AdMobBannerView(adUnitID: adUnitID, width: w)
                        .frame(width: w, height: adH)
                        .clipped()
                        .padding(.top, topOffset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .frame(height: DeveloperModeStore.isEnabled ? 0 : height)
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
final class RewardedAdManager: ObservableObject {
    @Published private(set) var isReady: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastErrorMessage: String? = nil

    private let adUnitID: String

    #if canImport(GoogleMobileAds)
    private var rewardedAd: RewardedAd?
    #endif

    init(adUnitID: String) {
        self.adUnitID = adUnitID

        if DeveloperModeStore.isEnabled {
            self.isReady = true
        }
    }

    func loadIfNeeded() {
        guard !isReady, !isLoading else { return }
        load()
    }

    func load() {
        if DeveloperModeStore.isEnabled {
            isReady = true
            isLoading = false
            lastErrorMessage = nil
            #if canImport(GoogleMobileAds)
            rewardedAd = nil
            #endif
            return
        }

        #if canImport(GoogleMobileAds)
        guard !isLoading else { return }
        isReady = false
        isLoading = true
        lastErrorMessage = nil
        rewardedAd = nil

        RewardedAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.lastErrorMessage = error.localizedDescription
                    self.isReady = false
                    self.rewardedAd = nil
                    return
                }

                self.rewardedAd = ad
                self.isReady = (ad != nil)
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
        if DeveloperModeStore.isEnabled {
            onReward()
            isReady = true
            isLoading = false
            lastErrorMessage = nil
            return
        }

        #if canImport(GoogleMobileAds)
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

        ad.present(from: root) {
            onReward()
        }

        isReady = false
        rewardedAd = nil
        load()
        #else
        lastErrorMessage = "GoogleMobileAds がリンクされていません"
        isReady = false
        onUnavailable?()
        #endif
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

    #if canImport(GoogleMobileAds)
    private var interstitialAd: InterstitialAd?
    #endif

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init()

        if DeveloperModeStore.isEnabled {
            self.isReady = true
        }
    }

    func loadIfNeeded() {
        guard !isReady, !isLoading else { return }
        load()
    }

    func load() {
        if DeveloperModeStore.isEnabled {
            isReady = true
            isLoading = false
            lastErrorMessage = nil
            #if canImport(GoogleMobileAds)
            interstitialAd = nil
            #endif
            return
        }

        #if canImport(GoogleMobileAds)
        guard !isLoading else { return }
        isReady = false
        isLoading = true
        lastErrorMessage = nil
        interstitialAd = nil

        InterstitialAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoading = false

                if let error {
                    self.lastErrorMessage = error.localizedDescription
                    self.isReady = false
                    self.interstitialAd = nil
                    return
                }

                self.interstitialAd = ad
                self.interstitialAd?.fullScreenContentDelegate = self
                self.isReady = (ad != nil)
            }
        }
        #else
        isReady = false
        isLoading = false
        lastErrorMessage = "GoogleMobileAds がリンクされていません"
        #endif
    }

    func show(onDismiss: @escaping () -> Void) {
        if DeveloperModeStore.isEnabled {
            onDismiss()
            isReady = true
            isLoading = false
            lastErrorMessage = nil
            return
        }

        #if canImport(GoogleMobileAds)
        guard let ad = interstitialAd else {
            isReady = false
            onDismiss()
            loadIfNeeded()
            return
        }

        guard let root = UIApplication.shared.topMostViewController() else {
            isReady = false
            onDismiss()
            loadIfNeeded()
            return
        }

        self.onDismiss = onDismiss
        ad.fullScreenContentDelegate = self
        ad.present(from: root)

        isReady = false
        interstitialAd = nil
        #else
        lastErrorMessage = "GoogleMobileAds がリンクされていません"
        onDismiss()
        #endif
    }
}

#if canImport(GoogleMobileAds)
// MARK: - GADFullScreenContentDelegate

extension InterstitialAdManager: FullScreenContentDelegate {
    @MainActor
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        let callback = onDismiss
        onDismiss = nil
        callback?()
        load()
    }

    @MainActor
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        lastErrorMessage = error.localizedDescription

        let callback = onDismiss
        onDismiss = nil
        callback?()
        load()
    }
}
#endif
