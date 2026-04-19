//
//  WorkTimerPreparationView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/31.
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
                ZStack {
                    Image("Home_background")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()

                    Color.black.opacity(0.22)
                        .ignoresSafeArea()

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 20) {
                            headerView

                            focusSummaryCard

                            durationSettingCard

                            Button {
                                viewModel.start()
                            } label: {
                                Image("work_clay")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 220, height: 88)
                                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(
                            minHeight: geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom,
                            alignment: .center
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, geo.safeAreaInsets.top + 8)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 24))
                    }
                    .scrollBounceBehavior(.basedOnSize)
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
        VStack(spacing: 14) {
            Text("集中時間")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            HStack(spacing: 14) {
                focusSummaryBlock(
                    title: "今日",
                    value: viewModel.todayFocusedDisplayText,
                    caption: "日付が変わるとリセット"
                )

                focusSummaryBlock(
                    title: "累計",
                    value: viewModel.totalFocusedDisplayText,
                    caption: "これまでの合計"
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func focusSummaryBlock(title: String, value: String, caption: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))

            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            Text(caption)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var durationSettingCard: some View {
        VStack(spacing: 18) {
            Text("作業時間を設定")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text("5分単位で設定できます。180分の次は「無制限」です。")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
                .multilineTextAlignment(.center)

            Text(viewModel.selectedDurationDisplayTitle)
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()

            DurationSelectionCarousel(
                options: viewModel.durationOptions,
                selectedOption: $viewModel.selectedDurationOption,
                onMoveSelection: { delta in
                    viewModel.moveSelection(by: delta)
                }
            )

            Text("デフォルトは25分")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - ViewModel

@MainActor
final class WorkTimerPreparationViewModel: ObservableObject {
    @Published var selectedDurationOption: WorkSessionDurationOption = .minutes(25)
    @Published var activeSession: WorkTimerSession?
    @Published private(set) var todayFocusedSeconds: Int = 0
    @Published private(set) var totalFocusedSeconds: Int = 0

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

    var todayFocusedDisplayText: String {
        Self.formatSummary(seconds: todayFocusedSeconds)
    }

    var totalFocusedDisplayText: String {
        Self.formatSummary(seconds: totalFocusedSeconds)
    }

    func start() {
        activeSession = WorkTimerSession(durationOption: selectedDurationOption)
    }

    func moveSelection(by delta: Int) {
        guard delta != 0 else { return }
        guard let currentIndex = durationOptions.firstIndex(of: selectedDurationOption) else { return }

        let nextIndex = min(max(0, currentIndex + delta), durationOptions.count - 1)
        guard nextIndex != currentIndex else { return }

        selectedDurationOption = durationOptions[nextIndex]
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
    let durationOption: WorkSessionDurationOption

    var id: String {
        durationOption.id
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
                WorkRunningBackgroundLayer(resourceName: "work")

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

// MARK: - Duration Picker

private struct DurationSelectionCarousel: View {
    let options: [WorkSessionDurationOption]
    @Binding var selectedOption: WorkSessionDurationOption
    let onMoveSelection: (Int) -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Button {
                    onMoveSelection(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.28), in: Circle())
                }
                .buttonStyle(.plain)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(options) { option in
                                DurationOptionChip(
                                    title: option.displayTitle,
                                    isSelected: option == selectedOption
                                )
                                .id(option.id)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                                        selectedOption = option
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 6)
                    }
                    .onAppear {
                        proxy.scrollTo(selectedOption.id, anchor: .center)
                    }
                    .onChange(of: selectedOption) { _, newValue in
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                            proxy.scrollTo(newValue.id, anchor: .center)
                        }
                    }
                }

                Button {
                    onMoveSelection(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.28), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Text("左右に切り替えて時間を選択")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
        }
    }
}

private struct DurationOptionChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.black.opacity(0.72) : Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.18 : 0.08), lineWidth: 1)
            )
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
