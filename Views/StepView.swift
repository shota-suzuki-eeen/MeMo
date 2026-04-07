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
    @EnvironmentObject private var bgmManager: BGMManager

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

    private enum Layout {
        static let startButtonSize: CGFloat = 212
        static let idleBottomPadding: CGFloat = 108
        static let sectionHorizontalPadding: CGFloat = 20
        static let bottomCardCornerRadius: CGFloat = 30
        static let closeButtonSize: CGFloat = 40
    }

    var body: some View {
        ZStack {
            StepBackdropMapView(
                points: backdropRoutePoints,
                followsUserLocation: shouldFollowUserLocation
            )
            .ignoresSafeArea()

            backgroundOverlay
                .ignoresSafeArea()

            contentView

            dismissButton

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
        case .idle, .waitingForPermission, .countingDown:
            return true
        case .running, .paused:
            return viewModel.routePoints.isEmpty
        case .finished:
            return false
        }
    }

    @ViewBuilder
    private var backgroundOverlay: some View {
        switch viewModel.sessionState {
        case .idle, .waitingForPermission, .countingDown:
            Color.white.opacity(0.70)
        case .running, .paused:
            LinearGradient(
                colors: [
                    Color.white.opacity(0.16),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.26)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .finished:
            LinearGradient(
                colors: [
                    Color.white.opacity(0.14),
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.32)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var dismissButton: some View {
        VStack {
            HStack {
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
            idleContentView
        case .running, .paused:
            activeContentView
        case .finished:
            finishedContentView
        }
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
        mapView.showsUserLocation = true
        mapView.setRegion(defaultRegion, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.followsUserLocation = followsUserLocation

        let removableAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(removableAnnotations)
        mapView.removeOverlays(mapView.overlays)

        guard !points.isEmpty else {
            if followsUserLocation {
                if mapView.userTrackingMode != .follow {
                    mapView.setUserTrackingMode(.follow, animated: false)
                }
            } else {
                if mapView.userTrackingMode != .none {
                    mapView.setUserTrackingMode(.none, animated: false)
                }
            }
            return
        }

        if mapView.userTrackingMode != .none {
            mapView.setUserTrackingMode(.none, animated: false)
        }

        let coordinates = points.map(\.coordinate)

        if coordinates.count == 1, let coordinate = coordinates.first {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            mapView.addAnnotation(annotation)
            mapView.setCenter(coordinate, animated: false)
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

        let edgePadding = UIEdgeInsets(top: 120, left: 40, bottom: 220, right: 40)
        mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: edgePadding, animated: false)
    }
}

private extension StepBackdropMapView {
    final class Coordinator: NSObject, MKMapViewDelegate {
        var followsUserLocation: Bool = true
        private let defaultRegion: MKCoordinateRegion
        private var didCenterOnUserLocation = false

        init(defaultRegion: MKCoordinateRegion) {
            self.defaultRegion = defaultRegion
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard followsUserLocation else { return }
            guard !didCenterOnUserLocation else { return }
            guard let location = userLocation.location else { return }

            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
            )
            mapView.setRegion(region, animated: false)
            didCenterOnUserLocation = true
        }

        func mapView(_ mapView: MKMapView, didFailToLocateUserWithError error: Error) {
            guard !didCenterOnUserLocation else { return }
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
