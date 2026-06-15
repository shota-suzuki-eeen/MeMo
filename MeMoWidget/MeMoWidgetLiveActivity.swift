//
//  MeMoWidgetLiveActivity.swift
//  MeMoWidgetExtension
//
//  Widget Extension UI for the care-status Live Activity.
//  Replace MeMoWidget/MeMoWidgetLiveActivity.swift with this content.
//  Add this file to the MeMoWidgetExtension target only.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct MeMoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeMoCareActivityAttributes.self) { context in
            if context.state.showsLockScreenCard {
                MeMoCareLockScreenLiveActivityView(context: context)
                    .activityBackgroundTint(.clear)
                    .activitySystemActionForegroundColor(.white)
            } else {
                EmptyView()
                    .activityBackgroundTint(.clear)
                    .activitySystemActionForegroundColor(.white)
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if context.state.showsDynamicIslandContent {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(context.state.petName)
                                .font(.headline.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            Text("今日 \(context.state.clampedTodaySteps.memoCompactFormatted)歩")
                                .font(.caption2.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text("満腹 \(context.state.clampedFullnessLevel)/\(context.state.clampedFullnessMaxLevel)")
                                .font(.caption2.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 4)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.showsDynamicIslandContent {
                        Image(context.state.petImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 78, height: 78)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.showsDynamicIslandContent {
                        VStack(spacing: 7) {
                            HStack(spacing: 8) {
                                MeMoLiveActivityMiniPill(
                                    title: "満腹度",
                                    value: "\(context.state.clampedFullnessLevel)/\(context.state.clampedFullnessMaxLevel)",
                                    progress: context.state.fullnessProgress,
                                    systemImage: "takeoutbag.and.cup.and.straw.fill"
                                )

                                MeMoLiveActivityMiniPill(
                                    title: "Lv.\(context.state.clampedHappinessLevel)",
                                    value: "\(context.state.clampedHappinessPoint)/\(context.state.clampedHappinessMaxPoint)",
                                    progress: context.state.happinessProgress,
                                    systemImage: "heart.fill"
                                )
                            }

                            MeMoLiveActivityGachaProgressView(state: context.state, compact: true)
                        }
                    }
                }
            } compactLeading: {
                if context.state.showsDynamicIslandContent {
                    Image(context.state.petImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
            } compactTrailing: {
                if context.state.showsDynamicIslandContent {
                    Text("\(context.state.clampedTodaySteps.memoCompactFormatted)歩")
                        .font(.caption2.monospacedDigit().weight(.bold))
                }
            } minimal: {
                if context.state.showsDynamicIslandContent {
                    Image(context.state.petImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                }
            }
            .keylineTint(.yellow)
        }
    }
}

private struct MeMoCareLockScreenLiveActivityView: View {
    let context: ActivityViewContext<MeMoCareActivityAttributes>

    var body: some View {
        ZStack {
            MeMoLiveActivityWallpaperBackground(assetName: context.state.wallpaperAssetName)

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.petName)
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)

                        HStack(spacing: 5) {
                            Image(systemName: "figure.walk")
                                .font(.caption2.weight(.bold))
                            Text("今日 \(context.state.clampedTodaySteps.memoFormatted)歩")
                                .font(.caption2.monospacedDigit().weight(.bold))
                        }
                        .foregroundStyle(.white.opacity(0.88))
                    }

                    VStack(spacing: 5) {
                        MeMoLiveActivityMetricLine(
                            title: "満腹度",
                            value: "\(context.state.clampedFullnessLevel)/\(context.state.clampedFullnessMaxLevel)",
                            progress: context.state.fullnessProgress,
                            systemImage: "takeoutbag.and.cup.and.straw.fill"
                        )

                        MeMoLiveActivityMetricLine(
                            title: "Lv.\(context.state.clampedHappinessLevel)",
                            value: "\(context.state.clampedHappinessPoint)/\(context.state.clampedHappinessMaxPoint)",
                            progress: context.state.happinessProgress,
                            systemImage: "heart.fill"
                        )
                    }

                    MeMoLiveActivityGachaProgressView(state: context.state, compact: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(context.state.petImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 116, height: 138)
                    .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 6)
                    .accessibilityLabel(Text(context.state.petName))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 2)
    }
}

private struct MeMoLiveActivityWallpaperBackground: View {
    let assetName: String

    var body: some View {
        ZStack {
            Image(assetName)
                .resizable()
                .scaledToFill()

            LinearGradient(
                colors: [
                    .black.opacity(0.72),
                    .black.opacity(0.42),
                    .black.opacity(0.66)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.14))
        }
    }
}

private struct MeMoLiveActivityMetricLine: View {
    let title: String
    let value: String
    let progress: Double
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
                    .frame(width: 14)

                Text(title)
                    .font(.caption2.weight(.semibold))

                Spacer(minLength: 6)

                Text(value)
                    .font(.caption2.monospacedDigit().weight(.heavy))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.94))

            ProgressView(value: min(1, max(0, progress)))
                .progressViewStyle(.linear)
                .tint(.yellow)
                .scaleEffect(x: 1, y: 0.62, anchor: .center)
        }
    }
}

private struct MeMoLiveActivityMiniPill: View {
    let title: String
    let value: String
    let progress: Double
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption2)
                Text(title)
                    .font(.caption2.weight(.semibold))
                Spacer(minLength: 2)
                Text(value)
                    .font(.caption2.monospacedDigit().weight(.bold))
            }
            .foregroundStyle(.white.opacity(0.94))

            ProgressView(value: min(1, max(0, progress)))
                .progressViewStyle(.linear)
                .tint(.yellow)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct MeMoLiveActivityGachaProgressView: View {
    let state: MeMoCareActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 4) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(compact ? .caption2 : .caption2.weight(.bold))

                Text("10連ガチャまで")
                    .font(compact ? .caption2.weight(.semibold) : .caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if state.tenGachaCompletedCount > 0 {
                    Text("×\(state.tenGachaCompletedCount)")
                        .font(compact ? .caption2.monospacedDigit().weight(.heavy) : .caption2.monospacedDigit().weight(.heavy))
                        .lineLimit(1)
                        .padding(.horizontal, compact ? 5 : 6)
                        .padding(.vertical, compact ? 1 : 2)
                        .background(.yellow.opacity(0.22), in: Capsule())
                }

                Spacer(minLength: 4)

                Text("\(state.tenGachaRemainderSteps.memoFormatted) / \(state.clampedTenGachaCost.memoFormatted)歩")
                    .font(compact ? .caption2.monospacedDigit().weight(.bold) : .caption2.monospacedDigit().weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
            .foregroundStyle(.white.opacity(0.94))

            ProgressView(value: state.tenGachaProgress)
                .progressViewStyle(.linear)
                .tint(.yellow)
                .scaleEffect(x: 1, y: compact ? 0.62 : 0.68, anchor: .center)
        }
        .padding(.horizontal, compact ? 8 : 9)
        .padding(.vertical, compact ? 6 : 7)
        .background(.black.opacity(0.26), in: RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous))
    }
}

private extension Int {
    var memoFormatted: String {
        Self.memoNumberFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    var memoCompactFormatted: String {
        if self >= 10_000 {
            let value = Double(self) / 10_000
            return String(format: "%.1f万", value)
        }
        return memoFormatted
    }

    private static let memoNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter
    }()
}
