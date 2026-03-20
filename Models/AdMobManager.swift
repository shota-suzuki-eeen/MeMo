////
////  AdMobManager.swift
////  MeMo
////
////  Created by shota suzuki on 2026/03/20.
////
//
//import Foundation
//import SwiftUI
//import UIKit
//import Combine
//import GoogleMobileAds
//
//// MARK: - Ad Unit IDs
//
//enum AdUnitID {
//    static let appID: String = ""
//
//    // 本番
//    static let bannerHomeProd: String = ""
//    static let rewardMojaProd: String = ""
//    static let rewardFoodProd: String = ""
//
//    // ✅ 修正：Step 用 reward
//    static let rewardStepEnjoyProd: String = ""
//
//    // ✅ 追加：本番（Interstitial_character_set）
//    static let interstitialCharacterSetProd: String = ""
//
//    // 開発（Google公式のダミー）
//    static let bannerTest: String = "ca-app-pub-3940256099942544/2934735716"
//    static let rewardedTest: String = "ca-app-pub-3940256099942544/1712485313"
//
//    // ✅ 追加：Interstitial のテストID（Google公式）
//    static let interstitialTest: String = "ca-app-pub-3940256099942544/4411468910"
//
//    static var bannerHome: String {
//        #if DEBUG
//        return bannerTest
//        #else
//        return bannerHomeProd
//        #endif
//    }
//
//    static var rewardMoja: String {
//        #if DEBUG
//        return rewardedTest
//        #else
//        return rewardMojaProd
//        #endif
//    }
//
//    static var rewardFood: String {
//        #if DEBUG
//        return rewardedTest
//        #else
//        return rewardFoodProd
//        #endif
//    }
//
//    // ✅ StepEnjoy 用 reward
//    static var rewardStepEnjoy: String {
//        #if DEBUG
//        return rewardedTest
//        #else
//        return rewardStepEnjoyProd
//        #endif
//    }
//
//    // ✅ 追加：Interstitial_character_set
//    static var interstitialCharacterSet: String {
//        #if DEBUG
//        return interstitialTest
//        #else
//        return interstitialCharacterSetProd
//        #endif
//    }
//}
//
//// MARK: - Developer Mode
//
//enum DeveloperModeStore {
//    static let key = "isDeveloperMode"
//
//    static var isEnabled: Bool {
//        UserDefaults.standard.bool(forKey: key)
//    }
//}
//
//// MARK: - App-level Manager
//
//@MainActor
//final class AdMobManager: ObservableObject {
//    static let shared = AdMobManager()
//
//    @Published private(set) var didStart: Bool = false
//
//    // ✅ 追加：キャラ切替用 interstitial をアプリ全体で1つ保持
//    let interstitialCharacterSet = InterstitialAdManager(adUnitID: AdUnitID.interstitialCharacterSet)
//
//    private init() {}
//
//    func start() {
//        guard !didStart else { return }
//        didStart = true
//
//        // ✅ 開発者モード中は広告SDK自体を起動しない
//        guard !DeveloperModeStore.isEnabled else { return }
//
//        MobileAds.shared.start()
//
//        // ✅ 起動時に1回ロードして持っておく
//        interstitialCharacterSet.load()
//    }
//}
//
//// MARK: - Root VC helper
//
//private extension UIApplication {
//
//    static func activeRootViewController() -> UIViewController? {
//        let scenes = UIApplication.shared.connectedScenes
//        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
//        let window = windowScene?.windows.first { $0.isKeyWindow }
//        return window?.rootViewController
//    }
//
//    static func activeScreen() -> UIScreen? {
//        let scenes = UIApplication.shared.connectedScenes
//        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
//        let window = windowScene?.windows.first { $0.isKeyWindow }
//        return window?.windowScene?.screen ?? windowScene?.screen
//    }
//
//    func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
//        let baseVC: UIViewController? = {
//            if let base { return base }
//            let scenes = connectedScenes
//            let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
//            let window = windowScene?.windows.first { $0.isKeyWindow }
//            return window?.rootViewController
//        }()
//
//        if let nav = baseVC as? UINavigationController {
//            return topMostViewController(base: nav.visibleViewController)
//        }
//        if let tab = baseVC as? UITabBarController {
//            return topMostViewController(base: tab.selectedViewController)
//        }
//        if let presented = baseVC?.presentedViewController {
//            return topMostViewController(base: presented)
//        }
//        return baseVC
//    }
//}
//
//// MARK: - Banner (SwiftUI)
//
//struct AdMobBannerView: UIViewRepresentable {
//    let adUnitID: String
//    let width: CGFloat
//
//    func makeCoordinator() -> Coordinator { Coordinator() }
//
//    func makeUIView(context: Context) -> BannerView {
//        let banner = BannerView(adSize: AdSizeBanner)
//        banner.backgroundColor = .clear
//
//        guard !DeveloperModeStore.isEnabled else {
//            context.coordinator.lastLoadedAdUnitID = nil
//            return banner
//        }
//
//        banner.adUnitID = adUnitID
//        banner.rootViewController = UIApplication.shared.topMostViewController()
//        banner.load(Request())
//
//        context.coordinator.lastLoadedAdUnitID = adUnitID
//        return banner
//    }
//
//    func updateUIView(_ uiView: BannerView, context: Context) {
//        uiView.backgroundColor = .clear
//
//        guard !DeveloperModeStore.isEnabled else {
//            uiView.rootViewController = nil
//            context.coordinator.lastLoadedAdUnitID = nil
//            return
//        }
//
//        uiView.rootViewController = UIApplication.shared.topMostViewController()
//
//        if context.coordinator.lastLoadedAdUnitID != adUnitID {
//            uiView.adUnitID = adUnitID
//            uiView.load(Request())
//            context.coordinator.lastLoadedAdUnitID = adUnitID
//        }
//    }
//
//    final class Coordinator {
//        var lastLoadedAdUnitID: String?
//    }
//}
//
//struct BannerArea: View {
//    let height: CGFloat
//    let adUnitID: String
//    var maxWidth: CGFloat? = nil
//    var contentHeight: CGFloat = 50
//    var topOffset: CGFloat = 10
//
//    var body: some View {
//        GeometryReader { proxy in
//            let rawW = max(1, proxy.size.width)
//            let w = normalizeBannerWidth(rawW)
//            let adH = min(max(1, contentHeight), height)
//
//            ZStack {
//                Color.clear
//
//                if !DeveloperModeStore.isEnabled {
//                    AdMobBannerView(adUnitID: adUnitID, width: w)
//                        .frame(width: w, height: adH)
//                        .clipped()
//                        .padding(.top, topOffset)
//                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//                }
//            }
//        }
//        .frame(height: DeveloperModeStore.isEnabled ? 0 : height)
//    }
//
//    private func normalizeBannerWidth(_ rawW: CGFloat) -> CGFloat {
//        let screen = UIApplication.activeScreen()
//        let screenW = screen?.bounds.width ?? rawW
//        let scale = screen?.scale ?? 1.0
//
//        var w = maxWidth.map { min(rawW, $0) } ?? rawW
//        w = min(w, screenW)
//
//        if w > screenW * 1.15 {
//            w = w / scale
//            w = min(w, screenW)
//        }
//
//        return max(1, w)
//    }
//}
//
//// MARK: - Rewarded
//
//@MainActor
//final class RewardedAdManager: ObservableObject {
//    @Published private(set) var isReady: Bool = false
//    @Published private(set) var lastErrorMessage: String? = nil
//
//    private let adUnitID: String
//    private var rewardedAd: RewardedAd?
//
//    init(adUnitID: String) {
//        self.adUnitID = adUnitID
//
//        if DeveloperModeStore.isEnabled {
//            self.isReady = true
//        }
//    }
//
//    func load() {
//        // ✅ 開発者モード中は常に即時報酬受け取り可能扱い
//        if DeveloperModeStore.isEnabled {
//            isReady = true
//            lastErrorMessage = nil
//            rewardedAd = nil
//            return
//        }
//
//        isReady = false
//        lastErrorMessage = nil
//        rewardedAd = nil
//
//        RewardedAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
//            guard let self else { return }
//
//            Task { @MainActor in
//                if let error {
//                    self.lastErrorMessage = error.localizedDescription
//                    self.isReady = false
//                    self.rewardedAd = nil
//                    return
//                }
//
//                self.rewardedAd = ad
//                self.isReady = (ad != nil)
//            }
//        }
//    }
//
//    func show(onReward: @escaping () -> Void) {
//        // ✅ 開発者モード中は広告を出さずに報酬だけ付与
//        if DeveloperModeStore.isEnabled {
//            onReward()
//            isReady = true
//            lastErrorMessage = nil
//            rewardedAd = nil
//            return
//        }
//
//        guard let ad = rewardedAd else {
//            isReady = false
//            return
//        }
//
//        guard let root = UIApplication.shared.topMostViewController() else {
//            isReady = false
//            return
//        }
//
//        ad.present(from: root) {
//            onReward()
//        }
//
//        isReady = false
//        rewardedAd = nil
//        load()
//    }
//}
//
//// MARK: - Interstitial
//
//@MainActor
//final class InterstitialAdManager: NSObject, ObservableObject {
//    @Published private(set) var isReady: Bool = false
//    @Published private(set) var lastErrorMessage: String? = nil
//
//    private let adUnitID: String
//    private var interstitialAd: InterstitialAd?
//    private var onDismiss: (() -> Void)?
//
//    init(adUnitID: String) {
//        self.adUnitID = adUnitID
//        super.init()
//
//        if DeveloperModeStore.isEnabled {
//            self.isReady = true
//        }
//    }
//
//    func load() {
//        // ✅ 開発者モード中は広告ロード不要
//        if DeveloperModeStore.isEnabled {
//            isReady = true
//            lastErrorMessage = nil
//            interstitialAd = nil
//            return
//        }
//
//        isReady = false
//        lastErrorMessage = nil
//        interstitialAd = nil
//
//        InterstitialAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
//            guard let self else { return }
//
//            Task { @MainActor in
//                if let error {
//                    self.lastErrorMessage = error.localizedDescription
//                    self.isReady = false
//                    self.interstitialAd = nil
//                    return
//                }
//
//                self.interstitialAd = ad
//                self.interstitialAd?.fullScreenContentDelegate = self
//                self.isReady = (ad != nil)
//            }
//        }
//    }
//
//    func show(onDismiss: @escaping () -> Void) {
//        // ✅ 開発者モード中は広告を出さずに後続処理だけ進める
//        if DeveloperModeStore.isEnabled {
//            onDismiss()
//            isReady = true
//            lastErrorMessage = nil
//            interstitialAd = nil
//            return
//        }
//
//        guard let ad = interstitialAd else {
//            isReady = false
//            return
//        }
//
//        guard let root = UIApplication.shared.topMostViewController() else {
//            isReady = false
//            return
//        }
//
//        self.onDismiss = onDismiss
//        ad.fullScreenContentDelegate = self
//
//        ad.present(from: root)
//
//        isReady = false
//        interstitialAd = nil
//    }
//}
//
//// MARK: - GADFullScreenContentDelegate
//
//extension InterstitialAdManager: FullScreenContentDelegate {
//    @MainActor
//    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
//        let callback = onDismiss
//        onDismiss = nil
//        callback?()
//
//        load()
//    }
//
//    @MainActor
//    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
//        lastErrorMessage = error.localizedDescription
//
//        let callback = onDismiss
//        onDismiss = nil
//        callback?()
//
//        load()
//    }
//}
