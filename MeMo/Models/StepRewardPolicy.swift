//
//  StepRewardPolicy.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation

enum StepRewardPolicy {
    static let rewardStepThreshold = 2_000
    static let dailyRewardMaxCount = 5
    static let dailyRewardStepCap = 10_000

    static func normalizedCycleStart(for now: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: now)
    }

    static func shouldResetDailyCycle(stored: Date, now: Date, calendar: Calendar = .current) -> Bool {
        normalizedCycleStart(for: stored, calendar: calendar) != normalizedCycleStart(for: now, calendar: calendar)
    }

    static func cappedProgressSteps(from totalWalkedSteps: Int) -> Int {
        min(dailyRewardStepCap, max(0, totalWalkedSteps))
    }

    static func bank(totalWalkedSteps: Int, claimedToday: Int) -> Int {
        let progress = cappedProgressSteps(from: totalWalkedSteps)
        let claimedSteps = min(dailyRewardStepCap, max(0, claimedToday) * rewardStepThreshold)
        return max(0, progress - claimedSteps)
    }

    static func claimableCount(bank: Int, claimedToday: Int) -> Int {
        let eligibleBySteps = max(0, bank / rewardStepThreshold)
        let eligibleByCap = max(0, dailyRewardMaxCount - claimedToday)
        return max(0, min(eligibleBySteps, eligibleByCap))
    }

    static func nextRewardRemainingSteps(totalWalkedSteps: Int, claimedToday: Int) -> Int {
        guard claimedToday < dailyRewardMaxCount else { return 0 }

        let nextBorder = min(dailyRewardStepCap, (claimedToday + 1) * rewardStepThreshold)
        let progress = cappedProgressSteps(from: totalWalkedSteps)

        return max(0, nextBorder - progress)
    }
}
