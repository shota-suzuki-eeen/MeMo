//
//  AppState+LiveActivity.swift
//  MeMo
//
//  Converts the current AppState into a Live Activity content state.
//  Add this file to the MeMo app target only.
//

import Foundation

extension AppState {
    static let liveActivityTenGachaCost: Int = 5_000

    var liveActivityPetName: String {
        let petID = normalizedCurrentPetID
        if let pet = PetMaster.all.first(where: { $0.id == petID }) {
            let trimmed = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed != "*" {
                return trimmed
            }
        }
        return "ぬくもりペット"
    }

    var liveActivityPetImageName: String {
        PetMaster.assetName(for: normalizedCurrentPetID)
    }

    @available(iOS 16.1, *)
    func makeLiveActivityContentState(now: Date = Date()) -> MeMoCareActivityAttributes.ContentState {
        ensureDailyResetIfNeeded(now: now)
        resetHappinessPettingIfNeeded(now: now)

        return MeMoCareActivityAttributes.ContentState(
            petName: liveActivityPetName,
            petImageName: liveActivityPetImageName,
            todaySteps: widgetTodaySteps,
            dailyStepGoal: AppState.fixedDailyStepGoal,
            fullnessLevel: satisfactionLevel,
            fullnessMaxLevel: AppState.fullnessMaxLevel,
            happinessPoint: happinessPoint,
            happinessMaxPoint: AppState.happinessMaxPointsPerLevel,
            walletSteps: walletSteps,
            tenGachaCost: AppState.liveActivityTenGachaCost,
            updatedAt: now
        )
    }
}
