import Foundation

@main
struct HalloweenEventStoreTests {
    static let key = "memo.event.halloween2026.progress.v1"
    static var assertions = 0
    static var testSuites: [(UserDefaults, String)] = []

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
        assertions += 1
    }

    static func defaults(_ json: [String: Any] = [:]) -> UserDefaults {
        let name = "memo.tests.halloween.\(UUID().uuidString)"
        let result = UserDefaults(suiteName: name)!
        testSuites.append((result, name))
        result.set(try! JSONSerialization.data(withJSONObject: json), forKey: key)
        return result
    }

    static func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    static func main() {
        defer { for (defaults, name) in testSuites { defaults.removePersistentDomain(forName: name) } }
        let old = defaults([
            "eventID": "halloween2026", "bestDistance": 567, "totalDistance": 1234,
            "candyCount": 89, "claimedRewardIDs": ["hs_0250"],
            "exchangedCounts": ["exchange_steps_500": 2], "futureKey": ["anything": true]
        ])
        let legacy = Halloween2026EventStore(defaults: old)
        check(legacy.bestDistance == 567 && legacy.totalDistance == 1234 && legacy.candyCount == 89, "legacy balances")
        check(legacy.claimedRewardIDs == ["hs_0250"] && legacy.exchangeCount(for: "exchange_steps_500") == 2, "legacy claims/exchanges")
        check(legacy.completedStageCount == 0 && !legacy.endlessUnlocked, "new progress defaults")
        legacy.addCandy(1)
        let reloaded = Halloween2026EventStore(defaults: old)
        check(reloaded.candyCount == 90 && reloaded.totalDistance == 1234, "old/new round trip")
        check(Halloween2026EventStore(defaults: defaults()).candyCount == 0, "all missing keys")

        let badNumbers = Halloween2026EventStore(defaults: defaults([
            "bestDistance": -1, "totalDistance": -4, "candyCount": -3,
            "exchangedCounts": ["legacy": -9], "completedStageCount": -1,
            "gachaDrawProgress": -5, "gachaTotalDraws": -7, "srDailyCounts": ["yakiniku": -2]
        ]))
        check(badNumbers.bestDistance == 0 && badNumbers.totalDistance == 0 && badNumbers.candyCount == 0, "negative balances")
        check(badNumbers.completedStageCount == 0 && badNumbers.gachaDrawProgress == 0, "negative progress")
        check(badNumbers.exchangeCount(for: "legacy") == 0 && badNumbers.srDailyCounts["yakiniku"] == 0, "negative counters")
        let huge = Halloween2026EventStore(defaults: defaults(["candyCount": Int.max, "totalDistance": Int.max]))
        huge.recordRun(distance: Int.max, candy: Int.max)
        check(huge.candyCount == Int.max && huge.totalDistance == Int.max, "overflow saturates")
        check(!huge.spendCandy(0) && !huge.spendCandy(-1), "invalid spending")

        let period = EventManager.halloween2026
        let start = date("2026-09-02T15:00:00Z")
        let end = date("2026-10-31T15:00:00Z")
        let rewardEnd = date("2026-11-07T15:00:00Z")
        check(!period.isActive(at: start.addingTimeInterval(-1)) && period.isActive(at: start), "start boundary")
        check(period.isActive(at: end.addingTimeInterval(-1)) && !period.isActive(at: end), "game boundary")
        check(period.areRewardsAvailable(at: end) && period.areRewardsAvailable(at: rewardEnd.addingTimeInterval(-1)), "grace period")
        check(!period.areRewardsAvailable(at: rewardEnd) && period.hasEnded(at: end), "final boundary")
        check(period.canFinishRun(startedAt: end.addingTimeInterval(-1)), "admitted play may finish")
        check(!period.canFinishRun(startedAt: end), "late play not admitted")
        check(Halloween2026Configuration.tokyoDayKey(at: end.addingTimeInterval(-1)) == "2026-10-31", "JST day before midnight")
        check(Halloween2026Configuration.tokyoDayKey(at: end) == "2026-11-01", "JST midnight")

        let progressDefaults = defaults()
        var progress = Halloween2026EventStore(defaults: progressDefaults)
        let playDate = end.addingTimeInterval(-1)
        check(progress.beginSession(mode: .endless, at: playDate) == nil, "endless locked")
        check(progress.beginSession(mode: .bonus, at: playDate) == nil, "wrong stage mode rejected")
        check(progress.beginSession(mode: .stage, at: end) == nil, "no late start")
        let interrupted = progress.beginSession(mode: .stage, at: playDate)!
        progress.checkpointSession(id: interrupted.id, distance: 80, candy: 100)
        progress = Halloween2026EventStore(defaults: progressDefaults)
        check(progress.activeSession?.distance == 80 && progress.activeSession?.candyCount == 0, "stage checkpoint preserves mode")
        progress.discardStageSession(id: interrupted.id)
        check(progress.completedStageCount == 0 && progress.candyCount == 0, "unfinished stage gives no reward")

        for number in 1...25 {
            let bonus = number.isMultiple(of: 5)
            let session = progress.beginSession(mode: bonus ? .bonus : .stage, at: playDate)!
            progress.checkpointSession(id: session.id, distance: 300, candy: 500)
            progress = Halloween2026EventStore(defaults: progressDefaults)
            check(progress.finalizeSession(id: session.id, distance: 300, candy: 500, clearedStage: true), "persisted session finalizes")
            check(!progress.finalizeSession(id: session.id, distance: 300, candy: 500, clearedStage: true), "duplicate finalization rejected")
            check(progress.completedStageCount == number, "stage progress")
        }
        check(progress.candyCount == 2500 && progress.endlessUnlocked, "25 stage maximum and endless unlock")
        check(progress.bestDistance == 0 && progress.totalDistance == 0, "stage distances not endless records")
        check(progress.beginSession(mode: .stage, at: playDate) == nil, "completed stages locked")
        let endless = progress.beginSession(mode: .endless, at: playDate)!
        progress.checkpointSession(id: endless.id, distance: 321, candy: 42)
        progress = Halloween2026EventStore(defaults: progressDefaults)
        check(progress.finalizeSession(id: endless.id, distance: 322, candy: 43), "endless result")
        check(progress.bestDistance == 322 && progress.totalDistance == 322 && progress.candyCount == 2543, "endless adds once")
        progress = Halloween2026EventStore(defaults: progressDefaults)
        check(!progress.finalizeSession(id: endless.id, distance: 322, candy: 43), "relaunch duplicate rejected")
        check(progress.candyCount == 2543 && progress.finalizedSessionIDs.count == 26, "finalized IDs survive relaunch")
        check(!progress.spendCandy(2544), "insufficient balance")

        let newState = Halloween2026EventStore(defaults: defaults([
            "gachaDrawProgress": 151, "gachaTotalDraws": 151, "srDayKey": "2026-10-02",
            "srDailyCounts": ["gachaTicket_nomal": 8], "eventAdDayKey": "2026-10-02",
            "usedEventAdSlots": ["morning"], "wallpaperGranted": true
        ]))
        newState.addCandy(1)
        check(newState.gachaDrawProgress == 1 && newState.gachaTotalDraws == 151, "gacha counters independent")
        check(newState.srDailyCounts["gachaTicket_nomal"] == 8 && newState.usedEventAdSlots == ["morning"] && newState.wallpaperGranted, "new state round trip")
        print("PASS: \(assertions) Halloween persistence, session, boundary and tuning assertions")
    }
}
