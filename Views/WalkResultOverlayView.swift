//
//  WalkResultOverlayView.swift
//  MeMo
//
//  お散歩終了時に中央表示するリザルトオーバーレイ。
//  2026/06 update: 広告停止中のため、2倍獲得を広告なしで実行する表記に調整。
//  2026/06 update: リザルト画面表示時点で rewardWalkDouble を画面単位プリロード。
//

import SwiftUI

struct WalkResultOverlayView: View {
    let result: WalkChallengeResult
    let onClaim: (_ multiplier: Int) -> Void
    let onCancel: (() -> Void)?

    init(
        result: WalkChallengeResult,
        onClaim: @escaping (_ multiplier: Int) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        self.result = result
        self.onClaim = onClaim
        self.onCancel = onCancel
    }

    @EnvironmentObject private var bgmManager: BGMManager
    @ObservedObject private var doubleRewardAd = AdMobManager.shared.rewardWalkDouble

    @State private var displayedSteps: Int = 0
    @State private var didDoubleReward: Bool = false
    @State private var isAnimatingDoubleCountUp: Bool = false
    @State private var isClaiming: Bool = false
    @State private var messageText: String?

    private var doubleRewardButtonTitle: String {
        doubleRewardAd.isReady ? "2倍獲得" : "広告を準備中"
    }

    private var canUseDoubleRewardButton: Bool {
        !isClaiming && !isAnimatingDoubleCountUp && doubleRewardAd.isReady
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image("walk_button")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 116, height: 116)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)

                VStack(spacing: 8) {
                    Text("お散歩リザルト")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)

                    VStack(spacing: 4) {
                        Text("\(displayedSteps)")
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText(value: Double(displayedSteps)))

                        Text("歩 獲得！")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(.secondary)

                        if didDoubleReward {
                            Text("（\(result.baseSteps) + \(result.baseSteps)）")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }

                if let messageText {
                    Text(messageText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    WalkResultButton(
                        title: "OK",
                        systemImageName: nil,
                        isPrimary: false,
                        isEnabled: !isClaiming && !isAnimatingDoubleCountUp,
                        action: claimNormal
                    )

                    WalkResultButton(
                        title: doubleRewardButtonTitle,
                        systemImageName: doubleRewardAd.isReady ? "play.rectangle.fill" : "arrow.triangle.2.circlepath",
                        isPrimary: true,
                        isEnabled: canUseDoubleRewardButton,
                        action: claimDoubleWithAd
                    )
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: 342)
            .background(
                Image("blue_block")
                    .resizable(capInsets: EdgeInsets(top: 28, leading: 28, bottom: 28, trailing: 28), resizingMode: .stretch)
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 14)
            .overlay(alignment: .topLeading) {
                if let onCancel {
                    Button {
                        bgmManager.playSE(.push)
                        onCancel()
                    } label: {
                        Image("close_button")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 46, height: 46)
                            .shadow(color: .black.opacity(0.20), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isClaiming || isAnimatingDoubleCountUp)
                    .opacity(isClaiming || isAnimatingDoubleCountUp ? 0.45 : 1)
                    .offset(x: -12, y: -12)
                    .accessibilityLabel("終了をキャンセル")
                }
            }
            .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
        .onAppear {
            displayedSteps = result.baseSteps
            AdMobManager.shared.prepareRewardWalkDouble()
        }
    }

    private func claimNormal() {
        guard !isClaiming else { return }
        isClaiming = true
        bgmManager.playSE(.push)
        onClaim(1)
    }

    private func claimDoubleWithAd() {
        guard !isClaiming else { return }
        guard doubleRewardAd.isReady else {
            messageText = "広告を準備中です。少し待ってからもう一度お試しください。"
            AdMobManager.shared.prepareRewardWalkDouble()
            return
        }

        isClaiming = true
        messageText = nil
        bgmManager.playSE(.push)

        doubleRewardAd.show {
            Task { @MainActor in
                await runDoubleCountUpAndClaim()
            }
        } onUnavailable: {
            Task { @MainActor in
                isClaiming = false
                messageText = "現在利用できません。少し待ってからもう一度お試しください。"
                AdMobManager.shared.prepareRewardWalkDouble()
            }
        }
    }

    @MainActor
    private func runDoubleCountUpAndClaim() async {
        didDoubleReward = true
        isAnimatingDoubleCountUp = true

        let start = result.baseSteps
        let end = result.doubledSteps
        let delta = max(0, end - start)

        guard delta > 0 else {
            displayedSteps = end
            isAnimatingDoubleCountUp = false
            onClaim(2)
            return
        }

        let steps = min(max(delta, 1), 80)
        for index in 1...steps {
            let progress = Double(index) / Double(steps)
            let eased = 1 - pow(1 - progress, 3)
            displayedSteps = start + Int((Double(delta) * eased).rounded())
            try? await Task.sleep(nanoseconds: 18_000_000)
        }

        displayedSteps = end
        try? await Task.sleep(nanoseconds: 260_000_000)
        isAnimatingDoubleCountUp = false
        onClaim(2)
    }
}

private struct WalkResultButton: View {
    let title: String
    let systemImageName: String?
    let isPrimary: Bool
    let isEnabled: Bool
    let action: () -> Void

    private var buttonBackgroundColor: Color {
        isPrimary
        ? Color(red: 0.92, green: 0.15, blue: 0.14)
        : Color.white.opacity(0.72)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImageName {
                    Image(systemName: systemImageName)
                        .font(.system(size: 15, weight: .black))
                }

                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isPrimary ? .white : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(buttonBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(isPrimary ? 0.34 : 0.42), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }
}
