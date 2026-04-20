//
//  WorkTimerPreparationView.swift
//  MeMo
//
//  Updated for compact no-scroll work preparation UI adjustment.
//

import SwiftUI
import UIKit
import Combine

struct WorkTimerPreparationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WorkTimerPreparationViewModel()

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let availableHeight = geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom
                let sectionSpacing = min(18, max(12, availableHeight * 0.018))
                let topPadding = geo.safeAreaInsets.top + 8
                let bottomPadding = max(geo.safeAreaInsets.bottom, 18)
                let situationCardWidth = min(geo.size.width - 40, 332)
                let contentVerticalOffset: CGFloat = -70

                ZStack {
                    Image("Home_background")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()

                    Color.black.opacity(0.22)
                        .ignoresSafeArea()

                    VStack(spacing: sectionSpacing) {
                        headerView

                        focusSummaryCard

                        situationSelectionCard(cardWidth: situationCardWidth)

                        durationSettingCard

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 20)
                    .padding(.top, topPadding)
                    .padding(.bottom, bottomPadding)
                    .offset(y: contentVerticalOffset)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.refreshFocusSummaryIfNeeded()
            }
            .fullScreenCover(item: $viewModel.activeSession) { session in
                WorkTimerRunningView(session: session) { focusedSeconds in
                    viewModel.recordFocusedTime(seconds: focusedSeconds)
                    viewModel.activeSession = nil
                }
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

            Color.clear
                .frame(width: 40, height: 40)
        }
    }

    private var focusSummaryCard: some View {
        HStack(spacing: 12) {
            focusSummaryBlock(
                title: "今日",
                value: viewModel.todayFocusedDisplayText
            )

            focusSummaryBlock(
                title: "累計",
                value: viewModel.totalFocusedDisplayText
            )
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
        VStack(spacing: 12) {
            Text("作業時間を設定")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

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
            .padding(.top, 4)

            HStack {
                Text("5分")
                Spacer()
                Text("無制限")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.70))
        }
        .padding(.horizontal, 4)
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

    let situationOptions: [WorkSituationOption] = WorkSituationOption.defaultOptions
    let durationOptions: [WorkSessionDurationOption] = WorkSessionDurationOption.defaultOptions

    private let focusTodaySecondsKey = "memo.work.focus.todaySeconds"
    private let focusTotalSecondsKey = "memo.work.focus.totalSeconds"
    private let focusTodayDayKey = "memo.work.focus.todayDayKey"

    init() {
        normalizeFocusSummaryIfNeeded()
        loadFocusSummary()
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

    func start() {
        start(with: selectedSituation)
    }

    func start(with situation: WorkSituationOption) {
        selectedSituation = situation
        activeSession = WorkTimerSession(
            situation: situation,
            durationOption: selectedDurationOption
        )
    }

    func selectDuration(at index: Int) {
        guard !durationOptions.isEmpty else { return }
        let clampedIndex = min(max(0, index), durationOptions.count - 1)
        selectedDurationOption = durationOptions[clampedIndex]
    }

    func refreshFocusSummaryIfNeeded() {
        normalizeFocusSummaryIfNeeded()
        loadFocusSummary()
    }

    func recordFocusedTime(seconds: Int) {
        let safeSeconds = max(0, seconds)
        guard safeSeconds > 0 else {
            loadFocusSummary()
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
        let hours = safeSeconds / 3600
        let minutes = (safeSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        }

        if minutes > 0 {
            return "\(minutes)分"
        }

        return "0分"
    }
}

// MARK: - Models

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

    static let defaultOptions: [WorkSituationOption] = [
        .workClay
    ]
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
        case .minutes(let minutes):
            return "minutes_\(minutes)"
        case .unlimited:
            return "unlimited"
        }
    }

    var displayTitle: String {
        switch self {
        case .minutes(let minutes):
            return "\(minutes)分"
        case .unlimited:
            return "無制限"
        }
    }

    var subtitleText: String {
        switch self {
        case .minutes(let minutes):
            return "\(minutes)分集中します"
        case .unlimited:
            return "終了するまで集中時間を計測します"
        }
    }

    var totalSeconds: Int? {
        switch self {
        case .minutes(let minutes):
            return minutes * 60
        case .unlimited:
            return nil
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
    @StateObject private var viewModel: WorkTimerRunningViewModel
    let onFinish: (Int) -> Void

    init(session: WorkTimerSession, onFinish: @escaping (Int) -> Void) {
        _viewModel = StateObject(wrappedValue: WorkTimerRunningViewModel(session: session))
        self.onFinish = onFinish
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                WorkRunningBackgroundLayer(resourceName: viewModel.backgroundResourceName)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.18),
                        Color.black.opacity(0.28),
                        Color.black.opacity(0.36)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer(minLength: 0)

                    VStack(spacing: 14) {
                        runningTextCard(text: viewModel.phaseTitle, fontSize: 22, horizontalPadding: 24)

                        runningTextCard(text: viewModel.timeText, fontSize: 54, horizontalPadding: 28, weight: .heavy)

                        runningTextCard(
                            text: viewModel.subtitleText,
                            fontSize: 16,
                            horizontalPadding: 20,
                            opacity: 0.20
                        )
                    }
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 0)

                    HStack(spacing: 16) {
                        if !viewModel.isCompleted {
                            Button {
                                viewModel.togglePause()
                            } label: {
                                Text(viewModel.isPaused ? "再開" : "一時停止")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 54)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(Color.black.opacity(0.60))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            onFinish(viewModel.finish())
                        } label: {
                            Text(viewModel.isCompleted ? "閉じる" : "終了")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.black.opacity(0.68))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, geo.safeAreaInsets.top + 24)
                .padding(.bottom, max(geo.safeAreaInsets.bottom, 28))
            }
            .ignoresSafeArea()
        }
        .interactiveDismissDisabled()
        .onAppear {
            viewModel.startIfNeeded()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private func runningTextCard(
        text: String,
        fontSize: CGFloat,
        horizontalPadding: CGFloat,
        weight: Font.Weight = .bold,
        opacity: Double = 0.26
    ) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: weight, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(opacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

// MARK: - Running ViewModel

@MainActor
private final class WorkTimerRunningViewModel: ObservableObject {
    @Published private(set) var timeText: String = "00:00:00"
    @Published private(set) var phaseTitle: String = ""
    @Published private(set) var subtitleText: String = ""
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var isCompleted: Bool = false

    private let session: WorkTimerSession
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

    deinit {
        timerTask?.cancel()
    }

    func startIfNeeded() {
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
    }

    func togglePause() {
        guard !isCompleted else { return }
        isPaused.toggle()
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
            phaseTitle = "のこり時間"
            subtitleText = session.durationOption.subtitleText
            timeText = Self.formatAsClock(remainingSeconds ?? 0)

        case .unlimited:
            phaseTitle = "経過時間"
            subtitleText = session.durationOption.subtitleText
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
                phaseTitle = "作業完了"
                subtitleText = "時間になりました。閉じると集中時間が保存されます。"
                stop()
            }
        } else {
            timeText = Self.formatAsClock(focusedSeconds)
        }
    }

    private static func formatAsClock(_ totalSeconds: Int) -> String {
        let safe = max(0, totalSeconds)
        let hours = safe / 3600
        let minutes = (safe % 3600) / 60
        let seconds = safe % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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
                        action: {
                            onSelect(single)
                        }
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
                                action: {
                                    onSelect(option)
                                }
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
        cardWidth / MemoryPhotoCardMetrics.aspectRatio
    }

    var body: some View {
        Button(action: action) {
            Image(situation.cardAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MemoryPhotoCardMetrics.cornerRadius,
                        style: .continuous
                    )
                )
                .shadow(
                    color: .black.opacity(isSelected ? 0.28 : 0.18),
                    radius: MemoryPhotoCardMetrics.shadowRadius,
                    x: 0,
                    y: MemoryPhotoCardMetrics.shadowYOffset
                )
                .scaleEffect(isSelected ? 1.0 : 0.985)
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: MemoryPhotoCardMetrics.cornerRadius,
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

    private let thumbSize: CGFloat = 34

    var body: some View {
        GeometryReader { geo in
            let usableWidth = max(geo.size.width - thumbSize, 1)
            let maxIndex = max(options.count - 1, 1)
            let stepWidth = usableWidth / CGFloat(maxIndex)
            let clampedIndex = min(max(0, selectedIndex), options.count - 1)
            let thumbOffset = CGFloat(clampedIndex) * stepWidth

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 12)

                Capsule()
                    .fill(Color.white.opacity(0.34))
                    .frame(width: thumbOffset + (thumbSize * 0.5), height: 12)

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                    .offset(x: thumbOffset)
            }
            .frame(height: thumbSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateSelection(
                            for: value.location.x,
                            usableWidth: usableWidth,
                            maxIndex: maxIndex
                        )
                    }
                    .onEnded { value in
                        updateSelection(
                            for: value.location.x,
                            usableWidth: usableWidth,
                            maxIndex: maxIndex
                        )
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        updateSelection(
                            for: value.location.x,
                            usableWidth: usableWidth,
                            maxIndex: maxIndex
                        )
                    }
            )
        }
        .frame(height: 44)
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
    @StateObject private var controller = LoopingVideoPlayerController()

    var body: some View {
        Group {
            if hasVideoAsset {
                LoopingVideoPlayer(controller: controller)
                    .ignoresSafeArea()
                    .onAppear {
                        controller.prepare(assetName: resourceName)
                        controller.play()
                    }
                    .onDisappear {
                        controller.pause()
                    }
            } else {
                Image("Home_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
        }
    }

    private var hasVideoAsset: Bool {
        ["mp4", "mov", "m4v"].contains {
            Bundle.main.url(forResource: resourceName, withExtension: $0) != nil
        }
    }
}
