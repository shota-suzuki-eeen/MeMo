import Foundation

@main
enum HappinessCheckpointTests {
    static func main() throws {
        var assertions = 0
        func check(_ result: Bool, _ message: String) {
            assertions += 1
            guard result else { fatalError(message) }
        }
        let defaults = UserDefaults.standard
        let levelKey = "memo.happiness.level"
        let pointKey = "memo.happiness.point"
        let checkpointKey = "memo.happiness.reachedCheckpointLevel.v1"
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("happiness-test.plist")
        func seed(_ level: Int?, _ point: Int = 0, checkpoint: Int? = nil, context: String = "") -> AppState {
            defaults.values = [:]
            defaults.set(level, forKey: levelKey + context)
            defaults.set(point, forKey: pointKey + context)
            defaults.set(checkpoint, forKey: checkpointKey + context)
            defaults.set(Data("preserved".utf8), forKey: "qa.unrelated.data")
            return AppState()
        }

        for level in 0...75 {
            let state = seed(level, 73)
            let expected = level / 5 * 5
            check(state.happinessCheckpointLevel == expected, "legacy floor at every level")
            check(state.happinessLevel == level && state.happinessPoint == 73, "legacy progress preserved")
            check(defaults.integer(forKey: checkpointKey) == expected, "additive checkpoint stored")
            check(state.walletSteps == 12345 && defaults.data(forKey: "qa.unrelated.data") == Data("preserved".utf8), "unrelated state preserved")
            check(defaults.object(forKey: "memo.gacha.specialItemCounts") == nil, "reading does not grant rewards")
        }

        var state = seed(nil)
        defaults.set(try JSONEncoder().encode([75]), forKey: "memo.happiness.standardRewardV2.claimedLevels")
        check(state.happinessLevel == 0 && state.happinessCheckpointLevel == 0, "missing keys do not infer an old peak from rewards")
        check(!state.consumeOneHappinessDecayStep(now: now), "new user stays Lv0")

        for level in [4, 9, 14, 39, 74] {
            state = seed(level, 99)
            let gain = state.addHappinessPoints(1, now: now)
            check(gain.gainedPoints == 1 && state.happinessLevel == level + 1 && state.happinessPoint == 0, "exact level threshold gain")
            check(state.happinessCheckpointLevel == level + 1, "new checkpoint records immediately")
            check(!state.consumeOneHappinessDecayStep(now: now), "threshold never rolls back to previous level/99")
            _ = state.addHappinessPoints(5, now: now)
            state.happinessLastDecayAt = now.addingTimeInterval(-1e100)
            check(state.pendingHappinessDecayCount(fullnessLevel: 0, now: now) == 5, "decay bounded by units above new checkpoint")
            for _ in 0..<5 { check(state.consumeOneHappinessDecayStep(now: now), "points above checkpoint can decay") }
            check(state.happinessLevel == level + 1 && state.happinessPoint == 0, "new checkpoint retained after decay")
        }

        state = seed(17, 37)
        state.happinessLastDecayAt = now.addingTimeInterval(-1e100)
        check(state.pendingHappinessDecayCount(fullnessLevel: 0, now: now) == 237, "Lv17.37 can lose exactly 237 units to Lv15")
        for _ in 0..<237 {
            check(state.consumeOneHappinessDecayStep(now: now), "valid decay step")
            check(state.happinessLevel >= 15 && state.happinessCheckpointLevel == 15, "never cross attained lower bound")
        }
        check(state.happinessLevel == 15 && state.happinessPoint == 0, "Lv17 settles at Lv15")
        check(!state.consumeOneHappinessDecayStep(now: now), "no extra step below checkpoint")
        try defaults.roundTrip(at: snapshot)
        state = AppState()
        check(state.happinessLevel == 15 && state.happinessCheckpointLevel == 15, "checkpoint survives serialized reload")
        _ = state.addHappinessPoints(1000, now: now)
        check(state.happinessLevel == 25 && state.happinessCheckpointLevel == 25, "checkpoint advances across several levels")
        state.happinessLevel = 12
        check(state.happinessLevel == 25 && state.happinessPoint == 0, "setter cannot lower reached checkpoint")
        defaults.set(2, forKey: levelKey)
        defaults.set(99, forKey: pointKey)
        check(state.happinessLevel == 25 && state.happinessPoint == 0, "interrupted old writes repaired to exact floor on load")
        check(defaults.object(forKey: "memo.gacha.specialItemCounts") == nil, "load repair does not compensate or grant")

        for (level, point, floor, count) in [(4, 99, 0, 499), (40, 25, 40, 25), (75, 99, 75, 99)] {
            state = seed(level, point)
            state.happinessLastDecayAt = now.addingTimeInterval(-1e100)
            check(state.pendingHappinessDecayCount(fullnessLevel: 0, now: now) == count, "pre-5, exact-40 and max-level pending bounds")
            for _ in 0..<count { check(state.consumeOneHappinessDecayStep(now: now), "bounded decay at zero and max") }
            check(state.happinessLevel == floor && state.happinessPoint == 0, "zero/exact40/max75 floors")
        }
        state = seed(75, 98)
        check(state.addHappinessPoints(Int.max, now: now).gainedPoints == 1 && state.happinessPoint == 99, "existing Lv75/99 cap retained for huge gain")

        for interval in [299.999, 300, 599.999, 600, 1e100, Double.infinity] {
            state = seed(17, 2)
            state.happinessLastDecayAt = now.addingTimeInterval(-interval)
            let expected = interval < 300 ? 0 : interval < 600 ? 1 : interval < 1e100 ? 2 : 202
            check(state.pendingHappinessDecayCount(fullnessLevel: 0, now: now) == expected, "finite and infinite elapsed bounded before integer conversion")
        }
        state = seed(17, 2)
        state.happinessLastDecayAt = Date(timeIntervalSince1970: .nan)
        check(state.pendingHappinessDecayCount(fullnessLevel: 0, now: now) == 0, "NaN date does not trap")
        state.happinessLastDecayAt = now.addingTimeInterval(600)
        check(state.pendingHappinessDecayCount(fullnessLevel: 0, now: now) == 0, "future anchor does not decay")
        state.happinessLastDecayAt = nil
        state.refreshHappinessDecayTracking(fullnessLevel: 0, now: now)
        check(state.happinessLastDecayAt == now && state.pendingHappinessDecayCount(fullnessLevel: 0, now: now) == 0, "missing anchor initializes safely")
        state.happinessLastDecayAt = now.addingTimeInterval(-10000)
        state.refreshHappinessDecayTracking(fullnessLevel: 1, now: now)
        check(state.happinessPoint == 2 && state.happinessLastDecayAt == now, "fullness preserves progress and tracking")
        check(state.pendingHappinessDecayCount(fullnessLevel: 1, now: now.addingTimeInterval(10000)) == 0, "fullness suppresses decay")
        _ = state.activateHappinessSleepMode(now: now, duration: 600)
        check(state.pendingHappinessDecayCount(fullnessLevel: 0, now: now.addingTimeInterval(60)) == 0, "sleep suppresses pending decay")
        check(!state.consumeOneHappinessDecayStep(now: now.addingTimeInterval(60)), "sleep suppresses consumption")
        check(state.pendingHappinessDecayCount(fullnessLevel: 0, now: now.addingTimeInterval(900)) == 1, "sleep end retains existing anchor semantics")

        state = seed(15)
        state.happinessLastDecayAt = now.addingTimeInterval(-1e100)
        check(state.pendingHappinessDecayCount(fullnessLevel: 0, now: now) == 0 && state.happinessLastDecayAt == now, "discard old elapsed backlog at floor")
        _ = state.addHappinessPoints(10, now: now)
        check(state.pendingHappinessDecayCount(fullnessLevel: 0, now: now.addingTimeInterval(299)) == 0, "new gain not erased by old backlog")
        check(state.pendingHappinessDecayCount(fullnessLevel: 0, now: now.addingTimeInterval(300)) == 1, "new gain decays after its next interval")

        state = seed(12, 10)
        check(state.happinessCheckpointLevel == 10, "standard floor initialized")
        for (index, petID) in PetMaster.happinessRewardPetIDs.enumerated() {
            let suffix = "." + petID
            defaults.set(7 + index, forKey: levelKey + suffix)
            defaults.set(20 + index, forKey: pointKey + suffix)
            state.currentPetID = petID
            let expected = (7 + index) / 5 * 5
            check(state.happinessCheckpointLevel == expected && state.happinessPoint == 20 + index, "reward context independent")
            state.currentPetID = PetMaster.happinessRewardCasualPetIDs[index]
            check(state.happinessCheckpointLevel == expected && state.happinessLevel == 7 + index, "casual shares existing reward owner")
            check(defaults.object(forKey: checkpointKey + "." + state.currentPetID) == nil, "no separate casual checkpoint")
        }
        state.currentPetID = "pet_002"
        check(state.happinessLevel == 12 && state.happinessCheckpointLevel == 10, "normal pets retain shared standard progress")
        try defaults.roundTrip(at: snapshot)
        check(AppState().happinessCheckpointLevel == 10, "context keys survive serialization")

        state = seed(4, 99)
        let legacyClaims = try JSONEncoder().encode([5, 10, 40])
        defaults.set(legacyClaims, forKey: "memo.happiness.claimedRewardLevels")
        _ = state.addHappinessPoints(1, now: now)
        check(state.gachaSpecialItemCount(id: "gachaTicket_nomal") == 0, "reaching checkpoint grants nothing automatically")
        check(state.claimHappinessReward(level: 5, now: now) != nil, "existing claim still grants reward")
        check(state.gachaSpecialItemCount(id: "gachaTicket_nomal") == 10, "normal ticket reward count preserved")
        check(state.claimHappinessReward(level: 5, now: now) == nil, "repeated claim rejected")
        defaults.set(4, forKey: levelKey)
        check(state.happinessLevel == 5, "claim retained across lower-bound load repair")
        try defaults.roundTrip(at: snapshot)
        state = AppState()
        check(state.claimHappinessReward(level: 5, now: now) == nil && state.gachaSpecialItemCount(id: "gachaTicket_nomal") == 10, "reload/re-attainment never duplicates ticket")
        check(defaults.data(forKey: "memo.happiness.claimedRewardLevels") == legacyClaims, "legacy claim data not reset")
        state.happinessLevel = 10
        check(state.claimHappinessReward(level: 10, now: now) != nil && state.gachaSpecialItemCount(id: "gachaTicket_special") == 1, "special ticket reward intact")
        check(state.claimHappinessReward(level: 10, now: now) == nil, "special ticket no duplicate")
        state.happinessLevel = 15
        check(state.claimHappinessReward(level: 15, now: now) != nil && state.gachaIsMachineUnlocked(id: "food"), "machine reward intact")
        check(state.claimHappinessReward(level: 15, now: now) == nil, "machine claim no duplicate")

        state = seed(10, context: ".reward_000")
        state.currentPetID = "reward_000"
        check(state.claimHappinessReward(level: 10, now: now) != nil, "reward-pet casual claim intact")
        check(state.ownedPetIDs().filter { $0 == "reward_000_casual" }.count == 1, "casual added once")
        state.currentPetID = "reward_000_casual"
        check(state.claimHappinessReward(level: 10, now: now) == nil, "casual shares claim and checkpoint context")

        for (level, point, savedFloor, expectedFloor) in [(12, 10, -1, 10), (12, 10, 13, 10), (12, 10, 40, 40), (Int.max, Int.max, Int.max, 75)] {
            state = seed(level, point, checkpoint: savedFloor)
            check(state.happinessCheckpointLevel == expectedFloor, "invalid and interrupted persisted values safely normalized")
            check(state.happinessLevel <= 75 && state.happinessPoint <= 99, "old caps remain valid")
        }
        print("PASS: \(assertions) happiness checkpoint/legacy/context/decay/reload/reward assertions (production owner and gacha ledger)")
    }
}
