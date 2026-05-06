//
//  MemoOnboardingRootModifier.swift
//  MeMo
//
//  Attach this to the authorized app root so onboarding can be displayed globally.
//  iOS 18.6+
//

import SwiftUI
import SwiftData

struct MemoOnboardingRootModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext

    let state: AppState
    let viewModel: MemoOnboardingViewModel

    @State private var isShowingTutorialGacha: Bool = false
    @State private var isShowingTutorialZukan: Bool = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                viewModel.bootIfNeeded(state: state)
                presentToiletTutorialForCurrentFlagIfNeeded()
                saveIfPossible()
            }
            .onReceive(NotificationCenter.default.publisher(for: .memoOnboardingRequestScreen)) { notification in
                guard let screen = notification.object as? MemoOnboardingScreen else { return }
                let force = notification.userInfo?[MemoOnboardingNotificationUserInfoKey.force] as? Bool ?? false
                viewModel.presentIfNeeded(screen, state: state, force: force)
            }
            .onReceive(NotificationCenter.default.publisher(for: .memoOnboardingRequestFoodTutorial)) { _ in
                viewModel.presentFoodTutorialIfNeeded(state: state)
            }
            .onReceive(NotificationCenter.default.publisher(for: .memoOnboardingRequestToiletTutorial)) { _ in
                viewModel.presentToiletTutorialIfNeeded(state: state)
            }
            .onReceive(NotificationCenter.default.publisher(for: .memoOnboardingTutorialFoodSelectionStarted)) { notification in
                let foodID = notification.userInfo?[MemoOnboardingNotificationUserInfoKey.foodID] as? String
                viewModel.handleTutorialFoodSelectionStarted(foodID: foodID, state: state)
                saveIfPossible()
            }
            .onReceive(NotificationCenter.default.publisher(for: .memoOnboardingFoodDidFeed)) { notification in
                guard let foodID = notification.userInfo?[MemoOnboardingNotificationUserInfoKey.foodID] as? String else { return }
                viewModel.presentFoodResultIfNeeded(foodID, state: state)
                saveIfPossible()
            }
            .onChange(of: state.ownedFoodCountsData) { _, _ in
                viewModel.syncActualFoodProgressIfNeeded(state: state)
                saveIfPossible()
            }
            .onChange(of: state.satisfactionLevel) { _, _ in
                viewModel.syncActualFoodProgressIfNeeded(state: state)
                saveIfPossible()
            }
            .onChange(of: state.happinessPoint) { _, _ in
                viewModel.syncActualFoodProgressIfNeeded(state: state)
                saveIfPossible()
            }
            .onChange(of: state.happinessLevel) { _, _ in
                viewModel.syncActualFoodProgressIfNeeded(state: state)
                saveIfPossible()
            }
            .onChange(of: state.toiletFlagAt) { _, _ in
                presentToiletTutorialForCurrentFlagIfNeeded()
                saveIfPossible()
            }
            .onReceive(NotificationCenter.default.publisher(for: .memoOnboardingToiletScratchStarted)) { _ in
                viewModel.presentToiletScratchIfNeeded(state: state)
                saveIfPossible()
            }
            .onReceive(NotificationCenter.default.publisher(for: .memoOnboardingToiletDidBecomeClean)) { _ in
                viewModel.completeToiletTutorialIfNeeded(state: state)
                saveIfPossible()
            }
            .fullScreenCover(isPresented: $isShowingTutorialGacha) {
                MemoTutorialGachaView(state: state) {
                    isShowingTutorialGacha = false
                    viewModel.resumeAfterTutorialGacha(state: state)
                    saveIfPossible()
                    MemoOnboardingNotifier.notifyTutorialGachaFinished()
                }
                .interactiveDismissDisabled(true)
            }
            .fullScreenCover(isPresented: $isShowingTutorialZukan) {
                MemoTutorialZukanSwitchView(state: state) {
                    isShowingTutorialZukan = false
                    viewModel.resumeAfterTutorialZukan(state: state)
                    saveIfPossible()
                    MemoOnboardingNotifier.notifyTutorialZukanFinished()
                }
                .interactiveDismissDisabled(true)
            }
            .overlay {
                MemoTeacherOnboardingOverlay(
                    state: state,
                    viewModel: viewModel,
                    onNeedsSave: {
                        saveIfPossible()
                    },
                    onOpenTutorialGacha: {
                        isShowingTutorialGacha = true
                    },
                    onOpenTutorialZukan: {
                        isShowingTutorialZukan = true
                    }
                )
                .zIndex(20_000)
            }
    }

    private func presentToiletTutorialForCurrentFlagIfNeeded() {
        guard state.memoMandatoryOnboardingCompleted else { return }
        guard state.hasToiletFlag else { return }
        guard state.memoToiletTutorialCompleted == false else { return }
        viewModel.presentToiletTutorialIfNeeded(state: state)
    }

    private func saveIfPossible() {
        do {
            try modelContext.save()
        } catch {
            print("❌ MemoOnboarding save error:", error)
        }
    }
}

extension View {
    func memoOnboardingRoot(
        state: AppState,
        viewModel: MemoOnboardingViewModel
    ) -> some View {
        modifier(MemoOnboardingRootModifier(state: state, viewModel: viewModel))
    }

    func memoOnboardingScreen(_ screen: MemoOnboardingScreen) -> some View {
        onAppear {
            MemoOnboardingNotifier.request(screen)
        }
    }
}
