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

        for number in 1...25 {
            var attempt = HalloweenStageAttempt(number: number)
            check(attempt.mode == (number.isMultiple(of: 5) ? .bonus : .stage), "every fifth stage bonus")
            check(Halloween2026Configuration.level(forStage: number) == (number - 1) / 5 + 1, "stage level allocation")
            check(attempt.duration == (number.isMultiple(of: 5) ? 20 : 30), "stage time allocation")
            attempt.collectCandy()
            attempt.advance(by: attempt.duration - 0.001)
            check(!attempt.isCleared && attempt.confirmedCandy == 0, "time, not distance or provisional candy, clears stage")
            attempt.advance(by: 0.01)
            check(attempt.isCleared && attempt.confirmedCandy == (number.isMultiple(of: 5) ? 1 : 50), "actual bonus versus normal reward")
            attempt.collide()
            attempt.advance(by: 99)
            check(attempt.isCleared, "completed runtime result is stable")
        }
        var failed = HalloweenStageAttempt(number: 2)
        failed.advance(by: 29)
        failed.collide()
        failed.advance(by: 100)
        check(failed.hasFailed && !failed.isCleared && failed.confirmedCandy == 0, "collision before time end fails with no reward")
        var bonusAttempt = HalloweenStageAttempt(number: 5)
        for _ in 0..<400 { bonusAttempt.collectCandy() }
        bonusAttempt.collide()
        check(!bonusAttempt.hasFailed && bonusAttempt.collectedCandy == 300 && bonusAttempt.confirmedCandy == 0, "bonus no collision, cap and provisional reward")
        bonusAttempt.advance(by: 20)
        check(bonusAttempt.confirmedCandy == 300, "bonus cap confirmed only at time end")

        let retryDefaults = defaults(["completedStageCount": 3, "candyCount": 150])
        var retryStore = Halloween2026EventStore(defaults: retryDefaults)
        let failureSession = retryStore.beginSession(mode: .stage, at: end.addingTimeInterval(-1))!
        check(retryStore.finalizeSession(id: failureSession.id, distance: 999, candy: 999), "failure finalizes once")
        retryStore = Halloween2026EventStore(defaults: retryDefaults)
        check(retryStore.currentStageNumber == 4 && retryStore.candyCount == 150, "failed stage retains previous progress/rewards after restart")
        let retrySession = retryStore.beginSession(mode: .stage, at: end.addingTimeInterval(-1))!
        check(!retryStore.finalizeSession(id: failureSession.id, distance: 999, candy: 999, clearedStage: true), "stale callback cannot finalize retry")
        retryStore.discardStageSession(id: retrySession.id)
        check(retryStore.candyCount == 150 && retryStore.currentStageNumber == 4, "close unfinished attempt keeps prior rewards")

        let progressDefaults = defaults()
        progressDefaults.set(["field_background"], forKey: WallpaperCatalog.focusUnlockedRewardAssetNamesKey)
        progressDefaults.set("field_background", forKey: WallpaperCatalog.selectedHomeWallpaperAssetNameKey)
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
        check(progress.wallpaperGranted, "completion wallpaper flag")
        check(Set(WallpaperCatalog.ownedWallpapers(defaults: progressDefaults).map(\.assetName)) == ["Home_background", "field_background", "halloween_main"], "event wallpaper extends existing catalog ownership")
        check(progressDefaults.string(forKey: WallpaperCatalog.selectedHomeWallpaperAssetNameKey) == "field_background", "completion never changes current wallpaper")
        progress = Halloween2026EventStore(defaults: progressDefaults)
        check(progress.wallpaperGranted && progressDefaults.stringArray(forKey: WallpaperCatalog.eventUnlockedAssetNamesKey) == ["halloween_main"], "restart retains one wallpaper ownership")
        let interruptedGrant = defaults(["completedStageCount": 25, "candyCount": 1800])
        interruptedGrant.set(["other_event_background"], forKey: WallpaperCatalog.eventUnlockedAssetNamesKey)
        let repaired = Halloween2026EventStore(defaults: interruptedGrant)
        check(repaired.wallpaperGranted && repaired.candyCount == 1800, "interrupted ownership write repaired without another candy reward")
        check(Set(interruptedGrant.stringArray(forKey: WallpaperCatalog.eventUnlockedAssetNamesKey)!) == ["other_event_background", "halloween_main"], "repair preserves other event ownership")
        check(Halloween2026EventStore(defaults: interruptedGrant).candyCount == 1800, "repeat repair idempotent")
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
