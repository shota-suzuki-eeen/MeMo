//
//  MeMoWatchBridgeInstaller.swift
//  MeMo
//
//  iPhone-side installer.
//  Add this file to the iPhone App target only.
//

import SwiftUI

#if os(iOS)
struct MeMoWatchBridgeInstaller: ViewModifier {
    let appState: AppState
    @ObservedObject var healthKitManager: HealthKitManager
    let backgroundAssetName: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                publishCurrentSnapshot(installIfNeeded: true)
            }
            .onChange(of: appState.currentPetID) { _, _ in
                publishCurrentSnapshot()
            }
            .onChange(of: appState.cachedTodaySteps) { _, _ in
                publishCurrentSnapshot()
            }
            .onChange(of: healthKitManager.todaySteps) { _, _ in
                publishCurrentSnapshot()
            }
            .onChange(of: appState.happinessPoint) { _, _ in
                publishCurrentSnapshot()
            }
            .onChange(of: appState.happinessLevel) { _, _ in
                publishCurrentSnapshot()
            }
            .onChange(of: appState.satisfactionLevel) { _, _ in
                publishCurrentSnapshot()
            }
            .onChange(of: appState.satisfactionLastUpdatedAt) { _, _ in
                publishCurrentSnapshot()
            }
            .onChange(of: backgroundAssetName) { _, _ in
                publishCurrentSnapshot()
            }
    }

    private func publishCurrentSnapshot(installIfNeeded: Bool = false) {
        if installIfNeeded {
            MeMoWatchConnectivityBridge.shared.install(
                appState: appState,
                healthKitManager: healthKitManager
            )
        }

        MeMoWatchConnectivityBridge.shared.publishCurrentSnapshot(
            backgroundAssetName: backgroundAssetName
        )
    }
}

extension View {
    func installMeMoWatchBridge(
        appState: AppState,
        healthKitManager: HealthKitManager,
        backgroundAssetName: String = "Home_background"
    ) -> some View {
        modifier(
            MeMoWatchBridgeInstaller(
                appState: appState,
                healthKitManager: healthKitManager,
                backgroundAssetName: backgroundAssetName
            )
        )
    }
}
#endif
