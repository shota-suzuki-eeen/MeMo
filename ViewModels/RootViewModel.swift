//
//  RootViewModel.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class RootViewModel: ObservableObject {
    @Published private(set) var didBoot: Bool = false
    @Published var sharedState: AppState?

    func bootIfNeeded(
        appStates: [AppState],
        modelContext: ModelContext,
        hk: HealthKitManager,
        bgmManager: BGMManager
    ) async {
        let state = ensureAppState(appStates: appStates, modelContext: modelContext)
        sharedState = state
        state.ensureInitialPetsIfNeeded()

        guard !didBoot else { return }
        didBoot = true

        state.ensureDailyResetIfNeeded(now: Date())
        try? modelContext.save()

        await startAuthorizationIfNeeded(hk: hk)
        bgmManager.startIfNeeded()
    }

    func startAuthorizationIfNeeded(hk: HealthKitManager) async {
        guard hk.authState == .unknown else { return }
        await hk.requestAuthorization()
    }

    func ensureAppState(appStates: [AppState], modelContext: ModelContext) -> AppState {
        if let first = appStates.first { return first }

        let created = AppState()
        modelContext.insert(created)
        try? modelContext.save()
        return created
    }
}
