//
//  HappinessStomachGauge.swift
//  MeMo
//
//  Safe version for happiness meter.
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
            let liquidDiameter = outerSize * 0.98

            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.22))
                    .frame(width: outerSize, height: outerSize)

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

                Circle()
                    .stroke(Color.white.opacity(0.82), lineWidth: 2)
                    .frame(width: outerSize, height: outerSize)

                VStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: innerSize * 0.22, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)

                    Text("\(displayPoint)/\(maxPoint)")
                        .font(.system(size: innerSize * 0.12, weight: .black))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Text("Lv.\(level)")
                        .font(.system(size: innerSize * 0.10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .monospacedDigit()
                }
            }
            .frame(width: outerSize, height: outerSize)
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
