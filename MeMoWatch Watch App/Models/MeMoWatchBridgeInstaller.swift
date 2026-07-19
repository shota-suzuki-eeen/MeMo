//
//  MeMoWatchBridgeInstaller.swift
//  MeMo
//
//  iPhone-side installer.
//  Add this file to the iPhone App target only.
//

import SwiftUI

#if os(iOS)
import Combine
import SwiftData

struct MeMoWatchBridgeInstaller: ViewModifier {
    @Environment(\.modelContext) private var modelContext

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
            .onChange(of: appState.ownedFoodCountsData) { _, _ in
                publishCurrentSnapshot()
            }
            .onChange(of: appState.toiletFlagAt) { _, _ in
                publishCurrentSnapshot()
            }
            .onChange(of: appState.toiletPoopsData) { _, _ in
                publishCurrentSnapshot()
            }
            .onChange(of: appState.toiletPoopLastSpawnAt) { _, _ in
                publishCurrentSnapshot()
            }
            .onChange(of: appState.toiletNextSpawnAt) { _, _ in
                publishCurrentSnapshot()
            }
            .onChange(of: backgroundAssetName) { _, _ in
                publishCurrentSnapshot()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .memoDesiredFoodDidChange)
            ) { _ in
                publishCurrentSnapshot()
            }
    }

    private func publishCurrentSnapshot(installIfNeeded: Bool = false) {
        if installIfNeeded {
            MeMoWatchConnectivityBridge.shared.install(
                appState: appState,
                healthKitManager: healthKitManager,
                persistChanges: {
                    do {
                        try modelContext.save()
                    } catch {
                        print("❌ MeMoWatch bridge save failed: \(error)")
                    }
                }
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
