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
            ZStack {
                Image("Home_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.22)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    headerView

                    timerTypeSelector

                    timerSettingCard

                    Spacer()

                    Button {
                        viewModel.start()
                    } label: {
                        Text("スタート")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.black.opacity(0.82))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: $viewModel.activeSession) { session in
                WorkTimerRunningView(session: session)
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

            Text("ワークタイマー")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear
                .frame(width: 40, height: 40)
        }
    }

    private var timerTypeSelector: some View {
        VStack(spacing: 14) {
            Text("タイマーを選択")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Picker("タイマー種別", selection: $viewModel.selectedMode) {
                ForEach(WorkTimerMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var timerSettingCard: some View {
        VStack(spacing: 18) {
            Text(viewModel.selectedMode.descriptionText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            switch viewModel.selectedMode {
            case .free:
                freeTimerSettingView

            case .pomodoro:
                pomodoroSettingView

            case .countdown:
                countdownSettingView
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var freeTimerSettingView: some View {
        VStack(spacing: 12) {
            Text("フリータイマー")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            Text("開始後は無制限でカウントアップします。")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))

            VStack(spacing: 8) {
                Text("00:00:00")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                Text("停止するまで計測を続けます")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var pomodoroSettingView: some View {
        VStack(spacing: 18) {
            Text("ポモドーロタイマー")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            HStack(spacing: 20) {
                pickerColumn(
                    title: "作業時間",
                    selection: $viewModel.pomodoroWorkMinutes,
                    values: viewModel.pomodoroMinuteOptions,
                    unit: "分"
                )

                VStack(spacing: 8) {
                    Text("休憩時間")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))

                    Text("\(viewModel.pomodoroBreakMinutes)")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)

                    Text("分")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity)
            }

            VStack(spacing: 6) {
                Text("5分ごとに休憩1分を自動設定")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.86))

                Text("作業 \(viewModel.pomodoroWorkMinutes) 分 → 休憩 \(viewModel.pomodoroBreakMinutes) 分 を繰り返します")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var countdownSettingView: some View {
        VStack(spacing: 18) {
            Text("カウントダウンタイマー")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            pickerColumn(
                title: "設定時間",
                selection: $viewModel.countdownMinutes,
                values: viewModel.countdownMinuteOptions,
                unit: "分"
            )

            Text("\(viewModel.countdownMinutes)分で開始します")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
        }
    }

    private func pickerColumn(
        title: String,
        selection: Binding<Int>,
        values: [Int],
        unit: String
    ) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))

            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 140)
            .clipped()

            Text(unit)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ViewModel

@MainActor
final class WorkTimerPreparationViewModel: ObservableObject {
    @Published var selectedMode: WorkTimerMode = .free
    @Published var pomodoroWorkMinutes: Int = 25
    @Published var countdownMinutes: Int = 10
    @Published var activeSession: WorkTimerSession?

    let pomodoroMinuteOptions: [Int] = Array(stride(from: 5, through: 180, by: 5))
    let countdownMinuteOptions: [Int] = Array(1...180)

    var pomodoroBreakMinutes: Int {
        max(1, pomodoroWorkMinutes / 5)
    }

    func start() {
        let session: WorkTimerSession

        switch selectedMode {
        case .free:
            session = .free

        case .pomodoro:
            session = .pomodoro(
                workMinutes: pomodoroWorkMinutes,
                breakMinutes: pomodoroBreakMinutes
            )

        case .countdown:
            session = .countdown(minutes: countdownMinutes)
        }

        activeSession = session
    }
}

// MARK: - Models

enum WorkTimerMode: String, CaseIterable, Identifiable {
    case free
    case pomodoro
    case countdown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .free: return "フリー"
        case .pomodoro: return "ポモドーロ"
        case .countdown: return "カウントダウン"
        }
    }

    var descriptionText: String {
        switch self {
        case .free:
            return "無制限でカウントアップし続けるタイマーです。"
        case .pomodoro:
            return "作業時間は5分単位で設定でき、休憩時間は自動で設定されます。"
        case .countdown:
            return "1分単位で時間を設定できるカウントダウンタイマーです。"
        }
    }
}

enum WorkTimerSession: Identifiable, Equatable {
    case free
    case pomodoro(workMinutes: Int, breakMinutes: Int)
    case countdown(minutes: Int)

    var id: String {
        switch self {
        case .free:
            return "free"
        case .pomodoro(let workMinutes, let breakMinutes):
            return "pomodoro_\(workMinutes)_\(breakMinutes)"
        case .countdown(let minutes):
            return "countdown_\(minutes)"
        }
    }

    var title: String {
        switch self {
        case .free:
            return "フリータイマー"
        case .pomodoro:
            return "ポモドーロタイマー"
        case .countdown:
            return "カウントダウンタイマー"
        }
    }
}

private enum WorkTimerPhase: Equatable {
    case freeRunning
    case pomodoroWork
    case pomodoroBreak
    case countdown
}

// MARK: - Running View

private struct WorkTimerRunningView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: WorkTimerRunningViewModel

    init(session: WorkTimerSession) {
        _viewModel = StateObject(wrappedValue: WorkTimerRunningViewModel(session: session))
    }

    var body: some View {
        ZStack {
            Image("Home_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text(viewModel.phaseTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                Text(viewModel.timeText)
                    .font(.system(size: 54, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)

                if let subtitle = viewModel.subtitleText {
                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.84))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                HStack(spacing: 16) {
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
                                    .fill(Color.black.opacity(0.78))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                    } label: {
                        Text("終了")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.red.opacity(0.82))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
        .interactiveDismissDisabled()
        .onAppear {
            viewModel.startIfNeeded()
        }
        .onDisappear {
            viewModel.stop()
        }
    }
}

// MARK: - Running ViewModel

@MainActor
private final class WorkTimerRunningViewModel: ObservableObject {
    @Published private(set) var timeText: String = "00:00:00"
    @Published private(set) var phaseTitle: String = ""
    @Published private(set) var subtitleText: String?
    @Published private(set) var isPaused: Bool = false

    private let session: WorkTimerSession
    private var phase: WorkTimerPhase = .freeRunning
    private var task: Task<Void, Never>?

    private var elapsedSeconds: Int = 0
    private var remainingSeconds: Int = 0

    private var pomodoroWorkSeconds: Int = 0
    private var pomodoroBreakSeconds: Int = 0
    private var pomodoroCycleCount: Int = 1

    init(session: WorkTimerSession) {
        self.session = session
        configureInitialState()
    }

    deinit {
        task?.cancel()
    }

    func startIfNeeded() {
        guard task == nil else { return }

        task = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)

                if Task.isCancelled { break }
                if isPaused { continue }

                tick()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func togglePause() {
        isPaused.toggle()
    }

    private func configureInitialState() {
        switch session {
        case .free:
            phase = .freeRunning
            elapsedSeconds = 0
            phaseTitle = "フリータイマー"
            subtitleText = "作業時間を計測中"
            timeText = Self.formatAsClock(elapsedSeconds)

        case .pomodoro(let workMinutes, let breakMinutes):
            pomodoroWorkSeconds = workMinutes * 60
            pomodoroBreakSeconds = breakMinutes * 60
            remainingSeconds = pomodoroWorkSeconds
            pomodoroCycleCount = 1
            phase = .pomodoroWork
            phaseTitle = "作業時間"
            subtitleText = "1サイクル目"
            timeText = Self.formatAsClock(remainingSeconds)

        case .countdown(let minutes):
            remainingSeconds = minutes * 60
            phase = .countdown
            phaseTitle = "カウントダウン"
            subtitleText = nil
            timeText = Self.formatAsClock(remainingSeconds)
        }
    }

    private func tick() {
        switch phase {
        case .freeRunning:
            elapsedSeconds += 1
            timeText = Self.formatAsClock(elapsedSeconds)

        case .pomodoroWork:
            remainingSeconds -= 1

            if remainingSeconds <= 0 {
                phase = .pomodoroBreak
                remainingSeconds = pomodoroBreakSeconds
                phaseTitle = "休憩時間"
                subtitleText = "\(pomodoroCycleCount)サイクル目の休憩"
                timeText = Self.formatAsClock(remainingSeconds)
                return
            }

            timeText = Self.formatAsClock(remainingSeconds)
            subtitleText = "\(pomodoroCycleCount)サイクル目"

        case .pomodoroBreak:
            remainingSeconds -= 1

            if remainingSeconds <= 0 {
                pomodoroCycleCount += 1
                phase = .pomodoroWork
                remainingSeconds = pomodoroWorkSeconds
                phaseTitle = "作業時間"
                subtitleText = "\(pomodoroCycleCount)サイクル目"
                timeText = Self.formatAsClock(remainingSeconds)
                return
            }

            timeText = Self.formatAsClock(remainingSeconds)
            subtitleText = "\(pomodoroCycleCount - 1)サイクル目の休憩"

        case .countdown:
            guard remainingSeconds > 0 else {
                timeText = "00:00:00"
                return
            }

            remainingSeconds -= 1
            timeText = Self.formatAsClock(max(remainingSeconds, 0))

            if remainingSeconds <= 0 {
                subtitleText = "時間になりました"
            }
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
