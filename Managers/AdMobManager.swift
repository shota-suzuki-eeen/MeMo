//
//  AdMobManager.swift
//  MeMo
//
//  Updated for AdMob production IDs.
//  Prepared for future subscription-based passive ad hiding.
//  お散歩機能のリワード広告IDを追加。
//  おやすみモード用のリワード広告管理を追加。
//  2026/06 update: リワード広告の起動時一括ロードを廃止し、画面単位プリロードへ変更。
//  2026/06 update: AdMob規約リスク低減のため、開発者モード時の広告SDK停止、
//  広告リクエスト60秒制限、インタースティシャル広告の頻度制御を追加。
//  2026/07 update: 図鑑のお世話キャラクター変更用インタースティシャルは、
//  初回表示あり → 2回目なし → 3回目表示ありの交互表示に調整。
//  2026/07 update: 複数広告枠で30分以内8回以上ロード失敗した場合のみ、
//  通信不良とは切り分けてAdMob一時停止モードへ移行する自動切り替えを追加。
//

import Foundation
import SwiftUI
import UIKit
import Combine
import Network

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - Ad Unit IDs

enum AdUnitID {
    static let appID: String = "ca-app-pub-1093843343402854~4339169050"

    // Production
    static let bannerHomeProd: String = "ca-app-pub-1093843343402854/3010924298"
    static let bannerWorkProd: String = "ca-app-pub-1093843343402854/3745421460"
    static let rewardGachaProd: String = "ca-app-pub-1093843343402854/8085898795"
    static let rewardWalkStartProd: String = "ca-app-pub-1093843343402854/2648339519"
    static let rewardWalkDoubleProd: String = "ca-app-pub-1093843343402854/9384714199"
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

// MARK: - AdMob temporary pause store

private struct RewardedAdLoadFailureRecord: Codable, Hashable {
    let adUnitID: String
    let occurredAt: Date
}

private enum AdMobTemporaryPauseStore {
    static let failureRecordsKey = "memo.admob.rewarded.loadFailureRecords"
    static let pauseUntilKey = "memo.admob.temporaryPauseUntil"

    static let failureWindow: TimeInterval = 30 * 60
    static let failureThreshold: Int = 8
    static let minimumDistinctFailedAdUnits: Int = 2
    static let pauseDuration: TimeInterval = 6 * 60 * 60

    static var pauseUntil: Date? {
        get { UserDefaults.standard.object(forKey: pauseUntilKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: pauseUntilKey) }
    }

    static func isPauseActive(now: Date = Date()) -> Bool {
        guard let pauseUntil else { return false }
        return now < pauseUntil
    }

    static func clearExpiredPauseIfNeeded(now: Date = Date()) {
        guard let pauseUntil else { return }
        if pauseUntil <= now {
            UserDefaults.standard.removeObject(forKey: pauseUntilKey)
        }
    }

    static func failureRecords(now: Date = Date()) -> [RewardedAdLoadFailureRecord] {
        guard let data = UserDefaults.standard.data(forKey: failureRecordsKey),
              let decoded = try? JSONDecoder().decode([RewardedAdLoadFailureRecord].self, from: data) else {
            return []
        }
        return decoded.filter { now.timeIntervalSince($0.occurredAt) <= failureWindow }
    }

    static func setFailureRecords(_ records: [RewardedAdLoadFailureRecord]) {
        if records.isEmpty {
            UserDefaults.standard.removeObject(forKey: failureRecordsKey)
            return
        }
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: failureRecordsKey)
    }

    static func appendFailure(adUnitID: String, now: Date = Date()) -> [RewardedAdLoadFailureRecord] {
        let next = failureRecords(now: now) + [RewardedAdLoadFailureRecord(adUnitID: adUnitID, occurredAt: now)]
        setFailureRecords(next)
        return next
    }

    static func clearFailures() {
        UserDefaults.standard.removeObject(forKey: failureRecordsKey)
    }

    static func enterPause(now: Date = Date()) -> Date {
        let until = now.addingTimeInterval(pauseDuration)
        pauseUntil = until
        clearFailures()
        return until
    }

    static func exitPause() {
        UserDefaults.standard.removeObject(forKey: pauseUntilKey)
        clearFailures()
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
    @Published private(set) var hasNetworkConnection: Bool = true
    @Published private(set) var temporaryPauseUntil: Date? = AdMobTemporaryPauseStore.pauseUntil
    @Published private(set) var lastRewardedUnavailableMessage: String? = nil

    let rewardGacha = RewardedAdManager(adUnitID: AdUnitID.rewardGacha)
    let rewardWalkStart = RewardedAdManager(adUnitID: AdUnitID.rewardWalkStart)
    let rewardWalkDouble = RewardedAdManager(adUnitID: AdUnitID.rewardWalkDouble)
    let rewardSleepMode = RewardedAdManager(adUnitID: AdUnitID.rewardSleepMode)
    // 図鑑のお世話キャラクター変更用。
    // 初回は表示対象、以降は「表示なし → 表示あり」を交互に繰り返す。
    let interstitialCharacterSet = InterstitialAdManager(
        adUnitID: AdUnitID.interstitialCharacterSet,
        startsEligibleOnFirstUserAction: true,
        respectsMinimumPresentationInterval: false
    )
    let interstitialGet = InterstitialAdManager(adUnitID: AdUnitID.interstitialGet)

    private var defaultsObserver: NSObjectProtocol?
    private var lastClaimedWorkRewardIDs: Set<String> = []
    private var lastClaimedHappinessRewardLevels: Set<Int> = []
    private var isShowingGetInterstitial: Bool = false
    private var didStartMobileAdsSDK: Bool = false
    private var didStartNetworkMonitor: Bool = false
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "memo.admob.network-monitor")

    private init() {}

    var isAdMobTemporaryPauseModeActive: Bool {
        refreshTemporaryPauseState()
        return AdMobTemporaryPauseStore.isPauseActive()
    }

    var canGrantRewardWithoutAdInTemporaryPause: Bool {
        isAdMobTemporaryPauseModeActive && hasNetworkConnection
    }

    var shouldShowRewardedAdVideoLabel: Bool {
        shouldUseRewardedAds && !isAdMobTemporaryPauseModeActive
    }

    var rewardedUnavailableMessage: String {
        if !hasNetworkConnection {
            return "通信接続後にもう一度お試しください"
        }
        return "広告を準備中です。少し待ってからもう一度お試しください"
    }

    private var shouldUsePassiveAds: Bool {
        guard !isAdMobTemporaryPauseModeActive else { return false }
        guard hasNetworkConnection else { return false }
        return MonetizationPolicy.shouldShowPassiveAdvertising(
            isDeveloperMode: DeveloperModeStore.isEnabled,
            hasPremiumAccess: SubscriptionAccessManager.shared.hasPremiumAccess
        )
    }

    private var shouldUseRewardedAds: Bool {
        guard !isAdMobTemporaryPauseModeActive else { return false }
        guard hasNetworkConnection else { return false }
        return MonetizationPolicy.shouldUseRewardedAdvertising(
            isDeveloperMode: DeveloperModeStore.isEnabled,
            hasPremiumAccess: SubscriptionAccessManager.shared.hasPremiumAccess
        )
    }

    private var shouldUseAnyAdvertisingSDKFeature: Bool {
        AdRuntimePolicy.canTouchAdvertisingSDK && (shouldUsePassiveAds || shouldUseRewardedAds)
    }

    func start() {
        guard !didStart else {
            refreshTemporaryPauseState()
            return
        }
        didStart = true

        startNetworkMonitorIfNeeded()
        refreshTemporaryPauseState()
        lastClaimedWorkRewardIDs = currentClaimedWorkRewardIDs()
        lastClaimedHappinessRewardLevels = currentClaimedHappinessRewardLevels()
        observeRewardDefaultChanges()

        guard shouldUseAnyAdvertisingSDKFeature else {
            applyAdvertisingDisabledState()
            return
        }

        startMobileAdsSDKIfNeeded()

        // リワード広告は画面単位でプリロードする。
        // 優先順: ガチャ → おやすみモード → お散歩開始 → 2倍獲得。
        if !shouldUseRewardedAds {
            markRewardedAdsAvailableWithoutAdIfAllowed()
        }

        guard shouldUsePassiveAds else { return }
        interstitialCharacterSet.loadIfNeeded()
        evaluateInterstitialGetPreload()
    }

    func prepareRewardGacha() {
        prepareRewardedAd(rewardGacha)
    }

    func prepareRewardSleepMode() {
        prepareRewardedAd(rewardSleepMode)
    }

    func prepareRewardWalkStart() {
        prepareRewardedAd(rewardWalkStart)
    }

    func prepareRewardWalkDouble() {
        prepareRewardedAd(rewardWalkDouble)
    }

    func prepareRewardedAdsInPreferredOrder() {
        prepareRewardGacha()
        prepareRewardSleepMode()
        prepareRewardWalkStart()
        prepareRewardWalkDouble()
    }

    private func prepareRewardedAd(_ manager: RewardedAdManager) {
        refreshTemporaryPauseState()

        guard hasNetworkConnection else {
            manager.markUnavailable(message: rewardedUnavailableMessage)
            return
        }

        guard shouldUseRewardedAds else {
            if canGrantRewardWithoutAd(for: manager.adUnitID) {
                manager.markAvailableWithoutAd()
            } else if !AdRuntimePolicy.canTouchAdvertisingSDK || !shouldUseRewardedAdsBecauseOfMonetizationSettings {
                manager.markAvailableWithoutAd()
            } else {
                manager.markUnavailable(message: rewardedUnavailableMessage)
            }
            return
        }

        startMobileAdsSDKIfNeeded()
        manager.loadIfNeeded()
    }

    private var shouldUseRewardedAdsBecauseOfMonetizationSettings: Bool {
        MonetizationPolicy.shouldUseRewardedAdvertising(
            isDeveloperMode: DeveloperModeStore.isEnabled,
            hasPremiumAccess: SubscriptionAccessManager.shared.hasPremiumAccess
        )
    }

    func prepareInterstitialCharacterSet() {
        refreshTemporaryPauseState()
        guard shouldUsePassiveAds else {
            interstitialCharacterSet.clearLoadedAd()
            return
        }
        startMobileAdsSDKIfNeeded()
        interstitialCharacterSet.loadIfNeeded()
    }

    func prepareInterstitialGetIfNeeded(isRewardClaimable: Bool) {
        refreshTemporaryPauseState()
        guard shouldUsePassiveAds else {
            interstitialGet.clearLoadedAd()
            return
        }
        guard isRewardClaimable else { return }
        startMobileAdsSDKIfNeeded()
        interstitialGet.loadIfNeeded()
    }

    func showInterstitialCharacterSetThenRun(_ action: @escaping () -> Void) {
        refreshTemporaryPauseState()
        guard shouldUsePassiveAds else {
            action()
            return
        }

        startMobileAdsSDKIfNeeded()
        prepareInterstitialCharacterSet()
        interstitialCharacterSet.show(onDismiss: action)
    }

    func showInterstitialGetThenRun(_ action: @escaping () -> Void = {}) {
        refreshTemporaryPauseState()
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

    func canGrantRewardWithoutAd(for adUnitID: String) -> Bool {
        refreshTemporaryPauseState()
        guard hasNetworkConnection else { return false }

        if isAdMobTemporaryPauseModeActive { return true }

        return !MonetizationPolicy.shouldUseRewardedAdvertising(
            isDeveloperMode: DeveloperModeStore.isEnabled,
            hasPremiumAccess: SubscriptionAccessManager.shared.hasPremiumAccess
        )
    }

    func recordRewardedLoadSuccess(adUnitID: String) {
        lastRewardedUnavailableMessage = nil
        AdMobTemporaryPauseStore.exitPause()
        temporaryPauseUntil = nil
        AdMobTemporaryPauseStore.clearFailures()
    }

    func recordRewardedLoadFailure(adUnitID: String, error: Error) {
        refreshTemporaryPauseState()

        guard hasNetworkConnection else {
            lastRewardedUnavailableMessage = rewardedUnavailableMessage
            return
        }

        guard !isConnectivityError(error) else {
            lastRewardedUnavailableMessage = rewardedUnavailableMessage
            return
        }

        guard !isAdMobTemporaryPauseModeActive else { return }

        let now = Date()
        let records = AdMobTemporaryPauseStore.appendFailure(adUnitID: adUnitID, now: now)
        let distinctAdUnits = Set(records.map(\.adUnitID)).count

        guard records.count >= AdMobTemporaryPauseStore.failureThreshold,
              distinctAdUnits >= AdMobTemporaryPauseStore.minimumDistinctFailedAdUnits else {
            return
        }

        let pauseUntil = AdMobTemporaryPauseStore.enterPause(now: now)
        temporaryPauseUntil = pauseUntil
        lastRewardedUnavailableMessage = nil
        applyTemporaryPauseState()
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
        markRewardedAdsAvailableWithoutAdIfAllowed()
        interstitialCharacterSet.clearLoadedAd()
        interstitialGet.clearLoadedAd()
        AdRequestRateLimiter.shared.resetAll()
    }

    private func applyTemporaryPauseState() {
        interstitialCharacterSet.clearLoadedAd()
        interstitialGet.clearLoadedAd()
        AdRequestRateLimiter.shared.resetAll()
        if hasNetworkConnection {
            markRewardedAdsAvailableWithoutAdIfAllowed()
        } else {
            markRewardedAdsUnavailableForConnection()
        }
    }

    private func markRewardedAdsAvailableWithoutAdIfAllowed() {
        guard hasNetworkConnection || !shouldUseRewardedAdsBecauseOfMonetizationSettings else {
            markRewardedAdsUnavailableForConnection()
            return
        }
        rewardGacha.markAvailableWithoutAd()
        rewardWalkStart.markAvailableWithoutAd()
        rewardWalkDouble.markAvailableWithoutAd()
        rewardSleepMode.markAvailableWithoutAd()
    }

    private func markRewardedAdsUnavailableForConnection() {
        let message = rewardedUnavailableMessage
        rewardGacha.markUnavailable(message: message)
        rewardWalkStart.markUnavailable(message: message)
        rewardWalkDouble.markUnavailable(message: message)
        rewardSleepMode.markUnavailable(message: message)
    }

    private func refreshTemporaryPauseState() {
        AdMobTemporaryPauseStore.clearExpiredPauseIfNeeded()
        let nextPauseUntil = AdMobTemporaryPauseStore.pauseUntil
        if temporaryPauseUntil != nextPauseUntil {
            temporaryPauseUntil = nextPauseUntil
        }
    }

    private func startNetworkMonitorIfNeeded() {
        guard !didStartNetworkMonitor else { return }
        didStartNetworkMonitor = true

        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isSatisfied = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let manager = self else { return }
                manager.handleNetworkStatusChange(isConnected: isSatisfied)
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    private func handleNetworkStatusChange(isConnected: Bool) {
        guard hasNetworkConnection != isConnected else { return }
        hasNetworkConnection = isConnected

        if !isConnected {
            lastRewardedUnavailableMessage = rewardedUnavailableMessage
            markRewardedAdsUnavailableForConnection()
            interstitialCharacterSet.clearLoadedAd()
            interstitialGet.clearLoadedAd()
            return
        }

        lastRewardedUnavailableMessage = nil
        refreshTemporaryPauseState()
        if isAdMobTemporaryPauseModeActive {
            markRewardedAdsAvailableWithoutAdIfAllowed()
        }
    }

    private func isConnectivityError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return true
        }

        let lowercased = (nsError.localizedDescription + " " + nsError.domain).lowercased()
        let keywords = [
            "network", "internet", "offline", "not connected", "connection", "timed out",
            "通信", "ネットワーク", "インターネット", "接続", "タイムアウト"
        ]
        return keywords.contains { lowercased.contains($0) }
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
        refreshTemporaryPauseState()
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
        !AdMobManager.shared.isAdMobTemporaryPauseModeActive
        && AdMobManager.shared.hasNetworkConnection
        && MonetizationPolicy.shouldShowPassiveAdvertising(
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
    @ObservedObject private var adMobManager = AdMobManager.shared

    private var shouldUsePassiveAds: Bool {
        !adMobManager.isAdMobTemporaryPauseModeActive
        && adMobManager.hasNetworkConnection
        && MonetizationPolicy.shouldShowPassiveAdvertising(
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
    @Published private(set) var isAvailableWithoutAd: Bool = false

    let adUnitID: String
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
            self.isAvailableWithoutAd = true
        }
    }

    func markAvailableWithoutAd() {
        isReady = true
        isLoading = false
        isAvailableWithoutAd = true
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

    func markUnavailable(message: String) {
        isReady = false
        isLoading = false
        isAvailableWithoutAd = false
        lastErrorMessage = message
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
        guard !AdMobManager.shared.isAdMobTemporaryPauseModeActive else {
            if AdMobManager.shared.canGrantRewardWithoutAd(for: adUnitID) {
                markAvailableWithoutAd()
            } else {
                markUnavailable(message: AdMobManager.shared.rewardedUnavailableMessage)
            }
            return
        }
        guard AdMobManager.shared.hasNetworkConnection else {
            markUnavailable(message: AdMobManager.shared.rewardedUnavailableMessage)
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
        guard !AdMobManager.shared.isAdMobTemporaryPauseModeActive else {
            if AdMobManager.shared.canGrantRewardWithoutAd(for: adUnitID) {
                markAvailableWithoutAd()
            } else {
                markUnavailable(message: AdMobManager.shared.rewardedUnavailableMessage)
            }
            return
        }
        guard AdMobManager.shared.hasNetworkConnection else {
            markUnavailable(message: AdMobManager.shared.rewardedUnavailableMessage)
            return
        }

        #if canImport(GoogleMobileAds)
        guard !isLoading else { return }
        guard canRequestNewAd() else { return }

        isReady = false
        isLoading = true
        isAvailableWithoutAd = false
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
                    manager.isAvailableWithoutAd = false
                    manager.rewardedAd = nil
                    AdMobManager.shared.recordRewardedLoadFailure(adUnitID: manager.adUnitID, error: error)
                    return
                }

                manager.rewardedAd = ad
                manager.rewardedAd?.fullScreenContentDelegate = manager
                manager.isReady = (ad != nil)
                manager.isAvailableWithoutAd = false
                AdMobManager.shared.recordRewardedLoadSuccess(adUnitID: manager.adUnitID)
            }
        }
        #else
        isReady = false
        isLoading = false
        isAvailableWithoutAd = false
        lastErrorMessage = "GoogleMobileAds がリンクされていません"
        #endif
    }

    func show(
        onReward: @escaping () -> Void,
        onUnavailable: (() -> Void)? = nil
    ) {
        if AdMobManager.shared.canGrantRewardWithoutAd(for: adUnitID) || !AdRuntimePolicy.canTouchAdvertisingSDK {
            markAvailableWithoutAd()
            onReward()
            return
        }

        guard AdMobManager.shared.hasNetworkConnection else {
            markUnavailable(message: AdMobManager.shared.rewardedUnavailableMessage)
            onUnavailable?()
            return
        }

        #if canImport(GoogleMobileAds)
        guard !isPresentingAd else {
            onUnavailable?()
            return
        }

        guard let ad = rewardedAd else {
            isReady = false
            isAvailableWithoutAd = false
            loadIfNeeded()
            onUnavailable?()
            return
        }

        guard let root = UIApplication.shared.topMostViewController() else {
            isReady = false
            isAvailableWithoutAd = false
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
        isAvailableWithoutAd = false
        rewardedAd = nil
        #else
        lastErrorMessage = "GoogleMobileAds がリンクされていません"
        isReady = false
        isAvailableWithoutAd = false
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
    private let startsEligibleOnFirstUserAction: Bool
    private let respectsMinimumPresentationInterval: Bool
    private var onDismiss: (() -> Void)?
    private var isPresentingAd: Bool = false
    private var userActionsSinceLastPresentation: Int
    private var lastPresentedAt: Date?
    private var lastLoadAt: Date?

    #if canImport(GoogleMobileAds)
    private var interstitialAd: InterstitialAd?
    #endif

    init(
        adUnitID: String,
        startsEligibleOnFirstUserAction: Bool = false,
        respectsMinimumPresentationInterval: Bool = true
    ) {
        self.adUnitID = adUnitID
        self.startsEligibleOnFirstUserAction = startsEligibleOnFirstUserAction
        self.respectsMinimumPresentationInterval = respectsMinimumPresentationInterval
        self.userActionsSinceLastPresentation = startsEligibleOnFirstUserAction ? max(0, AdRuntimePolicy.minimumInterstitialUserActions - 1) : 0
        super.init()
    }

    private var initialUserActionsSinceLastPresentation: Int {
        startsEligibleOnFirstUserAction ? max(0, AdRuntimePolicy.minimumInterstitialUserActions - 1) : 0
    }

    func clearLoadedAd() {
        isReady = false
        isLoading = false
        lastErrorMessage = nil
        onDismiss = nil
        isPresentingAd = false
        userActionsSinceLastPresentation = initialUserActionsSinceLastPresentation
        lastPresentedAt = nil
        lastLoadAt = nil
        AdRequestRateLimiter.shared.reset(key: adUnitID)
        #if canImport(GoogleMobileAds)
        interstitialAd = nil
        #endif
    }

    func loadIfNeeded() {
        guard AdRuntimePolicy.canTouchAdvertisingSDK,
              !AdMobManager.shared.isAdMobTemporaryPauseModeActive,
              AdMobManager.shared.hasNetworkConnection else {
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
        guard AdRuntimePolicy.canTouchAdvertisingSDK,
              !AdMobManager.shared.isAdMobTemporaryPauseModeActive,
              AdMobManager.shared.hasNetworkConnection else {
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
        guard AdRuntimePolicy.canTouchAdvertisingSDK,
              !AdMobManager.shared.isAdMobTemporaryPauseModeActive,
              AdMobManager.shared.hasNetworkConnection else {
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

        if respectsMinimumPresentationInterval,
           let lastPresentedAt,
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
