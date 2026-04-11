//
//  HappinessStomachGauge.swift
//  MeMo
//
//  Updated for HomeView happiness UI.
//

import SwiftUI

struct HappinessStomachGauge: View {
    let point: Double
    let displayPoint: Int
    let maxPoint: Int
    let level: Int
    let outerSize: CGFloat
    let innerSize: CGFloat

    private var clampedPoint: Double {
        min(Double(maxPoint), max(0, point))
    }

    private var fillFraction: CGFloat {
        guard maxPoint > 0 else { return 0 }
        return CGFloat(clampedPoint) / CGFloat(maxPoint)
    }

    private var liquidMainColor: Color {
        Color(red: 0.88, green: 0.24, blue: 0.32)
    }

    private var liquidDeepColor: Color {
        Color(red: 0.72, green: 0.12, blue: 0.20)
    }

    private var liquidHighlightColor: Color {
        Color(red: 1.0, green: 0.55, blue: 0.64)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase1 = CGFloat(t * 1.35)
            let phase2 = CGFloat(t * 1.02 + 1.4)
            let heartWidth = innerSize * 0.88
            let heartHeight = innerSize * 0.88
            let liquidDiameter = outerSize * 0.98

            ZStack {
                if fillFraction > 0.001 {
                    ZStack {
                        HappinessLiquidWaveShape(
                            fillFraction: fillFraction,
                            phase: phase1,
                            amplitude: 4.8
                        )
                        .fill(
                            LinearGradient(
                                colors: [
                                    liquidHighlightColor.opacity(0.92),
                                    liquidMainColor.opacity(0.96),
                                    liquidDeepColor.opacity(0.94)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        HappinessLiquidWaveShape(
                            fillFraction: max(0, fillFraction - 0.025),
                            phase: phase2,
                            amplitude: 7.0
                        )
                        .fill(Color.white.opacity(0.18))
                    }
                    .frame(width: liquidDiameter, height: liquidDiameter)
                    .clipShape(Circle())
                }

                ZStack {
                    Image("glass_heart")
                        .resizable()
                        .scaledToFit()
                        .frame(width: heartWidth, height: heartHeight)
                        .opacity(0.92)

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.white.opacity(0.10),
                            Color(red: 1.0, green: 0.82, blue: 0.88).opacity(0.14),
                            Color.white.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: heartWidth, height: heartHeight)
                    .blendMode(.screen)
                    .mask(
                        Image("glass_heart")
                            .resizable()
                            .scaledToFit()
                            .frame(width: heartWidth, height: heartHeight)
                    )

                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: innerSize * 0.52
                    )
                    .frame(width: heartWidth, height: heartHeight)
                    .blendMode(.screen)
                    .mask(
                        Image("glass_heart")
                            .resizable()
                            .scaledToFit()
                            .frame(width: heartWidth, height: heartHeight)
                    )

                    Capsule()
                        .fill(Color.white.opacity(0.82))
                        .frame(width: innerSize * 0.11, height: innerSize * 0.42)
                        .blur(radius: 1.1)
                        .rotationEffect(.degrees(11))
                        .offset(x: -innerSize * 0.08, y: -innerSize * 0.06)
                        .mask(
                            Image("glass_heart")
                                .resizable()
                                .scaledToFit()
                                .frame(width: heartWidth, height: heartHeight)
                        )

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.white.opacity(0.34))
                        .frame(width: innerSize * 0.42, height: innerSize * 0.14)
                        .blur(radius: 2.0)
                        .rotationEffect(.degrees(10))
                        .offset(x: innerSize * 0.10, y: -innerSize * 0.18)
                        .mask(
                            Image("glass_heart")
                                .resizable()
                                .scaledToFit()
                                .frame(width: heartWidth, height: heartHeight)
                        )

                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: innerSize * 0.52, height: innerSize * 0.07)
                        .blur(radius: 1.4)
                        .offset(x: 0, y: innerSize * 0.28)
                        .mask(
                            Image("glass_heart")
                                .resizable()
                                .scaledToFit()
                                .frame(width: heartWidth, height: heartHeight)
                        )
                }
                .frame(width: outerSize, height: outerSize)
                .drawingGroup()
            }
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 5)
        }
    }
}

private struct HappinessLiquidWaveShape: Shape {
    var fillFraction: CGFloat
    var phase: CGFloat
    var amplitude: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(phase, fillFraction) }
        set {
            phase = newValue.first
            fillFraction = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let fraction = max(0, min(1, fillFraction))
        guard fraction > 0 else { return path }

        let width = rect.width
        let liquidBaseY = rect.maxY - rect.height * fraction

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: liquidBaseY))

        for x in stride(from: CGFloat.zero, through: width, by: 2) {
            let progress = x / width
            let wave = sin((progress * .pi * 2 * 1.1) + phase) * amplitude
            let y = liquidBaseY + wave
            path.addLine(to: CGPoint(x: rect.minX + x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
