//
//  SleepModePopupView.swift
//  MeMo
//
//  おやすみモード開始確認・残り時間表示用ポップアップ。
//  2026/07 update: AdMob一時停止モード中だけ広告なし開始/リセット表示にし、
//  通常モード中は広告視聴ボタンとロード中スピナーを表示。
//

import SwiftUI

struct SleepModePopupView: View {
    let remainingSeconds: TimeInterval
    let isSleepModeActive: Bool
    let isAdReady: Bool
    let isAdLoading: Bool
    let message: String?
    let onLater: () -> Void
    let onStartWithAd: () -> Void
    let onResetWithAd: () -> Void

    @ObservedObject private var adMobManager = AdMobManager.shared

    private var safeRemainingSeconds: Int {
        max(0, Int(ceil(remainingSeconds)))
    }

    private var hours: Int {
        safeRemainingSeconds / 3600
    }

    private var minutes: Int {
        (safeRemainingSeconds % 3600) / 60
    }

    private var seconds: Int {
        safeRemainingSeconds % 60
    }

    private var isTemporaryPauseMode: Bool {
        adMobManager.isAdMobTemporaryPauseModeActive
    }

    private var isRewardButtonEnabled: Bool {
        if isTemporaryPauseMode {
            return adMobManager.canGrantRewardWithoutAdInTemporaryPause
        }
        return isAdReady
    }

    private var rewardedButtonTitle: String {
        if isTemporaryPauseMode { return "リセット" }
        return "広告視聴でリセット"
    }

    private var startButtonTitle: String {
        if isTemporaryPauseMode { return "スタート" }
        return "広告視聴でスタート"
    }

    private var rewardedButtonSystemImageName: String? {
        isTemporaryPauseMode ? nil : "play.rectangle.fill"
    }

    private var shouldShowAdLoadingIndicator: Bool {
        !isTemporaryPauseMode && isAdLoading
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(isSleepModeActive ? "sleep_button_on" : "sleep_button_off")
                .resizable()
                .scaledToFit()
                .frame(width: 116, height: 116)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)

            VStack(spacing: 8) {
                Text("おやすみモード")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                if isSleepModeActive {
                    Text("”おやすみモード”中は幸せ度が下がりません。\n満腹度と幸せ度の増加はいつも通りです。")
                        .font(.system(size: 15, weight: .bold))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                } else {
                    Text("8時間幸せ度が下がらなくなります。\n満腹度はいつも通り変化します。")
                        .font(.system(size: 15, weight: .bold))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }

            if isSleepModeActive {
                SleepModeTimerCard(hours: hours, minutes: minutes, seconds: seconds)
            }

            if let message {
                Text(message)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.32))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: 12) {
                SleepModePopupButton(
                    title: "もどる",
                    systemImageName: nil,
                    showsLoadingIndicator: false,
                    isPrimary: false,
                    isEnabled: true,
                    action: onLater
                )

                if isSleepModeActive {
                    SleepModePopupButton(
                        title: rewardedButtonTitle,
                        systemImageName: rewardedButtonSystemImageName,
                        showsLoadingIndicator: shouldShowAdLoadingIndicator,
                        isPrimary: true,
                        isEnabled: isRewardButtonEnabled,
                        action: onResetWithAd
                    )
                } else {
                    SleepModePopupButton(
                        title: startButtonTitle,
                        systemImageName: rewardedButtonSystemImageName,
                        showsLoadingIndicator: shouldShowAdLoadingIndicator,
                        isPrimary: true,
                        isEnabled: isRewardButtonEnabled,
                        action: onStartWithAd
                    )
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .frame(maxWidth: 342)
        .background(
            Image("purple_block")
                .resizable(capInsets: EdgeInsets(top: 28, leading: 28, bottom: 28, trailing: 28), resizingMode: .stretch)
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 14)
        .overlay(alignment: .topTrailing) {
            Button(action: onLater) {
                Image("close_button")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(.plain)
            .offset(x: 12, y: -12)
            .accessibilityLabel("閉じる")
        }
    }
}

private struct SleepModeTimerCard: View {
    let hours: Int
    let minutes: Int
    let seconds: Int

    var body: some View {
        VStack(spacing: 10) {
            Text("終了まで")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TimeUnitBox(value: hours, label: "時間")
                TimeUnitSeparator()
                TimeUnitBox(value: minutes, label: "分")
                TimeUnitSeparator()
                TimeUnitBox(value: seconds, label: "秒")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.38), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 5)
    }
}

private struct TimeUnitBox: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", value))
                .font(.system(size: 26, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)

            Text(label)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(width: 58, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.56))
        )
    }
}

private struct TimeUnitSeparator: View {
    var body: some View {
        Text(":")
            .font(.system(size: 24, weight: .black, design: .rounded))
            .foregroundStyle(.secondary)
            .offset(y: -7)
    }
}

private struct SleepModePopupButton: View {
    let title: String
    let systemImageName: String?
    let showsLoadingIndicator: Bool
    let isPrimary: Bool
    let isEnabled: Bool
    let action: () -> Void

    private var buttonBackgroundColor: Color {
        if !isEnabled {
            return isPrimary
            ? Color(red: 0.92, green: 0.15, blue: 0.14).opacity(0.58)
            : Color.white.opacity(0.48)
        }

        return isPrimary
        ? Color(red: 0.92, green: 0.15, blue: 0.14)
        : Color.white.opacity(0.72)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if showsLoadingIndicator {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(isPrimary ? .white : .primary)
                        .scaleEffect(0.76)
                        .frame(width: 16, height: 16)
                } else if let systemImageName {
                    Image(systemName: systemImageName)
                        .font(.system(size: 15, weight: .black))
                }

                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
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
            .shadow(color: .black.opacity(isEnabled ? 0.14 : 0.08), radius: 8, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.68)
    }
}
