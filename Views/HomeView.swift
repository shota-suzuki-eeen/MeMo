//
//  HomeView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers
#if canImport(WidgetKit)
import WidgetKit
#endif

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var bgmManager: BGMManager

    // ✅ Rootから渡された“同一のAppState”を使う
    let state: AppState

    @ObservedObject var hk: HealthKitManager

    // ✅ 初回のみ目標設定シートを出すためのフラグ（AppStateに持たせずUserDefaultsで保持）
    @AppStorage("didSetDailyGoalOnce") private var didSetDailyGoalOnce: Bool = false

    // 表示用
    @State private var todaySteps: Int = 0
    @State private var todayKcal: Int = 0

    // ✅ リング中央表示（演出でカウントアップさせる）
    @State private var displayedTodayKcal: Int = 0

    // ✅ 所持通貨表示（演出でカウントアップ/ダウンさせる）
    @State private var displayedWalletKcal: Int = 0

    // ✅ 満足度（表示用：0..3）
    @State private var displayedSatisfaction: Int = 0
    @State private var satisfactionRemainingText: String = "--:--"

    // 目標入力（初回必須）
    @State private var showGoalSheet: Bool = false

    // ✅ 今日の一枚（撮影ボタンに紐づける）
    @State private var todayPhotoImage: UIImage?
    @State private var todayPhotoEntry: TodayPhotoEntry?

    // ✅ 撮影ボタンで開くキャプチャ画面制御
    @State private var showCaptureModeDialog: Bool = false
    @State private var selectedCaptureMode: CameraCaptureView.Mode?

    // 軽いトースト（保存完了など）
    @State private var toastMessage: String?
    @State private var showToast: Bool = false

    // ✅ メーター演出用（表示値を別で持って滑らかに伸ばす）
    @State private var displayedFriendship: Double = 0

    /// ✅ リング進捗（1周目=0..1、2周目以降=1..2..）
    @State private var displayedKcalProgress: Double = 0

    // gain演出
    @State private var isAnimatingGain: Bool = false

    // ✅ Home表示中か（ショップ滞在中に onChange が走っても演出しない）
    @State private var isHomeVisible: Bool = false

    // ✅ MAX到達時 “もじゃ” 演出
    @State private var showMojaOverlay: Bool = false
    @State private var rewardScale: CGFloat = 0.8
    @State private var rewardOpacity: Double = 0.0

    // ✅ ごはん棚
    @State private var showFoodShelf: Bool = false

    // ✅ ドロップターゲット演出
    @State private var isDropTargeted: Bool = false

    // ✅ 追加：ドラッグでキャラ上ホバー中か（表情差し替えのため）
    @State private var isFoodHoveringOverCharacter: Bool = false

    @State private var showStepEnjoy: Bool = false

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

    // =========================================================
    // ✅ おふろフラグ演出（yogore）
    // =========================================================
    @State private var showBathOverlay: Bool = false
    @State private var bathOverlayOpacity: Double = 0.0
    @State private var isBathCleaningAnimationRunning: Bool = false

    // ✅ 追加：現在育成中キャラの「ベースアセット名」
    private var currentBaseAssetName: String {
        PetMaster.assetName(for: state.normalizedCurrentPetID)
    }

    // ✅ 追加：表示用キャラ名
    private var currentPetName: String {
        PetMaster.all.first(where: { $0.id == state.normalizedCurrentPetID })?.name ?? "ペット"
    }

    // ✅ 追加：トイレロック中か
    private var isToiletLocked: Bool {
        state.hasToiletFlag
    }

    // ✅ 追加：おふろフラグ中か
    private var hasBathFlag: Bool {
        state.hasBathFlag
    }

    // ✅ 追加：ウィジェット連携時に使う歩数
    private var widgetLinkedTodaySteps: Int {
        max(todaySteps, state.widgetTodaySteps)
    }

    // ✅ 追加：トイレ中に表示する *_wc が用意されているキャラ
    private var canShowWcAsset: Bool {
        [
            "beat",
            "biniki",
            "himei",
            "kakke",
            "kepyon",
            "ninjin",
            "obaoru",
            "purpor",
            "sun",
            "wanigeeta",
            "wareware"
        ].contains(currentBaseAssetName)
    }

    // ✅ 追加：ごはんホバー時の表情差し替え（*_hungry / *_burp）に対応しているキャラ
    private var canPlayCharacterAnimation: Bool {
        [
            "purpor",
            "obaoru",
            "ninjin",
            "kakke",
            "beat",
            "biniki",
            "himei",
            "kepyon",
            "sun",
            "wanigeeta",
            "wareware"
        ].contains(currentBaseAssetName)
    }

    // ✅ 追加：タップアクション対応キャラ
    private var canPlayTapAnimation: Bool {
        [
            "purpor",
            "obaoru",
            "kakke",
            "kepyon",
            "sun",
            "ninjin",
            "beat",
            "biniki",
            "himei",
            "wanigeeta",
            "wareware"
        ].contains(currentBaseAssetName)
    }

    // ✅ 追加：まばたき対応キャラ
    private var canPlayBlinkAnimation: Bool {
        [
            "purpor",
            "kakke",
            "obaoru",
            "kepyon",
            "sun",
            "wanigeeta",
            "beat",
            "ninjin",
            "biniki",
            "himei",
            "wareware"
        ].contains(currentBaseAssetName)
    }

    // ✅ 追加：満足度MAX判定
    private var isSatisfactionMax: Bool {
        displayedSatisfaction >= Layout.satisfactionSegments
    }

    // ✅ 追加：静止状態で表示すべきアセット名
    private var preferredCharacterRestAssetName: String {
        if isToiletLocked, canShowWcAsset {
            return "\(currentBaseAssetName)_wc"
        }

        if isFoodHoveringOverCharacter, canPlayCharacterAnimation {
            return isSatisfactionMax ? "\(currentBaseAssetName)_burp" : "\(currentBaseAssetName)_hungry"
        }

        return currentBaseAssetName
    }

    // ✅ 追加：撮影画面に渡す表示用メトリクス
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

        static let satisfactionSpacingFromWallet: CGFloat = 16
        static let satisfactionBarWidth: CGFloat = 125
        static let satisfactionBarHeight: CGFloat = 23
        static let satisfactionSegments: Int = 3
        static let satisfactionSegmentGap: CGFloat = 4
        static let satisfactionCornerRadius: CGFloat = 11

        static let satisfactionIconAssetName: String = "food_Icon"
        static let satisfactionIconSize: CGFloat = 24
        static let satisfactionIconSpacing: CGFloat = 10
        static let satisfactionCountdownFont: CGFloat = 11

        static let kcalRingTop: CGFloat = 36
        static let kcalRingTrailing: CGFloat = 18
        static let kcalRingSizeOuter: CGFloat = 135
        static let kcalRingSizeInner: CGFloat = 115

        static let characterTopOffset: CGFloat = 45
        static let characterMaxWidth: CGFloat = 210

        static let rightButtonsTopOffset: CGFloat = 210
        static let rightButtonsTrailing: CGFloat = 20
        static let rightButtonSize: CGFloat = 40
        static let rightButtonsSpacing: CGFloat = 18

        static let bottomButtonSize: CGFloat = 60
        static let bottomButtonsSpacing: CGFloat = 22
        static let bottomPadding: CGFloat = 80
        static let bottomHorizontalPadding: CGFloat = 20

        static let foodShelfHeight: CGFloat = 45
        static let foodShelfHorizontalPadding: CGFloat = 18
        static let foodShelfBottomGapFromButtons: CGFloat = 120
        static let foodItemSize: CGFloat = 64

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
        static let zBathOverlay: Double = 170
        static let zFoodShelf: Double = 220
        static let zBottomButtons: Double = 260
        static let zReward: Double = 300
        static let zBanner: Double = 1000

        static let toiletWiggleOffset: CGFloat = 3
        static let toiletWiggleDuration: Double = 0.12

        static let lockedPopupMaxWidth: CGFloat = 320
        static let lockedPopupPaddingH: CGFloat = 18
        static let lockedPopupPaddingV: CGFloat = 12
        static let lockedPopupShowSeconds: Double = 1.1

        static let bathFadeInDuration: Double = 0.95
        static let bathFadeOutDuration: Double = 1.15

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
                            if showFoodShelf {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture { closeFoodShelf() }
                            }

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
                                    .simultaneousGesture(
                                        TapGesture().onEnded {
                                            if showFoodShelf { closeFoodShelf() }
                                        }
                                    )
                                    .onDrop(
                                        of: [UTType.plainText.identifier, UTType.text.identifier],
                                        isTargeted: $isDropTargeted
                                    ) { providers in
                                        if isToiletLocked {
                                            showToiletLockedMessage()
                                            return false
                                        }

                                        guard let provider = providers.first else { return false }

                                        provider.loadItem(
                                            forTypeIdentifier: UTType.plainText.identifier,
                                            options: nil
                                        ) { item, _ in
                                            let id: String? = {
                                                if let s = item as? String { return s }
                                                if let data = item as? Data,
                                                   let s = String(data: data, encoding: .utf8) { return s }
                                                if let url = item as? URL { return url.absoluteString }
                                                return nil
                                            }()

                                            guard let foodId = id else { return }
                                            DispatchQueue.main.async {
                                                _ = handleFoodDrop(foodId: foodId, state: state)
                                                endFoodHoverIfNeeded()
                                            }
                                        }
                                        return true
                                    }

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
                            }

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

                                VStack(alignment: .leading, spacing: Layout.satisfactionSpacingFromWallet) {
                                    WalletCapsule(
                                        walletKcal: displayedWalletKcal,
                                        barWidth: Layout.walletWidth,
                                        height: Layout.capsuleHeight,
                                        iconSize: Layout.iconCoinSize
                                    )

                                    SatisfactionMeter(
                                        level: displayedSatisfaction,
                                        maxLevel: Layout.satisfactionSegments,
                                        barWidth: Layout.satisfactionBarWidth,
                                        height: Layout.satisfactionBarHeight,
                                        gap: Layout.satisfactionSegmentGap,
                                        cornerRadius: Layout.satisfactionCornerRadius,
                                        iconAssetName: Layout.satisfactionIconAssetName,
                                        iconSize: Layout.satisfactionIconSize,
                                        iconSpacing: Layout.satisfactionIconSpacing,
                                        countdownText: satisfactionRemainingText
                                    )
                                }

                                Spacer()
                            }
                            .padding(.top, Layout.leftTopPaddingTop)
                            .padding(.leading, Layout.leftTopPaddingLeading)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    if showFoodShelf { closeFoodShelf() }
                                }
                            )

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
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    if showFoodShelf { closeFoodShelf() }
                                }
                            )

                            RightSideButtons(
                                state: state,
                                onCamera: {
                                    if isToiletLocked {
                                        showToiletLockedMessage()
                                        return
                                    }
                                    showCaptureModeDialog = true
                                },
                                isToiletLocked: isToiletLocked,
                                onBlocked: { showToiletLockedMessage() },
                                buttonSize: Layout.rightButtonSize,
                                spacing: Layout.rightButtonsSpacing
                            )
                            .padding(.top, Layout.rightButtonsTopOffset)
                            .padding(.trailing, Layout.rightButtonsTrailing)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    if showFoodShelf { closeFoodShelf() }
                                }
                            )

                            if showFoodShelf {
                                FoodShelfPanel(state: state)
                                    .padding(.horizontal, Layout.foodShelfHorizontalPadding)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                    .padding(.bottom, Layout.bottomPadding + Layout.foodShelfBottomGapFromButtons)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                    .zIndex(Layout.zFoodShelf)
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
                        .overlay(alignment: .bottom) {
                            if showToast, let toastMessage {
                                ToastView(message: toastMessage)
                                    .padding(.bottom, 18)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                }

                if showBathOverlay || hasBathFlag {
                    Color.clear
                        .ignoresSafeArea()
                        .overlay {
                            Image("yogore")
                                .resizable()
                                .scaledToFill()
                                .ignoresSafeArea()
                                .opacity(bathOverlayOpacity)
                                .allowsHitTesting(false)
                        }
                        .zIndex(Layout.zBathOverlay)
                }
            }
            .overlay(alignment: .bottom) {
                TimelineView(.periodic(from: Date(), by: Layout.careSpawnCheckInterval)) { timeline in
                    let now = timeline.date

                    let canFood = true
                    let canBath = hasBathFlag
                    let canWc = true

                    BottomButtons(
                        onBath: {
                            if isToiletLocked {
                                showToiletLockedMessage()
                                return
                            }
                            onTapBath(state: state)
                        },
                        onFood: {
                            if isToiletLocked {
                                showToiletLockedMessage()
                                return
                            }
                            onTapFood(state: state)
                        },
                        onWc: {
                            onTapToilet(state: state)
                        },
                        onStep: {
                            if isToiletLocked {
                                showToiletLockedMessage()
                                return
                            }
                            onTapStep()
                        },
                        isBathAvailable: canBath,
                        isFoodAvailable: canFood,
                        isWcAvailable: canWc,
                        isToiletLocked: isToiletLocked,
                        onBlocked: { showToiletLockedMessage() },
                        buttonSize: Layout.bottomButtonSize,
                        spacing: Layout.bottomButtonsSpacing,
                        horizontalPadding: Layout.bottomHorizontalPadding
                    )
                    .onChange(of: timeline.date) { _, newDate in
                        displayedSatisfaction = state.currentSatisfaction(now: newDate)
                        updateSatisfactionCountdown(now: newDate)
                        state.ensureDailyResetIfNeeded(now: newDate)

                        state.ensureBathNextSpawnScheduled(now: newDate)
                        state.ensureToiletNextSpawnScheduled(now: newDate)

                        maybeSpawnBathFlag(state: state, now: newDate)
                        maybeSpawnToiletFlag(state: state, now: newDate)

                        save()
                    }
                    .onAppear {
                        displayedSatisfaction = state.currentSatisfaction(now: now)
                        updateSatisfactionCountdown(now: now)
                        state.ensureDailyResetIfNeeded(now: now)

                        state.ensureBathNextSpawnScheduled(now: now)
                        state.ensureToiletNextSpawnScheduled(now: now)

                        maybeSpawnBathFlag(state: state, now: now)
                        maybeSpawnToiletFlag(state: state, now: now)

                        syncBathOverlayFromState(animated: false)
                        save()
                    }
                }
                .padding(.bottom, Layout.bottomPadding)
                .zIndex(Layout.zBottomButtons)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        if showFoodShelf { closeFoodShelf() }
                    }
                )
            }
            .overlay(alignment: .top) {
                // ✅ AdMob バナーを一旦停止
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
            displayedSatisfaction = state.currentSatisfaction(now: Date())
            updateSatisfactionCountdown(now: Date())

            displayedFriendship = Double(state.friendshipPoint)
            displayedKcalProgress = calcKcalProgressRaw(todayKcal: displayedTodayKcal, goalKcal: state.dailyGoalKcal)

            handleDayRolloverIfNeeded(state: state)

            await runSync(state: state)

            state.ensureBathNextSpawnScheduled(now: Date())
            state.ensureToiletNextSpawnScheduled(now: Date())

            maybeSpawnBathFlag(state: state)
            maybeSpawnToiletFlag(state: state)
            loadTodayPhoto()

            if !didSetDailyGoalOnce, state.dailyGoalKcal <= 0 {
                showGoalSheet = true
            }

            updateToiletWiggle()
            syncBathOverlayFromState(animated: false)
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

            displayedSatisfaction = state.currentSatisfaction(now: Date())
            updateSatisfactionCountdown(now: Date())

            handleDayRolloverIfNeeded(state: state)

            Task {
                await runSync(state: state)

                state.ensureBathNextSpawnScheduled(now: Date())
                state.ensureToiletNextSpawnScheduled(now: Date())

                maybeSpawnBathFlag(state: state)
                maybeSpawnToiletFlag(state: state)
                loadTodayPhoto()

                if isHomeVisible {
                    await reconcileWalletDisplayIfNeeded(state: state)
                }

                updateToiletWiggle()
                syncBathOverlayFromState(animated: false)
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

            displayedSatisfaction = state.currentSatisfaction(now: Date())
            updateSatisfactionCountdown(now: Date())

            Task { await reconcileWalletDisplayIfNeeded(state: state) }

            updateToiletWiggle()
            syncBathOverlayFromState(animated: false)
            syncCharacterBaseFromState(force: true)
            updateWidgetSnapshot(forceReload: true)
        }
        .onDisappear {
            isHomeVisible = false
            Haptics.stopRattle()

            stopCharacterIdleLoop()
            isCharacterActionRunning = false

            characterAssetName = preferredCharacterRestAssetName
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
        .onChange(of: isDropTargeted) { _, newValue in
            if newValue {
                beginFoodHover()
            } else {
                endFoodHoverIfNeeded()
            }
        }
        .onChange(of: displayedSatisfaction) { _, _ in
            guard isFoodHoveringOverCharacter else { return }
            beginFoodHover()
        }
        .onChange(of: state.toiletFlagAt) { _, _ in
            syncCharacterBaseFromState(force: true)
            updateToiletWiggle()
            updateWidgetSnapshot(forceReload: true)
        }
        .onChange(of: state.bathFlagAt) { _, _ in
            syncBathOverlayFromState(animated: true)
            updateWidgetSnapshot(forceReload: true)
        }
        .onChange(of: state.toiletNextSpawnAt) { _, _ in
            updateWidgetSnapshot(forceReload: true)
        }
        .onChange(of: state.bathNextSpawnAt) { _, _ in
            updateWidgetSnapshot(forceReload: true)
        }
        .onChange(of: state.lastDayKey) { _, _ in
            updateWidgetSnapshot(forceReload: true)
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

    private func updateSatisfactionCountdown(now: Date = Date()) {
        guard let remaining = state.satisfactionRemainingSecondsUntilNextDecay(now: now),
              displayedSatisfaction > 0 else {
            satisfactionRemainingText = "--:--"
            return
        }

        let totalSeconds = max(0, Int(ceil(remaining)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        satisfactionRemainingText = String(format: "%02d:%02d", minutes, seconds)
    }

    private func syncBathOverlayFromState(animated: Bool) {
        let shouldShow = state.hasBathFlag

        if shouldShow {
            if !showBathOverlay {
                showBathOverlay = true
            }

            if animated {
                guard bathOverlayOpacity < 0.999 else { return }
                withAnimation(.easeInOut(duration: Layout.bathFadeInDuration)) {
                    bathOverlayOpacity = 1.0
                }
            } else {
                bathOverlayOpacity = 1.0
            }
            return
        }

        guard showBathOverlay || bathOverlayOpacity > 0.001 else { return }

        if animated {
            withAnimation(.easeInOut(duration: Layout.bathFadeOutDuration)) {
                bathOverlayOpacity = 0.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + Layout.bathFadeOutDuration) {
                if !state.hasBathFlag {
                    showBathOverlay = false
                    bathOverlayOpacity = 0.0
                }
            }
        } else {
            bathOverlayOpacity = 0.0
            showBathOverlay = false
        }
    }

    private func syncCharacterBaseFromState(force: Bool) {
        if !force {
            guard !isCharacterActionRunning else { return }
        }

        characterAssetName = preferredCharacterRestAssetName
    }

    private func beginFoodHover() {
        guard !isToiletLocked else {
            isFoodHoveringOverCharacter = false
            syncCharacterBaseFromState(force: true)
            return
        }

        isFoodHoveringOverCharacter = true

        guard canPlayCharacterAnimation else {
            characterAssetName = preferredCharacterRestAssetName
            return
        }

        guard !isCharacterActionRunning else { return }

        let base = currentBaseAssetName
        characterAssetName = isSatisfactionMax ? "\(base)_burp" : "\(base)_hungry"
    }

    private func endFoodHoverIfNeeded() {
        guard isFoodHoveringOverCharacter else { return }
        isFoodHoveringOverCharacter = false

        guard !isCharacterActionRunning else { return }

        characterAssetName = preferredCharacterRestAssetName
    }

    private func closeFoodShelf() {
        guard showFoodShelf else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            showFoodShelf = false
        }
    }

    private func maybeSpawnBathFlag(state: AppState, now: Date = Date()) {
        let didRaise = state.raiseBathFlagIfNeeded(now: now)
        if didRaise {
            save()
            syncBathOverlayFromState(animated: true)
            toast("よごれちゃった！")
        }
    }

    private func maybeSpawnToiletFlag(state: AppState, now: Date = Date()) {
        let didRaise = state.raiseToiletFlag(now: now)
        if didRaise {
            save()
            toast("トイレ行きたい！")
            syncCharacterBaseFromState(force: true)
            updateToiletWiggle()
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

                if isFoodHoveringOverCharacter {
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
                if isFoodHoveringOverCharacter { continue }
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
                    if isFoodHoveringOverCharacter { continue }
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
        guard !isFoodHoveringOverCharacter else { return }
        guard canPlayTapAnimation else { return }

        Task { await playJump() }
    }

    private func playBlink() async {
        guard isHomeVisible else { return }
        guard !isCharacterActionRunning else { return }
        guard !isToiletLocked else { return }
        guard !isFoodHoveringOverCharacter else { return }

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
        if isFoodHoveringOverCharacter { return }

        await MainActor.run { characterAssetName = blink2 }
        try? await Task.sleep(nanoseconds: 60_000_000)
        if isCharacterActionRunning || !isHomeVisible { return }
        if isToiletLocked { return }
        if isFoodHoveringOverCharacter { return }

        await MainActor.run { characterAssetName = blink1 }
        try? await Task.sleep(nanoseconds: 70_000_000)
        if isCharacterActionRunning || !isHomeVisible { return }
        if isToiletLocked { return }
        if isFoodHoveringOverCharacter { return }

        await MainActor.run { characterAssetName = preferredCharacterRestAssetName }
    }

    private func playJump() async {
        guard isHomeVisible else { return }
        guard !isCharacterActionRunning else { return }
        guard !isToiletLocked else { return }
        guard !isFoodHoveringOverCharacter else { return }

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

        if isFoodHoveringOverCharacter {
            await MainActor.run { beginFoodHover() }
        }
    }

    private func handleFoodDrop(foodId: String, state: AppState) -> Bool {
        defer {
            closeFoodShelf()
            endFoodHoverIfNeeded()
        }

        guard !isToiletLocked else {
            showToiletLockedMessage()
            return false
        }

        guard let food = FoodCatalog.byId(foodId) else {
            toast("ご飯が見つかりません")
            return false
        }

        let check = state.canFeedNow(now: Date())
        guard check.can else {
            toast(check.reason ?? "今はご飯できません")
            return false
        }

        guard state.foodCount(foodId: foodId) > 0 else {
            toast("そのご飯は所持していません")
            return false
        }

        let ok = state.consumeFood(foodId: foodId, count: 1)
        guard ok else {
            toast("消費に失敗しました")
            return false
        }

        let fed = state.feedOnce(now: Date())
        guard fed.didFeed else {
            toast(fed.reason ?? "今はご飯できません")
            return false
        }

        let isSuperFavorite = isSuperFavoriteFood(foodId: food.id, petID: state.normalizedCurrentPetID)
        let basePoint = 10
        let gainedPoint = isSuperFavorite ? (basePoint * 2) : basePoint

        if isSuperFavorite {
            state.revealSuperFavorite(petID: state.normalizedCurrentPetID)
        }

        save()

        displayedSatisfaction = fed.after
        updateSatisfactionCountdown(now: Date())
        addFriendshipWithAnimation(points: gainedPoint, state: state)
        playFeedSound(isSuperFavorite: isSuperFavorite)

        if isSuperFavorite {
            toast("\(food.name)をあげた！ 大好物だ！ +\(gainedPoint)")
            playSuperFavoriteReactionIfPossible()
        } else {
            toast("\(food.name)をあげた！ +\(gainedPoint)")
        }

        return true
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

        endFoodHoverIfNeeded()

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

        // ✅ 仕様変更:
        // なかよし度MAX到達時に獲得した分の「もじゃ」を AppState に反映する
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
                sortBy: [SortDescriptor(\TodayPhotoEntry.date, order: .reverse)]
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

        Task { @MainActor in
            Haptics.rattle(duration: 0.12, style: .light)
        }

        if showFoodShelf {
            closeFoodShelf()
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) {
            showFoodShelf = true
        }
    }

    private func onTapBath(state: AppState) {
        guard !isToiletLocked else {
            showToiletLockedMessage()
            return
        }

        guard state.hasBathFlag else {
            toast("今はまだおふろしなくて大丈夫")
            Task { @MainActor in
                Haptics.rattle(duration: 0.12, style: .light)
            }
            return
        }

        guard !isBathCleaningAnimationRunning else { return }
        isBathCleaningAnimationRunning = true

        bgmManager.playSE(.bath)

        withAnimation(.easeInOut(duration: Layout.bathFadeOutDuration)) {
            bathOverlayOpacity = 0.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Layout.bathFadeOutDuration) {
            let didResolve = state.resolveBath(now: Date())
            if didResolve {
                addFriendshipWithAnimation(points: 20, state: state)
                toast("おふろできれいになった！ +20")
                save()
            }

            showBathOverlay = false
            isBathCleaningAnimationRunning = false
            syncBathOverlayFromState(animated: false)
            updateWidgetSnapshot(forceReload: true)
        }
    }

    private func onTapToilet(state: AppState) {
        if state.hasToiletFlag {
            bgmManager.playSE(.wc)
            resolveToilet(state: state)
            syncCharacterBaseFromState(force: true)
            updateToiletWiggle()
            return
        }

        Task { @MainActor in
            Haptics.rattle(duration: 0.18, style: .light)
        }
    }

    private func onTapStep() {
        bgmManager.playSE(.open)
        showStepEnjoy = true
    }

    private func resolveToilet(state: AppState) {
        let r = state.resolveToilet(now: Date())
        guard r.didResolve else { return }

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
            updateSatisfactionCountdown(now: now)
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
        todayKcal  = shouldProtectKcal ? previousCachedKcal : fetchedKcal

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
    // ⚠️ Widget 側と同じ App Group ID を設定してください
    static let appGroupID = "group.com.shota.CalPet"
    static let widgetKind = "CalPetMediumWidget"

    private static let toiletFlagKey = "toiletFlag"
    private static let bathFlagKey = "bathFlag"
    private static let currentPetIDKey = "currentPetID"
    private static let todayStepsKey = "todaySteps"

    // ✅ アプリ未起動中でも Widget 側で状態判定できるように care 関連時刻も保存
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

private struct SatisfactionMeter: View {
    let level: Int
    let maxLevel: Int
    let barWidth: CGFloat
    let height: CGFloat
    let gap: CGFloat
    let cornerRadius: CGFloat

    let iconAssetName: String
    let iconSize: CGFloat
    let iconSpacing: CGFloat
    let countdownText: String

    private var clamped: Int { min(max(0, level), maxLevel) }

    var body: some View {
        let segments = max(1, maxLevel)
        let totalGap = gap * CGFloat(max(0, segments - 1))
        let segWidth = (barWidth - totalGap) / CGFloat(segments)
        let countdownIndex = max(0, clamped - 1)

        HStack(spacing: iconSpacing) {
            Image(iconAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)

            HStack(spacing: gap) {
                ForEach(0..<segments, id: \.self) { idx in
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(idx < clamped ? Color.green.opacity(0.95) : Color.black.opacity(0.55))
                            .frame(width: segWidth, height: height)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(Color.black.opacity(0.35), lineWidth: 1)
                            )

                        if clamped > 0, idx == countdownIndex {
                            Text(countdownText)
                                .font(.system(size: HomeView.Layout.satisfactionCountdownFont, weight: .bold))
                                .foregroundStyle(.black)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 2)
                        }
                    }
                }
            }
            .frame(width: barWidth, height: height, alignment: .leading)
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

    let onBath: () -> Void
    let onFood: () -> Void
    let onWc: () -> Void
    let onStep: () -> Void

    let isBathAvailable: Bool
    let isFoodAvailable: Bool
    let isWcAvailable: Bool

    let isToiletLocked: Bool
    let onBlocked: () -> Void

    let buttonSize: CGFloat
    let spacing: CGFloat
    let horizontalPadding: CGFloat

    private var bathImageName: String { isBathAvailable ? "bath_button_on" : "bath_button" }
    private var foodImageName: String { isFoodAvailable ? "food_button_on" : "food_button" }
    private var wcImageName: String { isToiletLocked ? "wc_button_on" : "wc_button" }

    var body: some View {
        HStack(spacing: spacing) {
            Button(action: {
                bgmManager.playSE(.push)
                if isToiletLocked {
                    onBlocked()
                } else {
                    onBath()
                }
            }) {
                Image(bathImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
            }

            Button(action: {
                bgmManager.playSE(.push)
                if isToiletLocked {
                    onBlocked()
                } else {
                    onFood()
                }
            }) {
                Image(foodImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
            }

            Button(action: {
                bgmManager.playSE(.push)
                onWc()
            }) {
                Image(wcImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
            }

            Button(action: {
                bgmManager.playSE(.push)
                if isToiletLocked {
                    onBlocked()
                } else {
                    onStep()
                }
            }) {
                Image("step_button")
                    .resizable()
                    .scaledToFit()
                    .frame(width: buttonSize, height: buttonSize)
            }
        }
        .padding(.horizontal, horizontalPadding)
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

private struct FoodShelfPanel: View {
    let state: AppState

    @State private var currentPage: Int = 0

    private var ownedFoods: [FoodCatalog.FoodItem] {
        FoodCatalog.all.filter { state.foodCount(foodId: $0.id) > 0 }
    }

    private var pages: [[FoodCatalog.FoodItem]] {
        chunked(ownedFoods, size: 3)
    }

    private var pageCount: Int { pages.count }
    private var canGoPrev: Bool { currentPage > 0 }
    private var canGoNext: Bool { currentPage + 1 < pageCount }

    var body: some View {
        ZStack {
            Image("gohan_telop")
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .clipped()

            if ownedFoods.isEmpty {
                Text("ご飯がありません（ショップで購入してください）")
                    .font(.footnote)
                    .foregroundStyle(.black.opacity(0.75))
                    .padding(.horizontal, 12)
            } else {
                ZStack {
                    TabView(selection: $currentPage) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { idx, foods in
                            HStack(spacing: 12) {
                                ForEach(foods) { food in
                                    FoodItemCell(
                                        food: food,
                                        count: state.foodCount(foodId: food.id)
                                    )
                                }
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: pageCount) { _, _ in
                        if currentPage >= pageCount {
                            currentPage = max(0, pageCount - 1)
                        }
                    }

                    HStack {
                        arrowButton(systemName: "chevron.left", enabled: canGoPrev) {
                            guard canGoPrev else { return }
                            withAnimation(.easeInOut(duration: 0.18)) {
                                currentPage -= 1
                            }
                        }

                        Spacer()

                        arrowButton(systemName: "chevron.right", enabled: canGoNext) {
                            guard canGoNext else { return }
                            withAnimation(.easeInOut(duration: 0.18)) {
                                currentPage += 1
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }
        }
        .frame(height: HomeView.Layout.foodShelfHeight)
    }

    private func chunked<T>(_ items: [T], size: Int) -> [[T]] {
        guard size > 0, !items.isEmpty else { return [] }
        var result: [[T]] = []
        var i = 0
        while i < items.count {
            let end = min(i + size, items.count)
            result.append(Array(items[i..<end]))
            i = end
        }
        return result
    }

    @ViewBuilder
    private func arrowButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(enabled ? Color.black.opacity(0.85) : Color.gray.opacity(0.55))
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(enabled ? 0.72 : 0.35))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.black.opacity(enabled ? 0.28 : 0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.85)
        .contentShape(Circle())
    }
}

private struct FoodItemCell: View {
    let food: FoodCatalog.FoodItem
    let count: Int

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(food.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: HomeView.Layout.foodItemSize, height: HomeView.Layout.foodItemSize)
                .padding(6)
                .background(Color.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.black.opacity(0.45), lineWidth: 2)
                )
                .draggable(food.id) {
                    Image(food.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: HomeView.Layout.foodItemSize, height: HomeView.Layout.foodItemSize)
                }

            Text("x\(count)")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.85))
                .clipShape(Capsule())
                .padding(6)
        }
    }
}
