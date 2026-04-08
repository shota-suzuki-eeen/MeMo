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
    @Environment(\.colorScheme) private var colorScheme
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
                if colorScheme == .dark {
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.11, blue: 0.14),
                            Color(red: 0.08, green: 0.09, blue: 0.11),
                            Color(red: 0.06, green: 0.07, blue: 0.09)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    Color(red: 0.96, green: 0.96, blue: 0.97)
                }
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
    @Environment(\.colorScheme) private var colorScheme

    let records: [WorkoutSessionRecord]
    let bottomInset: CGFloat
    let onTapRun: () -> Void

    @State private var selectedRange: StepActivityRange = .week
    @State private var selectedWeekOptionID: String?
    @State private var selectedMonthOptionID: String?
    @State private var selectedYearOptionID: String?
    @State private var isPickerPresented = false
    @State private var pickerSelectionID = ""

    private var summary: StepActivitySummary {
        StepActivitySummary(records: records, selection: currentSelection)
    }

    private var recentRecords: [WorkoutSessionRecord] {
        Array(records.prefix(12))
    }

    private var currentSelection: StepActivitySelection {
        switch selectedRange {
        case .week:
            return .week(selectedWeekOption)
        case .month:
            return .month(selectedMonthOption)
        case .year:
            return .year(selectedYearOption)
        case .all:
            return .all(title: allPeriodTitle)
        }
    }

    private var weekOptions: [StepActivityPickerOption] {
        StepActivityPickerOption.weekOptions(now: Date())
    }

    private var monthOptions: [StepActivityPickerOption] {
        StepActivityPickerOption.monthOptions(records: records)
    }

    private var yearOptions: [StepActivityPickerOption] {
        StepActivityPickerOption.yearOptions(records: records)
    }

    private var selectedWeekOption: StepActivityPickerOption {
        resolvedOption(in: weekOptions, preferredID: selectedWeekOptionID) ?? weekOptions[0]
    }

    private var selectedMonthOption: StepActivityPickerOption {
        resolvedOption(in: monthOptions, preferredID: selectedMonthOptionID) ?? StepActivityPickerOption.currentMonthFallback(now: Date())
    }

    private var selectedYearOption: StepActivityPickerOption {
        resolvedOption(in: yearOptions, preferredID: selectedYearOptionID) ?? StepActivityPickerOption.currentYearFallback(now: Date())
    }

    private var activePickerOptions: [StepActivityPickerOption] {
        switch selectedRange {
        case .week:
            return weekOptions
        case .month:
            return monthOptions
        case .year:
            return yearOptions
        case .all:
            return []
        }
    }

    private var canPresentPicker: Bool {
        switch selectedRange {
        case .week:
            return !activePickerOptions.isEmpty
        case .month, .year:
            return activePickerOptions.count > 1
        case .all:
            return false
        }
    }

    private var shouldShowPeriodSelector: Bool {
        selectedRange != .all
    }

    private var selectorLabel: String {
        switch selectedRange {
        case .week:
            return selectedWeekOption.title
        case .month:
            return selectedMonthOption.title
        case .year:
            return selectedYearOption.title
        case .all:
            return allPeriodTitle
        }
    }

    private var allPeriodTitle: String {
        StepActivitySummary.allPeriodTitle(records: records, now: Date())
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.68) : .secondary
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.90)
    }

    private var pickerBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.12, green: 0.13, blue: 0.16) : Color.white
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    Text("アクティビティ")
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundStyle(primaryTextColor)
                        .padding(.top, 86)

                    VStack(alignment: .leading, spacing: 14) {
                        StepActivityRangePicker(selectedRange: $selectedRange)

                        if shouldShowPeriodSelector {
                            StepActivityPeriodSelectorButton(
                                title: selectorLabel,
                                isEnabled: canPresentPicker,
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor
                            ) {
                                presentPicker()
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(summary.periodTitle)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(primaryTextColor)

                        Text(summary.distanceText)
                            .font(.system(size: 78, weight: .black, design: .rounded))
                            .foregroundStyle(primaryTextColor)
                            .minimumScaleFactor(0.68)
                            .lineLimit(1)

                        Text("KM")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(secondaryTextColor)
                    }

                    HStack(alignment: .top, spacing: 18) {
                        StepActivityMetricColumn(
                            title: "ラン",
                            value: summary.runCountText,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor
                        )
                        StepActivityMetricColumn(
                            title: "平均ペース",
                            value: summary.paceText,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor
                        )
                        StepActivityMetricColumn(
                            title: "時間",
                            value: summary.durationText,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor
                        )
                    }

                    StepActivityChartCard(
                        summary: summary,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor
                    )

                    VStack(alignment: .leading, spacing: 18) {
                        Text("最近のアクティビティ")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(primaryTextColor)

                        if recentRecords.isEmpty {
                            StepActivityEmptyStateCard(
                                onTapRun: onTapRun,
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor,
                                backgroundColor: cardBackgroundColor
                            )
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(recentRecords, id: \.id) { record in
                                    StepRecentActivityCard(
                                        record: record,
                                        primaryTextColor: primaryTextColor,
                                        secondaryTextColor: secondaryTextColor,
                                        backgroundColor: cardBackgroundColor
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, bottomInset)
            }
            .scrollDisabled(isPickerPresented)

            if isPickerPresented {
                Color.black.opacity(colorScheme == .dark ? 0.55 : 0.28)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        dismissPicker()
                    }

                StepActivityWheelPickerSheet(
                    options: activePickerOptions,
                    selectionID: $pickerSelectionID,
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor,
                    backgroundColor: pickerBackgroundColor,
                    onConfirm: applyPickerSelection
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isPickerPresented)
    }

    private func resolvedOption(
        in options: [StepActivityPickerOption],
        preferredID: String?
    ) -> StepActivityPickerOption? {
        if let preferredID,
           let matched = options.first(where: { $0.id == preferredID }) {
            return matched
        }

        return options.first
    }

    private func presentPicker() {
        guard canPresentPicker, let currentOption = currentPickerOption else { return }
        pickerSelectionID = currentOption.id
        isPickerPresented = true
    }

    private var currentPickerOption: StepActivityPickerOption? {
        switch selectedRange {
        case .week:
            return selectedWeekOption
        case .month:
            return resolvedOption(in: monthOptions, preferredID: selectedMonthOptionID)
        case .year:
            return resolvedOption(in: yearOptions, preferredID: selectedYearOptionID)
        case .all:
            return nil
        }
    }

    private func applyPickerSelection() {
        switch selectedRange {
        case .week:
            selectedWeekOptionID = pickerSelectionID
        case .month:
            selectedMonthOptionID = pickerSelectionID
        case .year:
            selectedYearOptionID = pickerSelectionID
        case .all:
            break
        }

        dismissPicker()
    }

    private func dismissPicker() {
        isPickerPresented = false
    }
}

private struct StepActivityRangePicker: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedRange: StepActivityRange

    private var selectedTextColor: Color {
        .black
    }

    private var unselectedTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.56) : .secondary
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.92)
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }

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
                        .foregroundStyle(selectedRange == range ? selectedTextColor : unselectedTextColor)
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
                .fill(backgroundColor)
        )
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

private struct StepActivityPeriodSelectorButton: View {
    let title: String
    let isEnabled: Bool
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isEnabled ? primaryTextColor : secondaryTextColor)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isEnabled ? primaryTextColor : secondaryTextColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text("期間を変更"))
    }
}

private struct StepActivityWheelPickerSheet: View {
    let options: [StepActivityPickerOption]
    @Binding var selectionID: String
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let backgroundColor: Color
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(secondaryTextColor.opacity(0.35))
                .frame(width: 44, height: 5)
                .padding(.top, 8)

            Picker("期間", selection: $selectionID) {
                ForEach(options) { option in
                    Text(option.title)
                        .tag(option.id)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 180)

            Button(action: onConfirm) {
                Text("選択")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(secondaryTextColor.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
    }
}

private struct StepActivityMetricColumn: View {
    let title: String
    let value: String
    let primaryTextColor: Color
    let secondaryTextColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(secondaryTextColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StepActivityChartCard: View {
    let summary: StepActivitySummary
    let primaryTextColor: Color
    let secondaryTextColor: Color

    var axisGridColor: Color {
        primaryTextColor.opacity(0.10)
    }

    var referenceLineColor: Color {
        primaryTextColor.opacity(0.28)
    }

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
                        .foregroundStyle(referenceLineColor)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .annotation(position: .trailing, alignment: .center) {
                            Text(summary.referenceLineText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(secondaryTextColor)
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
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1))
                        .foregroundStyle(axisGridColor)
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(summary.yAxisText(for: doubleValue))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                }
            }
            .frame(height: 228)

            if summary.hasNoActivityInRange {
                Text("この期間の記録はまだありません")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
            }
        }
        .padding(.top, 6)
    }
}

private struct StepActivityEmptyStateCard: View {
    let onTapRun: () -> Void
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let backgroundColor: Color

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(secondaryTextColor)

            Text("まだアクティビティがありません")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(primaryTextColor)

            Text("最初のランを始めると、ここに記録が表示されます。")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(secondaryTextColor)
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
                .fill(backgroundColor)
        )
    }
}

private struct StepRecentActivityCard: View {
    let record: WorkoutSessionRecord
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let backgroundColor: Color

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
                            .fill(primaryTextColor.opacity(0.06))
                            .overlay {
                                Image(systemName: "map")
                                    .font(.system(size: 26, weight: .medium))
                                    .foregroundStyle(secondaryTextColor)
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
                        .foregroundStyle(primaryTextColor)

                    Text(subtitleText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .top, spacing: 18) {
                StepRecentMetricColumn(
                    value: distanceText,
                    unit: "km",
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor
                )
                StepRecentMetricColumn(
                    value: paceText,
                    unit: "平均ペース",
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor
                )
                StepRecentMetricColumn(
                    value: durationText,
                    unit: "時間",
                    primaryTextColor: primaryTextColor,
                    secondaryTextColor: secondaryTextColor
                )
            }

            if let memo = record.memo, !memo.isEmpty {
                Text(memo)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(secondaryTextColor)
                    .lineLimit(2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(backgroundColor)
        )
    }
}

private struct StepRecentMetricColumn: View {
    let value: String
    let unit: String
    let primaryTextColor: Color
    let secondaryTextColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            Text(unit)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(secondaryTextColor)
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

private struct StepActivityPickerOption: Identifiable, Hashable {
    let id: String
    let title: String
    let anchorDate: Date
    let interval: DateInterval?

    init(
        id: String,
        title: String,
        anchorDate: Date,
        interval: DateInterval?
    ) {
        self.id = id
        self.title = title
        self.anchorDate = anchorDate
        self.interval = interval
    }

    static func weekOptions(now: Date) -> [StepActivityPickerOption] {
        let calendar = Calendar.memoActivity
        let currentWeekStart = calendar.startOfWeek(for: now)

        return (0...3).compactMap { offset in
            guard let start = calendar.date(byAdding: .day, value: -(offset * 7), to: currentWeekStart),
                  let end = calendar.date(byAdding: .day, value: 7, to: start) else {
                return nil
            }

            let title: String
            switch offset {
            case 0:
                title = "今週"
            case 1:
                title = "先週"
            default:
                title = StepActivityFormatter.weekRangeText(start: start, endExclusive: end)
            }

            return StepActivityPickerOption(
                id: "week-\(offset)",
                title: title,
                anchorDate: start,
                interval: DateInterval(start: start, end: end)
            )
        }
    }

    static func monthOptions(records: [WorkoutSessionRecord]) -> [StepActivityPickerOption] {
        let calendar = Calendar.memoActivity
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"

        let uniqueStarts = Set(
            records.compactMap { record in
                calendar.dateInterval(of: .month, for: record.startedAt)?.start
            }
        )

        return uniqueStarts
            .sorted(by: >)
            .compactMap { start in
                guard let interval = calendar.dateInterval(of: .month, for: start) else { return nil }
                return StepActivityPickerOption(
                    id: Self.monthIdentifier(for: start, calendar: calendar),
                    title: formatter.string(from: start),
                    anchorDate: start,
                    interval: interval
                )
            }
    }

    static func yearOptions(records: [WorkoutSessionRecord]) -> [StepActivityPickerOption] {
        let calendar = Calendar.memoActivity
        let years = Set(records.map { calendar.component(.year, from: $0.startedAt) })

        return years
            .sorted(by: >)
            .compactMap { year in
                var components = DateComponents()
                components.year = year
                components.month = 1
                components.day = 1
                guard let start = calendar.date(from: components),
                      let interval = calendar.dateInterval(of: .year, for: start) else {
                    return nil
                }

                return StepActivityPickerOption(
                    id: "year-\(year)",
                    title: "\(year)年",
                    anchorDate: start,
                    interval: interval
                )
            }
    }

    static func currentMonthFallback(now: Date) -> StepActivityPickerOption {
        let calendar = Calendar.memoActivity
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        let interval = calendar.dateInterval(of: .month, for: now)
        let anchorDate = interval?.start ?? now

        return StepActivityPickerOption(
            id: Self.monthIdentifier(for: anchorDate, calendar: calendar),
            title: formatter.string(from: anchorDate),
            anchorDate: anchorDate,
            interval: interval
        )
    }

    static func currentYearFallback(now: Date) -> StepActivityPickerOption {
        let calendar = Calendar.memoActivity
        let year = calendar.component(.year, from: now)
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        let anchorDate = calendar.date(from: components) ?? now
        let interval = calendar.dateInterval(of: .year, for: anchorDate)

        return StepActivityPickerOption(
            id: "year-\(year)",
            title: "\(year)年",
            anchorDate: anchorDate,
            interval: interval
        )
    }

    private static func monthIdentifier(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        return String(format: "month-%04d-%02d", year, month)
    }
}

private enum StepActivitySelection {
    case week(StepActivityPickerOption)
    case month(StepActivityPickerOption)
    case year(StepActivityPickerOption)
    case all(title: String)

    var range: StepActivityRange {
        switch self {
        case .week:
            return .week
        case .month:
            return .month
        case .year:
            return .year
        case .all:
            return .all
        }
    }

    var title: String {
        switch self {
        case .week(let option), .month(let option), .year(let option):
            return option.title
        case .all(let title):
            return title
        }
    }

    var anchorDate: Date {
        switch self {
        case .week(let option), .month(let option), .year(let option):
            return option.anchorDate
        case .all:
            return Date()
        }
    }

    var interval: DateInterval? {
        switch self {
        case .week(let option), .month(let option), .year(let option):
            return option.interval
        case .all:
            return nil
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

    init(records: [WorkoutSessionRecord], selection: StepActivitySelection) {
        let calendar = Calendar.memoActivity
        let filteredRecords = StepActivitySummary.records(for: selection, from: records)
        self.range = selection.range
        self.activeRecords = filteredRecords
        self.periodTitle = selection.title
        self.totalDistanceKilometers = filteredRecords.reduce(0) { $0 + $1.distanceKilometers }
        self.totalElapsedSeconds = filteredRecords.reduce(0) { $0 + max(0, $1.elapsedSeconds) }
        self.runCount = filteredRecords.count
        self.chartEntries = StepActivitySummary.chartEntries(
            for: selection,
            records: filteredRecords,
            allRecords: records,
            calendar: calendar
        )

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

        return String(format: "%.0f", value)
    }

    static func allPeriodTitle(records: [WorkoutSessionRecord], now: Date) -> String {
        let calendar = Calendar.memoActivity
        let currentYear = calendar.component(.year, from: now)
        let firstYear = records
            .map { calendar.component(.year, from: $0.startedAt) }
            .min() ?? currentYear

        if firstYear == currentYear {
            return "\(currentYear)年"
        }

        return "\(firstYear)年〜\(currentYear)年"
    }

    private static func records(
        for selection: StepActivitySelection,
        from records: [WorkoutSessionRecord]
    ) -> [WorkoutSessionRecord] {
        guard let interval = selection.interval else {
            return records
        }

        return records.filter { interval.contains($0.startedAt) }
    }

    private static func chartEntries(
        for selection: StepActivitySelection,
        records: [WorkoutSessionRecord],
        allRecords: [WorkoutSessionRecord],
        calendar: Calendar
    ) -> [StepActivityChartEntry] {
        switch selection {
        case .week(let option):
            guard let interval = option.interval else { return [] }

            let weekdaySymbols = ["月", "火", "水", "木", "金", "土", "日"]

            return (0..<7).compactMap { offset in
                guard let day = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
                let distance = records
                    .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
                    .reduce(0) { $0 + $1.distanceKilometers }

                return StepActivityChartEntry(
                    axisValue: weekdaySymbols[offset],
                    distanceKilometers: distance,
                    showsAxisLabel: true
                )
            }

        case .month(let option):
            guard let monthInterval = option.interval,
                  let dayRange = calendar.range(of: .day, in: .month, for: option.anchorDate) else {
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

        case .year(let option):
            let selectedYear = calendar.component(.year, from: option.anchorDate)

            return (1...12).map { month in
                let distance = records
                    .filter {
                        calendar.component(.year, from: $0.startedAt) == selectedYear &&
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
            let currentYear = calendar.component(.year, from: Date())
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

    static func weekRangeText(start: Date, endExclusive: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"

        let endDate = calendar.date(byAdding: .day, value: -1, to: endExclusive) ?? endExclusive
        return "\(formatter.string(from: start))〜\(formatter.string(from: endDate))"
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
