import Foundation

enum HalloweenRunMechanicsTests {
    struct SeededRandom: RandomNumberGenerator {
        var state: UInt64 = 20261002
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    static func run() -> Int {
        var count = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message)
            count += 1
        }
        var difficulty = HalloweenRunDifficulty()
        check(difficulty.level == 1 && difficulty.canSpawn, "every runtime starts at Lv1")
        for target in 2...5 {
            let boundary = Halloween2026Configuration.levelDistances[target - 1]
            difficulty.advance(distance: boundary - 1, objectsAreEmpty: false, seconds: 1)
            check(difficulty.level == target - 1 && difficulty.canSpawn, "level boundary below")
            difficulty.advance(distance: boundary, objectsAreEmpty: false, seconds: 0.05)
            check(difficulty.phase == .draining(target: target) && !difficulty.canSpawn, "boundary stops spawning")
            for _ in 0..<100 { difficulty.advance(distance: boundary + 30, objectsAreEmpty: false, seconds: 0.05) }
            check(difficulty.level == target - 1 && !difficulty.canSpawn, "existing objects drain without timeout/removal")
            difficulty.advance(distance: boundary + 30, objectsAreEmpty: true, seconds: 0.05)
            check(difficulty.level == target && difficulty.speedFraction == 0 && !difficulty.canSpawn, "empty field starts full safe interval")
            difficulty.advance(distance: boundary + 32, objectsAreEmpty: true, seconds: 0.3)
            check(abs(difficulty.speedFraction - 0.5) < 0.0001, "speed interpolates over0.6s")
            difficulty.advance(distance: boundary + 34, objectsAreEmpty: true, seconds: 0.3)
            check(difficulty.speedFraction == 1 && !difficulty.canSpawn, "speed completes before spawn resumes")
            difficulty.advance(distance: boundary + 46, objectsAreEmpty: true, seconds: 1.399)
            check(!difficulty.canSpawn, "full2s safety required")
            let resumed = difficulty.advance(distance: boundary + 46, objectsAreEmpty: true, seconds: 0.0011)
            check(resumed && difficulty.canSpawn && difficulty.level == target, "one spawn-clock reset event after safety")
            check(!difficulty.advance(distance: boundary + 46, objectsAreEmpty: true, seconds: 0.01), "resume notification is not repeated")
        }
        difficulty.advance(distance: Int.max, objectsAreEmpty: true, seconds: 99)
        check(difficulty.level == 5 && difficulty.canSpawn, "Lv5 remains stable")
        check(HalloweenRunDifficulty().level == 1, "next run resets level")

        var random = SeededRandom()
        for level in 1...5 {
            var planner = HalloweenObstaclePlanner()
            let speed = Halloween2026Configuration.scrollSpeeds[level - 1]
            let interval = Halloween2026Configuration.obstacleIntervals[level - 1]
            var laneCounts = [0, 0, 0]
            var doubles = 0
            for _ in 0..<10_000 {
                let previousSafe = planner.safeLane
                let blocked = planner.nextRow(level: level, scrollSpeed: speed, collisionBandHeight: 110, using: &random)
                check((1...2).contains(blocked.count), "never blocks all three lanes")
                check(!blocked.contains(planner.safeLane), "selected route remains open")
                let required = Double(abs(previousSafe - planner.safeLane)) * Halloween2026Configuration.laneMoveDuration + Halloween2026Configuration.laneDecisionMargin
                let available = HalloweenObstaclePlanner.movementWindow(interval: interval, scrollSpeed: speed, collisionBandHeight: 110)
                check(required <= available, "route between collision bands is reachable")
                for lane in blocked { laneCounts[lane] += 1 }
                if blocked.count == 2 { doubles += 1 }
            }
            for value in laneCounts {
                let fraction = Double(value) / Double(laneCounts.reduce(0, +))
                check(abs(fraction - 1.0 / 3.0) < 0.03, "all lanes, including center, have fair candidates")
            }
            check(abs(Double(doubles) / 10_000 - Halloween2026Configuration.doubleObstacleProbabilities[level - 1]) < 0.02, "configured double-row probability")
            for forbidden: Set<Int> in [[], [0], [1], [2], [0, 1], [0, 2], [1, 2], [0, 1, 2]] {
                for _ in 0..<100 {
                    let blocked = planner.nextRow(level: level, scrollSpeed: speed, collisionBandHeight: 110, candyLanes: forbidden, using: &random)
                    check(forbidden.isDisjoint(with: blocked), "row never overlaps reserved candy lanes")
                    check(blocked.count < 3, "crowded candy area delays row rather than blocking all lanes")
                }
            }
            for height in [480.0, 667, 874, 1024] {
                let playerY = height * 0.18
                let adjusted = Halloween2026Configuration.scrollSpeed(forLevel: level, sceneHeight: height, playerY: playerY, collisionHalfHeight: 55)
                check(adjusted <= speed, "small screen speed only reduces")
                check((height - Halloween2026Configuration.gameplayHeaderClearance - playerY - 55) / adjusted >= 0.9999, "visible reaction time >=1s")
            }
            let separation = Halloween2026Configuration.candyObstacleSeparation(scrollSpeed: speed)
            check((separation - 98) / speed >= 2 * Halloween2026Configuration.laneMoveDuration + Halloween2026Configuration.laneDecisionMargin - 0.0001, "candy safety permits two-lane movement")
        }
        return count
    }
}
