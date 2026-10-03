import Foundation

@main
enum GachaSelectionTests {
    static func main() throws {
        let machines = ["always", "food", "moja", "streetAnimals", "cyberpunkRacers", "hyakkaryouran"]
        let key = "memo.gacha.lastCompletedMachineID.v1"
        let defaults = UserDefaults.standard
        var assertions = 0
        func check(_ value: Bool, _ message: String) {
            assertions += 1
            guard value else { fatalError(message) }
        }
        func seed(saved: Any? = nil, unlocked: [String] = machines) -> AppState {
            defaults.values = [
                "memo.gacha.unlockedMachineIDs.v2": unlocked.filter { $0 != "always" },
                "memo.gacha.pityCounter": 17,
                "memo.gacha.guaranteedGoldNext": true,
                "memo.gacha.pityCountersByGacha": Data("{\"always\":17,\"food\":32}".utf8),
                "memo.gacha.guaranteedGoldNextByGacha": Data("{\"always\":true,\"food\":false}".utf8),
                "memo.gacha.freeAd.dayKey": "legacy-day",
                "memo.gacha.freeAd.usedSlots": ["morning"],
                "memo.gacha.specialItemCounts": Data("{\"gachaTicket_nomal\":20,\"gachaTicket_special\":2,\"wc\":3}".utf8),
                "memo.happiness.standardRewardV2.claimedLevels": Data("[15,30]".utf8),
                "memo.event.halloween2026.progress.v1": Data("{\"candy\":123}".utf8)
            ]
            defaults.values[key] = saved
            defaults.writes = [:]
            return AppState()
        }
        func same(_ lhs: [String: Any], _ rhs: [String: Any]) -> Bool {
            NSDictionary(dictionary: lhs).isEqual(to: rhs)
        }
        func record(_ state: AppState, id: String, count: Int = 1, expected: Int = 1, available: [String]? = nil, saved: Bool = true) -> Bool {
            state.gachaRecordCompletedDraw(machineID: id, rewardCount: count, expectedRewardCount: expected, availableMachineIDs: available ?? machines, persistenceSucceeded: saved)
        }

        // Old/malformed history is a read-only fallback, independent of unlock/pity history.
        let corrupt: [Any?] = [nil, "", "unknown", "removed", "halloween2026", " ALWAYS ", "food ", 123, Data([0, 1]), ["food"]]
        for value in corrupt {
            let state = seed(saved: value)
            let before = defaults.values
            check(state.gachaInitialMachineID(availableMachineIDs: machines) == "always", "old/unknown/malformed history falls back")
            check(same(before, defaults.values) && defaults.writes.isEmpty, "fallback never rewrites data or infers history")
        }

        // Resolve every availability subset, including absent default, empty and removed IDs.
        for mask in 0..<(1 << machines.count) {
            let available = machines.enumerated().compactMap { mask & (1 << $0.offset) != 0 ? $0.element : nil }
            for savedID in machines + ["unknown", "halloween2026"] {
                let state = seed(saved: savedID)
                let before = defaults.values
                let fallback = available.contains("always") ? "always" : available.first
                let expected = available.contains(savedID) ? savedID : fallback
                check(state.gachaInitialMachineID(availableMachineIDs: available) == expected, "stable-ID restoration respects current availability")
                check(state.gachaInitialMachineID(availableMachineIDs: Array(available.reversed())) == (available.contains(savedID) ? savedID : (available.contains("always") ? "always" : available.last)), "catalog reorder does not change remembered machine")
                check(state.gachaInitialMachineID(availableMachineIDs: available, alwaysOnly: true) == (available.contains("always") ? "always" : nil), "tutorial/initial-iPad Always restriction wins")
                check(same(before, defaults.values) && defaults.writes.isEmpty, "read-only availability fallback preserves history and all contracts")
            }
        }
        for id in machines.dropFirst() {
            let state = seed(saved: id, unlocked: ["always"])
            let before = defaults.values
            check(state.gachaInitialMachineID(availableMachineIDs: machines) == "always", "locked saved machine never becomes available")
            check(!record(state, id: id), "locked machine cannot be recorded")
            check(same(before, defaults.values), "locked fallback never unlocks or rewrites")
        }

        // Complete/incomplete/invalid counts and save failure never invent a completed draw.
        let bounds = [-1, 0, 1, 2, 9, 10, 11, Int.max]
        for id in machines {
            for expected in bounds {
                for count in bounds {
                    for saved in [false, true] {
                        let state = seed(saved: "old-history")
                        var before = defaults.values
                        let success = saved && (expected == 1 || expected == 10) && count == expected
                        check(record(state, id: id, count: count, expected: expected, saved: saved) == success, "only full supported draws with successful persistence are recorded")
                        if success { before[key] = id }
                        check(same(before, defaults.values), "recording only changes the additive selection key")
                        check(state.walletSteps == 10000, "selection never changes pricing or wallet")
                    }
                }
            }
        }
        for id in ["", "unknown", "halloween2026", "food "] {
            let state = seed(saved: "always")
            let before = defaults.values
            check(!record(state, id: id), "IDs outside current normal catalog cannot overwrite history")
            check(same(before, defaults.values), "event/unknown/invalid IDs leave all saved state unchanged")
        }

        // A completed draw, B viewing only, reopen A; full B draw and serialized reload B.
        let state = seed()
        check(record(state, id: "food", count: 10, expected: 10), "successful A ten-draw records A")
        let afterA = defaults.values
        check(state.gachaInitialMachineID(availableMachineIDs: ["always", "food", "moja"]) == "food", "A remains selected after B browsing without a draw")
        check(same(afterA, defaults.values), "browsing does not record B")
        check(record(state, id: "food", count: 10, expected: 10), "repeated successful callback is idempotent")
        check(defaults.writes[key] == 1, "same ID does not repeat the selection write")
        check(!record(state, id: "moja", count: 0, expected: 10) && !record(state, id: "moja", count: 10, expected: 10, saved: false), "B failed generation/save retains A")
        check(defaults.string(forKey: key) == "food", "failed B keeps actual A history")
        check(record(state, id: "moja"), "successful B single-draw replaces A")
        check(defaults.writes[key] == 2, "new successful ID is written once")
        let path = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("selection.plist")
        try defaults.roundTrip(at: path)
        check(AppState().gachaInitialMachineID(availableMachineIDs: machines) == "moja", "stable ID survives binary-plist reload into a new owner")
        check(AppState().gachaInitialMachineID(availableMachineIDs: machines, alwaysOnly: true) == "always", "reload cannot bypass tutorial/initial-iPad restriction")
        check(defaults.string(forKey: key) == "moja", "Always-only display does not overwrite existing history")

        // Actual released payment/slot APIs feed the same completed-draw owner.
        for id in machines {
            for payment in [GachaDrawPayment.steps(500), .steps(5000), .normalTickets(1), .normalTickets(10)] {
                let state = seed(saved: "always")
                let count: Int
                switch payment {
                case .steps(let cost): count = cost == 500 ? 1 : 10
                case .normalTickets(let tickets): count = tickets
                }
                check(state.gachaConsumeDrawPayment(payment), "existing walk/ticket payment succeeds")
                check(record(state, id: id, count: count, expected: count), "walk/ticket full draw records selected machine")
                check(defaults.string(forKey: key) == id, "single/ten remember current stable ID")
            }
            let special = seed(saved: "always")
            check(special.gachaConsumeSpecialItem(id: GachaTicketPolicy.specialTicketID), "released special ticket consumes")
            check(record(special, id: id), "full guaranteed-character single uses same selection owner")
            let free = seed(saved: "always")
            let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 12))!
            check(free.gachaConsumeFreeTenDraw(now: now) != nil, "normal earned-ad slot consumes through released API")
            check(record(free, id: id, count: 10, expected: 10), "full normal free ten records current machine")
            let recorded = defaults.values
            check(free.gachaConsumeFreeTenDraw(now: now) == nil, "repeated free-slot callback cannot consume again")
            check(same(recorded, defaults.values), "rejected repeat does not change history or slots")
        }
        let failed = seed(saved: "food")
        failed.walletSteps = 499
        check(!failed.gachaConsumeDrawPayment(.steps(500)), "insufficient walk balance rejects draw")
        check(!failed.gachaConsumeDrawPayment(.normalTickets(21)), "insufficient normal tickets reject draw")
        check(defaults.string(forKey: key) == "food", "failed released payments preserve history")
        let initial = seed(saved: "food")
        check(initial.gachaConsumeInitialIPadFreeTenDraw(isPad: true), "existing initial-iPad allowance succeeds")
        check(record(initial, id: "always", count: 10, expected: 10), "successful initial-iPad Always draw records Always")
        check(!initial.gachaConsumeInitialIPadFreeTenDraw(isPad: true), "initial-iPad repeat remains rejected")
        check(defaults.string(forKey: key) == "always", "rejected initial-iPad repeat preserves selection")

        print("PASS: \(assertions) normal-gacha selection/commit/payment/reload assertions (isolated dependency shells)")
    }
}
