//
//  MeMoWidgetLiveActivity.swift
//  MeMoWidgetExtension
//
//  Widget Extension UI for the care-status Live Activity.
//  Replace MeMoWidget/MeMoWidgetLiveActivity.swift with this content.
//  Add this file to the MeMoWidgetExtension target only.
//

import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

struct MeMoWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeMoCareActivityAttributes.self) { context in
            if context.state.showsLockScreenCard {
                TimelineView(.periodic(from: context.state.updatedAt, by: 60)) { timeline in
                    MeMoCareLockScreenLiveActivityView(context: context, now: timeline.date)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .activityBackgroundTint(.black)
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
                        TimelineView(.periodic(from: context.state.updatedAt, by: 60)) { timeline in
                            MeMoDynamicIslandLeadingView(state: context.state, now: timeline.date)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.showsDynamicIslandContent {
                        TimelineView(.periodic(from: context.state.updatedAt, by: 60)) { timeline in
                            MeMoDynamicIslandPetView(
                                state: context.state,
                                now: timeline.date,
                                size: CGSize(width: 112, height: 112)
                            )
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    EmptyView()
                }
            } compactLeading: {
                if context.state.showsDynamicIslandContent {
                    TimelineView(.periodic(from: context.state.updatedAt, by: 60)) { timeline in
                        MeMoDynamicIslandPetView(
                            state: context.state,
                            now: timeline.date,
                            size: CGSize(width: 24, height: 24)
                        )
                    }
                }
            } compactTrailing: {
                if context.state.showsDynamicIslandContent {
                    Text("\(context.state.clampedTodaySteps.memoCompactFormatted)歩")
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            } minimal: {
                if context.state.showsDynamicIslandContent {
                    TimelineView(.periodic(from: context.state.updatedAt, by: 60)) { timeline in
                        MeMoDynamicIslandPetView(
                            state: context.state,
                            now: timeline.date,
                            size: CGSize(width: 22, height: 22)
                        )
                    }
                }
            }
            .keylineTint(.yellow)
        }
    }
}

private struct MeMoDynamicIslandLeadingView: View {
    let state: MeMoCareActivityAttributes.ContentState
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(state.petName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("今日 \(state.clampedTodaySteps.memoCompactFormatted)歩")
                    .font(.title3.monospacedDigit().weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)

                Text("最終更新 \(state.updatedAt.memoHourMinuteFormatted)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 10)

            MeMoDynamicIslandFullnessPanel(state: state, now: now)
                .frame(width: 250, alignment: .leading)
        }
        .padding(.leading, 6)
        .padding(.top, 1)
        .frame(width: 258, height: 130, alignment: .topLeading)
        .clipped()
    }
}
private struct MeMoDynamicIslandPetView: View {
    let state: MeMoCareActivityAttributes.ContentState
    let now: Date
    let size: CGSize

    var body: some View {
        Image(state.effectivePetImageName(now: now))
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .accessibilityLabel(Text(state.petName))
    }
}


private struct MeMoCareLockScreenLiveActivityView: View {
    let context: ActivityViewContext<MeMoCareActivityAttributes>
    let now: Date

    private var state: MeMoCareActivityAttributes.ContentState { context.state }

    var body: some View {
        ZStack {
            Color.black

            MeMoLiveActivityWallpaperBackground(assetName: state.wallpaperAssetName)
                .clipped()

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 7) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.petName)
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: "figure.walk")
                                .font(.caption2.weight(.bold))

                            Text("今日 \(state.clampedTodaySteps.memoFormatted)歩")
                                .font(.caption2.monospacedDigit().weight(.bold))
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                        .foregroundStyle(.white.opacity(0.88))
                    }

                    MeMoLiveActivityFullnessCountdownView(state: state, now: now)

                    MeMoLiveActivityGachaProgressView(state: state, compact: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(state.effectivePetImageName(now: now))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 146)
                    .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 6)
                    .accessibilityLabel(Text(state.petName))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
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
                    .black.opacity(0.74),
                    .black.opacity(0.38),
                    .black.opacity(0.66)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.12))
        }
    }
}

private struct MeMoFullnessRemainingTimeText: View {
    let state: MeMoCareActivityAttributes.ContentState
    let now: Date

    var body: some View {
        if let interval = state.fullnessZeroDateInterval(now: now) {
            Text(timerInterval: interval.start...interval.end, countsDown: true)
        } else {
            Text(state.fullnessZeroRemainingText(now: now))
        }
    }
}

private struct MeMoLiveActivityFullnessCountdownView: View {
    let state: MeMoCareActivityAttributes.ContentState
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                    .font(.caption2.weight(.bold))
                    .frame(width: 14)

                Text("満腹")
                    .font(.caption2.weight(.semibold))

                Text("\(state.estimatedFullnessLevel(now: now))/\(state.clampedFullnessMaxLevel)")
                    .font(.caption2.monospacedDigit().weight(.heavy))
                    .lineLimit(1)

                Spacer(minLength: 6)

                HStack(spacing: 2) {
                    Text("0まで")
                    MeMoFullnessRemainingTimeText(state: state, now: now)
                }
                .font(.caption2.monospacedDigit().weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.58)
            }
            .foregroundStyle(.white.opacity(0.94))

            ProgressView(value: state.fullnessZeroProgress(now: now))
                .progressViewStyle(.linear)
                .tint(.yellow)
                .scaleEffect(x: 1, y: 0.62, anchor: .center)
        }
    }
}

private struct MeMoDynamicIslandFullnessPanel: View {
    let state: MeMoCareActivityAttributes.ContentState
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                        .font(.caption.weight(.bold))

                    Text("満腹度")
                        .font(.caption.weight(.bold))

                    Text("\(state.estimatedFullnessLevel(now: now))/\(state.clampedFullnessMaxLevel)")
                        .font(.caption.monospacedDigit().weight(.heavy))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("0まで")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.82))

                    MeMoFullnessRemainingTimeText(state: state, now: now)
                        .font(.caption.monospacedDigit().weight(.heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
                .foregroundStyle(.white)

                Spacer(minLength: 0)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.68)

            ProgressView(value: state.fullnessZeroProgress(now: now))
                .progressViewStyle(.linear)
                .tint(.yellow)
                .scaleEffect(x: 1, y: 0.9, anchor: .center)
        }
        .padding(.leading, 0)
        .padding(.trailing, 0)
        .padding(.top, 0)
        .padding(.bottom, 0)
        .frame(maxWidth: 250, maxHeight: 38, alignment: .leading)
        .layoutPriority(20)
    }
}

private struct MeMoLiveActivityFullnessMiniPill: View {
    let state: MeMoCareActivityAttributes.ContentState
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                    .font(.caption2)

                Text("満腹")
                    .font(.caption2.weight(.semibold))

                Spacer(minLength: 2)

                Text("\(state.estimatedFullnessLevel(now: now))/\(state.clampedFullnessMaxLevel)")
                    .font(.caption2.monospacedDigit().weight(.bold))
            }
            .foregroundStyle(.white.opacity(0.94))

            HStack(spacing: 4) {
                Text("0まで")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.76))

                Spacer(minLength: 2)

                MeMoFullnessRemainingTimeText(state: state, now: now)
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }

            ProgressView(value: state.fullnessZeroProgress(now: now))
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

                Text("10回ガチャまで")
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

                Text("あと \(state.tenGachaRemainingSteps.memoFormatted) 歩")
                    .font(compact ? .caption2.monospacedDigit().weight(.bold) : .caption2.monospacedDigit().weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
            .foregroundStyle(.white.opacity(0.94))

            ProgressView(value: state.tenGachaProgress)
                .progressViewStyle(.linear)
                .tint(.yellow)
                .scaleEffect(x: 1, y: compact ? 0.62 : 0.68, anchor: .center)

            if !compact {
                Text("最終更新 \(state.updatedAt.memoHourMinuteFormatted)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, compact ? 8 : 9)
        .padding(.vertical, compact ? 6 : 7)
        .background(.black.opacity(0.26), in: RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous))
    }
}

private extension Date {
    var memoHourMinuteFormatted: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: self)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
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
