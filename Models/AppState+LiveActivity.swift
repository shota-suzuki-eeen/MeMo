//
//  AppState+LiveActivity.swift
//  MeMo
//
//  Converts the current AppState into a Live Activity content state.
//  Add this file to the MeMo app target only.
//

import Foundation

extension AppState {
    static let liveActivityTenGachaCost: Int = 10_000

    var liveActivityPetName: String {
        let petID = normalizedCurrentPetID

        // ユーザー編集名が追加された場合は、ここで UserDefaults / SwiftData の保存値を最優先にする。
        let customNameKey = "memo.pet.customName.\(petID)"
        let customName = UserDefaults.standard.string(forKey: customNameKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !customName.isEmpty {
            return customName
        }

        if let pet = PetMaster.all.first(where: { $0.id == petID }) {
            let trimmed = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed != "*" {
                return trimmed
            }
        }

        return "ぬくもりペット"
    }

    var liveActivityPetImageName: String {
        let baseName = PetMaster.assetName(for: normalizedCurrentPetID)
        return hasToiletFlag ? "\(baseName)_wc" : baseName
    }

    var liveActivityWallpaperAssetName: String {
        let selected = UserDefaults.standard.string(forKey: WallpaperCatalog.selectedHomeWallpaperAssetNameKey)
        let trimmed = selected?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? WallpaperCatalog.defaultWallpaper.assetName : trimmed
    }

    @available(iOS 16.1, *)
    func makeLiveActivityContentState(
        now: Date = Date(),
        showsLockScreenCard: Bool = true,
        showsDynamicIslandContent: Bool = true
    ) -> MeMoCareActivityAttributes.ContentState {
        ensureDailyResetIfNeeded(now: now)
        resetHappinessPettingIfNeeded(now: now)

        let currentFullness = applySatisfactionDecayIfNeeded(now: now)

        return MeMoCareActivityAttributes.ContentState(
            petName: liveActivityPetName,
            petImageName: liveActivityPetImageName,
            wallpaperAssetName: liveActivityWallpaperAssetName,
            todaySteps: widgetTodaySteps,
            dailyStepGoal: AppState.fixedDailyStepGoal,
            fullnessLevel: currentFullness,
            fullnessMaxLevel: AppState.fullnessMaxLevel,
            happinessLevel: happinessLevel,
            happinessPoint: happinessPoint,
            happinessMaxPoint: AppState.happinessMaxPointsPerLevel,
            walletSteps: walletSteps,
            tenGachaCost: AppState.liveActivityTenGachaCost,
            dayKey: AppState.makeDayKey(now),
            showsLockScreenCard: showsLockScreenCard,
            showsDynamicIslandContent: showsDynamicIslandContent,
            updatedAt: now
        )
    }
}
