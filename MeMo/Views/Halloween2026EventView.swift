//
//  Halloween2026EventView.swift
//  MeMo
//
//  期間限定ランイベントのトップ画面。
//

import SwiftUI
import SwiftData

struct Halloween2026EventView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bgmManager: BGMManager

    let state: AppState
    @ObservedObject var store: Halloween2026EventStore
    let onRunGameActiveChanged: (Bool) -> Void

    @State private var showRewardWindow = false
    @State private var showRunGame = false
    @State private var showExchange = false

    init(
        state: AppState,
        store: Halloween2026EventStore,
        onRunGameActiveChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.state = state
        _store = ObservedObject(wrappedValue: store)
        self.onRunGameActiveChanged = onRunGameActiveChanged
    }

    var body: some View {
        Group {
            if showRunGame {
                // ゲーム中はイベントトップのTimelineView・背景Blur等も描画しない。
                Color.black
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            } else {
                eventTopContent
            }
        }
        .ignoresSafeArea()
        .fullScreenCover(
            isPresented: $showRunGame,
            onDismiss: {
                onRunGameActiveChanged(false)
            }
        ) {
            HalloweenRunGameView(
                store: store,
                onClose: {
                    showRunGame = false
                }
            )
            .environmentObject(bgmManager)
            .memoIPadPresentedPhoneCanvas()
        }
        .fullScreenCover(isPresented: $showExchange) {
            Halloween2026ExchangeView(state: state, store: store)
                .environmentObject(bgmManager)
                .memoIPadPresentedPhoneCanvas()
        }
        .onAppear {
            bgmManager.switchBackground(to: .fishing)
        }
        .onDisappear {
            // ランゲームのfullScreenCover表示による一時的なDisappearでは
            // BGMをmainへ戻さない。
            if !showRunGame {
                bgmManager.switchBackground(to: .main)
            }
        }
    }

    private var eventTopContent: some View {
        TimelineView(.periodic(from: Date(), by: 15)) { timeline in
            ZStack {
                background

                if EventManager.isActive(.halloween2026, at: timeline.date) {
                    activeContent
                } else {
                    endedContent
                }

                if showRewardWindow {
                    Halloween2026RewardWindow(
                        state: state,
                        store: store,
                        onClose: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showRewardWindow = false
                            }
                        }
                    )
                    .zIndex(20_000)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.05, blue: 0.20),
                    Color(red: 0.26, green: 0.08, blue: 0.30),
                    Color(red: 0.08, green: 0.04, blue: 0.16),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.orange.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 8)
                .offset(x: 150, y: -310)

            Circle()
                .fill(Color.purple.opacity(0.20))
                .frame(width: 320, height: 320)
                .blur(radius: 20)
                .offset(x: -170, y: 310)
        }
        .ignoresSafeArea()
    }

    private var activeContent: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 18)
                .padding(.top, 54)

            scoreHeader
                .padding(.horizontal, 18)
                .padding(.top, 22)

            candyBalance
                .padding(.top, 14)

            Spacer(minLength: 28)

            startButton
                .padding(.horizontal, 30)

            HStack(spacing: 14) {
                rewardButton
                exchangeButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)

            Text("2026/10/31 23:59まで")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.70))
                .padding(.top, 18)

            Spacer(minLength: 36)
        }
    }

    private var topBar: some View {
        ZStack {
            HStack {
                Button {
                    bgmManager.playSE(.push)
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.36), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()
            }

            VStack(spacing: 2) {
                Text("HALLOWEEN EVENT")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                Text("CANDY RUN")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(2.0)
                    .foregroundStyle(Color.orange)
            }
            .foregroundStyle(.white)
        }
        .frame(minHeight: 48)
    }

    private var scoreHeader: some View {
        HStack(spacing: 12) {
            scoreCard(title: "BEST", value: store.bestDistance)
            scoreCard(title: "TOTAL", value: store.totalDistance)
        }
    }

    private func scoreCard(title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.66))

            Text("\(value.formatted())m")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.66)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 76)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
    }

    private var candyBalance: some View {
        HStack(spacing: 7) {
            HalloweenCandyIcon(size: 24)

            Text(store.candyCount.formatted())
                .font(.system(size: 21, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 46)
        .background(Color.black.opacity(0.34), in: Capsule())
        .overlay {
            Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("所持キャンディ \(store.candyCount)個")
    }

    private var startButton: some View {
        Button {
            bgmManager.playSE(.push)
            guard EventManager.isActive(.halloween2026) else { return }

            // fullScreenCoverの表示より先にRootへ通知し、
            // HomeViewを背面の描画ツリーから外す。
            onRunGameActiveChanged(true)
            showRunGame = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "figure.run")
                    .font(.system(size: 42, weight: .black))

                Text("START")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .tracking(1.5)

                Text("左右タップで障害物をよけよう！")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .opacity(0.86)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 174)
            .background(
                LinearGradient(
                    colors: [Color.orange, Color(red: 0.90, green: 0.28, blue: 0.20)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 32, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.40), lineWidth: 2)
            }
            .shadow(color: Color.orange.opacity(0.32), radius: 24, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }

    private var rewardButton: some View {
        Button {
            bgmManager.playSE(.push)
            withAnimation(.easeInOut(duration: 0.18)) {
                showRewardWindow = true
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                eventSubButtonLabel(title: "報酬", systemImage: "gift.fill")

                if store.hasClaimableReward {
                    EventNotificationBadge()
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.hasClaimableReward ? "報酬、受け取り可能な報酬があります" : "報酬")
    }

    private var exchangeButton: some View {
        Button {
            bgmManager.playSE(.push)
            guard EventManager.isActive(.halloween2026) else { return }
            showExchange = true
        } label: {
            eventSubButtonLabel(title: "交換所", systemImage: "arrow.left.arrow.right")
        }
        .buttonStyle(.plain)
    }

    private func eventSubButtonLabel(title: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 25, weight: .black))

            Text(title)
                .font(.system(size: 16, weight: .black, design: .rounded))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 92)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
    }

    private var endedContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 58, weight: .bold))
                .foregroundStyle(.orange)

            Text("イベントは終了しました")
                .font(.system(size: 25, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            Text("ゲーム・報酬受取・交換所は\n2026/10/31で終了しました。")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.76))
                .multilineTextAlignment(.center)

            Button {
                dismiss()
            } label: {
                Text("ホームへ戻る")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .frame(minHeight: 50)
                    .background(Color.orange, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(28)
        .background(Color.black.opacity(0.40), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(.horizontal, 30)
    }
}
