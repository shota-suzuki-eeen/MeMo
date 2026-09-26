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
        var fullnessLastUpdatedAt: Date?
        var fullnessDecayUnitSeconds: TimeInterval
        var fullnessNextDecayAt: Date?
        var fullnessZeroAt: Date?
        var happinessLevel: Int
        var happinessPoint: Int
        var happinessMaxPoint: Int
        var walletSteps: Int
        var tenGachaCost: Int
        var toiletFlagAt: Date?
        var toiletNextSpawnAt: Date?
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
        var clampedFullnessDecayUnitSeconds: TimeInterval { max(1, fullnessDecayUnitSeconds) }

        var stepProgress: Double {
            min(1, Double(clampedTodaySteps) / Double(clampedDailyStepGoal))
        }

        /// 保存値そのものを 5 段階メーターとして見る場合の進捗。
        /// Live Activity の表示では、原則 `estimatedFullnessProgress(now:)` または
        /// `fullnessZeroProgress(now:)` を使う。
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

        /// `fullnessLevel` はアプリ側の保存値をそのまま保持する。
        /// Live Activity / Widget 側では、保存時刻と decay schedule から現在表示用の満腹度を推定する。
        func estimatedFullnessLevel(now: Date = Date()) -> Int {
            let baseLevel = clampedFullnessLevel
            guard baseLevel > 0 else { return 0 }

            if let fullnessZeroAt, fullnessZeroAt <= now {
                return 0
            }

            if let fullnessNextDecayAt {
                guard fullnessNextDecayAt <= now else { return baseLevel }

                let elapsedAfterNextDecay = max(0, now.timeIntervalSince(fullnessNextDecayAt))
                let additionalDecayCount = Int(floor(elapsedAfterNextDecay / clampedFullnessDecayUnitSeconds))
                let totalDecayCount = 1 + additionalDecayCount
                return min(max(0, baseLevel - totalDecayCount), clampedFullnessMaxLevel)
            }

            guard let fullnessLastUpdatedAt else { return baseLevel }

            let elapsed = max(0, now.timeIntervalSince(fullnessLastUpdatedAt))
            let decayCount = Int(floor(elapsed / clampedFullnessDecayUnitSeconds))
            return min(max(0, baseLevel - decayCount), clampedFullnessMaxLevel)
        }

        func estimatedFullnessProgress(now: Date = Date()) -> Double {
            Double(estimatedFullnessLevel(now: now)) / Double(clampedFullnessMaxLevel)
        }

        /// 満腹度が 0 になるまでの「時間ベース」進捗。
        /// 5 段階の残量ではなく、保存時刻から 0 到達時刻までの残り時間を 0...1 で返す。
        func fullnessZeroProgress(now: Date = Date()) -> Double {
            guard estimatedFullnessLevel(now: now) > 0 else { return 0 }
            guard let fullnessZeroAt else { return estimatedFullnessProgress(now: now) }

            let start = fullnessProgressStartDate(now: now)
            let total = max(1, fullnessZeroAt.timeIntervalSince(start))
            let remaining = max(0, fullnessZeroAt.timeIntervalSince(now))
            return min(1, max(0, remaining / total))
        }

        func fullnessZeroRemainingSeconds(now: Date = Date()) -> TimeInterval {
            guard estimatedFullnessLevel(now: now) > 0 else { return 0 }
            guard let fullnessZeroAt else { return 0 }
            return max(0, fullnessZeroAt.timeIntervalSince(now))
        }

        func fullnessZeroRemainingText(now: Date = Date()) -> String {
            let seconds = Int(ceil(fullnessZeroRemainingSeconds(now: now)))
            let hours = seconds / 3_600
            let minutes = (seconds % 3_600) / 60
            let remainingSeconds = seconds % 60
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }

        func fullnessZeroDateInterval(now: Date = Date()) -> DateInterval? {
            guard estimatedFullnessLevel(now: now) > 0 else { return nil }
            guard let fullnessZeroAt, fullnessZeroAt > now else { return nil }

            let start = fullnessProgressStartDate(now: now)
            guard start < fullnessZeroAt else { return nil }

            return DateInterval(start: start, end: fullnessZeroAt)
        }

        private func fullnessProgressStartDate(now: Date = Date()) -> Date {
            let rawStart = fullnessLastUpdatedAt ?? updatedAt
            if rawStart > now { return now }
            return rawStart
        }

        func isToiletActive(now: Date = Date()) -> Bool {
            if toiletFlagAt != nil { return true }
            if let toiletNextSpawnAt, toiletNextSpawnAt <= now { return true }
            return false
        }

        func effectiveToiletFlagAt(now: Date = Date()) -> Date? {
            if let toiletFlagAt { return toiletFlagAt }
            if let toiletNextSpawnAt, toiletNextSpawnAt <= now { return toiletNextSpawnAt }
            return nil
        }

        func effectivePetImageName(now: Date = Date()) -> String {
            let baseImageName: String
            if petImageName.hasSuffix("_wc") {
                baseImageName = String(petImageName.dropLast(3))
            } else {
                baseImageName = petImageName
            }

            return isToiletActive(now: now) ? "\(baseImageName)_wc" : baseImageName
        }
    }

    var appDisplayName: String = "ミーモ"
}
