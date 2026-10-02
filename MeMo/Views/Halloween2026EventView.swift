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
    @State private var showGacha = false

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
        .fullScreenCover(
            isPresented: $showRunGame,
            onDismiss: {
                onRunGameActiveChanged(false)
            }
        ) {
            HalloweenRunGameView(
                store: store,
                playerAssetName: PetMaster.assetName(for: state.normalizedCurrentPetID),
                onClose: {
                    showRunGame = false
                }
            )
            .environmentObject(bgmManager)
            .memoIPadPresentedPhoneCanvas()
        }
        .fullScreenCover(isPresented: $showGacha) {
            Halloween2026GachaView(store: store, state: state)
                .environmentObject(bgmManager)
                .memoIPadPresentedPhoneCanvas()
        }
        .statusBarHidden()
        .onAppear {
            if !showRunGame { store.recoverInterruptedSession() }
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

                if EventManager.areRewardsAvailable(.halloween2026, at: timeline.date) {
                    activeContent(at: timeline.date)
                } else {
                    endedContent
                }

                if showRewardWindow {
                    HalloweenEventBackground(assetName: "halloween_shop")
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
        HalloweenEventBackground(assetName: "halloween_main")
    }

    private func activeContent(at date: Date) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                topBar
                VStack(spacing: 10) {
                    Text(store.endlessUnlocked ? "全25面クリア · ENDLESS 解放済み" : "STAGE \(store.currentStageNumber) / 25\(store.nextRunMode == .bonus ? " · BONUS" : "")")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                    let level = store.endlessUnlocked ? 1 : Halloween2026Configuration.level(forStage: store.currentStageNumber)
                    Text("現在 Lv\(level)").font(.headline)
                    HalloweenLevelPumpkins(level: level)
                    if store.endlessUnlocked { Text("毎回Lv1からスタート").font(.caption) }
                }.foregroundStyle(.white).padding(18).frame(maxWidth: .infinity)
                    .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 24))
                scoreHeader
                candyBalance
                startButton
                if !EventManager.isActive(.halloween2026, at: date) {
                    Text("ミニゲームは終了しました。\nガチャ・未受取報酬は11/7まで利用できます。")
                        .font(.subheadline.bold()).foregroundStyle(.white).multilineTextAlignment(.center)
                }
                HStack(spacing: 14) { rewardButton; gachaButton }
                Text("ゲーム：10/31まで\nガチャ・報酬受取：11/7まで（日本時間）")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.center)
            }.padding(.horizontal, 20).padding(.vertical, 12)
                .frame(maxWidth: 520).frame(maxWidth: .infinity)
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
                    .font(.system(size: 28, weight: .black))

                Text(store.endlessUnlocked ? "ENDLESS" : (store.nextRunMode == .bonus ? "BONUS" : "START"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .tracking(1.5)

                Text(store.nextRunMode == .bonus ? "20秒間、キャンディを集めよう！" : (store.endlessUnlocked ? "左右タップで記録に挑戦！" : "30秒間、障害物をよけよう！"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .opacity(0.86)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 126)
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
        .disabled(!EventManager.isActive(.halloween2026))
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

    private var gachaButton: some View {
        Button {
            bgmManager.playSE(.push)
            guard EventManager.areRewardsAvailable(.halloween2026) else { return }
            showGacha = true
        } label: {
            eventSubButtonLabel(title: "イベントガチャ", systemImage: "sparkles")
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
        .frame(maxWidth: .infinity, minHeight: 82)
        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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

            Text("ミニゲームは10/31、ガチャ・報酬受取は\n11/7で終了しました。\n所持キャンディは保存されています。")
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
