//
//  MeMoCareActivityAttributes.swift
//  MeMo
//
//  Live Activity attributes for the lock-screen care status card.
//  Add this file to BOTH the MeMo app target and the MeMoWidgetExtension target.
//

import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct MeMoCareActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var petName: String
        var petImageName: String
        var wallpaperAssetName: String
        var todaySteps: Int
        var dailyStepGoal: Int
        var fullnessLevel: Int
        var fullnessMaxLevel: Int
        var happinessLevel: Int
        var happinessPoint: Int
        var happinessMaxPoint: Int
        var walletSteps: Int
        var tenGachaCost: Int
        var dayKey: String
        var showsLockScreenCard: Bool
        var showsDynamicIslandContent: Bool
        var updatedAt: Date

        var clampedTodaySteps: Int { max(0, todaySteps) }
        var clampedDailyStepGoal: Int { max(1, dailyStepGoal) }
        var clampedFullnessLevel: Int { min(max(0, fullnessLevel), max(1, fullnessMaxLevel)) }
        var clampedFullnessMaxLevel: Int { max(1, fullnessMaxLevel) }
        var clampedHappinessLevel: Int { max(0, happinessLevel) }
        var clampedHappinessPoint: Int { min(max(0, happinessPoint), max(1, happinessMaxPoint)) }
        var clampedHappinessMaxPoint: Int { max(1, happinessMaxPoint) }
        var clampedWalletSteps: Int { max(0, walletSteps) }
        var clampedTenGachaCost: Int { max(1, tenGachaCost) }

        var stepProgress: Double {
            min(1, Double(clampedTodaySteps) / Double(clampedDailyStepGoal))
        }

        var fullnessProgress: Double {
            Double(clampedFullnessLevel) / Double(clampedFullnessMaxLevel)
        }

        var happinessProgress: Double {
            Double(clampedHappinessPoint) / Double(clampedHappinessMaxPoint)
        }

        var tenGachaCompletedCount: Int {
            clampedWalletSteps / clampedTenGachaCost
        }

        var tenGachaRemainderSteps: Int {
            clampedWalletSteps % clampedTenGachaCost
        }

        var tenGachaProgress: Double {
            Double(tenGachaRemainderSteps) / Double(clampedTenGachaCost)
        }

        var tenGachaRemainingSteps: Int {
            let remainder = tenGachaRemainderSteps
            return remainder == 0 ? clampedTenGachaCost : max(0, clampedTenGachaCost - remainder)
        }
    }

    var appDisplayName: String = "ミーモ"
}
