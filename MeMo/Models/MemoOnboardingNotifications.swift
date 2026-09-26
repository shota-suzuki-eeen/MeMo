//
//  MemoOnboardingNotifications.swift
//  MeMo
//
//  Lightweight bridge for existing SwiftUI views that are not owned by the onboarding ViewModel.
//  iOS 18.6+
//

import Foundation

extension Notification.Name {
    static let memoOnboardingRequestScreen = Notification.Name("memo.onboarding.requestScreen")
    static let memoOnboardingRequestFoodTutorial = Notification.Name("memo.onboarding.requestFoodTutorial")
    static let memoOnboardingRequestToiletTutorial = Notification.Name("memo.onboarding.requestToiletTutorial")
    static let memoOnboardingFoodDidFeed = Notification.Name("memo.onboarding.foodDidFeed")
    static let memoOnboardingTutorialFoodSelectionStarted = Notification.Name("memo.onboarding.tutorialFoodSelectionStarted")
    static let memoOnboardingTutorialFoodScopeTap = Notification.Name("memo.onboarding.tutorialFoodScopeTap")
    static let memoOnboardingTutorialFoodScopeSwipe = Notification.Name("memo.onboarding.tutorialFoodScopeSwipe")
    static let memoOnboardingTutorialFoodScopeDragChanged = Notification.Name("memo.onboarding.tutorialFoodScopeDragChanged")
    static let memoOnboardingTutorialFoodScopeDragReset = Notification.Name("memo.onboarding.tutorialFoodScopeDragReset")
    static let memoOnboardingToiletScratchStarted = Notification.Name("memo.onboarding.toiletScratchStarted")
    static let memoOnboardingToiletDidBecomeClean = Notification.Name("memo.onboarding.toiletDidBecomeClean")
    static let memoOnboardingStartFirstFreeGachaRequested = Notification.Name("memo.onboarding.startFirstFreeGachaRequested")
    static let memoOnboardingTutorialGachaFinished = Notification.Name("memo.onboarding.tutorialGachaFinished")
    static let memoOnboardingTutorialZukanFinished = Notification.Name("memo.onboarding.tutorialZukanFinished")
}

enum MemoOnboardingNotificationUserInfoKey {
    static let foodID = "foodID"
    static let force = "force"
    static let screen = "screen"
    static let translationHeight = "translationHeight"
    static let predictedEndTranslationHeight = "predictedEndTranslationHeight"
}

enum MemoOnboardingNotifier {
    static func request(_ screen: MemoOnboardingScreen, force: Bool = false) {
        NotificationCenter.default.post(
            name: .memoOnboardingRequestScreen,
            object: screen,
            userInfo: [MemoOnboardingNotificationUserInfoKey.force: force]
        )
    }

    static func requestFoodTutorial() {
        NotificationCenter.default.post(name: .memoOnboardingRequestFoodTutorial, object: nil)
    }

    static func requestToiletTutorial() {
        NotificationCenter.default.post(name: .memoOnboardingRequestToiletTutorial, object: nil)
    }

    static func notifyFoodDidFeed(foodID: String) {
        NotificationCenter.default.post(
            name: .memoOnboardingFoodDidFeed,
            object: nil,
            userInfo: [MemoOnboardingNotificationUserInfoKey.foodID: foodID]
        )
    }

    static func notifyTutorialFoodSelectionStarted(foodID: String?) {
        var userInfo: [String: Any] = [:]
        if let foodID {
            userInfo[MemoOnboardingNotificationUserInfoKey.foodID] = foodID
        }

        NotificationCenter.default.post(
            name: .memoOnboardingTutorialFoodSelectionStarted,
            object: nil,
            userInfo: userInfo
        )
    }

    static func notifyTutorialFoodScopeTap(screen: MemoOnboardingScreen) {
        NotificationCenter.default.post(
            name: .memoOnboardingTutorialFoodScopeTap,
            object: nil,
            userInfo: [MemoOnboardingNotificationUserInfoKey.screen: screen.rawValue]
        )
    }

    static func notifyTutorialFoodScopeSwipe(screen: MemoOnboardingScreen) {
        NotificationCenter.default.post(
            name: .memoOnboardingTutorialFoodScopeSwipe,
            object: nil,
            userInfo: [MemoOnboardingNotificationUserInfoKey.screen: screen.rawValue]
        )
    }

    static func notifyTutorialFoodScopeDragChanged(
        screen: MemoOnboardingScreen,
        translationHeight: Double,
        predictedEndTranslationHeight: Double
    ) {
        NotificationCenter.default.post(
            name: .memoOnboardingTutorialFoodScopeDragChanged,
            object: nil,
            userInfo: [
                MemoOnboardingNotificationUserInfoKey.screen: screen.rawValue,
                MemoOnboardingNotificationUserInfoKey.translationHeight: translationHeight,
                MemoOnboardingNotificationUserInfoKey.predictedEndTranslationHeight: predictedEndTranslationHeight
            ]
        )
    }

    static func notifyTutorialFoodScopeDragReset(screen: MemoOnboardingScreen) {
        NotificationCenter.default.post(
            name: .memoOnboardingTutorialFoodScopeDragReset,
            object: nil,
            userInfo: [MemoOnboardingNotificationUserInfoKey.screen: screen.rawValue]
        )
    }

    static func notifyTutorialFoodSelectionCancelled() {
        // Down-swipe cancellation is intentionally ignored during the mandatory food tutorial.
        // Keeping this no-op preserves compatibility if HomeView still calls the old hook.
    }

    static func notifyToiletScratchStarted() {
        NotificationCenter.default.post(name: .memoOnboardingToiletScratchStarted, object: nil)
    }

    static func notifyToiletDidBecomeClean() {
        NotificationCenter.default.post(name: .memoOnboardingToiletDidBecomeClean, object: nil)
    }

    static func requestFirstFreeGachaStart() {
        NotificationCenter.default.post(name: .memoOnboardingStartFirstFreeGachaRequested, object: nil)
    }

    static func notifyTutorialGachaFinished() {
        NotificationCenter.default.post(name: .memoOnboardingTutorialGachaFinished, object: nil)
    }

    static func notifyTutorialZukanFinished() {
        NotificationCenter.default.post(name: .memoOnboardingTutorialZukanFinished, object: nil)
    }
}
