//
//  CaptureLocationManager.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class CaptureLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var placeName: String? = nil
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private var didRequestOnce = false
    private var didResolvePlace = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
    }

    func start() {
        // すでに解決済みなら何もしない（無駄な再取得防止）
        if didResolvePlace { return }

        let status = manager.authorizationStatus
        authorizationStatus = status

        switch status {
        case .notDetermined:
            // 1回だけ許可要求
            if !didRequestOnce {
                didRequestOnce = true
                manager.requestWhenInUseAuthorization()
            }

        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()

        case .denied, .restricted:
            // 拒否/制限なら何もしない（placeNameはnilのまま）
            break

        @unknown default:
            break
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        geocoder.cancelGeocode()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authorizationStatus = status

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            stop()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !didResolvePlace else { return }
        guard let loc = locations.last else { return }

        // 逆ジオコーディングは1回だけ
        didResolvePlace = true
        manager.stopUpdatingLocation()

        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            guard let self else { return }
            let pm = placemarks?.first

            // 表示に使いやすい順で採用
            let name =
                pm?.name ??
                pm?.locality ??          // 市区町村
                pm?.administrativeArea ?? // 都道府県
                pm?.country

            Task { @MainActor in
                self.placeName = name
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 失敗しても placeName は nil のまま（表示側が "おもいで" フォールバック）
        stop()
    }
}
