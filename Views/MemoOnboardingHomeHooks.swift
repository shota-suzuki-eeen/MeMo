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
        } else {
            MemoOnboardingNotifier.request(.home)
        }
    }

    static func stepScreenAppeared() {
        MemoOnboardingNotifier.request(.step)
    }

    static func gachaScreenAppeared(state: AppState) {
        guard state.memoMandatoryOnboardingCompleted else { return }
        if state.memoCanUseFirstVisitFreeTenDraw {
            state.memoMarkFirstVisitFreeTenDrawOffered()
            MemoOnboardingNotifier.request(.gacha, force: true)
        } else {
            MemoOnboardingNotifier.request(.gacha)
        }
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
        } else {
            MemoOnboardingNotifier.requestFoodTutorial()
        }
    }

    static func rareFoodTabTappedDuringTutorial(state: AppState) {
        guard state.memoShouldRunMandatoryOnboarding else { return }
        guard state.memoMandatoryOnboardingCurrentStep == .some(.foodRareTab) else { return }
        MemoOnboardingNotifier.request(.foodGiveRare, force: true)
    }

    static func foodDidFeed(foodID: String) {
        MemoOnboardingNotifier.notifyFoodDidFeed(foodID: foodID)
    }

    static func toiletFlagAppeared(state: AppState) {
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
