//
//  MeMoWatchHomeView.swift
//  MeMo Watch App
//
//  iPhone HomeView asset based Watch Home UI.
//  The Watch implementation intentionally avoids MTKView / MetalKit and reproduces
//  the iPhone meter presentation with lightweight SwiftUI liquid-wave rendering.
//
//  Uses the same asset names as iPhone HomeView:
//  - Home_background / selected wallpaper asset
//  - mini_person
//  - current pet asset from PetMaster
//  - glass_heart
//  - numeric level badge assets: "0"..."40"
//  - glass_stomach
//

import Foundation
import SwiftUI

struct MeMoWatchHomeView: View {
    @StateObject private var viewModel = MeMoWatchHomeViewModel()

    private let referenceSize = CGSize(width: 368, height: 448)

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let safeHeight = geometry.size.height
            let scale = width / referenceSize.width
            let layoutHeight = max(safeHeight, referenceSize.height * scale)
            let layoutWidth = referenceSize.width * scale

            ZStack(alignment: .topLeading) {
                Color.black
                    .ignoresSafeArea()

                ZStack {
                    backgroundLayer(width: layoutWidth, height: layoutHeight)

                    stepMeter(scale: scale)
                        .position(x: layoutWidth * 0.50, y: 76 * scale)

                    characterLayer(scale: scale)
                        .position(x: layoutWidth * 0.50, y: 275 * scale)

                    WatchHappinessGauge(
                        point: viewModel.happinessPoint,
                        maxPoint: viewModel.happinessMaxPoint,
                        level: viewModel.happinessLevel,
                        scale: scale
                    )
                    .position(x: 70 * scale, y: 356 * scale)

                    WatchFullnessGauge(
                        level: viewModel.fullnessLevel,
                        maxLevel: viewModel.fullnessMaxLevel,
                        scale: scale
                    )
                    .position(x: layoutWidth - (70 * scale), y: 356 * scale)
                }
                .frame(width: layoutWidth, height: layoutHeight)
                .position(x: width * 0.5, y: layoutHeight * 0.5)
            }
            .frame(width: width, height: layoutHeight)
            .contentShape(Rectangle())
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .watchSystemOverlayHiddenIfAvailable()
        .task {
            await viewModel.start()
        }
    }

    private func backgroundLayer(width: CGFloat, height: CGFloat) -> some View {
        Image(viewModel.backgroundAssetName)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
            .background(Color(red: 0.95, green: 0.88, blue: 0.78))
    }

    private func stepMeter(scale: CGFloat) -> some View {
        WatchHomeStepMeter(
            steps: viewModel.todaySteps,
            goalSteps: viewModel.dailyStepGoal,
            miniCharacterAssetName: "mini_person"
        )
        .frame(width: 278 * scale, height: 64 * scale)
    }

    private func characterLayer(scale: CGFloat) -> some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.78))
                .frame(width: 118 * scale, height: 23 * scale)
                .blur(radius: 9 * scale)
                .offset(y: 135 * scale)
                .allowsHitTesting(false)

            MeMoWatchCharacterSpriteView(
                assetName: viewModel.currentCharacterAssetName,
                baseAssetName: viewModel.currentCharacterAssetName,
                isIdleEnabled: true,
                maxDisplaySize: CGSize(
                    width: 190 * scale,
                    height: 282 * scale
                )
            )
            .scaleEffect(viewModel.isPettingFeedbackActive ? 1.025 : 1.0)
            .animation(
                .spring(response: 0.16, dampingFraction: 0.62),
                value: viewModel.isPettingFeedbackActive
            )
        }
        .frame(width: 210 * scale, height: 300 * scale)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { _ in
                    viewModel.petCharacter()
                }
        )
    }
}

// MARK: - iPhone-style step meter

private struct WatchHomeStepMeter: View {
    let steps: Int
    let goalSteps: Int
    let miniCharacterAssetName: String

    private var safeSteps: Int { max(0, steps) }
    private var safeGoalSteps: Int { max(1, goalSteps) }

    private var blueProgress: CGFloat {
        CGFloat(min(1, Double(safeSteps) / Double(safeGoalSteps)))
    }

    private var goldProgress: CGFloat {
        guard safeSteps > safeGoalSteps else { return 0 }
        return CGFloat(min(1, Double(safeSteps - safeGoalSteps) / Double(safeGoalSteps)))
    }

    private var activeProgress: CGFloat {
        goldProgress > 0 ? goldProgress : blueProgress
    }

    private var currentStepText: String {
        Self.numberFormatter.string(from: NSNumber(value: safeSteps)) ?? "0"
    }

    private var goalStepText: String {
        Self.numberFormatter.string(from: NSNumber(value: safeGoalSteps)) ?? "0"
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let height = max(1, geometry.size.height)
            let scale = min(width / 278, height / 64)
            let trackHeight = min(35 * scale, height)
            let iconSize = min(34 * scale, height)
            let iconHalf = iconSize / 2
            let trackCenterY = height - (trackHeight / 2)
            let trackTopY = trackCenterY - (trackHeight / 2)
            let iconOverlap = min(4 * scale, iconSize * 0.5)
            let iconCenterY = max(iconHalf, trackTopY - iconHalf + iconOverlap)
            let liquidInset = 2 * scale
            let liquidWidth = max(1, width - (liquidInset * 2))
            let liquidFrontX = liquidInset + (liquidWidth * activeProgress)
            let iconX = liquidFrontX - (8 * scale)
            let clampedIconX = min(max(iconHalf, iconX), width - iconHalf)

            ZStack(alignment: .topLeading) {
                WatchLinearLiquidSurface(
                    blueProgress: blueProgress,
                    goldProgress: goldProgress
                )
                .frame(width: width, height: trackHeight)
                .shadow(color: .black.opacity(0.18), radius: 7 * scale, x: 0, y: 4 * scale)
                .position(x: width / 2, y: trackCenterY)

                Text(currentStepText)
                    .font(.system(size: 31 * scale, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.52), radius: 3 * scale, x: 0, y: 1 * scale)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .position(x: width / 2, y: trackCenterY)
                    .allowsHitTesting(false)

                Text("/ \(goalStepText)歩")
                    .font(.system(size: 11 * scale, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.94))
                    .monospacedDigit()
                    .shadow(color: .black.opacity(0.52), radius: 3 * scale, x: 0, y: 1 * scale)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .frame(width: width - (18 * scale), alignment: .trailing)
                    .position(x: width / 2, y: trackCenterY)
                    .allowsHitTesting(false)

                Image(miniCharacterAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .position(x: clampedIconX, y: iconCenterY)
                    .animation(.easeOut(duration: 0.28), value: activeProgress)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日の歩数メーター \(safeSteps)歩")
    }
}

private struct WatchLinearLiquidSurface: View {
    let blueProgress: CGFloat
    let goldProgress: CGFloat

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 12.0,
                paused: scenePhase != .active
            )
        ) { timeline in
            GeometryReader { geometry in
                let size = geometry.size
                let phase = CGFloat(timeline.date.timeIntervalSinceReferenceDate * 1.8)
                let amplitude = max(1.2, size.height * 0.075)

                ZStack {
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.16))

                    WatchHorizontalLiquidWaveShape(
                        progress: blueProgress,
                        phase: phase,
                        amplitude: amplitude
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.20, green: 0.70, blue: 1.00),
                                Color(red: 0.04, green: 0.53, blue: 1.00),
                                Color(red: 0.01, green: 0.25, blue: 0.74)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    if goldProgress > 0.001 {
                        WatchHorizontalLiquidWaveShape(
                            progress: goldProgress,
                            phase: phase + 2.3,
                            amplitude: amplitude
                        )
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.90, blue: 0.30),
                                    Color(red: 1.00, green: 0.78, blue: 0.08),
                                    Color(red: 0.78, green: 0.42, blue: 0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.24),
                            Color.white.opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.30), lineWidth: max(0.8, size.height * 0.025))
                }
                .clipShape(Capsule(style: .continuous))
            }
        }
    }
}

// MARK: - iPhone-style status gauges

private struct WatchHappinessGauge: View {
    let point: Int
    let maxPoint: Int
    let level: Int
    let scale: CGFloat

    private var fillFraction: CGFloat {
        CGFloat(min(1, max(0, Double(point) / Double(max(maxPoint, 1)))))
    }

    private var levelAssetName: String {
        String(min(40, max(0, level)))
    }

    var body: some View {
        let outerSize = 88 * scale
        let innerSize = 75 * scale
        let assetWidth = innerSize * 0.88
        let assetHeight = innerSize * 0.88
        let liquidDiameter = outerSize * 0.98

        ZStack {
            if fillFraction > 0.001 {
                WatchCircularLiquidSurface(
                    fillFraction: fillFraction,
                    mainColor: Color(red: 0.88, green: 0.24, blue: 0.32),
                    deepColor: Color(red: 0.72, green: 0.12, blue: 0.20),
                    highlightColor: Color(red: 1.00, green: 0.55, blue: 0.64)
                )
                .frame(width: liquidDiameter, height: liquidDiameter)
                .clipShape(Circle())
                .allowsHitTesting(false)
            }

            WatchGlassAssetLayer(
                assetName: "glass_heart",
                assetWidth: assetWidth,
                assetHeight: assetHeight,
                innerSize: innerSize,
                accentColor: Color(red: 1.00, green: 0.82, blue: 0.88)
            )

            Image(levelAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: outerSize * 0.78, height: outerSize * 0.44)
                .offset(y: outerSize * 0.03)
                .shadow(color: .black.opacity(0.16), radius: 4 * scale, x: 0, y: 2 * scale)
        }
        .frame(width: outerSize, height: outerSize)
        .shadow(color: .black.opacity(0.16), radius: 7 * scale, x: 0, y: 4 * scale)
    }
}

private struct WatchFullnessGauge: View {
    let level: Int
    let maxLevel: Int
    let scale: CGFloat

    private var fillFraction: CGFloat {
        CGFloat(min(1, max(0, Double(level) / Double(max(maxLevel, 1)))))
    }

    private var colorLevel: Int {
        min(maxLevel, max(0, level))
    }

    private var liquidMainColor: Color {
        switch colorLevel {
        case 0: return Color(red: 0.18, green: 0.42, blue: 0.20).opacity(0.18)
        case 1: return Color(red: 0.15, green: 0.49, blue: 0.17)
        case 2: return Color(red: 0.13, green: 0.45, blue: 0.15)
        case 3: return Color(red: 0.11, green: 0.40, blue: 0.13)
        case 4: return Color(red: 0.10, green: 0.36, blue: 0.12)
        default: return Color(red: 0.09, green: 0.32, blue: 0.11)
        }
    }

    private var liquidDeepColor: Color {
        switch colorLevel {
        case 0: return Color(red: 0.08, green: 0.22, blue: 0.09).opacity(0.14)
        case 1: return Color(red: 0.07, green: 0.26, blue: 0.08)
        case 2: return Color(red: 0.06, green: 0.23, blue: 0.07)
        case 3: return Color(red: 0.05, green: 0.20, blue: 0.06)
        case 4: return Color(red: 0.04, green: 0.18, blue: 0.05)
        default: return Color(red: 0.03, green: 0.16, blue: 0.05)
        }
    }

    private var liquidHighlightColor: Color {
        Color(red: 0.42, green: 0.76, blue: 0.46)
    }

    var body: some View {
        let outerSize = 88 * scale
        let innerSize = 75 * scale
        let assetWidth = innerSize * 0.92
        let assetHeight = innerSize * 0.92
        let liquidDiameter = outerSize * 0.98

        ZStack {
            if fillFraction > 0.001 {
                WatchCircularLiquidSurface(
                    fillFraction: fillFraction,
                    mainColor: liquidMainColor,
                    deepColor: liquidDeepColor,
                    highlightColor: liquidHighlightColor
                )
                .frame(width: liquidDiameter, height: liquidDiameter)
                .clipShape(Circle())
                .allowsHitTesting(false)
            }

            WatchGlassAssetLayer(
                assetName: "glass_stomach",
                assetWidth: assetWidth,
                assetHeight: assetHeight,
                innerSize: innerSize,
                accentColor: Color(red: 0.80, green: 0.88, blue: 0.86)
            )
        }
        .frame(width: outerSize, height: outerSize)
        .shadow(color: .black.opacity(0.16), radius: 7 * scale, x: 0, y: 4 * scale)
    }
}

private struct WatchCircularLiquidSurface: View {
    let fillFraction: CGFloat
    let mainColor: Color
    let deepColor: Color
    let highlightColor: Color

    @Environment(\.scenePhase) private var scenePhase

    private var clampedFillFraction: CGFloat {
        min(1, max(0, fillFraction))
    }

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 12.0,
                paused: scenePhase != .active
            )
        ) { timeline in
            GeometryReader { geometry in
                let size = geometry.size
                let phase = CGFloat(timeline.date.timeIntervalSinceReferenceDate * 1.35)
                let amplitude = max(1.5, size.height * 0.045)

                ZStack {
                    Circle()
                        .fill(deepColor.opacity(0.08))

                    WatchVerticalLiquidWaveShape(
                        fillFraction: clampedFillFraction,
                        phase: phase,
                        amplitude: amplitude
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                highlightColor.opacity(0.96),
                                mainColor.opacity(0.98),
                                deepColor.opacity(0.98)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    WatchVerticalLiquidWaveShape(
                        fillFraction: max(0, clampedFillFraction - 0.02),
                        phase: phase + 1.65,
                        amplitude: amplitude * 1.35
                    )
                    .fill(Color.white.opacity(0.10))

                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.04),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: max(size.width, size.height) * 0.72
                    )
                }
                .clipShape(Circle())
            }
        }
    }
}

private struct WatchGlassAssetLayer: View {
    let assetName: String
    let assetWidth: CGFloat
    let assetHeight: CGFloat
    let innerSize: CGFloat
    let accentColor: Color

    var body: some View {
        ZStack {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: assetWidth, height: assetHeight)
                .opacity(0.94)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.30),
                    Color.white.opacity(0.10),
                    accentColor.opacity(0.14),
                    Color.white.opacity(0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: assetWidth, height: assetHeight)
            .blendMode(.screen)
            .mask(
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: assetWidth, height: assetHeight)
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.24),
                    Color.white.opacity(0.05),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 1,
                endRadius: innerSize * 0.52
            )
            .frame(width: assetWidth, height: assetHeight)
            .blendMode(.screen)
            .mask(
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: assetWidth, height: assetHeight)
            )

            Capsule()
                .fill(Color.white.opacity(0.76))
                .frame(width: innerSize * 0.10, height: innerSize * 0.38)
                .blur(radius: max(0.6, innerSize * 0.014))
                .rotationEffect(.degrees(11))
                .offset(x: -innerSize * 0.08, y: -innerSize * 0.06)
                .mask(
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: assetWidth, height: assetHeight)
                )

            RoundedRectangle(cornerRadius: innerSize * 0.18, style: .continuous)
                .fill(Color.white.opacity(0.32))
                .frame(width: innerSize * 0.40, height: innerSize * 0.13)
                .blur(radius: max(0.8, innerSize * 0.025))
                .rotationEffect(.degrees(10))
                .offset(x: innerSize * 0.10, y: -innerSize * 0.18)
                .mask(
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: assetWidth, height: assetHeight)
                )

            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: innerSize * 0.50, height: innerSize * 0.065)
                .blur(radius: max(0.6, innerSize * 0.018))
                .offset(y: innerSize * 0.28)
                .mask(
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: assetWidth, height: assetHeight)
                )
        }
    }
}

// MARK: - Lightweight SwiftUI liquid shapes

private struct WatchHorizontalLiquidWaveShape: Shape {
    var progress: CGFloat
    var phase: CGFloat
    var amplitude: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, phase) }
        set {
            progress = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let safeProgress = min(1, max(0, progress))

        guard safeProgress > 0.001 else {
            return path
        }

        if safeProgress >= 0.999 {
            path.addRect(rect)
            return path
        }

        let height = max(1, rect.height)
        let baseFrontX = rect.minX + (rect.width * safeProgress)
        let sampleStep = max(1, height / 24)

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        var y = rect.minY
        while y <= rect.maxY {
            let normalizedY = (y - rect.minY) / height
            let wave =
                sin((normalizedY * .pi * 2 * 1.20) + phase) * amplitude
                + sin((normalizedY * .pi * 2 * 2.35) - (phase * 0.72) + 1.1) * amplitude * 0.42
            let x = min(rect.maxX, max(rect.minX, baseFrontX + wave))
            path.addLine(to: CGPoint(x: x, y: y))
            y += sampleStep
        }

        let finalWave =
            sin((.pi * 2 * 1.20) + phase) * amplitude
            + sin((.pi * 2 * 2.35) - (phase * 0.72) + 1.1) * amplitude * 0.42
        let finalX = min(rect.maxX, max(rect.minX, baseFrontX + finalWave))
        path.addLine(to: CGPoint(x: finalX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct WatchVerticalLiquidWaveShape: Shape {
    var fillFraction: CGFloat
    var phase: CGFloat
    var amplitude: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(fillFraction, phase) }
        set {
            fillFraction = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let safeFill = min(1, max(0, fillFraction))

        guard safeFill > 0.001 else {
            return path
        }

        let width = max(1, rect.width)
        let surfaceBaseY = rect.maxY - (rect.height * safeFill)
        let sampleStep = max(1, width / 32)

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))

        var x = rect.minX
        while x <= rect.maxX {
            let normalizedX = (x - rect.minX) / width
            let wave =
                sin((normalizedX * .pi * 2 * 1.10) + phase) * amplitude
                + sin((normalizedX * .pi * 2 * 2.15) - (phase * 0.76) + 1.4) * amplitude * 0.45
            let y = min(rect.maxY, max(rect.minY, surfaceBaseY + wave))
            path.addLine(to: CGPoint(x: x, y: y))
            x += sampleStep
        }

        let finalWave =
            sin((.pi * 2 * 1.10) + phase) * amplitude
            + sin((.pi * 2 * 2.15) - (phase * 0.76) + 1.4) * amplitude * 0.45
        let finalY = min(rect.maxY, max(rect.minY, surfaceBaseY + finalWave))
        path.addLine(to: CGPoint(x: rect.maxX, y: finalY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private extension View {
    @ViewBuilder
    func watchSystemOverlayHiddenIfAvailable() -> some View {
        #if os(watchOS)
        if #available(watchOS 9.0, *) {
            self.persistentSystemOverlays(.hidden)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

#Preview {
    MeMoWatchHomeView()
}
