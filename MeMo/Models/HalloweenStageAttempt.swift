import Foundation

/// Runtime only. Confirmed progress remains owned by Halloween2026EventStore.
struct HalloweenStageAttempt {
    let number: Int
    private(set) var elapsed: TimeInterval = 0
    private(set) var collectedCandy = 0
    private(set) var hasFailed = false

    var mode: HalloweenRunMode { Halloween2026Configuration.isBonusStage(number) ? .bonus : .stage }
    var duration: TimeInterval {
        mode == .bonus ? Halloween2026Configuration.bonusStageDuration : Halloween2026Configuration.normalStageDuration
    }
    var remaining: TimeInterval { max(0, duration - elapsed) }
    var isCleared: Bool { !hasFailed && remaining == 0 }
    var isFinished: Bool { hasFailed || isCleared }
    var confirmedCandy: Int {
        guard isCleared else { return 0 }
        return mode == .bonus ? collectedCandy : Halloween2026Configuration.normalStageCandyReward
    }

    mutating func advance(by seconds: TimeInterval) {
        guard !isFinished, seconds.isFinite else { return }
        elapsed = min(duration, elapsed + max(0, seconds))
    }

    mutating func collide() {
        guard !isFinished, mode == .stage else { return }
        hasFailed = true
    }

    mutating func collectCandy() {
        guard !isFinished, mode == .bonus else { return }
        collectedCandy = min(Halloween2026Configuration.bonusCandyLimit, collectedCandy + 1)
    }
}
