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
            MeMoCareLockScreenLiveActivityView(context: context)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(context.attributes.appDisplayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(context.state.petName)
                            .font(.headline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Text("\(context.state.clampedTodaySteps.memoFormatted)歩")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Image(context.state.petImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
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
            } compactLeading: {
                Image(context.state.petImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
            } compactTrailing: {
                Text("\(context.state.clampedTodaySteps.memoCompactFormatted)歩")
                    .font(.caption2.monospacedDigit().weight(.bold))
            } minimal: {
                Image(context.state.petImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
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

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 9) {
                    header

                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.state.petName)
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)

                        HStack(spacing: 5) {
                            Image(systemName: "figure.walk")
                                .font(.caption.weight(.bold))
                            Text("今日 \(context.state.clampedTodaySteps.memoFormatted)歩")
                                .font(.caption.monospacedDigit().weight(.bold))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                    }

                    VStack(spacing: 7) {
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
                    .frame(width: 106, height: 126)
                    .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 6)
                    .accessibilityLabel(Text(context.state.petName))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 2)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "pawprint.fill")
                .font(.caption.weight(.bold))
            Text(context.attributes.appDisplayName)
                .font(.caption.weight(.semibold))
            Spacer(minLength: 8)
            Text("お世話中")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.18), in: Capsule())
        }
        .foregroundStyle(.white.opacity(0.92))
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
                    .black.opacity(0.70),
                    .black.opacity(0.40),
                    .black.opacity(0.62)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.16))
        }
    }
}

private struct MeMoLiveActivityMetricLine: View {
    let title: String
    let value: String
    let progress: Double
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
                    .frame(width: 15)

                Text(title)
                    .font(.caption.weight(.semibold))

                Spacer(minLength: 6)

                Text(value)
                    .font(.caption.monospacedDigit().weight(.heavy))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.94))

            ProgressView(value: min(1, max(0, progress)))
                .progressViewStyle(.linear)
                .tint(.yellow)
                .scaleEffect(x: 1, y: 0.72, anchor: .center)
        }
    }
}

private struct MeMoLiveActivityMiniPill: View {
    let title: String
    let value: String
    let progress: Double
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct MeMoLiveActivityGachaProgressView: View {
    let state: MeMoCareActivityAttributes.ContentState
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(compact ? .caption2 : .caption.weight(.bold))

                Text("次の10連ガチャまで")
                    .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))

                Spacer(minLength: 6)

                Text("\(state.clampedWalletSteps.memoFormatted) / \(state.clampedTenGachaCost.memoFormatted)歩")
                    .font(compact ? .caption2.monospacedDigit().weight(.bold) : .caption.monospacedDigit().weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .foregroundStyle(.white.opacity(0.94))

            ProgressView(value: state.tenGachaProgress)
                .progressViewStyle(.linear)
                .tint(.yellow)
                .scaleEffect(x: 1, y: compact ? 0.7 : 0.78, anchor: .center)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 7 : 9)
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
