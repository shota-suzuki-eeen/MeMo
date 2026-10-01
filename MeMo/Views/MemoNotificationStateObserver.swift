import SwiftUI

/// Keeps TASK_008 reconciliation separate from HomeView's already-split modifier chain.
struct MemoNotificationStateObserver: View {
    @Environment(\.scenePhase) private var scenePhase
    let state: AppState

    var body: some View {
        Color.clear
            .task { await reconcileAll() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await reconcileAll() }
            }
            .onChange(of: state.satisfactionLevel) { _, _ in reconcileHome() }
            .onChange(of: state.satisfactionLastUpdatedAt) { _, _ in reconcileHome() }
            .onChange(of: state.toiletFlagAt) { _, _ in reconcileHome() }
            .onChange(of: state.toiletNextSpawnAt) { _, _ in reconcileHome() }
            .onReceive(NotificationCenter.default.publisher(for: .memoMandatoryOnboardingDidComplete)) { _ in
                Task { await reconcileAll() }
            }
    }

    @MainActor
    private func reconcileAll() async {
        MemoNotificationReconciler.shared.register(appState: state)
        await MemoNotificationReconciler.shared.reconcileAll()
    }

    private func reconcileHome() {
        Task { @MainActor in
            MemoNotificationReconciler.shared.register(appState: state)
            await MemoNotificationReconciler.shared.reconcileHome()
        }
    }
}
