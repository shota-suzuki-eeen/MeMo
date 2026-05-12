//
//  WalkView.swift
//  MeMo
//
//  お散歩中のタップ計測画面。
//  タイマーは WalkChallengeStore の終了時刻ベースで進むため、途中退場・アプリ終了でも停止しない。
//

import SwiftUI

struct WalkView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bgmManager: BGMManager

    let state: AppState
    let onSave: () -> Void

    @ObservedObject private var store = WalkChallengeStore.shared
    @ObservedObject private var weatherManager = WalkWeatherManager.shared

    private var isRainyPresentation: Bool {
        store.activeSession?.isRainFreeStart == true || weatherManager.isRainyToday
    }

    var body: some View {
        ZStack {
            Image(isRainyPresentation ? "park_rainny" : "park")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(isRainyPresentation ? 0.12 : 0.04)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                WalkTimerPill(text: store.formattedRemainingTime)
                    .padding(.top, 76)

                AnimatedWalkCounterView(value: store.currentTapCount)
                    .padding(.top, 4)

                Image("walk_button")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 190, height: 190)
                    .shadow(color: .black.opacity(0.24), radius: 16, x: 0, y: 10)
                    .accessibilityHidden(true)

                Button {
                    guard store.isSessionActive else { return }
                    store.registerTap()
                    bgmManager.playSE(.push)
                    Haptics.tap(style: .soft)
                } label: {
                    Image("walk_tap")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 214, height: 112)
                        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                .disabled(!store.isSessionActive)
                .scaleEffect(store.isSessionActive ? 1.0 : 0.96)
                .opacity(store.isSessionActive ? 1.0 : 0.62)
                .accessibilityLabel("タップして歩数を獲得")

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                HStack {
                    Button {
                        bgmManager.playSE(.push)
                        dismiss()
                    } label: {
                        Image("close_button")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 54, height: 54)
                            .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("閉じる")

                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 20)

                Spacer()
            }

            if !store.isSessionActive && store.pendingResult == nil {
                WalkInactiveMessageView(onClose: { dismiss() })
                    .padding(.horizontal, 20)
            }
        }
        .onAppear {
            NotificationCenter.default.post(name: .memoHideHomeBannerAd, object: nil)
            store.bootstrap()
        }
        .onDisappear {
            NotificationCenter.default.post(name: .memoShowHomeBannerAd, object: nil)
        }
    }
}

private struct WalkTimerPill: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 18, weight: .black))
            Text(text)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.54))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.58), lineWidth: 2)
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 6)
        .accessibilityLabel("残り時間 \(text)")
    }
}

private struct AnimatedWalkCounterView: View {
    let value: Int

    private var digits: [Int] {
        let clamped = max(0, value)
        let text = String(format: "%05d", clamped)
        return text.compactMap { Int(String($0)) }
    }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(digits.enumerated()), id: \.offset) { _, digit in
                DigitReelView(digit: digit)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.13, green: 0.11, blue: 0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 2)
                )
        )
        .shadow(color: .black.opacity(0.32), radius: 14, x: 0, y: 8)
        .accessibilityLabel("獲得歩数 \(value)歩")
    }
}

private struct DigitReelView: View {
    let digit: Int

    @State private var displayedDigit: Int = 0
    @State private var incomingDigit: Int = 0
    @State private var isRolling: Bool = false

    var body: some View {
        ZStack {
            Text("\(displayedDigit)")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .offset(y: isRolling ? 42 : 0)
                .opacity(isRolling ? 0 : 1)

            Text("\(incomingDigit)")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .offset(y: isRolling ? 0 : -42)
                .opacity(isRolling ? 1 : 0)
        }
        .frame(width: 42, height: 56)
        .clipped()
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .onAppear {
            displayedDigit = digit
            incomingDigit = digit
        }
        .onChange(of: digit) { _, newValue in
            guard newValue != displayedDigit else { return }
            incomingDigit = newValue
            isRolling = false

            withAnimation(.easeOut(duration: 0.105)) {
                isRolling = true
            }

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 110_000_000)
                displayedDigit = newValue
                isRolling = false
            }
        }
    }
}

private struct WalkInactiveMessageView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("お散歩は終了しました")
                .font(.system(size: 22, weight: .black, design: .rounded))

            Text("リザルトが表示されるまで少し待つか、Homeに戻って確認してください。")
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Homeへ戻る") {
                onClose()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(radius: 18)
    }
}
