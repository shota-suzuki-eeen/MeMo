import Foundation

/// Runtime transition authority. Distance and objects continue to move while spawning is stopped.
struct HalloweenRunDifficulty {
    enum Phase: Equatable {
        case running
        case draining(target: Int)
        case safe(previous: Int, elapsed: TimeInterval)
    }

    private(set) var level = 1
    private(set) var phase: Phase = .running
    var canSpawn: Bool { phase == .running }
    var speedFraction: Double {
        guard case let .safe(_, elapsed) = phase else { return 1 }
        return min(1, elapsed / Halloween2026Configuration.speedTransitionDuration)
    }
    var previousSpeedLevel: Int {
        guard case let .safe(previous, _) = phase else { return level }
        return previous
    }

    /// Returns true only when a full2s safe interval has ended; callers reset spawn clocks then.
    @discardableResult
    mutating func advance(distance: Int, objectsAreEmpty: Bool, seconds: TimeInterval) -> Bool {
        switch phase {
        case .running:
            if level < Halloween2026Configuration.maximumLevel,
               distance >= Halloween2026Configuration.levelDistances[level] {
                phase = .draining(target: level + 1)
            }
        case let .draining(target):
            if objectsAreEmpty {
                let previous = level
                level = target
                phase = .safe(previous: previous, elapsed: 0)
            }
        case let .safe(previous, elapsed):
            let nextElapsed = elapsed + (seconds.isFinite ? max(0, seconds) : 0)
            if nextElapsed >= Halloween2026Configuration.levelSafetyDuration {
                phase = .running
                return true
            }
            phase = .safe(previous: previous, elapsed: nextElapsed)
        }
        return false
    }
}
