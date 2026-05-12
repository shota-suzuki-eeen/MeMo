//
//  WalkResultOverlayView.swift
//  MeMo
//
//  お散歩終了時に中央表示するリザルトオーバーレイ。
//

import SwiftUI

struct WalkResultOverlayView: View {
    let result: WalkChallengeResult
    let onClaim: (_ multiplier: Int) -> Void

    @EnvironmentObject private var bgmManager: BGMManager
    @ObservedObject private var doubleRewardAd = AdMobManager.shared.rewardWalkDouble

    @State private var displayedSteps: Int = 0
    @State private var didDoubleReward: Bool = false
    @State private var isAnimatingDoubleCountUp: Bool = false
    @State private var isClaiming: Bool = false
    @State private var messageText: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("お散歩リザルト")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                VStack(spacing: 8) {
                    Text("\(displayedSteps)")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText(value: Double(displayedSteps)))

                    Text("歩 獲得！")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.secondary)

                    if didDoubleReward {
                        Text("（\(result.baseSteps) + \(result.baseSteps)）")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.vertical, 6)

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
                        title: doubleRewardAd.isLoading && !doubleRewardAd.isReady ? "準備中" : "2倍獲得",
                        systemImageName: "play.rectangle.fill",
                        isPrimary: true,
                        isEnabled: !isClaiming && !isAnimatingDoubleCountUp,
                        action: claimDoubleWithAd
                    )
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 26)
            .frame(maxWidth: 344)
            .background(
                Image("red_block")
                    .resizable(capInsets: EdgeInsets(top: 28, leading: 28, bottom: 28, trailing: 28), resizingMode: .stretch)
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 26, x: 0, y: 15)
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
        isClaiming = true
        messageText = nil
        bgmManager.playSE(.push)

        AdMobManager.shared.rewardWalkDouble.show {
            Task { @MainActor in
                await runDoubleCountUpAndClaim()
            }
        } onUnavailable: {
            Task { @MainActor in
                isClaiming = false
                messageText = "広告の準備ができていません。少し待ってからもう一度お試しください。"
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
                ZStack {
                    Image("clay_block")
                        .resizable(capInsets: EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18), resizingMode: .stretch)
                    if isPrimary {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.18))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }
}
