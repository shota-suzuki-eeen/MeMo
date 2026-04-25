//
//  HomeView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import SwiftUI
import SwiftData
import UIKit
import AVFoundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var bgmManager: BGMManager
    @State private var touchTapSEPool = TouchTapSEPool()
    @AppStorage(WallpaperCatalog.selectedHomeWallpaperAssetNameKey)
    private var selectedHomeWallpaperAssetName: String = WallpaperCatalog.defaultWallpaper.assetName

    let state: AppState
    @ObservedObject var hk: HealthKitManager

    @State private var todaySteps: Int = 0
    @State private var displayedTodaySteps: Int = 0
    @State private var displayedWalletSteps: Int = 0

    @State private var showCaptureModeDialog: Bool = false
    @State private var selectedCaptureMode: CameraCaptureView.Mode?


    @State private var displayedStepProgress: Double = 0
    @State private var displayedFullnessLevel: Int = 0
    @State private var animatedFullnessLevel: Double = 0

    @State private var isAnimatingGain: Bool = false
    @State private var isHomeVisible: Bool = false
    @State private var hasCompletedInitialLoad: Bool = false
    @State private var isForegroundSyncInProgress: Bool = false

    @State private var showStepEnjoy: Bool = false
    @State private var showGachaView: Bool = false

    @State private var showWorkTimerPreparation: Bool = false
    @State private var showRightMenuPopup: Bool = false
    @State private var activeTopInfoPopup: TopInfoPopup?

    @State private var showFoodSelector: Bool = false
    @State private var selectedFoodID: String?
    @State private var selectedFoodRarityTab: FoodSelectorRarityTab = .normal
    @State private var foodSelectorDragOffset: CGSize = .zero
    @State private var isFoodFeedingAnimationRunning: Bool = false
    @State private var pendingFoodFeedID: String?
    @State private var isFoodSelectorHorizontalRattling: Bool = false
    @State private var foodSelectorDragAnchorFoodID: String?

    @State private var characterAssetName: String = ""
    @State private var idleLoopTask: Task<Void, Never>?
    @State private var isCharacterActionRunning: Bool = false
    @State private var toiletLockedPopupDismissTask: Task<Void, Never>?
    @State private var toiletTicketCleanupTask: Task<Void, Never>?
    @State private var foodFeedResolutionTask: Task<Void, Never>?
    @State private var toiletWiggleActivationTask: Task<Void, Never>?
    @State private var floatingHeartCleanupTasks: [UUID: Task<Void, Never>] = [:]
    @State private var happinessDecayAnimationTask: Task<Void, Never>?

    private let doubleBlinkChance: Double = 0.18
    private let doubleBlinkGapRange: ClosedRange<Double> = 0.18...0.45

    @State private var showToiletLockedPopup: Bool = false
    @State private var toiletLockedPopupText: String = ""

    @State private var isToiletWiggleOn: Bool = false

    @State private var toiletPoopActivePoint: [String: CGPoint] = [:]
    @State private var homeContentSize: CGSize = .zero

    @State private var toiletTicketClearingPoopIDs: Set<String> = []
    @State private var isToiletTicketCleaning: Bool = false

    @State private var displayedHappinessPoint: Int = 0
    @State private var animatedHappinessPoint: Double = 0
    @State private var displayedHappinessLevel: Int = 0
    @State private var isAnimatingHappinessDecay: Bool = false
    @State private var characterPettingStartPoint: CGPoint?
    @State private var characterPettingLastPoint: CGPoint?
    @State private var characterPettingAccumulatedDistance: CGFloat = 0
    @State private var floatingHearts: [FloatingHeart] = []

    private let characterRubDistancePerTouch: CGFloat = 28

    private enum CharacterPettingTriggerKind {
        case tap
        case rub
    }

    private struct HomePersistenceSnapshot: Equatable {
        let walletSteps: Int
        let pendingSteps: Int
        let lastSyncedAt: Date?
        let dailyGoalKcal: Int
        let lastDayKey: String
        let cachedTodaySteps: Int
        let cachedTodayMeterSteps: Int
        let satisfactionLevel: Int
        let satisfactionLastUpdatedAt: Date?
        let foodFlagAt: Date?
        let foodLastRaisedAt: Date?
        let foodNextSpawnAt: Date?
        let toiletFlagAt: Date?
        let toiletLastRaisedAt: Date?
        let toiletNextSpawnAt: Date?
        let toiletPoopsData: Data?
        let toiletPoopLastSpawnAt: Date?
        let currentPetID: String
        let ownedPetIDsData: Data?
        let ownedFoodCountsData: Data?
    }

    private var fullnessMaxLevel: Int { 5 }

    private var currentBaseAssetName: String {
        PetMaster.assetName(for: state.normalizedCurrentPetID)
    }

    private var currentPetName: String {
        PetMaster.all.first(where: { $0.id == state.normalizedCurrentPetID })?.name ?? "ペット"
    }

    private var isToiletLocked: Bool { state.hasToiletFlag }
    private var fixedDailyGoalSteps: Int { AppState.fixedDailyStepGoal }

    private var widgetLinkedTodaySteps: Int {
        max(todaySteps, state.widgetTodaySteps)
    }

    private var ownedFoods: [FoodCatalog.FoodItem] {
        FoodCatalog.all.filter { state.foodCount(foodId: $0.id) > 0 }
    }

    private var currentFoodSelectorFoods: [FoodCatalog.FoodItem] {
        ownedFoods.filter { selectedFoodRarityTab.matches($0) }
    }

    private var selectedFood: FoodCatalog.FoodItem? {
        let foods = currentFoodSelectorFoods
        guard let selectedFoodID else { return foods.first }
        return foods.first(where: { $0.id == selectedFoodID }) ?? foods.first
    }

    private var visibleToiletPoops: [AppState.ToiletPoopItem] {
        state.toiletPoops().filter { !$0.isCleared }
    }

    private var ownedToiletTicketCount: Int {
        state.gachaSpecialItemCount(id: "wc")
    }

    private var canShowToiletTicketButton: Bool {
        state.hasToiletFlag && ownedToiletTicketCount > 0
    }

    private var currentFullnessLevel: Int {
        normalizedFullnessLevel(state.currentSatisfaction(now: Date()))
    }

    private var happinessMaxPoints: Int {
        AppState.happinessMaxPointsPerLevel
    }

    private var currentClaimableHappinessRewardLevel: Int? {
        state.nextClaimableHappinessRewardLevel()
    }

    private var currentClaimedHappinessRewardLevels: Set<Int> {
        state.claimedHappinessRewardLevelsSnapshot()
    }

    private var currentWalletCoinCount: Int {
        max(0, max(displayedWalletSteps, state.walletSteps))
    }

    private var currentTodayStepCount: Int {
        max(0, max(displayedTodaySteps, max(todaySteps, hk.todaySteps)))
    }

    private var currentTotalStepCount: Int {
        max(0, state.stepEnjoyTotalSteps)
    }

    private var currentHappinessLevelValue: Int {
        max(displayedHappinessLevel, state.happinessLevel)
    }

    private var currentHappinessPointValue: Int {
        min(happinessMaxPoints - 1, max(displayedHappinessPoint, state.happinessPoint))
    }

    private var nextHappinessRewardLevel: Int? {
        if let claimableLevel = currentClaimableHappinessRewardLevel {
            return claimableLevel
        }
        return state.nextUpcomingHappinessRewardLevel()
    }

    private var canShowFoodBubble: Bool {
        currentFullnessLevel < fullnessMaxLevel
    }

    private var canShowWcAsset: Bool {
        [
            "person","dog","cat","chicken","monkey","rabbit","frog","penguin","sheep","shark","turtle","dolphin",
            "Sloth","baku","blackGibbon","bulldog","deer","fox","frilledLizard","giraffe","koala","okapi",
            "platypus","raccoon","Shoebill","Triceratops","bee","amesho","barinys","blue","shiba","gorilla",
            "lizard","meerkat","otter","owl","parakeet","peacock","pig","raccoonDog","redPanda","seal",
            "seaOtter","skunk","swallow","tiger","whiteTiger","zebra","wolf"
        ].contains(currentBaseAssetName)
    }

    private var canPlayBlinkAnimation: Bool {
        [
            "person","dog","cat","chicken","monkey","rabbit","frog","penguin","sheep","shark","turtle","dolphin",
            "Sloth","baku","blackGibbon","bulldog","deer","fox","frilledLizard","giraffe","koala","okapi",
            "platypus","raccoon","Shoebill","Triceratops","bee","amesho","barinys","blue","shiba","gorilla",
            "lizard","meerkat","otter","owl","parakeet","peacock","pig","raccoonDog","redPanda","seal",
            "seaOtter","skunk","swallow","tiger","whiteTiger","zebra","wolf"
        ].contains(currentBaseAssetName)
    }

    private var preferredCharacterRestAssetName: String {
        if isToiletLocked, canShowWcAsset {
            return "\(currentBaseAssetName)_wc"
        }
        return currentBaseAssetName
    }

    private var captureMetricValues: (steps: Int, activeKcal: Int, totalKcal: Int) {
        let steps = max(todaySteps, hk.todaySteps)
        return (steps: steps, activeKcal: 0, totalKcal: steps)
    }

    private var effectiveCurrentHomeWallpaperAssetName: String {
        WallpaperCatalog.item(for: selectedHomeWallpaperAssetName)?.assetName
        ?? WallpaperCatalog.defaultWallpaper.assetName
    }

    fileprivate enum TopInfoPopup: Int, Identifiable {
        case wallet
        case todaySteps
        case happinessRewards
        var id: Int { rawValue }
    }

    fileprivate enum FoodSelectorRarityTab: String, CaseIterable, Identifiable {
        case normal = "N"
        case rare = "R"

        var id: String { rawValue }

        var next: FoodSelectorRarityTab {
            self == .normal ? .rare : .normal
        }

        var accentColor: Color {
            switch self {
            case .normal:
                return Color(red: 0.24, green: 0.56, blue: 0.98)
            case .rare:
                return Color(red: 0.97, green: 0.34, blue: 0.38)
            }
        }

        var glowColors: [Color] {
            switch self {
            case .normal:
                return [
                    Color(red: 0.49, green: 0.73, blue: 1.0).opacity(0.70),
                    Color(red: 0.28, green: 0.57, blue: 1.0).opacity(0.34),
                    .clear
                ]
            case .rare:
                return [
                    Color(red: 1.0, green: 0.54, blue: 0.57).opacity(0.76),
                    Color(red: 0.97, green: 0.32, blue: 0.36).opacity(0.38),
                    .clear
                ]
            }
        }

        var emptyText: String {
            switch self {
            case .normal:
                return "Nのご飯は持っていません"
            case .rare:
                return "Rのご飯は持っていません"
            }
        }

        func matches(_ food: FoodCatalog.FoodItem) -> Bool {
            switch self {
            case .normal:
                return food.isShopEligible
            case .rare:
                return !food.isShopEligible
            }
        }
    }

    fileprivate enum Layout {
        static let bannerHeight: CGFloat = 76
        static let bannerWidthIPhone: CGFloat = 320

        static let leftTopPaddingTop: CGFloat = 44
        static let leftTopPaddingLeading: CGFloat = 18
        static let meterStackSpacing: CGFloat = 18

        static let topStatusButtonsTop: CGFloat = 60
        static let topStatusButtonsLeading: CGFloat = 18
        static let topStatusButtonsSpacing: CGFloat = 10
        static let topStatusButtonSize: CGFloat = 56
        static let topStatusButtonIconSize: CGFloat = 42

        static let happinessGaugeTop: CGFloat = 55
        static let happinessGaugeLeading: CGFloat = 28
        static let fullnessGaugeLeading: CGFloat = 178
        static let topStatusButtonsTrailing: CGFloat = 28
        static let happinessGaugeOuterSize: CGFloat = 135
        static let happinessGaugeInnerSize: CGFloat = 115
        static let happinessRewardButtonFont: CGFloat = 12

        static let iconHeartSize: CGFloat = 31
        static let iconCoinSize: CGFloat = 26
        static let capsuleHeight: CGFloat = 23

        static let barWidth: CGFloat = 125
        static let walletWidth: CGFloat = 125
        static let redMinWidth: CGFloat = 18


        static let fullnessGaugeTop: CGFloat = 55
        static let fullnessGaugeTrailing: CGFloat = 28
        static let fullnessGaugeOuterSize: CGFloat = 135
        static let fullnessGaugeInnerSize: CGFloat = 115

        static let characterTopOffset: CGFloat = 45
        static let characterMaxHeight: CGFloat = 480
        static let characterTouchWidth: CGFloat = 240
        static let characterShadowWidthRatio: CGFloat = 0.8
        static let characterShadowHeightRatio: CGFloat = 0.10
        static let characterShadowMaxWidth: CGFloat = 170
        static let characterShadowMaxHeight: CGFloat = 40
        static let characterShadowYOffsetRatio: CGFloat = 0.48
        static let characterShadowOpacity: Double = 0.9
        static let characterShadowBlurRadius: CGFloat = 14

        static let menuPopupCornerRadius: CGFloat = 20
        static let menuPopupHorizontalPadding: CGFloat = 18
        static let menuPopupVerticalPadding: CGFloat = 18
        static let menuPopupMaxWidth: CGFloat = 360
        static let menuPopupBackgroundAssetName: String = "blue_block"
        static let menuPopupButtonBackgroundAssetName: String = "clay_block"
        static let menuPopupCloseButtonAssetName: String = "close_button"
        static let menuPopupCloseButtonSize: CGFloat = 54
        static let menuPopupCloseButtonTopPadding: CGFloat = 18
        static let menuPopupCloseButtonTrailingPadding: CGFloat = 18
        static let menuPopupContentTopPadding: CGFloat = 34
        static let menuPopupContentBottomPadding: CGFloat = 20
        static let menuPopupGridOffsetX: CGFloat = -12
        static let menuPopupGridOffsetY: CGFloat = 8
        static let menuPopupGridWidth: CGFloat = 296
        static let zMenuPopup: Double = 900

        static let topInfoPopupCornerRadius: CGFloat = 30
        static let topInfoPopupHorizontalPadding: CGFloat = 22
        static let topInfoPopupVerticalPadding: CGFloat = 24
        static let topInfoPopupScreenHorizontalPadding: CGFloat = 16
        static let topInfoPopupScreenVerticalPadding: CGFloat = 16
        static let topInfoPopupMaxWidth: CGFloat = 360
        static let topInfoPopupContentMaxHeight: CGFloat = 560
        static let topInfoPopupBackgroundAssetName: String = "red_block"
        static let topInfoPopupCloseButtonAssetName: String = "close_button"
        static let topInfoPopupCloseButtonSize: CGFloat = 48
        static let zTopInfoPopup: Double = 1200

        static let rightButtonSize: CGFloat = 116
        static let rightButtonsSpacing: CGFloat = 28

        static let bottomButtonSize: CGFloat = 68
        static let bottomButtonsSpacing: CGFloat = 16
        static let bottomPadding: CGFloat = 72
        static let bottomHorizontalPadding: CGFloat = 18

        static let bottomButtonBackgroundAssetName: String = "clay_block"

        static let bottomButtonBackgroundSize: CGFloat = 76
        static let bottomButtonIconSize: CGFloat = 68
        static let bottomButtonCornerRadius: CGFloat = 22
        static let bottomBarHorizontalPadding: CGFloat = 14
        static let bottomBarVerticalPadding: CGFloat = 12

        static let toiletTicketBottomTrailing: CGFloat = 18
        static let toiletTicketBottomOffset: CGFloat = 158
        static let toiletTicketBadgeOffsetX: CGFloat = 21
        static let toiletTicketBadgeOffsetY: CGFloat = -21

        static let floatingBubbleSize: CGFloat = 90
        static let foodBubbleLeading: CGFloat = 42
        static let foodBubbleTop: CGFloat = 246
        static let wcBubbleTrailing: CGFloat = 32
        static let wcBubbleTop: CGFloat = 230
        static let floatingBubbleAmplitude: CGFloat = 6
        static let floatingBubbleDuration: Double = 1.7
        static let zFoodBubble: Double = 240
        static let zFoodSelector: Double = 245
        static let zToiletPoops: Double = 270
        static let zToiletTicketButton: Double = 275
        static let zWcButton: Double = 240

        static let foodSelectorBottomGapFromButtons: CGFloat = 166
        static let foodSelectorHitAreaWidth: CGFloat = 320
        static let foodSelectorHitAreaHeight: CGFloat = 220
        static let foodSelectorInstructionOffsetY: CGFloat = 150
        static let foodSelectorRollStepWidth: CGFloat = 96
        static let foodSelectorRollMaxVisibleOffset: Double = 3.0
        static let foodSelectorPendingDecisionThreshold: CGFloat = 44
        static let foodSelectorToggleOffsetX: CGFloat = 148
        static let foodSelectorToggleOffsetY: CGFloat = -18

        static let fullnessLabelOffsetY: CGFloat = 44
        static let fullnessValueFont: CGFloat = 14
        static let fullnessCaptionFont: CGFloat = 10

        static let zCharacter: Double = 50
        static let zBottomButtons: Double = 260
        static let zBanner: Double = 1000

        static let toiletPoopSize: CGFloat = 140
        static let toiletPoopHitSize: CGFloat = 156
        static let toiletPoopHorizontalInset: CGFloat = 14
        static let toiletPoopTopInset: CGFloat = 78
        static let toiletPoopBottomInset: CGFloat = 170
        static let toiletPoopMinSpacing: CGFloat = 6
        static let toiletPoopScratchDistanceToClear: CGFloat = 640
        static let toiletPoopScratchRectInset: CGFloat = 10

        static let toiletWiggleOffset: CGFloat = 3
        static let toiletWiggleDuration: Double = 0.12

        static let lockedPopupMaxWidth: CGFloat = 320
        static let lockedPopupPaddingH: CGFloat = 18
        static let lockedPopupPaddingV: CGFloat = 12
        static let lockedPopupShowSeconds: Double = 1.1

        static let careSpawnCheckInterval: Double = 1.0
    }


    var body: some View {
        lifecycleConfiguredHomeView
    }

    private var lifecycleConfiguredHomeView: some View {
        modalConfiguredHomeView
            .task {
                guard !hasCompletedInitialLoad else { return }
                let previousSnapshot = makeHomePersistenceSnapshot()

                state.ensureInitialPetsIfNeeded()
                _ = state.normalizeFixedDailyStepGoal()

                await hk.startStepUpdatesIfNeeded()
                await hk.refreshTodayStepsForWidget()

                syncCharacterBaseFromState(force: true)

                todaySteps = state.widgetTodaySteps
                displayedTodaySteps = todaySteps
                displayedWalletSteps = state.walletSteps
                syncDisplayedHappiness(animated: false)
                displayedStepProgress = calcStepProgressRaw(
                    todaySteps: displayedTodaySteps,
                    goalSteps: fixedDailyGoalSteps
                )
                displayedFullnessLevel = normalizedFullnessLevel(state.applySatisfactionDecayIfNeeded(now: Date()))
                animatedFullnessLevel = Double(displayedFullnessLevel)

                handleDayRolloverIfNeeded(state: state)
                await runSync(state: state)

                state.ensureToiletNextSpawnScheduled(now: Date())
                state.ensureFoodNextSpawnScheduled(now: Date())

                maybeSpawnToiletFlag(state: state, persistChanges: false)
                maybeSpawnFoodFlag(state: state, persistChanges: false)

                syncToiletPoopsIfNeeded(containerSize: homeContentSize, persistChanges: false)
                syncFoodSelectorSelection()
                syncDisplayedFullness()
                scheduleHappinessDecayIfNeeded(now: Date())

                updateToiletWiggle()
                syncCharacterBaseFromState(force: true)
                persistHomeStateIfNeeded(previousSnapshot: previousSnapshot, forceWidgetReload: true)
                hasCompletedInitialLoad = true
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                guard hasCompletedInitialLoad else { return }
                runForegroundResyncIfNeeded()
            }
            .onAppear {
                isHomeVisible = true

                _ = state.normalizeFixedDailyStepGoal()
                syncCharacterBaseFromState(force: true)
                startCharacterIdleLoopIfNeeded()
                syncDisplayedHappiness(animated: false)
                syncDisplayedFullness(animated: false)
                scheduleHappinessDecayIfNeeded(now: Date())

                withAnimation(.easeOut(duration: 0.25)) {
                    displayedStepProgress = calcStepProgressRaw(
                        todaySteps: displayedTodaySteps,
                        goalSteps: fixedDailyGoalSteps
                    )
                }

                Task { await reconcileWalletDisplayIfNeeded(state: state) }

                syncFoodSelectorSelection()
                syncToiletPoopsIfNeeded(containerSize: homeContentSize)
                updateToiletWiggle()
                syncCharacterBaseFromState(force: true)
                updateWidgetSnapshot(forceReload: true)
            }
            .onDisappear {
                isHomeVisible = false
                Haptics.stopRattle()
                cancelDelayedHomeTasks()

                stopCharacterIdleLoop()
                isCharacterActionRunning = false
                characterAssetName = preferredCharacterRestAssetName
                activeTopInfoPopup = nil
                showToiletLockedPopup = false
                showFoodSelector = false
                selectedFoodRarityTab = .normal
                resetFoodSelectorDragState()
                isFoodFeedingAnimationRunning = false
                pendingFoodFeedID = nil
                stopFoodSelectorHorizontalRattleIfNeeded()
                toiletPoopActivePoint.removeAll()
                toiletTicketClearingPoopIDs.removeAll()
                isToiletTicketCleaning = false
                characterPettingStartPoint = nil
                characterPettingLastPoint = nil
                characterPettingAccumulatedDistance = 0
                floatingHearts.removeAll()
                touchTapSEPool.stopAll()
            }
            .onChange(of: state.walletKcal) { _, _ in
                guard isHomeVisible else { return }
                Task { await reconcileWalletDisplayIfNeeded(state: state) }
                updateWidgetSnapshot()
            }
            .onChange(of: state.dailyGoalKcal) { _, _ in
                let didNormalize = state.normalizeFixedDailyStepGoal()
                if didNormalize { save() }
                withAnimation(.easeOut(duration: 0.25)) {
                    displayedStepProgress = calcStepProgressRaw(
                        todaySteps: displayedTodaySteps,
                        goalSteps: fixedDailyGoalSteps
                    )
                }
            }
            .onChange(of: todaySteps) { _, _ in
                updateWidgetSnapshot()
            }
            .onChange(of: state.currentPetID) { _, _ in
                syncCharacterBaseFromState(force: true)
                updateWidgetSnapshot(forceReload: true)
            }
            .onChange(of: state.toiletFlagAt) { _, _ in
                toiletTicketClearingPoopIDs.removeAll()
                isToiletTicketCleaning = false

                if state.hasToiletFlag {
                    toiletPoopActivePoint.removeAll()

                    if showFoodSelector {
                        closeFoodSelector()
                    }

                    if showRightMenuPopup {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showRightMenuPopup = false
                        }
                    }

                    showCaptureModeDialog = false
                    syncToiletPoopsIfNeeded(containerSize: homeContentSize)
                } else {
                    toiletPoopActivePoint.removeAll()
                }

                syncCharacterBaseFromState(force: true)
                updateToiletWiggle()
                updateWidgetSnapshot(forceReload: true)
            }
            .onChange(of: state.foodFlagAt) { _, _ in
                syncDisplayedFullness()

                if currentFullnessLevel < fullnessMaxLevel {
                    syncFoodSelectorSelection()
                } else {
                    closeFoodSelector()
                }

                updateWidgetSnapshot(forceReload: true)
            }
            .onChange(of: state.satisfactionLevel) { _, _ in
                syncDisplayedFullness()
                scheduleHappinessDecayIfNeeded(now: Date())
            }
            .onChange(of: state.satisfactionLastUpdatedAt) { _, _ in
                syncDisplayedFullness()
                scheduleHappinessDecayIfNeeded(now: Date())
            }
            .onChange(of: state.toiletNextSpawnAt) { _, _ in
                updateWidgetSnapshot(forceReload: true)
            }
            .onChange(of: state.foodNextSpawnAt) { _, _ in
                updateWidgetSnapshot(forceReload: true)
            }
            .onChange(of: state.ownedFoodCountsData) { _, _ in
                syncFoodSelectorSelection()
            }
            .onChange(of: state.lastDayKey) { _, _ in
                updateWidgetSnapshot(forceReload: true)
            }
    }

    private var modalConfiguredHomeView: some View {
        homeRootView
            .confirmationDialog("撮影モードを選択", isPresented: $showCaptureModeDialog, titleVisibility: .visible) {
                Button("ARで撮影") {
                    bgmManager.playSE(.push)
                    selectedCaptureMode = .ar
                }
                Button("通常撮影") {
                    bgmManager.playSE(.push)
                    selectedCaptureMode = .plain
                }
                Button("キャンセル", role: .cancel) {
                    bgmManager.playSE(.push)
                }
            }
            .fullScreenCover(item: $selectedCaptureMode) { mode in
                CameraCaptureView(
                    initialMode: mode,
                    todaySteps: captureMetricValues.steps,
                    todayActiveKcal: captureMetricValues.activeKcal,
                    todayTotalKcal: captureMetricValues.totalKcal,
                    plainBackgroundAssetName: effectiveCurrentHomeWallpaperAssetName,
                    characterAssetName: PetMaster.assetName(for: state.normalizedCurrentPetID),
                    metricValueProvider: {
                        let values = captureMetricValues
                        return (steps: values.steps, activeKcal: values.activeKcal, totalKcal: values.totalKcal)
                    }
                ) {
                    selectedCaptureMode = nil
                } onCapture: { image in
                    saveTodayPhoto(image, placeName: nil, latitude: nil, longitude: nil)
                } onCaptureWithPlace: { image, placeName, lat, lon in
                    saveTodayPhoto(image, placeName: placeName, latitude: lat, longitude: lon)
                }
            }
            .fullScreenCover(isPresented: $showWorkTimerPreparation) {
                WorkTimerPreparationView()
            }
            .fullScreenCover(isPresented: $showGachaView) {
                GachaView()
                    .environmentObject(bgmManager)
            }
            .fullScreenCover(isPresented: $showStepEnjoy) {
                NavigationStack {
                    StepView(state: state, hk: hk, onSave: { save() })
                }
            }
    }

    private var homeRootView: some View {
        NavigationStack {
            homeSceneView
        }
        .navigationBarHidden(true)
    }

    private var homeSceneView: some View {
        ZStack {
            homeBackgroundView
            mainHomeContentView
            rightMenuPopupOverlay
            topInfoPopupOverlay
            bottomButtonsTimelineLayer
            toiletTicketButtonLayer
            toiletPoopsLayer
            toiletBubbleLayer
            topBannerOverlay
        }
    }

    private var homeBackgroundView: some View {
        Image(effectiveCurrentHomeWallpaperAssetName)
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }

    private var mainHomeContentView: some View {
        VStack(spacing: 0) {
            headerSpacerView
            homeGeometryContentView
        }
    }

    private var headerSpacerView: some View {
        Color.clear
            .frame(width: Layout.bannerWidthIPhone, height: Layout.bannerHeight)
            .frame(maxWidth: .infinity)
            .frame(height: Layout.bannerHeight)
    }

    private var homeGeometryContentView: some View {
        GeometryReader { geo in
            geometryContentBody(geo: geo)
        }
    }

    private func geometryContentBody(geo: GeometryProxy) -> some View {
        let characterDisplayHeight = min(geo.size.width * 0.9, Layout.characterMaxHeight)
        let characterTouchWidth = min(geo.size.width * 0.72, Layout.characterTouchWidth)
        let characterTouchHeight = characterDisplayHeight * 1.15

        return interactiveHomeArea(
            geo: geo,
            characterDisplayHeight: characterDisplayHeight,
            characterTouchWidth: characterTouchWidth,
            characterTouchHeight: characterTouchHeight
        )
    }

    private func interactiveHomeArea(
        geo: GeometryProxy,
        characterDisplayHeight: CGFloat,
        characterTouchWidth: CGFloat,
        characterTouchHeight: CGFloat
    ) -> some View {
        ZStack {
            topStatusButtonsLayer
            characterShadowLayer(displayHeight: characterDisplayHeight)
            characterTouchLayer(width: characterTouchWidth, height: characterTouchHeight)
            characterImageLayer(displayHeight: characterDisplayHeight)
            floatingHeartsLayer
            happinessGaugeLayer
            fullnessGaugeLayer
            foodBubbleLayer
            foodSelectorOverlayLayer
            toiletLockedPopupLayer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            homeContentSize = geo.size
            syncDisplayedFullness(animated: false)
            syncToiletPoopsIfNeeded(containerSize: geo.size)
        }
        .onChange(of: geo.size) { _, newSize in
            homeContentSize = newSize
            syncToiletPoopsIfNeeded(containerSize: newSize)
        }
    }

    private var topStatusButtonsLayer: some View {
        TopStatusButtons(
            onCoin: { openTopInfoPopup(.wallet) },
            onShoes: { openTopInfoPopup(.todaySteps) },
            onPresentBox: { openTopInfoPopup(.happinessRewards) },
            buttonSize: Layout.topStatusButtonSize,
            iconSize: Layout.topStatusButtonIconSize,
            spacing: Layout.topStatusButtonsSpacing
        )
        .padding(.top, Layout.topStatusButtonsTop)
        .padding(.trailing, Layout.topStatusButtonsTrailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .zIndex(Layout.zBanner + 1)
    }

    private func characterShadowLayer(displayHeight: CGFloat) -> some View {
        let shadowWidth = min(Layout.characterShadowMaxWidth, displayHeight * Layout.characterShadowWidthRatio)
        let shadowHeight = min(Layout.characterShadowMaxHeight, displayHeight * Layout.characterShadowHeightRatio)
        let shadowYOffset = Layout.characterTopOffset + (displayHeight * Layout.characterShadowYOffsetRatio)

        return Ellipse()
            .fill(Color.black.opacity(Layout.characterShadowOpacity))
            .frame(width: shadowWidth, height: shadowHeight)
            .blur(radius: Layout.characterShadowBlurRadius)
            .offset(y: shadowYOffset)
            .allowsHitTesting(false)
            .zIndex(Layout.zCharacter - 2)
    }

    private func characterTouchLayer(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.001))
            .frame(width: width, height: height)
            .offset(y: Layout.characterTopOffset)
            .zIndex(Layout.zCharacter)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleCharacterPettingChanged(
                            value,
                            gestureAreaSize: CGSize(width: width, height: height)
                        )
                    }
                    .onEnded { value in
                        handleCharacterPettingEnded(
                            value,
                            gestureAreaSize: CGSize(width: width, height: height)
                        )
                    }
            )
    }

    private func characterImageLayer(displayHeight: CGFloat) -> some View {
        Image(characterAssetName.isEmpty ? preferredCharacterRestAssetName : characterAssetName)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: displayHeight)
            .offset(
                x: isToiletLocked ? (isToiletWiggleOn ? Layout.toiletWiggleOffset : -Layout.toiletWiggleOffset) : 0,
                y: Layout.characterTopOffset
            )
            .animation(
                isToiletLocked
                ? .easeInOut(duration: Layout.toiletWiggleDuration).repeatForever(autoreverses: true)
                : .default,
                value: isToiletWiggleOn
            )
            .zIndex(Layout.zCharacter - 1)
            .allowsHitTesting(false)
    }

    private var floatingHeartsLayer: some View {
        ForEach(floatingHearts) { heart in
            FloatingHeartView(heart: heart)
                .offset(x: heart.xOffset, y: heart.yOffset)
                .zIndex(Layout.zCharacter + 1)
                .allowsHitTesting(false)
        }
    }

    private var happinessGaugeLayer: some View {
        HappinessStomachGauge(
            point: animatedHappinessPoint,
            displayPoint: displayedHappinessPoint,
            maxPoint: happinessMaxPoints,
            level: displayedHappinessLevel,
            outerSize: Layout.happinessGaugeOuterSize,
            innerSize: Layout.happinessGaugeInnerSize
        )
        .padding(.top, Layout.happinessGaugeTop)
        .padding(.leading, Layout.happinessGaugeLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var fullnessGaugeLayer: some View {
        FullnessStomachGauge(
            level: animatedFullnessLevel,
            displayLevel: displayedFullnessLevel,
            maxLevel: fullnessMaxLevel,
            outerSize: Layout.fullnessGaugeOuterSize,
            innerSize: Layout.fullnessGaugeInnerSize
        )
        .padding(.top, Layout.fullnessGaugeTop)
        .padding(.leading, Layout.fullnessGaugeLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var foodBubbleLayer: some View {
        if canShowFoodBubble {
            FloatingThoughtButton(
                imageName: "food_button",
                size: Layout.floatingBubbleSize,
                amplitude: Layout.floatingBubbleAmplitude,
                duration: Layout.floatingBubbleDuration,
                action: {
                    if isToiletLocked {
                        showToiletLockedMessage()
                        return
                    }
                    onTapFood(state: state)
                }
            )
            .padding(.leading, Layout.foodBubbleLeading)
            .padding(.top, Layout.foodBubbleTop)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .zIndex(Layout.zFoodBubble)
        }
    }

    @ViewBuilder
    private var foodSelectorOverlayLayer: some View {
        if showFoodSelector {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { closeFoodSelector() }
                .zIndex(Layout.zFoodSelector)

            FoodSelectionCarousel(
                foods: currentFoodSelectorFoods,
                countProvider: { foodID in
                    state.foodCount(foodId: foodID)
                },
                selectedFoodID: selectedFoodID,
                selectedRarityTab: selectedFoodRarityTab,
                pendingFoodID: pendingFoodFeedID,
                dragOffset: foodSelectorDragOffset,
                isFeedingAnimationRunning: isFoodFeedingAnimationRunning,
                onMoveSelection: { delta in
                    moveFoodSelection(delta)
                },
                onFeed: {
                    feedSelectedFood(state: state)
                },
                onToggleRarity: {
                    toggleFoodSelectorRarity()
                },
                onCardTap: { foodID in
                    handleFoodSelectorTap(foodID)
                },
                onDragChanged: { value in
                    handleFoodSelectorDragChanged(value)
                },
                onDragEnded: { value in
                    handleFoodSelectorDragEnded(value, state: state)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, Layout.bottomPadding + Layout.foodSelectorBottomGapFromButtons)
            .zIndex(Layout.zFoodSelector + 1)
        }
    }

    @ViewBuilder
    private var toiletLockedPopupLayer: some View {
        if showToiletLockedPopup {
            Text(toiletLockedPopupText)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, Layout.lockedPopupPaddingH)
                .padding(.vertical, Layout.lockedPopupPaddingV)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(radius: 10)
                .frame(maxWidth: Layout.lockedPopupMaxWidth)
                .transition(.opacity.combined(with: .scale))
                .zIndex(999)
        }
    }
    @ViewBuilder
    private var rightMenuPopupOverlay: some View {
        if showRightMenuPopup {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(Layout.zMenuPopup)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showRightMenuPopup = false
                    }
                }

            CenterMenuPopup(
                isToiletLocked: isToiletLocked,
                onBlocked: { showToiletLockedMessage() },
                onCamera: {
                    if isToiletLocked {
                        showToiletLockedMessage()
                        return
                    }
                    showRightMenuPopup = false
                    showCaptureModeDialog = true
                },
                onDismiss: {
                    bgmManager.playSE(.push)
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showRightMenuPopup = false
                    }
                },
                buttonSize: Layout.rightButtonSize,
                spacing: Layout.rightButtonsSpacing
            )
            .frame(maxWidth: Layout.menuPopupMaxWidth)
            .padding(.horizontal, Layout.menuPopupHorizontalPadding)
            .zIndex(Layout.zMenuPopup + 1)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var topInfoPopupOverlay: some View {
        if let activeTopInfoPopup {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(Layout.zTopInfoPopup)
                .onTapGesture { closeTopInfoPopup(playSound: false) }

            HomeTopInfoPopup(
                popup: activeTopInfoPopup,
                walletCoinCount: currentWalletCoinCount,
                todayStepCount: currentTodayStepCount,
                totalStepCount: currentTotalStepCount,
                happinessLevel: currentHappinessLevelValue,
                happinessPoint: currentHappinessPointValue,
                happinessMaxPoints: happinessMaxPoints,
                claimableLevel: currentClaimableHappinessRewardLevel,
                nextRewardLevel: nextHappinessRewardLevel,
                rewardDefinitions: AppState.happinessRewardDefinitions,
                claimedRewardLevels: currentClaimedHappinessRewardLevels,
                onClose: { closeTopInfoPopup() },
                onClaim: { level in
                    claimHappinessReward(level: level)
                }
            )
            .frame(maxWidth: Layout.topInfoPopupMaxWidth)
            .padding(.horizontal, Layout.topInfoPopupScreenHorizontalPadding)
            .padding(.vertical, Layout.topInfoPopupScreenVerticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .ignoresSafeArea()
            .zIndex(Layout.zTopInfoPopup + 1)
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
    }

    private var bottomButtonsTimelineLayer: some View {
        TimelineView(.periodic(from: Date(), by: Layout.careSpawnCheckInterval)) { timeline in
            let now = timeline.date

            BottomButtons(
                onMenu: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showRightMenuPopup = true
                    }
                },
                onGatya: {
                    showGachaView = true
                },
                onWork: {
                    showWorkTimerPreparation = true
                },
                onStep: {
                    onTapStep()
                },
                isToiletLocked: isToiletLocked,
                onBlocked: { showToiletLockedMessage() },
                buttonSize: Layout.bottomButtonSize,
                spacing: Layout.bottomButtonsSpacing,
                horizontalPadding: Layout.bottomHorizontalPadding
            )
            .onChange(of: timeline.date) { _, newDate in
                let previousSnapshot = makeHomePersistenceSnapshot()

                state.ensureDailyResetIfNeeded(now: newDate)
                syncDisplayedFullness(now: newDate)
                scheduleHappinessDecayIfNeeded(now: newDate)

                state.ensureToiletNextSpawnScheduled(now: newDate)
                state.ensureFoodNextSpawnScheduled(now: newDate)

                maybeSpawnToiletFlag(state: state, now: newDate, persistChanges: false)
                maybeSpawnFoodFlag(state: state, now: newDate, persistChanges: false)
                syncToiletPoopsIfNeeded(containerSize: homeContentSize, now: newDate, persistChanges: false)

                persistHomeStateIfNeeded(previousSnapshot: previousSnapshot)
            }
            .onAppear {
                let previousSnapshot = makeHomePersistenceSnapshot()

                state.ensureDailyResetIfNeeded(now: now)
                syncDisplayedFullness(now: now)
                scheduleHappinessDecayIfNeeded(now: now)

                state.ensureToiletNextSpawnScheduled(now: now)
                state.ensureFoodNextSpawnScheduled(now: now)

                maybeSpawnToiletFlag(state: state, now: now, persistChanges: false)
                maybeSpawnFoodFlag(state: state, now: now, persistChanges: false)
                syncToiletPoopsIfNeeded(containerSize: homeContentSize, now: now, persistChanges: false)

                persistHomeStateIfNeeded(previousSnapshot: previousSnapshot)
            }
        }
        .padding(.bottom, Layout.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .zIndex(Layout.zBottomButtons)
    }

    @ViewBuilder
    private var toiletTicketButtonLayer: some View {
        if canShowToiletTicketButton {
            ToiletTicketQuickButton(
                imageName: "wc",
                countText: "\(ownedToiletTicketCount)",
                action: {
                    onTapToiletTicket(state: state)
                }
            )
            .padding(.trailing, Layout.toiletTicketBottomTrailing)
            .padding(.bottom, Layout.toiletTicketBottomOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .zIndex(Layout.zToiletTicketButton)
        }
    }

    @ViewBuilder
    private var toiletPoopsLayer: some View {
        if state.hasToiletFlag {
            GeometryReader { rootGeo in
                ZStack {
                    ForEach(visibleToiletPoops) { poop in
                        ToiletPoopView(
                            item: poop,
                            size: Layout.toiletPoopSize,
                            hitSize: Layout.toiletPoopHitSize,
                            opacity: toiletPoopOpacity(for: poop),
                            isScratchEnabled: state.hasToiletFlag && !isToiletTicketCleaning,
                            onScratchChanged: { value in
                                handleToiletPoopScratchChanged(poop, value: value)
                            },
                            onScratchEnded: {
                                handleToiletPoopScratchEnded(poop)
                            }
                        )
                        .position(rootPosition(for: poop, rootSize: rootGeo.size))
                    }
                }
                .frame(width: rootGeo.size.width, height: rootGeo.size.height)
            }
            .allowsHitTesting(state.hasToiletFlag && !isToiletTicketCleaning)
            .zIndex(Layout.zToiletPoops)
        }
    }

    @ViewBuilder
    private var toiletBubbleLayer: some View {
        if state.hasToiletFlag {
            FloatingThoughtButton(
                imageName: "wc_button",
                size: Layout.floatingBubbleSize,
                amplitude: Layout.floatingBubbleAmplitude,
                duration: Layout.floatingBubbleDuration,
                action: {
                    onTapToilet(state: state)
                }
            )
            .padding(.trailing, Layout.wcBubbleTrailing)
            .padding(.top, Layout.bannerHeight + Layout.wcBubbleTop)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .zIndex(Layout.zWcButton)
        }
    }

    private var topBannerOverlay: some View {
        Color.clear
            .frame(width: Layout.bannerWidthIPhone, height: Layout.bannerHeight)
            .frame(maxWidth: .infinity)
            .frame(height: Layout.bannerHeight)
            .frame(maxHeight: .infinity, alignment: .top)
            .zIndex(Layout.zBanner)
    }

    private func makeHomePersistenceSnapshot() -> HomePersistenceSnapshot {
        HomePersistenceSnapshot(
            walletSteps: state.walletSteps,
            pendingSteps: state.pendingSteps,
            lastSyncedAt: state.lastSyncedAt,
            dailyGoalKcal: state.dailyGoalKcal,
            lastDayKey: state.lastDayKey,
            cachedTodaySteps: state.cachedTodaySteps,
            cachedTodayMeterSteps: state.cachedTodayMeterSteps,
            satisfactionLevel: state.satisfactionLevel,
            satisfactionLastUpdatedAt: state.satisfactionLastUpdatedAt,
            foodFlagAt: state.foodFlagAt,
            foodLastRaisedAt: state.foodLastRaisedAt,
            foodNextSpawnAt: state.foodNextSpawnAt,
            toiletFlagAt: state.toiletFlagAt,
            toiletLastRaisedAt: state.toiletLastRaisedAt,
            toiletNextSpawnAt: state.toiletNextSpawnAt,
            toiletPoopsData: state.toiletPoopsData,
            toiletPoopLastSpawnAt: state.toiletPoopLastSpawnAt,
            currentPetID: state.currentPetID,
            ownedPetIDsData: state.ownedPetIDsData,
            ownedFoodCountsData: state.ownedFoodCountsData
        )
    }

    @discardableResult
    @MainActor
    private func persistHomeStateIfNeeded(
        previousSnapshot: HomePersistenceSnapshot?,
        forceWidgetReload: Bool = false
    ) -> Bool {
        let currentSnapshot = makeHomePersistenceSnapshot()

        if let previousSnapshot, previousSnapshot == currentSnapshot {
            if forceWidgetReload {
                updateWidgetSnapshot(forceReload: true)
            }
            return false
        }

        save(forceWidgetReload: forceWidgetReload)
        return true
    }

    @MainActor
    private func runForegroundResyncIfNeeded() {
        guard !isForegroundSyncInProgress else { return }
        isForegroundSyncInProgress = true

        Task { @MainActor in
            defer { isForegroundSyncInProgress = false }

            let previousSnapshot = makeHomePersistenceSnapshot()

            bgmManager.startIfNeeded()
            await hk.startStepUpdatesIfNeeded()
            await hk.refreshTodayStepsForWidget()

            state.ensureInitialPetsIfNeeded()
            _ = state.normalizeFixedDailyStepGoal()

            syncCharacterBaseFromState(force: true)

            todaySteps = state.widgetTodaySteps
            displayedTodaySteps = todaySteps
            syncDisplayedHappiness(animated: false)
            displayedStepProgress = calcStepProgressRaw(
                todaySteps: displayedTodaySteps,
                goalSteps: fixedDailyGoalSteps
            )
            syncDisplayedFullness()

            handleDayRolloverIfNeeded(state: state)

            await runSync(state: state)

            state.ensureToiletNextSpawnScheduled(now: Date())
            state.ensureFoodNextSpawnScheduled(now: Date())

            maybeSpawnToiletFlag(state: state, persistChanges: false)
            maybeSpawnFoodFlag(state: state, persistChanges: false)

            syncToiletPoopsIfNeeded(containerSize: homeContentSize, persistChanges: false)
            syncFoodSelectorSelection()
            syncDisplayedFullness()
            scheduleHappinessDecayIfNeeded(now: Date())

            if isHomeVisible {
                await reconcileWalletDisplayIfNeeded(state: state)
            }

            updateToiletWiggle()
            syncCharacterBaseFromState(force: true)
            persistHomeStateIfNeeded(previousSnapshot: previousSnapshot, forceWidgetReload: true)
        }
    }

    @MainActor
    private func scheduleMainActorTask(
        after delay: TimeInterval,
        operation: @escaping @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            let safeDelay = max(0, delay)
            if safeDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(safeDelay * 1_000_000_000))
            } else {
                await Task.yield()
            }
            guard !Task.isCancelled else { return }
            operation()
        }
    }

    @MainActor
    private func cancelDelayedHomeTasks() {

        toiletLockedPopupDismissTask?.cancel()
        toiletLockedPopupDismissTask = nil

        toiletTicketCleanupTask?.cancel()
        toiletTicketCleanupTask = nil

        foodFeedResolutionTask?.cancel()
        foodFeedResolutionTask = nil


        toiletWiggleActivationTask?.cancel()
        toiletWiggleActivationTask = nil

        happinessDecayAnimationTask?.cancel()
        happinessDecayAnimationTask = nil

        floatingHeartCleanupTasks.values.forEach { $0.cancel() }
        floatingHeartCleanupTasks.removeAll()
    }

    @MainActor
    private func syncDisplayedHappiness(animated: Bool = true) {
        state.resetHappinessPettingIfNeeded(now: Date())
        let point = state.happinessPoint
        let level = state.happinessLevel

        displayedHappinessPoint = point
        displayedHappinessLevel = level

        if animated {
            withAnimation(.easeInOut(duration: 0.22)) {
                animatedHappinessPoint = Double(point)
            }
        } else {
            animatedHappinessPoint = Double(point)
        }
    }

    @MainActor
    private func scheduleHappinessDecayIfNeeded(now: Date = Date()) {
        let fullness = state.currentSatisfaction(now: now)
        state.refreshHappinessDecayTracking(fullnessLevel: fullness, now: now)

        guard fullness == 0 else {
            happinessDecayAnimationTask?.cancel()
            happinessDecayAnimationTask = nil
            syncDisplayedHappiness(animated: false)
            return
        }

        let pending = state.pendingHappinessDecayCount(fullnessLevel: fullness, now: now)
        guard pending > 0 else {
            happinessDecayAnimationTask?.cancel()
            happinessDecayAnimationTask = nil
            syncDisplayedHappiness(animated: false)
            return
        }

        guard !isAnimatingHappinessDecay else { return }

        happinessDecayAnimationTask?.cancel()
        happinessDecayAnimationTask = Task { @MainActor in
            await animatePendingHappinessDecay(units: pending)
            happinessDecayAnimationTask = nil
        }
    }

    @MainActor
    private func animatePendingHappinessDecay(units: Int) async {
        guard !isAnimatingHappinessDecay else { return }
        let safeUnits = max(0, units)
        guard safeUnits > 0 else {
            syncDisplayedHappiness(animated: false)
            return
        }

        isAnimatingHappinessDecay = true
        for _ in 0..<safeUnits {
            guard !Task.isCancelled else { break }
            guard state.consumeOneHappinessDecayStep() else { break }
            syncDisplayedHappiness(animated: true)
            try? await Task.sleep(nanoseconds: 55_000_000)
            guard !Task.isCancelled else { break }
        }
        isAnimatingHappinessDecay = false
        syncDisplayedHappiness(animated: false)
    }

    @MainActor
    private func spawnFloatingHeart(at location: CGPoint, in gestureAreaSize: CGSize) {
        let safeWidth = max(1, gestureAreaSize.width)
        let safeHeight = max(1, gestureAreaSize.height)

        let clampedX = min(max(0, location.x), safeWidth)
        let clampedY = min(max(0, location.y), safeHeight)

        let heart = FloatingHeart(
            xOffset: clampedX - (safeWidth * 0.5) + CGFloat.random(in: -10...10),
            yOffset: Layout.characterTopOffset + clampedY - (safeHeight * 0.5) + CGFloat.random(in: -10...6),
            size: CGFloat.random(in: 30...52)
        )
        floatingHearts.append(heart)

        let heartID = heart.id
        floatingHeartCleanupTasks[heartID]?.cancel()
        floatingHeartCleanupTasks[heartID] = scheduleMainActorTask(after: 0.95) {
            floatingHearts.removeAll { $0.id == heartID }
            floatingHeartCleanupTasks.removeValue(forKey: heartID)
        }
    }

    @MainActor
    private func spawnRareFoodFloatingHearts(count: Int = 5) {
        guard count > 0 else { return }

        let safeWidth = max(homeContentSize.width, 1)
        let characterDisplayHeight = min(safeWidth * 0.9, Layout.characterMaxHeight)
        let baseYOffset = Layout.characterTopOffset - (characterDisplayHeight * 0.38)
        let xRange = (-safeWidth * 0.22)...(safeWidth * 0.22)

        for index in 0..<count {
            let heart = FloatingHeart(
                xOffset: CGFloat.random(in: xRange),
                yOffset: baseYOffset + CGFloat.random(in: -36...28),
                size: CGFloat.random(in: 34...62)
            )

            floatingHearts.append(heart)

            let heartID = heart.id
            floatingHeartCleanupTasks[heartID]?.cancel()
            floatingHeartCleanupTasks[heartID] = scheduleMainActorTask(after: 1.05 + (Double(index) * 0.04)) {
                floatingHearts.removeAll { $0.id == heartID }
                floatingHeartCleanupTasks.removeValue(forKey: heartID)
            }
        }
    }


    @MainActor
    private func registerCharacterPettingTouch(
        at location: CGPoint,
        in gestureAreaSize: CGSize,
        triggerKind: CharacterPettingTriggerKind,
        count: Int = 1
    ) {
        guard count > 0 else { return }

        let wasDailyLimitReached =
            state.happinessPettingPointsToday >= AppState.happinessDailyPettingPointLimit

        let result = state.registerHappinessPettingTouch(count: count, now: Date())

        guard !wasDailyLimitReached else { return }

        for _ in 0..<count {
            spawnFloatingHeart(at: location, in: gestureAreaSize)
        }

        switch triggerKind {
        case .tap:
            for _ in 0..<count {
                touchTapSEPool.play()
            }
        case .rub:
            bgmManager.playSE(.love)
        }

        if result.gainedPoints > 0 {
            syncDisplayedHappiness(animated: true)
            Task { @MainActor in
                Haptics.tap(style: .soft)
            }
        }
    }

    private func resetCharacterPettingTracking() {
        characterPettingStartPoint = nil
        characterPettingLastPoint = nil
        characterPettingAccumulatedDistance = 0
    }

    private func handleCharacterPettingChanged(
        _ value: DragGesture.Value,
        gestureAreaSize: CGSize
    ) {
        guard !isToiletLocked else { return }

        if characterPettingStartPoint == nil {
            characterPettingStartPoint = value.startLocation
            characterPettingLastPoint = value.location
            return
        }

        guard let lastPoint = characterPettingLastPoint else {
            characterPettingLastPoint = value.location
            return
        }

        let distance = hypot(value.location.x - lastPoint.x, value.location.y - lastPoint.y)
        characterPettingAccumulatedDistance += distance
        characterPettingLastPoint = value.location

        while characterPettingAccumulatedDistance >= characterRubDistancePerTouch {
            characterPettingAccumulatedDistance -= characterRubDistancePerTouch
            registerCharacterPettingTouch(at: value.location, in: gestureAreaSize, triggerKind: .rub)
        }
    }

    private func handleCharacterPettingEnded(
        _ value: DragGesture.Value,
        gestureAreaSize: CGSize
    ) {
        defer { resetCharacterPettingTracking() }

        guard !isToiletLocked else {
            showToiletLockedMessage()
            return
        }

        let totalDistance = hypot(
            value.location.x - value.startLocation.x,
            value.location.y - value.startLocation.y
        )

        if totalDistance < 10 {
            registerCharacterPettingTouch(at: value.location, in: gestureAreaSize, triggerKind: .tap)
        }
    }

    private func openTopInfoPopup(_ popup: TopInfoPopup) {
        bgmManager.playSE(.push)
        withAnimation(.easeInOut(duration: 0.18)) {
            activeTopInfoPopup = popup
        }
    }

    private func closeTopInfoPopup(playSound: Bool = true) {
        if playSound {
            bgmManager.playSE(.push)
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            activeTopInfoPopup = nil
        }
    }

    private func claimHappinessReward(level: Int) {
        guard state.claimHappinessReward(level: level, now: Date()) != nil else {
            return
        }

        save()
        syncDisplayedHappiness(animated: false)
    }

    private func normalizedFullnessLevel(_ value: Int) -> Int {
        min(fullnessMaxLevel, max(0, value))
    }

    @MainActor
    private func syncDisplayedFullness(now: Date = Date(), animated: Bool = true) {
        let newLevel = normalizedFullnessLevel(state.applySatisfactionDecayIfNeeded(now: now))
        let targetAnimatedLevel = Double(newLevel)

        displayedFullnessLevel = newLevel

        if animated {
            let duration = targetAnimatedLevel > animatedFullnessLevel ? 0.72 : 0.32
            withAnimation(.easeInOut(duration: duration)) {
                animatedFullnessLevel = targetAnimatedLevel
            }
        } else {
            animatedFullnessLevel = targetAnimatedLevel
        }

        if newLevel >= fullnessMaxLevel, showFoodSelector {
            closeFoodSelector()
        }
    }

    @discardableResult
    @MainActor
    private func syncToiletPoopsIfNeeded(
        containerSize: CGSize,
        now: Date = Date(),
        persistChanges: Bool = true
    ) -> Bool {
        guard containerSize.width > 1, containerSize.height > 1 else { return false }

        if !state.hasToiletFlag {
            toiletPoopActivePoint.removeAll()
            toiletTicketClearingPoopIDs.removeAll()
            isToiletTicketCleaning = false

            if !state.toiletPoops().isEmpty {
                state.clearToiletPoops()
                if persistChanges {
                    save()
                }
                return true
            }
            return false
        }

        let didChange = state.updateToiletPoopsByTime(now: now)
        if didChange, persistChanges {
            save()
        }
        return didChange
    }

    private func position(for poop: AppState.ToiletPoopItem, in containerSize: CGSize) -> CGPoint {
        CGPoint(
            x: max(0, min(containerSize.width, CGFloat(poop.centerXRatio) * containerSize.width)),
            y: max(0, min(containerSize.height, CGFloat(poop.centerYRatio) * containerSize.height))
        )
    }

    private func rootPosition(for poop: AppState.ToiletPoopItem, rootSize: CGSize) -> CGPoint {
        let contentSize: CGSize

        if homeContentSize.width > 1, homeContentSize.height > 1 {
            contentSize = homeContentSize
        } else {
            contentSize = CGSize(
                width: rootSize.width,
                height: max(0, rootSize.height - Layout.bannerHeight)
            )
        }

        let contentPosition = position(for: poop, in: contentSize)

        return CGPoint(
            x: contentPosition.x,
            y: Layout.bannerHeight + contentPosition.y
        )
    }

    private func currentToiletPoopProgress(id: String) -> CGFloat {
        let progress = state.toiletPoops().first(where: { $0.id == id })?.cleanedProgress ?? 0
        return CGFloat(max(0, min(1, progress)))
    }

    private func toiletPoopOpacity(for poop: AppState.ToiletPoopItem) -> Double {
        if toiletTicketClearingPoopIDs.contains(poop.id) {
            return 0
        }

        let progress = max(0, min(1, CGFloat(poop.cleanedProgress)))
        return max(0.02, 1 - (progress * 0.98))
    }

    private func toiletPoopScratchRect() -> CGRect {
        let inset = Layout.toiletPoopScratchRectInset
        let origin = (Layout.toiletPoopHitSize - Layout.toiletPoopSize) * 0.5 + inset
        let side = max(18, Layout.toiletPoopSize - (inset * 2))
        return CGRect(x: origin, y: origin, width: side, height: side)
    }

    private func handleToiletPoopScratchChanged(_ poop: AppState.ToiletPoopItem, value: DragGesture.Value) {
        guard state.hasToiletFlag else { return }
        guard !isToiletTicketCleaning else { return }

        let scratchRect = toiletPoopScratchRect()
        let point = value.location

        guard scratchRect.contains(point) else {
            toiletPoopActivePoint.removeValue(forKey: poop.id)
            return
        }

        let current = currentToiletPoopProgress(id: poop.id)

        if let lastPoint = toiletPoopActivePoint[poop.id], scratchRect.contains(lastPoint) {
            let segmentDistance = hypot(point.x - lastPoint.x, point.y - lastPoint.y)

            if segmentDistance > 0 {
                let progress = min(1, current + (segmentDistance / Layout.toiletPoopScratchDistanceToClear))
                _ = state.updateToiletPoopProgress(id: poop.id, progress: Double(progress))

                if progress >= 1 {
                    completeToiletPoopIfNeeded(id: poop.id)
                    return
                }
            }
        }

        toiletPoopActivePoint[poop.id] = point
    }

    private func handleToiletPoopScratchEnded(_ poop: AppState.ToiletPoopItem) {
        toiletPoopActivePoint.removeValue(forKey: poop.id)
        save()
    }

    @MainActor
    private func completeToiletPoopIfNeeded(id: String) {
        guard state.markToiletPoopCleared(id: id) else { return }

        toiletPoopActivePoint.removeValue(forKey: id)

        Task { @MainActor in
            Haptics.tap(style: .soft)
        }

        save()

        if !state.hasRemainingToiletPoops {
            toiletPoopActivePoint.removeAll()
            bgmManager.playSE(.wc)
            resolveToilet(state: state)
        }
    }

    private func syncFoodSelectorSelection() {
        let allOwnedFoods = ownedFoods
        let foods = currentFoodSelectorFoods

        guard !allOwnedFoods.isEmpty else {
            selectedFoodID = nil
            pendingFoodFeedID = nil
            showFoodSelector = false
            selectedFoodRarityTab = .normal
            resetFoodSelectorDragState()
            isFoodFeedingAnimationRunning = false
            return
        }

        if let pendingFoodFeedID,
           !foods.contains(where: { $0.id == pendingFoodFeedID }) {
            self.pendingFoodFeedID = nil
        }

        guard !foods.isEmpty else {
            selectedFoodID = nil
            return
        }

        if let selectedFoodID,
           foods.contains(where: { $0.id == selectedFoodID }) {
            return
        }

        selectedFoodID = foods.first?.id
        pendingFoodFeedID = nil
    }

    private func resetFoodSelectorDragState() {
        foodSelectorDragOffset = .zero
        foodSelectorDragAnchorFoodID = nil
    }

    private func closeFoodSelector() {
        resetFoodSelectorDragState()
        isFoodFeedingAnimationRunning = false
        pendingFoodFeedID = nil
        selectedFoodRarityTab = .normal
        stopFoodSelectorHorizontalRattleIfNeeded()

        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            showFoodSelector = false
        }
    }

    private func openFoodSelector() {
        guard !isToiletLocked else {
            showToiletLockedMessage()
            return
        }

        let feedState = state.canFeedNow(now: Date())
        guard feedState.can else {
            return
        }

        guard !ownedFoods.isEmpty else { return }

        selectedFoodRarityTab = .normal
        syncFoodSelectorSelection()
        resetFoodSelectorDragState()
        isFoodFeedingAnimationRunning = false
        pendingFoodFeedID = nil
        stopFoodSelectorHorizontalRattleIfNeeded()

        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            showFoodSelector = true
        }
    }

    private func toggleFoodSelectorRarity() {
        stopFoodSelectorHorizontalRattleIfNeeded()
        pendingFoodFeedID = nil
        resetFoodSelectorDragState()
        selectedFoodRarityTab = selectedFoodRarityTab.next
        syncFoodSelectorSelection()

        Task { @MainActor in
            Haptics.tap(style: .soft)
        }
    }

    private func applyFoodSelectionDelta(_ delta: Int, animated: Bool = true) {
        let foods = currentFoodSelectorFoods
        guard foods.count >= 2 else { return }
        guard delta != 0 else { return }

        syncFoodSelectorSelection()
        guard let currentID = selectedFoodID,
              let currentIndex = foods.firstIndex(where: { $0.id == currentID }) else {
            selectedFoodID = foods.first?.id
            pendingFoodFeedID = nil
            return
        }

        let nextIndex = (currentIndex + delta).positiveModulo(foods.count)
        let nextFoodID = foods[nextIndex].id
        guard nextFoodID != currentID else { return }

        let applySelection = {
            selectedFoodID = nextFoodID
            pendingFoodFeedID = nil
        }

        if animated {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                applySelection()
            }
        } else {
            applySelection()
        }

        Task { @MainActor in
            Haptics.tap(style: .soft)
        }
    }

    private func moveFoodSelection(_ delta: Int) {
        guard delta != 0 else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                foodSelectorDragOffset = .zero
            }
            return
        }

        applyFoodSelectionDelta(delta)

        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            foodSelectorDragOffset = .zero
        }
    }


    private func updateFoodSelectionWhileDragging(_ value: DragGesture.Value) {
        let foods = currentFoodSelectorFoods
        guard !foods.isEmpty else {
            resetFoodSelectorDragState()
            return
        }

        if foodSelectorDragAnchorFoodID == nil {
            syncFoodSelectorSelection()
            foodSelectorDragAnchorFoodID = selectedFoodID ?? foods.first?.id
        }

        foodSelectorDragOffset = value.translation
    }

    private func resolvedFoodSelectionDelta(horizontal: CGFloat, predictedHorizontal: CGFloat) -> Int {
        let stepWidth = max(Layout.foodSelectorRollStepWidth, 1)
        let projectedHorizontal = abs(predictedHorizontal) > abs(horizontal) ? predictedHorizontal : horizontal
        let roundedDelta = Int(round((-projectedHorizontal) / stepWidth))

        if roundedDelta != 0 {
            return roundedDelta
        }

        let fallbackThreshold = stepWidth * 0.32
        if projectedHorizontal <= -fallbackThreshold {
            return 1
        }
        if projectedHorizontal >= fallbackThreshold {
            return -1
        }

        return 0
    }

    private func cancelPendingFoodSelection() {
        guard pendingFoodFeedID != nil else { return }

        stopFoodSelectorHorizontalRattleIfNeeded()
        pendingFoodFeedID = nil

        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            resetFoodSelectorDragState()
        }

        Task { @MainActor in
            Haptics.tap(style: .soft)
        }
    }

    private func handleFoodSelectorDragChanged(_ value: DragGesture.Value) {
        stopFoodSelectorHorizontalRattleIfNeeded()

        if pendingFoodFeedID != nil {
            foodSelectorDragOffset = CGSize(width: 0, height: value.translation.height)
            return
        }

        updateFoodSelectionWhileDragging(value)
    }

    private func handleFoodSelectorDragEnded(_ value: DragGesture.Value, state: AppState) {
        stopFoodSelectorHorizontalRattleIfNeeded()

        let horizontal = value.translation.width
        let vertical = value.translation.height
        let predictedHorizontal = value.predictedEndTranslation.width
        let predictedVertical = value.predictedEndTranslation.height

        defer {
            foodSelectorDragAnchorFoodID = nil
        }

        if pendingFoodFeedID != nil {
            let isFeedSwipe =
                predictedVertical < -110 ||
                vertical < -100

            let isCancelSwipe =
                predictedVertical > 110 ||
                vertical > 100

            if isFeedSwipe {
                feedSelectedFood(state: state)
                return
            }

            if isCancelSwipe {
                cancelPendingFoodSelection()
                return
            }

            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                foodSelectorDragOffset = .zero
            }
            return
        }

        let isPrimaryFeedSwipe =
            predictedVertical < -95 &&
            abs(predictedHorizontal) < 70 &&
            abs(horizontal) < 80

        let isSecondaryFeedSwipe =
            vertical < -85 &&
            abs(horizontal) < 55

        if isPrimaryFeedSwipe || isSecondaryFeedSwipe {
            handleFoodFeedSwipe(state: state)
            return
        }

        let committedDelta = resolvedFoodSelectionDelta(
            horizontal: horizontal,
            predictedHorizontal: predictedHorizontal
        )

        withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
            if committedDelta != 0 {
                applyFoodSelectionDelta(committedDelta, animated: false)
            }
            foodSelectorDragOffset = .zero
        }
    }

    private func stopFoodSelectorHorizontalRattleIfNeeded() {
        guard isFoodSelectorHorizontalRattling else { return }
        isFoodSelectorHorizontalRattling = false

        Task { @MainActor in
            Haptics.stopRattle()
        }
    }

    private func handleFoodFeedSwipe(state: AppState) {
        guard !isToiletLocked else {
            showToiletLockedMessage()
            closeFoodSelector()
            return
        }

        let feedState = state.canFeedNow(now: Date())
        guard feedState.can else {
            closeFoodSelector()
            return
        }

        guard let selectedFood else {
            Task { @MainActor in
                Haptics.rattle(duration: 0.12, style: .light)
            }
            closeFoodSelector()
            return
        }

        pendingFoodFeedID = selectedFood.id
        resetFoodSelectorDragState()

        Task { @MainActor in
            Haptics.tap(style: .soft)
        }
    }

    private func handleFoodSelectorTap(_ foodID: String) {
        guard !isToiletLocked else {
            showToiletLockedMessage()
            closeFoodSelector()
            return
        }

        let feedState = state.canFeedNow(now: Date())
        guard feedState.can else {
            closeFoodSelector()
            return
        }

        guard currentFoodSelectorFoods.contains(where: { $0.id == foodID }) else {
            return
        }

        stopFoodSelectorHorizontalRattleIfNeeded()

        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
            selectedFoodID = foodID
            resetFoodSelectorDragState()
            pendingFoodFeedID = foodID
        }

        Task { @MainActor in
            Haptics.tap(style: .soft)
        }
    }

    @MainActor
    private func feedSelectedFood(state: AppState) {
        stopFoodSelectorHorizontalRattleIfNeeded()

        guard !isToiletLocked else {
            showToiletLockedMessage()
            closeFoodSelector()
            return
        }

        guard !isFoodFeedingAnimationRunning else { return }
        guard let selectedFood else {
            pendingFoodFeedID = nil
            Task { @MainActor in
                Haptics.rattle(duration: 0.12, style: .light)
            }
            closeFoodSelector()
            return
        }

        let feedState = state.canFeedNow(now: Date())
        guard feedState.can else {
            pendingFoodFeedID = nil
            closeFoodSelector()
            return
        }

        let selectedFoodID = selectedFood.id
        let shouldShowRareFoodEffect = !selectedFood.isShopEligible

        pendingFoodFeedID = selectedFoodID
        isFoodFeedingAnimationRunning = true
        foodSelectorDragAnchorFoodID = nil

        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
            foodSelectorDragOffset = CGSize(width: 0, height: -120)
        }

        Task { @MainActor in
            Haptics.tap(style: .medium)
        }

        foodFeedResolutionTask?.cancel()
        foodFeedResolutionTask = scheduleMainActorTask(after: 0.16) { [selectedFoodID, shouldShowRareFoodEffect] in
            let didFeed = resolveFood(foodId: selectedFoodID, state: state)
            isFoodFeedingAnimationRunning = false
            foodSelectorDragOffset = .zero
            foodFeedResolutionTask = nil

            if didFeed {
                if shouldShowRareFoodEffect {
                    bgmManager.playSE(.touch)
                    spawnRareFoodFloatingHearts(count: 5)
                }

                syncFoodSelectorSelection()
                closeFoodSelector()
            } else {
                pendingFoodFeedID = nil
            }
        }
    }

    @MainActor
    private func showToiletLockedMessage() {
        toiletLockedPopupText = "\(currentPetName)は今それどころじゃない！"
        withAnimation(.easeOut(duration: 0.12)) {
            showToiletLockedPopup = true
        }

        toiletLockedPopupDismissTask?.cancel()
        toiletLockedPopupDismissTask = scheduleMainActorTask(after: Layout.lockedPopupShowSeconds) {
            withAnimation(.easeInOut(duration: 0.18)) {
                showToiletLockedPopup = false
            }
            toiletLockedPopupDismissTask = nil
        }

        Task { @MainActor in
            Haptics.rattle(duration: 0.10, style: .light)
        }
    }

    @MainActor
    private func updateToiletWiggle() {
        toiletWiggleActivationTask?.cancel()

        if isToiletLocked {
            isToiletWiggleOn = false
            toiletWiggleActivationTask = scheduleMainActorTask(after: 0) {
                isToiletWiggleOn = true
                toiletWiggleActivationTask = nil
            }
        } else {
            isToiletWiggleOn = false
        }
    }

    @MainActor
    private func syncCharacterBaseFromState(force: Bool) {
        if !force {
            guard !isCharacterActionRunning else { return }
        }
        characterAssetName = preferredCharacterRestAssetName
    }

    @discardableResult
    @MainActor
    private func maybeSpawnToiletFlag(
        state: AppState,
        now: Date = Date(),
        persistChanges: Bool = true
    ) -> Bool {
        let didRaise = state.raiseToiletFlag(now: now)
        if didRaise {
            if persistChanges {
                save()
            }
            syncToiletPoopsIfNeeded(containerSize: homeContentSize, now: now, persistChanges: persistChanges)
            syncCharacterBaseFromState(force: true)
            updateToiletWiggle()
        }
        return didRaise
    }

    @discardableResult
    @MainActor
    private func maybeSpawnFoodFlag(
        state: AppState,
        now: Date = Date(),
        persistChanges: Bool = true
    ) -> Bool {
        syncDisplayedFullness(now: now)

        let feedState = state.canFeedNow(now: now)
        guard feedState.can else {
            if state.hasFoodFlag {
                let didResolve = state.resolveFood(now: now)
                if didResolve, persistChanges {
                    save()
                }
                return didResolve
            }
            return false
        }

        let didRaise = state.raiseFoodFlagIfNeeded(now: now)
        if didRaise {
            if persistChanges {
                save()
            }
        }
        return didRaise
    }

    @MainActor
    private func startCharacterIdleLoopIfNeeded() {
        guard idleLoopTask == nil else { return }

        idleLoopTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)

            while !Task.isCancelled {
                if !isHomeVisible {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    continue
                }

                if isToiletLocked {
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    continue
                }

                if isCharacterActionRunning {
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    continue
                }

                let wait = Double.random(in: 2.2...6.0)
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))

                if Task.isCancelled { break }
                if !isHomeVisible { continue }
                if isToiletLocked { continue }
                if isCharacterActionRunning { continue }

                if !canPlayBlinkAnimation {
                    await MainActor.run {
                        characterAssetName = preferredCharacterRestAssetName
                    }
                    continue
                }

                let doDouble = Double.random(in: 0...1) < doubleBlinkChance
                await playBlink()

                if doDouble {
                    let gap = Double.random(in: doubleBlinkGapRange)
                    try? await Task.sleep(nanoseconds: UInt64(gap * 1_000_000_000))

                    if Task.isCancelled { break }
                    if !isHomeVisible { continue }
                    if isToiletLocked { continue }
                    if isCharacterActionRunning { continue }

                    await playBlink()
                }
            }
        }
    }

    @MainActor
    private func stopCharacterIdleLoop() {
        idleLoopTask?.cancel()
        idleLoopTask = nil
    }

    @MainActor
    private func playBlink() async {
        guard isHomeVisible else { return }
        guard !isCharacterActionRunning else { return }
        guard !isToiletLocked else { return }

        guard canPlayBlinkAnimation else {
            await MainActor.run { characterAssetName = preferredCharacterRestAssetName }
            return
        }

        let base = currentBaseAssetName
        let blink1 = "\(base)_idle_blink_0001"
        let blink2 = "\(base)_idle_blink_0002"

        await MainActor.run { characterAssetName = blink1 }
        try? await Task.sleep(nanoseconds: 70_000_000)
        if isCharacterActionRunning || !isHomeVisible { return }
        if isToiletLocked { return }

        await MainActor.run { characterAssetName = blink2 }
        try? await Task.sleep(nanoseconds: 60_000_000)
        if isCharacterActionRunning || !isHomeVisible { return }
        if isToiletLocked { return }

        await MainActor.run { characterAssetName = blink1 }
        try? await Task.sleep(nanoseconds: 70_000_000)
        if isCharacterActionRunning || !isHomeVisible { return }
        if isToiletLocked { return }

        await MainActor.run { characterAssetName = preferredCharacterRestAssetName }
    }

    @discardableResult
    @MainActor
    private func resolveFood(foodId: String, state: AppState) -> Bool {
        guard !isToiletLocked else {
            showToiletLockedMessage()
            return false
        }

        guard let food = FoodCatalog.byId(foodId) else {
            return false
        }

        let now = Date()
        let feedState = state.canFeedNow(now: now)
        guard feedState.can else {
            syncDisplayedFullness(now: now)
            syncFoodSelectorSelection()
            return false
        }

        guard state.foodCount(foodId: foodId) > 0 else {
            Task { @MainActor in
                Haptics.rattle(duration: 0.12, style: .light)
            }
            syncFoodSelectorSelection()
            return false
        }

        guard state.consumeFood(foodId: foodId, count: 1) else {
            return false
        }

        let feedResult = state.feedOnce(now: now)
        guard feedResult.didFeed else {
            syncDisplayedFullness(now: now)
            syncFoodSelectorSelection()
            return false
        }

        _ = state.resolveFood(now: now)

        let happinessBonus = state.happinessBonusPoints(forFoodID: food.id)
        if happinessBonus > 0 {
            _ = state.addHappinessPoints(happinessBonus, now: now)
        }

        save()
        syncDisplayedFullness(now: now)
        syncDisplayedHappiness(animated: happinessBonus > 0)

        bgmManager.playSE(.eat)


        syncFoodSelectorSelection()
        updateWidgetSnapshot(forceReload: true)
        return true
    }

    private func calcStepProgressRaw(todaySteps: Int, goalSteps: Int) -> Double {
        guard goalSteps > 0 else { return 0 }
        return Double(todaySteps) / Double(goalSteps)
    }

    @MainActor
    private func reconcileWalletDisplayIfNeeded(state: AppState) async {
        guard isHomeVisible else { return }
        guard !isAnimatingGain else { return }

        let target = state.walletSteps

        if displayedWalletSteps > target {
            await playWalletCountDownAnimation(from: displayedWalletSteps, to: target)
            return
        }

        if displayedWalletSteps != target {
            await MainActor.run { displayedWalletSteps = target }
        }
    }


    @MainActor
    private func playWalletCountDownAnimation(from: Int, to: Int) async {
        guard isHomeVisible else { return }
        guard from > to else { return }
        guard !isAnimatingGain else { return }

        let magnitude = from - to
        let duration = min(1.2, max(0.25, Double(magnitude) * 0.006))

        let fps: Double = 60
        let frames = max(1, Int(duration * fps))

        await MainActor.run {
            Haptics.startRattle(style: .light, interval: 0.04, intensity: 0.65)
        }

        for i in 0...frames {
            if !isHomeVisible { break }

            let t = Double(i) / Double(frames)
            let eased = 1 - pow(1 - t, 3)
            let v = from - Int(Double(magnitude) * eased)

            await MainActor.run {
                displayedWalletSteps = max(to, v)
            }

            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / fps))
        }

        await MainActor.run {
            displayedWalletSteps = to
            Haptics.stopRattle()
        }
    }

    private func makeUniquePhotoFileName(dayKey: String, now: Date) -> String {
        let ms = Int64(now.timeIntervalSince1970 * 1000)
        return "\(dayKey)_\(ms).jpg"
    }

    private func normalizePlaceName(_ placeName: String?) -> String? {
        guard let placeName else { return nil }
        let t = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    @MainActor
    private func saveTodayPhoto(
        _ uiImage: UIImage,
        placeName: String?,
        latitude: Double?,
        longitude: Double?
    ) {
        do {
            let key = AppState.makeDayKey(Date())
            let now = Date()

            let fileName = makeUniquePhotoFileName(dayKey: key, now: now)

            try TodayPhotoStorage.saveJPEG(uiImage, fileName: fileName, quality: 0.9)

            let created = TodayPhotoEntry(
                dayKey: key,
                date: now,
                fileName: fileName,
                placeName: normalizePlaceName(placeName),
                latitude: latitude,
                longitude: longitude
            )
            modelContext.insert(created)

            try modelContext.save()

            Task { @MainActor in
                Haptics.rattle(duration: 0.18, style: .light)
            }
        } catch {
            print("❌ saveTodayPhoto failed:", error)
        }
    }

    @MainActor
    private func onTapFood(state: AppState) {
        guard !isToiletLocked else {
            showToiletLockedMessage()
            return
        }

        let feedState = state.canFeedNow(now: Date())
        guard feedState.can else {
            return
        }

        syncFoodSelectorSelection()

        guard !ownedFoods.isEmpty else {
            bgmManager.playSE(.push)
            Task { @MainActor in
                Haptics.rattle(duration: 0.12, style: .light)
            }
            return
        }

        bgmManager.playSE(.push)

        if showFoodSelector {
            closeFoodSelector()
        } else {
            openFoodSelector()
        }

        updateWidgetSnapshot(forceReload: true)
    }

    @MainActor
    private func onTapToilet(state: AppState) {
        guard state.hasToiletFlag else {
            Task { @MainActor in
                Haptics.rattle(duration: 0.18, style: .light)
            }
            return
        }

        guard !isToiletTicketCleaning else { return }

        syncToiletPoopsIfNeeded(containerSize: homeContentSize)

        guard !visibleToiletPoops.isEmpty else {
            resolveToilet(state: state)
            syncCharacterBaseFromState(force: true)
            updateToiletWiggle()
            return
        }

    }

    @MainActor
    private func onTapToiletTicket(state: AppState) {
        guard state.hasToiletFlag else { return }
        guard !isToiletTicketCleaning else { return }

        syncToiletPoopsIfNeeded(containerSize: homeContentSize)

        let poops = visibleToiletPoops
        guard !poops.isEmpty else {
            resolveToilet(state: state)
            return
        }

        guard state.gachaSpecialItemCount(id: "wc") > 0 else {
            Task { @MainActor in
                Haptics.rattle(duration: 0.12, style: .light)
            }
            return
        }

        isToiletTicketCleaning = true
        toiletPoopActivePoint.removeAll()

        withAnimation(.easeOut(duration: 0.28)) {
            toiletTicketClearingPoopIDs = Set(poops.map(\.id))
        }

        toiletTicketCleanupTask?.cancel()
        toiletTicketCleanupTask = scheduleMainActorTask(after: 0.30) {
            guard state.gachaConsumeSpecialItem(id: "wc", count: 1) else {
                toiletTicketClearingPoopIDs.removeAll()
                isToiletTicketCleaning = false
                toiletTicketCleanupTask = nil
                return
            }

            for poop in poops {
                _ = state.markToiletPoopCleared(id: poop.id)
            }

            toiletTicketClearingPoopIDs.removeAll()
            isToiletTicketCleaning = false

            if !poops.isEmpty, !state.hasRemainingToiletPoops {
                bgmManager.playSE(.wc)
            }

            resolveToilet(state: state)
            toiletTicketCleanupTask = nil
        }
    }

    @MainActor
    private func onTapStep() {
        guard !isToiletLocked else {
            showToiletLockedMessage()
            return
        }

        showStepEnjoy = true
    }

    @MainActor
    private func resolveToilet(state: AppState) {
        let r = state.resolveToilet(now: Date())
        guard r.didResolve else { return }

        toiletPoopActivePoint.removeAll()
        toiletTicketClearingPoopIDs.removeAll()
        isToiletTicketCleaning = false

        save()

        syncCharacterBaseFromState(force: true)
        updateToiletWiggle()
        updateWidgetSnapshot(forceReload: true)
    }

    @MainActor
    private func save(forceWidgetReload: Bool = false) {
        do {
            try modelContext.save()
            updateWidgetSnapshot(forceReload: forceWidgetReload)
        } catch {
            print("❌ modelContext.save() failed:", error)
        }
    }

    @MainActor
    private func updateWidgetSnapshot(forceReload: Bool = false) {
        let widgetState = state.makeWidgetStateSnapshot(todaySteps: widgetLinkedTodaySteps)
        let changed = HomeWidgetBridge.save(widgetState: widgetState, state: state)

        #if canImport(WidgetKit)
        if forceReload || changed {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }

    @MainActor
    private func handleDayRolloverIfNeeded(state: AppState) {
        let now = Date()
        let todayKey = AppState.makeDayKey(now)
        guard state.lastDayKey == todayKey else {
            state.cachedTodaySteps = 0
            state.cachedTodayMeterSteps = 0
            todaySteps = 0
            displayedTodaySteps = 0

            state.ensureDailyResetIfNeeded(now: now)
            state.resetHappinessPettingIfNeeded(now: now)
            state.lastSyncedAt = Calendar.current.startOfDay(for: now)
            syncDisplayedHappiness(animated: false)
            syncDisplayedFullness(now: now)
            scheduleHappinessDecayIfNeeded(now: now)
            save()
            return
        }
    }

    @MainActor
    private func runSync(state: AppState) async {
        guard hk.authState == .authorized else { return }

        let now = Date()
        let todayKey = AppState.makeDayKey(now)

        let previousCachedSteps = max(0, state.cachedTodaySteps)
        let beforeDisplayedTodaySteps = displayedTodaySteps
        let beforeDisplayedWallet = displayedWalletSteps

        await hk.refreshTodayStepsForWidget(now: now)
        let fetchedSteps = max(hk.todaySteps, await hk.fetchTodayStepTotal(now: now))

        let cacheResult = state.updateTodayStepCacheProtectingZero(
            fetchedSteps: fetchedSteps,
            todayKey: todayKey
        )

        state.lastSyncedAt = now

        todaySteps = cacheResult.stepsToUse

        let deltaSteps = max(0, cacheResult.stepsToUse - previousCachedSteps)
        if deltaSteps > 0 {
            state.pendingSteps += deltaSteps
        }
        save()

        await playGainAnimationIfNeeded(
            state: state,
            fromDisplayedTodaySteps: beforeDisplayedTodaySteps,
            fromDisplayedWallet: beforeDisplayedWallet
        )

        if !isAnimatingGain {
            displayedTodaySteps = todaySteps

            if isHomeVisible {
                displayedWalletSteps = state.walletSteps
            }

            withAnimation(.easeOut(duration: 0.25)) {
                displayedStepProgress = calcStepProgressRaw(
                    todaySteps: displayedTodaySteps,
                    goalSteps: fixedDailyGoalSteps
                )
            }
        }

        syncCharacterBaseFromState(force: true)
        updateWidgetSnapshot()
    }

    @MainActor
    private func playGainAnimationIfNeeded(
        state: AppState,
        fromDisplayedTodaySteps: Int,
        fromDisplayedWallet: Int
    ) async {
        guard !isAnimatingGain else { return }

        let deltaWallet = state.pendingSteps
        let targetWallet = state.walletSteps + max(0, deltaWallet)
        let targetTodaySteps = todaySteps

        let hasAnyIncrease = (targetWallet > fromDisplayedWallet) || (targetTodaySteps > fromDisplayedTodaySteps)
        guard hasAnyIncrease else { return }

        isAnimatingGain = true

        if deltaWallet > 0 {
            state.pendingSteps = 0
            state.walletSteps = targetWallet
            save()
        }

        let totalMagnitude = max(targetWallet - fromDisplayedWallet, targetTodaySteps - fromDisplayedTodaySteps)
        let duration = min(1.6, max(0.45, Double(totalMagnitude) * 0.008))

        let fps: Double = 60
        let frames = max(1, Int(duration * fps))

        await MainActor.run {
            Haptics.startRattle(style: .light, interval: 0.03, intensity: 0.8)
        }

        for i in 0...frames {
            let t = Double(i) / Double(frames)
            let eased = 1 - pow(1 - t, 3)

            let newWallet = fromDisplayedWallet + Int(Double(targetWallet - fromDisplayedWallet) * eased)
            let newTodaySteps = fromDisplayedTodaySteps + Int(Double(targetTodaySteps - fromDisplayedTodaySteps) * eased)

            await MainActor.run {
                displayedWalletSteps = newWallet
                displayedTodaySteps = newTodaySteps
                displayedStepProgress = calcStepProgressRaw(
                    todaySteps: displayedTodaySteps,
                    goalSteps: fixedDailyGoalSteps
                )
            }

            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / fps))
        }

        await MainActor.run {
            displayedWalletSteps = targetWallet
            displayedTodaySteps = targetTodaySteps
            displayedStepProgress = calcStepProgressRaw(
                todaySteps: displayedTodaySteps,
                goalSteps: fixedDailyGoalSteps
            )
            Haptics.stopRattle()
        }

        isAnimatingGain = false
        syncCharacterBaseFromState(force: true)
    }
}

// MARK: - Widget Bridge
private enum HomeWidgetBridge {
    static let appGroupID = "group.com.shota.CalPet"
    static let widgetKind = "CalPetMediumWidget"

    private static let toiletFlagKey = "toiletFlag"
    private static let bathFlagKey = "bathFlag"
    private static let currentPetIDKey = "currentPetID"
    private static let todayStepsKey = "todaySteps"

    private static let toiletFlagAtKey = "toiletFlagAt"
    private static let bathFlagAtKey = "bathFlagAt"
    private static let toiletNextSpawnAtKey = "toiletNextSpawnAt"
    private static let bathNextSpawnAtKey = "bathNextSpawnAt"
    private static let lastDayKeyKey = "lastDayKey"

    private static let lastSignatureKey = "homeWidgetLastSignature"

    private static func unixSeconds(_ date: Date?) -> Int64? {
        guard let date else { return nil }
        return Int64(date.timeIntervalSince1970)
    }

    private static func write(_ value: Int64?, forKey key: String, defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    static func save(widgetState: AppState.WidgetStateSnapshot, state _: AppState) -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return false }

        let normalizedPetID = widgetState.currentPetID.trimmingCharacters(in: .whitespacesAndNewlines)
        let safePetID = normalizedPetID.isEmpty ? "pet_000" : normalizedPetID
        let safeSteps = max(0, widgetState.todaySteps)
        let safeLastDayKey = widgetState.lastDayKey.trimmingCharacters(in: .whitespacesAndNewlines)

        let toiletFlagAt = unixSeconds(widgetState.toiletFlagAt)
        let bathFlagAt = unixSeconds(widgetState.bathFlagAt)
        let toiletNextSpawnAt = unixSeconds(widgetState.toiletNextSpawnAt)
        let bathNextSpawnAt = unixSeconds(widgetState.bathNextSpawnAt)

        let toiletFlagText = toiletFlagAt != nil ? String(toiletFlagAt!) : "nil"
        let bathFlagText = bathFlagAt != nil ? String(bathFlagAt!) : "nil"
        let toiletNextSpawnText = toiletNextSpawnAt != nil ? String(toiletNextSpawnAt!) : "nil"
        let bathNextSpawnText = bathNextSpawnAt != nil ? String(bathNextSpawnAt!) : "nil"

        let signatureParts: [String] = [
            String(widgetState.toiletFlag),
            String(widgetState.bathFlag),
            safePetID,
            String(safeSteps),
            safeLastDayKey,
            toiletFlagText,
            bathFlagText,
            toiletNextSpawnText,
            bathNextSpawnText
        ]
        let signature = signatureParts.joined(separator: "|")

        let previousSignature = defaults.string(forKey: lastSignatureKey)

        defaults.set(widgetState.toiletFlag, forKey: toiletFlagKey)
        defaults.set(widgetState.bathFlag, forKey: bathFlagKey)
        defaults.set(safePetID, forKey: currentPetIDKey)
        defaults.set(safeSteps, forKey: todayStepsKey)

        defaults.set(safeLastDayKey, forKey: lastDayKeyKey)
        write(toiletFlagAt, forKey: toiletFlagAtKey, defaults: defaults)
        write(bathFlagAt, forKey: bathFlagAtKey, defaults: defaults)
        write(toiletNextSpawnAt, forKey: toiletNextSpawnAtKey, defaults: defaults)
        write(bathNextSpawnAt, forKey: bathNextSpawnAtKey, defaults: defaults)

        defaults.set(signature, forKey: lastSignatureKey)
        defaults.synchronize()

        return previousSignature != signature
    }
}

private struct FullnessStomachGauge: View {
    let level: Double
    let displayLevel: Int
    let maxLevel: Int
    let outerSize: CGFloat
    let innerSize: CGFloat

    private var clampedLevel: Double {
        min(Double(maxLevel), max(0, level))
    }

    private var displayedClampedLevel: Int {
        min(maxLevel, max(0, displayLevel))
    }

    private var colorLevel: Int {
        min(maxLevel, max(0, Int(ceil(clampedLevel))))
    }

    private var fillFraction: CGFloat {
        guard maxLevel > 0 else { return 0 }
        return CGFloat(clampedLevel) / CGFloat(maxLevel)
    }


    private var liquidMainColor: Color {
        switch colorLevel {
        case 0: return Color(red: 0.18, green: 0.42, blue: 0.20).opacity(0.18)
        case 1: return Color(red: 0.15, green: 0.49, blue: 0.17)
        case 2: return Color(red: 0.13, green: 0.45, blue: 0.15)
        case 3: return Color(red: 0.11, green: 0.40, blue: 0.13)
        case 4: return Color(red: 0.10, green: 0.36, blue: 0.12)
        default: return Color(red: 0.09, green: 0.32, blue: 0.11)
        }
    }

    private var liquidDeepColor: Color {
        switch colorLevel {
        case 0: return Color(red: 0.08, green: 0.22, blue: 0.09).opacity(0.14)
        case 1: return Color(red: 0.07, green: 0.26, blue: 0.08)
        case 2: return Color(red: 0.06, green: 0.23, blue: 0.07)
        case 3: return Color(red: 0.05, green: 0.20, blue: 0.06)
        case 4: return Color(red: 0.04, green: 0.18, blue: 0.05)
        default: return Color(red: 0.03, green: 0.16, blue: 0.05)
        }
    }

    private var liquidHighlightColor: Color {
        Color(red: 0.42, green: 0.76, blue: 0.46)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase1 = CGFloat(t * 1.45)
            let phase2 = CGFloat(t * 1.05 + 1.1)
            let stomachWidth = innerSize * 0.88
            let stomachHeight = innerSize * 0.88
            let liquidDiameter = outerSize * 0.98

            ZStack {
                if fillFraction > 0.001 {
                    ZStack {
                        StomachLiquidWaveShape(
                            fillFraction: fillFraction,
                            phase: phase1,
                            amplitude: 4.8
                        )
                        .fill(
                            LinearGradient(
                                colors: [
                                    liquidHighlightColor.opacity(0.90),
                                    liquidMainColor.opacity(0.96),
                                    liquidDeepColor.opacity(0.94)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        StomachLiquidWaveShape(
                            fillFraction: max(0, fillFraction - 0.025),
                            phase: phase2,
                            amplitude: 7.0
                        )
                        .fill(Color.white.opacity(0.18))

                        Canvas { context, size in
                            let bubbleSpecs: [(CGFloat, CGFloat, CGFloat, Double)] = [
                                (0.32, 0.70, 3.2, 0.55),
                                (0.56, 0.61, 2.6, 0.75),
                                (0.68, 0.48, 4.0, 0.48),
                                (0.76, 0.66, 2.8, 0.68),
                                (0.43, 0.52, 2.4, 0.82),
                                (0.60, 0.77, 3.6, 0.60)
                            ]

                            let liquidTop = size.height * (1 - fillFraction)

                            for spec in bubbleSpecs {
                                let x = spec.0 * size.width + CGFloat(sin(t * spec.3 + Double(spec.0) * 7.0)) * 2.2
                                let verticalTravel = CGFloat((t * (18.0 * spec.3)).truncatingRemainder(dividingBy: 22))
                                let yBase = spec.1 * size.height
                                let y = max(liquidTop + 8, yBase - verticalTravel)
                                let r = spec.2

                                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                                context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.34)))
                                context.stroke(
                                    Path(ellipseIn: rect.insetBy(dx: 0.8, dy: 0.8)),
                                    with: .color(Color.white.opacity(0.52)),
                                    lineWidth: 0.7
                                )
                            }
                        }
                    }
                    .frame(width: liquidDiameter, height: liquidDiameter)
                    .clipShape(Circle())
                }

                ZStack {
                    Image("stomach")
                        .resizable()
                        .scaledToFit()
                        .frame(width: stomachWidth, height: stomachHeight)
                        .opacity(0.82)

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.white.opacity(0.10),
                            Color(red: 0.80, green: 0.88, blue: 0.86).opacity(0.14),
                            Color.white.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: stomachWidth, height: stomachHeight)
                    .blendMode(.screen)
                    .mask(
                        Image("stomach")
                            .resizable()
                            .scaledToFit()
                            .frame(width: stomachWidth, height: stomachHeight)
                    )

                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: innerSize * 0.52
                    )
                    .frame(width: stomachWidth, height: stomachHeight)
                    .blendMode(.screen)
                    .mask(
                        Image("stomach")
                            .resizable()
                            .scaledToFit()
                            .frame(width: stomachWidth, height: stomachHeight)
                    )

                    Capsule()
                        .fill(Color.white.opacity(0.82))
                        .frame(width: innerSize * 0.11, height: innerSize * 0.42)
                        .blur(radius: 1.1)
                        .rotationEffect(.degrees(11))
                        .offset(x: -innerSize * 0.08, y: -innerSize * 0.06)
                        .mask(
                            Image("stomach")
                                .resizable()
                                .scaledToFit()
                                .frame(width: stomachWidth, height: stomachHeight)
                        )

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.white.opacity(0.34))
                        .frame(width: innerSize * 0.42, height: innerSize * 0.14)
                        .blur(radius: 2.0)
                        .rotationEffect(.degrees(10))
                        .offset(x: innerSize * 0.10, y: -innerSize * 0.18)
                        .mask(
                            Image("stomach")
                                .resizable()
                                .scaledToFit()
                                .frame(width: stomachWidth, height: stomachHeight)
                        )

                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: innerSize * 0.52, height: innerSize * 0.07)
                        .blur(radius: 1.4)
                        .offset(x: 0, y: innerSize * 0.28)
                        .mask(
                            Image("stomach")
                                .resizable()
                                .scaledToFit()
                                .frame(width: stomachWidth, height: stomachHeight)
                        )
                }
                .frame(width: outerSize, height: outerSize)
                .drawingGroup()
            }
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 5)
        }
    }
}

private struct StomachLiquidWaveShape: Shape {
    var fillFraction: CGFloat
    var phase: CGFloat
    var amplitude: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(phase, fillFraction) }
        set {
            phase = newValue.first
            fillFraction = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let fraction = max(0, min(1, fillFraction))
        guard fraction > 0 else { return path }

        let width = rect.width
        let liquidBaseY = rect.maxY - rect.height * fraction

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: liquidBaseY))

        for x in stride(from: CGFloat.zero, through: width, by: 2) {
            let progress = x / width
            let wave = sin((progress * .pi * 2 * 1.15) + phase) * amplitude
            let y = liquidBaseY + wave
            path.addLine(to: CGPoint(x: rect.minX + x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

private struct ToiletPoopView: View {
    let item: AppState.ToiletPoopItem
    let size: CGFloat
    let hitSize: CGFloat
    let opacity: Double
    let isScratchEnabled: Bool
    let onScratchChanged: (DragGesture.Value) -> Void
    let onScratchEnded: () -> Void

    var body: some View {
        Image("poop")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(x: item.isFlippedHorizontally ? -1 : 1, y: 1)
            .rotationEffect(.degrees(item.rotationDegrees))
            .opacity(opacity)
            .animation(.easeOut(duration: 0.28), value: opacity)
            .frame(width: hitSize, height: hitSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged(onScratchChanged)
                    .onEnded { _ in
                        onScratchEnded()
                    }
            )
            .allowsHitTesting(isScratchEnabled)
    }
}

private struct FloatingThoughtButton: View {
    let imageName: String
    let size: CGFloat
    let amplitude: CGFloat
    let duration: Double
    let action: () -> Void

    @State private var startDate: Date = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let cycle = max(duration, 0.01)
            let phase = (elapsed / cycle) * (.pi * 2)
            let yOffset = CGFloat(sin(phase)) * amplitude

            Button(action: action) {
                ZStack {
                    Color.clear
                        .frame(width: size, height: size)

                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .offset(y: yOffset)
                }
                .frame(width: size, height: size)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            startDate = Date()
        }
    }
}

private struct TopStatusButtons: View {
    let onCoin: () -> Void
    let onShoes: () -> Void
    let onPresentBox: () -> Void
    let buttonSize: CGFloat
    let iconSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        VStack(spacing: spacing) {
            StatusIconButton(imageName: "coin", buttonSize: buttonSize, iconSize: iconSize, action: onCoin)
            StatusIconButton(imageName: "shoes", buttonSize: buttonSize, iconSize: iconSize, action: onShoes)
            StatusIconButton(imageName: "presentBox", buttonSize: buttonSize, iconSize: iconSize, action: onPresentBox)
        }
    }
}

private struct StatusIconButton: View {
    let imageName: String
    let buttonSize: CGFloat
    let iconSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(HomeView.Layout.bottomButtonBackgroundAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)

                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
            }
            .frame(width: buttonSize, height: buttonSize)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
    }
}


private struct HomeTopInfoPopup: View {
    let popup: HomeView.TopInfoPopup
    let walletCoinCount: Int
    let todayStepCount: Int
    let totalStepCount: Int
    let happinessLevel: Int
    let happinessPoint: Int
    let happinessMaxPoints: Int
    let claimableLevel: Int?
    let nextRewardLevel: Int?
    let rewardDefinitions: [AppState.HappinessRewardDefinition]
    let claimedRewardLevels: Set<Int>
    let onClose: () -> Void
    let onClaim: (Int) -> Void

    private var titleText: String {
        switch popup {
        case .wallet: return "所持コイン"
        case .todaySteps: return "今日の歩数"
        case .happinessRewards: return "幸せ報酬"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Text(titleText)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)

                Spacer(minLength: 0)

                Button(action: onClose) {
                    Image(HomeView.Layout.topInfoPopupCloseButtonAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: HomeView.Layout.topInfoPopupCloseButtonSize,
                            height: HomeView.Layout.topInfoPopupCloseButtonSize
                        )
                }
                .buttonStyle(.plain)
            }

            content
        }
        .padding(.horizontal, HomeView.Layout.topInfoPopupHorizontalPadding)
        .padding(.top, HomeView.Layout.topInfoPopupVerticalPadding)
        .padding(.bottom, HomeView.Layout.topInfoPopupVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(
            maxHeight: popup == .happinessRewards
            ? HomeView.Layout.topInfoPopupContentMaxHeight
            : nil,
            alignment: .top
        )
        .background {
            Image(HomeView.Layout.topInfoPopupBackgroundAssetName)
                .resizable()
                .scaledToFill()
        }
        .clipShape(RoundedRectangle(cornerRadius: HomeView.Layout.topInfoPopupCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 6)
    }

    @ViewBuilder
    private var content: some View {
        switch popup {
        case .wallet:
            VStack(alignment: .leading, spacing: 14) {
                HomeTopInfoValueBlock(
                    label: "現在の所持通貨",
                    valueText: "\(walletCoinCount)",
                    caption: "歩いたぶんだけコインとしてたまります"
                )
            }

        case .todaySteps:
            VStack(alignment: .leading, spacing: 14) {
                HomeTopInfoValueBlock(
                    label: "今日の歩数",
                    valueText: "\(todayStepCount)",
                    caption: "その日の歩数を確認できます"
                )

                HomeTopInfoValueBlock(
                    label: "総歩数",
                    valueText: "\(totalStepCount)",
                    caption: "このアプリ内で記録された累計歩数です"
                )
            }

        case .happinessRewards:
            HomeHappinessRewardsContent(
                happinessLevel: happinessLevel,
                happinessPoint: happinessPoint,
                happinessMaxPoints: happinessMaxPoints,
                claimableLevel: claimableLevel,
                nextRewardLevel: nextRewardLevel,
                rewardDefinitions: rewardDefinitions,
                claimedRewardLevels: claimedRewardLevels,
                onClaim: onClaim
            )
        }
    }
}

private struct HomeHappinessRewardsContent: View {
    let happinessLevel: Int
    let happinessPoint: Int
    let happinessMaxPoints: Int
    let claimableLevel: Int?
    let nextRewardLevel: Int?
    let rewardDefinitions: [AppState.HappinessRewardDefinition]
    let claimedRewardLevels: Set<Int>
    let onClaim: (Int) -> Void

    private let rewardRowHeight: CGFloat = 108
    private let rewardRowSpacing: CGFloat = 20

    private var descendingRewards: [AppState.HappinessRewardDefinition] {
        Array(rewardDefinitions.reversed())
    }

    private var currentProgressLevel: Double {
        let safeMaxPoints = max(happinessMaxPoints, 1)
        let fractionalLevel = Double(max(0, min(happinessPoint, safeMaxPoints - 1))) / Double(safeMaxPoints)
        let highestRewardLevel = rewardDefinitions.map(\.level).max() ?? 0
        return min(Double(highestRewardLevel), Double(max(0, happinessLevel)) + fractionalLevel)
    }

    private var summaryText: String {
        if let claimableLevel,
           let reward = rewardDefinitions.first(where: { $0.level == claimableLevel }) {
            return "Lv.\(claimableLevel) の \(reward.characterName) を受け取れます"
        }

        if let nextRewardLevel,
           let reward = rewardDefinitions.first(where: { $0.level == nextRewardLevel }) {
            let remaining = max(0, nextRewardLevel - happinessLevel)
            return "次は Lv.\(nextRewardLevel) の \(reward.characterName) まであと \(remaining) Lv"
        }

        return "現在の幸せ報酬はすべて受け取り済みです"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryCard

            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 18) {
                    HomeHappinessRewardsProgressColumn(
                        rewards: descendingRewards,
                        currentLevelProgress: currentProgressLevel,
                        rowHeight: rewardRowHeight,
                        spacing: rewardRowSpacing
                    )
                    .frame(
                        width: 32,
                        height: HomeHappinessRewardsProgressColumn.contentHeight(
                            rewardCount: descendingRewards.count,
                            rowHeight: rewardRowHeight,
                            spacing: rewardRowSpacing
                        )
                    )

                    LazyVStack(spacing: rewardRowSpacing) {
                        ForEach(descendingRewards) { reward in
                            HomeHappinessRewardRow(
                                reward: reward,
                                isClaimed: claimedRewardLevels.contains(reward.level),
                                canClaim: !claimedRewardLevels.contains(reward.level) && happinessLevel >= reward.level,
                                remainingLevels: max(0, reward.level - happinessLevel),
                                onClaim: {
                                    onClaim(reward.level)
                                }
                            )
                            .frame(height: rewardRowHeight)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("現在の幸せ度")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black.opacity(0.62))

            Text("Lv.\(happinessLevel)")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)

            Text("進捗 \(max(0, happinessPoint))/\(max(happinessMaxPoints, 0))")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black.opacity(0.72))

            Text(summaryText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.black.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct HomeHappinessRewardRow: View {
    let reward: AppState.HappinessRewardDefinition
    let isClaimed: Bool
    let canClaim: Bool
    let remainingLevels: Int
    let onClaim: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(reward.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text("Lv.\(reward.level)")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("キャラクター報酬")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))

                Text(reward.characterName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)

            trailingStatusView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var trailingStatusView: some View {
        if isClaimed {
            statusCapsule(
                title: "受取済み",
                foregroundColor: .white,
                backgroundColor: Color.white.opacity(0.14)
            )
        } else if canClaim {
            Button(action: onClaim) {
                statusCapsule(
                    title: "受け取る",
                    foregroundColor: .white,
                    backgroundColor: Color(red: 0.85, green: 0.20, blue: 0.28).opacity(0.95)
                )
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .trailing, spacing: 6) {
                Text("未達成")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.76))

                Text("あと\(remainingLevels)Lv")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.90))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func statusCapsule(
        title: String,
        foregroundColor: Color,
        backgroundColor: Color
    ) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(backgroundColor)
            )
    }
}

private struct HomeHappinessRewardsProgressColumn: View {
    let rewards: [AppState.HappinessRewardDefinition]
    let currentLevelProgress: Double
    let rowHeight: CGFloat
    let spacing: CGFloat

    private var maximumLevelValue: Int {
        max(rewards.map(\.level).max() ?? 0, 1)
    }

    var body: some View {
        GeometryReader { geo in
            let fullHeight = geo.size.height
            let fillHeight = resolvedFillHeight(fullHeight: fullHeight)

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 10)

                ForEach(1..<maximumLevelValue, id: \.self) { level in
                    Capsule()
                        .fill(level.isMultiple(of: 5) ? Color.white.opacity(0.46) : Color.white.opacity(0.26))
                        .frame(width: level.isMultiple(of: 5) ? 18 : 12, height: level.isMultiple(of: 5) ? 3 : 2)
                        .position(
                            x: geo.size.width * 0.5,
                            y: yPosition(forLevel: Double(level), fullHeight: fullHeight)
                        )
                }

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.21, green: 0.95, blue: 0.42),
                                Color(red: 0.91, green: 0.96, blue: 0.58)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 10, height: fillHeight)

                ForEach(Array(rewards.enumerated()), id: \.element.id) { index, reward in
                    Circle()
                        .fill(currentLevelProgress >= Double(reward.level) ? Color(red: 0.22, green: 0.95, blue: 0.42) : Color.white.opacity(0.78))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.18), lineWidth: 1)
                        )
                        .position(
                            x: geo.size.width * 0.5,
                            y: Self.nodeCenterY(index: index, rowHeight: rowHeight, spacing: spacing)
                        )
                }
            }
        }
    }

    static func contentHeight(rewardCount: Int, rowHeight: CGFloat, spacing: CGFloat) -> CGFloat {
        let rowsHeight = CGFloat(max(rewardCount, 0)) * rowHeight
        let spacingHeight = CGFloat(max(rewardCount - 1, 0)) * spacing
        return max(rowsHeight + spacingHeight, 1)
    }

    private static func nodeCenterY(index: Int, rowHeight: CGFloat, spacing: CGFloat) -> CGFloat {
        (rowHeight * 0.5) + (CGFloat(index) * (rowHeight + spacing))
    }

    private func resolvedFillHeight(fullHeight: CGFloat) -> CGFloat {
        let clampedProgress = max(0, min(currentLevelProgress, Double(maximumLevelValue)))
        let ascendingRewards = rewards.sorted(by: { $0.level < $1.level })

        let points: [(level: Double, height: CGFloat)] = [(0, 0)] + ascendingRewards.compactMap { reward in
            guard let descendingIndex = rewards.firstIndex(where: { $0.level == reward.level }) else { return nil }
            let centerY = Self.nodeCenterY(index: descendingIndex, rowHeight: rowHeight, spacing: spacing)
            return (Double(reward.level), max(0, fullHeight - centerY))
        }

        guard let last = points.last else { return 0 }

        if clampedProgress >= last.level {
            return min(fullHeight, last.height)
        }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]

            guard clampedProgress <= current.level else { continue }

            let span = max(current.level - previous.level, 0.0001)
            let ratio = (clampedProgress - previous.level) / span
            let interpolated = previous.height + CGFloat(ratio) * (current.height - previous.height)
            return max(0, min(fullHeight, interpolated))
        }

        return 0
    }

    private func yPosition(forLevel level: Double, fullHeight: CGFloat) -> CGFloat {
        let fillHeight = resolvedFillHeight(forLevel: level, fullHeight: fullHeight)
        return max(0, min(fullHeight, fullHeight - fillHeight))
    }

    private func resolvedFillHeight(forLevel level: Double, fullHeight: CGFloat) -> CGFloat {
        let proxy = HomeHappinessRewardsProgressColumn(
            rewards: rewards,
            currentLevelProgress: level,
            rowHeight: rowHeight,
            spacing: spacing
        )
        return proxy.resolvedFillHeight(fullHeight: fullHeight)
    }
}

private struct HomeTopInfoValueBlock: View {
    let label: String
    let valueText: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(valueText)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(.primary)

            Text(caption)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
private struct CenterMenuPopup: View {
    let isToiletLocked: Bool
    let onBlocked: () -> Void
    let onCamera: () -> Void
    let onDismiss: () -> Void
    let buttonSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(HomeView.Layout.menuPopupBackgroundAssetName)
                .resizable()
                .scaledToFit()

            RightSideButtons(
                onCamera: onCamera,
                isToiletLocked: isToiletLocked,
                onBlocked: onBlocked,
                buttonSize: buttonSize,
                spacing: spacing
            )
            .frame(width: HomeView.Layout.menuPopupGridWidth, alignment: .leading)
            .padding(.top, HomeView.Layout.menuPopupContentTopPadding)
            .padding(.bottom, HomeView.Layout.menuPopupContentBottomPadding)
            .offset(
                x: HomeView.Layout.menuPopupGridOffsetX,
                y: HomeView.Layout.menuPopupGridOffsetY
            )

            Button(action: onDismiss) {
                Image(HomeView.Layout.menuPopupCloseButtonAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: HomeView.Layout.menuPopupCloseButtonSize,
                        height: HomeView.Layout.menuPopupCloseButtonSize
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, HomeView.Layout.menuPopupCloseButtonTopPadding)
            .padding(.trailing, HomeView.Layout.menuPopupCloseButtonTrailingPadding)
        }
        .frame(maxWidth: HomeView.Layout.menuPopupMaxWidth)
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
    }
}

private struct RightSideButtons: View {
    @EnvironmentObject private var bgmManager: BGMManager

    let onCamera: () -> Void
    let isToiletLocked: Bool
    let onBlocked: () -> Void
    let buttonSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            HStack(spacing: spacing) {
                Button(action: {
                    bgmManager.playSE(.push)
                    onCamera()
                }) {
                    MenuPopupActionIcon(imageName: "camera_button", buttonSize: buttonSize)
                }
                .buttonStyle(.plain)

                if isToiletLocked {
                    Button(action: {
                        bgmManager.playSE(.push)
                        onBlocked()
                    }) {
                        MenuPopupActionIcon(imageName: "omoide_button", buttonSize: buttonSize)
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink { MemoriesView() } label: {
                        MenuPopupActionIcon(imageName: "omoide_button", buttonSize: buttonSize)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        bgmManager.playSE(.push)
                    })
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: spacing) {
                if isToiletLocked {
                    Button(action: {
                        bgmManager.playSE(.push)
                        onBlocked()
                    }) {
                        MenuPopupActionIcon(imageName: "picture_button", buttonSize: buttonSize)
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink { ZukanView() } label: {
                        MenuPopupActionIcon(imageName: "picture_button", buttonSize: buttonSize)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        bgmManager.playSE(.push)
                    })
                    .buttonStyle(.plain)
                }

                if isToiletLocked {
                    Button(action: {
                        bgmManager.playSE(.push)
                        onBlocked()
                    }) {
                        MenuPopupActionIcon(imageName: "option_button", buttonSize: buttonSize)
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink { SettingsView() } label: {
                        MenuPopupActionIcon(imageName: "option_button", buttonSize: buttonSize)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        bgmManager.playSE(.push)
                    })
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: HomeView.Layout.menuPopupGridWidth, alignment: .leading)
    }
}

private struct MenuPopupActionIcon: View {
    let imageName: String
    let buttonSize: CGFloat

    private var iconSize: CGFloat { buttonSize * 0.74 }

    var body: some View {
        ZStack {
            Image(HomeView.Layout.menuPopupButtonBackgroundAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: buttonSize, height: buttonSize)

            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
        }
        .frame(width: buttonSize, height: buttonSize)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
    }
}

private struct BottomButtons: View {
    @EnvironmentObject private var bgmManager: BGMManager

    let onMenu: () -> Void
    let onGatya: () -> Void
    let onWork: () -> Void
    let onStep: () -> Void

    let isToiletLocked: Bool
    let onBlocked: () -> Void

    let buttonSize: CGFloat
    let spacing: CGFloat
    let horizontalPadding: CGFloat

    var body: some View {
        HStack(spacing: spacing) {
            BottomActionButton(imageName: "menu_button", buttonSize: buttonSize) {
                bgmManager.playSE(.push)
                if isToiletLocked { onBlocked(); return }
                onMenu()
            }

            BottomActionButton(imageName: "gatya_button", buttonSize: buttonSize) {
                bgmManager.playSE(.push)
                if isToiletLocked { onBlocked(); return }
                onGatya()
            }

            BottomActionButton(imageName: "work_button", buttonSize: buttonSize) {
                bgmManager.playSE(.push)
                if isToiletLocked { onBlocked(); return }
                onWork()
            }

            BottomActionButton(imageName: "step_button", buttonSize: buttonSize) {
                bgmManager.playSE(.push)
                if isToiletLocked { onBlocked(); return }
                onStep()
            }
        }
        .padding(.horizontal, HomeView.Layout.bottomBarHorizontalPadding)
        .padding(.vertical, HomeView.Layout.bottomBarVerticalPadding)
        .padding(.horizontal, horizontalPadding)
    }
}

private struct BottomActionButton: View {
    let imageName: String
    let buttonSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(HomeView.Layout.bottomButtonBackgroundAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: HomeView.Layout.bottomButtonBackgroundSize,
                        height: HomeView.Layout.bottomButtonBackgroundSize
                    )

                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: HomeView.Layout.bottomButtonIconSize,
                        height: HomeView.Layout.bottomButtonIconSize
                    )
            }
            .frame(
                width: HomeView.Layout.bottomButtonBackgroundSize,
                height: HomeView.Layout.bottomButtonBackgroundSize
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: HomeView.Layout.bottomButtonCornerRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
    }
}


private struct ToiletTicketQuickButton: View {
    let imageName: String
    let countText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Image(HomeView.Layout.bottomButtonBackgroundAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: HomeView.Layout.bottomButtonBackgroundSize,
                        height: HomeView.Layout.bottomButtonBackgroundSize
                    )

                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)

                Text(countText)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.78), in: Capsule())
                    .offset(
                        x: HomeView.Layout.toiletTicketBadgeOffsetX,
                        y: HomeView.Layout.toiletTicketBadgeOffsetY
                    )
            }
            .frame(
                width: HomeView.Layout.bottomButtonBackgroundSize,
                height: HomeView.Layout.bottomButtonBackgroundSize
            )
            .contentShape(
                RoundedRectangle(
                    cornerRadius: HomeView.Layout.bottomButtonCornerRadius,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
    }
}

private struct FoodSelectionCarousel: View {
    let foods: [FoodCatalog.FoodItem]
    let countProvider: (String) -> Int
    let selectedFoodID: String?
    let selectedRarityTab: HomeView.FoodSelectorRarityTab
    let pendingFoodID: String?
    let dragOffset: CGSize
    let isFeedingAnimationRunning: Bool
    let onMoveSelection: (Int) -> Void
    let onFeed: () -> Void
    let onToggleRarity: () -> Void
    let onCardTap: (String) -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void

    private struct VisibleCard: Identifiable {
        let id: String
        let item: FoodCatalog.FoodItem
        let relativeIndex: Int
    }

    private var isPendingMode: Bool {
        pendingFoodID != nil
    }

    private var pendingFoodItem: FoodCatalog.FoodItem? {
        guard let pendingFoodID else { return nil }
        return foods.first(where: { $0.id == pendingFoodID })
    }

    private var pendingActionText: String? {
        guard isPendingMode else { return nil }

        if dragOffset.height <= -HomeView.Layout.foodSelectorPendingDecisionThreshold { return "あげる" }
        if dragOffset.height >= HomeView.Layout.foodSelectorPendingDecisionThreshold { return "やめる" }
        return nil
    }

    private var selectedIndex: Int {
        guard !foods.isEmpty else { return 0 }
        guard let selectedFoodID,
              let idx = foods.firstIndex(where: { $0.id == selectedFoodID }) else { return 0 }
        return idx
    }

    private var normalizedHorizontalProgress: Double {
        guard HomeView.Layout.foodSelectorRollStepWidth > 0 else { return 0 }
        let raw = dragOffset.width / HomeView.Layout.foodSelectorRollStepWidth
        let clamped = min(
            HomeView.Layout.foodSelectorRollMaxVisibleOffset,
            max(-HomeView.Layout.foodSelectorRollMaxVisibleOffset, Double(raw))
        )
        return clamped
    }

    private var focusedIndex: Int {
        guard !foods.isEmpty else { return 0 }
        let previewDelta = Int(round(-normalizedHorizontalProgress))
        return (selectedIndex + previewDelta).positiveModulo(foods.count)
    }

    private var visibleCards: [VisibleCard] {
        guard !foods.isEmpty else { return [] }

        let candidateOffsets = [0, 1, -1, 2, -2, 3, -3]
        var seenIndexes: Set<Int> = []
        var cards: [VisibleCard] = []

        for relative in candidateOffsets {
            let index = (selectedIndex + relative).positiveModulo(foods.count)
            guard seenIndexes.insert(index).inserted else { continue }
            cards.append(
                VisibleCard(
                    id: foods[index].id + "_\(relative)",
                    item: foods[index],
                    relativeIndex: relative
                )
            )
        }

        return cards
    }

    var body: some View {
        ZStack {
            Color.clear
                .frame(
                    width: HomeView.Layout.foodSelectorHitAreaWidth,
                    height: HomeView.Layout.foodSelectorHitAreaHeight
                )
                .contentShape(Rectangle())

            FoodRarityToggleButton(
                selectedTab: selectedRarityTab,
                action: onToggleRarity
            )
            .offset(
                x: HomeView.Layout.foodSelectorToggleOffsetX,
                y: HomeView.Layout.foodSelectorToggleOffsetY
            )
            .zIndex(40)

            if isPendingMode, let pendingFoodItem {
                PendingFoodSelectionCard(
                    item: pendingFoodItem,
                    countText: countText(for: pendingFoodItem.id),
                    dragOffset: dragOffset,
                    isFeedingAnimationRunning: isFeedingAnimationRunning
                )

                if let pendingActionText {
                    Text(pendingActionText)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.58), in: Capsule())
                        .offset(y: pendingActionText == "あげる" ? -138 : 138)
                        .transition(.opacity)
                }

                VStack(spacing: 6) {
                    Text(pendingFoodItem.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)

                    Text("上フリックであげる / 下フリックでキャンセル")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                }
                .offset(y: HomeView.Layout.foodSelectorInstructionOffsetY)
            } else if foods.isEmpty {
                FoodSelectionEmptyState(tab: selectedRarityTab)
                    .offset(y: 16)
            } else {
                ForEach(visibleCards.sorted(by: {
                    abs(Double($0.relativeIndex) + normalizedHorizontalProgress) >
                    abs(Double($1.relativeIndex) + normalizedHorizontalProgress)
                })) { card in
                    let relativePosition = Double(card.relativeIndex) + normalizedHorizontalProgress

                    FoodCarouselCard(
                        item: card.item,
                        countText: countText(for: card.item.id),
                        relativePosition: relativePosition,
                        dragOffset: dragOffset,
                        isFeedingAnimationRunning: isFeedingAnimationRunning,
                        isFocused: card.item.id == selectedFoodID,
                        isPendingFeed: false,
                        onTap: {
                            onCardTap(card.item.id)
                        }
                    )
                    .zIndex(zIndex(for: relativePosition))
                }

                VStack(spacing: 6) {
                    if let focused = foods[safe: focusedIndex] {
                        Text(focused.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)

                        Text("横スクロールで選ぶ / タップで仮決定 / 上フリックであげる / 下フリックでキャンセル")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .offset(y: HomeView.Layout.foodSelectorInstructionOffsetY)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged(onDragChanged)
                .onEnded(onDragEnded)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ごはんセレクター")
        .accessibilityHint("横スクロールでごはんを選び、タップで仮決定してから、上フリックであげるか下フリックでキャンセルします")
    }

    private func countText(for foodID: String) -> String {
        let count = max(1, countProvider(foodID))
        return "x\(count)"
    }

    private func zIndex(for relativePosition: Double) -> Double {
        10 - min(9, abs(relativePosition) * 2.4)
    }
}

private struct FoodRarityToggleButton: View {
    let selectedTab: HomeView.FoodSelectorRarityTab
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                FoodRarityTogglePill(tab: selectedTab, isActive: true)

                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.88))

                FoodRarityTogglePill(tab: selectedTab.next, isActive: false)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.42), in: Capsule())
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
        .accessibilityLabel("ご飯表示切り替え")
        .accessibilityHint("タップするたびにNとRを切り替えます")
    }
}

private struct FoodRarityTogglePill: View {
    let tab: HomeView.FoodSelectorRarityTab
    let isActive: Bool

    private var backgroundColor: Color {
        isActive ? tab.accentColor : Color.white.opacity(0.18)
    }

    var body: some View {
        Text(tab.rawValue)
            .font(.system(size: 12, weight: .black))
            .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.78))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(backgroundColor, in: Capsule())
    }
}

private struct FoodSelectionEmptyState: View {
    let tab: HomeView.FoodSelectorRarityTab

    var body: some View {
        VStack(spacing: 10) {
            Text(tab.emptyText)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            Text("切り替えボタンで別レアリティを表示できます")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.36), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct FoodRarityBackdropGlow: View {
    let tab: HomeView.FoodSelectorRarityTab
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: tab.glowColors,
                    center: .center,
                    startRadius: 4,
                    endRadius: size * 0.6
                )
            )
            .frame(width: size, height: size)
            .blur(radius: 8)
    }
}


private struct FoodCarouselCard: View {
    let item: FoodCatalog.FoodItem
    let countText: String
    let relativePosition: Double
    let dragOffset: CGSize
    let isFeedingAnimationRunning: Bool
    let isFocused: Bool
    let isPendingFeed: Bool
    let onTap: () -> Void

    private var rarityTab: HomeView.FoodSelectorRarityTab {
        item.isShopEligible ? .normal : .rare
    }

    private var clampedPosition: Double {
        min(
            HomeView.Layout.foodSelectorRollMaxVisibleOffset,
            max(-HomeView.Layout.foodSelectorRollMaxVisibleOffset, relativePosition)
        )
    }

    private var absPosition: Double {
        abs(clampedPosition)
    }

    private var config: (x: CGFloat, y: CGFloat, scale: CGFloat, opacity: Double, rotation: Double, blur: CGFloat) {
        let sign = clampedPosition == 0 ? 0 : (clampedPosition > 0 ? 1.0 : -1.0)
        let x = (clampedPosition * 88.0) - (sign * max(0, absPosition - 1.0) * 30.0)
        let y = 72.0 - (absPosition * 38.0) - (max(0, absPosition - 1.0) * 8.0)
        let scale = max(0.60, 1.06 - (absPosition * 0.18))
        let opacity = max(0.12, 1.0 - (absPosition * 0.28) - (max(0, absPosition - 1.0) * 0.10))
        let rotation = -clampedPosition * 28.0
        let blur = max(0, (absPosition - 1.2) * 1.0)

        return (
            x: CGFloat(x),
            y: CGFloat(y),
            scale: CGFloat(scale),
            opacity: opacity,
            rotation: rotation,
            blur: CGFloat(blur)
        )
    }

    private var dragY: CGFloat {
        guard absPosition < 0.75 else { return 0 }
        return min(0, dragOffset.height * 0.48)
    }

    private var feedLift: CGFloat {
        guard isFeedingAnimationRunning, absPosition < 0.75 else { return 0 }
        return -118
    }

    private var cardSize: CGSize {
        let side = max(92.0, 126.0 - (absPosition * 14.0) - (max(0, absPosition - 1.0) * 4.0))
        return CGSize(width: side, height: side)
    }

    private var focusShadowColor: Color {
        rarityTab.accentColor.opacity(isFocused && absPosition < 0.75 ? 0.28 : 0.0)
    }

    var body: some View {
        ZStack {
            Image("dish")
                .resizable()
                .scaledToFit()
                .frame(width: cardSize.width, height: cardSize.height)

            FoodRarityBackdropGlow(tab: rarityTab, size: cardSize.width * 0.72)

            Image(item.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: cardSize.width * 0.68, height: cardSize.height * 0.68)
                .padding(10)
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .overlay(alignment: .bottomTrailing) {
            Text(countText)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.72), in: Capsule())
                .offset(x: 10, y: 10)
        }
        .shadow(color: focusShadowColor, radius: 12, x: 0, y: 6)
        .scaleEffect(config.scale)
        .opacity(config.opacity)
        .blur(radius: config.blur)
        .rotation3DEffect(
            .degrees(config.rotation),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.65
        )
        .offset(x: config.x, y: config.y + dragY + feedLift)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.82), value: dragOffset)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isFeedingAnimationRunning)
    }
}

private struct PendingFoodSelectionCard: View {
    let item: FoodCatalog.FoodItem
    let countText: String
    let dragOffset: CGSize
    let isFeedingAnimationRunning: Bool

    @State private var startDate: Date = Date()

    private var rarityTab: HomeView.FoodSelectorRarityTab {
        item.isShopEligible ? .normal : .rare
    }

    private var dragFollowOffsetY: CGFloat {
        max(-92, min(92, dragOffset.height * 0.42))
    }

    private var feedLift: CGFloat {
        isFeedingAnimationRunning ? -126 : 0
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let cycle = max(HomeView.Layout.floatingBubbleDuration, 0.01)
            let phase = (elapsed / cycle) * (.pi * 2)
            let floatOffset = isFeedingAnimationRunning
                ? CGFloat.zero
                : CGFloat(sin(phase)) * HomeView.Layout.floatingBubbleAmplitude

            ZStack {
                Image("dish")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 188, height: 188)

                FoodRarityBackdropGlow(tab: rarityTab, size: 138)

                Image(item.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 126, height: 126)
            }
            .frame(width: 188, height: 188)
            .overlay(alignment: .bottomTrailing) {
                Text(countText)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.76), in: Capsule())
                    .offset(x: 10, y: 10)
            }
            .scaleEffect(isFeedingAnimationRunning ? 1.04 : 1.0)
            .offset(y: floatOffset + dragFollowOffsetY + feedLift)
        }
        .onAppear {
            startDate = Date()
        }
    }
}

private extension Int {
    func positiveModulo(_ n: Int) -> Int {
        guard n > 0 else { return self }
        let remainder = self % n
        return remainder >= 0 ? remainder : remainder + n
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}


private final class TouchTapSEPool: NSObject, AVAudioPlayerDelegate {
    private var activePlayers: [UUID: AVAudioPlayer] = [:]
    private var bundleAudioURLCache: [String: URL] = [:]
    private var dataAssetCache: [String: Data] = [:]

    func play() {
        do {
            try configureAudioSessionIfNeeded()

            let player = try makeAudioPlayer(named: "effect_touch")
            let id = UUID()

            player.delegate = self
            player.volume = 1.0
            player.numberOfLoops = 0
            player.prepareToPlay()

            activePlayers[id] = player
            player.play()
        } catch {
            print("❌ effect_touch の再生に失敗しました: \(error.localizedDescription)")
        }
    }

    func stopAll() {
        for player in activePlayers.values {
            player.stop()
        }
        activePlayers.removeAll()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.removePlayer(player)
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.removePlayer(player)
            if let error {
                print("❌ effect_touch デコードエラー: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func configureAudioSessionIfNeeded() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [])
        try session.setActive(true)
    }

    private func makeAudioPlayer(named name: String) throws -> AVAudioPlayer {
        if let url = findAudioFileURLInBundle(named: name) {
            return try AVAudioPlayer(contentsOf: url)
        }

        if let data = findAudioDataAsset(named: name) {
            return try AVAudioPlayer(data: data)
        }

        throw NSError(
            domain: "HomeView.TouchTapSEPool",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "音源が見つかりません: \(name)"]
        )
    }

    private func findAudioFileURLInBundle(named name: String) -> URL? {
        if let cached = bundleAudioURLCache[name] {
            return cached
        }

        let exts = ["m4a", "mp3", "wav", "aif", "aiff", "caf"]
        for ext in exts {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                bundleAudioURLCache[name] = url
                return url
            }
        }
        return nil
    }

    private func findAudioDataAsset(named name: String) -> Data? {
        if let cached = dataAssetCache[name] {
            return cached
        }

        if let data = NSDataAsset(name: name)?.data {
            dataAssetCache[name] = data
            return data
        }

        return nil
    }

    @MainActor
    private func removePlayer(_ target: AVAudioPlayer) {
        guard let id = activePlayers.first(where: { $0.value === target })?.key else {
            return
        }
        activePlayers.removeValue(forKey: id)
    }
}

private struct FloatingHeart: Identifiable, Equatable {
    let id = UUID()
    let xOffset: CGFloat
    let yOffset: CGFloat
    let size: CGFloat
}

private struct FloatingHeartView: View {
    let heart: FloatingHeart
    @State private var isAnimating = false

    var body: some View {
        Image("heart")
            .resizable()
            .scaledToFit()
            .frame(width: heart.size, height: heart.size)
            .shadow(color: .white.opacity(0.35), radius: 4)
            .offset(y: isAnimating ? -72 : -12)
            .opacity(isAnimating ? 0 : 1)
            .scaleEffect(isAnimating ? 1.18 : 0.74)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) {
                    isAnimating = true
                }
            }
    }
}
