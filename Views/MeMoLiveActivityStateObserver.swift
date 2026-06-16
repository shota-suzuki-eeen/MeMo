//
//  MeMoLiveActivityStateObserver.swift
//  MeMo
//
//  Invisible bridge that keeps the active Live Activity synchronized with AppState.
//  Add this file to the MeMo app target only.
//

import Combine
import SwiftUI

struct MeMoLiveActivityStateObserver: View {
    @Environment(\.scenePhase) private var scenePhase

    let state: AppState

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                requestLaunchSynchronization()
            }
            .onReceive(timer) { _ in
                guard scenePhase == .active else { return }
                requestUpdate(force: false)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                requestLaunchSynchronization()
            }
            .onChange(of: state.satisfactionLevel) { _, _ in
                requestUpdate(force: true)
            }
            .onChange(of: state.satisfactionLastUpdatedAt) { _, _ in
                requestUpdate(force: true)
            }
            .onChange(of: state.happinessLevel) { _, _ in
                requestUpdate(force: true)
            }
            .onChange(of: state.happinessPoint) { _, _ in
                requestUpdate(force: true)
            }
            .onChange(of: state.toiletFlagAt) { _, _ in
                requestUpdate(force: true)
            }
            .onChange(of: state.toiletNextSpawnAt) { _, _ in
                requestUpdate(force: false)
            }
            .onChange(of: state.currentPetID) { _, _ in
                requestUpdate(force: true)
            }
            .onChange(of: state.cachedTodaySteps) { _, _ in
                requestUpdate(force: false)
            }
            .onChange(of: state.walletSteps) { _, _ in
                requestUpdate(force: true)
            }
    }

    private func requestLaunchSynchronization() {
        Task { @MainActor in
            await MeMoLiveActivityManager.shared.synchronizeOnAppLaunch(from: state)
        }
    }

    private func requestUpdate(force: Bool) {
        Task { @MainActor in
            await MeMoLiveActivityManager.shared.updateIfNeeded(from: state, force: force)
        }
    }
}
