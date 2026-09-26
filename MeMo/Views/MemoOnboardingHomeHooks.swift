//
//  MemoOnboardingHomeHooks.swift
//  MeMo
//
//  Small hook points for HomeView / GachaView / other screens.
//  Keeping this separate makes the existing large views safer to edit.
//  iOS 18.6+
//

import Foundation

@MainActor
enum MemoOnboardingHomeHooks {
    static func homeAppeared(state: AppState) {
        if state.memoShouldRunMandatoryOnboarding {
            state.memoStartMandatoryOnboardingIfNeeded()
            MemoOnboardingNotifier.request(state.memoMandatoryOnboardingCurrentStep ?? .appPurpose, force: true)
            return
        }

        // Home itself no longer has a first-visit explanation.
        // If the first toilet flag is already active when Home appears, surface that event tutorial instead.
        if state.hasToiletFlag {
            toiletFlagAppeared(state: state)
        }
    }

    static func stepScreenAppeared() {
        // Removed from the active tutorial flow.
        // Keep the hook as a no-op so older call sites remain compile-safe.
    }

    static func gachaScreenAppeared(state: AppState) {
        // Removed from the active first-visit tutorial flow.
        // The mandatory gacha tutorial is still driven by MemoOnboardingViewModel.
        _ = state
    }

    static func zukanScreenAppeared(state: AppState? = nil) {
        if let state, state.memoShouldRunMandatoryOnboarding {
            MemoOnboardingNotifier.request(.zukanButton, force: true)
        } else {
            MemoOnboardingNotifier.request(.zukan)
        }
    }

    static func memoriesScreenAppeared() {
        MemoOnboardingNotifier.request(.memories)
    }

    static func settingsScreenAppeared() {
        MemoOnboardingNotifier.request(.settings)
    }

    static func workTimerPreparationScreenAppeared() {
        MemoOnboardingNotifier.request(.workFocusRewardIntro)
    }

    static func runScreenAppeared() {
        MemoOnboardingNotifier.request(.workRouteRecordIntro)
    }

    static func cameraCaptureScreenAppeared() {
        MemoOnboardingNotifier.request(.cameraCapture)
    }

    static func foodBubbleTapped(state: AppState) {
        guard state.memoFoodTutorialCompleted == false else { return }
        state.memoPrepareFoodTutorialItemsIfNeeded()
        if state.memoShouldRunMandatoryOnboarding {
            switch state.memoMandatoryOnboardingCurrentStep {
            case .some(.foodButtonForRare):
                MemoOnboardingNotifier.request(.foodRareTab, force: true)
            case .some(.foodRareTab), .some(.foodGiveRare):
                MemoOnboardingNotifier.request(.foodRareTab, force: true)
            default:
                MemoOnboardingNotifier.request(.foodGiveNormal, force: true)
            }
        }
    }

    static func rareFoodTabTappedDuringTutorial(state: AppState) {
        guard state.memoShouldRunMandatoryOnboarding else { return }
        guard state.memoMandatoryOnboardingCurrentStep == .some(.foodRareTab) else { return }
        MemoOnboardingNotifier.request(.foodGiveRare, force: true)
    }

    static func tutorialFoodSelectionStarted(foodID: String?) {
        MemoOnboardingNotifier.notifyTutorialFoodSelectionStarted(foodID: foodID)
    }

    static func tutorialFoodSelectionCancelled() {
        // Down-swipe cancellation should not move the mandatory food tutorial back.
        // Keep this hook as a no-op so existing HomeView calls remain safe.
    }

    static func foodDidFeed(foodID: String) {
        MemoOnboardingNotifier.notifyFoodDidFeed(foodID: foodID)
    }

    static func toiletFlagAppeared(state: AppState) {
        guard state.memoMandatoryOnboardingCompleted else { return }
        guard state.memoToiletTutorialCompleted == false else { return }
        state.memoPrepareToiletTutorialFlagIfNeeded()
        MemoOnboardingNotifier.requestToiletTutorial()
    }

    static func toiletScratchStarted() {
        MemoOnboardingNotifier.notifyToiletScratchStarted()
    }

    static func toiletDidBecomeClean() {
        MemoOnboardingNotifier.notifyToiletDidBecomeClean()
    }
}

@MainActor
enum MemoFirstVisitGachaHooks {
    static func canShowFirstVisitFreeTenDrawButton(state: AppState) -> Bool {
        state.memoCanUseFirstVisitFreeTenDraw && state.memoMandatoryOnboardingCompleted
    }

    static func beginFirstVisitFreeTenDrawIfPossible(state: AppState) -> Bool {
        state.memoConsumeFirstVisitFreeTenDraw()
    }

    static func didFinishFirstVisitFreeTenDraw(state: AppState) {
        state.memoMarkFirstVisitFreeTenDrawCompleted()
    }
}
