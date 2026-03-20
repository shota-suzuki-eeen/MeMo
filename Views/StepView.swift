//
//  StepView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import SwiftUI

struct StepView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bgmManager: BGMManager
    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false

    let state: AppState
    @ObservedObject var hk: HealthKitManager
    let onSave: () -> Void

    @StateObject private var viewModel = StepViewModel()

    // ✅ StepEnjoy 用リワード広告
    // 一旦 AdMob 周りを止めるためコメントアウト
    // @StateObject private var rewardedAd = RewardedAdManager(adUnitID: AdUnitID.rewardStepEnjoy)

    // ✅ 歩行中だけ揺らす
    @State private var isWalking = false
    @State private var stopWalkingWorkItem: DispatchWorkItem?

    // ✅ 表示用歩数（画面表示後にカウントアップ）
    @State private var displayedDayTotalSteps: Int = 0

    // ✅ 初回ロード多重防止
    @State private var didAppearOnce: Bool = false

    // ✅ 報酬ポップアップ
    @State private var selectedRewardIndex: Int? = nil
    @State private var showRewardPopup: Bool = false

    private var currentPetAsset: String {
        PetMaster.assetName(for: state.currentPetID)
    }

    private var rewardThreshold: Int {
        StepRewardPolicy.rewardStepThreshold
    }

    private var rewardMaxCount: Int {
        StepRewardPolicy.dailyRewardMaxCount
    }

    /// ✅ CameraCaptureView 側と揃えるための「今日の合計歩数」
    /// - hk.todaySteps を優先
    /// - 未反映/0 のときは state のキャッシュも保険で使う
    private var unifiedTodayTotalSteps: Int {
        max(hk.todaySteps, state.cachedTodaySteps)
    }

    /// ✅ 表示用進捗
    /// - 「今日歩いた実歩数」を正として扱う
    private var progressStepsForMeter: Int {
        StepRewardPolicy.cappedProgressSteps(from: displayedDayTotalSteps)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let safeH = max(1, h)

            let headerH: CGFloat = 56
            let totalStepsH: CGFloat = 64
            let verticalGaps: CGFloat = 12 + 12

            let minCardsH: CGFloat = max(210, min(270, safeH * 0.30))

            let remainingForCharacter = safeH - (headerH + totalStepsH + minCardsH + verticalGaps)
            let characterBoxH = max(170, min(340, remainingForCharacter))

            let imageSize = min(w * 0.76, characterBoxH * 1.05)

            ZStack {
                VStack(spacing: 10) {
                    header
                        .frame(height: headerH)

                    VStack(spacing: 12) {
                        // ✅ 1. 歩数
                        stepCountView
                            .frame(height: totalStepsH)

                        // ✅ 2. 報酬
                        rewardCardCompact
                            .padding(.horizontal, 18)
                            .frame(minHeight: minCardsH)

                        // ✅ 3. キャラ画像
                        Image(currentPetAsset)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageSize, height: imageSize)
                            .offset(y: isWalking ? -6 : 0)
                            .animation(
                                isWalking
                                ? .easeInOut(duration: 0.18).repeatForever(autoreverses: true)
                                : .default,
                                value: isWalking
                            )
                            .frame(height: characterBoxH)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.top, 24)

                    Color.clear.frame(height: 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .safeAreaPadding(.top, 6)
                .safeAreaPadding(.bottom, 8)

                if showRewardPopup, let rewardIndex = selectedRewardIndex {
                    RewardClaimPopup(
                        rewardIndex: rewardIndex,
                        onClose: {
                            bgmManager.playSE(.push)
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showRewardPopup = false
                                selectedRewardIndex = nil
                            }
                        },
                        onNormalReward: {
                            bgmManager.playSE(.push)
                            viewModel.claimNormalReward(state: state, save: onSave)
                            Haptics.notify(.success)

                            withAnimation(.easeInOut(duration: 0.18)) {
                                showRewardPopup = false
                                selectedRewardIndex = nil
                            }
                        },
                        onAdReward: {
                            bgmManager.playSE(.push)

                            // ✅ AdMob を一旦無効化
                            // 開発者モード時のみ広告報酬の処理を通す
                            guard isDeveloperMode else { return }

                            viewModel.claimAdReward(state: state, save: onSave)
                            Haptics.notify(.success)

                            withAnimation(.easeInOut(duration: 0.18)) {
                                showRewardPopup = false
                                selectedRewardIndex = nil
                            }
                        },
                        // ✅ AdMob無効中のため、開発者モード時のみ押せる
                        isAdReady: isDeveloperMode,
                        isDeveloperMode: isDeveloperMode
                    )
                    .transition(.opacity)
                    .zIndex(999)
                }
            }
            .frame(width: w, height: h, alignment: .top)
        }
        .background(
            ZStack {
                Image("Step_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.18)
                    .ignoresSafeArea()
            }
        )
        .task {
            guard !didAppearOnce else { return }
            didAppearOnce = true

            // ✅ AdMob の先読みは一旦停止
            // rewardedAd.load()

            await refreshOnAppear()
        }
        .onDisappear {
            stopWalkingWorkItem?.cancel()
            stopWalkingWorkItem = nil
            stopWalkingImmediately()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()

            Button("とじる") {
                bgmManager.playSE(.push)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Step Count

    private var stepCountView: some View {
        Text("\(displayedDayTotalSteps)歩")
            .font(.system(size: 38, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 18)
    }

    // MARK: - Reward Card

    private var rewardCardCompact: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("報酬")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))

                Spacer(minLength: 8)

                Text("本日の獲得数 \(state.stepEnjoyDailyRewardCount)/\(rewardMaxCount)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .monospacedDigit()
            }

            rewardMeterSection

            if state.stepEnjoyDailyRewardCount >= rewardMaxCount {
                Text("今日はこれ以上獲得できません")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
            } else {
                let remaining = StepRewardPolicy.nextRewardRemainingSteps(
                    totalWalkedSteps: displayedDayTotalSteps,
                    claimedToday: state.stepEnjoyDailyRewardCount
                )

                Text("次のプレゼントまであと \(remaining) 歩")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .monospacedDigit()
            }

            if let foodName = viewModel.gainedFoodName {
                Text("🎁 \(foodName) を獲得！")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(12)
        .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
    }

    private var rewardMeterSection: some View {
        GeometryReader { geo in
            let fullWidth = max(1, geo.size.width)
            let progressRatio = min(
                1.0,
                max(0.0, CGFloat(progressStepsForMeter) / CGFloat(StepRewardPolicy.dailyRewardStepCap))
            )
            let fillWidth = fullWidth * progressRatio

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(height: 14)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.yellow.opacity(0.95),
                                Color.orange.opacity(0.92)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(14, fillWidth), height: 14)

                ForEach(1...rewardMaxCount, id: \.self) { index in
                    let x = fullWidth * CGFloat(index) / CGFloat(rewardMaxCount)

                    rewardMarkerButton(index: index)
                        .position(x: min(max(16, x), fullWidth - 16), y: 7)
                }
            }
        }
        .frame(height: 32)
        .padding(.top, 2)
    }

    @ViewBuilder
    private func rewardMarkerButton(index: Int) -> some View {
        let claimedCount = state.stepEnjoyDailyRewardCount
        let claimable = viewModel.claimableCount

        let isAlreadyClaimed = index <= claimedCount
        let isAvailableNow = index > claimedCount && index <= (claimedCount + claimable)

        Button {
            guard isAvailableNow else { return }
            bgmManager.playSE(.push)
            selectedRewardIndex = index
            withAnimation(.easeInOut(duration: 0.18)) {
                showRewardPopup = true
            }
            Haptics.tap(style: .light)
        } label: {
            ZStack {
                Circle()
                    .fill(markerFillColor(isAlreadyClaimed: isAlreadyClaimed, isAvailableNow: isAvailableNow))
                    .frame(width: 28, height: 28)

                Image(systemName: markerSymbolName(isAlreadyClaimed: isAlreadyClaimed))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(markerForegroundColor(isAlreadyClaimed: isAlreadyClaimed, isAvailableNow: isAvailableNow))
            }
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(isAvailableNow ? 0.95 : 0.28), lineWidth: isAvailableNow ? 2 : 1)
            }
            .shadow(color: isAvailableNow ? .yellow.opacity(0.45) : .clear, radius: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailableNow)
    }

    private func markerSymbolName(isAlreadyClaimed: Bool) -> String {
        isAlreadyClaimed ? "checkmark" : "gift.fill"
    }

    private func markerFillColor(isAlreadyClaimed: Bool, isAvailableNow: Bool) -> Color {
        if isAlreadyClaimed { return Color.green.opacity(0.95) }
        if isAvailableNow { return Color.yellow.opacity(0.98) }
        return Color.white.opacity(0.24)
    }

    private func markerForegroundColor(isAlreadyClaimed: Bool, isAvailableNow: Bool) -> Color {
        if isAlreadyClaimed { return .white }
        if isAvailableNow { return .black }
        return .white.opacity(0.7)
    }

    // MARK: - Actions

    private func refreshOnAppear() async {
        viewModel.gainedFoodName = nil

        let fetchedBeforeTotal = max(0, await hk.fetchTodayStepTotal(now: Date()))
        let beforeTotal = max(unifiedTodayTotalSteps, fetchedBeforeTotal)
        displayedDayTotalSteps = beforeTotal

        await viewModel.refresh(state: state, hk: hk, save: onSave)

        let delta = max(0, viewModel.deltaSteps)

        // ✅ StepEnjoy側も CameraCaptureView 側も「今日の合計歩数」でそろえる
        let fetchedFinalTotal = max(0, await hk.fetchTodayStepTotal(now: Date()))
        let finalTotal = max(unifiedTodayTotalSteps, viewModel.dayTotalSteps, fetchedFinalTotal)

        let startValue = max(0, finalTotal - delta)
        displayedDayTotalSteps = startValue

        if delta > 0 {
            startWalking(duration: 1.2)
            await animateStepCount(from: startValue, to: finalTotal, duration: 1.2)
        } else {
            displayedDayTotalSteps = finalTotal
            stopWalkingImmediately()
        }
    }

    private func animateStepCount(from: Int, to: Int, duration: Double) async {
        let safeFrom = max(0, from)
        let safeTo = max(safeFrom, to)

        guard safeTo > safeFrom else {
            await MainActor.run {
                displayedDayTotalSteps = safeTo
            }
            return
        }

        let diff = safeTo - safeFrom
        let frames = max(12, min(48, diff))
        let stepDuration = duration / Double(frames)

        for i in 0...frames {
            let progress = Double(i) / Double(frames)
            let eased = 1.0 - pow(1.0 - progress, 3.0)
            let current = safeFrom + Int(Double(diff) * eased)

            await MainActor.run {
                displayedDayTotalSteps = min(safeTo, current)
            }

            if i != 0 && i != frames && i % 6 == 0 {
                await MainActor.run {
                    Haptics.tap(style: .light)
                }
            }

            try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
        }

        await MainActor.run {
            displayedDayTotalSteps = safeTo
        }
    }

    private func startWalking(duration: TimeInterval) {
        stopWalkingWorkItem?.cancel()

        isWalking = true

        let item = DispatchWorkItem {
            stopWalkingImmediately()
        }
        stopWalkingWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
    }

    private func stopWalkingImmediately() {
        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            isWalking = false
        }
    }
}

// MARK: - Reward Popup

private struct RewardClaimPopup: View {
    let rewardIndex: Int
    let onClose: () -> Void
    let onNormalReward: () -> Void
    let onAdReward: () -> Void
    let isAdReady: Bool
    let isDeveloperMode: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("プレゼント \(rewardIndex)")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(8)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                Text("ランダムでたべものが1つ手に入ります。")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("広告報酬を選ぶと、ランダムでたべものを獲得しつつ、さらに満足度を1つ減らしてお腹をすかせることができます。")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    Button(action: onNormalReward) {
                        Text("通常報酬")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: onAdReward) {
                        HStack(spacing: 8) {
                            Image(systemName: isDeveloperMode ? "hammer.fill" : "play.rectangle.fill")
                            Text(
                                isDeveloperMode
                                ? "開発者モード報酬"
                                : (isAdReady ? "広告報酬" : "広告機能は停止中")
                            )
                        }
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isAdReady)
                }
            }
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 24)
            .shadow(radius: 18)
        }
    }
}
