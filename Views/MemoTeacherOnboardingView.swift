//
//  MemoTeacherOnboardingView.swift
//  MeMo
//
//  Gentle teacher-style onboarding cards and spotlight guidance.
//  iOS 18.6+
//

import SwiftUI
import UIKit

struct MemoTeacherOnboardingOverlay: View {
    let state: AppState?
    let viewModel: MemoOnboardingViewModel
    let onNeedsSave: () -> Void
    let onOpenTutorialGacha: () -> Void
    let onOpenTutorialZukan: () -> Void

    var body: some View {
        ZStack {
            if viewModel.isPresented, let screen = viewModel.activeScreen {
                if screen.usesSpotlight {
                    MemoOnboardingSpotlightOverlay(
                        screen: screen,
                        state: state,
                        foodInteractionPhase: viewModel.foodInteractionPhase,
                        onTargetActivated: {
                            handleSpotlightTargetActivated()
                        },
                        onPrimaryAction: {
                            viewModel.handlePrimaryAction(state: state)
                            onNeedsSave()
                        }
                    )
                    .transition(.opacity)
                } else {
                    Color.black.opacity(0.42)
                        .ignoresSafeArea()
                        .transition(.opacity)

                    MemoTeacherOnboardingCard(
                        screen: screen,
                        state: state,
                        primaryAction: {
                            viewModel.handlePrimaryAction(state: state)
                            onNeedsSave()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: viewModel.isPresented)
        .allowsHitTesting(viewModel.isPresented)
    }

    private func handleSpotlightTargetActivated() {
        let routeAction = viewModel.handleSpotlightTargetActivated(state: state)
        onNeedsSave()

        switch routeAction {
        case .none, .saveOnly:
            break
        case .openTutorialGacha:
            onOpenTutorialGacha()
        case .openTutorialZukan:
            onOpenTutorialZukan()
        }
    }
}

private struct MemoTeacherOnboardingCard: View {
    let screen: MemoOnboardingScreen
    let state: AppState?
    let primaryAction: () -> Void

    private var messageText: String {
        if let state {
            return state.memoFoodTutorialMessage(for: screen)
        }
        return screen.message
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            Text(messageText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: primaryAction) {
                Text(screen.primaryButtonTitle)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: 360)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
        .padding(.horizontal, 20)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.16))
                    .frame(width: 42, height: 42)

                Text("👩‍🏫")
                    .font(.system(size: 24))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(screen.title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.primary)

                Text("いっしょにやってみよう")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct MemoOnboardingSpotlightOverlay: View {
    let screen: MemoOnboardingScreen
    let state: AppState?
    let foodInteractionPhase: MemoOnboardingFoodInteractionPhase
    let onTargetActivated: () -> Void
    let onPrimaryAction: () -> Void

    @State private var isPulsing: Bool = false

    private var messageText: String {
        switch screen {
        case .foodGiveNormal:
            let foodName = state?.memoTutorialNormalFoodName ?? "Nのごはん"
            if foodInteractionPhase == .pendingSwipe {
                return "\(foodName)を仮決定できたよ。上方向にスワイプすると、ごはんをあげられるよ。"
            }
            return "その画面のまま、\(foodName)をタップして仮決定しよう。"

        case .foodGiveRare:
            let foodName = state?.memoTutorialRareFoodName ?? "Rのごはん"
            if foodInteractionPhase == .pendingSwipe {
                return "\(foodName)を仮決定できたよ。上方向にスワイプすると、ごはんをあげられるよ。"
            }
            return "その画面のまま、\(foodName)をタップして仮決定しよう。"

        default:
            break
        }

        if let state {
            return state.memoFoodTutorialMessage(for: screen)
        }
        return screen.message
    }

    private var primaryPromptText: String {
        if foodInteractionPhase == .pendingSwipe {
            switch screen {
            case .foodGiveNormal, .foodGiveRare:
                return "上にスワイプしてみよう！"
            default:
                break
            }
        }
        return screen.primaryButtonTitle
    }

    private var target: MemoOnboardingTarget {
        screen.spotlightTarget ?? .foodButton
    }

    var body: some View {
        GeometryReader { proxy in
            let targetFrame = target.frame(in: proxy.size, foodInteractionPhase: foodInteractionPhase)
            let passThroughFrame = target.passThroughFrame(
                in: proxy.size,
                spotlightFrame: targetFrame,
                foodInteractionPhase: foodInteractionPhase
            )
            let bubbleWidth = min(proxy.size.width - 32, 344)
            let bubbleY = target.messageCenterY(in: proxy.size, targetFrame: targetFrame)

            ZStack {
                dimmingLayer(targetFrame: targetFrame)
                    .allowsHitTesting(false)

                targetHighlight(frame: targetFrame)
                    .allowsHitTesting(false)
                    .position(x: targetFrame.midX, y: targetFrame.midY)

                if screen.spotlightAllowsPassThroughToRealControl {
                    instructionBubble(width: bubbleWidth, showsPrimaryButton: false)
                        .allowsHitTesting(false)
                        .position(x: proxy.size.width / 2, y: bubbleY)

                    MemoOnboardingTouchGate(
                        passThroughFrame: passThroughFrame,
                        onPassThroughHit: onTargetActivated
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()
                } else if screen.spotlightNeedsPrimaryButton {
                    MemoOnboardingTouchGate(passThroughFrame: nil, onPassThroughHit: nil)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .ignoresSafeArea()

                    instructionBubble(width: bubbleWidth, showsPrimaryButton: true)
                        .position(x: proxy.size.width / 2, y: bubbleY)
                } else {
                    MemoOnboardingTouchGate(passThroughFrame: nil, onPassThroughHit: nil)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .ignoresSafeArea()

                    Button(action: onTargetActivated) {
                        Color.clear
                            .contentShape(RoundedRectangle(cornerRadius: target.cornerRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .frame(width: targetFrame.width, height: targetFrame.height)
                    .position(x: targetFrame.midX, y: targetFrame.midY)

                    instructionBubble(width: bubbleWidth, showsPrimaryButton: false)
                        .allowsHitTesting(false)
                        .position(x: proxy.size.width / 2, y: bubbleY)
                }
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }

    private func dimmingLayer(targetFrame: CGRect) -> some View {
        Color.black.opacity(0.62)
            .overlay {
                RoundedRectangle(cornerRadius: target.cornerRadius, style: .continuous)
                    .frame(width: targetFrame.width + 18, height: targetFrame.height + 18)
                    .position(x: targetFrame.midX, y: targetFrame.midY)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
    }

    private func targetHighlight(frame: CGRect) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: target.cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.001))

            RoundedRectangle(cornerRadius: target.cornerRadius, style: .continuous)
                .stroke(Color.white, lineWidth: 4)
                .shadow(color: .white.opacity(0.9), radius: 14)
                .scaleEffect(isPulsing ? 1.12 : 0.94)

            RoundedRectangle(cornerRadius: target.cornerRadius, style: .continuous)
                .stroke(Color.accentColor.opacity(0.95), lineWidth: 3)
                .scaleEffect(isPulsing ? 0.96 : 1.08)
        }
        .frame(width: frame.width, height: frame.height)
    }

    private func instructionBubble(width: CGFloat, showsPrimaryButton: Bool) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("👩‍🏫")
                    .font(.system(size: 24))

                Text(screen.title)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }

            Text(messageText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showsPrimaryButton {
                Button(action: onPrimaryAction) {
                    Text(primaryPromptText)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Text(primaryPromptText)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityLabel(primaryPromptText)
            }
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

private struct MemoOnboardingTouchGate: UIViewRepresentable {
    let passThroughFrame: CGRect?
    let onPassThroughHit: (() -> Void)?

    func makeUIView(context: Context) -> TouchGateView {
        let view = TouchGateView()
        view.backgroundColor = .clear
        view.isOpaque = false
        return view
    }

    func updateUIView(_ uiView: TouchGateView, context: Context) {
        uiView.passThroughFrame = passThroughFrame
        uiView.onPassThroughHit = onPassThroughHit
    }

    final class TouchGateView: UIView {
        var passThroughFrame: CGRect?
        var onPassThroughHit: (() -> Void)?
        private var lastHitNotificationTime: TimeInterval = 0

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            if let passThroughFrame, passThroughFrame.contains(point) {
                notifyPassThroughHitIfNeeded()
                return nil
            }
            return self
        }

        private func notifyPassThroughHitIfNeeded() {
            guard let onPassThroughHit else { return }
            let now = CACurrentMediaTime()
            guard now - lastHitNotificationTime > 0.35 else { return }
            lastHitNotificationTime = now
            DispatchQueue.main.async {
                onPassThroughHit()
            }
        }
    }
}

private extension MemoOnboardingTarget {
    var cornerRadius: CGFloat {
        switch self {
        case .foodButton, .gachaButton, .zukanButton, .freeTenGachaButton, .zukanSwitchButton:
            return 28
        case .normalFood, .rareFood, .rareFoodTab:
            return 26
        case .fullnessMeter:
            return 68
        }
    }

    func frame(
        in size: CGSize,
        foodInteractionPhase: MemoOnboardingFoodInteractionPhase = .choosing
    ) -> CGRect {
        switch self {
        case .foodButton:
            let side: CGFloat = 96
            let centerX: CGFloat = min(max(CGFloat(64), size.width * 0.20), size.width - CGFloat(88))
            let centerY: CGFloat = min(max(CGFloat(320), size.height * 0.47), size.height - CGFloat(230))
            return CGRect(x: centerX - side / 2, y: centerY - side / 2, width: side, height: side)

        case .normalFood:
            return foodSpotlightFrame(in: size, phase: foodInteractionPhase)

        case .rareFoodTab:
            let width: CGFloat = 120
            let height: CGFloat = 58
            let selectorCenterY: CGFloat = min(max(CGFloat(420), size.height - CGFloat(320)), size.height - CGFloat(230))
            let centerX: CGFloat = min(size.width - CGFloat(54), (size.width / 2) + CGFloat(148))
            let centerY: CGFloat = selectorCenterY + CGFloat(38)
            return CGRect(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height)

        case .rareFood:
            return foodSpotlightFrame(in: size, phase: foodInteractionPhase)

        case .fullnessMeter:
            let side: CGFloat = 142
            let centerX: CGFloat = size.width - CGFloat(161)
            let centerY: CGFloat = 218
            return CGRect(x: centerX - side / 2, y: centerY - side / 2, width: side, height: side)

        case .gachaButton:
            let side: CGFloat = 96

            // HomeView の BottomButtons と同じ並びに合わせる。
            // menu / gatya / work / step の2番目が gatya_button。
            let buttonSize: CGFloat = 68
            let spacing: CGFloat = 16
            let horizontalPadding: CGFloat = 18
            let bottomPadding: CGFloat = -38
            let scopeOffsetX: CGFloat = -3 // -で左、+で右
            let itemCount: CGFloat = 4

            let rowWidth = (buttonSize * itemCount) + (spacing * (itemCount - 1))
            let availableWidth = max(0, size.width - (horizontalPadding * 2))
            let rowStartX = horizontalPadding + max(0, (availableWidth - rowWidth) / 2)

            let centerX = rowStartX + buttonSize + spacing + (buttonSize / 2) + scopeOffsetX
            let centerY = size.height - bottomPadding - (buttonSize / 2)

            return CGRect(x: centerX - side / 2, y: centerY - side / 2, width: side, height: side)

        case .zukanButton:
            let side: CGFloat = 96

            // HomeView の BottomButtons と同じ並びに合わせる。
            // menu / gatya / work / step のうち、図鑑への入口になる menu_button にスコープを当てる。
            let buttonSize: CGFloat = 68
            let spacing: CGFloat = 16
            let horizontalPadding: CGFloat = 18
            let bottomPadding: CGFloat = -38
            let scopeOffsetX: CGFloat = -12 // -で左、+で右
            let itemCount: CGFloat = 4

            let rowWidth = (buttonSize * itemCount) + (spacing * (itemCount - 1))
            let availableWidth = max(0, size.width - (horizontalPadding * 2))
            let rowStartX = horizontalPadding + max(0, (availableWidth - rowWidth) / 2)

            let centerX = rowStartX + (buttonSize / 2) + scopeOffsetX
            let centerY = size.height - bottomPadding - (buttonSize / 2)

            return CGRect(x: centerX - side / 2, y: centerY - side / 2, width: side, height: side)

        case .freeTenGachaButton:
            let width: CGFloat = min(size.width - CGFloat(44), CGFloat(340))
            let height: CGFloat = 74
            let centerX: CGFloat = size.width / 2
            let centerY: CGFloat = size.height * 0.66
            return CGRect(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height)

        case .zukanSwitchButton:
            let width: CGFloat = min(size.width - CGFloat(44), CGFloat(340))
            let height: CGFloat = 58
            let centerX: CGFloat = size.width / 2
            let centerY: CGFloat = size.height - CGFloat(128)
            return CGRect(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height)
        }
    }

    func passThroughFrame(
        in size: CGSize,
        spotlightFrame: CGRect,
        foodInteractionPhase: MemoOnboardingFoodInteractionPhase
    ) -> CGRect {
        switch self {
        case .normalFood, .rareFood:
            return foodItemOnlyFrame(
                in: size,
                phase: foodInteractionPhase,
                spotlightFrame: spotlightFrame
            )
        default:
            return spotlightFrame
        }
    }

    func messageCenterY(in size: CGSize, targetFrame: CGRect) -> CGFloat {
        let preferredGap: CGFloat = 128
        let cardHalfHeight: CGFloat = 106

        if targetFrame.midY > size.height * 0.54 {
            return max(cardHalfHeight + CGFloat(18), targetFrame.minY - preferredGap)
        }

        return min(size.height - cardHalfHeight - CGFloat(18), targetFrame.maxY + preferredGap)
    }

    private func foodSpotlightFrame(
        in size: CGSize,
        phase: MemoOnboardingFoodInteractionPhase
    ) -> CGRect {
        let width: CGFloat = min(CGFloat(218), size.width - CGFloat(96))
        let height: CGFloat = phase == .pendingSwipe ? 252 : 238
        let centerX: CGFloat = size.width / 2
        let baseCenterY: CGFloat = min(max(CGFloat(420), size.height - CGFloat(210)), size.height - CGFloat(210))
        let centerY: CGFloat = phase == .pendingSwipe ? baseCenterY - CGFloat(44) : baseCenterY
        return CGRect(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height)
    }

    private func foodItemOnlyFrame(
        in size: CGSize,
        phase: MemoOnboardingFoodInteractionPhase,
        spotlightFrame: CGRect
    ) -> CGRect {
        let width: CGFloat = min(CGFloat(142), max(CGFloat(112), spotlightFrame.width - CGFloat(62)))
        let height: CGFloat = phase == .pendingSwipe ? 186 : 176
        let centerX: CGFloat = spotlightFrame.midX
        let centerY: CGFloat = phase == .pendingSwipe ? spotlightFrame.midY - CGFloat(2) : spotlightFrame.midY + CGFloat(6)
        return CGRect(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height)
    }
}

#if DEBUG
#Preview("Onboarding Card") {
    MemoTeacherOnboardingCard(
        screen: .appPurpose,
        state: nil,
        primaryAction: {}
    )
    .padding()
}
#endif
