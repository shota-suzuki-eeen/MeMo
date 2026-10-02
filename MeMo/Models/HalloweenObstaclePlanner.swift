import Foundation

/// Keeps one reachable route through consecutive collision bands, including center-lane obstacles.
struct HalloweenObstaclePlanner {
    private(set) var safeLane = 1

    static func movementWindow(interval: TimeInterval, scrollSpeed: Double,
                               collisionBandHeight: Double) -> TimeInterval {
        max(0, interval - Halloween2026Configuration.maximumFrameStep
            - collisionBandHeight / max(1, scrollSpeed))
    }

    mutating func nextRow<R: RandomNumberGenerator>(level: Int, scrollSpeed: Double,
        collisionBandHeight: Double, candyLanes: Set<Int> = [], using random: inout R) -> [Int] {
        let index = min(4, max(0, level - 1))
        let interval = Halloween2026Configuration.obstacleIntervals[index]
        let window = Self.movementWindow(interval: interval, scrollSpeed: scrollSpeed,
                                         collisionBandHeight: collisionBandHeight)
        let reachable = (0...2).filter {
            Double(abs($0 - safeLane)) * Halloween2026Configuration.laneMoveDuration
                + Halloween2026Configuration.laneDecisionMargin <= window
        }
        let wantsDouble = Double.random(in: 0..<1, using: &random)
            < Halloween2026Configuration.doubleObstacleProbabilities[index]
        let singles = [[0], [1], [2]]
        let doubles = [[0, 1], [0, 2], [1, 2]]
        func valid(_ candidates: [[Int]]) -> [[Int]] {
            candidates.filter { blocked in
                candyLanes.isDisjoint(with: blocked) && reachable.contains { !blocked.contains($0) }
            }
        }
        var candidates = valid(wantsDouble ? doubles : singles)
        if candidates.isEmpty { candidates = valid(singles) }
        // A crowded candy region can delay a row; never replace safety with an unavoidable row.
        guard let blocked = candidates.randomElement(using: &random),
              let route = reachable.filter({ !blocked.contains($0) }).randomElement(using: &random)
        else { return [] }
        safeLane = route
        return blocked
    }
}
