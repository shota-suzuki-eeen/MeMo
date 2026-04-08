//
//  StepView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import SwiftUI
import SwiftData
import UIKit
import MapKit
import Charts

struct StepView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var bgmManager: BGMManager

    @Query(sort: \WorkoutSessionRecord.startedAt, order: .reverse)
    private var workoutRecords: [WorkoutSessionRecord]

    let state: AppState
    @ObservedObject var hk: HealthKitManager
    let onSave: () -> Void

    @StateObject private var viewModel = StepViewModel()

    @State private var shouldStartAfterPermission = false
    @State private var countdownNumber: Int?
    @State private var countdownScale: CGFloat = 0.42
    @State private var countdownOpacity: Double = 0
    @State private var countdownBlur: CGFloat = 18
    @State private var countdownTask: Task<Void, Never>?

    @State private var selectedScreen: DisplayScreen = .run

    private enum DisplayScreen {
        case run
        case activity
    }

    private enum Layout {
        static let startButtonSize: CGFloat = 212
        static let idleBottomPadding: CGFloat = 192
        static let sectionHorizontalPadding: CGFloat = 20
        static let bottomCardCornerRadius: CGFloat = 30
        static let closeButtonSize: CGFloat = 40

        static let switcherBottomPadding: CGFloat = 42
        static let switcherSpacing: CGFloat = 34
        static let switcherHorizontalPadding: CGFloat = 26
        static let switcherVerticalPadding: CGFloat = 18

        static let activityBottomPadding: CGFloat = 180
    }

    var body: some View {
        ZStack {
            surfaceBackground
                .ignoresSafeArea()

            if shouldShowFocusedMapBackground {
                StepFocusedMapBackground(
                    points: backdropRoutePoints,
                    followsUserLocation: shouldFollowUserLocation,
                    isCondensed: isPrimarySwitcherScreen
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }

            contentView

            if shouldShowScreenSwitcher {
                VStack {
                    Spacer()
                    screenSwitcher
                        .padding(.bottom, Layout.switcherBottomPadding)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            topBar

            countdownOverlay
        }
        .navigationBarHidden(true)
        .task {
            viewModel.configureIfNeeded()
            _ = hk.todaySteps
        }
        .onChange(of: scenePhase) { _, newValue in
            viewModel.handleScenePhase(newValue)
        }
        .onChange(of: viewModel.locationAuthorizationState) { _, newValue in
            handleAuthorizationChanged(newValue)
        }
        .onDisappear {
            cancelCountdownFlow()
        }
    }

    private var backdropRoutePoints: [WorkoutRoutePoint] {
        viewModel.finishedSession?.routePoints ?? viewModel.routePoints
    }

    private var shouldFollowUserLocation: Bool {
        switch viewModel.sessionState {
        case .idle, .waitingForPermission, .countingDown, .running, .paused:
            return true
        case .finished:
            return false
        }
    }

    private var isPrimarySwitcherScreen: Bool {
        switch viewModel.sessionState {
        case .idle, .waitingForPermission, .countingDown:
            return true
        case .running, .paused, .finished:
            return false
        }
    }

    private var shouldShowScreenSwitcher: Bool {
        isPrimarySwitcherScreen && countdownNumber == nil
    }

    private var shouldShowFocusedMapBackground: Bool {
        switch viewModel.sessionState {
        case .idle, .waitingForPermission, .countingDown:
            return selectedScreen == .run
        case .running, .paused, .finished:
            return true
        }
    }

    @ViewBuilder
    private var surfaceBackground: some View {
        switch viewModel.sessionState {
        case .idle, .waitingForPermission, .countingDown:
            switch selectedScreen {
            case .run:
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.98, blue: 0.99),
                        Color(red: 0.95, green: 0.96, blue: 0.98),
                        Color(red: 0.93, green: 0.94, blue: 0.97)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .activity:
                Color(red: 0.96, green: 0.96, blue: 0.97)
            }
        case .running, .paused:
            LinearGradient(
                colors: [
                    Color(red: 0.91, green: 0.93, blue: 0.96),
                    Color(red: 0.86, green: 0.88, blue: 0.92),
                    Color(red: 0.80, green: 0.83, blue: 0.89)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .finished:
            LinearGradient(
                colors: [
                    Color(red: 0.87, green: 0.90, blue: 0.94),
                    Color(red: 0.79, green: 0.83, blue: 0.89),
                    Color(red: 0.70, green: 0.74, blue: 0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var topBar: some View {
        VStack {
            HStack(spacing: 12) {
                Spacer()

                if shouldShowQuickRunButton {
                    Button {
                        bgmManager.playSE(.push)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            selectedScreen = .run
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: Layout.closeButtonSize, height: Layout.closeButtonSize)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    bgmManager.playSE(.push)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: Layout.closeButtonSize, height: Layout.closeButtonSize)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()
        }
    }

    private var shouldShowQuickRunButton: Bool {
        switch viewModel.sessionState {
        case .idle, .waitingForPermission, .countingDown:
            return selectedScreen == .activity
        case .running, .paused, .finished:
            return false
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.sessionState {
        case .idle, .waitingForPermission, .countingDown:
            switch selectedScreen {
            case .run:
                idleContentView
            case .activity:
                activityContentView
            }
        case .running, .paused:
            activeContentView
        case .finished:
            finishedContentView
        }
    }

    private var screenSwitcher: some View {
        HStack(alignment: .top, spacing: Layout.switcherSpacing) {
            StepScreenSwitchButton(
                title: "ラン",
                systemImage: "figure.run",
                isSelected: selectedScreen == .run
            ) {
                bgmManager.playSE(.push)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    selectedScreen = .run
                }
            }

            StepScreenSwitchButton(
                title: "アクティビティ",
                systemImage: "chart.bar.xaxis",
                isSelected: selectedScreen == .activity
            ) {
                bgmManager.playSE(.push)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    selectedScreen = .activity
                }
            }
        }
        .padding(.horizontal, Layout.switcherHorizontalPadding)
        .padding(.vertical, Layout.switcherVerticalPadding)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.32), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
        .padding(.horizontal, 20)
    }

    private var idleContentView: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            Button {
                handleStartButtonTapped()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.96, green: 0.84, blue: 0.12))
                        .shadow(color: .black.opacity(0.14), radius: 22, x: 0, y: 10)

                    Text("スタート")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                }
                .frame(width: Layout.startButtonSize, height: Layout.startButtonSize)
            }
            .buttonStyle(.plain)
            .disabled(
                viewModel.sessionState == .waitingForPermission ||
                viewModel.sessionState == .countingDown
            )
            .opacity(
                viewModel.sessionState == .waitingForPermission ||
                viewModel.sessionState == .countingDown ? 0.92 : 1
            )

            idleFooterContent
                .padding(.horizontal, 24)
        }
        .padding(.bottom, Layout.idleBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var activityContentView: some View {
        StepActivityDashboardView(
            records: workoutRecords,
            bottomInset: Layout.activityBottomPadding
        ) {
            bgmManager.playSE(.push)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                selectedScreen = .run
            }
        }
    }

    @ViewBuilder
    private var idleFooterContent: some View {
        switch viewModel.locationAuthorizationState {
        case .authorizedAlways, .authorizedWhenInUse:
            EmptyView()
        case .notDetermined:
            Text("位置情報の利用許可後に計測を開始します")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.72))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: Capsule())
        case .restricted, .denied:
            VStack(spacing: 12) {
                Text("距離表示とルート保存のため、位置情報の許可が必要です")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.78))
                    .multilineTextAlignment(.center)

                Button {
                    bgmManager.playSE(.push)
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                } label: {
                    Text("設定を開く")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var activeContentView: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    StepMetricTile(
                        title: "時間",
                        value: viewModel.formattedElapsedTime,
                        valueFontSize: 36
                    )

                    StepMetricTile(
                        title: "距離",
                        value: viewModel.formattedDistanceKilometers,
                        valueFontSize: 28
                    )
                }

                if let accuracyMessage = viewModel.accuracyMessage {
                    Text(accuracyMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Layout.bottomCardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.bottomCardCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .padding(.horizontal, Layout.sectionHorizontalPadding)

            HStack(spacing: 14) {
                Button {
                    bgmManager.playSE(.push)
                    viewModel.togglePause()
                } label: {
                    Text(viewModel.pauseButtonTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Color.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    bgmManager.playSE(.push)
                    viewModel.finishWorkout()
                } label: {
                    Text("終了")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Layout.sectionHorizontalPadding)
        }
        .padding(.bottom, 42)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var finishedContentView: some View {
        VStack {
            Spacer(minLength: 0)

            VStack(spacing: 18) {
                Text("ワークアウト完了")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))

                HStack(spacing: 12) {
                    StepMetricTile(
                        title: "時間",
                        value: viewModel.summaryElapsedText,
                        valueFontSize: 30
                    )

                    StepMetricTile(
                        title: "距離",
                        value: viewModel.summaryDistanceText,
                        valueFontSize: 24
                    )
                }

                if let saveMessage = viewModel.saveMessage {
                    Text(saveMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }

                HStack(spacing: 14) {
                    Button {
                        bgmManager.playSE(.push)
                        viewModel.saveFinishedWorkout(
                            modelContext: modelContext,
                            characterID: state.normalizedCurrentPetID
                        )
                        onSave()
                    } label: {
                        Text(saveButtonTitle)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(saveButtonForegroundColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(saveButtonBackground)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canTapSaveButton)

                    Button {
                        bgmManager.playSE(.push)
                        viewModel.handlePrimaryAction()
                    } label: {
                        Text("もう一度")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Layout.bottomCardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.bottomCardCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .padding(.horizontal, Layout.sectionHorizontalPadding)
            .padding(.bottom, 42)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    @ViewBuilder
    private var countdownOverlay: some View {
        if let countdownNumber {
            ZStack {
                Color.black.opacity(0.98)
                    .ignoresSafeArea()

                Text("\(countdownNumber)")
                    .font(.system(size: 220, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.93, green: 0.88, blue: 0.02))
                    .monospacedDigit()
                    .scaleEffect(countdownScale)
                    .opacity(countdownOpacity)
                    .blur(radius: countdownBlur)
            }
            .transition(.opacity)
        }
    }

    private var canTapSaveButton: Bool {
        if case .saving = viewModel.saveState { return false }
        if case .saved = viewModel.saveState { return false }
        return true
    }

    private var saveButtonTitle: String {
        switch viewModel.saveState {
        case .idle, .failed:
            return "ルートを保存"
        case .saving:
            return "保存中..."
        case .saved:
            return "保存済み"
        }
    }

    private var saveButtonForegroundColor: Color {
        switch viewModel.saveState {
        case .saved:
            return .white
        default:
            return .black
        }
    }

    @ViewBuilder
    private var saveButtonBackground: some View {
        switch viewModel.saveState {
        case .saved:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.green.opacity(0.82))
        default:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        }
    }

    private func handleStartButtonTapped() {
        selectedScreen = .run
        bgmManager.playSE(.push)

        switch viewModel.prepareWorkoutStart() {
        case .startCountdown:
            startCountdownFlow()
        case .waitingForPermission:
            shouldStartAfterPermission = true
        case .blocked:
            shouldStartAfterPermission = false
        }
    }

    private func handleAuthorizationChanged(_ newValue: LocationTrackingManager.AuthorizationState) {
        guard shouldStartAfterPermission else { return }

        if newValue.isAuthorized {
            shouldStartAfterPermission = false
            viewModel.beginCountdown()
            startCountdownFlow()
        } else if newValue == .denied || newValue == .restricted {
            shouldStartAfterPermission = false
        }
    }

    private func startCountdownFlow() {
        guard countdownTask == nil else { return }

        countdownTask = Task { @MainActor in
            for number in [3, 2, 1] {
                showCountdown(number)

                withAnimation(.easeOut(duration: 0.28)) {
                    countdownScale = 1.0
                    countdownOpacity = 1.0
                    countdownBlur = 0
                }

                do {
                    try await Task.sleep(nanoseconds: 650_000_000)
                } catch {
                    finishCancelledCountdown()
                    return
                }

                withAnimation(.easeIn(duration: 0.16)) {
                    countdownOpacity = 0
                    countdownScale = 1.06
                }

                do {
                    try await Task.sleep(nanoseconds: 160_000_000)
                } catch {
                    finishCancelledCountdown()
                    return
                }
            }

            clearCountdownOverlay()
            countdownTask = nil
            viewModel.beginWorkoutAfterCountdown()
        }
    }

    private func showCountdown(_ number: Int) {
        countdownNumber = number
        countdownScale = 0.42
        countdownOpacity = 0
        countdownBlur = 18
    }

    private func clearCountdownOverlay() {
        countdownNumber = nil
        countdownScale = 0.42
        countdownOpacity = 0
        countdownBlur = 18
    }

    private func finishCancelledCountdown() {
        countdownTask = nil
        clearCountdownOverlay()
        viewModel.cancelCountdownIfNeeded()
    }

    private func cancelCountdownFlow() {
        shouldStartAfterPermission = false
        countdownTask?.cancel()
        countdownTask = nil
        clearCountdownOverlay()
        viewModel.cancelCountdownIfNeeded()
    }
}

private struct StepActivityDashboardView: View {
    let records: [WorkoutSessionRecord]
    let bottomInset: CGFloat
    let onTapRun: () -> Void

    @State private var selectedRange: StepActivityRange = .week

    private var summary: StepActivitySummary {
        StepActivitySummary(records: records, range: selectedRange, now: Date())
    }

    private var recentRecords: [WorkoutSessionRecord] {
        Array(records.prefix(12))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                Text("アクティビティ")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(.black)
                    .padding(.top, 86)

                StepActivityRangePicker(selectedRange: $selectedRange)

                VStack(alignment: .leading, spacing: 8) {
                    Text(summary.periodTitle)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black)

                    Text(summary.distanceText)
                        .font(.system(size: 78, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .minimumScaleFactor(0.68)
                        .lineLimit(1)

                    Text("KM")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 18) {
                    StepActivityMetricColumn(title: "ラン", value: summary.runCountText)
                    StepActivityMetricColumn(title: "平均ペース", value: summary.paceText)
                    StepActivityMetricColumn(title: "時間", value: summary.durationText)
                }

                StepActivityChartCard(summary: summary)

                VStack(alignment: .leading, spacing: 18) {
                    Text("最近のアクティビティ")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)

                    if recentRecords.isEmpty {
                        StepActivityEmptyStateCard(onTapRun: onTapRun)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(recentRecords, id: \.id) { record in
                                StepRecentActivityCard(record: record)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, bottomInset)
        }
    }
}

private struct StepActivityRangePicker: View {
    @Binding var selectedRange: StepActivityRange

    var body: some View {
        HStack(spacing: 0) {
            ForEach(StepActivityRange.allCases) { range in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedRange = range
                    }
                } label: {
                    Text(range.title)
                        .font(.system(size: 17, weight: selectedRange == range ? .bold : .medium))
                        .foregroundStyle(selectedRange == range ? .black : .secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            Capsule()
                                .fill(selectedRange == range ? Color(red: 0.96, green: 0.84, blue: 0.12) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.92))
        )
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct StepActivityMetricColumn: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StepActivityChartCard: View {
    let summary: StepActivitySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Chart {
                ForEach(summary.chartEntries) { entry in
                    BarMark(
                        x: .value("期間", entry.axisValue),
                        y: .value("距離", entry.distanceKilometers)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .foregroundStyle(Color(red: 0.96, green: 0.84, blue: 0.12))
                }

                if let referenceValue = summary.referenceLineValue {
                    RuleMark(y: .value("平均", referenceValue))
                        .foregroundStyle(Color.gray.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .trailing, alignment: .center) {
                            Text(summary.referenceLineText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .chartYScale(domain: 0 ... summary.chartUpperBound)
            .chartXAxis {
                AxisMarks(values: summary.axisMarkValues) { value in
                    AxisValueLabel(centered: true) {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(Color.black.opacity(0.08))
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(summary.yAxisText(for: doubleValue))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(height: 228)

            if summary.hasNoActivityInRange {
                Text("この期間の記録はまだありません")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 6)
    }
}

private struct StepActivityEmptyStateCard: View {
    let onTapRun: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.secondary)

            Text("まだアクティビティがありません")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.black)

            Text("最初のランを始めると、ここに記録が表示されます。")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onTapRun) {
                Text("ラン画面へ")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(red: 0.96, green: 0.84, blue: 0.12))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
    }
}

private struct StepRecentActivityCard: View {
    let record: WorkoutSessionRecord

    private var distanceText: String {
        String(format: "%.2f", record.distanceKilometers)
    }

    private var paceText: String {
        StepActivityFormatter.paceText(elapsedSeconds: record.elapsedSeconds, distanceKilometers: record.distanceKilometers)
    }

    private var durationText: String {
        StepActivityFormatter.durationText(seconds: record.elapsedSeconds)
    }

    private var headlineText: String {
        StepActivityFormatter.relativeDateText(for: record.startedAt)
    }

    private var subtitleText: String {
        "\(StepActivityFormatter.weekdayText(for: record.startedAt)) ラン"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Group {
                    if record.routePoints.isEmpty {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.black.opacity(0.04))
                            .overlay {
                                Image(systemName: "map")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                    } else {
                        WorkoutRouteMapView(points: record.routePoints)
                    }
                }
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(headlineText)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)

                    Text(subtitleText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .top, spacing: 18) {
                StepRecentMetricColumn(value: distanceText, unit: "km")
                StepRecentMetricColumn(value: paceText, unit: "平均ペース")
                StepRecentMetricColumn(value: durationText, unit: "時間")
            }

            if let memo = record.memo, !memo.isEmpty {
                Text(memo)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white.opacity(0.88))
        )
    }
}

private struct StepRecentMetricColumn: View {
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            Text(unit)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum StepActivityRange: String, CaseIterable, Identifiable {
    case week
    case month
    case year
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week:
            return "週"
        case .month:
            return "月"
        case .year:
            return "年"
        case .all:
            return "すべて"
        }
    }
}

private struct StepActivitySummary {
    let range: StepActivityRange
    let periodTitle: String
    let totalDistanceKilometers: Double
    let totalElapsedSeconds: Int
    let runCount: Int
    let chartEntries: [StepActivityChartEntry]
    let referenceLineValue: Double?
    let chartUpperBound: Double

    private let activeRecords: [WorkoutSessionRecord]

    init(records: [WorkoutSessionRecord], range: StepActivityRange, now: Date) {
        let calendar = Calendar.memoActivity
        let filteredRecords = StepActivitySummary.records(in: range, from: records, calendar: calendar, now: now)
        self.range = range
        self.activeRecords = filteredRecords
        self.periodTitle = StepActivitySummary.periodTitle(for: range, allRecords: records, calendar: calendar, now: now)
        self.totalDistanceKilometers = filteredRecords.reduce(0) { $0 + $1.distanceKilometers }
        self.totalElapsedSeconds = filteredRecords.reduce(0) { $0 + max(0, $1.elapsedSeconds) }
        self.runCount = filteredRecords.count
        self.chartEntries = StepActivitySummary.chartEntries(for: range, records: filteredRecords, allRecords: records, calendar: calendar, now: now)

        let nonZeroEntries = chartEntries.filter { $0.distanceKilometers > 0 }
        if nonZeroEntries.isEmpty {
            self.referenceLineValue = nil
        } else {
            self.referenceLineValue = nonZeroEntries.reduce(0) { $0 + $1.distanceKilometers } / Double(nonZeroEntries.count)
        }

        self.chartUpperBound = StepActivitySummary.chartUpperBound(for: chartEntries, referenceLineValue: referenceLineValue)
    }

    var distanceText: String {
        String(format: "%.1f", totalDistanceKilometers)
    }

    var runCountText: String {
        String(runCount)
    }

    var paceText: String {
        StepActivityFormatter.paceText(elapsedSeconds: totalElapsedSeconds, distanceKilometers: totalDistanceKilometers)
    }

    var durationText: String {
        StepActivityFormatter.durationText(seconds: totalElapsedSeconds)
    }

    var axisMarkValues: [String] {
        chartEntries.filter(\.showsAxisLabel).map(\.axisValue)
    }

    var hasNoActivityInRange: Bool {
        activeRecords.isEmpty
    }

    var referenceLineText: String {
        guard let referenceLineValue else { return "" }
        return String(format: "%.1f", referenceLineValue)
    }

    func yAxisText(for value: Double) -> String {
        if value == 0 {
            return "0km"
        }

        if value < 10 {
            return String(format: "%.0f", value)
        }

        return String(format: "%.0f", value)
    }

    private static func records(
        in range: StepActivityRange,
        from records: [WorkoutSessionRecord],
        calendar: Calendar,
        now: Date
    ) -> [WorkoutSessionRecord] {
        switch range {
        case .week:
            let start = calendar.startOfWeek(for: now)
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? now
            return records.filter { $0.startedAt >= start && $0.startedAt < end }
        case .month:
            guard let interval = calendar.dateInterval(of: .month, for: now) else { return [] }
            return records.filter { interval.contains($0.startedAt) }
        case .year:
            guard let interval = calendar.dateInterval(of: .year, for: now) else { return [] }
            return records.filter { interval.contains($0.startedAt) }
        case .all:
            return records
        }
    }

    private static func chartEntries(
        for range: StepActivityRange,
        records: [WorkoutSessionRecord],
        allRecords: [WorkoutSessionRecord],
        calendar: Calendar,
        now: Date
    ) -> [StepActivityChartEntry] {
        switch range {
        case .week:
            let start = calendar.startOfWeek(for: now)
            let weekdaySymbols = ["月", "火", "水", "木", "金", "土", "日"]

            return (0..<7).compactMap { offset in
                guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
                let distance = records
                    .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
                    .reduce(0) { $0 + $1.distanceKilometers }

                return StepActivityChartEntry(
                    axisValue: weekdaySymbols[offset],
                    distanceKilometers: distance,
                    showsAxisLabel: true
                )
            }

        case .month:
            guard let monthInterval = calendar.dateInterval(of: .month, for: now),
                  let dayRange = calendar.range(of: .day, in: .month, for: now) else {
                return []
            }

            let highlightedDays = Set(Self.monthAxisDays(lastDay: dayRange.count))

            return dayRange.compactMap { day in
                guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start) else { return nil }
                let distance = records
                    .filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
                    .reduce(0) { $0 + $1.distanceKilometers }

                return StepActivityChartEntry(
                    axisValue: "\(day)",
                    distanceKilometers: distance,
                    showsAxisLabel: highlightedDays.contains(day)
                )
            }

        case .year:
            let currentYear = calendar.component(.year, from: now)

            return (1...12).map { month in
                let distance = records
                    .filter {
                        calendar.component(.year, from: $0.startedAt) == currentYear &&
                        calendar.component(.month, from: $0.startedAt) == month
                    }
                    .reduce(0) { $0 + $1.distanceKilometers }

                return StepActivityChartEntry(
                    axisValue: "\(month)",
                    distanceKilometers: distance,
                    showsAxisLabel: true
                )
            }

        case .all:
            let currentYear = calendar.component(.year, from: now)
            let firstYear = allRecords
                .map { calendar.component(.year, from: $0.startedAt) }
                .min() ?? currentYear

            return (firstYear...max(firstYear, currentYear)).map { year in
                let distance = records
                    .filter { calendar.component(.year, from: $0.startedAt) == year }
                    .reduce(0) { $0 + $1.distanceKilometers }

                return StepActivityChartEntry(
                    axisValue: "\(year)",
                    distanceKilometers: distance,
                    showsAxisLabel: true
                )
            }
        }
    }

    private static func monthAxisDays(lastDay: Int) -> [Int] {
        let candidates = [1, 5, 12, 19, 26, lastDay]
        var result: [Int] = []

        for candidate in candidates where candidate >= 1 && candidate <= lastDay {
            if !result.contains(candidate) {
                result.append(candidate)
            }
        }

        return result
    }

    private static func periodTitle(
        for range: StepActivityRange,
        allRecords: [WorkoutSessionRecord],
        calendar: Calendar,
        now: Date
    ) -> String {
        switch range {
        case .week:
            return "今週"
        case .month:
            return StepActivityFormatter.monthText(for: now)
        case .year:
            return StepActivityFormatter.yearText(for: now)
        case .all:
            let currentYear = calendar.component(.year, from: now)
            let firstYear = allRecords
                .map { calendar.component(.year, from: $0.startedAt) }
                .min() ?? currentYear

            if firstYear == currentYear {
                return "\(currentYear)年"
            }
            return "\(firstYear)年〜\(currentYear)年"
        }
    }

    private static func chartUpperBound(
        for entries: [StepActivityChartEntry],
        referenceLineValue: Double?
    ) -> Double {
        let maxValue = max(entries.map(\.distanceKilometers).max() ?? 0, referenceLineValue ?? 0)
        guard maxValue > 0 else { return 2 }

        let step: Double
        switch maxValue {
        case ...4:
            step = 1
        case ...10:
            step = 2
        case ...20:
            step = 4
        case ...40:
            step = 8
        default:
            step = 10
        }

        return ceil(maxValue / step) * step
    }
}

private struct StepActivityChartEntry: Identifiable {
    let id = UUID()
    let axisValue: String
    let distanceKilometers: Double
    let showsAxisLabel: Bool
}

private enum StepActivityFormatter {
    private static let calendar = Calendar.memoActivity

    static func durationText(seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        let hours = safeSeconds / 3600
        let minutes = (safeSeconds % 3600) / 60
        let secs = safeSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    static func paceText(elapsedSeconds: Int, distanceKilometers: Double) -> String {
        guard distanceKilometers > 0 else { return "--'--''" }
        let secondsPerKilometer = max(0, Int((Double(elapsedSeconds) / distanceKilometers).rounded()))
        let minutes = secondsPerKilometer / 60
        let seconds = secondsPerKilometer % 60
        return String(format: "%d'%02d''", minutes, seconds)
    }

    static func relativeDateText(for date: Date) -> String {
        if calendar.isDateInToday(date) {
            return "今日"
        }

        if calendar.isDateInYesterday(date) {
            return "昨日"
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    static func weekdayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    static func monthText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    static func yearText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年"
        return formatter.string(from: date)
    }
}

private struct StepScreenSwitchButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(isSelected ? Color.black : Color.primary.opacity(0.82))
                    .frame(width: 60, height: 60)
                    .background(Color.white.opacity(isSelected ? 1.0 : 0.92), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(isSelected ? 0.12 : 0.05), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(isSelected ? 0.14 : 0.06), radius: 8, x: 0, y: 5)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary.opacity(isSelected ? 0.96 : 0.72))
                    .lineLimit(1)
            }
            .frame(minWidth: 100)
        }
        .buttonStyle(.plain)
    }
}

private struct StepMetricTile: View {
    let title: String
    let value: String
    let valueFontSize: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))

            Text(value)
                .font(.system(size: valueFontSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.75)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct StepFocusedMapBackground: View {
    let points: [WorkoutRoutePoint]
    let followsUserLocation: Bool
    let isCondensed: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let width = size.width * 1.18
            let height = size.height * (isCondensed ? 0.64 : 0.80)
            let topOffset = isCondensed ? -12.0 : -42.0
            let cornerRadius = isCondensed ? 46.0 : 54.0

            StepBackdropMapView(
                points: points,
                followsUserLocation: followsUserLocation
            )
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .mask {
                StepFocusedMapMask()
                    .frame(width: width, height: height)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    .blur(radius: 6)
                    .opacity(0.55)
            }
            .overlay {
                StepFocusedMapVignette()
                    .frame(width: width, height: height)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .offset(y: topOffset)
        }
        .allowsHitTesting(false)
    }
}

private struct StepFocusedMapMask: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.22),
                    Color.white.opacity(0.36),
                    Color.white.opacity(0.22),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color.white,
                    Color.white,
                    Color.white.opacity(0.96),
                    Color.white.opacity(0.72),
                    Color.white.opacity(0.28),
                    Color.clear
                ],
                center: .center,
                startRadius: 4,
                endRadius: 420
            )
            .scaleEffect(x: 1.12, y: 0.80)
        }
        .compositingGroup()
    }
}

private struct StepFocusedMapVignette: View {
    var body: some View {
        RadialGradient(
            colors: [
                Color.clear,
                Color.clear,
                Color.white.opacity(0.07),
                Color.white.opacity(0.20)
            ],
            center: .center,
            startRadius: 10,
            endRadius: 420
        )
        .blendMode(.screen)
    }
}

private struct StepBackdropMapView: UIViewRepresentable {
    let points: [WorkoutRoutePoint]
    let followsUserLocation: Bool

    private let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.681236, longitude: 139.767125),
        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
    )

    func makeCoordinator() -> Coordinator {
        Coordinator(defaultRegion: defaultRegion)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsTraffic = false
        mapView.pointOfInterestFilter = .includingAll
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.showsUserLocation = true
        mapView.setRegion(defaultRegion, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.followsUserLocation = followsUserLocation

        let removableAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(removableAnnotations)
        mapView.removeOverlays(mapView.overlays)

        if followsUserLocation {
            if mapView.userTrackingMode != .follow {
                mapView.setUserTrackingMode(.follow, animated: false)
            }
        } else if mapView.userTrackingMode != .none {
            mapView.setUserTrackingMode(.none, animated: false)
        }

        guard !points.isEmpty else {
            if !followsUserLocation {
                mapView.setRegion(defaultRegion, animated: false)
            }
            return
        }

        let coordinates = points.map(\.coordinate)

        if coordinates.count == 1, let coordinate = coordinates.first {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            mapView.addAnnotation(annotation)

            if !followsUserLocation {
                mapView.setCenter(coordinate, animated: false)
            }
            return
        }

        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)

        if let startCoordinate = coordinates.first {
            let start = MKPointAnnotation()
            start.coordinate = startCoordinate
            start.title = "START"
            mapView.addAnnotation(start)
        }

        if let endCoordinate = coordinates.last {
            let end = MKPointAnnotation()
            end.coordinate = endCoordinate
            end.title = "GOAL"
            mapView.addAnnotation(end)
        }

        guard !followsUserLocation else { return }

        let edgePadding = UIEdgeInsets(top: 120, left: 40, bottom: 220, right: 40)
        mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: edgePadding, animated: false)
    }
}

private extension StepBackdropMapView {
    final class Coordinator: NSObject, MKMapViewDelegate {
        var followsUserLocation: Bool = true
        private let defaultRegion: MKCoordinateRegion

        init(defaultRegion: MKCoordinateRegion) {
            self.defaultRegion = defaultRegion
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard followsUserLocation else { return }
            guard let location = userLocation.location else { return }

            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.0065, longitudeDelta: 0.0065)
            )
            mapView.setRegion(region, animated: false)
        }

        func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
            guard !followsUserLocation else { return }
            mapView.setRegion(defaultRegion, animated: false)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.black.withAlphaComponent(0.68)
            renderer.lineWidth = 5
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }

            let identifier = "StepBackdropMapAnnotationView"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.canShowCallout = false

            if let markerView = view as? MKMarkerAnnotationView {
                if annotation.title ?? "" == "START" {
                    markerView.markerTintColor = .systemGreen
                    markerView.glyphText = "S"
                } else {
                    markerView.markerTintColor = .systemRed
                    markerView.glyphText = "G"
                }
            }

            return view
        }
    }
}

private extension Calendar {
    static var memoActivity: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        calendar.firstWeekday = 2
        return calendar
    }

    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}
