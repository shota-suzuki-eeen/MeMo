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
    @State private var isShowingLimitedHappinessRewardIntro: Bool = false
    @State private var pendingLimitedHappinessRewardIntroTask: Task<Void, Never>?

    @ViewBuilder
    func body(content: Content) -> some View {
        if MemoDevice.isIPad {
            content
                .onAppear {
                    _ = state.memoSkipAllOnboardingForIPadIfNeeded()
                    _ = state.memoConsumeLimitedHappinessRewardCharacterIntroPending()
                    saveIfPossible()
                }
                .onChange(of: state.ownedPetIDsData) { _, _ in
                    if state.memoMarkLimitedHappinessRewardCharacterOwnedFromRewardListIfNeeded() {
                        _ = state.memoConsumeLimitedHappinessRewardCharacterIntroPending()
                        saveIfPossible()
                    }
                }
                .onDisappear {
                    pendingLimitedHappinessRewardIntroTask?.cancel()
                    pendingLimitedHappinessRewardIntroTask = nil
                }
        } else {
            content
                .onAppear {
                    viewModel.bootIfNeeded(state: state)
                    presentToiletTutorialForCurrentFlagIfNeeded()
                    scheduleLimitedHappinessRewardIntroIfHomeIsReady()
                    saveIfPossible()
                }
                .onDisappear {
                    pendingLimitedHappinessRewardIntroTask?.cancel()
                    pendingLimitedHappinessRewardIntroTask = nil
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
                .onReceive(NotificationCenter.default.publisher(for: .memoLimitedHappinessRewardCharacterDidBecomePending)) { _ in
                    scheduleLimitedHappinessRewardIntroIfHomeIsReady(after: 0.45)
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
                .onChange(of: state.ownedPetIDsData) { _, _ in
                    if state.memoMarkLimitedHappinessRewardCharacterOwnedFromRewardListIfNeeded() {
                        saveIfPossible()
                    }
                    scheduleLimitedHappinessRewardIntroIfHomeIsReady(after: 0.45)
                }
                .onChange(of: state.toiletFlagAt) { _, _ in
                    presentToiletTutorialForCurrentFlagIfNeeded()
                    scheduleLimitedHappinessRewardIntroIfHomeIsReady(after: 0.45)
                    saveIfPossible()
                }
                .onReceive(NotificationCenter.default.publisher(for: .memoOnboardingToiletScratchStarted)) { _ in
                    viewModel.presentToiletScratchIfNeeded(state: state)
                    saveIfPossible()
                }
                .onReceive(NotificationCenter.default.publisher(for: .memoOnboardingToiletDidBecomeClean)) { _ in
                    viewModel.completeToiletTutorialIfNeeded(state: state)
                    scheduleLimitedHappinessRewardIntroIfHomeIsReady(after: 0.45)
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

                    if isShowingLimitedHappinessRewardIntro {
                        MemoLimitedHappinessRewardIntroOverlay {
                            dismissLimitedHappinessRewardIntro()
                        }
                        .transition(.opacity)
                        .zIndex(20_100)
                    }
                }
        }
    }

    private func presentToiletTutorialForCurrentFlagIfNeeded() {
        guard state.memoMandatoryOnboardingCompleted else { return }
        guard state.hasToiletFlag else { return }
        guard state.memoToiletTutorialCompleted == false else { return }
        viewModel.presentToiletTutorialIfNeeded(state: state)
    }

    private func scheduleLimitedHappinessRewardIntroIfHomeIsReady(after delay: TimeInterval = 0) {
        pendingLimitedHappinessRewardIntroTask?.cancel()

        guard state.memoCanPresentLimitedHappinessRewardCharacterIntro else { return }
        guard state.hasToiletFlag == false else { return }
        guard viewModel.isPresented == false else { return }
        guard isShowingTutorialGacha == false else { return }
        guard isShowingTutorialZukan == false else { return }
        guard isShowingLimitedHappinessRewardIntro == false else { return }

        pendingLimitedHappinessRewardIntroTask = Task { @MainActor in
            let safeDelay = max(0, delay)
            if safeDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(safeDelay * 1_000_000_000))
            } else {
                await Task.yield()
            }

            guard !Task.isCancelled else { return }
            guard state.memoCanPresentLimitedHappinessRewardCharacterIntro else { return }
            guard state.hasToiletFlag == false else { return }
            guard viewModel.isPresented == false else { return }
            guard isShowingTutorialGacha == false else { return }
            guard isShowingTutorialZukan == false else { return }
            guard isShowingLimitedHappinessRewardIntro == false else { return }

            withAnimation(.easeInOut(duration: 0.22)) {
                isShowingLimitedHappinessRewardIntro = true
            }
        }
    }

    private func dismissLimitedHappinessRewardIntro() {
        _ = state.memoConsumeLimitedHappinessRewardCharacterIntroPending()
        saveIfPossible()

        withAnimation(.easeInOut(duration: 0.22)) {
            isShowingLimitedHappinessRewardIntro = false
        }
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
