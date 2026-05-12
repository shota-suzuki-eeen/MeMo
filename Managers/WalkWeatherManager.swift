//
//  WalkWeatherManager.swift
//  MeMo
//
//  雨の日の1日1回広告不要スタート判定に使う天気取得マネージャー。
//  WeatherKit が利用できない環境では isRainyToday=false のまま安全側に倒す。
//

import Foundation
import Combine
import CoreLocation

#if canImport(WeatherKit)
import WeatherKit
#endif

final class WalkWeatherManager: NSObject, ObservableObject {
    static let shared = WalkWeatherManager()

    @Published private(set) var isRainyToday: Bool = false
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var lastErrorMessage: String?

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    @MainActor
    func refreshRainStatus() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastErrorMessage = nil
        defer { isRefreshing = false }

        #if canImport(WeatherKit)
        guard let location = await requestCurrentLocation() else {
            lastErrorMessage = "位置情報を取得できませんでした"
            return
        }

        do {
            let weather = try await WeatherService.shared.weather(for: location)
            isRainyToday = Self.isRainCondition(weather.currentWeather.condition)
            lastUpdatedAt = Date()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
        #else
        isRainyToday = false
        lastErrorMessage = "WeatherKit が利用できません"
        #endif
    }

    @MainActor
    private func requestCurrentLocation() async -> CLLocation? {
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            return locationManager.location
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            break
        }

        if let cached = locationManager.location,
           abs(cached.timestamp.timeIntervalSinceNow) < 30 * 60 {
            return cached
        }

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    #if canImport(WeatherKit)
    private static func isRainCondition(_ condition: WeatherCondition) -> Bool {
        let text = String(describing: condition).lowercased()
        let rainKeywords = [
            "rain",
            "drizzle",
            "shower",
            "thunder",
            "storm",
            "sleet",
            "hail",
            "wintry"
        ]
        return rainKeywords.contains { text.contains($0) }
    }
    #endif
}

extension WalkWeatherManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor [weak self] in
            self?.locationContinuation?.resume(returning: location)
            self?.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.lastErrorMessage = error.localizedDescription
            self?.locationContinuation?.resume(returning: manager.location)
            self?.locationContinuation = nil
        }
    }
}
