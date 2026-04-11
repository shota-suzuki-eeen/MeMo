//
//  AppState+Gacha.swift
//  MeMo
//
//  Created by shota suzuki on 2026/04/10.
//

import Foundation

enum GachaFreeAdSlot: String, CaseIterable, Codable, Identifiable {
    case morning
    case noon
    case evening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: return "朝"
        case .noon: return "昼"
        case .evening: return "夜"
        }
    }

    var windowText: String {
        switch self {
        case .morning: return "5:00-10:00"
        case .noon: return "10:00-15:00"
        case .evening: return "15:00-23:00"
        }
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let hour = calendar.component(.hour, from: date)
        switch self {
        case .morning:
            return (5..<10).contains(hour)
        case .noon:
            return (10..<15).contains(hour)
        case .evening:
            return (15..<23).contains(hour)
        }
    }

    static func current(at date: Date, calendar: Calendar = .current) -> GachaFreeAdSlot? {
        allCases.first { $0.contains(date, calendar: calendar) }
    }
}

extension AppState {
    private enum GachaStorageKeys {
        static let pityCounter = "memo.gacha.pityCounter"
        static let guaranteedGoldNext = "memo.gacha.guaranteedGoldNext"
        static let freeAdDayKey = "memo.gacha.freeAd.dayKey"
        static let freeAdUsedSlots = "memo.gacha.freeAd.usedSlots"
        static let specialItemCounts = "memo.gacha.specialItemCounts"
    }

    private var gachaDefaults: UserDefaults {
        .standard
    }

    var gachaPityCounter: Int {
        get { max(0, gachaDefaults.integer(forKey: GachaStorageKeys.pityCounter)) }
        set { gachaDefaults.set(max(0, newValue), forKey: GachaStorageKeys.pityCounter) }
    }

    var gachaGuaranteedGoldNext: Bool {
        get { gachaDefaults.bool(forKey: GachaStorageKeys.guaranteedGoldNext) }
        set { gachaDefaults.set(newValue, forKey: GachaStorageKeys.guaranteedGoldNext) }
    }

    private var gachaFreeAdDayKeyStorage: String {
        get { gachaDefaults.string(forKey: GachaStorageKeys.freeAdDayKey) ?? "" }
        set { gachaDefaults.set(newValue, forKey: GachaStorageKeys.freeAdDayKey) }
    }

    private var gachaFreeAdUsedSlotsStorage: [String] {
        get { gachaDefaults.stringArray(forKey: GachaStorageKeys.freeAdUsedSlots) ?? [] }
        set { gachaDefaults.set(newValue, forKey: GachaStorageKeys.freeAdUsedSlots) }
    }

    private var gachaSpecialItemCountsStorage: [String: Int] {
        get {
            guard let data = gachaDefaults.data(forKey: GachaStorageKeys.specialItemCounts),
                  let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            let encoded = try? JSONEncoder().encode(newValue)
            gachaDefaults.set(encoded, forKey: GachaStorageKeys.specialItemCounts)
        }
    }

    func gachaResetIfNeeded(now: Date = Date()) {
        ensureDailyResetIfNeeded(now: now)

        let todayKey = AppState.makeDayKey(now)
        guard gachaFreeAdDayKeyStorage != todayKey else { return }

        gachaFreeAdDayKeyStorage = todayKey
        gachaFreeAdUsedSlotsStorage = []
    }

    func gachaUsedFreeAdSlots(now: Date = Date()) -> Set<GachaFreeAdSlot> {
        gachaResetIfNeeded(now: now)
        let slots = gachaFreeAdUsedSlotsStorage.compactMap(GachaFreeAdSlot.init(rawValue:))
        return Set(slots)
    }

    func gachaAvailableFreeAdSlot(now: Date = Date()) -> GachaFreeAdSlot? {
        gachaResetIfNeeded(now: now)

        guard let currentSlot = GachaFreeAdSlot.current(at: now) else { return nil }
        let used = gachaUsedFreeAdSlots(now: now)
        guard !used.contains(currentSlot) else { return nil }
        return currentSlot
    }

    func gachaCanUseFreeTenDraw(now: Date = Date()) -> Bool {
        gachaAvailableFreeAdSlot(now: now) != nil
    }

    @discardableResult
    func gachaConsumeFreeTenDraw(now: Date = Date()) -> GachaFreeAdSlot? {
        gachaResetIfNeeded(now: now)

        guard let slot = gachaAvailableFreeAdSlot(now: now) else { return nil }
        var used = gachaUsedFreeAdSlots(now: now)
        used.insert(slot)
        gachaFreeAdUsedSlotsStorage = used.map(\.rawValue).sorted()
        return slot
    }

    func gachaSpecialItemCount(id: String) -> Int {
        let dict = gachaSpecialItemCountsStorage
        return max(0, dict[id] ?? 0)
    }

    @discardableResult
    func gachaAddSpecialItem(id: String, count: Int = 1) -> Bool {
        let add = max(0, count)
        guard add > 0 else { return false }

        var dict = gachaSpecialItemCountsStorage
        let current = max(0, dict[id] ?? 0)
        dict[id] = current + add
        gachaSpecialItemCountsStorage = dict
        return true
    }

    @discardableResult
    func gachaConsumeSpecialItem(id: String, count: Int = 1) -> Bool {
        let use = max(0, count)
        if use == 0 {
            return true
        }

        var dict = gachaSpecialItemCountsStorage
        let current = max(0, dict[id] ?? 0)
        guard current >= use else { return false }

        let next = current - use
        if next <= 0 {
            dict.removeValue(forKey: id)
        } else {
            dict[id] = next
        }

        gachaSpecialItemCountsStorage = dict
        return true
    }

    func gachaResetPity() {
        gachaPityCounter = 0
        gachaGuaranteedGoldNext = false
    }

    func gachaAdvancePityAfterNonGold(threshold: Int = 150) {
        let next = max(0, gachaPityCounter) + 1
        gachaPityCounter = next
        gachaGuaranteedGoldNext = next >= max(1, threshold)
    }
}
