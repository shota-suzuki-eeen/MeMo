//
//  MeMoWidgetLiveActivity.swift
//  MeMoWidgetExtension
//
//  Widget Extension UI for the care-status Live Activity.
//  Replace the generated MeMoWidget/MeMoWidgetLiveActivity.swift with this content. Add this file to the MeMoWidgetExtension target only.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct MeMoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeMoCareActivityAttributes.self) { context in
            MeMoCareLockScreenLiveActivityView(context: context)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.petName)
                            .font(.headline)
                            .lineLimit(1)

                        MeMoLiveActivityMetricLine(
                            title: "歩数",
                            value: "\(context.state.clampedTodaySteps)/\(context.state.clampedDailyStepGoal)",
                            progress: context.state.stepProgress,
                            systemImage: "figure.walk"
                        )
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Image(context.state.petImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 70, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            MeMoLiveActivityMiniPill(
                                title: "満腹",
                                value: "\(context.state.clampedFullnessLevel)/\(context.state.clampedFullnessMaxLevel)",
                                progress: context.state.fullnessProgress,
                                systemImage: "takeoutbag.and.cup.and.straw.fill"
                            )

                            MeMoLiveActivityMiniPill(
                                title: "ごきげん",
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
                    .clipShape(Circle())
            } compactTrailing: {
                Text("あと\(context.state.tenGachaRemainingSteps)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
            } minimal: {
                Image(context.state.petImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .clipShape(Circle())
            }
            .keylineTint(.yellow)
        }
    }
}

private struct MeMoCareLockScreenLiveActivityView: View {
    let context: ActivityViewContext<MeMoCareActivityAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "pawprint.fill")
                        .font(.caption.weight(.bold))
                    Text(context.attributes.appDisplayName)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.secondary)

                Text(context.state.petName)
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                VStack(spacing: 8) {
                    MeMoLiveActivityMetricLine(
                        title: "歩数",
                        value: "\(context.state.clampedTodaySteps)/\(context.state.clampedDailyStepGoal)",
                        progress: context.state.stepProgress,
                        systemImage: "figure.walk"
                    )

                    MeMoLiveActivityMetricLine(
                        title: "満腹度",
                        value: "\(context.state.clampedFullnessLevel)/\(context.state.clampedFullnessMaxLevel)",
                        progress: context.state.fullnessProgress,
                        systemImage: "takeoutbag.and.cup.and.straw.fill"
                    )

                    MeMoLiveActivityMetricLine(
                        title: "ごきげん",
                        value: "\(context.state.clampedHappinessPoint)/\(context.state.clampedHappinessMaxPoint)",
                        progress: context.state.happinessProgress,
                        systemImage: "heart.fill"
                    )
                }

                MeMoLiveActivityGachaProgressView(state: context.state, compact: false)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(context.state.petImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 106, height: 126)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(radius: 8, y: 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .padding(.horizontal, 2)
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
                    .frame(width: 16)

                Text(title)
                    .font(.caption.weight(.semibold))

                Spacer(minLength: 6)

                Text(value)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .lineLimit(1)
            }

            ProgressView(value: min(1, max(0, progress)))
                .progressViewStyle(.linear)
                .tint(.yellow)
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

            ProgressView(value: min(1, max(0, progress)))
                .progressViewStyle(.linear)
                .tint(.yellow)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

                Text(state.tenGachaRemainingSteps == 0 ? "OK" : "あと\(state.tenGachaRemainingSteps)歩")
                    .font(compact ? .caption2.monospacedDigit().weight(.bold) : .caption.monospacedDigit().weight(.bold))
                    .lineLimit(1)
            }

            ProgressView(value: state.tenGachaProgress)
                .progressViewStyle(.linear)
                .tint(.yellow)
        }
        .padding(compact ? 8 : 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous))
    }
}
