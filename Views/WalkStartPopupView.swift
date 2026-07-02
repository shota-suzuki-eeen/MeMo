//
//  WalkStartPopupView.swift
//  MeMo
//
//  HomeView の menu_button 内 walk_button から呼び出す開始確認ポップアップ。
//  2026/07 update: AdMob一時停止モード中だけ広告なしスタート表示にし、
//  通常モード中は広告視聴ボタンとロード中スピナーを表示。
//

import SwiftUI
import UIKit

struct WalkStartPopupView: View {
    let isRainy: Bool
    let canUseRainFreeStart: Bool
    let isAdReady: Bool
    let isAdLoading: Bool
    let onLater: () -> Void
    let onStartWithAd: () -> Void
    let onStartRainFree: () -> Void

    @ObservedObject private var adMobManager = AdMobManager.shared

    private var isTemporaryPauseMode: Bool {
        adMobManager.isAdMobTemporaryPauseModeActive
    }

    private var shouldDisableAdStartButton: Bool {
        if isTemporaryPauseMode {
            return !adMobManager.canGrantRewardWithoutAdInTemporaryPause
        }
        return !isAdReady
    }

    private var adStartButtonTitle: String {
        isTemporaryPauseMode ? "スタート" : "広告視聴でスタート"
    }

    private var adStartButtonSystemImageName: String? {
        isTemporaryPauseMode ? nil : "play.rectangle.fill"
    }

    private var shouldShowAdStartLoadingIndicator: Bool {
        !isTemporaryPauseMode && isAdLoading
    }

    var body: some View {
        VStack(spacing: 18) {
            Image("walk_button")
                .resizable()
                .scaledToFit()
                .frame(width: 116, height: 116)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)

            VStack(spacing: 8) {
                Text("お散歩")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Text(descriptionText)
                    .font(.system(size: 15, weight: .bold))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                WalkPopupButton(
                    title: "もどる",
                    systemImageName: nil,
                    showsLoadingIndicator: false,
                    isPrimary: false,
                    isEnabled: true,
                    action: onLater
                )

                if canUseRainFreeStart {
                    WalkPopupButton(
                        title: "スタート",
                        systemImageName: nil,
                        showsLoadingIndicator: false,
                        isPrimary: true,
                        isEnabled: true,
                        action: onStartRainFree
                    )
                } else {
                    WalkPopupButton(
                        title: adStartButtonTitle,
                        systemImageName: adStartButtonSystemImageName,
                        showsLoadingIndicator: shouldShowAdStartLoadingIndicator,
                        isPrimary: true,
                        isEnabled: !shouldDisableAdStartButton,
                        action: onStartWithAd
                    )
                }
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

    private var descriptionText: String {
        if canUseRainFreeStart {
            return "1回チャレンジできます。\n5分間、タップするたびに歩数通貨を獲得できます。"
        }

        if isRainy {
            return "5分間チャレンジできます。\n雨の日の無料チャレンジは今日は使用済みです。"
        }

        return "5分間チャレンジできます。\nタップするたびに歩数通貨を獲得できます。"
    }
}

private struct WalkPopupButton: View {
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
        .accessibilityHint("")
    }
}
