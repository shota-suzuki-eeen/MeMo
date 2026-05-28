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

    var updatedAt: Date

    static let placeholder = MeMoWatchSnapshot(
        todaySteps: 0,
        dailyStepGoal: 10_000,
        happinessPoint: 0,
        happinessLevel: 0,
        happinessMaxPoint: 100,
        fullnessLevel: 0,
        fullnessMaxLevel: 5,
        characterAssetName: "pet_000",
        backgroundAssetName: "Home_background",
        updatedAt: Date()
    )
}

@MainActor
final class MeMoWatchConnectivityBridge: NSObject, ObservableObject {
    static let shared = MeMoWatchConnectivityBridge()

    private nonisolated static let userDefaultsKey = "memo.watch.latestSnapshot"

    @Published private(set) var latestSnapshot: MeMoWatchSnapshot = MeMoWatchConnectivityBridge.initialSnapshot()

    #if canImport(WatchConnectivity)
    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }
    #endif

    #if os(iOS)
    private weak var appState: AppState?
    private weak var healthKitManager: HealthKitManager?
    #endif

    private override init() {
        super.init()
    }

    func activate() {
        #if canImport(WatchConnectivity)
        guard let session else { return }
        guard session.activationState == .notActivated else { return }
        session.delegate = self
        session.activate()
        #endif
    }

    #if os(iOS)
    func install(appState: AppState, healthKitManager: HealthKitManager) {
        self.appState = appState
        self.healthKitManager = healthKitManager
        activate()
        publishCurrentSnapshot()
    }

    func publishCurrentSnapshot(
        backgroundAssetName: String = "Home_background",
        now: Date = Date()
    ) {
        guard let appState else { return }

        let todaySteps = max(
            0,
            max(
                healthKitManager?.todaySteps ?? 0,
                appState.cachedTodaySteps
            )
        )

        let snapshot = MeMoWatchSnapshot(
            todaySteps: todaySteps,
            dailyStepGoal: AppState.fixedDailyStepGoal,
            happinessPoint: appState.happinessPoint,
            happinessLevel: appState.happinessLevel,
            happinessMaxPoint: AppState.happinessMaxPointsPerLevel,
            fullnessLevel: appState.currentSatisfaction(now: now),
            fullnessMaxLevel: AppState.fullnessMaxLevel,
            characterAssetName: PetMaster.assetName(for: appState.normalizedCurrentPetID),
            backgroundAssetName: backgroundAssetName,
            updatedAt: now
        )

        apply(snapshot)
        send(snapshot)
    }
    #endif

    func sendPettingTouch() {
        #if os(watchOS)
        #if canImport(WatchConnectivity)
        guard let session else { return }
        guard session.activationState == .activated else { return }

        let message: [String: Any] = [
            "event": "pettingTouch",
            "sentAt": Date().timeIntervalSince1970
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
        #endif
        #endif
    }

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
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
        #endif
        #endif
    }

    private nonisolated static func initialSnapshot() -> MeMoWatchSnapshot {
        loadStoredSnapshot(key: userDefaultsKey) ?? .placeholder
    }

    private nonisolated static func payload(from snapshot: MeMoWatchSnapshot) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(snapshot) else { return nil }
        return ["snapshotData": data]
    }

    private nonisolated static func snapshot(from dictionary: [String: Any]) -> MeMoWatchSnapshot? {
        if let data = dictionary["snapshotData"] as? Data {
            return try? JSONDecoder().decode(MeMoWatchSnapshot.self, from: data)
        }

        return nil
    }

    private nonisolated static func store(_ snapshot: MeMoWatchSnapshot, key: String) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private nonisolated static func loadStoredSnapshot(key: String) -> MeMoWatchSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(MeMoWatchSnapshot.self, from: data)
    }
}

#if canImport(WatchConnectivity)
extension MeMoWatchConnectivityBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        #if os(iOS)
        Task { @MainActor in
            self.publishCurrentSnapshot()
        }
        #endif
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String : Any]
    ) {
        guard let snapshot = Self.snapshot(from: applicationContext) else { return }
        Task { @MainActor in
            self.apply(snapshot)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String : Any] = [:]
    ) {
        handleIncoming(dictionary: userInfo)
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String : Any]
    ) {
        handleIncoming(dictionary: message)
    }

    private nonisolated func handleIncoming(dictionary: [String: Any]) {
        if let snapshot = Self.snapshot(from: dictionary) {
            Task { @MainActor in
                self.apply(snapshot)
            }
            return
        }

        #if os(iOS)
        if dictionary["event"] as? String == "pettingTouch" {
            Task { @MainActor in
                guard let appState = self.appState else { return }
                _ = appState.registerHappinessPettingTouch(count: 1, now: Date())
                self.publishCurrentSnapshot()
            }
        }
        #endif
    }
}
#endif
