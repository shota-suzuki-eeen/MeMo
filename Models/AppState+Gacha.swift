//
//  AppState+Gacha.swift
//  MeMo
//
//  Updated for per-gacha pity counters.
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
        static let defaultGachaID = "always"

        // Legacy single-machine pity storage. Kept so existing users keep the old いつでもガチャ progress.
        static let legacyPityCounter = "memo.gacha.pityCounter"
        static let legacyGuaranteedGoldNext = "memo.gacha.guaranteedGoldNext"

        // New per-machine pity storage. Keyed by GachaDefinition.id, for example "always" and "food".
        static let pityCountersByGacha = "memo.gacha.pityCountersByGacha"
        static let guaranteedGoldNextByGacha = "memo.gacha.guaranteedGoldNextByGacha"

        static let freeAdDayKey = "memo.gacha.freeAd.dayKey"
        static let freeAdUsedSlots = "memo.gacha.freeAd.usedSlots"
        static let specialItemCounts = "memo.gacha.specialItemCounts"
        static let initialIPadFreeTenDrawConsumed = "memo.gacha.initialIPadFreeTenDrawConsumed"
    }

    private var gachaDefaults: UserDefaults {
        .standard
    }

    private static func normalizedGachaID(_ gachaID: String) -> String {
        let trimmed = gachaID.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? GachaStorageKeys.defaultGachaID : trimmed
    }

    private var gachaPityCountersStorage: [String: Int] {
        get {
            guard let data = gachaDefaults.data(forKey: GachaStorageKeys.pityCountersByGacha),
                  let dict = try? JSONDecoder().decode([String: Int].self, from: data) else {
                let legacyValue = max(0, gachaDefaults.integer(forKey: GachaStorageKeys.legacyPityCounter))
                return legacyValue > 0 ? [GachaStorageKeys.defaultGachaID: legacyValue] : [:]
            }
            return dict.mapValues { max(0, $0) }
        }
        set {
            let sanitized = newValue.mapValues { max(0, $0) }
            let encoded = try? JSONEncoder().encode(sanitized)
            gachaDefaults.set(encoded, forKey: GachaStorageKeys.pityCountersByGacha)
        }
    }

    private var gachaGuaranteedGoldNextStorage: [String: Bool] {
        get {
            guard let data = gachaDefaults.data(forKey: GachaStorageKeys.guaranteedGoldNextByGacha),
                  let dict = try? JSONDecoder().decode([String: Bool].self, from: data) else {
                let legacyValue = gachaDefaults.bool(forKey: GachaStorageKeys.legacyGuaranteedGoldNext)
                return legacyValue ? [GachaStorageKeys.defaultGachaID: true] : [:]
            }
            return dict
        }
        set {
            let encoded = try? JSONEncoder().encode(newValue)
            gachaDefaults.set(encoded, forKey: GachaStorageKeys.guaranteedGoldNextByGacha)
        }
    }

    var gachaPityCounter: Int {
        get { gachaPityCounter(for: GachaStorageKeys.defaultGachaID) }
        set { setGachaPityCounter(newValue, for: GachaStorageKeys.defaultGachaID) }
    }

    var gachaGuaranteedGoldNext: Bool {
        get { gachaGuaranteedGoldNext(for: GachaStorageKeys.defaultGachaID) }
        set { setGachaGuaranteedGoldNext(newValue, for: GachaStorageKeys.defaultGachaID) }
    }

    func gachaPityCounter(for gachaID: String) -> Int {
        let key = Self.normalizedGachaID(gachaID)
        return max(0, gachaPityCountersStorage[key] ?? 0)
    }

    func gachaGuaranteedGoldNext(for gachaID: String) -> Bool {
        let key = Self.normalizedGachaID(gachaID)
        return gachaGuaranteedGoldNextStorage[key] ?? false
    }

    private func setGachaPityCounter(_ value: Int, for gachaID: String) {
        let key = Self.normalizedGachaID(gachaID)
        var dict = gachaPityCountersStorage
        dict[key] = max(0, value)
        gachaPityCountersStorage = dict

        if key == GachaStorageKeys.defaultGachaID {
            gachaDefaults.set(max(0, value), forKey: GachaStorageKeys.legacyPityCounter)
        }
    }

    private func setGachaGuaranteedGoldNext(_ value: Bool, for gachaID: String) {
        let key = Self.normalizedGachaID(gachaID)
        var dict = gachaGuaranteedGoldNextStorage
        dict[key] = value
        gachaGuaranteedGoldNextStorage = dict

        if key == GachaStorageKeys.defaultGachaID {
            gachaDefaults.set(value, forKey: GachaStorageKeys.legacyGuaranteedGoldNext)
        }
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

    private var gachaInitialIPadFreeTenDrawConsumedStorage: Bool {
        get { gachaDefaults.bool(forKey: GachaStorageKeys.initialIPadFreeTenDrawConsumed) }
        set { gachaDefaults.set(newValue, forKey: GachaStorageKeys.initialIPadFreeTenDrawConsumed) }
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

    func gachaCanUseInitialIPadFreeTenDraw(isPad: Bool) -> Bool {
        isPad && !gachaInitialIPadFreeTenDrawConsumedStorage
    }

    @discardableResult
    func gachaConsumeInitialIPadFreeTenDraw(isPad: Bool) -> Bool {
        guard gachaCanUseInitialIPadFreeTenDraw(isPad: isPad) else { return false }
        gachaInitialIPadFreeTenDrawConsumedStorage = true
        return true
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
        gachaResetPity(for: GachaStorageKeys.defaultGachaID)
    }

    func gachaResetPity(for gachaID: String) {
        setGachaPityCounter(0, for: gachaID)
        setGachaGuaranteedGoldNext(false, for: gachaID)
    }

    func gachaAdvancePityAfterNonGold(threshold: Int = 100) {
        gachaAdvancePityAfterNonGold(for: GachaStorageKeys.defaultGachaID, threshold: threshold)
    }

    func gachaAdvancePityAfterNonGold(for gachaID: String, threshold: Int = 100) {
        let next = max(0, gachaPityCounter(for: gachaID)) + 1
        setGachaPityCounter(next, for: gachaID)
        setGachaGuaranteedGoldNext(next >= max(1, threshold), for: gachaID)
    }
}
