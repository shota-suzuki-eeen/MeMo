//
//  HappinessStomachGauge.swift
//  MeMo
//
//  Updated for HomeView happiness UI.
//  円形内の波表現だけ MetalCircularLiquidLayer に差し替え、
//  glass_heart とレベルバッジアセットの重なり順・サイズ感は既存実装に戻しています。
//  おやすみモード中は幸せ度メーターの液体色を金色にします。
//
//  2026/07/14 update:
//  ゲージ全体を30fpsで再構築していたTimelineViewを撤去しました。
//  波の更新はMetal内だけで継続し、おやすみモードの色判定は
//  UserDefaults変更・フォアグラウンド復帰・終了予定時刻にだけ更新します.
//

import SwiftUI
import Foundation

struct HappinessStomachGauge: View {
    let point: Double
    let displayPoint: Int
    let maxPoint: Int
    let level: Int
    let outerSize: CGFloat
    let innerSize: CGFloat
    let isActive: Bool

    @Environment(\.scenePhase) private var scenePhase

    @State private var displayedLevelAssetName: String
    @State private var levelBadgeOpacity: Double = 1
    @State private var sleepModeActive: Bool
    @State private var sleepModeEndTask: Task<Void, Never>?

    init(
        point: Double,
        displayPoint: Int,
        maxPoint: Int,
        level: Int,
        outerSize: CGFloat,
        innerSize: CGFloat,
        isActive: Bool = true
    ) {
        self.point = point
        self.displayPoint = displayPoint
        self.maxPoint = maxPoint
        self.level = level
        self.outerSize = outerSize
        self.innerSize = innerSize
        self.isActive = isActive

        _displayedLevelAssetName = State(
            initialValue: HappinessStomachGauge.levelAssetName(
                for: level
            )
        )
        _sleepModeActive = State(
            initialValue: HappinessStomachGauge.isSleepModeActive()
        )
    }

    private var clampedPoint: Double {
        min(Double(max(maxPoint, 1)), max(0, point))
    }

    private var fillFraction: CGFloat {
        guard maxPoint > 0 else { return 0 }
        return CGFloat(clampedPoint) / CGFloat(maxPoint)
    }

    private static let sleepModeEndsAtKey =
        "memo.happiness.sleepMode.endsAt"

    private static func sleepModeEndsAt() -> Date? {
        UserDefaults.standard.object(
            forKey: sleepModeEndsAtKey
        ) as? Date
    }

    private static func isSleepModeActive(
        now: Date = Date()
    ) -> Bool {
        guard let endsAt = sleepModeEndsAt() else {
            return false
        }
        return endsAt > now
    }

    private func liquidMainColor(
        isSleepModeActive: Bool
    ) -> Color {
        isSleepModeActive
        ? Color(red: 1.0, green: 0.72, blue: 0.16)
        : Color(red: 0.88, green: 0.24, blue: 0.32)
    }

    private func liquidDeepColor(
        isSleepModeActive: Bool
    ) -> Color {
        isSleepModeActive
        ? Color(red: 0.88, green: 0.52, blue: 0.04)
        : Color(red: 0.72, green: 0.12, blue: 0.20)
    }

    private func liquidHighlightColor(
        isSleepModeActive: Bool
    ) -> Color {
        isSleepModeActive
        ? Color(red: 1.0, green: 0.94, blue: 0.48)
        : Color(red: 1.0, green: 0.55, blue: 0.64)
    }

    private var isMetalLiquidActive: Bool {
        isActive && scenePhase == .active
    }

    private static func levelAssetName(
        for level: Int
    ) -> String {
        let clampedLevel = min(
            AppState.happinessMaxLevel,
            max(0, level)
        )
        return String(clampedLevel)
    }

    var body: some View {
        let heartWidth = innerSize * 0.88
        let heartHeight = innerSize * 0.88
        let liquidDiameter = outerSize * 0.98

        ZStack {
            if fillFraction > 0.001 {
                MetalCircularLiquidLayer(
                    fillFraction: fillFraction,
                    mainColor: liquidMainColor(
                        isSleepModeActive: sleepModeActive
                    ),
                    deepColor: liquidDeepColor(
                        isSleepModeActive: sleepModeActive
                    ),
                    highlightColor: liquidHighlightColor(
                        isSleepModeActive: sleepModeActive
                    ),
                    isActive: isMetalLiquidActive
                )
                .frame(
                    width: liquidDiameter,
                    height: liquidDiameter
                )
                .clipShape(Circle())
                .allowsHitTesting(false)
            }

            ZStack {
                Image("glass_heart")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: heartWidth,
                        height: heartHeight
                    )
                    .opacity(0.92)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.30),
                        Color.white.opacity(0.10),
                        Color(
                            red: 1.0,
                            green: 0.82,
                            blue: 0.88
                        )
                        .opacity(0.14),
                        Color.white.opacity(0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(
                    width: heartWidth,
                    height: heartHeight
                )
                .blendMode(.screen)
                .mask(
                    Image("glass_heart")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: heartWidth,
                            height: heartHeight
                        )
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
                .frame(
                    width: heartWidth,
                    height: heartHeight
                )
                .blendMode(.screen)
                .mask(
                    Image("glass_heart")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: heartWidth,
                            height: heartHeight
                        )
                )

                Capsule()
                    .fill(Color.white.opacity(0.82))
                    .frame(
                        width: innerSize * 0.11,
                        height: innerSize * 0.42
                    )
                    .blur(radius: 1.1)
                    .rotationEffect(.degrees(11))
                    .offset(
                        x: -innerSize * 0.08,
                        y: -innerSize * 0.06
                    )
                    .mask(
                        Image("glass_heart")
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: heartWidth,
                                height: heartHeight
                            )
                    )

                RoundedRectangle(
                    cornerRadius: 30,
                    style: .continuous
                )
                .fill(Color.white.opacity(0.34))
                .frame(
                    width: innerSize * 0.42,
                    height: innerSize * 0.14
                )
                .blur(radius: 2.0)
                .rotationEffect(.degrees(10))
                .offset(
                    x: innerSize * 0.10,
                    y: -innerSize * 0.18
                )
                .mask(
                    Image("glass_heart")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: heartWidth,
                            height: heartHeight
                        )
                )

                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(
                        width: innerSize * 0.52,
                        height: innerSize * 0.07
                    )
                    .blur(radius: 1.4)
                    .offset(
                        x: 0,
                        y: innerSize * 0.28
                    )
                    .mask(
                        Image("glass_heart")
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: heartWidth,
                                height: heartHeight
                            )
                    )
            }
            .frame(
                width: outerSize,
                height: outerSize
            )
            .drawingGroup()

            HappinessLevelFrontBadge(
                assetName: displayedLevelAssetName,
                outerSize: outerSize,
                opacity: levelBadgeOpacity
            )
            .allowsHitTesting(false)
        }
        .shadow(
            color: .black.opacity(0.16),
            radius: 8,
            x: 0,
            y: 5
        )
        .onAppear {
            refreshSleepModeState()
        }
        .onDisappear {
            sleepModeEndTask?.cancel()
            sleepModeEndTask = nil
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UserDefaults.didChangeNotification
            )
        ) { _ in
            guard scenePhase == .active else { return }
            refreshSleepModeState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshSleepModeState()
            } else {
                sleepModeEndTask?.cancel()
                sleepModeEndTask = nil
            }
        }
        .onChange(of: level) { _, newLevel in
            let nextAssetName = Self.levelAssetName(
                for: newLevel
            )
            guard nextAssetName != displayedLevelAssetName else {
                return
            }

            withAnimation(.easeOut(duration: 0.16)) {
                levelBadgeOpacity = 0
            }

            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.16
            ) {
                displayedLevelAssetName = nextAssetName
                withAnimation(.easeIn(duration: 0.22)) {
                    levelBadgeOpacity = 1
                }
            }
        }
    }

    private func refreshSleepModeState(
        now: Date = Date()
    ) {
        let nextValue = Self.isSleepModeActive(now: now)
        if sleepModeActive != nextValue {
            sleepModeActive = nextValue
        }

        scheduleSleepModeExpiration(now: now)
    }

    private func scheduleSleepModeExpiration(
        now: Date
    ) {
        sleepModeEndTask?.cancel()
        sleepModeEndTask = nil

        guard scenePhase == .active,
              let endsAt = Self.sleepModeEndsAt(),
              endsAt > now else {
            return
        }

        let delay = endsAt.timeIntervalSince(now)
        let nanoseconds = UInt64(
            min(delay, 24 * 60 * 60) * 1_000_000_000
        )

        sleepModeEndTask = Task { @MainActor in
            do {
                try await Task.sleep(
                    nanoseconds: nanoseconds
                )
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            let nextValue = Self.isSleepModeActive()
            if sleepModeActive != nextValue {
                sleepModeActive = nextValue
            }
            sleepModeEndTask = nil
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
            .frame(
                width: badgeWidth,
                height: badgeHeight
            )
            .opacity(opacity)
            .shadow(
                color: .black.opacity(0.16),
                radius: 4,
                x: 0,
                y: 2
            )
    }
}
