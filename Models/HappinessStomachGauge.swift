//
//  HappinessStomachGauge.swift
//  MeMo
//
//  Updated for HomeView happiness UI.
//  円形内の波表現だけ MetalCircularLiquidLayer に差し替え、
//  glass_heart とレベルバッジアセットの重なり順・サイズ感は既存実装に戻しています。
//

import SwiftUI

struct HappinessStomachGauge: View {
    let point: Double
    let displayPoint: Int
    let maxPoint: Int
    let level: Int
    let outerSize: CGFloat
    let innerSize: CGFloat

    @Environment(\.scenePhase) private var scenePhase

    @State private var displayedLevelAssetName: String
    @State private var levelBadgeOpacity: Double = 1

    init(
        point: Double,
        displayPoint: Int,
        maxPoint: Int,
        level: Int,
        outerSize: CGFloat,
        innerSize: CGFloat
    ) {
        self.point = point
        self.displayPoint = displayPoint
        self.maxPoint = maxPoint
        self.level = level
        self.outerSize = outerSize
        self.innerSize = innerSize
        _displayedLevelAssetName = State(initialValue: HappinessStomachGauge.levelAssetName(for: level))
    }

    private var clampedPoint: Double {
        min(Double(max(maxPoint, 1)), max(0, point))
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

    private var isMetalLiquidActive: Bool {
        scenePhase == .active
    }

    private static func levelAssetName(for level: Int) -> String {
        let clampedLevel = min(AppState.happinessMaxLevel, max(0, level))
        return String(clampedLevel)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            let heartWidth = innerSize * 0.88
            let heartHeight = innerSize * 0.88
            let liquidDiameter = outerSize * 0.98

            ZStack {
                if fillFraction > 0.001 {
                    MetalCircularLiquidLayer(
                        fillFraction: fillFraction,
                        mainColor: liquidMainColor,
                        deepColor: liquidDeepColor,
                        highlightColor: liquidHighlightColor,
                        isActive: isMetalLiquidActive
                    )
                    .frame(width: liquidDiameter, height: liquidDiameter)
                    .clipShape(Circle())
                    .allowsHitTesting(false)
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

                HappinessLevelFrontBadge(
                    assetName: displayedLevelAssetName,
                    outerSize: outerSize,
                    opacity: levelBadgeOpacity
                )
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 5)
        }
        .onChange(of: level) { _, newLevel in
            let nextAssetName = Self.levelAssetName(for: newLevel)
            guard nextAssetName != displayedLevelAssetName else { return }

            withAnimation(.easeOut(duration: 0.16)) {
                levelBadgeOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                displayedLevelAssetName = nextAssetName
                withAnimation(.easeIn(duration: 0.22)) {
                    levelBadgeOpacity = 1
                }
            }
        }
    }
}

private struct HappinessLevelFrontBadge: View {
    let assetName: String
    let outerSize: CGFloat
    let opacity: Double

    private var badgeWidth: CGFloat {
        outerSize * 0.58
    }

    private var badgeHeight: CGFloat {
        outerSize * 0.32
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: badgeWidth, height: badgeHeight)
            .opacity(opacity)
            .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 2)
    }
}
