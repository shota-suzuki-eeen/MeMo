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
    static let memoOnboardingToiletScratchStarted = Notification.Name("memo.onboarding.toiletScratchStarted")
    static let memoOnboardingToiletDidBecomeClean = Notification.Name("memo.onboarding.toiletDidBecomeClean")
    static let memoOnboardingStartFirstFreeGachaRequested = Notification.Name("memo.onboarding.startFirstFreeGachaRequested")
    static let memoOnboardingTutorialGachaFinished = Notification.Name("memo.onboarding.tutorialGachaFinished")
    static let memoOnboardingTutorialZukanFinished = Notification.Name("memo.onboarding.tutorialZukanFinished")
}

enum MemoOnboardingNotificationUserInfoKey {
    static let foodID = "foodID"
    static let force = "force"
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
