//
//  MemoLimitedHappinessRewardIntroOverlay.swift
//  MeMo
//
//  Onboarding shown the first time a happiness-level limited character is claimed.
//

import SwiftUI

struct MemoLimitedHappinessRewardIntroOverlay: View {
    let onDismiss: () -> Void

    @State private var isPulsing: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let targetFrame = happinessMeterFrame(in: proxy.size)
            let bubbleWidth = min(proxy.size.width - 32, 344)
            let bubbleY = messageCenterY(in: proxy.size, targetFrame: targetFrame)

            ZStack {
                dimmingLayer(targetFrame: targetFrame)
                    .allowsHitTesting(false)

                targetHighlight(frame: targetFrame)
                    .position(x: targetFrame.midX, y: targetFrame.midY)
                    .allowsHitTesting(false)

                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()

                instructionBubble(width: bubbleWidth)
                    .position(x: proxy.size.width / 2, y: bubbleY)
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }

    private func happinessMeterFrame(in size: CGSize) -> CGRect {
        let side: CGFloat = 142
        let centerX: CGFloat = 86
        let centerY: CGFloat = 210
        return CGRect(x: centerX - side / 2, y: centerY - side / 2, width: side, height: side)
    }

    private func messageCenterY(in size: CGSize, targetFrame: CGRect) -> CGFloat {
        let preferredGap: CGFloat = 128
        let cardHalfHeight: CGFloat = 132

        if targetFrame.midY > size.height * 0.54 {
            return max(cardHalfHeight + CGFloat(18), targetFrame.minY - preferredGap)
        }

        return min(size.height - cardHalfHeight - CGFloat(18), targetFrame.maxY + preferredGap)
    }

    private func dimmingLayer(targetFrame: CGRect) -> some View {
        Color.black.opacity(0.62)
            .overlay {
                RoundedRectangle(cornerRadius: 68, style: .continuous)
                    .frame(width: targetFrame.width + 18, height: targetFrame.height + 18)
                    .position(x: targetFrame.midX, y: targetFrame.midY)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }

    private func targetHighlight(frame: CGRect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 68, style: .continuous)
                .fill(Color.white.opacity(0.001))

            RoundedRectangle(cornerRadius: 68, style: .continuous)
                .stroke(Color.white, lineWidth: 4)
                .shadow(color: .white.opacity(0.9), radius: 14)
                .scaleEffect(isPulsing ? 1.12 : 0.94)

            RoundedRectangle(cornerRadius: 68, style: .continuous)
                .stroke(Color.accentColor.opacity(0.95), lineWidth: 3)
                .scaleEffect(isPulsing ? 0.96 : 1.08)
        }
        .frame(width: frame.width, height: frame.height)
    }

    private func instructionBubble(width: CGFloat) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("👩‍🏫")
                    .font(.system(size: 24))

                Text("特別なキャラクターを獲得したよ！")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }

            Text("特別なキャラクターは、キャラクターごとに固有の幸せ度メーターを持っているよ。\n幸せレベルを上げることで、さまざまな衣装を獲得できるから、たくさんお世話してあげよう！")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Text("わかった")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: width)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
    }
}

#if DEBUG
#Preview("Limited Happiness Reward Intro") {
    MemoLimitedHappinessRewardIntroOverlay(onDismiss: {})
}
#endif
