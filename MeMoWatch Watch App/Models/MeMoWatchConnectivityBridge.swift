//
//  MeMoWatchConnectivityBridge.swift
//  MeMo
//
//  Shared iPhone / Watch bridge.
//  Add this file to both the iPhone App target and the Watch App target.
//

import Combine
import Foundation

#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

#if os(iOS) && canImport(WidgetKit)
import WidgetKit
#endif

#if os(iOS) && canImport(UIKit)
import UIKit
#endif

struct MeMoWatchFoodItemSnapshot: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var assetName: String
    var rarity: String
    var count: Int

    var isRare: Bool {
        rarity == "R"
    }
}

struct MeMoWatchToiletPoopSnapshot: Codable, Equatable, Identifiable {
    var id: String
    var centerXRatio: Double
    var centerYRatio: Double
    var rotationDegrees: Double
    var isFlippedHorizontally: Bool
    var cleanedProgress: Double
}

struct MeMoWatchSnapshot: Codable, Equatable {
    var todaySteps: Int
    var dailyStepGoal: Int

    var happinessPoint: Int
    var happinessLevel: Int
    var happinessMaxPoint: Int

    var fullnessLevel: Int
    var fullnessMaxLevel: Int

    var characterAssetName: String
    var backgroundAssetName: String

    // Optional fields keep snapshots saved by older app versions decodable.
    var desiredFoodID: String? = nil
    var desiredFoodAssetName: String? = nil
    var ownedFoods: [MeMoWatchFoodItemSnapshot]? = nil

    // Toilet fields are optional so snapshots stored by earlier app versions remain decodable.
    var hasToiletFlag: Bool? = nil
    var toiletPoops: [MeMoWatchToiletPoopSnapshot]? = nil

    var updatedAt: Date

    static let placeholder = MeMoWatchSnapshot(
        todaySteps: 0,
        dailyStepGoal: 10_000,
        happinessPoint: 0,
        happinessLevel: 0,
        happinessMaxPoint: 100,
        fullnessLevel: 0,
        fullnessMaxLevel: 5,
        characterAssetName: "person",
        backgroundAssetName: "Home_background",
        desiredFoodID: nil,
        desiredFoodAssetName: nil,
        ownedFoods: [],
        hasToiletFlag: false,
        toiletPoops: [],
        updatedAt: Date()
    )
}

@MainActor
final class MeMoWatchConnectivityBridge: NSObject, ObservableObject {
    static let shared = MeMoWatchConnectivityBridge()

    private static let userDefaultsKey = "memo.watch.latestSnapshot"

    @Published private(set) var latestSnapshot: MeMoWatchSnapshot =
        MeMoWatchConnectivityBridge.initialSnapshot()

    #if canImport(WatchConnectivity)
    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }
    #endif

    #if os(iOS)
    private weak var appState: AppState?
    private weak var healthKitManager: HealthKitManager?
    private var lastBackgroundAssetName: String = "Home_background"
    private var persistChangesHandler: (() -> Void)?
    private var pendingWatchEvents: [[String: Any]] = []
    private var processedWatchRequestIDs: Set<String> = []
    private var processedWatchRequestIDOrder: [String] = []
    private var isRefreshingStepsForWatch = false
    #endif

    private override init() {
        super.init()
    }

    func activate() {
        #if canImport(WatchConnectivity)
        guard let session else { return }

        session.delegate = self

        if session.activationState == .notActivated {
            session.activate()
        }
        #endif
    }

    #if os(iOS)
    func install(
        appState: AppState,
        healthKitManager: HealthKitManager,
        persistChanges: (() -> Void)? = nil
    ) {
        self.appState = appState
        self.healthKitManager = healthKitManager
        self.persistChangesHandler = persistChanges
        activate()
        publishCurrentSnapshot(backgroundAssetName: nil)
        flushPendingWatchEventsIfNeeded()
    }

    /// Watch から最新状態を要求された時に、iPhone 側 HealthKit を再取得してから
    /// iPhone を正本としたスナップショットを返す。
    ///
    /// iPhone が前面表示中は HomeView の既存同期処理を優先し、ここでは歩数通貨を
    /// 変更しない。iPhone がバックグラウンド中のみキャッシュ差分を正式に加算することで、
    /// HomeView の同期処理との二重加算を防ぐ。
    func refreshLatestStepsAndPublish(
        backgroundAssetName: String? = nil,
        now: Date = Date()
    ) async {
        guard !isRefreshingStepsForWatch else {
            publishCurrentSnapshot(backgroundAssetName: backgroundAssetName, now: now)
            return
        }

        isRefreshingStepsForWatch = true
        defer { isRefreshingStepsForWatch = false }

        if let healthKitManager {
            await healthKitManager.refreshTodayStepsForWidget(now: now)
        }

        synchronizeBackgroundStepGainIfNeeded(now: now)
        publishCurrentSnapshot(backgroundAssetName: backgroundAssetName, now: now)
    }

    private func synchronizeBackgroundStepGainIfNeeded(now: Date) {
        guard let appState, let healthKitManager else { return }

        #if canImport(UIKit)
        // Foregroundでは HomeView.runSync が既存仕様どおり加算を担当する。
        // Watch要求とHomeView同期が同時に走った場合の二重加算を防ぐため、
        // ここで正式加算するのはiPhoneがバックグラウンドの時だけに限定する。
        guard UIApplication.shared.applicationState == .background else { return }
        #endif

        let todayKey = AppState.makeDayKey(now)

        if appState.lastDayKey != todayKey {
            appState.cachedTodaySteps = 0
            appState.cachedTodayMeterSteps = 0
            appState.ensureDailyResetIfNeeded(now: now)
            appState.lastSyncedAt = Calendar.current.startOfDay(for: now)
        }

        let previousCachedSteps = max(0, appState.cachedTodaySteps)
        let fetchedSteps = max(0, healthKitManager.todaySteps)
        let cacheResult = appState.updateTodayStepCacheProtectingZero(
            fetchedSteps: fetchedSteps,
            todayKey: todayKey
        )

        let deltaSteps = max(0, cacheResult.stepsToUse - previousCachedSteps)
        appState.lastSyncedAt = now

        if deltaSteps > 0 {
            _ = appState.addWalletSteps(deltaSteps)
        }

        persistChangesHandler?()
        refreshWidgetSnapshotIfAvailable(appState: appState, now: now)
    }

    func publishCurrentSnapshot(
        backgroundAssetName: String? = nil,
        now: Date = Date()
    ) {
        guard let appState else { return }

        // Keep the iPhone toilet timeline authoritative, including the 15-minute
        // poop growth rule and the same maximum of 10 poops used by HomeView.
        if appState.hasToiletFlag {
            let didUpdateToiletPoops = appState.updateToiletPoopsByTime(now: now)
            if didUpdateToiletPoops {
                persistChangesHandler?()
                refreshWidgetSnapshotIfAvailable(appState: appState, now: now)
            }
        }

        let resolvedBackgroundAssetName: String
        if let backgroundAssetName,
           !backgroundAssetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedBackgroundAssetName = backgroundAssetName
            lastBackgroundAssetName = backgroundAssetName
        } else {
            resolvedBackgroundAssetName = lastBackgroundAssetName
        }

        let todaySteps = max(
            0,
            max(
                healthKitManager?.todaySteps ?? 0,
                appState.cachedTodaySteps
            )
        )

        let fullnessLevel = appState.currentSatisfaction(now: now)
        if fullnessLevel < AppState.fullnessMaxLevel {
            _ = appState.ensureDesiredFoodIfNeeded()
        }

        let desiredFood = appState.desiredFood
        let ownedFoods = FoodCatalog.all.compactMap { food -> MeMoWatchFoodItemSnapshot? in
            let count = appState.foodCount(foodId: food.id)
            guard count > 0 else { return nil }

            return MeMoWatchFoodItemSnapshot(
                id: food.id,
                name: food.name,
                assetName: food.assetName,
                rarity: food.isShopEligible ? "N" : "R",
                count: count
            )
        }

        let hasToiletFlag = appState.hasToiletFlag
        let toiletPoops = Array(
            appState.toiletPoops()
                .filter { !$0.isCleared }
                .prefix(AppState.toiletPoopMaxCount)
        )
        .map { poop in
            MeMoWatchToiletPoopSnapshot(
                id: poop.id,
                centerXRatio: poop.centerXRatio,
                centerYRatio: poop.centerYRatio,
                rotationDegrees: poop.rotationDegrees,
                isFlippedHorizontally: poop.isFlippedHorizontally,
                cleanedProgress: max(0, min(1, poop.cleanedProgress))
            )
        }

        let snapshot = MeMoWatchSnapshot(
            todaySteps: todaySteps,
            dailyStepGoal: AppState.fixedDailyStepGoal,
            happinessPoint: appState.happinessPoint,
            happinessLevel: appState.happinessLevel,
            happinessMaxPoint: AppState.happinessMaxPointsPerLevel,
            fullnessLevel: fullnessLevel,
            fullnessMaxLevel: AppState.fullnessMaxLevel,
            characterAssetName: PetMaster.assetName(
                for: appState.normalizedCurrentPetID
            ),
            backgroundAssetName: resolvedBackgroundAssetName,
            desiredFoodID: desiredFood?.id,
            desiredFoodAssetName: desiredFood?.assetName,
            ownedFoods: ownedFoods,
            hasToiletFlag: hasToiletFlag,
            toiletPoops: toiletPoops,
            updatedAt: now
        )

        apply(snapshot)
        send(snapshot)
    }

    @discardableResult
    private func resolveFoodFeedRequest(foodID: String) -> Bool {
        guard let appState else { return false }
        guard !appState.hasToiletFlag else {
            publishCurrentSnapshot(backgroundAssetName: nil)
            return false
        }
        guard let food = FoodCatalog.byId(foodID) else {
            publishCurrentSnapshot(backgroundAssetName: nil)
            return false
        }

        let now = Date()
        let feedState = appState.canFeedNow(now: now)
        guard feedState.can else {
            publishCurrentSnapshot(backgroundAssetName: nil, now: now)
            return false
        }

        guard appState.foodCount(foodId: foodID) > 0 else {
            publishCurrentSnapshot(backgroundAssetName: nil, now: now)
            return false
        }

        guard appState.consumeFood(foodId: foodID, count: 1) else {
            publishCurrentSnapshot(backgroundAssetName: nil, now: now)
            return false
        }

        let feedResult = appState.feedOnce(now: now)
        guard feedResult.didFeed else {
            publishCurrentSnapshot(backgroundAssetName: nil, now: now)
            return false
        }

        _ = appState.resolveFood(now: now)

        let happinessBonus = appState.happinessBonusPoints(forFoodID: food.id)
            + appState.desiredFoodAdditionalHappinessBonus(forFoodID: food.id)

        _ = appState.registerDesiredFoodFeedingResult(foodID: food.id)

        if happinessBonus > 0 {
            _ = appState.addHappinessPoints(happinessBonus, now: now)
        }

        persistChangesHandler?()
        refreshWidgetSnapshotIfAvailable(appState: appState, now: now)
        publishCurrentSnapshot(backgroundAssetName: nil, now: now)
        return true
    }

    @discardableResult
    private func resolveToiletPoopProgressRequest(
        poopID: String,
        progress: Double
    ) -> Bool {
        guard let appState else { return false }

        let now = Date()

        if appState.hasToiletFlag {
            _ = appState.updateToiletPoopsByTime(now: now)
        }

        guard appState.hasToiletFlag else {
            publishCurrentSnapshot(backgroundAssetName: nil, now: now)
            return false
        }

        let clampedProgress = max(0, min(1, progress))
        guard appState.toiletPoops().contains(where: {
            $0.id == poopID && !$0.isCleared
        }) else {
            publishCurrentSnapshot(backgroundAssetName: nil, now: now)
            return false
        }

        _ = appState.updateToiletPoopProgress(
            id: poopID,
            progress: clampedProgress
        )

        if clampedProgress >= 1 {
            _ = appState.markToiletPoopCleared(id: poopID)
        }

        if !appState.hasRemainingToiletPoops {
            let result = appState.resolveToilet(now: now)
            if result.didResolve {
                _ = appState.addHappinessPoints(10, now: now)
            }
        }

        persistChangesHandler?()
        refreshWidgetSnapshotIfAvailable(appState: appState, now: now)
        publishCurrentSnapshot(backgroundAssetName: nil, now: now)
        return true
    }

    private func refreshWidgetSnapshotIfAvailable(appState: AppState, now: Date) {
        #if canImport(WidgetKit)
        let todaySteps = max(
            0,
            max(
                healthKitManager?.todaySteps ?? 0,
                appState.cachedTodaySteps
            )
        )
        let widgetState = appState.makeWidgetStateSnapshot(todaySteps: todaySteps)
        let changed = HomeWidgetBridge.save(widgetState: widgetState, state: appState)
        if changed {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
    #endif

    func sendPettingTouch() {
        #if os(watchOS)
        sendWatchEvent("pettingTouch")
        #endif
    }

    func sendFoodFeedRequest(foodID: String) {
        #if os(watchOS)
        guard !foodID.isEmpty else { return }
        sendWatchEvent(
            "feedFood",
            payload: ["foodID": foodID]
        )
        #endif
    }

    func sendToiletPoopProgress(
        poopID: String,
        progress: Double
    ) {
        #if os(watchOS)
        guard !poopID.isEmpty else { return }
        sendWatchEvent(
            "updateToiletPoopProgress",
            payload: [
                "poopID": poopID,
                "progress": max(0, min(1, progress))
            ]
        )
        #endif
    }

    func requestCurrentSnapshot() {
        #if os(watchOS)
        sendWatchEvent("requestSnapshot")
        #endif
    }

    #if os(watchOS)
    private func sendWatchEvent(
        _ event: String,
        payload: [String: Any] = [:]
    ) {
        #if canImport(WatchConnectivity)
        guard let session else { return }

        var message = payload
        message["event"] = event
        message["requestID"] = UUID().uuidString
        message["sentAt"] = Date().timeIntervalSince1970

        guard session.activationState == .activated else {
            session.activate()

            if event == "requestSnapshot" {
                try? session.updateApplicationContext(message)
            } else {
                session.transferUserInfo(message)
            }
            return
        }

        if session.isReachable {
            session.sendMessage(
                message,
                replyHandler: nil,
                errorHandler: { _ in
                    if event == "requestSnapshot" {
                        try? session.updateApplicationContext(message)
                    } else {
                        session.transferUserInfo(message)
                    }
                }
            )
        } else if event == "requestSnapshot" {
            // 定期的な最新歩数要求はキューを積み上げず、最新1件だけを保持する。
            try? session.updateApplicationContext(message)
        } else {
            session.transferUserInfo(message)
        }
        #endif
    }
    #endif

    private func apply(_ snapshot: MeMoWatchSnapshot) {
        latestSnapshot = snapshot
        Self.store(snapshot, key: Self.userDefaultsKey)
    }

    private func send(_ snapshot: MeMoWatchSnapshot) {
        #if os(iOS)
        #if canImport(WatchConnectivity)
        guard let session else { return }
        guard session.activationState == .activated else { return }
        guard let payload = Self.payload(from: snapshot) else { return }

        do {
            try session.updateApplicationContext(payload)
        } catch {
            session.transferUserInfo(payload)
        }

        if session.isReachable {
            session.sendMessage(
                payload,
                replyHandler: nil,
                errorHandler: nil
            )
        }
        #endif
        #endif
    }

    private func handleIncomingOnMainActor(dictionary: [String: Any]) {
        if let snapshot = Self.snapshot(from: dictionary) {
            apply(snapshot)
            return
        }

        #if os(iOS)
        guard let event = dictionary["event"] as? String else { return }

        if appState == nil {
            enqueuePendingWatchEvent(dictionary)
            return
        }

        if let requestID = dictionary["requestID"] as? String {
            guard markWatchRequestAsProcessedIfNeeded(requestID) else { return }
        }

        switch event {
        case "pettingTouch":
            guard let appState else { return }
            _ = appState.registerHappinessPettingTouch(
                count: 1,
                now: Date()
            )
            persistChangesHandler?()
            publishCurrentSnapshot(backgroundAssetName: nil)

        case "feedFood":
            guard let foodID = dictionary["foodID"] as? String else { return }
            _ = resolveFoodFeedRequest(foodID: foodID)

        case "updateToiletPoopProgress":
            guard let poopID = dictionary["poopID"] as? String else { return }
            let progress: Double
            if let raw = dictionary["progress"] as? Double {
                progress = raw
            } else if let raw = dictionary["progress"] as? NSNumber {
                progress = raw.doubleValue
            } else {
                return
            }
            _ = resolveToiletPoopProgressRequest(
                poopID: poopID,
                progress: progress
            )

        case "requestSnapshot":
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.refreshLatestStepsAndPublish(backgroundAssetName: nil)
            }

        default:
            break
        }
        #endif
    }

    #if os(iOS)
    private func enqueuePendingWatchEvent(_ dictionary: [String: Any]) {
        if let requestID = dictionary["requestID"] as? String,
           pendingWatchEvents.contains(where: { $0["requestID"] as? String == requestID }) {
            return
        }

        pendingWatchEvents.append(dictionary)
        if pendingWatchEvents.count > 32 {
            pendingWatchEvents.removeFirst(pendingWatchEvents.count - 32)
        }
    }

    private func flushPendingWatchEventsIfNeeded() {
        guard appState != nil, !pendingWatchEvents.isEmpty else { return }
        let queuedEvents = pendingWatchEvents
        pendingWatchEvents.removeAll()

        for event in queuedEvents {
            handleIncomingOnMainActor(dictionary: event)
        }
    }

    private func markWatchRequestAsProcessedIfNeeded(_ requestID: String) -> Bool {
        guard !processedWatchRequestIDs.contains(requestID) else { return false }

        processedWatchRequestIDs.insert(requestID)
        processedWatchRequestIDOrder.append(requestID)

        if processedWatchRequestIDOrder.count > 128 {
            let overflow = processedWatchRequestIDOrder.count - 128
            let removed = Array(processedWatchRequestIDOrder.prefix(overflow))
            processedWatchRequestIDOrder.removeFirst(overflow)
            for id in removed {
                processedWatchRequestIDs.remove(id)
            }
        }

        return true
    }
    #endif

    private static func initialSnapshot() -> MeMoWatchSnapshot {
        loadStoredSnapshot(key: userDefaultsKey) ?? .placeholder
    }

    private static func payload(
        from snapshot: MeMoWatchSnapshot
    ) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return nil
        }
        return ["snapshotData": data]
    }

    private static func snapshot(
        from dictionary: [String: Any]
    ) -> MeMoWatchSnapshot? {
        guard let data = dictionary["snapshotData"] as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(
            MeMoWatchSnapshot.self,
            from: data
        )
    }

    private static func store(
        _ snapshot: MeMoWatchSnapshot,
        key: String
    ) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadStoredSnapshot(
        key: String
    ) -> MeMoWatchSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(
            MeMoWatchSnapshot.self,
            from: data
        )
    }
}

#if canImport(WatchConnectivity)
extension MeMoWatchConnectivityBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }

        Task { @MainActor in
            #if os(iOS)
            self.publishCurrentSnapshot(backgroundAssetName: nil)
            #elseif os(watchOS)
            self.requestCurrentSnapshot()
            #endif
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            self.handleIncomingOnMainActor(
                dictionary: applicationContext
            )
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            self.handleIncomingOnMainActor(dictionary: userInfo)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            self.handleIncomingOnMainActor(dictionary: message)
        }
    }
}
#endif
