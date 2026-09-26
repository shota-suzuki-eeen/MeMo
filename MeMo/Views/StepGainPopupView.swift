//
//  StepGainPopupView.swift
//  MeMo
//
//  Created for HomeView step gain feedback.
//

import SwiftUI

struct StepGainPopupItem: Identifiable, Equatable {
    let id: UUID
    let amount: Int

    init(amount: Int) {
        self.id = UUID()
        self.amount = max(0, amount)
    }
}

struct StepGainPopupView: View {
    let amount: Int

    @State private var popScale: CGFloat = 0.72
    @State private var sparkleScale: CGFloat = 0.2
    @State private var sparkleOpacity: Double = 0
    @State private var floatingOffset: CGFloat = 8

    var body: some View {
        ZStack {
            sparkleLayer

            Text("+\(amount)歩")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.30, green: 0.78, blue: 1.0),
                                    Color(red: 0.12, green: 0.42, blue: 0.96)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(.white.opacity(0.82), lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)
                )
                .shadow(color: .black.opacity(0.20), radius: 2, x: 0, y: 2)
                .scaleEffect(popScale)
                .offset(y: floatingOffset)
        }
        .accessibilityLabel("\(amount)歩追加")
        .onAppear {
            playPopAnimation()
        }
    }

    private var sparkleLayer: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.86))
                .frame(width: 12, height: 12)
                .offset(x: -92, y: -20)

            Circle()
                .fill(Color.cyan.opacity(0.78))
                .frame(width: 10, height: 10)
                .offset(x: 92, y: -28)

            Circle()
                .fill(Color.white.opacity(0.62))
                .frame(width: 8, height: 8)
                .offset(x: -70, y: 34)

            Circle()
                .fill(Color.blue.opacity(0.74))
                .frame(width: 9, height: 9)
                .offset(x: 72, y: 36)
        }
        .scaleEffect(sparkleScale)
        .opacity(sparkleOpacity)
    }

    private func playPopAnimation() {
        popScale = 0.72
        sparkleScale = 0.2
        sparkleOpacity = 0
        floatingOffset = 8

        withAnimation(.spring(response: 0.22, dampingFraction: 0.48)) {
            popScale = 1.14
            sparkleScale = 1.12
            sparkleOpacity = 1
            floatingOffset = -4
        }

        withAnimation(.spring(response: 0.22, dampingFraction: 0.78).delay(0.16)) {
            popScale = 1.0
            floatingOffset = 0
        }

        withAnimation(.easeOut(duration: 0.72).delay(0.68)) {
            sparkleOpacity = 0
            sparkleScale = 1.38
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.mint, .cyan],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        StepGainPopupView(amount: 1234)
    }
}
