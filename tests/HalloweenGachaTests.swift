import Foundation

enum HalloweenGachaTests {
    static func run() {
        let check = HalloweenEventStoreTests.check
        let defaults = HalloweenEventStoreTests.defaults
        let date = HalloweenEventStoreTests.date
        let now = date("2026-10-02T03:00:00Z")
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        check(HalloweenGachaCatalog.normalFoodIDs.count == 19 && HalloweenGachaCatalog.rareFoodIDs.count == 8, "event item pools")
        check((HalloweenGachaCatalog.normalFoodIDs + HalloweenGachaCatalog.rareFoodIDs + ["yakiniku"]).allSatisfy { FoodCatalog.byId($0) != nil }, "all event foods resolve")
        check(Set(HalloweenGachaCatalog.characterIDs).count == 25, "25 unique verified last-one characters")
        var rarities: [String: Int] = [:]
        for i in 0..<10_000 {
            var first = true
            let reward = HalloweenGachaCatalog.roll(counts: [:], random: {
                defer { first = false }; return first ? (Double(i) + 0.5) / 10_000 : 0
            })
            rarities[reward.2, default: 0] += 1
            check(reward.0 != .character && reward.3 > 0, "normal roll has a real item and no character")
        }
        check(rarities == ["N": 6600, "R": 3000, "SR": 400], "exact 66/30/4 intervals")
        var sr: [String: Int] = [:]
        for i in 0..<1000 {
            var first = true
            let reward = HalloweenGachaCatalog.roll(counts: [:], random: {
                defer { first = false }; return first ? 0.98 : (Double(i) + 0.5) / 1000
            })
            sr[reward.1, default: 0] += 1
        }
        check(sr == ["gachaTicket_nomal": 600, "yakiniku": 200, "fishingPoints500": 200], "SR weights 3/1/1")
        let fullCaps = Halloween2026Configuration.srDailyLimits
        check(HalloweenGachaCatalog.availableSRIDs(counts: fullCaps).isEmpty, "all SR caps remove SR tier")
        let removed = HalloweenGachaCatalog.roll(counts: ["gachaTicket_nomal": 10, "yakiniku": 2], random: { 0.99 })
        check(removed.0 == .fishingPoints && removed.3 == 500, "remaining SR normalizes to fishing500")
        var nCount = 0
        for i in 0..<9600 {
            var first = true
            let r = HalloweenGachaCatalog.roll(counts: fullCaps, random: {
                defer { first = false }; return first ? (Double(i) + 0.5) / 9600 : 0
            })
            if r.2 == "N" { nCount += 1 }
            check(r.2 != "SR", "exhausted SR never returns")
        }
        check(nCount == 6600, "exhausted N/R 68.75/31.25")

        let d = defaults(["candyCount": 1000, "gachaDrawProgress": 45, "bestDistance": 567,
                          "totalDistance": 1751, "claimedRewardIDs": ["hs_0250"], "exchangedCounts": ["legacy": 2]])
        let store = Halloween2026EventStore(defaults: d)
        let batch = store.prepareGachaBatch(id: "boundary", count: 10, inventory: HalloweenGachaInventory(foods: ["barger": 7]), at: now, random: { 0 })!
        check(store.candyCount == 500 && store.gachaDrawProgress == 5 && store.gachaTotalDraws == 10, "10-roll crosses50 and carries5")
        check(batch.rewards.count == 11 && batch.rewards[5].kind == .character && batch.rewards[5].drawNumber == 5, "last-one shown immediately after boundary draw")
        check(batch.foodTargets["barger"] == 17 && batch.petIDs.count == 1, "existing food ownership plus10 and one new pet")
        check(store.prepareGachaBatch(id: "boundary", count: 10, inventory: HalloweenGachaInventory(), at: now) == batch, "duplicate pending callback returns same persisted batch")
        check(store.prepareGachaBatch(id: "other", count: 1, inventory: HalloweenGachaInventory(), at: now) == nil, "pending batch blocks all other draws")
        let loaded = Halloween2026EventStore(defaults: d)
        check(loaded.pendingGachaBatch == batch && loaded.candyCount == 500 && loaded.gachaDrawProgress == 5, "pending delivery survives cold reload")
        loaded.completeGachaDelivery(id: "wrong")
        check(loaded.pendingGachaBatch != nil, "wrong acknowledgement cannot clear pending delivery")
        loaded.completeGachaDelivery(id: "boundary")
        let done = Halloween2026EventStore(defaults: d)
        check(done.pendingGachaBatch == nil && done.prepareGachaBatch(id: "boundary", count: 10, inventory: HalloweenGachaInventory(), at: now) == nil, "completed callback cannot draw again after restart")
        check(done.bestDistance == 567 && done.totalDistance == 1751 && done.claimedRewardIDs == ["hs_0250"] && done.exchangeCount(for: "legacy") == 2, "prior rewards progress preserved")
        var stalePayload = try! JSONSerialization.jsonObject(with: d.data(forKey: "memo.event.halloween2026.progress.v1")!) as! [String: Any]
        stalePayload["pendingGachaBatch"] = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(batch))
        d.set(try! JSONSerialization.data(withJSONObject: stalePayload), forKey: "memo.event.halloween2026.progress.v1")
        let repaired = Halloween2026EventStore(defaults: d)
        let repairedPayload = try! JSONSerialization.jsonObject(with: d.data(forKey: "memo.event.halloween2026.progress.v1")!) as! [String: Any]
        check(repaired.pendingGachaBatch == nil && repaired.completedGachaBatchIDs.contains("boundary"), "completed receipt suppresses stale journal")
        check(repairedPayload["pendingGachaBatch"] == nil && repaired.candyCount == 500 && repaired.gachaDrawProgress == 5 && repaired.bestDistance == 567, "stale journal removed on disk without resetting prior state")
        let insufficient = Halloween2026EventStore(defaults: defaults(["candyCount": 49]))
        check(insufficient.prepareGachaBatch(id: "poor", count: 1, inventory: HalloweenGachaInventory(), at: now) == nil && insufficient.candyCount == 49, "insufficient candy is unchanged")
        check(done.prepareGachaBatch(id: "invalid", count: 2, inventory: HalloweenGachaInventory(), at: now) == nil, "invalid count rejected")
        let closed = date("2026-11-07T15:00:00Z")
        check(done.prepareGachaBatch(id: "closed", count: 1, inventory: HalloweenGachaInventory(), at: closed) == nil && done.candyCount == 500, "final close preserves candy")
        let allOwned = Halloween2026EventStore(defaults: defaults(["candyCount": 500, "gachaDrawProgress": 49]))
        let complete = allOwned.prepareGachaBatch(id: "allowned", count: 10, inventory: HalloweenGachaInventory(ownedPetIDs: Set(HalloweenGachaCatalog.characterIDs)), at: now, random: { 0 })!
        check(complete.rewards.count == 10 && complete.petIDs.isEmpty && allOwned.gachaDrawProgress == 9, "complete continues with no alternative last-one")

        let capStore = Halloween2026EventStore(defaults: defaults(["candyCount": 1000, "srDayKey": "2026-10-02", "srDailyCounts": ["gachaTicket_nomal": 9]]))
        var pickIndex = 0
        let caps = capStore.prepareGachaBatch(id: "caps", count: 10, inventory: HalloweenGachaInventory(), at: now, random: {
            pickIndex += 1; return pickIndex.isMultiple(of: 2) ? 0 : 0.999
        })!
        check(capStore.srDailyCounts == ["gachaTicket_nomal": 10, "yakiniku": 2, "fishingPoints500": 2], "caps enforced between every draw in one ten-roll")
        check(caps.fishingPointTarget == 1000 && caps.itemTargets["gachaTicket_nomal"] == 1 && caps.foodTargets["yakiniku"] == 2, "SR rewards1000 fish/one ticket/two yakiniku")
        capStore.completeGachaDelivery(id: "caps")
        check(capStore.currentSRCounts(at: date("2026-10-02T14:59:59Z")) == capStore.srDailyCounts, "JST before midnight still capped")
        check(capStore.currentSRCounts(at: date("2026-10-02T15:00:00Z")).isEmpty && capStore.gachaDrawProgress == 10, "JST midnight resets only SR availability")

        let adDefaults = defaults([:])
        let ads = Halloween2026EventStore(defaults: adDefaults)
        adDefaults.set("normal-independent", forKey: "memo.gacha.freeAd.dayKey")
        adDefaults.set(["noon"], forKey: "memo.gacha.freeAd.usedSlots")
        for (hour, slot) in [(5, GachaFreeAdSlot.morning), (10, .noon), (15, .evening)] {
            let time = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: hour))!
            let claim = ads.availableEventAdClaim(at: time, calendar: tokyo)!
            check(claim.slot == slot, "event free slot boundary")
            let id = "ad-\(hour)"
            let free = ads.prepareGachaBatch(id: id, count: 10, inventory: HalloweenGachaInventory(), adClaim: claim, at: time, calendar: tokyo, random: { 0 })!
            check(free.rewards.count == 10 && ads.candyCount == 0, "earned ad makes10 without candy")
            ads.completeGachaDelivery(id: id)
            check(ads.availableEventAdClaim(at: time, calendar: tokyo) == nil, "same slot cannot be used twice")
            check(ads.prepareGachaBatch(id: id, count: 10, inventory: HalloweenGachaInventory(), adClaim: claim, at: time, calendar: tokyo) == nil, "duplicate earned callback rejected")
        }
        check(ads.gachaTotalDraws == 30 && ads.gachaDrawProgress == 30, "ads count toward last-one")
        check(adDefaults.stringArray(forKey: "memo.gacha.freeAd.usedSlots") == ["noon"], "event cannot consume regular slot")
        for hour in [0, 4, 23] {
            let time = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: hour))!
            check(ads.availableEventAdClaim(at: time, calendar: tokyo) == nil, "overnight has no ad slot")
        }
        let tomorrow = date("2026-10-03T01:00:00Z")
        check(ads.availableEventAdClaim(at: tomorrow, calendar: tokyo) != nil && ads.gachaDrawProgress == 30, "next day restores ad independently of50 count")
        let grace = date("2026-11-07T03:00:00Z")
        check(ads.availableEventAdClaim(at: grace, calendar: tokyo) != nil, "ads available during reward grace")
        check(ads.availableEventAdClaim(at: closed, calendar: tokyo) == nil, "ads closed at final boundary")
    }
}
