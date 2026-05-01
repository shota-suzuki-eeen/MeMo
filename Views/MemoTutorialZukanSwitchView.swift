//
//  MemoTutorialZukanSwitchView.swift
//  MeMo
//
//  Mandatory onboarding-only character switch screen.
//  The first tutorial switch applies immediately without an interstitial ad.
//  iOS 18.6+
//

import SwiftUI

struct MemoTutorialZukanSwitchView: View {
    let state: AppState
    let onFinish: () -> Void

    @State private var isButtonPulsing: Bool = false

    private var petID: String {
        state.memoTutorialGachaCharacterPetID
    }

    private var petName: String {
        state.memoTutorialGachaCharacterName
    }

    private var petAssetName: String {
        state.memoTutorialGachaCharacterAssetName
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background

                VStack(spacing: 18) {
                    Spacer(minLength: max(proxy.safeAreaInsets.top + 18, 34))

                    Text("図鑑")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(radius: 8)

                    teacherCard(
                        title: "仲間を切り替えよう",
                        message: "ガチャで出会ったキャラクターは図鑑からお世話できるよ。\n今回は広告なしで切り替えられるよ。"
                    )

                    characterCard

                    Spacer(minLength: 10)

                    Button(action: switchCharacter) {
                        Text("\(petName) をお世話する")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white, lineWidth: 3)
                                    .scaleEffect(isButtonPulsing ? 1.06 : 0.97)
                                    .shadow(color: .white.opacity(0.82), radius: 14)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom + 20, 32))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            _ = state.memoAwardTutorialGachaCharacterIfNeeded()
            withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                isButtonPulsing = true
            }
        }
    }

    private var background: some View {
        ZStack {
            Image("zukan_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.54)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var characterCard: some View {
        VStack(spacing: 12) {
            Text("新しく仲間になったキャラクター")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.primary)

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.72))

                Image(petAssetName)
                    .resizable()
                    .scaledToFit()
                    .padding(28)
            }
            .frame(width: 260, height: 260)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.orange, lineWidth: 4)
            )

            Text(petName)
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.primary)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
        .padding(.horizontal, 22)
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
        .padding(.horizontal, 22)
    }

    private func switchCharacter() {
        _ = state.memoSwitchToTutorialGachaCharacter()
        onFinish()
    }
}

#if DEBUG
#Preview("Tutorial Zukan Placeholder") {
    Text("Preview requires AppState from the app runtime")
        .padding()
}
#endif
