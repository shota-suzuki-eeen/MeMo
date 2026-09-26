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

        if let customName = MeMoLiveActivityPetNameStore.nickname(for: petID) {
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

    func liveActivityHasToiletFlag(now: Date = Date()) -> Bool {
        if toiletFlagAt != nil { return true }
        if let toiletNextSpawnAt, toiletNextSpawnAt <= now { return true }
        return false
    }

    func liveActivityEffectiveToiletFlagAt(now: Date = Date()) -> Date? {
        if let toiletFlagAt { return toiletFlagAt }
        if let toiletNextSpawnAt, toiletNextSpawnAt <= now { return toiletNextSpawnAt }
        return nil
    }

    func liveActivityPetImageName(now: Date = Date()) -> String {
        let baseName = PetMaster.assetName(for: normalizedCurrentPetID)
        return liveActivityHasToiletFlag(now: now) ? "\(baseName)_wc" : baseName
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

        let fullnessLevelForLiveActivity = min(max(0, satisfactionLevel), AppState.fullnessMaxLevel)
        let fullnessSchedule = liveActivityFullnessSchedule(now: now, savedFullnessLevel: fullnessLevelForLiveActivity)

        return MeMoCareActivityAttributes.ContentState(
            petName: liveActivityPetName,
            petImageName: liveActivityPetImageName(now: now),
            wallpaperAssetName: liveActivityWallpaperAssetName,
            todaySteps: widgetTodaySteps,
            dailyStepGoal: AppState.fixedDailyStepGoal,
            fullnessLevel: fullnessLevelForLiveActivity,
            fullnessMaxLevel: AppState.fullnessMaxLevel,
            fullnessLastUpdatedAt: satisfactionLastUpdatedAt,
            fullnessDecayUnitSeconds: AppState.fullnessDecayUnitSeconds,
            fullnessNextDecayAt: fullnessSchedule.nextDecayAt,
            fullnessZeroAt: fullnessSchedule.zeroAt,
            happinessLevel: happinessLevel,
            happinessPoint: happinessPoint,
            happinessMaxPoint: AppState.happinessMaxPointsPerLevel,
            walletSteps: walletSteps,
            tenGachaCost: AppState.liveActivityTenGachaCost,
            toiletFlagAt: liveActivityEffectiveToiletFlagAt(now: now),
            toiletNextSpawnAt: toiletNextSpawnAt,
            dayKey: AppState.makeDayKey(now),
            showsLockScreenCard: showsLockScreenCard,
            showsDynamicIslandContent: showsDynamicIslandContent,
            updatedAt: now
        )
    }

    private func liveActivityFullnessSchedule(
        now: Date,
        savedFullnessLevel: Int
    ) -> (nextDecayAt: Date?, zeroAt: Date?) {
        guard savedFullnessLevel > 0 else {
            return (nil, nil)
        }

        let unitSeconds = max(1, AppState.fullnessDecayUnitSeconds)
        let baseDate = satisfactionLastUpdatedAt ?? now
        let zeroAt = baseDate.addingTimeInterval(Double(savedFullnessLevel) * unitSeconds)

        guard zeroAt > now else {
            return (nil, zeroAt)
        }

        let elapsed = max(0, now.timeIntervalSince(baseDate))
        let completedDecayUnits = max(0, Int(floor(elapsed / unitSeconds)))
        let nextDecayAt = baseDate.addingTimeInterval(Double(completedDecayUnits + 1) * unitSeconds)

        return (min(nextDecayAt, zeroAt), zeroAt)
    }
}

private enum MeMoLiveActivityPetNameStore {
    private static let storageKey = "memo.zukan.customPetNames.v1"
    private static let maxNicknameLength = 12
    private static let blockedCharacterSet = CharacterSet(charactersIn: "<>[]{}\\/")

    static func nickname(for petID: String) -> String? {
        let normalizedPetID = petID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedPetID.isEmpty == false else { return nil }
        guard PetMaster.all.contains(where: { $0.id == normalizedPetID }) else { return nil }

        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data),
              let rawName = decoded[normalizedPetID] else {
            return nil
        }

        return validatedNickname(from: rawName)
    }

    private static func validatedNickname(from input: String) -> String? {
        let normalized = input
            .replacingOccurrences(of: "　", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping

        guard normalized.isEmpty == false else { return nil }
        guard normalized.count <= maxNicknameLength else { return nil }

        let containsUnavailableCharacter = normalized.unicodeScalars.contains { scalar in
            CharacterSet.controlCharacters.contains(scalar)
            || CharacterSet.newlines.contains(scalar)
            || blockedCharacterSet.contains(scalar)
        }

        return containsUnavailableCharacter ? nil : normalized
    }
}
