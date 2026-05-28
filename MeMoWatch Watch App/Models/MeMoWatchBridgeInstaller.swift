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
    let healthKitManager: HealthKitManager
    let backgroundAssetName: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                MeMoWatchConnectivityBridge.shared.install(
                    appState: appState,
                    healthKitManager: healthKitManager
                )
                MeMoWatchConnectivityBridge.shared.publishCurrentSnapshot(
                    backgroundAssetName: backgroundAssetName
                )
            }
            .onChange(of: appState.currentPetID) { _, _ in
                MeMoWatchConnectivityBridge.shared.publishCurrentSnapshot(
                    backgroundAssetName: backgroundAssetName
                )
            }
            .onChange(of: appState.cachedTodaySteps) { _, _ in
                MeMoWatchConnectivityBridge.shared.publishCurrentSnapshot(
                    backgroundAssetName: backgroundAssetName
                )
            }
            .onChange(of: appState.satisfactionLevel) { _, _ in
                MeMoWatchConnectivityBridge.shared.publishCurrentSnapshot(
                    backgroundAssetName: backgroundAssetName
                )
            }
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
