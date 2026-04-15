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
    @State private var isActivityPickerPresented = false

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
        static let countdownImageSize: CGFloat = 240
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
        isPrimarySwitcherScreen &&
        countdownNumber == nil &&
        !(selectedScreen == .activity && isActivityPickerPresented)
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
                isActivityPickerPresented = false
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
        MemoStepActivityDashboardView(
            records: workoutRecords,
            bottomInset: Layout.activityBottomPadding,
            characterAssetName: PetMaster.assetName(for: state.normalizedCurrentPetID),
            plainBackgroundAssetName: "Home_background",
            isPickerPresented: $isActivityPickerPresented
        ) {
            bgmManager.playSE(.push)
            isActivityPickerPresented = false
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

                Image(countdownAssetName(for: countdownNumber))
                    .resizable()
                    .scaledToFit()
                    .frame(width: Layout.countdownImageSize, height: Layout.countdownImageSize)
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

    private func countdownAssetName(for number: Int) -> String {
        switch number {
        case 3:
            return "run_3"
        case 2:
            return "run_2"
        default:
            return "run_1"
        }
    }

    private func handleStartButtonTapped() {
        selectedScreen = .run
        isActivityPickerPresented = false
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
    private let followSpan = MKCoordinateSpan(latitudeDelta: 0.0065, longitudeDelta: 0.0065)

    func makeCoordinator() -> Coordinator {
        Coordinator(
            defaultRegion: defaultRegion,
            followSpan: followSpan
        )
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
        mapView.userTrackingMode = .none

        if followsUserLocation {
            if let cachedCoordinate = Coordinator.cachedUserCoordinate {
                mapView.setRegion(
                    MKCoordinateRegion(center: cachedCoordinate, span: followSpan),
                    animated: false
                )
            }
        } else {
            mapView.setRegion(defaultRegion, animated: false)
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.updateFollowMode(followsUserLocation, on: mapView)

        let removableAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(removableAnnotations)
        mapView.removeOverlays(mapView.overlays)

        if followsUserLocation {
            context.coordinator.applyCurrentUserRegionIfNeeded(on: mapView)
        } else {
            context.coordinator.resetFollowingState()
        }

        guard !points.isEmpty else {
            if !followsUserLocation {
                context.coordinator.showDefaultRegion(on: mapView)
            }
            return
        }

        let coordinates = points.map(\.coordinate)

        if coordinates.count == 1, let coordinate = coordinates.first {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            mapView.addAnnotation(annotation)

            if !followsUserLocation {
                context.coordinator.showRegion(around: coordinate, on: mapView)
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

        static var cachedUserCoordinate: CLLocationCoordinate2D?

        private let defaultRegion: MKCoordinateRegion
        private let followSpan: MKCoordinateSpan
        private let recenterDistanceThreshold: CLLocationDistance = 12

        private var hasAppliedInitialUserRegion = false
        private var lastUserCoordinate: CLLocationCoordinate2D?

        init(
            defaultRegion: MKCoordinateRegion,
            followSpan: MKCoordinateSpan
        ) {
            self.defaultRegion = defaultRegion
            self.followSpan = followSpan
        }

        func updateFollowMode(_ followsUserLocation: Bool, on mapView: MKMapView) {
            let modeChanged = self.followsUserLocation != followsUserLocation
            self.followsUserLocation = followsUserLocation

            if mapView.userTrackingMode != .none {
                mapView.setUserTrackingMode(.none, animated: false)
            }

            guard followsUserLocation else { return }

            if modeChanged {
                resetFollowingState()
                applyCurrentUserRegionIfNeeded(on: mapView)
            }
        }

        func applyCurrentUserRegionIfNeeded(on mapView: MKMapView) {
            guard followsUserLocation else { return }

            let coordinate = mapView.userLocation.location?.coordinate ?? Self.cachedUserCoordinate
            guard let coordinate else { return }

            applyUserRegion(
                on: mapView,
                coordinate: coordinate,
                forceRegionRefresh: !hasAppliedInitialUserRegion
            )
        }

        func resetFollowingState() {
            hasAppliedInitialUserRegion = false
            lastUserCoordinate = nil
        }

        func showDefaultRegion(on mapView: MKMapView) {
            if let cachedUserCoordinate = Self.cachedUserCoordinate {
                showRegion(around: cachedUserCoordinate, on: mapView)
            } else {
                mapView.setRegion(defaultRegion, animated: false)
            }
        }

        func showRegion(around coordinate: CLLocationCoordinate2D, on mapView: MKMapView) {
            let region = MKCoordinateRegion(center: coordinate, span: followSpan)
            mapView.setRegion(region, animated: false)
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard followsUserLocation,
                  let location = userLocation.location else { return }

            applyUserRegion(on: mapView, coordinate: location.coordinate)
        }

        func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
            guard !followsUserLocation else { return }
            showDefaultRegion(on: mapView)
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

        private func applyUserRegion(
            on mapView: MKMapView,
            coordinate: CLLocationCoordinate2D,
            forceRegionRefresh: Bool = false
        ) {
            Self.cachedUserCoordinate = coordinate

            if forceRegionRefresh || !hasAppliedInitialUserRegion {
                hasAppliedInitialUserRegion = true
                lastUserCoordinate = coordinate
                mapView.setRegion(
                    MKCoordinateRegion(center: coordinate, span: followSpan),
                    animated: false
                )
                return
            }

            guard shouldRecenter(for: coordinate) else { return }

            lastUserCoordinate = coordinate
            mapView.setCenter(coordinate, animated: false)
        }

        private func shouldRecenter(for coordinate: CLLocationCoordinate2D) -> Bool {
            guard let lastUserCoordinate else { return true }

            let previousLocation = CLLocation(
                latitude: lastUserCoordinate.latitude,
                longitude: lastUserCoordinate.longitude
            )
            let newLocation = CLLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )

            return newLocation.distance(from: previousLocation) >= recenterDistanceThreshold
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
