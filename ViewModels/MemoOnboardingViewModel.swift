//
//  MemoOnboardingViewModel.swift
//  MeMo
//
//  MVVM coordinator for mandatory onboarding and small tutorials.
//  Updated to avoid auto-presenting removed legacy first-visit Home tutorial.
//  iOS 18.6+
//

import Foundation
import Observation

@Observable
final class MemoOnboardingViewModel {
    var activeScreen: MemoOnboardingScreen?
    var isPresented: Bool = false
    var foodInteractionPhase: MemoOnboardingFoodInteractionPhase = .choosing

    @ObservationIgnored
    private var pendingScreens: [MemoOnboardingScreen] = []

    func bootIfNeeded(state: AppState?) {
        guard let state else { return }

        if state.memoShouldRunMandatoryOnboarding {
            state.memoStartMandatoryOnboardingIfNeeded()
            let savedStep = state.memoMandatoryOnboardingCurrentStep ?? .appPurpose
            presentMandatory(savedStep, state: state)
            return
        }

        // The previous implementation auto-presented `.home` here.
        // That screen is no longer part of the active tutorial flow, so after the mandatory tutorial
        // completes we wait for each concrete screen/event hook to request its own first-time guide.
    }

    func presentIfNeeded(_ screen: MemoOnboardingScreen, state: AppState?, force: Bool = false) {
        guard let state else { return }

        if state.memoShouldRunMandatoryOnboarding {
            if screen.isMandatoryTutorialStep || force {
                presentMandatory(screen.isMandatoryTutorialStep ? screen : (state.memoMandatoryOnboardingCurrentStep ?? .appPurpose), state: state)
            }
            return
        }

        guard force || state.memoOnboardingShouldPresent(screen) else { return }
        present(screen)
    }

    func presentFoodTutorialIfNeeded(state: AppState?) {
        guard let state else { return }
        guard state.memoFoodTutorialCompleted == false else { return }
        state.memoPrepareFoodTutorialItemsIfNeeded()
        present(.foodTutorialIntro)
    }

    func presentToiletTutorialIfNeeded(state: AppState?) {
        guard let state else { return }
        guard state.memoMandatoryOnboardingCompleted else { return }
        guard state.memoToiletTutorialCompleted == false else { return }
        state.memoPrepareToiletTutorialFlagIfNeeded()
        present(.toiletTutorialIntro)
    }

    func presentFoodResultIfNeeded(_ foodID: String, state: AppState?) {
        guard let state else { return }
        foodInteractionPhase = .choosing

        if state.memoShouldRunMandatoryOnboarding {
            if foodID == state.memoTutorialNormalFoodID {
                _ = state.memoMarkTutorialFoodFed(foodID: foodID)
                moveMandatory(to: .foodNormalResult, state: state)
            } else if foodID == state.memoTutorialRareFoodID {
                _ = state.memoMarkTutorialFoodFed(foodID: foodID)
                moveMandatory(to: .foodRareResult, state: state)
            }
            return
        }

        guard let screen = state.memoMarkTutorialFoodFed(foodID: foodID) else { return }
        present(screen)
    }

    func syncActualFoodProgressIfNeeded(state: AppState?) {
        guard let state else { return }
        guard state.memoShouldRunMandatoryOnboarding else { return }
        guard let activeScreen else { return }

        switch activeScreen {
        case .foodGiveNormal:
            guard state.memoHasTutorialNormalFoodActuallyBeenFed else { return }
            foodInteractionPhase = .choosing
            _ = state.memoMarkTutorialFoodFed(foodID: state.memoTutorialNormalFoodID)
            moveMandatory(to: .foodNormalResult, state: state)

        case .foodGiveRare:
            guard state.memoHasTutorialRareFoodActuallyBeenFed else { return }
            foodInteractionPhase = .choosing
            _ = state.memoMarkTutorialFoodFed(foodID: state.memoTutorialRareFoodID)
            moveMandatory(to: .foodRareResult, state: state)

        default:
            break
        }
    }

    func handleTutorialFoodSelectionStarted(foodID: String?, state: AppState?) {
        guard let screen = activeScreen else { return }
        guard screen == .foodGiveNormal || screen == .foodGiveRare else { return }

        if let state, let foodID {
            switch screen {
            case .foodGiveNormal:
                guard foodID == state.memoTutorialNormalFoodID else { return }
            case .foodGiveRare:
                guard foodID == state.memoTutorialRareFoodID else { return }
            default:
                break
            }
        }

        foodInteractionPhase = .pendingSwipe
    }

    func presentToiletScratchIfNeeded(state: AppState?) {
        guard let state else { return }
        guard state.memoMandatoryOnboardingCompleted else { return }
        guard state.memoToiletTutorialCompleted == false else { return }
        if state.memoMarkToiletTutorialScratchShown() {
            present(.toiletTutorialScratch)
        }
    }

    func completeToiletTutorialIfNeeded(state: AppState?) {
        guard let state else { return }
        if state.memoMarkToiletTutorialCompletedIfNeeded() {
            dismiss(markCurrentAsSeen: false, state: state)
        }
    }

    func handlePrimaryAction(state: AppState?) {
        guard let screen = activeScreen else { return }
        guard let state else {
            dismiss(markCurrentAsSeen: false, state: nil)
            return
        }

        switch screen {
        case .appPurpose:
            state.memoStartMandatoryOnboardingIfNeeded()
            moveMandatory(to: .foodButton, state: state)

        case .foodNormalResult:
            moveMandatory(to: .foodButtonForRare, state: state)

        case .foodRareResult:
            moveMandatory(to: .foodFullnessReminder, state: state)

        case .foodFullnessReminder:
            moveMandatory(to: .gachaButton, state: state)

        case .gachaCharacterResult:
            moveMandatory(to: .zukanButton, state: state)

        case .tutorialFinished:
            _ = state.memoMarkMandatoryOnboardingCompleted()
            dismiss(markCurrentAsSeen: false, state: state)

        case .gacha:
            if state.memoCanUseFirstVisitFreeTenDraw {
                state.memoMarkFirstVisitFreeTenDrawOffered()
                MemoOnboardingNotifier.requestFirstFreeGachaStart()
            }
            dismiss(markCurrentAsSeen: true, state: state)

        case .foodTutorialIntro:
            state.memoPrepareFoodTutorialItemsIfNeeded()
            MemoOnboardingNotifier.requestFoodTutorial()
            dismiss(markCurrentAsSeen: false, state: state)

        case .foodTutorialNormalResult:
            dismiss(markCurrentAsSeen: false, state: state)

        case .foodTutorialRareResult:
            dismiss(markCurrentAsSeen: false, state: state)
            MemoOnboardingNotifier.request(.foodTutorialDone, force: true)

        case .foodTutorialDone:
            state.memoMarkFoodTutorialCompleted()
            dismiss(markCurrentAsSeen: false, state: state)

        case .toiletTutorialIntro:
            state.memoPrepareToiletTutorialFlagIfNeeded()
            _ = state.memoMarkToiletTutorialScratchShown()
            pendingScreens.removeAll()
            activeScreen = .toiletTutorialScratch
            isPresented = true
            updateFoodInteractionPhase(for: .toiletTutorialScratch)

        case .toiletTutorialScratch:
            dismiss(markCurrentAsSeen: false, state: state)

        default:
            dismiss(markCurrentAsSeen: true, state: state)
        }
    }

    func handleSpotlightTargetActivated(state: AppState?) -> MemoOnboardingSpotlightRouteAction {
        guard let screen = activeScreen, let state else { return .none }

        switch screen {
        case .foodButton:
            foodInteractionPhase = .choosing
            state.memoStartMandatoryOnboardingIfNeeded()
            state.memoPrepareFoodTutorialItemsIfNeeded()
            moveMandatory(to: .foodGiveNormal, state: state)
            return .saveOnly

        case .foodButtonForRare:
            foodInteractionPhase = .choosing
            state.memoPrepareFoodTutorialItemsIfNeeded()
            moveMandatory(to: .foodRareTab, state: state)
            return .saveOnly

        case .foodRareTab:
            foodInteractionPhase = .choosing
            moveMandatory(to: .foodGiveRare, state: state)
            return .saveOnly

        case .foodGiveNormal:
            if foodInteractionPhase == .pendingSwipe {
                let didApply = state.memoApplyTutorialNormalFood()
                guard didApply || state.memoFoodTutorialNormalFed else {
                    foodInteractionPhase = .choosing
                    return .saveOnly
                }
                foodInteractionPhase = .choosing
                _ = state.memoMarkTutorialFoodFed(foodID: state.memoTutorialNormalFoodID)
                moveMandatory(to: .foodNormalResult, state: state)
                return .saveOnly
            }

            foodInteractionPhase = .pendingSwipe
            return .saveOnly

        case .foodGiveRare:
            if foodInteractionPhase == .pendingSwipe {
                let didApply = state.memoApplyTutorialRareFood()
                guard didApply || state.memoFoodTutorialRareFed else {
                    foodInteractionPhase = .choosing
                    return .saveOnly
                }
                foodInteractionPhase = .choosing
                _ = state.memoMarkTutorialFoodFed(foodID: state.memoTutorialRareFoodID)
                moveMandatory(to: .foodRareResult, state: state)
                return .saveOnly
            }

            foodInteractionPhase = .pendingSwipe
            return .saveOnly

        case .gachaButton:
            foodInteractionPhase = .choosing
            state.memoSaveMandatoryOnboardingStep(.gachaButton)
            hideCurrentPresentation()
            return .openTutorialGacha

        case .zukanButton:
            foodInteractionPhase = .choosing
            state.memoSaveMandatoryOnboardingStep(.zukanButton)
            hideCurrentPresentation()
            return .openTutorialZukan

        default:
            return .none
        }
    }

    func resumeAfterTutorialGacha(state: AppState?) {
        guard let state else { return }
        moveMandatory(to: .gachaCharacterResult, state: state)
    }

    func resumeAfterTutorialZukan(state: AppState?) {
        guard let state else { return }
        moveMandatory(to: .tutorialFinished, state: state)
    }

    func dismiss(markCurrentAsSeen: Bool = true, state: AppState?) {
        if markCurrentAsSeen, let screen = activeScreen, let state {
            _ = state.memoOnboardingMarkSeen(screen)
        }

        if let next = pendingScreens.first {
            pendingScreens.removeFirst()
            activeScreen = next
            isPresented = true
            updateFoodInteractionPhase(for: next)
            return
        }

        activeScreen = nil
        isPresented = false
        foodInteractionPhase = .choosing
    }

    func resetQueue() {
        pendingScreens.removeAll()
    }

    private func moveMandatory(to screen: MemoOnboardingScreen, state: AppState) {
        state.memoSaveMandatoryOnboardingStep(screen)
        pendingScreens.removeAll()
        activeScreen = screen
        isPresented = true
        updateFoodInteractionPhase(for: screen)
    }

    private func presentMandatory(_ screen: MemoOnboardingScreen, state: AppState) {
        let resolved = screen.isMandatoryTutorialStep ? screen : .appPurpose
        state.memoSaveMandatoryOnboardingStep(resolved)
        present(resolved)
    }

    private func hideCurrentPresentation() {
        pendingScreens.removeAll()
        activeScreen = nil
        isPresented = false
        foodInteractionPhase = .choosing
    }

    private func present(_ screen: MemoOnboardingScreen) {
        guard activeScreen != screen else {
            isPresented = true
            updateFoodInteractionPhase(for: screen, preserveFoodPhaseWhenPossible: true)
            return
        }

        if isPresented, activeScreen != nil {
            if pendingScreens.contains(screen) == false {
                pendingScreens.append(screen)
            }
            return
        }

        activeScreen = screen
        isPresented = true
        updateFoodInteractionPhase(for: screen)
    }

    private func updateFoodInteractionPhase(
        for screen: MemoOnboardingScreen,
        preserveFoodPhaseWhenPossible: Bool = false
    ) {
        switch screen {
        case .foodGiveNormal, .foodGiveRare:
            if preserveFoodPhaseWhenPossible == false {
                foodInteractionPhase = .choosing
            }
        default:
            foodInteractionPhase = .choosing
        }
    }
}

enum MemoOnboardingSpotlightRouteAction: Equatable {
    case none
    case saveOnly
    case openTutorialGacha
    case openTutorialZukan
}
