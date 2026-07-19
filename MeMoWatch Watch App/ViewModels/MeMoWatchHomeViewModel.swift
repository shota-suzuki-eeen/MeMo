//
//  MeMoWatchHomeViewModel.swift
//  MeMo Watch App
//

import Combine
import Foundation
import SwiftUI

fileprivate extension Int {
    func memoPositiveModulo(_ modulus: Int) -> Int {
        guard modulus > 0 else { return self }
        let remainder = self % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }
}

enum MeMoWatchFoodRarityTab: String, CaseIterable, Identifiable {
    case normal = "N"
    case rare = "R"

    var id: String { rawValue }

    var next: MeMoWatchFoodRarityTab {
        self == .normal ? .rare : .normal
    }

    func matches(_ food: MeMoWatchFoodItemSnapshot) -> Bool {
        switch self {
        case .normal:
            return !food.isRare
        case .rare:
            return food.isRare
        }
    }

    var emptyMessage: String {
        switch self {
        case .normal:
            return "Nのごはんはありません"
        case .rare:
            return "Rのごはんはありません"
        }
    }
}

@MainActor
final class MeMoWatchHomeViewModel: ObservableObject {
    @Published private(set) var snapshot: MeMoWatchSnapshot = .placeholder
    @Published private(set) var isPettingFeedbackActive: Bool = false

    @Published var isFoodSelectorPresented: Bool = false
    @Published var selectedFoodID: String?
    @Published var selectedFoodRarityTab: MeMoWatchFoodRarityTab = .normal
    @Published private(set) var pendingFoodID: String?
    @Published private(set) var pendingFoodDragOffsetY: CGFloat = 0
    @Published private(set) var isFoodFeedingAnimationRunning: Bool = false

    private let bridge = MeMoWatchConnectivityBridge.shared
    private var cancellables = Set<AnyCancellable>()
    private var pettingFeedbackTask: Task<Void, Never>?
    private var feedingAnimationTask: Task<Void, Never>?
    private var hasStarted = false

    var todaySteps: Int {
        max(0, snapshot.todaySteps)
    }

    var dailyStepGoal: Int {
        max(1, snapshot.dailyStepGoal)
    }

    var stepProgress: Double {
        min(1, max(0, Double(todaySteps) / Double(dailyStepGoal)))
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

    var canShowFoodBubble: Bool {
        fullnessLevel < fullnessMaxLevel
        && !isFoodSelectorPresented
        && pendingFoodID == nil
    }

    var desiredFoodAssetName: String? {
        let name = snapshot.desiredFoodAssetName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return nil }
        return name
    }

    var ownedFoods: [MeMoWatchFoodItemSnapshot] {
        snapshot.ownedFoods ?? []
    }

    var currentFoodSelectorFoods: [MeMoWatchFoodItemSnapshot] {
        ownedFoods.filter { selectedFoodRarityTab.matches($0) }
    }

    var selectedFood: MeMoWatchFoodItemSnapshot? {
        let foods = currentFoodSelectorFoods
        guard !foods.isEmpty else { return nil }
        guard let selectedFoodID else { return foods.first }
        return foods.first(where: { $0.id == selectedFoodID }) ?? foods.first
    }

    var selectedFoodIndex: Int {
        let foods = currentFoodSelectorFoods
        guard !foods.isEmpty else { return 0 }
        guard let selectedFoodID,
              let index = foods.firstIndex(where: { $0.id == selectedFoodID }) else {
            return 0
        }
        return index
    }

    var pendingFood: MeMoWatchFoodItemSnapshot? {
        guard let pendingFoodID else { return nil }
        return ownedFoods.first(where: { $0.id == pendingFoodID })
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true

        bridge.activate()
        snapshot = bridge.latestSnapshot
        reconcileFoodStateWithSnapshot()
        bridge.requestCurrentSnapshot()

        bridge.$latestSnapshot
            .receive(on: DispatchQueue.main)
            .sink { [weak self] nextSnapshot in
                guard let self else { return }
                self.snapshot = nextSnapshot
                self.reconcileFoodStateWithSnapshot()
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
            self?.isPettingFeedbackActive = false
        }
    }

    func openFoodSelector() {
        guard fullnessLevel < fullnessMaxLevel else { return }

        pendingFoodID = nil
        pendingFoodDragOffsetY = 0
        isFoodFeedingAnimationRunning = false

        if let desiredFoodID = snapshot.desiredFoodID,
           let desiredFood = ownedFoods.first(where: { $0.id == desiredFoodID }) {
            selectedFoodRarityTab = desiredFood.isRare ? .rare : .normal
            selectedFoodID = desiredFood.id
        } else {
            syncFoodSelection()
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            isFoodSelectorPresented = true
        }
    }

    func closeFoodSelector() {
        withAnimation(.spring(response: 0.26, dampingFraction: 0.90)) {
            isFoodSelectorPresented = false
        }
    }

    func toggleFoodRarity() {
        selectedFoodRarityTab = selectedFoodRarityTab.next
        syncFoodSelection(forceFirst: true)
    }

    func moveFoodSelection(_ delta: Int) {
        let foods = currentFoodSelectorFoods
        guard !foods.isEmpty else {
            selectedFoodID = nil
            return
        }
        guard delta != 0 else { return }

        let currentIndex = selectedFoodIndex
        let nextIndex = (currentIndex + delta).memoPositiveModulo(foods.count)
        selectedFoodID = foods[nextIndex].id
    }

    func selectFood(at index: Int) {
        let foods = currentFoodSelectorFoods
        guard !foods.isEmpty else {
            selectedFoodID = nil
            return
        }

        let resolvedIndex = index.memoPositiveModulo(foods.count)
        selectedFoodID = foods[resolvedIndex].id
    }

    func selectFood(id: String) {
        guard currentFoodSelectorFoods.contains(where: { $0.id == id }) else { return }
        selectedFoodID = id
    }

    func confirmSelectedFood() {
        guard let selectedFood else { return }
        pendingFoodID = selectedFood.id
        pendingFoodDragOffsetY = 0

        withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
            isFoodSelectorPresented = false
        }
    }

    func updatePendingFoodDrag(translationY: CGFloat) {
        guard pendingFoodID != nil else { return }
        pendingFoodDragOffsetY = max(-88, min(88, translationY))
    }

    func endPendingFoodDrag(
        translationY: CGFloat,
        predictedEndTranslationY: CGFloat
    ) {
        guard pendingFoodID != nil else { return }
        guard !isFoodFeedingAnimationRunning else { return }

        let threshold: CGFloat = 34
        let projected = abs(predictedEndTranslationY) > abs(translationY)
            ? predictedEndTranslationY
            : translationY

        if translationY <= -threshold || projected <= -threshold {
            feedPendingFood()
            return
        }

        if translationY >= threshold || projected >= threshold {
            cancelPendingFood()
            return
        }

        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            pendingFoodDragOffsetY = 0
        }
    }

    func cancelPendingFood() {
        guard pendingFoodID != nil else { return }

        withAnimation(.spring(response: 0.22, dampingFraction: 0.90)) {
            pendingFoodDragOffsetY = 54
        }

        pendingFoodID = nil
        pendingFoodDragOffsetY = 0
    }

    func feedPendingFood() {
        guard let pendingFoodID else { return }
        guard !isFoodFeedingAnimationRunning else { return }

        isFoodFeedingAnimationRunning = true
        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
            pendingFoodDragOffsetY = -120
        }

        bridge.sendFoodFeedRequest(foodID: pendingFoodID)

        feedingAnimationTask?.cancel()
        feedingAnimationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            guard let self else { return }

            self.pendingFoodID = nil
            self.pendingFoodDragOffsetY = 0
            self.isFoodFeedingAnimationRunning = false
            self.feedingAnimationTask = nil

            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }
            self.bridge.requestCurrentSnapshot()
        }
    }

    private func reconcileFoodStateWithSnapshot() {
        if fullnessLevel >= fullnessMaxLevel {
            isFoodSelectorPresented = false
            if !isFoodFeedingAnimationRunning {
                pendingFoodID = nil
                pendingFoodDragOffsetY = 0
            }
        }

        if let pendingFoodID,
           !ownedFoods.contains(where: { $0.id == pendingFoodID }) {
            self.pendingFoodID = nil
            pendingFoodDragOffsetY = 0
            isFoodFeedingAnimationRunning = false
        }

        syncFoodSelection()
    }

    private func syncFoodSelection(forceFirst: Bool = false) {
        let foods = currentFoodSelectorFoods
        guard !foods.isEmpty else {
            selectedFoodID = nil
            return
        }

        if !forceFirst,
           let selectedFoodID,
           foods.contains(where: { $0.id == selectedFoodID }) {
            return
        }

        selectedFoodID = foods.first?.id
    }

    deinit {
        pettingFeedbackTask?.cancel()
        feedingAnimationTask?.cancel()
    }
}
