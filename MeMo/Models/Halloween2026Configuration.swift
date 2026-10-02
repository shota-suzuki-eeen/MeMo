import Foundation

/// Approved initial tuning. Device playtesting may adjust these values.
enum Halloween2026Configuration {
    static let stageCount = 25
    static let maximumLevel = 5
    static let normalStageDuration: TimeInterval = 30
    static let bonusStageDuration: TimeInterval = 20
    static let normalStageCandyReward = 50
    static let bonusCandyLimit = 300
    static let candyCostPerDraw = 50
    static let tenDrawCount = 10
    static let lastOneInterval = 50
    static let rarityWeights = [66, 30, 4]
    static let srWeights = [60, 20, 20]
    static let srDailyLimits = ["gachaTicket_nomal": 10, "yakiniku": 2, "fishingPoints500": 2]
    static let fishingPointsPerReward = 500
    static let levelDistances = [0, 250, 600, 1_050, 1_600]
    static let distanceSpeeds: [Double] = [8, 10, 12, 14, 16]
    static let scrollSpeeds: [Double] = [260, 305, 350, 395, 440]
    static let obstacleIntervals: [TimeInterval] = [1.45, 1.35, 1.25, 1.15, 1.05]
    static let doubleObstacleProbabilities: [Double] = [0, 0.1, 0.2, 0.3, 0.4]
    static let candyIntervals: [TimeInterval] = [1.1, 1.0, 0.9, 0.8, 0.75]
    static let candySpawnProbability = 0.85
    static let candyColumnProbability = 0.4
    static let startSafetyDuration: TimeInterval = 1
    static let levelSafetyDuration: TimeInterval = 2
    static let speedTransitionDuration: TimeInterval = 0.6
    static let resumeCountdownDuration: TimeInterval = 3
    static let runCheckpointInterval: TimeInterval = 1
    static let minimumObstacleReactionTime: TimeInterval = 1
    static let laneMoveDuration: TimeInterval = 0.14
    static let laneDecisionMargin: TimeInterval = 0.2
    static let maximumFrameStep: TimeInterval = 0.05
    static let gameplayHeaderClearance: Double = 130
    static let levelPushDuration: TimeInterval = 0.35
    static let levelReadDuration: TimeInterval = 0.9
    static let levelExitDuration: TimeInterval = 0.25
    static let levelResumeMargin: TimeInterval = 0.5

    static func isBonusStage(_ number: Int) -> Bool {
        (1...stageCount).contains(number) && number.isMultiple(of: 5)
    }

    static func level(forStage number: Int) -> Int {
        min(maximumLevel, max(1, (min(stageCount, max(1, number)) - 1) / 5 + 1))
    }

    static func level(forDistance distance: Int) -> Int {
        levelDistances.filter { max(0, distance) >= $0 }.count
    }

    static func scrollSpeed(forLevel level: Int, sceneHeight: Double, playerY: Double,
                            collisionHalfHeight: Double, headerClearance: Double = gameplayHeaderClearance) -> Double {
        let visibleTravel = max(1, sceneHeight - headerClearance - playerY - collisionHalfHeight)
        return min(scrollSpeeds[min(4, max(0, level - 1))], visibleTravel / minimumObstacleReactionTime)
    }

    static func candyObstacleSeparation(scrollSpeed: Double) -> Double {
        // Obstacle/player band55 + candy/player band43, then time for two moves and a decision.
        98 + max(0, scrollSpeed) * (2 * laneMoveDuration + laneDecisionMargin)
    }

    static func tokyoDayKey(at date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }
}

enum HalloweenRunMode: String, Codable {
    case stage, bonus, endless
}

struct HalloweenRunSession: Codable, Equatable {
    let id: String
    let mode: HalloweenRunMode
    let stageNumber: Int?
    let startedAt: Date
    var distance: Int
    var candyCount: Int
}
