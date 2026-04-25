//
//  WorkTimerPreparationView.swift
//  MeMo
//
//  Updated to add work focus rewards, a reward list screen,
//  and the dedicated work background across the work flow.
//  Updated to show Banner_Work in the timer screen and Interstitial_Get after reward claims.
//

import SwiftUI
import UIKit
import Combine
import AVFoundation

struct WorkTimerPreparationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bgmManager: BGMManager
    @StateObject private var viewModel = WorkTimerPreparationViewModel()

    @State private var showRewardsView: Bool = false

    var body: some View {
        GeometryReader { geo in
            let horizontalPadding: CGFloat = 20
            let availableHeight = geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom
            let sectionSpacing = min(18, max(10, availableHeight * 0.016))
            let topPadding = geo.safeAreaInsets.top + 80
            let bottomPadding = max(geo.safeAreaInsets.bottom, 24)
            let contentWidth = max(geo.size.width - (horizontalPadding * 2), 1)
            let maxSituationCardHeight = min(availableHeight * 0.52, 470)
            let situationCardWidth = min(contentWidth, maxSituationCardHeight * WorkCardMetrics.aspectRatio)

            ZStack {
                Image("work_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.22)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: sectionSpacing) {
                        headerView
                        focusSummaryCard
                        situationSelectionCard(cardWidth: situationCardWidth)
                        durationSettingCard
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .onAppear {
            bgmManager.switchBackground(to: .main)
            viewModel.refreshFocusSummaryIfNeeded()
            AdMobManager.shared.prepareInterstitialGetIfNeeded(isRewardClaimable: viewModel.hasClaimableRewards)
        }
        .onChange(of: viewModel.hasClaimableRewards) { _, canClaim in
            AdMobManager.shared.prepareInterstitialGetIfNeeded(isRewardClaimable: canClaim)
        }
        .onDisappear {
            if viewModel.activeSession == nil {
                bgmManager.restoreDefaultBackground()
            }
        }
        .fullScreenCover(isPresented: $showRewardsView) {
            WorkFocusRewardsView(viewModel: viewModel)
                .environmentObject(bgmManager)
        }
        .fullScreenCover(item: $viewModel.activeSession) { session in
            WorkTimerRunningView(session: session) { focusedSeconds in
                viewModel.recordFocusedTime(seconds: focusedSeconds)
                viewModel.activeSession = nil
            }
        }
    }

    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.55), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("ワーク")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            rewardListEntryButton
        }
    }

    private var rewardListEntryButton: some View {
        Button {
            showRewardsView = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image("presentBox")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)

                if viewModel.hasClaimableRewards {
                    Circle()
                        .fill(Color(red: 0.20, green: 0.90, blue: 0.38))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.95), lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
                        .offset(x: 4, y: -4)
                }
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("報酬一覧")
    }

    private var focusSummaryCard: some View {
        HStack(spacing: 12) {
            focusSummaryBlock(title: "今日", value: viewModel.todayFocusedDisplayText)
            focusSummaryBlock(title: "累計", value: viewModel.totalFocusedDisplayText)
        }
    }

    private func focusSummaryBlock(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))

            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.20))
        )
    }

    private func situationSelectionCard(cardWidth: CGFloat) -> some View {
        WorkSituationCarousel(
            options: viewModel.situationOptions,
            selectedSituation: viewModel.selectedSituation,
            cardWidth: cardWidth,
            onSelect: { situation in
                viewModel.start(with: situation)
            }
        )
    }

    private var durationSettingCard: some View {
        VStack(spacing: 10) {
            Text(viewModel.selectedDurationDisplayTitle)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            DurationSelectionSlider(
                options: viewModel.durationOptions,
                selectedIndex: viewModel.selectedDurationIndex,
                onSelectIndex: { index in
                    viewModel.selectDuration(at: index)
                }
            )

            HStack {
                Text("5分")
                Spacer()
                Text("無制限")
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white.opacity(0.70))
        }
        .padding(.top, -6)
        .padding(.horizontal, 4)
    }
}

private struct WorkFocusRewardsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WorkTimerPreparationViewModel

    @State private var didInitialScrollToBottom: Bool = false

    private let rewardRowHeight: CGFloat = 128
    private let rewardRowSpacing: CGFloat = 28
    private let bottomAnchorID = "work.reward.bottom.anchor"

    var body: some View {
        GeometryReader { geo in
            let horizontalPadding: CGFloat = 20
            let topPadding = geo.safeAreaInsets.top + 72
            let bottomPadding = max(geo.safeAreaInsets.bottom, 24)

            ZStack {
                Image("work_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.26)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    headerView
                    summaryCard
                    rewardsScrollView
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            viewModel.refreshFocusSummaryIfNeeded()
            AdMobManager.shared.prepareInterstitialGetIfNeeded(isRewardClaimable: viewModel.hasClaimableRewards)
        }
    }

    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.55), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("報酬一覧")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear
                .frame(width: 40, height: 40)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("累計集中時間")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))

            Text(viewModel.totalFocusedDisplayText)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(viewModel.nextRewardSummaryText)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var rewardsScrollView: some View {
        let descendingRewards = Array(viewModel.rewards.reversed())
        let contentHeight = WorkRewardsProgressColumn.contentHeight(
            rewardCount: descendingRewards.count,
            rowHeight: rewardRowHeight,
            spacing: rewardRowSpacing
        )

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: 18) {
                    WorkRewardsProgressColumn(
                        rewards: descendingRewards,
                        totalFocusedSeconds: viewModel.totalFocusedSeconds,
                        highestRewardSeconds: viewModel.highestRewardSeconds,
                        rowHeight: rewardRowHeight,
                        spacing: rewardRowSpacing
                    )
                    .frame(width: 32, height: contentHeight)

                    LazyVStack(spacing: rewardRowSpacing) {
                        ForEach(descendingRewards) { reward in
                            WorkRewardRow(
                                reward: reward,
                                canClaim: viewModel.canClaim(reward),
                                isClaimed: viewModel.isRewardClaimed(reward),
                                remainingText: viewModel.remainingTimeText(for: reward),
                                onClaim: {
                                    let shouldShowInterstitial = viewModel.canClaim(reward)
                                    withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                                        viewModel.claim(reward)
                                    }
                                    if shouldShowInterstitial {
                                        AdMobManager.shared.showInterstitialGetThenRun()
                                        AdMobManager.shared.prepareInterstitialGetIfNeeded(isRewardClaimable: viewModel.hasClaimableRewards)
                                    }
                                }
                            )
                            .frame(height: rewardRowHeight)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorID)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
            .onAppear {
                guard !didInitialScrollToBottom else { return }
                didInitialScrollToBottom = true

                DispatchQueue.main.async {
                    proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                }
            }
        }
    }
}

private struct WorkRewardRow: View {
    let reward: WorkFocusReward
    let canClaim: Bool
    let isClaimed: Bool
    let remainingText: String
    let onClaim: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(reward.rewardAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(reward.milestoneDisplayText)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("背景報酬")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))

                Text(reward.rewardAssetName)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 8)
            trailingStatusView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var trailingStatusView: some View {
        if isClaimed {
            statusCapsule(
                title: "受取済み",
                foregroundColor: .white,
                backgroundColor: Color.white.opacity(0.14)
            )
        } else if canClaim {
            Button(action: onClaim) {
                statusCapsule(
                    title: "受け取る",
                    foregroundColor: .white,
                    backgroundColor: Color(red: 0.16, green: 0.76, blue: 0.33)
                )
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .trailing, spacing: 6) {
                Text("未達成")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.76))

                Text("あと\(remainingText)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.90))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func statusCapsule(title: String, foregroundColor: Color, backgroundColor: Color) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(backgroundColor)
            )
    }
}

private struct WorkRewardsProgressColumn: View {
    let rewards: [WorkFocusReward]
    let totalFocusedSeconds: Int
    let highestRewardSeconds: Int
    let rowHeight: CGFloat
    let spacing: CGFloat

    var body: some View {
        GeometryReader { geo in
            let fullHeight = geo.size.height
            let fillHeight = resolvedFillHeight(fullHeight: fullHeight)
            let ascendingMilestones = rewards.map(\.milestoneHours).sorted()

            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 10)

                ForEach(1..<max(1, maximumHourValue), id: \.self) { hour in
                    Capsule()
                        .fill(hour.isMultiple(of: 5) ? Color.white.opacity(0.46) : Color.white.opacity(0.26))
                        .frame(width: hour.isMultiple(of: 5) ? 18 : 12, height: hour.isMultiple(of: 5) ? 3 : 2)
                        .position(x: geo.size.width * 0.5, y: yPosition(forHour: hour, fullHeight: fullHeight))
                }

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.21, green: 0.95, blue: 0.42),
                                Color(red: 0.91, green: 0.96, blue: 0.58)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 10, height: fillHeight)

                ForEach(Array(rewards.enumerated()), id: \.element.id) { index, reward in
                    Circle()
                        .fill(totalFocusedSeconds >= reward.milestoneSeconds ? Color(red: 0.22, green: 0.95, blue: 0.42) : Color.white.opacity(0.78))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.18), lineWidth: 1)
                        )
                        .position(
                            x: geo.size.width * 0.5,
                            y: Self.nodeCenterY(index: index, rowHeight: rowHeight, spacing: spacing)
                        )
                }
            }
        }
    }

    private var maximumHourValue: Int {
        max(rewards.map(\.milestoneHours).max() ?? (highestRewardSeconds / 3600), 1)
    }

    private func resolvedFillHeight(fullHeight: CGFloat) -> CGFloat {
        let clampedHours = max(0, min(Double(totalFocusedSeconds) / 3600.0, Double(maximumHourValue)))
        let milestones = rewards.map(\.milestoneHours).sorted()
        guard !milestones.isEmpty else { return 0 }

        let points: [(hours: Double, height: CGFloat)] = [(0, 0)] + milestones.enumerated().map { offset, milestone in
            let descendingIndex = rewards.firstIndex(where: { $0.milestoneHours == milestone }) ?? (rewards.count - 1 - offset)
            let centerY = Self.nodeCenterY(index: descendingIndex, rowHeight: rowHeight, spacing: spacing)
            return (Double(milestone), max(0, fullHeight - centerY))
        }

        guard let last = points.last else { return 0 }
        if clampedHours >= last.hours {
            return min(fullHeight, last.height)
        }

        for index in 1..<points.count {
            let previous = points[index - 1]
            let current = points[index]
            guard clampedHours <= current.hours else { continue }

            let span = max(current.hours - previous.hours, 0.0001)
            let ratio = (clampedHours - previous.hours) / span
            let interpolated = previous.height + CGFloat(ratio) * (current.height - previous.height)
            return max(0, min(fullHeight, interpolated))
        }

        return 0
    }

    private func yPosition(forHour hour: Int, fullHeight: CGFloat) -> CGFloat {
        let fillHeight = resolvedFillHeight(forHour: Double(hour), fullHeight: fullHeight)
        return max(0, min(fullHeight, fullHeight - fillHeight))
    }

    private func resolvedFillHeight(forHour hour: Double, fullHeight: CGFloat) -> CGFloat {
        let safeTotalSeconds = totalFocusedSeconds
        let proxyTotalSeconds = Int(hour * 3600.0)
        let proxy = WorkRewardsProgressColumn(
            rewards: rewards,
            totalFocusedSeconds: proxyTotalSeconds,
            highestRewardSeconds: highestRewardSeconds,
            rowHeight: rowHeight,
            spacing: spacing
        )
        _ = safeTotalSeconds
        return proxy.resolvedFillHeight(fullHeight: fullHeight)
    }

    static func contentHeight(rewardCount: Int, rowHeight: CGFloat, spacing: CGFloat) -> CGFloat {
        let rowsHeight = CGFloat(max(rewardCount, 0)) * rowHeight
        let spacingHeight = CGFloat(max(rewardCount - 1, 0)) * spacing
        return max(rowsHeight + spacingHeight, 1)
    }

    private static func nodeCenterY(index: Int, rowHeight: CGFloat, spacing: CGFloat) -> CGFloat {
        (rowHeight * 0.5) + (CGFloat(index) * (rowHeight + spacing))
    }
}

// MARK: - ViewModel

@MainActor
final class WorkTimerPreparationViewModel: ObservableObject {
    @Published var selectedSituation: WorkSituationOption = .workClay
    @Published var selectedDurationOption: WorkSessionDurationOption = .minutes(25)
    @Published var activeSession: WorkTimerSession?
    @Published private(set) var todayFocusedSeconds: Int = 0
    @Published private(set) var totalFocusedSeconds: Int = 0
    @Published private(set) var claimedRewardIDs: Set<String> = []

    let situationOptions: [WorkSituationOption] = WorkSituationOption.defaultOptions
    let durationOptions: [WorkSessionDurationOption] = WorkSessionDurationOption.defaultOptions
    let rewards: [WorkFocusReward] = WorkFocusReward.defaultRewards

    private let focusTodaySecondsKey = "memo.work.focus.todaySeconds"
    private let focusTotalSecondsKey = "memo.work.focus.totalSeconds"
    private let focusTodayDayKey = "memo.work.focus.todayDayKey"
    private let focusClaimedRewardIDsKey = "memo.work.focus.claimedRewardIDs"
    private let focusUnlockedRewardAssetNamesKey = "memo.work.focus.unlockedRewardAssetNames"

    init() {
        normalizeFocusSummaryIfNeeded()
        loadFocusSummary()
        loadRewardStates()
    }

    var selectedDurationDisplayTitle: String {
        selectedDurationOption.displayTitle
    }

    var selectedDurationIndex: Int {
        durationOptions.firstIndex(of: selectedDurationOption) ?? 0
    }

    var todayFocusedDisplayText: String {
        Self.formatSummary(seconds: todayFocusedSeconds)
    }

    var totalFocusedDisplayText: String {
        Self.formatSummary(seconds: totalFocusedSeconds)
    }

    var highestRewardSeconds: Int {
        rewards.map(\.milestoneSeconds).max() ?? (5 * 60 * 60)
    }

    var hasClaimableRewards: Bool {
        rewards.contains(where: canClaim(_:))
    }

    var nextRewardSummaryText: String {
        if let nextReward = rewards.first(where: { !isRewardClaimed($0) && totalFocusedSeconds < $0.milestoneSeconds }) {
            return "次は \(nextReward.milestoneDisplayText) 報酬まであと \(remainingTimeText(for: nextReward))"
        }

        if hasClaimableRewards {
            return "受け取れる報酬があります"
        }

        if rewards.allSatisfy({ isRewardClaimed($0) }) {
            return "現在の報酬はすべて受け取り済みです"
        }

        return "報酬は累計5時間ごとに受け取れます"
    }

    func start() {
        start(with: selectedSituation)
    }

    func start(with situation: WorkSituationOption) {
        selectedSituation = situation
        activeSession = WorkTimerSession(situation: situation, durationOption: selectedDurationOption)
    }

    func selectDuration(at index: Int) {
        guard !durationOptions.isEmpty else { return }
        let clampedIndex = min(max(0, index), durationOptions.count - 1)
        selectedDurationOption = durationOptions[clampedIndex]
    }

    func refreshFocusSummaryIfNeeded() {
        normalizeFocusSummaryIfNeeded()
        loadFocusSummary()
        loadRewardStates()
    }

    func recordFocusedTime(seconds: Int) {
        let safeSeconds = max(0, seconds)
        guard safeSeconds > 0 else {
            loadFocusSummary()
            loadRewardStates()
            return
        }

        normalizeFocusSummaryIfNeeded()

        let defaults = UserDefaults.standard
        let todayTotal = defaults.integer(forKey: focusTodaySecondsKey) + safeSeconds
        let allTimeTotal = defaults.integer(forKey: focusTotalSecondsKey) + safeSeconds

        defaults.set(todayTotal, forKey: focusTodaySecondsKey)
        defaults.set(allTimeTotal, forKey: focusTotalSecondsKey)
        defaults.set(Self.makeDayKey(Date()), forKey: focusTodayDayKey)

        loadFocusSummary()
        loadRewardStates()
    }

    func isRewardClaimed(_ reward: WorkFocusReward) -> Bool {
        claimedRewardIDs.contains(reward.id)
    }

    func canClaim(_ reward: WorkFocusReward) -> Bool {
        totalFocusedSeconds >= reward.milestoneSeconds && !isRewardClaimed(reward)
    }

    func remainingTimeText(for reward: WorkFocusReward) -> String {
        let remainingSeconds = max(0, reward.milestoneSeconds - totalFocusedSeconds)
        return Self.formatSummary(seconds: remainingSeconds)
    }

    func claim(_ reward: WorkFocusReward) {
        guard canClaim(reward) else { return }

        var nextClaimedIDs = claimedRewardIDs
        nextClaimedIDs.insert(reward.id)
        claimedRewardIDs = nextClaimedIDs

        let defaults = UserDefaults.standard
        defaults.set(Array(nextClaimedIDs).sorted(), forKey: focusClaimedRewardIDsKey)

        var unlockedAssets = Set(defaults.stringArray(forKey: focusUnlockedRewardAssetNamesKey) ?? [])
        unlockedAssets.insert(reward.rewardAssetName)
        defaults.set(Array(unlockedAssets).sorted(), forKey: focusUnlockedRewardAssetNamesKey)
    }

    private func normalizeFocusSummaryIfNeeded(now: Date = Date()) {
        let defaults = UserDefaults.standard
        let todayKey = Self.makeDayKey(now)
        let storedDayKey = defaults.string(forKey: focusTodayDayKey)

        guard storedDayKey != todayKey else { return }

        defaults.set(todayKey, forKey: focusTodayDayKey)
        defaults.set(0, forKey: focusTodaySecondsKey)
    }

    private func loadFocusSummary() {
        let defaults = UserDefaults.standard
        todayFocusedSeconds = max(0, defaults.integer(forKey: focusTodaySecondsKey))
        totalFocusedSeconds = max(0, defaults.integer(forKey: focusTotalSecondsKey))
    }

    private func loadRewardStates() {
        let defaults = UserDefaults.standard
        let storedIDs = defaults.stringArray(forKey: focusClaimedRewardIDsKey) ?? []
        claimedRewardIDs = Set(storedIDs)
    }

    private static func makeDayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func formatSummary(seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        let totalMinutes = safeSeconds / 60

        if safeSeconds >= 3600 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return "\(hours)時間\(minutes)分"
        }

        if totalMinutes > 0 {
            return "\(totalMinutes)分"
        }

        return "0分"
    }
}

// MARK: - Models

struct WorkFocusReward: Identifiable, Equatable, Hashable {
    let id: String
    let milestoneHours: Int
    let rewardAssetName: String

    var milestoneSeconds: Int {
        milestoneHours * 60 * 60
    }

    var milestoneDisplayText: String {
        "\(milestoneHours)時間"
    }

    static let defaultRewards: [WorkFocusReward] = [
        WorkFocusReward(id: "work.reward.5h", milestoneHours: 5, rewardAssetName: "concrete_background"),
        WorkFocusReward(id: "work.reward.10h", milestoneHours: 10, rewardAssetName: "field_background"),
        WorkFocusReward(id: "work.reward.15h", milestoneHours: 15, rewardAssetName: "beach_background"),
        WorkFocusReward(id: "work.reward.20h", milestoneHours: 20, rewardAssetName: "office_background"),
        WorkFocusReward(id: "work.reward.25h", milestoneHours: 25, rewardAssetName: "bath_background"),
        WorkFocusReward(id: "work.reward.30h", milestoneHours: 30, rewardAssetName: "japanese_background")
    ]
}

struct WorkSituationOption: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let cardAssetName: String
    let runningBackgroundResourceName: String

    static let workClay = WorkSituationOption(
        id: "work_clay",
        title: "ワーク",
        cardAssetName: "work_clay",
        runningBackgroundResourceName: "work"
    )

    static let defaultOptions: [WorkSituationOption] = [.workClay]
}

enum WorkSessionDurationOption: Hashable, Identifiable {
    case minutes(Int)
    case unlimited

    static let defaultOptions: [WorkSessionDurationOption] = {
        var values = Array(stride(from: 5, through: 180, by: 5)).map { WorkSessionDurationOption.minutes($0) }
        values.append(.unlimited)
        return values
    }()

    var id: String {
        switch self {
        case .minutes(let minutes): return "minutes_\(minutes)"
        case .unlimited: return "unlimited"
        }
    }

    var displayTitle: String {
        switch self {
        case .minutes(let minutes): return "\(minutes)分"
        case .unlimited: return "無制限"
        }
    }

    var subtitleText: String {
        switch self {
        case .minutes(let minutes): return "\(minutes)分集中します"
        case .unlimited: return "終了するまで集中時間を計測します"
        }
    }

    var totalSeconds: Int? {
        switch self {
        case .minutes(let minutes): return minutes * 60
        case .unlimited: return nil
        }
    }
}

struct WorkTimerSession: Identifiable, Equatable {
    let situation: WorkSituationOption
    let durationOption: WorkSessionDurationOption

    var id: String {
        "\(situation.id)_\(durationOption.id)"
    }
}

// MARK: - Running View

private struct WorkTimerRunningView: View {
    @EnvironmentObject private var bgmManager: BGMManager
    @StateObject private var viewModel: WorkTimerRunningViewModel

    let onFinish: (Int) -> Void

    init(session: WorkTimerSession, onFinish: @escaping (Int) -> Void) {
        _viewModel = StateObject(wrappedValue: WorkTimerRunningViewModel(session: session))
        self.onFinish = onFinish
    }

    var body: some View {
        GeometryReader { geo in
            let horizontalPadding: CGFloat = 24
            let topPadding = geo.safeAreaInsets.top + 18
            let bottomInset = max(geo.safeAreaInsets.bottom, 24)
            let availableHeight = geo.size.height - geo.safeAreaInsets.top - bottomInset
            let timerToVideoSpacing: CGFloat = 12
            let desiredVideoHeight = min(max(availableHeight * 0.64, 340), 660)
            let maxVideoHeight = max(130, availableHeight - 210)
            let videoHeight = min(desiredVideoHeight, maxVideoHeight)
            let videoToButtonsSpacing: CGFloat = 16
            let bannerTopSpacing: CGFloat = 8

            ZStack {
                Image("work_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.18)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    timerDisplay
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, topPadding)

                    Color.clear
                        .frame(height: timerToVideoSpacing)

                    WorkRunningVideoCard(
                        resourceName: viewModel.backgroundResourceName,
                        shouldPlay: viewModel.shouldPlayMedia
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: videoHeight)
                    .padding(.horizontal, horizontalPadding)

                    controlButtons
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, videoToButtonsSpacing)

                    // ✅ Banner_Work
                    // workタイマー画面の下部（ボタンの下）に表示。
                    AdBannerView(
                        placement: .work,
                        height: 64,
                        maxBannerWidth: 320,
                        contentHeight: 50,
                        topOffset: 6
                    )
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, bannerTopSpacing)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .ignoresSafeArea()
        }
        .interactiveDismissDisabled()
        .onAppear {
            bgmManager.stop(fadeDuration: 0.35)
            viewModel.startIfNeeded()
        }
        .onDisappear {
            viewModel.stop()
            bgmManager.restoreDefaultBackground(fadeDuration: 0.45)
        }
    }

    private var timerDisplay: some View {
        Text(viewModel.timeText)
            .font(.system(size: 72, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .minimumScaleFactor(0.55)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.28))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
    }

    private var controlButtons: some View {
        HStack(spacing: 16) {
            if !viewModel.isCompleted {
                runningControlButton(
                    title: viewModel.isPaused ? "再開" : "一時停止",
                    backgroundColor: Color.black.opacity(0.48)
                ) {
                    viewModel.togglePause()
                }
            }

            runningControlButton(
                title: "終了",
                backgroundColor: Color(red: 0.82, green: 0.18, blue: 0.20).opacity(0.92)
            ) {
                onFinish(viewModel.finish())
            }
        }
    }

    private func runningControlButton(title: String, backgroundColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct WorkRunningVideoCard: View {
    let resourceName: String
    let shouldPlay: Bool

    private let cornerRadius: CGFloat = 32

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius + 8, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .blur(radius: 22)
                .padding(10)

            WorkRunningBackgroundLayer(resourceName: resourceName, shouldPlay: shouldPlay)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.clear,
                                    Color.black.opacity(0.14)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.screen)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.26), radius: 22, x: 0, y: 14)
    }
}

// MARK: - Running ViewModel

@MainActor
private final class WorkTimerRunningViewModel: ObservableObject {
    @Published private(set) var timeText: String = "00:00:00"
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var isCompleted: Bool = false

    private let session: WorkTimerSession
    private let ambientAudioController = WorkSessionAmbientAudioController(assetName: "takibi")

    private var timerTask: Task<Void, Never>?
    private var focusedSeconds: Int = 0
    private var remainingSeconds: Int?
    private var hasFinishedSession: Bool = false

    init(session: WorkTimerSession) {
        self.session = session
        self.remainingSeconds = session.durationOption.totalSeconds
        configureInitialState()
    }

    var backgroundResourceName: String {
        session.situation.runningBackgroundResourceName
    }

    var shouldPlayMedia: Bool {
        !isPaused && !isCompleted
    }

    deinit {
        timerTask?.cancel()
    }

    func startIfNeeded() {
        ambientAudioController.playLoopIfNeeded(fadeDuration: 0.8)

        guard timerTask == nil else { return }

        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                if isPaused || isCompleted { continue }
                tick()
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
        ambientAudioController.stopImmediately()
    }

    func togglePause() {
        guard !isCompleted else { return }
        isPaused.toggle()

        if isPaused {
            ambientAudioController.fadeOutAndPause(duration: 0.45)
        } else {
            ambientAudioController.playLoopIfNeeded(fadeDuration: 0.65)
        }
    }

    func finish() -> Int {
        stop()
        guard !hasFinishedSession else { return focusedSeconds }
        hasFinishedSession = true
        return max(0, focusedSeconds)
    }

    private func configureInitialState() {
        switch session.durationOption {
        case .minutes:
            timeText = Self.formatAsClock(remainingSeconds ?? 0)
        case .unlimited:
            timeText = Self.formatAsClock(0)
        }
    }

    private func tick() {
        focusedSeconds += 1

        if let currentRemaining = remainingSeconds {
            let nextRemaining = max(0, currentRemaining - 1)
            remainingSeconds = nextRemaining
            timeText = Self.formatAsClock(nextRemaining)

            if nextRemaining == 0 {
                isCompleted = true
                isPaused = true
                ambientAudioController.fadeOutAndPause(duration: 0.55)
                stopTimerTask()
            }
        } else {
            timeText = Self.formatAsClock(focusedSeconds)
        }
    }

    private func stopTimerTask() {
        timerTask?.cancel()
        timerTask = nil
    }

    private static func formatAsClock(_ totalSeconds: Int) -> String {
        let safe = max(0, totalSeconds)
        let hours = safe / 3600
        let minutes = (safe % 3600) / 60
        let seconds = safe % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

private final class WorkSessionAmbientAudioController {
    private let assetName: String
    private let targetVolume: Float = 0.72

    private var player: AVAudioPlayer?
    private var fadeTask: Task<Void, Never>?
    private var cachedBundleURL: URL?
    private var cachedAssetData: Data?

    init(assetName: String) {
        self.assetName = assetName
    }

    deinit {
        fadeTask?.cancel()
        player?.stop()
    }

    @MainActor
    func playLoopIfNeeded(fadeDuration: TimeInterval) {
        do {
            try configureAudioSessionIfNeeded()
            try preparePlayerIfNeeded()
        } catch {
            print("❌ Work ambient audio prepare failed: \(error.localizedDescription)")
            return
        }

        guard let player else { return }

        fadeTask?.cancel()

        if !player.isPlaying {
            if player.currentTime >= player.duration {
                player.currentTime = 0
            }
            player.play()
        }

        let startVolume = max(0, min(targetVolume, player.volume))
        player.volume = startVolume
        scheduleFade(from: startVolume, to: targetVolume, duration: fadeDuration)
    }

    @MainActor
    func fadeOutAndPause(duration: TimeInterval) {
        guard let player else { return }
        fadeTask?.cancel()
        let currentVolume = max(0, min(targetVolume, player.volume))
        scheduleFade(from: currentVolume, to: 0, duration: duration) {
            player.pause()
            player.volume = 0
        }
    }

    @MainActor
    func fadeOutAndStop(duration: TimeInterval) {
        guard let player else { return }
        fadeTask?.cancel()
        let currentVolume = max(0, min(targetVolume, player.volume))
        scheduleFade(from: currentVolume, to: 0, duration: duration) {
            player.stop()
            player.currentTime = 0
            player.volume = 0
        }
    }

    @MainActor
    func stopImmediately() {
        fadeTask?.cancel()
        player?.stop()
        player?.currentTime = 0
        player?.volume = 0
    }

    @MainActor
    private func preparePlayerIfNeeded() throws {
        if player != nil { return }

        let resolvedPlayer = try makeAudioPlayer(named: assetName)
        resolvedPlayer.numberOfLoops = -1
        resolvedPlayer.volume = 0
        resolvedPlayer.prepareToPlay()
        player = resolvedPlayer
    }

    @MainActor
    private func scheduleFade(from startVolume: Float, to endVolume: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        fadeTask?.cancel()

        guard let player else {
            completion?()
            return
        }

        let safeDuration = max(0.01, duration)
        let stepCount = max(1, Int((safeDuration / 0.05).rounded(.up)))
        let sleepNanoseconds = UInt64((safeDuration / Double(stepCount)) * 1_000_000_000)

        fadeTask = Task { @MainActor in
            for step in 0...stepCount {
                guard !Task.isCancelled else { return }
                let progress = Float(step) / Float(stepCount)
                let nextVolume = startVolume + ((endVolume - startVolume) * progress)
                player.volume = max(0, min(targetVolume, nextVolume))

                if step < stepCount {
                    try? await Task.sleep(nanoseconds: sleepNanoseconds)
                }
            }

            completion?()
            fadeTask = nil
        }
    }

    private func configureAudioSessionIfNeeded() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [])
        try session.setActive(true)
    }

    private func makeAudioPlayer(named name: String) throws -> AVAudioPlayer {
        if let url = findAudioFileURLInBundle(named: name) {
            return try AVAudioPlayer(contentsOf: url)
        }

        if let data = findAudioDataAsset(named: name) {
            return try AVAudioPlayer(data: data)
        }

        throw NSError(
            domain: "WorkSessionAmbientAudioController",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "音源が見つかりません: \(name)"]
        )
    }

    private func findAudioFileURLInBundle(named name: String) -> URL? {
        if let cachedBundleURL { return cachedBundleURL }

        let candidates = ["m4a", "mp3", "wav", "aif", "aiff", "caf"]
        for ext in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                cachedBundleURL = url
                return url
            }
        }
        return nil
    }

    private func findAudioDataAsset(named name: String) -> Data? {
        if let cachedAssetData { return cachedAssetData }

        if let data = NSDataAsset(name: name)?.data {
            cachedAssetData = data
            return data
        }

        return nil
    }
}

// MARK: - Situation Card

private struct WorkSituationCarousel: View {
    let options: [WorkSituationOption]
    let selectedSituation: WorkSituationOption
    let cardWidth: CGFloat
    let onSelect: (WorkSituationOption) -> Void

    var body: some View {
        Group {
            if options.count <= 1, let single = options.first {
                HStack {
                    Spacer(minLength: 0)
                    WorkSituationCard(
                        situation: single,
                        cardWidth: cardWidth,
                        isSelected: single == selectedSituation,
                        action: { onSelect(single) }
                    )
                    Spacer(minLength: 0)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(options) { option in
                            WorkSituationCard(
                                situation: option,
                                cardWidth: cardWidth,
                                isSelected: option == selectedSituation,
                                action: { onSelect(option) }
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }
}

private struct WorkSituationCard: View {
    let situation: WorkSituationOption
    let cardWidth: CGFloat
    let isSelected: Bool
    let action: () -> Void

    private var cardHeight: CGFloat {
        cardWidth / WorkCardMetrics.aspectRatio
    }

    var body: some View {
        Button(action: action) {
            Image(situation.cardAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: WorkCardMetrics.cornerRadius,
                        style: .continuous
                    )
                )
                .shadow(
                    color: .black.opacity(isSelected ? 0.28 : 0.18),
                    radius: WorkCardMetrics.shadowRadius,
                    x: 0,
                    y: WorkCardMetrics.shadowYOffset
                )
                .scaleEffect(isSelected ? 1.0 : 0.985)
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: WorkCardMetrics.cornerRadius,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Duration Slider

private struct DurationSelectionSlider: View {
    let options: [WorkSessionDurationOption]
    let selectedIndex: Int
    let onSelectIndex: (Int) -> Void

    private let thumbSize: CGFloat = 42
    private let trackHeight: CGFloat = 12
    private let trackBackgroundColor = Color(red: 0.39, green: 0.31, blue: 0.11).opacity(0.70)
    private let trackFillColor = Color(red: 0.73, green: 0.59, blue: 0.19)

    var body: some View {
        GeometryReader { geo in
            let usableWidth = max(geo.size.width - thumbSize, 1)
            let maxIndex = max(options.count - 1, 1)
            let stepWidth = usableWidth / CGFloat(maxIndex)
            let clampedIndex = min(max(0, selectedIndex), options.count - 1)
            let thumbOffset = CGFloat(clampedIndex) * stepWidth

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackBackgroundColor)
                    .frame(height: trackHeight)

                Capsule()
                    .fill(trackFillColor)
                    .frame(width: thumbOffset + (thumbSize * 0.5), height: trackHeight)

                Image("clock")
                    .resizable()
                    .scaledToFit()
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.22), radius: 8, x: 0, y: 4)
                    .offset(x: thumbOffset)
            }
            .frame(height: thumbSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateSelection(for: value.location.x, usableWidth: usableWidth, maxIndex: maxIndex)
                    }
                    .onEnded { value in
                        updateSelection(for: value.location.x, usableWidth: usableWidth, maxIndex: maxIndex)
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        updateSelection(for: value.location.x, usableWidth: usableWidth, maxIndex: maxIndex)
                    }
            )
        }
        .frame(height: 50)
    }

    private func updateSelection(for xPosition: CGFloat, usableWidth: CGFloat, maxIndex: Int) {
        guard !options.isEmpty else { return }

        let clampedX = min(max(0, xPosition - (thumbSize * 0.5)), usableWidth)
        let ratio = clampedX / max(usableWidth, 1)
        let resolvedIndex = Int(round(ratio * CGFloat(maxIndex)))
        onSelectIndex(min(max(0, resolvedIndex), options.count - 1))
    }
}

// MARK: - Running Background

private struct WorkRunningBackgroundLayer: View {
    let resourceName: String
    let shouldPlay: Bool

    @StateObject private var controller = LoopingVideoPlayerController()

    var body: some View {
        Group {
            if hasVideoAsset {
                LoopingVideoPlayer(controller: controller)
                    .onAppear {
                        controller.prepare(assetName: resourceName)
                        updatePlaybackState()
                    }
                    .onDisappear {
                        controller.pause()
                    }
                    .onChange(of: resourceName) { _, newValue in
                        controller.prepare(assetName: newValue)
                        updatePlaybackState()
                    }
                    .onChange(of: shouldPlay) { _, _ in
                        updatePlaybackState()
                    }
            } else {
                Image("work_background")
                    .resizable()
                    .scaledToFill()
            }
        }
    }

    private func updatePlaybackState() {
        if shouldPlay {
            controller.play()
        } else {
            controller.pause()
        }
    }

    private var hasVideoAsset: Bool {
        ["mp4", "mov", "m4v"].contains {
            Bundle.main.url(forResource: resourceName, withExtension: $0) != nil
        }
    }
}

private enum WorkCardMetrics {
    static let cornerRadius: CGFloat = 20
    static let shadowRadius: CGFloat = 16
    static let shadowYOffset: CGFloat = 10
    static let aspectRatio: CGFloat = 367.0 / 512.0
}
