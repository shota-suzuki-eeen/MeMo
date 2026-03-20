//
//  StepViewModel.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation
import Combine

@MainActor
final class StepViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var isClaiming = false

    @Published var deltaSteps: Int = 0
    @Published var dayTotalSteps: Int = 0
    @Published var weekTotalSteps: Int = 0
    @Published var claimableCount: Int = 0

    @Published var gainedFoodName: String?

    func refresh(state: AppState, hk: HealthKitManager, save: () -> Void) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let now = Date()
        applyDailyResetIfNeeded(state: state, now: now)

        let start = state.stepEnjoyLastCheckedAt ?? now
        let fetchedDelta = await hk.fetchStepCount(from: start, to: now)
        let safeDelta = max(0, fetchedDelta)

        state.stepEnjoyLastCheckedAt = now
        state.stepEnjoyLastDeltaSteps = safeDelta
        state.stepEnjoyTotalSteps += safeDelta

        deltaSteps = safeDelta

        let fetchedTodayTotal = await hk.fetchTodayStepTotal(now: now)
        let resolvedTodayTotal = max(state.cachedTodaySteps, hk.todaySteps, fetchedTodayTotal)
        dayTotalSteps = max(0, resolvedTodayTotal)

        weekTotalSteps = await hk.fetchWeekStepTotal(now: now)

        // ✅ 今日の実歩数を正として、未受取ぶんの bank を再同期する
        state.stepEnjoyDailyRewardStepBank = StepRewardPolicy.bank(
            totalWalkedSteps: dayTotalSteps,
            claimedToday: state.stepEnjoyDailyRewardCount
        )

        claimableCount = StepRewardPolicy.claimableCount(
            bank: state.stepEnjoyDailyRewardStepBank,
            claimedToday: state.stepEnjoyDailyRewardCount
        )

        save()
    }

    func claimNormalReward(state: AppState, save: () -> Void) {
        claimReward(state: state, decreaseSatisfaction: false, save: save)
    }

    func claimAdReward(state: AppState, save: () -> Void) {
        claimReward(state: state, decreaseSatisfaction: true, save: save)
    }

    private func claimReward(state: AppState, decreaseSatisfaction: Bool, save: () -> Void) {
        guard !isClaiming else { return }
        isClaiming = true
        defer { isClaiming = false }

        let claimable = StepRewardPolicy.claimableCount(
            bank: state.stepEnjoyDailyRewardStepBank,
            claimedToday: state.stepEnjoyDailyRewardCount
        )

        guard claimable >= 1 else { return }

        state.stepEnjoyDailyRewardCount += 1
        state.stepEnjoyLastRewardAt = Date()

        // ✅ 受け取り後も「今日の実歩数」を正として bank を再計算
        state.stepEnjoyDailyRewardStepBank = StepRewardPolicy.bank(
            totalWalkedSteps: dayTotalSteps,
            claimedToday: state.stepEnjoyDailyRewardCount
        )

        if let reward = FoodCatalog.all.randomElement() {
            _ = state.addFood(foodId: reward.id, count: 1)
            gainedFoodName = reward.name
        } else {
            gainedFoodName = nil
        }

        if decreaseSatisfaction {
            _ = state.decreaseSatisfaction(by: 1, now: Date())
        }

        claimableCount = StepRewardPolicy.claimableCount(
            bank: state.stepEnjoyDailyRewardStepBank,
            claimedToday: state.stepEnjoyDailyRewardCount
        )

        save()
    }

    private func applyDailyResetIfNeeded(state: AppState, now: Date) {
        if StepRewardPolicy.shouldResetDailyCycle(stored: state.stepEnjoyDailyCycleStart, now: now) {
            state.stepEnjoyDailyCycleStart = StepRewardPolicy.normalizedCycleStart(for: now)
            state.stepEnjoyDailyRewardCount = 0
            state.stepEnjoyDailyRewardStepBank = 0
        }
    }
}
