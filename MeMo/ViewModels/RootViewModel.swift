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
    @Published private(set) var recoveryError: String?

    func bootIfNeeded(
        appStates: [AppState],
        modelContext: ModelContext,
        hk: HealthKitManager,
        bgmManager: BGMManager
    ) async {
        let state = ensureAppState(appStates: appStates, modelContext: modelContext)
        do {
            try Halloween2026GachaGranting.recover(state: state, store: .shared, context: modelContext)
            recoveryError = nil
        } catch {
            recoveryError = "報酬の保存を完了できませんでした。アプリを再度開いてください。"
            return
        }
        sharedState = state
        state.ensureInitialPetsIfNeeded()

        guard !didBoot else { return }
        didBoot = true

        state.ensureDailyResetIfNeeded(now: Date())
        try? modelContext.save()

        await startAuthorizationIfNeeded(hk: hk)
        bgmManager.setDefaultBackground(for: state.normalizedCurrentPetID)
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
