//
//  MemoTutorialGachaView.swift
//  MeMo
//
//  Mandatory onboarding-only gacha screen.
//  This first 10-pull is ad-free and guarantees one random gacha character.
//  iOS 18.6+
//

import SwiftUI

struct MemoTutorialGachaView: View {
    let state: AppState
    let onFinish: () -> Void

    @State private var phase: Phase = .intro
    @State private var rewards: [MemoTutorialGachaRewardModel] = []
    @State private var isButtonPulsing: Bool = false
    @State private var rollTask: Task<Void, Never>?

    private enum Phase: Equatable {
        case intro
        case rolling
        case result
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background

                VStack(spacing: 0) {
                    Spacer(minLength: max(proxy.safeAreaInsets.top + 18, 34))

                    Text("ガチャ")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(radius: 8)

                    Spacer(minLength: 18)

                    switch phase {
                    case .intro:
                        introContent
                            .padding(.horizontal, 22)
                    case .rolling:
                        rollingContent
                            .padding(.horizontal, 22)
                    case .result:
                        resultContent(proxy: proxy)
                            .padding(.horizontal, 18)
                    }

                    Spacer(minLength: max(proxy.safeAreaInsets.bottom + 18, 28))
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            state.memoMarkFirstVisitFreeTenDrawOffered()
            withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                isButtonPulsing = true
            }
        }
        .onDisappear {
            rollTask?.cancel()
            rollTask = nil
        }
    }

    private var background: some View {
        ZStack {
            Image("gacha_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.58)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var introContent: some View {
        VStack(spacing: 22) {
            Image("gatyaMachine")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 280)
                .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 10)

            teacherCard(
                title: "今回は特別だよ！",
                message: "無料で10回引けるようにしておいたよ。\n広告もなし。試しに引いてみよう！"
            )

            Button(action: startFreeTenDraw) {
                VStack(spacing: 5) {
                    Text("はじめて特典")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white.opacity(0.88))

                    Text("無料で10回引く")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.white)

                    Text("キャラクターが1体かならず出るよ")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 82)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.orange.gradient)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white, lineWidth: 3)
                        .scaleEffect(isButtonPulsing ? 1.07 : 0.96)
                        .shadow(color: .white.opacity(0.86), radius: 16)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
        }
        .frame(maxWidth: 380)
        .frame(maxWidth: .infinity)
    }

    private var rollingContent: some View {
        VStack(spacing: 22) {
            ProgressView()
                .controlSize(.large)
                .tint(.white)

            Text("ガチャを回しているよ…")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(.white)

            Text("どんな仲間に出会えるかな？")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(24)
        .frame(maxWidth: 340)
        .background(Color.black.opacity(0.36), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func resultContent(proxy: GeometryProxy) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                teacherCard(
                    title: "すごい！",
                    message: "キャラクターをゲットしたみたい！\n早速お世話してみよう！"
                )

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                    spacing: 10
                ) {
                    ForEach(rewards) { reward in
                        rewardCard(reward)
                    }
                }
                .frame(maxWidth: 360)

                Button(action: onFinish) {
                    Text("お世話しにいこう！")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: 360)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, max(proxy.safeAreaInsets.bottom, 16) + 12)
        }
    }

    private func rewardCard(_ reward: MemoTutorialGachaRewardModel) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(reward.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 92)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                if reward.isCharacter {
                    Text("SR")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange, in: Capsule())
                        .padding(8)
                }
            }

            VStack(spacing: 3) {
                Text(reward.title)
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(reward.subtitle)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
        .frame(minHeight: 156)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(reward.isCharacter ? Color.orange : Color.white.opacity(0.35), lineWidth: reward.isCharacter ? 3 : 1)
        )
    }

    private func teacherCard(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("👩‍🏫")
                    .font(.system(size: 26))

                Text(title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }

            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: 360, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
    }

    private func startFreeTenDraw() {
        guard phase == .intro else { return }
        phase = .rolling

        rollTask?.cancel()
        rollTask = Task {
            try? await Task.sleep(nanoseconds: 1_150_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                rewards = state.memoAwardTutorialFreeTenGachaRewards()
                phase = .result
            }
        }
    }
}

#if DEBUG
#Preview("Tutorial Gacha Placeholder") {
    Text("Preview requires AppState from the app runtime")
        .padding()
}
#endif
