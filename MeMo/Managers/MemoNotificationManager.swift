//
//  MemoNotificationManager.swift
//  MeMo
//
//  Local-notification contract and coordinator. Actual event timing is owned by TASK_008.
//

import Foundation
import Combine
import UserNotifications

enum MemoNotificationRoute: String, Sendable {
    case home
    case gacha
    case fishing
}

enum MemoNotificationKind: String, CaseIterable, Identifiable, Sendable {
    case fullnessZero
    case toilet
    case sleepEnded
    case gachaFreeTen
    case fishingTimeBoostEnded
    case fishingBasketFull

    var id: String { rawValue }

    var route: MemoNotificationRoute {
        switch self {
        case .fullnessZero, .toilet, .sleepEnded:
            return .home
        case .gachaFreeTen:
            return .gacha
        case .fishingTimeBoostEnded, .fishingBasketFull:
            return .fishing
        }
    }

    var categoryIdentifier: String { "memo.notification.category.\(rawValue)" }

    var preferenceKey: String { "memo.notifications.\(rawValue).enabled" }
}

enum MemoNotificationRequestID: String, CaseIterable, Identifiable, Sendable {
    case fullnessZero = "memo.notification.fullnessZero"
    case toilet = "memo.notification.toilet"
    case sleepEnded = "memo.notification.sleepEnded"
    case gachaFreeTenMorning = "memo.notification.gachaFreeTen.morning"
    case gachaFreeTenNoon = "memo.notification.gachaFreeTen.noon"
    case gachaFreeTenEvening = "memo.notification.gachaFreeTen.evening"
    case fishingTimeBoostEnded = "memo.notification.fishingTimeBoostEnded"
    case fishingBasketFull = "memo.notification.fishingBasketFull"

    var id: String { rawValue }
    var identifier: String { rawValue }

    var kind: MemoNotificationKind {
        switch self {
        case .fullnessZero:
            return .fullnessZero
        case .toilet:
            return .toilet
        case .sleepEnded:
            return .sleepEnded
        case .gachaFreeTenMorning, .gachaFreeTenNoon, .gachaFreeTenEvening:
            return .gachaFreeTen
        case .fishingTimeBoostEnded:
            return .fishingTimeBoostEnded
        case .fishingBasketFull:
            return .fishingBasketFull
        }
    }
}

enum MemoNotificationPreferences {
    static let masterEnabledKey = "memo.notifications.enabled"

    static func value(forKey key: String, defaults: UserDefaults = .standard) -> Bool {
        // `bool(forKey:)` returns false for a missing key. Missing notification keys intentionally mean ON.
        defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
    }

    static func isKindEnabled(
        _ kind: MemoNotificationKind,
        defaults: UserDefaults = .standard
    ) -> Bool {
        value(forKey: masterEnabledKey, defaults: defaults)
            && value(forKey: kind.preferenceKey, defaults: defaults)
    }
}

struct MemoLocalNotificationRequest: Sendable {
    let requestID: MemoNotificationRequestID
    let title: String
    let body: String
    let trigger: UNNotificationTrigger

    var kind: MemoNotificationKind { requestID.kind }

    init(
        requestID: MemoNotificationRequestID,
        title: String,
        body: String,
        trigger: UNNotificationTrigger
    ) {
        self.requestID = requestID
        self.title = title
        self.body = body
        self.trigger = trigger
    }
}

@MainActor
final class MemoNotificationManager: NSObject, ObservableObject {
    static let shared = MemoNotificationManager()

    enum UserInfoKey {
        static let kind = "memoNotificationKind"
        static let route = "memoNotificationRoute"
    }

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var pendingRoute: MemoNotificationRoute?
    @Published private(set) var isPendingRouteReadyForHome = false

    private let center: UNUserNotificationCenter
    private var isAuthorizationRequestInFlight = false

    private override init() {
        center = .current()
        super.init()
    }

    func configure() {
        center.delegate = self
        center.setNotificationCategories(Set(MemoNotificationKind.allCases.map {
            UNNotificationCategory(
                identifier: $0.categoryIdentifier,
                actions: [],
                intentIdentifiers: []
            )
        }))
        Task { await refreshAuthorizationStatus() }
    }

    @discardableResult
    func refreshAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        return settings.authorizationStatus
    }

    /// Called only after the mandatory onboarding is complete and Home is ready.
    func requestAuthorizationFromHomeIfNeeded() async {
        guard !isAuthorizationRequestInFlight else { return }
        guard await refreshAuthorizationStatus() == .notDetermined else { return }
        isAuthorizationRequestInFlight = true
        defer { isAuthorizationRequestInFlight = false }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        await refreshAuthorizationStatus()
    }

    func schedule(_ request: MemoLocalNotificationRequest) async throws {
        guard MemoNotificationPreferences.isKindEnabled(request.kind) else {
            cancel(request.kind)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.categoryIdentifier = request.kind.categoryIdentifier
        content.userInfo = [
            UserInfoKey.kind: request.kind.rawValue,
            UserInfoKey.route: request.kind.route.rawValue
        ]

        let notificationRequest = UNNotificationRequest(
            identifier: request.requestID.identifier,
            content: content,
            trigger: request.trigger
        )
        try await center.add(notificationRequest)
    }

    func cancel(_ kind: MemoNotificationKind) {
        let identifiers = MemoNotificationRequestID.allCases
            .filter { $0.kind == kind }
            .map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func cancelAll() {
        let identifiers = MemoNotificationRequestID.allCases.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    /// TASK_008 can provide its complete desired set here without duplicating identifier or preference logic.
    func reconcile(with desiredRequests: [MemoLocalNotificationRequest]) async {
        let desiredRequestIDs = Set(desiredRequests.map(\.requestID))
        for requestID in MemoNotificationRequestID.allCases where !desiredRequestIDs.contains(requestID) {
            cancel(requestID: requestID)
        }
        for request in desiredRequests {
            try? await schedule(request)
        }
    }

    private func cancel(requestID: MemoNotificationRequestID) {
        center.removePendingNotificationRequests(withIdentifiers: [requestID.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [requestID.identifier])
    }

    func beginRootPresentationDismissal() {
        guard pendingRoute != nil else { return }
        isPendingRouteReadyForHome = false
    }

    func markPendingRouteReadyForHome() {
        guard pendingRoute != nil else { return }
        isPendingRouteReadyForHome = true
    }

    func consumePendingRouteIfReady() -> MemoNotificationRoute? {
        guard isPendingRouteReadyForHome else { return nil }
        defer { pendingRoute = nil }
        isPendingRouteReadyForHome = false
        return pendingRoute
    }

    nonisolated private static func kind(from userInfo: [AnyHashable: Any]) -> MemoNotificationKind? {
        guard let rawValue = userInfo[UserInfoKey.kind] as? String else { return nil }
        return MemoNotificationKind(rawValue: rawValue)
    }

    nonisolated private static func route(from userInfo: [AnyHashable: Any]) -> MemoNotificationRoute? {
        if let kind = kind(from: userInfo) {
            return kind.route
        }
        guard let rawValue = userInfo[UserInfoKey.route] as? String else { return nil }
        return MemoNotificationRoute(rawValue: rawValue)
    }
}

extension MemoNotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard let kind = Self.kind(from: notification.request.content.userInfo),
              MemoNotificationPreferences.isKindEnabled(kind) else {
            completionHandler([])
            return
        }
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let route = Self.route(from: response.notification.request.content.userInfo) {
            Task { @MainActor in
                // Stored until Home consumes it, including when the delegate runs during a cold launch.
                isPendingRouteReadyForHome = false
                pendingRoute = route
            }
        }
        completionHandler()
    }
}
