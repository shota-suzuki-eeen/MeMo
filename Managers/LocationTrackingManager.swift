//
//  LocationTrackingManager.swift
//  MeMo
//
//  Created by shota suzuki on 2026/04/07.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationTrackingManager: NSObject, ObservableObject {
    enum AuthorizationState: Equatable {
        case notDetermined
        case restricted
        case denied
        case authorizedWhenInUse
        case authorizedAlways

        var isAuthorized: Bool {
            self == .authorizedWhenInUse || self == .authorizedAlways
        }
    }

    @Published private(set) var authorizationState: AuthorizationState = .notDetermined
    @Published private(set) var routePoints: [WorkoutRoutePoint] = []
    @Published private(set) var totalDistanceMeters: Double = 0
    @Published private(set) var latestHorizontalAccuracy: CLLocationAccuracy?
    @Published private(set) var lastKnownLocation: CLLocation?
    @Published private(set) var isTracking: Bool = false

    private let locationManager = CLLocationManager()
    private var previousAcceptedLocation: CLLocation?

    private let maxAcceptedHorizontalAccuracy: CLLocationAccuracy = 65
    private let maxAcceptedLocationAge: TimeInterval = 10
    private let minimumDistanceDelta: CLLocationDistance = 1.5
    private let maxReasonableJumpDistance: CLLocationDistance = 250

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.pausesLocationUpdatesAutomatically = false

        // 画面遷移直後の初期化では有効化しない
        locationManager.allowsBackgroundLocationUpdates = false

        refreshAuthorizationState()
    }

    func refreshAuthorizationState() {
        authorizationState = Self.convert(CLLocationManager.authorizationStatus())
        updateBackgroundLocationCapability()
    }

    func requestAuthorization() {
        refreshAuthorizationState()

        switch authorizationState {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways, .restricted, .denied:
            break
        }
    }

    func startTracking() {
        refreshAuthorizationState()
        guard authorizationState.isAuthorized else { return }

        previousAcceptedLocation = nil
        isTracking = true
        updateBackgroundLocationCapability()
        locationManager.startUpdatingLocation()
    }

    func pauseTracking() {
        guard isTracking else { return }
        locationManager.stopUpdatingLocation()
        isTracking = false
        previousAcceptedLocation = nil
        updateBackgroundLocationCapability()
    }

    func resumeTracking() {
        refreshAuthorizationState()
        guard authorizationState.isAuthorized else { return }

        previousAcceptedLocation = nil
        isTracking = true
        updateBackgroundLocationCapability()
        locationManager.startUpdatingLocation()
    }

    func stopTracking(resetPreviousLocation: Bool = true) {
        locationManager.stopUpdatingLocation()
        isTracking = false
        if resetPreviousLocation {
            previousAcceptedLocation = nil
        }
        updateBackgroundLocationCapability()
    }

    func reset() {
        stopTracking()
        routePoints = []
        totalDistanceMeters = 0
        latestHorizontalAccuracy = nil
        lastKnownLocation = nil
    }

    private func updateBackgroundLocationCapability() {
        locationManager.allowsBackgroundLocationUpdates =
            (authorizationState == .authorizedAlways && isTracking)
    }

    private func appendAcceptedLocation(_ location: CLLocation) {
        latestHorizontalAccuracy = location.horizontalAccuracy
        lastKnownLocation = location

        let point = WorkoutRoutePoint(location: location)
        if routePoints.last?.coordinate.latitude != point.latitude ||
            routePoints.last?.coordinate.longitude != point.longitude {
            routePoints.append(point)
        }

        if let previousAcceptedLocation {
            let delta = location.distance(from: previousAcceptedLocation)
            if delta >= minimumDistanceDelta, delta <= maxReasonableJumpDistance {
                totalDistanceMeters += delta
            }
        }

        previousAcceptedLocation = location
    }

    private func shouldAccept(_ location: CLLocation) -> Bool {
        guard location.horizontalAccuracy >= 0 else { return false }
        guard location.horizontalAccuracy <= maxAcceptedHorizontalAccuracy else { return false }
        guard abs(location.timestamp.timeIntervalSinceNow) <= maxAcceptedLocationAge else { return false }

        if let previousAcceptedLocation {
            let delta = location.distance(from: previousAcceptedLocation)
            if delta > maxReasonableJumpDistance {
                return false
            }
        }

        return true
    }

    private static func convert(_ status: CLAuthorizationStatus) -> AuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
        case .authorizedAlways:
            return .authorizedAlways
        @unknown default:
            return .denied
        }
    }
}

extension LocationTrackingManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationState = Self.convert(manager.authorizationStatus)
            self.updateBackgroundLocationCapability()

            if !self.authorizationState.isAuthorized {
                self.stopTracking(resetPreviousLocation: true)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard self.isTracking else { return }

            for location in locations where self.shouldAccept(location) {
                self.appendAcceptedLocation(location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.latestHorizontalAccuracy = nil
        }
    }
}
