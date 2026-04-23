//
//  StepViewModel.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation
import Combine
import SwiftUI
import SwiftData

@MainActor
final class StepViewModel: ObservableObject {
    enum SessionState: Equatable {
        case idle
        case waitingForPermission
        case countingDown
        case running
        case paused
        case finished
    }

    enum SaveState: Equatable {
        case idle
        case saving
        case saved(Date)
        case failed(String)
    }

    enum StartPreparationResult: Equatable {
        case startCountdown
        case waitingForPermission
        case blocked
    }

    @Published private(set) var sessionState: SessionState = .idle
    @Published private(set) var saveState: SaveState = .idle

    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var totalDistanceMeters: Double = 0
    @Published private(set) var routePoints: [WorkoutRoutePoint] = []
    @Published private(set) var locationAuthorizationState: LocationTrackingManager.AuthorizationState = .notDetermined
    @Published private(set) var latestHorizontalAccuracy: Double?

    @Published private(set) var saveMessage: String?
    @Published private(set) var finishedSession: WorkoutSessionDraft?

    private let locationTrackingManager: LocationTrackingManager
    private let routeStore: WorkoutRouteStore

    private var cancellables: Set<AnyCancellable> = []
    private var timer: Timer?
    private var didConfigure = false

    private var startedAt: Date?
    private var pausedAt: Date?
    private var accumulatedPausedTime: TimeInterval = 0

    init(
        locationTrackingManager: LocationTrackingManager,
        routeStore: WorkoutRouteStore
    ) {
        self.locationTrackingManager = locationTrackingManager
        self.routeStore = routeStore
        bindLocationManager()
    }

    convenience init() {
        self.init(
            locationTrackingManager: LocationTrackingManager(),
            routeStore: WorkoutRouteStore()
        )
    }

    deinit {
        timer?.invalidate()
        NotificationCenter.default.post(
            name: BGMManager.stepSessionDidExitWorkoutNotification,
            object: nil
        )
    }

    var isRunning: Bool {
        sessionState == .running
    }

    var isPaused: Bool {
        sessionState == .paused
    }

    var isFinished: Bool {
        sessionState == .finished
    }

    var shouldShowPermissionGuide: Bool {
        locationAuthorizationState == .denied || locationAuthorizationState == .restricted
    }

    var shouldPlayCharacterVideo: Bool {
        sessionState == .running
    }

    var formattedElapsedTime: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedDistanceKilometers: String {
        String(format: "%.2f km", max(0, totalDistanceMeters) / 1000.0)
    }

    var summaryDistanceText: String {
        formattedDistanceKilometers
    }

    var summaryElapsedText: String {
        formattedElapsedTime
    }

    var primaryActionTitle: String {
        switch sessionState {
        case .idle:
            return "スタート"
        case .waitingForPermission:
            return "位置情報を確認中"
        case .countingDown:
            return "準備中"
        case .running:
            return "計測中"
        case .paused:
            return "再開"
        case .finished:
            return "もう一度"
        }
    }

    var pauseButtonTitle: String {
        sessionState == .paused ? "再開" : "停止"
    }

    var permissionMessage: String {
        switch locationAuthorizationState {
        case .notDetermined:
            return "ステップ計測を始めるには、位置情報の許可が必要です。"
        case .restricted:
            return "この端末では位置情報が制限されています。設定をご確認ください。"
        case .denied:
            return "位置情報がオフのため、距離とルートを計測できません。設定アプリから許可してください。"
        case .authorizedWhenInUse, .authorizedAlways:
            return "位置情報の準備ができています。"
        }
    }

    var accuracyMessage: String? {
        guard let latestHorizontalAccuracy else { return nil }
        if latestHorizontalAccuracy <= 20 {
            return nil
        }
        return "測位精度が不安定です。屋外で少し待つと改善する場合があります。"
    }

    func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true
        locationTrackingManager.refreshAuthorizationState()
    }

    func handlePrimaryAction() {
        switch sessionState {
        case .paused:
            resumeWorkout()
        case .finished:
            resetForNewWorkout()
        case .idle, .waitingForPermission, .countingDown, .running:
            break
        }
    }

    func prepareWorkoutStart() -> StartPreparationResult {
        switch locationAuthorizationState {
        case .authorizedAlways, .authorizedWhenInUse:
            sessionState = .countingDown
            notifyStepWorkoutBGMShouldStop()
            return .startCountdown
        case .notDetermined:
            sessionState = .waitingForPermission
            locationTrackingManager.requestAuthorization()
            return .waitingForPermission
        case .denied, .restricted:
            sessionState = .idle
            notifyStepWorkoutBGMShouldResumeMain()
            return .blocked
        }
    }

    func beginCountdown() {
        guard locationAuthorizationState.isAuthorized else { return }
        sessionState = .countingDown
        notifyStepWorkoutBGMShouldStop()
    }

    func cancelCountdownIfNeeded() {
        guard sessionState == .countingDown else { return }
        sessionState = .idle
        notifyStepWorkoutBGMShouldResumeMain()
    }

    func beginWorkoutAfterCountdown() {
        guard locationAuthorizationState.isAuthorized else {
            sessionState = .idle
            notifyStepWorkoutBGMShouldResumeMain()
            return
        }
        notifyStepWorkoutBGMShouldStop()
        startNewWorkout()
    }

    func togglePause() {
        switch sessionState {
        case .running:
            pauseWorkout()
        case .paused:
            resumeWorkout()
        default:
            break
        }
    }

    func finishWorkout() {
        guard let startedAt else { return }

        let endedAt = Date()
        elapsedSeconds = calculateElapsedSeconds(referenceDate: endedAt)
        stopTimer()
        locationTrackingManager.pauseTracking()

        finishedSession = WorkoutSessionDraft(
            startedAt: startedAt,
            endedAt: endedAt,
            elapsedSeconds: elapsedSeconds,
            totalDistanceMeters: totalDistanceMeters,
            routePoints: routePoints
        )

        saveState = .idle
        saveMessage = nil
        sessionState = .finished
        notifyStepWorkoutBGMShouldResumeMain()
    }

    func saveFinishedWorkout(
        modelContext: ModelContext,
        characterID: String?
    ) {
        guard case .finished = sessionState,
              let finishedSession else { return }

        saveState = .saving
        saveMessage = nil

        do {
            let draft = WorkoutSessionDraft(
                id: finishedSession.id,
                startedAt: finishedSession.startedAt,
                endedAt: finishedSession.endedAt,
                elapsedSeconds: finishedSession.elapsedSeconds,
                totalDistanceMeters: finishedSession.totalDistanceMeters,
                routePoints: finishedSession.routePoints,
                memo: finishedSession.memo,
                characterID: characterID
            )
            _ = try routeStore.save(draft: draft, in: modelContext)
            saveState = .saved(Date())
            saveMessage = "ルートを保存しました。"
        } catch {
            saveState = .failed("保存に失敗しました: \(error.localizedDescription)")
            saveMessage = "保存に失敗しました。"
        }
    }

    func resetForNewWorkout() {
        stopTimer()
        startedAt = nil
        pausedAt = nil
        accumulatedPausedTime = 0
        elapsedSeconds = 0
        totalDistanceMeters = 0
        routePoints = []
        latestHorizontalAccuracy = nil
        finishedSession = nil
        saveState = .idle
        saveMessage = nil
        locationTrackingManager.reset()
        sessionState = .idle
        notifyStepWorkoutBGMShouldResumeMain()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            refreshElapsedTime()
            if sessionState == .running {
                startTimer()
            }
        case .background, .inactive:
            refreshElapsedTime()
            stopTimer()
        @unknown default:
            break
        }
    }

    private func bindLocationManager() {
        locationTrackingManager.$authorizationState
            .sink { [weak self] newValue in
                guard let self else { return }
                self.locationAuthorizationState = newValue

                if !newValue.isAuthorized, self.sessionState == .countingDown {
                    self.sessionState = .idle
                    self.notifyStepWorkoutBGMShouldResumeMain()
                }
            }
            .store(in: &cancellables)

        locationTrackingManager.$totalDistanceMeters
            .sink { [weak self] meters in
                self?.totalDistanceMeters = max(0, meters)
            }
            .store(in: &cancellables)

        locationTrackingManager.$routePoints
            .sink { [weak self] points in
                self?.routePoints = points
            }
            .store(in: &cancellables)

        locationTrackingManager.$latestHorizontalAccuracy
            .sink { [weak self] accuracy in
                self?.latestHorizontalAccuracy = accuracy
            }
            .store(in: &cancellables)
    }

    private func startNewWorkout() {
        resetForNewWorkout()
        startedAt = Date()
        sessionState = .running
        locationTrackingManager.startTracking()
        startTimer()
        refreshElapsedTime()
        notifyStepWorkoutBGMShouldStop()
    }

    private func pauseWorkout() {
        guard sessionState == .running else { return }
        pausedAt = Date()
        refreshElapsedTime()
        stopTimer()
        locationTrackingManager.pauseTracking()
        sessionState = .paused
    }

    private func resumeWorkout() {
        guard sessionState == .paused else { return }

        if let pausedAt {
            accumulatedPausedTime += Date().timeIntervalSince(pausedAt)
        }
        self.pausedAt = nil

        locationTrackingManager.resumeTracking()
        sessionState = .running
        refreshElapsedTime()
        startTimer()
        notifyStepWorkoutBGMShouldStop()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshElapsedTime()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func refreshElapsedTime() {
        elapsedSeconds = calculateElapsedSeconds(referenceDate: Date())
    }

    private func calculateElapsedSeconds(referenceDate: Date) -> Int {
        guard let startedAt else { return 0 }

        let effectiveReferenceDate: Date = {
            if sessionState == .paused, let pausedAt {
                return pausedAt
            }
            return referenceDate
        }()

        let activeInterval = effectiveReferenceDate.timeIntervalSince(startedAt) - accumulatedPausedTime
        return max(0, Int(activeInterval.rounded(.down)))
    }

    private func notifyStepWorkoutBGMShouldStop() {
        NotificationCenter.default.post(
            name: BGMManager.stepSessionDidEnterWorkoutNotification,
            object: nil
        )
    }

    private func notifyStepWorkoutBGMShouldResumeMain() {
        NotificationCenter.default.post(
            name: BGMManager.stepSessionDidExitWorkoutNotification,
            object: nil
        )
    }
}
