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

    @AppStorage("didSetDailyGoalOnce") private var didSetDailyGoalOnce: Bool = false

    @State private var todaySteps: Int = 0
    @State private var todayKcal: Int = 0
    @State private var displayedTodayKcal: Int = 0
    @State private var displayedWalletKcal: Int = 0

    @State private var showGoalSheet: Bool = false

    @State private var todayPhotoImage: UIImage?
    @State private var todayPhotoEntry: TodayPhotoEntry?

    @State private var showCaptureModeDialog: Bool = false
    @State private var selectedCaptureMode: CameraCaptureView.Mode?

    @State private var toastMessage: String?
    @State private var showToast: Bool = false

    @State private var displayedFriendship: Double = 0
    @State private var displayedKcalProgress: Double = 0

    @State private var isAnimatingGain: Bool = false
    @State private var isHomeVisible: Bool = false

    @State private var showMojaOverlay: Bool = false
    @State private var rewardScale: CGFloat = 0.8
    @State private var rewardOpacity: Double = 0.0

    @State private var showStepEnjoy: Bool = false

    // ✅ 追加：ワークタイマー準備画面
    @State private var showWorkTimerPreparation: Bool = false

    // ✅ メニューポップアップ
    @State private var showRightMenuPopup: Bool = false

    // ✅ ごはんセレクター
    @State private var showFoodSelector: Bool = false
    @State private var selectedFoodID: String?
    @State private var foodSelectorDragOffset: CGSize = .zero
    @State private var isFoodFeedingAnimationRunning: Bool = false
    @State private var isFoodSelectorHorizontalRattling: Bool = false

    // =========================================================
    // ✅ キャラクターアニメ（アイドルまばたき / タップジャンプ）
    // =========================================================
    @State private var characterAssetName: String = ""
    @State private var idleLoopTask: Task<Void, Never>?
    @State private var isCharacterActionRunning: Bool = false

    private let doubleBlinkChance: Double = 0.18
    private let doubleBlinkGapRange: ClosedRange<Double> = 0.18...0.45

    // =========================================================
    // ✅ トイレフラグ中の操作ロック & ポップアップ
    // =========================================================
    @State private var showToiletLockedPopup: Bool = false
    @State private var toiletLockedPopupText: String = ""

    // ✅ トイレ中モジモジ（左右揺れ）
    @State private var isToiletWiggleOn: Bool = false

    // ✅ トイレpoop擦り処理
    @State private var toiletPoopActivePoint: [String: CGPoint] = [:]
    @State private var homeContentSize: CGSize = .zero

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

    private var canPlayTapAnimation: Bool {
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
        let total = max(todayKcal, hk.todayTotalEnergyKcal)
        let active = max(0, hk.todayActiveEnergyKcal)

        return (steps: steps, activeKcal: active, totalKcal: total)
    }

    // MARK: - Layout
    fileprivate enum Layout {
        static let bannerHeight: CGFloat = 76
        static let bannerWidthIPhone: CGFloat = 320
        static let homeBackgroundAssetName: String = "Home_background"

        static let leftTopPaddingTop: CGFloat = 44
        static let leftTopPaddingLeading: CGFloat = 18
        static let meterStackSpacing: CGFloat = 18

        static let iconHeartSize: CGFloat = 31
        static let iconCoinSize: CGFloat = 26
        static let capsuleHeight: CGFloat = 23

        static let barWidth: CGFloat = 125
        static let walletWidth: CGFloat = 125
        static let redMinWidth: CGFloat = 18

        static let friendshipTextFont: CGFloat = 11

        static let kcalRingTop: CGFloat = 36
        static let kcalRingTrailing: CGFloat = 18
        static let kcalRingSizeOuter: CGFloat = 135
        static let kcalRingSizeInner: CGFloat = 115

        static let characterTopOffset: CGFloat = 45
        static let characterMaxWidth: CGFloat = 210

        // ✅ メニューポップアップ
        static let menuPopupCornerRadius: CGFloat = 20
        static let menuPopupHorizontalPadding: CGFloat = 28
        static let menuPopupVerticalPadding: CGFloat = 24
        static let menuPopupMaxWidth: CGFloat = 160
        static let zMenuPopup: Double = 900

        static let rightButtonSize: CGFloat = 40
        static let rightButtonsSpacing: CGFloat = 18

        // ✅ 下部ボタンを少し大きく + 間隔調整
        static let bottomButtonSize: CGFloat = 68
        static let bottomButtonsSpacing: CGFloat = 16
        static let bottomPadding: CGFloat = 72
        static let bottomHorizontalPadding: CGFloat = 18

        // ✅ 下部ボタン背景
        static let bottomButtonBackgroundSize: CGFloat = 76
        static let bottomButtonIconSize: CGFloat = 68
        static let bottomButtonCornerRadius: CGFloat = 22
        static let bottomButtonBackgroundColor = Color.black.opacity(0.34)
        static let bottomButtonStrokeColor = Color.white.opacity(0.16)
        static let bottomBarHorizontalPadding: CGFloat = 14
        static let bottomBarVerticalPadding: CGFloat = 12
        static let bottomBarCornerRadius: CGFloat = 28
        static let bottomBarBackgroundColor = Color.black.opacity(0.18)

        // ✅ 吹き出しボタン
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

        static let rewardMaxWidth: CGFloat = 220
        static let getTextMaxWidth: CGFloat = 200

        static let getTextOffsetX: CGFloat = 11
        static let getTextOffsetY: CGFloat = -160

        static let kcalCenterCurrentFont: CGFloat = 18
        static let kcalCenterGoalFont: CGFloat = 12
        static let kcalCenterDividerHeight: CGFloat = 1
        static let kcalCenterDividerWidthRatio: CGFloat = 0.62
        static let kcalCenterSpacing: CGFloat = 4

        static let zCharacter: Double = 50
        static let zBottomButtons: Double = 260
        static let zReward: Double = 300
        static let zToiletPoops: Double = 980
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
                        let characterWidth = min(geo.size.width * 0.62, Layout.characterMaxWidth)

                        ZStack {
                            Rectangle()
                                .fill(Color.black.opacity(0.001))
                                .frame(width: characterWidth, height: characterWidth * 1.15)
                                .offset(y: Layout.characterTopOffset)
                                .zIndex(Layout.zCharacter)
                                .highPriorityGesture(
                                    TapGesture().onEnded {
                                        if isToiletLocked {
                                            showToiletLockedMessage()
                                        } else {
                                            triggerCharacterJump()
                                        }
                                    }
                                )

                            Image(characterAssetName.isEmpty ? preferredCharacterRestAssetName : characterAssetName)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: characterWidth)
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

                            VStack(alignment: .leading, spacing: Layout.meterStackSpacing) {
                                FriendshipMeter(
                                    value: displayedFriendship,
                                    maxValue: Double(AppState.friendshipMaxMeter),
                                    currentTextValue: Int(displayedFriendship.rounded()),
                                    maxTextValue: AppState.friendshipMaxMeter,
                                    barWidth: Layout.barWidth,
                                    height: Layout.capsuleHeight,
                                    iconSize: Layout.iconHeartSize,
                                    redMinWidth: Layout.redMinWidth
                                )

                                WalletCapsule(
                                    walletKcal: displayedWalletKcal,
                                    barWidth: Layout.walletWidth,
                                    height: Layout.capsuleHeight,
                                    iconSize: Layout.iconCoinSize
                                )

                                Spacer()
                            }
                            .padding(.top, Layout.leftTopPaddingTop)
                            .padding(.leading, Layout.leftTopPaddingLeading)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                            KcalRing(
                                progress: displayedKcalProgress,
                                currentKcal: displayedTodayKcal,
                                goalKcal: state.dailyGoalKcal,
                                outerSize: Layout.kcalRingSizeOuter,
                                innerSize: Layout.kcalRingSizeInner
                            )
                            .padding(.top, Layout.kcalRingTop)
                            .padding(.trailing, Layout.kcalRingTrailing)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

                            if hasFoodFlag {
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
                                            isScratchEnabled: state.hasToiletFlag,
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
                                .allowsHitTesting(state.hasToiletFlag)
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
                                    dragOffset: foodSelectorDragOffset,
                                    isFeedingAnimationRunning: isFoodFeedingAnimationRunning,
                                    onMoveSelection: { delta in
                                        moveFoodSelection(delta)
                                    },
                                    onFeed: {
                                        feedSelectedFood(state: state)
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

                            if showMojaOverlay {
                                ZStack {
                                    Color.black.opacity(0.001)
                                        .ignoresSafeArea()
                                        .onTapGesture { dismissMojaOverlay() }

                                    ZStack {
                                        Image("moja")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: min(geo.size.width * 0.7, Layout.rewardMaxWidth))
                                            .opacity(rewardOpacity)
                                            .scaleEffect(rewardScale)

                                        Image("get_text")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: min(geo.size.width * 0.62, Layout.getTextMaxWidth))
                                            .offset(x: Layout.getTextOffsetX, y: Layout.getTextOffsetY)
                                            .opacity(rewardOpacity)
                                            .scaleEffect(rewardScale)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                .transition(.opacity)
                                .zIndex(Layout.zReward)
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
                        state: state,
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
                            toast("ガチャ機能は準備中です")
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

                        state.ensureToiletNextSpawnScheduled(now: newDate)
                        state.ensureFoodNextSpawnScheduled(now: newDate)

                        maybeSpawnToiletFlag(state: state, now: newDate)
                        maybeSpawnFoodFlag(state: state, now: newDate)
                        syncToiletPoopsIfNeeded(containerSize: homeContentSize, now: newDate)

                        save()
                    }
                    .onAppear {
                        state.ensureDailyResetIfNeeded(now: now)

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
        .task {
            state.ensureInitialPetsIfNeeded()

            syncCharacterBaseFromState(force: true)

            if state.dailyGoalKcal > 0, didSetDailyGoalOnce == false {
                didSetDailyGoalOnce = true
            }

            todaySteps = state.widgetTodaySteps
            todayKcal = state.cachedTodayKcal

            displayedTodayKcal = todayKcal
            displayedWalletKcal = state.walletKcal
            displayedFriendship = Double(state.friendshipPoint)
            displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)

            handleDayRolloverIfNeeded(state: state)

            await runSync(state: state)

            state.ensureToiletNextSpawnScheduled(now: Date())
            state.ensureFoodNextSpawnScheduled(now: Date())

            maybeSpawnToiletFlag(state: state)
            maybeSpawnFoodFlag(state: state)

            syncToiletPoopsIfNeeded(containerSize: homeContentSize)
            loadTodayPhoto()
            syncFoodSelectorSelection()

            if !didSetDailyGoalOnce, state.dailyGoalKcal <= 0 {
                showGoalSheet = true
            }

            updateToiletWiggle()
            syncCharacterBaseFromState(force: true)
            updateWidgetSnapshot(forceReload: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            state.ensureInitialPetsIfNeeded()

            syncCharacterBaseFromState(force: true)

            todaySteps = state.widgetTodaySteps
            todayKcal = state.cachedTodayKcal

            displayedTodayKcal = todayKcal
            displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)

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

                if isHomeVisible {
                    await reconcileWalletDisplayIfNeeded(state: state)
                }

                updateToiletWiggle()
                syncCharacterBaseFromState(force: true)
                updateWidgetSnapshot(forceReload: true)
            }
        }
        .sheet(isPresented: $showGoalSheet) {
            GoalSettingSheet(
                currentGoal: state.dailyGoalKcal,
                isDismissDisabled: state.dailyGoalKcal <= 0,
                onSave: { newGoal in
                    state.dailyGoalKcal = newGoal
                    didSetDailyGoalOnce = true
                    save()

                    withAnimation(.easeOut(duration: 0.35)) {
                        displayedKcalProgress = calcKcalProgressRaw(
                            todayKcal: displayedTodayKcal,
                            goalKcal: state.dailyGoalKcal
                        )
                    }

                    showGoalSheet = false
                }
            )
        }
        .fullScreenCover(isPresented: $showStepEnjoy) {
            NavigationStack {
                StepView(state: state, hk: hk, onSave: save)
            }
        }
        .onAppear {
            isHomeVisible = true

            syncCharacterBaseFromState(force: true)
            startCharacterIdleLoopIfNeeded()

            withAnimation(.easeOut(duration: 0.25)) {
                displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)
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
            showFoodSelector = false
            foodSelectorDragOffset = .zero
            isFoodFeedingAnimationRunning = false
            stopFoodSelectorHorizontalRattleIfNeeded()
            toiletPoopActivePoint.removeAll()
        }
        .onChange(of: state.walletKcal) { _, _ in
            guard isHomeVisible else { return }
            Task { await reconcileWalletDisplayIfNeeded(state: state) }
            updateWidgetSnapshot()
        }
        .onChange(of: state.dailyGoalKcal) { _, _ in
            if state.dailyGoalKcal > 0, didSetDailyGoalOnce == false {
                didSetDailyGoalOnce = true
            }
            withAnimation(.easeOut(duration: 0.25)) {
                displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)
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
            if state.hasFoodFlag {
                syncFoodSelectorSelection()
            } else {
                closeFoodSelector()
            }
            updateWidgetSnapshot(forceReload: true)
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

    private func syncToiletPoopsIfNeeded(containerSize: CGSize, now: Date = Date()) {
        guard containerSize.width > 1, containerSize.height > 1 else { return }

        if !state.hasToiletFlag {
            toiletPoopActivePoint.removeAll()

            if !state.toiletPoops().isEmpty {
                state.clearToiletPoops()
                save()
            }
            return
        }

        var didChange = false

        if state.updateToiletPoopsByTime(now: now) {
            didChange = true
        }

        if state.toiletPoops().isEmpty {
            let generated = generateToiletPoops(in: containerSize, count: 2)
            if !generated.isEmpty {
                state.setToiletPoops(generated)
                didChange = true
            }
        }

        if didChange {
            save()
        }
    }

    private func generateToiletPoops(in containerSize: CGSize, count: Int) -> [AppState.ToiletPoopItem] {
        let poopSize = Layout.toiletPoopSize
        let horizontalInset = Layout.toiletPoopHorizontalInset + poopSize * 0.5
        let topInset = Layout.toiletPoopTopInset + poopSize * 0.5
        let bottomInset = Layout.toiletPoopBottomInset + poopSize * 0.5

        let minX = horizontalInset
        let maxX = max(minX, containerSize.width - horizontalInset)
        let minY = topInset
        let maxY = max(minY, containerSize.height - bottomInset)

        guard maxX > minX, maxY > minY else { return [] }

        var items: [AppState.ToiletPoopItem] = []
        let maxCount = max(0, count)
        let maxAttempts = 600

        for _ in 0..<maxCount {
            var created: AppState.ToiletPoopItem?

            for _ in 0..<maxAttempts {
                let point = CGPoint(
                    x: CGFloat.random(in: minX...maxX),
                    y: CGFloat.random(in: minY...maxY)
                )

                let poopRect = CGRect(
                    x: point.x - poopSize * 0.5,
                    y: point.y - poopSize * 0.5,
                    width: poopSize,
                    height: poopSize
                ).insetBy(
                    dx: -(Layout.toiletPoopMinSpacing * 0.5),
                    dy: -(Layout.toiletPoopMinSpacing * 0.5)
                )

                let overlapsAnotherPoop = items.contains { existing in
                    let existingPoint = CGPoint(
                        x: existing.centerXRatio * containerSize.width,
                        y: existing.centerYRatio * containerSize.height
                    )

                    let existingRect = CGRect(
                        x: existingPoint.x - poopSize * 0.5,
                        y: existingPoint.y - poopSize * 0.5,
                        width: poopSize,
                        height: poopSize
                    ).insetBy(
                        dx: -(Layout.toiletPoopMinSpacing * 0.5),
                        dy: -(Layout.toiletPoopMinSpacing * 0.5)
                    )

                    return poopRect.intersects(existingRect)
                }

                if overlapsAnotherPoop {
                    continue
                }

                created = AppState.ToiletPoopItem(
                    centerXRatio: Double(point.x / max(containerSize.width, 1)),
                    centerYRatio: Double(point.y / max(containerSize.height, 1)),
                    rotationDegrees: Double.random(in: -32...32),
                    isFlippedHorizontally: Bool.random()
                )
                break
            }

            if let created {
                items.append(created)
            }
        }

        return items
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
            showFoodSelector = false
            foodSelectorDragOffset = .zero
            isFoodFeedingAnimationRunning = false
            return
        }

        if let selectedFoodID,
           foods.contains(where: { $0.id == selectedFoodID }) {
            return
        }

        selectedFoodID = foods.first?.id
    }

    private func closeFoodSelector() {
        foodSelectorDragOffset = .zero
        isFoodFeedingAnimationRunning = false
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

        syncFoodSelectorSelection()

        guard !ownedFoods.isEmpty else { return }

        foodSelectorDragOffset = .zero
        isFoodFeedingAnimationRunning = false
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
            return
        }

        let nextIndex = (currentIndex + delta).positiveModulo(foods.count)

        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            selectedFoodID = foods[nextIndex].id
            foodSelectorDragOffset = .zero
        }

        Task { @MainActor in
            Haptics.tap(style: .soft)
        }
    }

    private func handleFoodSelectorDragChanged(_ value: DragGesture.Value) {
        foodSelectorDragOffset = value.translation

        let horizontal = abs(value.translation.width)
        let vertical = abs(value.translation.height)
        let isHorizontalDrag = horizontal > 14 && horizontal > vertical * 1.1

        if isHorizontalDrag {
            startFoodSelectorHorizontalRattleIfNeeded()
        } else {
            stopFoodSelectorHorizontalRattleIfNeeded()
        }
    }

    private func handleFoodSelectorDragEnded(_ value: DragGesture.Value, state: AppState) {
        stopFoodSelectorHorizontalRattleIfNeeded()
        let horizontal = value.translation.width
        let vertical = value.translation.height
        let predictedHorizontal = value.predictedEndTranslation.width
        let predictedVertical = value.predictedEndTranslation.height

        defer {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                foodSelectorDragOffset = .zero
            }
        }

        if predictedVertical < -95, abs(predictedHorizontal) < 70, abs(horizontal) < 80 {
            feedSelectedFood(state: state)
            return
        }

        let projectedHorizontal = abs(predictedHorizontal) > abs(horizontal)
            ? predictedHorizontal
            : horizontal

        let rawStepDelta = Int(round((-projectedHorizontal) / Layout.foodSelectorRollStepWidth))
        let clampedStepDelta = min(3, max(-3, rawStepDelta))

        if clampedStepDelta != 0 {
            moveFoodSelection(clampedStepDelta)
            return
        }

        if vertical < -85, abs(horizontal) < 55 {
            feedSelectedFood(state: state)
        }
    }

    private func startFoodSelectorHorizontalRattleIfNeeded() {
        guard !isFoodSelectorHorizontalRattling else { return }
        isFoodSelectorHorizontalRattling = true

        Task { @MainActor in
            Haptics.startRattle(style: .soft, interval: 0.028, intensity: 0.72)
        }
    }

    private func stopFoodSelectorHorizontalRattleIfNeeded() {
        guard isFoodSelectorHorizontalRattling else { return }
        isFoodSelectorHorizontalRattling = false

        Task { @MainActor in
            Haptics.stopRattle()
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
            toast("ご飯を持っていません")
            Task { @MainActor in
                Haptics.rattle(duration: 0.12, style: .light)
            }
            closeFoodSelector()
            return
        }

        isFoodFeedingAnimationRunning = true

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

    private func triggerCharacterJump() {
        guard isHomeVisible else { return }
        guard !isCharacterActionRunning else { return }
        guard !isToiletLocked else { return }
        guard canPlayTapAnimation else { return }

        Task { await playJump() }
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

    private func playJump() async {
        guard isHomeVisible else { return }
        guard !isCharacterActionRunning else { return }
        guard !isToiletLocked else { return }

        guard canPlayTapAnimation else {
            await MainActor.run { characterAssetName = preferredCharacterRestAssetName }
            return
        }

        let base = currentBaseAssetName
        let tap1 = "\(base)_tap_0001"
        let tap2 = "\(base)_tap_0002"

        await MainActor.run {
            isCharacterActionRunning = true
            characterAssetName = tap1
        }
        try? await Task.sleep(nanoseconds: 80_000_000)

        await MainActor.run { characterAssetName = tap2 }
        try? await Task.sleep(nanoseconds: 200_000_000)

        await MainActor.run { characterAssetName = tap1 }
        try? await Task.sleep(nanoseconds: 90_000_000)

        await MainActor.run {
            characterAssetName = preferredCharacterRestAssetName
            isCharacterActionRunning = false
        }
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

        guard state.hasFoodFlag else { return false }
        guard let food = FoodCatalog.byId(foodId) else {
            toast("ご飯が見つかりません")
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

        guard state.resolveFood(now: Date()) else {
            toast("今はごはんの時間じゃないよ")
            syncFoodSelectorSelection()
            return false
        }

        let isSuperFavorite = isSuperFavoriteFood(foodId: food.id, petID: state.normalizedCurrentPetID)
        let gainedPoint = isSuperFavorite ? 20 : 10

        if isSuperFavorite {
            _ = state.revealSuperFavorite(petID: state.normalizedCurrentPetID)
        }

        save()

        addFriendshipWithAnimation(points: gainedPoint, state: state)
        playFeedSound(isSuperFavorite: isSuperFavorite)

        if isSuperFavorite {
            toast("\(food.name)をあげた！ 大好物だ！ +\(gainedPoint)")
            playSuperFavoriteReactionIfPossible()
        } else {
            toast("\(food.name)をあげた！ +\(gainedPoint)")
        }

        syncFoodSelectorSelection()
        updateWidgetSnapshot(forceReload: true)
        return true
    }

    private func calcKcalProgressRaw(todayKcal: Int, goalKcal: Int) -> Double {
        guard goalKcal > 0 else { return 0 }
        return Double(todayKcal) / Double(goalKcal)
    }

    private func reconcileWalletDisplayIfNeeded(state: AppState) async {
        guard isHomeVisible else { return }
        guard !isAnimatingGain else { return }

        let target = state.walletKcal

        if displayedWalletKcal > target {
            await playWalletCountDownAnimation(from: displayedWalletKcal, to: target)
            return
        }

        if displayedWalletKcal != target {
            await MainActor.run { displayedWalletKcal = target }
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
                displayedWalletKcal = max(to, v)
            }

            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / fps))
        }

        await MainActor.run {
            displayedWalletKcal = to
            Haptics.stopRattle()
        }
    }

    private func addFriendshipWithAnimation(points: Int, state: AppState) {
        guard points > 0 else { return }

        let maxMeter = AppState.friendshipMaxMeter
        let beforeDisplayed = displayedFriendship

        let result = state.addFriendship(points: points, maxMeter: maxMeter)

        let gainedMoja = max(0, result.gainedCards)
        if gainedMoja > 0 {
            state.addMoja(gainedMoja)
        }

        save()

        let after = result.afterPoint

        Task { @MainActor in
            Haptics.rattle(duration: 0.50, style: .medium)
        }

        if result.didWrap {
            withAnimation(.easeOut(duration: 0.35)) {
                displayedFriendship = Double(maxMeter)
            }

            triggerMojaOverlay()

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

    private func triggerMojaOverlay() {
        showMojaOverlay = false
        rewardScale = 0.8
        rewardOpacity = 0.0

        withAnimation(.easeOut(duration: 0.12)) {
            showMojaOverlay = true
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.62)) {
            rewardScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.18)) {
            rewardOpacity = 1.0
        }
    }

    private func dismissMojaOverlay() {
        withAnimation(.easeInOut(duration: 0.18)) {
            rewardOpacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.12)) {
                showMojaOverlay = false
            }
            rewardScale = 0.8
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

        guard state.hasFoodFlag else {
            Task { @MainActor in
                Haptics.rattle(duration: 0.12, style: .light)
            }
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
            state.ensureDailyResetIfNeeded(now: now)
            state.lastSyncedAt = Calendar.current.startOfDay(for: now)
            save()
            loadTodayPhoto()
            return
        }
    }

    private func runSync(state: AppState) async {
        guard hk.authState == .authorized else { return }

        let previousCachedSteps = state.cachedTodaySteps
        let previousCachedKcal = state.cachedTodayKcal

        let beforeDisplayedTodayKcal = displayedTodayKcal
        let beforeDisplayedWallet = displayedWalletKcal

        let result = await hk.syncAndGetDeltaKcal(lastSyncedAt: state.lastSyncedAt)
        state.lastSyncedAt = result.newLastSyncedAt

        let fetchedSteps = hk.todaySteps
        let fetchedKcal = hk.todayTotalEnergyKcal

        let shouldProtectSteps = (fetchedSteps == 0 && previousCachedSteps > 0)
        let shouldProtectKcal = (fetchedKcal == 0 && previousCachedKcal > 0)

        todaySteps = shouldProtectSteps ? previousCachedSteps : fetchedSteps
        todayKcal = shouldProtectKcal ? previousCachedKcal : fetchedKcal

        if !shouldProtectSteps { state.cachedTodaySteps = todaySteps }
        if !shouldProtectKcal { state.cachedTodayKcal = todayKcal }

        if result.deltaKcal > 0 {
            state.pendingKcal += result.deltaKcal
        }
        save()

        await playGainAnimationIfNeeded(
            state: state,
            fromDisplayedTodayKcal: beforeDisplayedTodayKcal,
            fromDisplayedWallet: beforeDisplayedWallet
        )

        if !isAnimatingGain {
            displayedTodayKcal = todayKcal

            if isHomeVisible {
                displayedWalletKcal = state.walletKcal
            }

            withAnimation(.easeOut(duration: 0.25)) {
                displayedKcalProgress = calcKcalProgressRaw(
                    todayKcal: displayedTodayKcal,
                    goalKcal: state.dailyGoalKcal
                )
            }
        }

        syncCharacterBaseFromState(force: true)
        updateWidgetSnapshot()
    }

    private func playGainAnimationIfNeeded(
        state: AppState,
        fromDisplayedTodayKcal: Int,
        fromDisplayedWallet: Int
    ) async {
        guard !isAnimatingGain else { return }

        let deltaWallet = state.pendingKcal
        let targetWallet = state.walletKcal + max(0, deltaWallet)
        let targetTodayKcal = todayKcal

        let hasAnyIncrease = (targetWallet > fromDisplayedWallet) || (targetTodayKcal > fromDisplayedTodayKcal)
        guard hasAnyIncrease else { return }

        isAnimatingGain = true

        if deltaWallet > 0 {
            state.pendingKcal = 0
            state.walletKcal = targetWallet
            save()
        }

        let totalMagnitude = max(targetWallet - fromDisplayedWallet, targetTodayKcal - fromDisplayedTodayKcal)
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
            let newTodayKcal = fromDisplayedTodayKcal + Int(Double(targetTodayKcal - fromDisplayedTodayKcal) * eased)

            await MainActor.run {
                displayedWalletKcal = newWallet
                displayedTodayKcal = newTodayKcal
                displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)
            }

            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / fps))
        }

        await MainActor.run {
            displayedWalletKcal = targetWallet
            displayedTodayKcal = targetTodayKcal
            displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)
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

// MARK: - UI Parts

private struct FriendshipMeter: View {
    let value: Double
    let maxValue: Double
    let currentTextValue: Int
    let maxTextValue: Int

    let barWidth: CGFloat
    let height: CGFloat
    let iconSize: CGFloat
    let redMinWidth: CGFloat

    private var progress: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(min(1.0, value / maxValue))
    }

    private var rawWidth: CGFloat { barWidth * progress }
    private var baseWidth: CGFloat { Swift.max(redMinWidth, rawWidth) }
    private var scaleX: CGFloat {
        guard baseWidth > 0 else { return 0 }
        return rawWidth / baseWidth
    }

    var body: some View {
        HStack(spacing: 10) {
            Image("heart_Icon")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: barWidth, height: height)

                if rawWidth > 0 {
                    Capsule()
                        .fill(Color(red: 0.95, green: 0.12, blue: 0.12))
                        .frame(width: baseWidth, height: height)
                        .scaleEffect(x: scaleX, y: 1, anchor: .leading)
                }

                Text("\(currentTextValue)/\(maxTextValue)")
                    .font(.system(size: HomeView.Layout.friendshipTextFont, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(width: barWidth, height: height)
            }
        }
    }
}

private struct WalletCapsule: View {
    let walletKcal: Int

    let barWidth: CGFloat
    let height: CGFloat
    let iconSize: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            Image("coin_Icon")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)

            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: barWidth, height: height)

                Text("\(walletKcal)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
    }
}

private struct KcalRing: View {
    let progress: Double
    let currentKcal: Int
    let goalKcal: Int

    let outerSize: CGFloat
    let innerSize: CGFloat

    private var goalText: String { goalKcal > 0 ? "\(goalKcal)" : "—" }

    private var lap1: CGFloat {
        CGFloat(min(1.0, max(0.0, progress)))
    }

    private var lap2: CGFloat {
        let v = progress - 1.0
        return CGFloat(min(1.0, max(0.0, v)))
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.9))
                .frame(width: outerSize, height: outerSize)

            Circle()
                .stroke(lineWidth: 14)
                .opacity(0.18)
                .foregroundStyle(.white)
                .frame(width: innerSize, height: innerSize)

            Circle()
                .trim(from: 0, to: lap1)
                .stroke(style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(-90))
                .frame(width: innerSize, height: innerSize)
                .animation(.easeOut(duration: 0.55), value: lap1)

            if lap2 > 0 {
                Circle()
                    .trim(from: 0, to: lap2)
                    .stroke(style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .foregroundStyle(.green)
                    .rotationEffect(.degrees(-90))
                    .frame(width: innerSize, height: innerSize)
                    .animation(.easeOut(duration: 0.55), value: lap2)
            }

            VStack(spacing: HomeView.Layout.kcalCenterSpacing) {
                Text("\(currentKcal)")
                    .font(.system(size: HomeView.Layout.kcalCenterCurrentFont, weight: .bold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Rectangle()
                    .fill(Color.white.opacity(0.75))
                    .frame(
                        width: innerSize * HomeView.Layout.kcalCenterDividerWidthRatio,
                        height: HomeView.Layout.kcalCenterDividerHeight
                    )

                Text("\(goalText)")
                    .font(.system(size: HomeView.Layout.kcalCenterGoalFont, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: innerSize * 0.9)
        }
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

private struct CenterMenuPopup: View {
    let state: AppState
    let isToiletLocked: Bool
    let onBlocked: () -> Void
    let onCamera: () -> Void
    let onDismiss: () -> Void
    let buttonSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            RightSideButtons(
                state: state,
                onCamera: onCamera,
                isToiletLocked: isToiletLocked,
                onBlocked: onBlocked,
                buttonSize: buttonSize,
                spacing: spacing
            )
        }
        .padding(.horizontal, HomeView.Layout.menuPopupHorizontalPadding)
        .padding(.vertical, HomeView.Layout.menuPopupVerticalPadding)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: HomeView.Layout.menuPopupCornerRadius, style: .continuous))
        .shadow(radius: 18)
    }
}

private struct RightSideButtons: View {
    @EnvironmentObject private var bgmManager: BGMManager

    let state: AppState
    let onCamera: () -> Void

    let isToiletLocked: Bool
    let onBlocked: () -> Void

    let buttonSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        VStack(spacing: spacing) {
            Button(action: {
                bgmManager.playSE(.push)
                onCamera()
            }) {
                Image("camera_button")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
            }

            if isToiletLocked {
                Button(action: {
                    bgmManager.playSE(.push)
                    onBlocked()
                }) {
                    Image("omoide_button")
                        .resizable()
                        .scaledToFit()
                        .frame(width: buttonSize, height: buttonSize)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink { MemoriesView() } label: {
                    Image("omoide_button")
                        .resizable()
                        .scaledToFit()
                        .frame(width: buttonSize, height: buttonSize)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    bgmManager.playSE(.push)
                })
            }

            if isToiletLocked {
                Button(action: {
                    bgmManager.playSE(.push)
                    onBlocked()
                }) {
                    Image("moja")
                        .resizable()
                        .scaledToFit()
                        .frame(width: buttonSize, height: buttonSize)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink { GetView(state: state) } label: {
                    Image("moja")
                        .resizable()
                        .scaledToFit()
                        .frame(width: buttonSize, height: buttonSize)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    bgmManager.playSE(.push)
                })
            }

            if isToiletLocked {
                Button(action: {
                    bgmManager.playSE(.push)
                    onBlocked()
                }) {
                    Image("picture_button")
                        .resizable()
                        .scaledToFit()
                        .frame(width: buttonSize, height: buttonSize)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink { ZukanView() } label: {
                    Image("picture_button")
                        .resizable()
                        .scaledToFit()
                        .frame(width: buttonSize, height: buttonSize)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    bgmManager.playSE(.push)
                })
            }

            if isToiletLocked {
                Button(action: {
                    bgmManager.playSE(.push)
                    onBlocked()
                }) {
                    Image("shop_button")
                        .resizable()
                        .scaledToFit()
                        .frame(width: buttonSize, height: buttonSize)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink { ShopView(state: state) } label: {
                    Image("shop_button")
                        .resizable()
                        .scaledToFit()
                        .frame(width: buttonSize, height: buttonSize)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    bgmManager.playSE(.push)
                })
            }

            if isToiletLocked {
                Button(action: {
                    bgmManager.playSE(.push)
                    onBlocked()
                }) {
                    Image("option_button")
                        .resizable()
                        .scaledToFit()
                        .frame(width: buttonSize, height: buttonSize)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink { SettingsView() } label: {
                    Image("option_button")
                        .resizable()
                        .scaledToFit()
                        .frame(width: buttonSize, height: buttonSize)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    bgmManager.playSE(.push)
                })
            }
        }
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
        .background(
            RoundedRectangle(
                cornerRadius: HomeView.Layout.bottomBarCornerRadius,
                style: .continuous
            )
            .fill(HomeView.Layout.bottomBarBackgroundColor)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: HomeView.Layout.bottomBarCornerRadius,
                style: .continuous
            )
            .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
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
                RoundedRectangle(
                    cornerRadius: HomeView.Layout.bottomButtonCornerRadius,
                    style: .continuous
                )
                .fill(HomeView.Layout.bottomButtonBackgroundColor)
                .frame(
                    width: HomeView.Layout.bottomButtonBackgroundSize,
                    height: HomeView.Layout.bottomButtonBackgroundSize
                )

                RoundedRectangle(
                    cornerRadius: HomeView.Layout.bottomButtonCornerRadius,
                    style: .continuous
                )
                .stroke(HomeView.Layout.bottomButtonStrokeColor, lineWidth: 1)

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

private struct FoodSelectionCarousel: View {
    let foods: [FoodCatalog.FoodItem]
    let countProvider: (String) -> Int
    let selectedFoodID: String?
    let dragOffset: CGSize
    let isFeedingAnimationRunning: Bool
    let onMoveSelection: (Int) -> Void
    let onFeed: () -> Void
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void

    private struct VisibleCard: Identifiable {
        let id: String
        let item: FoodCatalog.FoodItem
        let relativeIndex: Int
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
                    isFeedingAnimationRunning: isFeedingAnimationRunning
                )
                .zIndex(zIndex(for: relativePosition))
            }

            VStack(spacing: 6) {
                if let focused = foods[safe: focusedIndex] {
                    Text(focused.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)

                    Text("左右にドラムロール / 上フリックであげる")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .offset(y: HomeView.Layout.foodSelectorInstructionOffsetY)
        }
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged(onDragChanged)
                .onEnded(onDragEnded)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ごはんセレクター")
        .accessibilityHint("左右にドラムロールのように動かしてごはんを選び、上フリックであげます")
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
        absPosition < 0.75 ? 0.24 : 0.18
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.black.opacity(backgroundOpacity))
                .frame(width: cardSize.width, height: cardSize.height)

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
        .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.82), value: dragOffset)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isFeedingAnimationRunning)
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

private struct GoalSettingSheet: View {
    let currentGoal: Int
    let isDismissDisabled: Bool
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("目標消費カロリー（kcal）") {
                    TextField("例：300", text: $text)
                        .keyboardType(.numberPad)

                    if let error {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }

                    Text("当日中の変更も即時反映されます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("保存") {
                        guard let v = Int(text), v > 0 else {
                            error = "1以上の数値を入力してください。"
                            return
                        }
                        onSave(v)
                    }
                }
            }
            .navigationTitle("目標設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { if !isDismissDisabled { dismiss() } }
                        .disabled(isDismissDisabled)
                }
            }
        }
        .onAppear { text = currentGoal > 0 ? String(currentGoal) : "" }
    }
}
