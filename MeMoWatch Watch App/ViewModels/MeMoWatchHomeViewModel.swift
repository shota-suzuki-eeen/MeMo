//
//  MeMoWatchHomeViewModel.swift
//  MeMo Watch App
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class MeMoWatchHomeViewModel: ObservableObject {
    @Published private(set) var snapshot: MeMoWatchSnapshot = .placeholder
    @Published private(set) var isPettingFeedbackActive: Bool = false

    private let bridge = MeMoWatchConnectivityBridge.shared
    private var cancellables = Set<AnyCancellable>()
    private var pettingFeedbackTask: Task<Void, Never>?

    var todaySteps: Int {
        max(0, snapshot.todaySteps)
    }

    var stepProgress: Double {
        let goal = max(1, snapshot.dailyStepGoal)
        return min(1, max(0, Double(todaySteps) / Double(goal)))
    }

    var currentCharacterAssetName: String {
        let base = snapshot.characterAssetName.trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? "person" : base
    }

    var backgroundAssetName: String {
        let name = snapshot.backgroundAssetName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Home_background" : name
    }

    var happinessPoint: Int {
        max(0, snapshot.happinessPoint)
    }

    var happinessLevel: Int {
        max(0, snapshot.happinessLevel)
    }

    var happinessMaxPoint: Int {
        max(1, snapshot.happinessMaxPoint)
    }

    var fullnessLevel: Int {
        max(0, snapshot.fullnessLevel)
    }

    var fullnessMaxLevel: Int {
        max(1, snapshot.fullnessMaxLevel)
    }

    func start() async {
        bridge.activate()
        snapshot = bridge.latestSnapshot

        bridge.$latestSnapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] nextSnapshot in
                self?.snapshot = nextSnapshot
            }
            .store(in: &cancellables)
    }

    func petCharacter() {
        bridge.sendPettingTouch()

        isPettingFeedbackActive = true
        pettingFeedbackTask?.cancel()
        pettingFeedbackTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.isPettingFeedbackActive = false
            }
        }
    }

    deinit {
        pettingFeedbackTask?.cancel()
    }
}
