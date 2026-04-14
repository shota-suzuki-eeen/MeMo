//
//  HomeView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import SwiftUI
import SwiftData
import UIKit
#if canImport(WidgetKit)
import WidgetKit
#endif

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var bgmManager: BGMManager

    let state: AppState
    @ObservedObject var hk: HealthKitManager

    @State private var todaySteps: Int = 0
    @State private var displayedTodaySteps: Int = 0
    @State private var displayedWalletSteps: Int = 0

    @State private var todayPhotoImage: UIImage?
    @State private var todayPhotoEntry: TodayPhotoEntry?

    @State private var showCaptureModeDialog: Bool = false
    @State private var selectedCaptureMode: CameraCaptureView.Mode?

    @State private var toastMessage: String?
    @State private var showToast: Bool = false

    @State private var displayedFriendship: Double = 0
    @State private var displayedStepProgress: Double = 0
    @State private var displayedFullnessLevel: Int = 0
    @State private var animatedFullnessLevel: Double = 0

    @State private var isAnimatingGain: Bool = false
    @State private var isHomeVisible: Bool = false

    @State private var showStepEnjoy: Bool = false
    @State private var showGachaView: Bool = false

    @State private var showWorkTimerPreparation: Bool = false
    @State private var showRightMenuPopup: Bool = false
    @State private var activeTopInfoPopup: TopInfoPopup?

    @State private var showFoodSelector: Bool = false
    @State private var selectedFoodID: String?
    @State private var foodSelectorDragOffset: CGSize = .zero
    @State private var isFoodFeedingAnimationRunning: Bool = false
    @State private var pendingFoodFeedID: String?
    @State private var isFoodSelectorHorizontalRattling: Bool = false
    @State private var foodSelectorDragAnchorFoodID: String?
    @State private var foodSelectorScrollSelectionDelta: Int = 0

    @State private var characterAssetName: String = ""
    @State private var idleLoopTask: Task<Void, Never>?
    @State private var isCharacterActionRunning: Bool = false

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

    private var fullnessMaxLevel: Int {
        5
    }

    private var currentBaseAssetName: String {
        PetMaster.assetName(for: state.normalizedCurrentPetID)
    }

    private var currentPetName: String {
        PetMaster.all.first(where: { $0.id == state.normalizedCurrentPetID })?.name ?? "ペット"
    }

    private var isToiletLocked: Bool {
        state.hasToiletFlag
    }

    private var hasFoodFlag: Bool {
        state.hasFoodFlag
    }

    private var fixedDailyGoalSteps: Int {
        AppState.fixedDailyStepGoal
    }

    private var widgetLinkedTodaySteps: Int {
        max(todaySteps, state.widgetTodaySteps)
    }

    private var ownedFoods: [FoodCatalog.FoodItem] {
        FoodCatalog.all.filter { state.foodCount(foodId: $0.id) > 0 }
    }

    private var selectedFood: FoodCatalog.FoodItem? {
        guard let selectedFoodID else { return ownedFoods.first }
        return ownedFoods.first(where: { $0.id == selectedFoodID }) ?? ownedFoods.first
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

    private var currentWalletCoinCount: Int {
        max(0, max(displayedWalletSteps, state.walletSteps))
    }

    private var currentTodayStepCount: Int {
        max(0, max(displayedTodaySteps, max(todaySteps, hk.todaySteps)))
    }

    private var currentHappinessLevelValue: Int {
        max(displayedHappinessLevel, state.happinessLevel)
    }

    private var currentHappinessPointValue: Int {
        min(happinessMaxPoints - 1, max(displayedHappinessPoint, state.happinessPoint))
    }

    private var nextHappinessRewardLevel: Int {
        if let claimableLevel = currentClaimableHappinessRewardLevel {
            return claimableLevel
        }

        let rewardStep = AppState.happinessRewardLevelStep
        let level = max(0, currentHappinessLevelValue)
        return max(rewardStep, ((level / rewardStep) + 1) * rewardStep)
    }

    private var canShowFoodBubble: Bool {
        currentFullnessLevel < fullnessMaxLevel
    }

    private var canShowWcAsset: Bool {
        [
            "person",
            "dog",
            "cat",
            "chicken",
            "monkey",
            "rabbit",
            "frog",
            "penguin",
            "sheep",
            "shark",
            "turtle",
            "dolphin",
            "Sloth",
            "baku",
            "blackGibbon",
            "bulldog",
            "deer",
            "fox",
            "frilledLizard",
            "giraffe",
            "koala",
            "okapi",
            "platypus",
            "raccoon",
            "Shoebill",
            "Triceratops",
            "bee",
            "amesho",
            "barinys",
            "blue",
            "shiba",
            "gorilla",
            "lizard",
            "meerkat",
            "otter",
            "owl",
            "parakeet",
            "peacock",
            "pig",
            "raccoonDog",
            "redPanda",
            "seal",
            "seaOtter",
            "skunk",
            "swallow",
            "tiger",
            "whiteTiger",
            "zebra",
            "wolf"
        ].contains(currentBaseAssetName)
    }

    private var canPlayBlinkAnimation: Bool {
        [
            "person",
            "dog",
            "cat",
            "chicken",
            "monkey",
            "rabbit",
            "frog",
            "penguin",
            "sheep",
            "shark",
            "turtle",
            "dolphin",
            "Sloth",
            "baku",
            "blackGibbon",
            "bulldog",
            "deer",
            "fox",
            "frilledLizard",
            "giraffe",
            "koala",
            "okapi",
            "platypus",
            "raccoon",
            "Shoebill",
            "Triceratops",
            "bee",
            "amesho",
            "barinys",
            "blue",
            "shiba",
            "gorilla",
            "lizard",
            "meerkat",
            "otter",
            "owl",
            "parakeet",
            "peacock",
            "pig",
            "raccoonDog",
            "redPanda",
            "seal",
            "seaOtter",
            "skunk",
            "swallow",
            "tiger",
            "whiteTiger",
            "zebra",
            "wolf"
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

        return (
            steps: steps,
            activeKcal: 0,
            totalKcal: steps
        )
    }

    fileprivate enum TopInfoPopup: Int, Identifiable {
        case wallet
        case todaySteps
        case happinessRewards

        var id: Int { rawValue }
    }

    fileprivate enum Layout {
        static let bannerHeight: CGFloat = 76
        static let bannerWidthIPhone: CGFloat = 320
        static let homeBackgroundAssetName: String = "Home_background"

        static let leftTopPaddingTop: CGFloat = 44
        static let leftTopPaddingLeading: CGFloat = 18
        static let meterStackSpacing: CGFloat = 18

        static let topStatusButtonsTop: CGFloat = 34
        static let topStatusButtonsLeading: CGFloat = 18
        static let topStatusButtonsSpacing: CGFloat = 10
        static let topStatusButtonSize: CGFloat = 56
        static let topStatusButtonIconSize: CGFloat = 42

        static let happinessGaugeTop: CGFloat = 32
        static let happinessGaugeLeading: CGFloat = 96
        static let happinessGaugeOuterSize: CGFloat = 135
        static let happinessGaugeInnerSize: CGFloat = 115
        static let happinessRewardButtonFont: CGFloat = 12

        static let iconHeartSize: CGFloat = 31
        static let iconCoinSize: CGFloat = 26
        static let capsuleHeight: CGFloat = 23

        static let barWidth: CGFloat = 125
        static let walletWidth: CGFloat = 125
        static let redMinWidth: CGFloat = 18

        static let friendshipTextFont: CGFloat = 11

        static let fullnessGaugeTop: CGFloat = 32
        static let fullnessGaugeTrailing: CGFloat = 18
        static let fullnessGaugeOuterSize: CGFloat = 135
        static let fullnessGaugeInnerSize: CGFloat = 115

        static let characterTopOffset: CGFloat = 45
        static let characterMaxHeight: CGFloat = 480
        static let characterTouchWidth: CGFloat = 240

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

        static let topInfoPopupCornerRadius: CGFloat = 24
        static let topInfoPopupHorizontalPadding: CGFloat = 28
        static let topInfoPopupVerticalPadding: CGFloat = 24
        static let topInfoPopupMaxWidth: CGFloat = 320
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
        static let zFloatingButtons: Double = 240
        static let zFoodSelector: Double = 245

        static let foodSelectorBottomGapFromButtons: CGFloat = 146
        static let foodSelectorHitAreaWidth: CGFloat = 320
        static let foodSelectorHitAreaHeight: CGFloat = 220
        static let foodSelectorInstructionOffsetY: CGFloat = 150
        static let foodSelectorRollStepWidth: CGFloat = 96
        static let foodSelectorRollMaxVisibleOffset: Double = 3.0
        static let foodSelectorPendingDecisionThreshold: CGFloat = 44

        static let fullnessLabelOffsetY: CGFloat = 44
        static let fullnessValueFont: CGFloat = 14
        static let fullnessCaptionFont: CGFloat = 10

        static let zCharacter: Double = 50
        static let zBottomButtons: Double = 260
        static let zToiletTicketButton: Double = 270
        static let zToiletPoops: Double = 2000
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
        NavigationStack {
            ZStack {
                Image(Layout.homeBackgroundAssetName)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Color.clear
                        .frame(width: Layout.bannerWidthIPhone, height: Layout.bannerHeight)
                        .frame(maxWidth: .infinity)
                        .frame(height: Layout.bannerHeight)

                    GeometryReader { geo in
                        let characterDisplayHeight = min(geo.size.width * 0.9, Layout.characterMaxHeight)
                        let characterTouchWidth = min(geo.size.width * 0.72, Layout.characterTouchWidth)

                        ZStack {
                            TopStatusButtons(
                                onCoin: { openTopInfoPopup(.wallet) },
                                onShoes: { openTopInfoPopup(.todaySteps) },
                                onPresentBox: { openTopInfoPopup(.happinessRewards) },
                                buttonSize: Layout.topStatusButtonSize,
                                iconSize: Layout.topStatusButtonIconSize,
                                spacing: Layout.topStatusButtonsSpacing
                            )
                            .padding(.top, Layout.topStatusButtonsTop)
                            .padding(.leading, Layout.topStatusButtonsLeading)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .zIndex(Layout.zBanner + 1)

                            Rectangle()
                                .fill(Color.black.opacity(0.001))
                                .frame(width: characterTouchWidth, height: characterDisplayHeight * 1.15)
                                .offset(y: Layout.characterTopOffset)
                                .zIndex(Layout.zCharacter)
                                .highPriorityGesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            handleCharacterPettingChanged(value)
                                        }
                                        .onEnded { value in
                                            handleCharacterPettingEnded(value)
                                        }
                                )

                            Image(characterAssetName.isEmpty ? preferredCharacterRestAssetName : characterAssetName)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: characterDisplayHeight)
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
                                .allowsHitTesting(false)

                            ForEach(floatingHearts) { heart in
                                FloatingHeartView(heart: heart)
                                    .offset(x: heart.xOffset, y: Layout.characterTopOffset - 14)
                                    .zIndex(Layout.zCharacter + 1)
                                    .allowsHitTesting(false)
                            }

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

                            FullnessStomachGauge(
                                level: animatedFullnessLevel,
                                displayLevel: displayedFullnessLevel,
                                maxLevel: fullnessMaxLevel,
                                outerSize: Layout.fullnessGaugeOuterSize,
                                innerSize: Layout.fullnessGaugeInnerSize
                            )
                            .padding(.top, Layout.fullnessGaugeTop)
                            .padding(.trailing, Layout.fullnessGaugeTrailing)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

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
                                .zIndex(Layout.zFloatingButtons)
                            }

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
                                .padding(.top, Layout.wcBubbleTop)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                .zIndex(Layout.zFloatingButtons)
                            }

                            if state.hasToiletFlag {
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
                                        .position(position(for: poop, in: geo.size))
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .allowsHitTesting(state.hasToiletFlag && !isToiletTicketCleaning)
                                .zIndex(Layout.zToiletPoops)
                            }

                            if showFoodSelector {
                                Color.black.opacity(0.001)
                                    .ignoresSafeArea()
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        closeFoodSelector()
                                    }
                                    .zIndex(Layout.zFoodSelector)

                                FoodSelectionCarousel(
                                    foods: ownedFoods,
                                    countProvider: { foodID in
                                        state.foodCount(foodId: foodID)
                                    },
                                    selectedFoodID: selectedFoodID,
                                    pendingFoodID: pendingFoodFeedID,
                                    dragOffset: foodSelectorDragOffset,
                                    isFeedingAnimationRunning: isFoodFeedingAnimationRunning,
                                    onMoveSelection: { delta in
                                        moveFoodSelection(delta)
                                    },
                                    onFeed: {
                                        feedSelectedFood(state: state)
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

                            if let activeTopInfoPopup {
                                Color.black.opacity(0.28)
                                    .ignoresSafeArea()
                                    .transition(.opacity)
                                    .zIndex(Layout.zTopInfoPopup)
                                    .onTapGesture {
                                        closeTopInfoPopup(playSound: false)
                                    }

                                HomeTopInfoPopup(
                                    popup: activeTopInfoPopup,
                                    walletCoinCount: currentWalletCoinCount,
                                    todayStepCount: currentTodayStepCount,
                                    happinessLevel: currentHappinessLevelValue,
                                    happinessPoint: currentHappinessPointValue,
                                    happinessMaxPoints: happinessMaxPoints,
                                    claimableLevel: currentClaimableHappinessRewardLevel,
                                    nextRewardLevel: nextHappinessRewardLevel,
                                    onClose: {
                                        closeTopInfoPopup()
                                    },
                                    onClaim: {
                                        claimCurrentHappinessRewardFromPopup()
                                    }
                                )
                                .frame(maxWidth: Layout.topInfoPopupMaxWidth)
                                .padding(.horizontal, Layout.topInfoPopupHorizontalPadding)
                                .zIndex(Layout.zTopInfoPopup + 1)
                                .transition(.scale(scale: 0.92).combined(with: .opacity))
                            }

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
                        .overlay(alignment: .bottom) {
                            if showToast, let toastMessage {
                                ToastView(message: toastMessage)
                                    .padding(.bottom, 18)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                }

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
            .overlay(alignment: .bottom) {
                TimelineView(.periodic(from: Date(), by: Layout.careSpawnCheckInterval)) { timeline in
                    let now = timeline.date

                    BottomButtons(
                        onMenu: {
                            bgmManager.playSE(.open)
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showRightMenuPopup = true
                            }
                        },
                        onGatya: {
                            bgmManager.playSE(.push)
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
                        state.ensureDailyResetIfNeeded(now: newDate)
                        syncDisplayedFullness(now: newDate)
                        scheduleHappinessDecayIfNeeded(now: newDate)

                        state.ensureToiletNextSpawnScheduled(now: newDate)
                        state.ensureFoodNextSpawnScheduled(now: newDate)

                        maybeSpawnToiletFlag(state: state, now: newDate)
                        maybeSpawnFoodFlag(state: state, now: newDate)
                        syncToiletPoopsIfNeeded(containerSize: homeContentSize, now: newDate)

                        save()
                    }
                    .onAppear {
                        state.ensureDailyResetIfNeeded(now: now)
                        syncDisplayedFullness(now: now)
                        scheduleHappinessDecayIfNeeded(now: now)

                        state.ensureToiletNextSpawnScheduled(now: now)
                        state.ensureFoodNextSpawnScheduled(now: now)

                        maybeSpawnToiletFlag(state: state, now: now)
                        maybeSpawnFoodFlag(state: state, now: now)
                        syncToiletPoopsIfNeeded(containerSize: homeContentSize, now: now)

                        save()
                    }
                }
                .padding(.bottom, Layout.bottomPadding)
                .zIndex(Layout.zBottomButtons)
            }
            .overlay(alignment: .bottomTrailing) {
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
                    .zIndex(Layout.zToiletTicketButton)
                }
            }
            .overlay(alignment: .top) {
                Color.clear
                    .frame(width: Layout.bannerWidthIPhone, height: Layout.bannerHeight)
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.bannerHeight)
                    .zIndex(Layout.zBanner)
            }
            .navigationBarHidden(true)
        }
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
                plainBackgroundAssetName: Layout.homeBackgroundAssetName,
                characterAssetName: PetMaster.assetName(for: state.normalizedCurrentPetID),
                metricValueProvider: {
                    let values = captureMetricValues
                    return (
                        steps: values.steps,
                        activeKcal: values.activeKcal,
                        totalKcal: values.totalKcal
                    )
                }
            ) {
                selectedCaptureMode = nil
            } onCapture: { image in
                saveTodayPhoto(image, placeName: nil, latitude: nil, longitude: nil)
                selectedCaptureMode = nil
            } onCaptureWithPlace: { image, placeName, lat, lon in
                saveTodayPhoto(image, placeName: placeName, latitude: lat, longitude: lon)
                selectedCaptureMode = nil
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
                StepView(state: state, hk: hk, onSave: save)
            }
        }
        .task {
            state.ensureInitialPetsIfNeeded()
            let didNormalizeGoal = state.normalizeFixedDailyStepGoal()

            syncCharacterBaseFromState(force: true)

            todaySteps = state.widgetTodaySteps
            displayedTodaySteps = todaySteps
            displayedWalletSteps = state.walletSteps
            displayedFriendship = Double(state.friendshipPoint)
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

            maybeSpawnToiletFlag(state: state)
            maybeSpawnFoodFlag(state: state)

            syncToiletPoopsIfNeeded(containerSize: homeContentSize)
            loadTodayPhoto()
            syncFoodSelectorSelection()
            syncDisplayedFullness()
            scheduleHappinessDecayIfNeeded(now: Date())

            updateToiletWiggle()
            syncCharacterBaseFromState(force: true)
            updateWidgetSnapshot(forceReload: true)

            if didNormalizeGoal {
                save()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
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

            Task {
                await runSync(state: state)

                state.ensureToiletNextSpawnScheduled(now: Date())
                state.ensureFoodNextSpawnScheduled(now: Date())

                maybeSpawnToiletFlag(state: state)
                maybeSpawnFoodFlag(state: state)

                syncToiletPoopsIfNeeded(containerSize: homeContentSize)
                loadTodayPhoto()
                syncFoodSelectorSelection()
                syncDisplayedFullness()
                scheduleHappinessDecayIfNeeded(now: Date())

                if isHomeVisible {
                    await reconcileWalletDisplayIfNeeded(state: state)
                }

                updateToiletWiggle()
                syncCharacterBaseFromState(force: true)
                updateWidgetSnapshot(forceReload: true)
            }
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

            stopCharacterIdleLoop()
            isCharacterActionRunning = false
            characterAssetName = preferredCharacterRestAssetName
            activeTopInfoPopup = nil
            showFoodSelector = false
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
        }
        .onChange(of: state.walletKcal) { _, _ in
            guard isHomeVisible else { return }
            Task { await reconcileWalletDisplayIfNeeded(state: state) }
            updateWidgetSnapshot()
        }
        .onChange(of: state.dailyGoalKcal) { _, _ in
            let didNormalize = state.normalizeFixedDailyStepGoal()
            if didNormalize {
                save()
            }
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

    private func scheduleHappinessDecayIfNeeded(now: Date = Date()) {
        let fullness = state.currentSatisfaction(now: now)
        state.refreshHappinessDecayTracking(fullnessLevel: fullness, now: now)

        guard fullness == 0 else {
            syncDisplayedHappiness(animated: false)
            return
        }

        let pending = state.pendingHappinessDecayCount(fullnessLevel: fullness, now: now)
        guard pending > 0 else {
            syncDisplayedHappiness(animated: false)
            return
        }

        guard !isAnimatingHappinessDecay else { return }
        Task { await animatePendingHappinessDecay(units: pending) }
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
            guard state.consumeOneHappinessDecayStep() else { break }
            syncDisplayedHappiness(animated: true)
            try? await Task.sleep(nanoseconds: 55_000_000)
        }
        isAnimatingHappinessDecay = false
        syncDisplayedHappiness(animated: false)
    }

    private func spawnFloatingHeart() {
        let heart = FloatingHeart(
            xOffset: CGFloat.random(in: -28...28),
            size: CGFloat.random(in: 22...40)
        )
        floatingHearts.append(heart)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            floatingHearts.removeAll { $0.id == heart.id }
        }
    }

    private func registerCharacterPettingTouch(count: Int = 1) {
        guard count > 0 else { return }
        let result = state.registerHappinessPettingTouch(count: count, now: Date())

        for _ in 0..<count {
            spawnFloatingHeart()
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

    private func handleCharacterPettingChanged(_ value: DragGesture.Value) {
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
            registerCharacterPettingTouch()
        }
    }

    private func handleCharacterPettingEnded(_ value: DragGesture.Value) {
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
            registerCharacterPettingTouch()
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

    private func claimCurrentHappinessRewardFromPopup() {
        guard let claimableLevel = currentClaimableHappinessRewardLevel else {
            toast("受け取れる報酬はありません")
            return
        }

        bgmManager.playSE(.push)
        claimHappinessReward(level: claimableLevel)
    }

    private func claimHappinessReward(level: Int) {
        guard let reward = state.claimHappinessReward(level: level, now: Date()) else {
            toast("受け取れる報酬はありません")
            return
        }

        save()
        toast("幸せLv.\(reward.level)報酬で\(reward.foodName)を獲得！")
        syncDisplayedHappiness(animated: false)
    }

    private func normalizedFullnessLevel(_ value: Int) -> Int {
        min(fullnessMaxLevel, max(0, value))
    }

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

    private func syncToiletPoopsIfNeeded(containerSize: CGSize, now: Date = Date()) {
        guard containerSize.width > 1, containerSize.height > 1 else { return }

        if !state.hasToiletFlag {
            toiletPoopActivePoint.removeAll()
            toiletTicketClearingPoopIDs.removeAll()
            isToiletTicketCleaning = false

            if !state.toiletPoops().isEmpty {
                state.clearToiletPoops()
                save()
            }
            return
        }

        let didChange = state.updateToiletPoopsByTime(now: now)

        if didChange {
            save()
        }
    }

    private func position(for poop: AppState.ToiletPoopItem, in containerSize: CGSize) -> CGPoint {
        CGPoint(
            x: max(0, min(containerSize.width, CGFloat(poop.centerXRatio) * containerSize.width)),
            y: max(0, min(containerSize.height, CGFloat(poop.centerYRatio) * containerSize.height))
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

    private func completeToiletPoopIfNeeded(id: String) {
        guard state.markToiletPoopCleared(id: id) else { return }

        toiletPoopActivePoint.removeValue(forKey: id)

        Task { @MainActor in
            Haptics.tap(style: .soft)
        }

        save()

        if !state.hasRemainingToiletPoops {
            toiletPoopActivePoint.removeAll()
            resolveToilet(state: state)
        }
    }

    private func syncFoodSelectorSelection() {
        let foods = ownedFoods

        guard !foods.isEmpty else {
            selectedFoodID = nil
            pendingFoodFeedID = nil
            showFoodSelector = false
            resetFoodSelectorDragState()
            isFoodFeedingAnimationRunning = false
            return
        }

        if let pendingFoodFeedID,
           !foods.contains(where: { $0.id == pendingFoodFeedID }) {
            self.pendingFoodFeedID = nil
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
        foodSelectorScrollSelectionDelta = 0
    }

    private func closeFoodSelector() {
        resetFoodSelectorDragState()
        isFoodFeedingAnimationRunning = false
        pendingFoodFeedID = nil
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
            toast(feedState.reason ?? "もう満腹みたい")
            return
        }

        syncFoodSelectorSelection()

        guard !ownedFoods.isEmpty else { return }

        resetFoodSelectorDragState()
        isFoodFeedingAnimationRunning = false
        pendingFoodFeedID = nil
        stopFoodSelectorHorizontalRattleIfNeeded()

        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            showFoodSelector = true
        }
    }

    private func moveFoodSelection(_ delta: Int) {
        let foods = ownedFoods
        guard foods.count >= 2 else { return }
        guard delta != 0 else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                foodSelectorDragOffset = .zero
            }
            return
        }

        syncFoodSelectorSelection()
        guard let currentID = selectedFoodID,
              let currentIndex = foods.firstIndex(where: { $0.id == currentID }) else {
            selectedFoodID = foods.first?.id
            pendingFoodFeedID = nil
            return
        }

        let direction = delta > 0 ? 1 : -1
        let nextIndex = (currentIndex + direction).positiveModulo(foods.count)
        let nextFoodID = foods[nextIndex].id

        guard nextFoodID != currentID else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                foodSelectorDragOffset = .zero
            }
            return
        }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            selectedFoodID = nextFoodID
            foodSelectorDragOffset = .zero
        }

        pendingFoodFeedID = nil

        Task { @MainActor in
            Haptics.tap(style: .soft)
        }
    }

    private func updateFoodSelectionWhileDragging(_ value: DragGesture.Value) {
        let foods = ownedFoods
        guard !foods.isEmpty else {
            resetFoodSelectorDragState()
            return
        }

        if foodSelectorDragAnchorFoodID == nil {
            syncFoodSelectorSelection()
            foodSelectorDragAnchorFoodID = selectedFoodID ?? foods.first?.id
            foodSelectorScrollSelectionDelta = 0
        }

        guard let anchorFoodID = foodSelectorDragAnchorFoodID,
              let anchorIndex = foods.firstIndex(where: { $0.id == anchorFoodID }) else {
            foodSelectorDragAnchorFoodID = selectedFoodID ?? foods.first?.id
            foodSelectorScrollSelectionDelta = 0
            foodSelectorDragOffset = value.translation
            return
        }

        guard foods.count >= 2 else {
            foodSelectorDragOffset = CGSize(width: 0, height: value.translation.height)
            return
        }

        let stepWidth = max(Layout.foodSelectorRollStepWidth, 1)
        let steppedDelta = Int(round((-value.translation.width) / stepWidth))

        if steppedDelta != foodSelectorScrollSelectionDelta {
            let nextIndex = (anchorIndex + steppedDelta).positiveModulo(foods.count)
            let nextFoodID = foods[nextIndex].id

            if nextFoodID != selectedFoodID {
                withAnimation(.spring(response: 0.18, dampingFraction: 0.92)) {
                    selectedFoodID = nextFoodID
                }

                Task { @MainActor in
                    Haptics.tap(style: .soft)
                }
            }

            foodSelectorScrollSelectionDelta = steppedDelta
        }

        let residualX = value.translation.width + (CGFloat(foodSelectorScrollSelectionDelta) * stepWidth)
        foodSelectorDragOffset = CGSize(width: residualX, height: value.translation.height)
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
            foodSelectorScrollSelectionDelta = 0

            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                foodSelectorDragOffset = .zero
            }
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

        let selectionThreshold = Layout.foodSelectorRollStepWidth * 0.42
        let didContinuouslyScroll = abs(horizontal) >= selectionThreshold

        if !didContinuouslyScroll {
            if predictedHorizontal <= -selectionThreshold {
                moveFoodSelection(1)
                return
            }

            if predictedHorizontal >= selectionThreshold {
                moveFoodSelection(-1)
                return
            }
        }
    }

    private func startFoodSelectorHorizontalRattleIfNeeded() {
        guard !isFoodSelectorHorizontalRattling else { return }
        isFoodSelectorHorizontalRattling = true
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
            toast(feedState.reason ?? "もう満腹みたい")
            closeFoodSelector()
            return
        }

        guard let selectedFood else {
            toast("ご飯を持っていません")
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
            toast(feedState.reason ?? "もう満腹みたい")
            closeFoodSelector()
            return
        }

        guard ownedFoods.contains(where: { $0.id == foodID }) else {
            toast("ご飯が見つかりません")
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
            toast("ご飯を持っていません")
            Task { @MainActor in
                Haptics.rattle(duration: 0.12, style: .light)
            }
            closeFoodSelector()
            return
        }

        let feedState = state.canFeedNow(now: Date())
        guard feedState.can else {
            pendingFoodFeedID = nil
            toast(feedState.reason ?? "もう満腹みたい")
            closeFoodSelector()
            return
        }

        pendingFoodFeedID = selectedFood.id
        isFoodFeedingAnimationRunning = true
        foodSelectorDragAnchorFoodID = nil
        foodSelectorScrollSelectionDelta = 0

        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
            foodSelectorDragOffset = CGSize(width: 0, height: -120)
        }

        Task { @MainActor in
            Haptics.tap(style: .medium)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            let didFeed = resolveFood(foodId: selectedFood.id, state: state)
            isFoodFeedingAnimationRunning = false
            foodSelectorDragOffset = .zero

            if didFeed {
                syncFoodSelectorSelection()
                closeFoodSelector()
            } else {
                pendingFoodFeedID = nil
            }
        }
    }

    private func showToiletLockedMessage() {
        toiletLockedPopupText = "\(currentPetName)は今それどころじゃない！"
        withAnimation(.easeOut(duration: 0.12)) {
            showToiletLockedPopup = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.lockedPopupShowSeconds) {
            withAnimation(.easeInOut(duration: 0.18)) {
                showToiletLockedPopup = false
            }
        }

        Task { @MainActor in
            Haptics.rattle(duration: 0.10, style: .light)
        }
    }

    private func updateToiletWiggle() {
        if isToiletLocked {
            isToiletWiggleOn = false
            DispatchQueue.main.async {
                isToiletWiggleOn = true
            }
        } else {
            isToiletWiggleOn = false
        }
    }

    private func syncCharacterBaseFromState(force: Bool) {
        if !force {
            guard !isCharacterActionRunning else { return }
        }
        characterAssetName = preferredCharacterRestAssetName
    }

    private func maybeSpawnToiletFlag(state: AppState, now: Date = Date()) {
        let didRaise = state.raiseToiletFlag(now: now)
        if didRaise {
            save()
            syncToiletPoopsIfNeeded(containerSize: homeContentSize, now: now)
            toast("トイレ行きたい！")
            syncCharacterBaseFromState(force: true)
            updateToiletWiggle()
        }
    }

    private func maybeSpawnFoodFlag(state: AppState, now: Date = Date()) {
        syncDisplayedFullness(now: now)

        let feedState = state.canFeedNow(now: now)
        guard feedState.can else {
            if state.hasFoodFlag {
                _ = state.resolveFood(now: now)
                save()
            }
            return
        }

        let didRaise = state.raiseFoodFlagIfNeeded(now: now)
        if didRaise {
            save()
            toast("おなかすいた！")
        }
    }

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

    private func stopCharacterIdleLoop() {
        idleLoopTask?.cancel()
        idleLoopTask = nil
    }

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

    private func isSuperFavoriteFood(foodId: String, petID: String) -> Bool {
        switch petID {
        case "pet_001": return foodId == "ra-men"
        case "pet_002": return foodId == "icecream"
        case "pet_003": return foodId == "barger"
        case "pet_004": return foodId == "coke"
        case "pet_005": return foodId == "yo-guruto"
        case "pet_006": return foodId == "sarad"
        case "pet_007": return foodId == "coffee"
        case "pet_000": return foodId == "onigiri"
        case "pet_008": return foodId == "nabe"
        case "pet_009": return foodId == "sute-ki"
        case "pet_010": return foodId == "pizza"
        default:
            return false
        }
    }

    private func playSuperFavoriteReactionIfPossible() {
        guard !isToiletLocked else { return }

        let base = currentBaseAssetName
        let love = "\(base)_love"

        guard !isCharacterActionRunning else { return }

        Task { @MainActor in
            isCharacterActionRunning = true
            characterAssetName = love
        }

        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)

            await MainActor.run {
                characterAssetName = preferredCharacterRestAssetName
                isCharacterActionRunning = false
            }
        }
    }

    private func playFeedSound(isSuperFavorite: Bool) {
        bgmManager.playSE(.eat)

        guard isSuperFavorite else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            bgmManager.playSE(.love)
        }
    }

    @discardableResult
    private func resolveFood(foodId: String, state: AppState) -> Bool {
        guard !isToiletLocked else {
            showToiletLockedMessage()
            return false
        }

        guard let food = FoodCatalog.byId(foodId) else {
            toast("ご飯が見つかりません")
            return false
        }

        let now = Date()
        let feedState = state.canFeedNow(now: now)
        guard feedState.can else {
            toast(feedState.reason ?? "今はごはんの時間じゃないよ")
            syncDisplayedFullness(now: now)
            syncFoodSelectorSelection()
            return false
        }

        guard state.foodCount(foodId: foodId) > 0 else {
            toast("そのご飯は持っていません")
            Task { @MainActor in
                Haptics.rattle(duration: 0.12, style: .light)
            }
            syncFoodSelectorSelection()
            return false
        }

        guard state.consumeFood(foodId: foodId, count: 1) else {
            toast("ご飯の消費に失敗しました")
            return false
        }

        let feedResult = state.feedOnce(now: now)
        guard feedResult.didFeed else {
            toast(feedResult.reason ?? "今はごはんをあげられません")
            syncDisplayedFullness(now: now)
            syncFoodSelectorSelection()
            return false
        }

        _ = state.resolveFood(now: now)

        let isSuperFavorite = isSuperFavoriteFood(foodId: food.id, petID: state.normalizedCurrentPetID)
        let gainedPoint = isSuperFavorite ? 20 : 10

        if isSuperFavorite {
            _ = state.revealSuperFavorite(petID: state.normalizedCurrentPetID)
        }

        let happinessBonus = state.happinessBonusPoints(forFoodID: food.id)
        if happinessBonus > 0 {
            _ = state.addHappinessPoints(happinessBonus, now: now)
        }

        save()
        syncDisplayedFullness(now: now)
        syncDisplayedHappiness(animated: happinessBonus > 0)

        addFriendshipWithAnimation(points: gainedPoint, state: state)
        playFeedSound(isSuperFavorite: isSuperFavorite)

        let happinessSuffix = happinessBonus > 0 ? " / 幸せ度 +\(happinessBonus)" : ""
        if isSuperFavorite {
            toast("\(food.name)をあげた！ 満腹度 \(normalizedFullnessLevel(feedResult.after))/\(fullnessMaxLevel) +\(gainedPoint)\(happinessSuffix)")
            playSuperFavoriteReactionIfPossible()
        } else {
            toast("\(food.name)をあげた！ 満腹度 \(normalizedFullnessLevel(feedResult.after))/\(fullnessMaxLevel) +\(gainedPoint)\(happinessSuffix)")
        }

        syncFoodSelectorSelection()
        updateWidgetSnapshot(forceReload: true)
        return true
    }

    private func calcStepProgressRaw(todaySteps: Int, goalSteps: Int) -> Double {
        guard goalSteps > 0 else { return 0 }
        return Double(todaySteps) / Double(goalSteps)
    }

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

    private func addFriendshipWithAnimation(points: Int, state: AppState) {
        guard points > 0 else { return }

        let maxMeter = AppState.friendshipMaxMeter
        let beforeDisplayed = displayedFriendship

        let result = state.addFriendship(points: points, maxMeter: maxMeter)

        save()

        let after = result.afterPoint

        Task { @MainActor in
            Haptics.rattle(duration: 0.50, style: .medium)
        }

        if result.didWrap {
            withAnimation(.easeOut(duration: 0.35)) {
                displayedFriendship = Double(maxMeter)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.37) {
                displayedFriendship = 0
                withAnimation(.easeOut(duration: 0.55)) {
                    displayedFriendship = Double(after)
                }
            }
        } else {
            displayedFriendship = beforeDisplayed
            withAnimation(.easeOut(duration: 0.65)) {
                displayedFriendship = Double(after)
            }
        }
    }

    private func makeUniquePhotoFileName(dayKey: String, now: Date) -> String {
        let ms = Int64(now.timeIntervalSince1970 * 1000)
        return "\(dayKey)_\(ms).jpg"
    }

    private func loadTodayPhoto() {
        let key = AppState.makeDayKey(Date())
        do {
            var descriptor = FetchDescriptor<TodayPhotoEntry>(
                predicate: #Predicate { $0.dayKey == key },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            descriptor.fetchLimit = 1

            let found = try modelContext.fetch(descriptor).first
            todayPhotoEntry = found
            if let fileName = found?.fileName {
                todayPhotoImage = TodayPhotoStorage.loadImage(fileName: fileName)
            } else {
                todayPhotoImage = nil
            }
        } catch {
            todayPhotoEntry = nil
            todayPhotoImage = nil
        }
    }

    private func normalizePlaceName(_ placeName: String?) -> String? {
        guard let placeName else { return nil }
        let t = placeName.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

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

            todayPhotoEntry = created
            todayPhotoImage = uiImage

            toast("今日の一枚を保存しました")
            Task { @MainActor in
                Haptics.rattle(duration: 0.18, style: .light)
            }
        } catch {
            print("❌ saveTodayPhoto failed:", error)
            toast("保存に失敗しました")
        }
    }

    private func toast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.2)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeInOut(duration: 0.2)) { showToast = false }
        }
    }

    private func onTapFood(state: AppState) {
        guard !isToiletLocked else {
            showToiletLockedMessage()
            return
        }

        let feedState = state.canFeedNow(now: Date())
        guard feedState.can else {
            toast(feedState.reason ?? "もう満腹みたい")
            return
        }

        syncFoodSelectorSelection()

        guard !ownedFoods.isEmpty else {
            bgmManager.playSE(.push)
            toast("ご飯を持っていません")
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

        bgmManager.playSE(.wc)
        toast("うんちを直接こすって掃除しよう！")
    }

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
            toast("トイレチケットを持っていません")
            Task { @MainActor in
                Haptics.rattle(duration: 0.12, style: .light)
            }
            return
        }

        bgmManager.playSE(.wc)
        isToiletTicketCleaning = true
        toiletPoopActivePoint.removeAll()

        withAnimation(.easeOut(duration: 0.28)) {
            toiletTicketClearingPoopIDs = Set(poops.map(\.id))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            guard state.gachaConsumeSpecialItem(id: "wc", count: 1) else {
                toiletTicketClearingPoopIDs.removeAll()
                isToiletTicketCleaning = false
                toast("トイレチケットの消費に失敗しました")
                return
            }

            for poop in poops {
                _ = state.markToiletPoopCleared(id: poop.id)
            }

            toiletTicketClearingPoopIDs.removeAll()
            isToiletTicketCleaning = false
            resolveToilet(state: state)
        }
    }

    private func onTapStep() {
        guard !isToiletLocked else {
            showToiletLockedMessage()
            return
        }

        bgmManager.playSE(.open)
        showStepEnjoy = true
    }

    private func resolveToilet(state: AppState) {
        let r = state.resolveToilet(now: Date())
        guard r.didResolve else { return }

        toiletPoopActivePoint.removeAll()
        toiletTicketClearingPoopIDs.removeAll()
        isToiletTicketCleaning = false

        addFriendshipWithAnimation(points: r.isWithin1h ? 20 : 10, state: state)
        toast(r.isWithin1h ? "トイレ成功（1時間以内）+20" : "トイレ成功 +10")
        save()

        syncCharacterBaseFromState(force: true)
        updateToiletWiggle()
        updateWidgetSnapshot(forceReload: true)
    }

    private func save() {
        do {
            try modelContext.save()
            updateWidgetSnapshot()
        } catch {
            print("❌ modelContext.save() failed:", error)
        }
    }

    private func updateWidgetSnapshot(forceReload: Bool = false) {
        let widgetState = state.makeWidgetStateSnapshot(todaySteps: widgetLinkedTodaySteps)
        let changed = HomeWidgetBridge.save(widgetState: widgetState, state: state)

        #if canImport(WidgetKit)
        if forceReload || changed {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }

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
            loadTodayPhoto()
            return
        }
    }

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
                                context.fill(
                                    Path(ellipseIn: rect),
                                    with: .color(Color.white.opacity(0.34))
                                )
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
            StatusIconButton(
                imageName: "coin",
                buttonSize: buttonSize,
                iconSize: iconSize,
                action: onCoin
            )

            StatusIconButton(
                imageName: "shoes",
                buttonSize: buttonSize,
                iconSize: iconSize,
                action: onShoes
            )

            StatusIconButton(
                imageName: "presentBox",
                buttonSize: buttonSize,
                iconSize: iconSize,
                action: onPresentBox
            )
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
    let happinessLevel: Int
    let happinessPoint: Int
    let happinessMaxPoints: Int
    let claimableLevel: Int?
    let nextRewardLevel: Int
    let onClose: () -> Void
    let onClaim: () -> Void

    private var titleText: String {
        switch popup {
        case .wallet:
            return "所持コイン"
        case .todaySteps:
            return "今日の歩数"
        case .happinessRewards:
            return "幸せ報酬"
        }
    }

    private var rewardRuleText: String {
        "幸せLv.\(AppState.happinessRewardLevelStep)ごとにレアごはんを1個受け取れます"
    }

    private var remainingLevelsText: String {
        let remaining = max(0, nextRewardLevel - happinessLevel)
        return "あと \(remaining) Lvで次の報酬です"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Text(titleText)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            content
        }
        .padding(.horizontal, HomeView.Layout.topInfoPopupHorizontalPadding)
        .padding(.vertical, HomeView.Layout.topInfoPopupVerticalPadding)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: HomeView.Layout.topInfoPopupCornerRadius, style: .continuous))
        .shadow(radius: 18)
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
            }

        case .happinessRewards:
            VStack(alignment: .leading, spacing: 14) {
                HomeTopInfoValueBlock(
                    label: "現在の幸せLv.",
                    valueText: "Lv.\(happinessLevel)",
                    caption: "現在の幸せ度 \(happinessPoint)/\(happinessMaxPoints)"
                )

                HomeTopInfoDescriptionRow(
                    title: "報酬ルール",
                    detail: rewardRuleText
                )

                if let claimableLevel {
                    HomeTopInfoDescriptionRow(
                        title: "受け取り可能",
                        detail: "Lv.\(claimableLevel) の報酬を受け取れます"
                    )

                    Button(action: onClaim) {
                        Text("Lv.\(claimableLevel)報酬を受け取る")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.85, green: 0.20, blue: 0.28).opacity(0.95), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    HomeTopInfoDescriptionRow(
                        title: "次の報酬",
                        detail: "Lv.\(nextRewardLevel) で獲得"
                    )

                    Text(remainingLevelsText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
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

private struct HomeTopInfoDescriptionRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(detail)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
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
                    MenuPopupActionIcon(
                        imageName: "camera_button",
                        buttonSize: buttonSize
                    )
                }
                .buttonStyle(.plain)

                if isToiletLocked {
                    Button(action: {
                        bgmManager.playSE(.push)
                        onBlocked()
                    }) {
                        MenuPopupActionIcon(
                            imageName: "omoide_button",
                            buttonSize: buttonSize
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink { MemoriesView() } label: {
                        MenuPopupActionIcon(
                            imageName: "omoide_button",
                            buttonSize: buttonSize
                        )
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
                        MenuPopupActionIcon(
                            imageName: "picture_button",
                            buttonSize: buttonSize
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink { ZukanView() } label: {
                        MenuPopupActionIcon(
                            imageName: "picture_button",
                            buttonSize: buttonSize
                        )
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
                        MenuPopupActionIcon(
                            imageName: "option_button",
                            buttonSize: buttonSize
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink { SettingsView() } label: {
                        MenuPopupActionIcon(
                            imageName: "option_button",
                            buttonSize: buttonSize
                        )
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

    private var iconSize: CGFloat {
        buttonSize * 0.74
    }

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
            BottomActionButton(
                imageName: "menu_button",
                buttonSize: buttonSize,
                action: {
                    bgmManager.playSE(.push)
                    if isToiletLocked {
                        onBlocked()
                        return
                    }
                    onMenu()
                }
            )

            BottomActionButton(
                imageName: "gatya_button",
                buttonSize: buttonSize,
                action: {
                    bgmManager.playSE(.push)
                    if isToiletLocked {
                        onBlocked()
                        return
                    }
                    onGatya()
                }
            )

            BottomActionButton(
                imageName: "work_button",
                buttonSize: buttonSize,
                action: {
                    bgmManager.playSE(.push)
                    if isToiletLocked {
                        onBlocked()
                        return
                    }
                    onWork()
                }
            )

            BottomActionButton(
                imageName: "step_button",
                buttonSize: buttonSize,
                action: {
                    bgmManager.playSE(.push)
                    if isToiletLocked {
                        onBlocked()
                        return
                    }
                    onStep()
                }
            )
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
            .contentShape(RoundedRectangle(
                cornerRadius: HomeView.Layout.bottomButtonCornerRadius,
                style: .continuous
            ))
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
            .contentShape(RoundedRectangle(
                cornerRadius: HomeView.Layout.bottomButtonCornerRadius,
                style: .continuous
            ))
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
    }
}

private struct FoodSelectionCarousel: View {
    let foods: [FoodCatalog.FoodItem]
    let countProvider: (String) -> Int
    let selectedFoodID: String?
    let pendingFoodID: String?
    let dragOffset: CGSize
    let isFeedingAnimationRunning: Bool
    let onMoveSelection: (Int) -> Void
    let onFeed: () -> Void
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

        if dragOffset.height <= -HomeView.Layout.foodSelectorPendingDecisionThreshold {
            return "あげる"
        }

        if dragOffset.height >= HomeView.Layout.foodSelectorPendingDecisionThreshold {
            return "やめる"
        }

        return nil
    }

    private var selectedIndex: Int {
        guard !foods.isEmpty else { return 0 }
        guard let selectedFoodID,
              let idx = foods.firstIndex(where: { $0.id == selectedFoodID }) else {
            return 0
        }
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

        let candidateOffsets = [-3, -2, -1, 0, 1, 2, 3]
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

                        Text("左右フリックで1つずつ / 横スクロールで連続選択 / タップ or 上フリックで仮止め")
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
        .accessibilityHint("左右フリックで1つずつ、横スクロールで連続してごはんを選び、タップまたは上フリックで仮止めします")
    }

    private func countText(for foodID: String) -> String {
        let count = max(1, countProvider(foodID))
        return "x\(count)"
    }

    private func zIndex(for relativePosition: Double) -> Double {
        10 - min(9, abs(relativePosition) * 2.4)
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

    private var backgroundOpacity: Double {
        if isPendingFeed && absPosition < 0.75 {
            return 0.32
        }
        return absPosition < 0.75 ? 0.24 : 0.18
    }

    private var borderOpacity: Double {
        if isPendingFeed && absPosition < 0.75 {
            return 0.95
        }
        if isFocused && absPosition < 0.75 {
            return 0.42
        }
        return 0.16
    }

    private var borderLineWidth: CGFloat {
        isPendingFeed && absPosition < 0.75 ? 3 : 1
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(backgroundOpacity))
                .frame(width: cardSize.width, height: cardSize.height)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(borderOpacity), lineWidth: borderLineWidth)
                )

            Image(item.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: cardSize.width * 0.68, height: cardSize.height * 0.68)
                .padding(10)

            Text(countText)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.72), in: Capsule())
                .offset(x: 10, y: 10)
        }
        .scaleEffect(config.scale)
        .opacity(config.opacity)
        .blur(radius: config.blur)
        .rotation3DEffect(
            .degrees(config.rotation),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.65
        )
        .offset(
            x: config.x,
            y: config.y + dragY + feedLift
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
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

            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.black.opacity(0.34))
                    .frame(width: 188, height: 188)
                    .overlay(
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .stroke(Color.white.opacity(0.92), lineWidth: 3)
                    )

                Image(item.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 126, height: 126)

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

private struct FloatingHeart: Identifiable, Equatable {
    let id = UUID()
    let xOffset: CGFloat
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

private struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .shadow(radius: 8)
    }
}
