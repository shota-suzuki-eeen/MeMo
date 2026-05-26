//
//  AppState+LimitedHappinessRewardOnboarding.swift
//  MeMo
//
//  First-time onboarding trigger for happiness-level limited character rewards.
//

import Foundation

extension Notification.Name {
    static let memoLimitedHappinessRewardCharacterDidBecomePending = Notification.Name("memo.limitedHappinessRewardCharacter.didBecomePending")
}

extension AppState {
    private enum LimitedHappinessRewardOnboardingStorageKeys {
        static let pending = "memo.onboarding.limitedHappinessRewardCharacter.pending"
        static let completed = "memo.onboarding.limitedHappinessRewardCharacter.completed"
    }

    private var limitedHappinessRewardOnboardingDefaults: UserDefaults { .standard }

    var memoLimitedHappinessRewardCharacterIntroPending: Bool {
        limitedHappinessRewardOnboardingDefaults.bool(
            forKey: LimitedHappinessRewardOnboardingStorageKeys.pending
        )
    }

    var memoLimitedHappinessRewardCharacterIntroCompleted: Bool {
        limitedHappinessRewardOnboardingDefaults.bool(
            forKey: LimitedHappinessRewardOnboardingStorageKeys.completed
        )
    }

    var memoCanPresentLimitedHappinessRewardCharacterIntro: Bool {
        memoMandatoryOnboardingCompleted
        && memoLimitedHappinessRewardCharacterIntroPending
        && memoLimitedHappinessRewardCharacterIntroCompleted == false
    }

    @discardableResult
    func memoMarkLimitedHappinessRewardCharacterClaimedIfNeeded(
        claimedPetID: String? = nil,
        shouldSwitchCurrentPet: Bool = false
    ) -> Bool {
        guard memoMandatoryOnboardingCompleted else { return false }
        guard memoLimitedHappinessRewardCharacterIntroCompleted == false else { return false }
        guard memoLimitedHappinessRewardCharacterIntroPending == false else { return false }

        if shouldSwitchCurrentPet,
           let claimedPetID,
           PetMaster.isHappinessRewardExclusivePetID(claimedPetID),
           PetMaster.all.contains(where: { $0.id == claimedPetID }) {
            currentPetID = claimedPetID
        }

        limitedHappinessRewardOnboardingDefaults.set(
            true,
            forKey: LimitedHappinessRewardOnboardingStorageKeys.pending
        )

        NotificationCenter.default.post(
            name: .memoLimitedHappinessRewardCharacterDidBecomePending,
            object: nil
        )

        return true
    }

    @discardableResult
    func memoMarkLimitedHappinessRewardCharacterOwnedFromRewardListIfNeeded() -> Bool {
        let ownedLimitedRewardPetIDs = ownedPetIDs().filter { petID in
            PetMaster.isHappinessRewardExclusivePetID(petID)
        }
        guard let latestClaimedPetID = ownedLimitedRewardPetIDs.last else { return false }

        return memoMarkLimitedHappinessRewardCharacterClaimedIfNeeded(
            claimedPetID: latestClaimedPetID,
            shouldSwitchCurrentPet: true
        )
    }

    @discardableResult
    func memoConsumeLimitedHappinessRewardCharacterIntroPending() -> Bool {
        guard memoCanPresentLimitedHappinessRewardCharacterIntro else { return false }

        limitedHappinessRewardOnboardingDefaults.set(
            false,
            forKey: LimitedHappinessRewardOnboardingStorageKeys.pending
        )
        limitedHappinessRewardOnboardingDefaults.set(
            true,
            forKey: LimitedHappinessRewardOnboardingStorageKeys.completed
        )

        return true
    }

    func memoClearLimitedHappinessRewardCharacterIntroForDebug() {
        limitedHappinessRewardOnboardingDefaults.removeObject(
            forKey: LimitedHappinessRewardOnboardingStorageKeys.pending
        )
        limitedHappinessRewardOnboardingDefaults.removeObject(
            forKey: LimitedHappinessRewardOnboardingStorageKeys.completed
        )
    }
}
