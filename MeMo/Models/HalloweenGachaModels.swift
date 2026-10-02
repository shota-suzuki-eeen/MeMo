import Foundation

/// Event-only rewards. Characters enter exclusively at the 50-draw boundary.
struct HalloweenGachaReward: Codable, Equatable, Identifiable {
    enum Kind: String, Codable { case food, item, fishingPoints, character }
    let id: String
    let kind: Kind
    let itemID: String
    let rarity: String
    let amount: Int
    let drawNumber: Int
}

struct HalloweenGachaInventory {
    var foods: [String: Int] = [:]
    var items: [String: Int] = [:]
    var fishingPoints: Int = 0
    var ownedPetIDs: Set<String> = []
}

/// Absolute delivery targets make retry after a partial multi-store write idempotent.
/// Pending delivery is recovered before exposing the inventory at startup.
struct HalloweenGachaBatch: Codable, Equatable, Identifiable {
    let id: String
    let rewards: [HalloweenGachaReward]
    let foodTargets: [String: Int]
    let itemTargets: [String: Int]
    let fishingPointTarget: Int?
    let petIDs: Set<String>
}

struct HalloweenGachaAdClaim {
    let slot: GachaFreeAdSlot
    let dayKey: String
    let startedAt: Date
}

enum HalloweenGachaCatalog {
    static let normalFoodIDs = [
        "barger", "beer", "cake", "carry", "coffee", "coke", "gyuudon", "icecream", "karaage",
        "nabe", "onigiri", "pan", "pizza", "poteti", "ra-men", "sandowitch", "sarad", "sute-ki", "yo-guruto"
    ]
    static let rareFoodIDs = ["matsuzakaBeef", "spinyLobster", "shineMuscat", "eel", "snowCrab", "otoro", "cantaloupe", "matsutake"]
    static let srIDs = ["gachaTicket_nomal", "yakiniku", "fishingPoints500"]
    // All 25 base PNGs in MeMo_material/キャラクター/ハロウィン, verified against Assets.xcassets.
    static let characterAssetNames = [
        "arachne", "barky", "baty", "boogie", "clownie", "dracella", "drya", "dully", "fin",
        "frank", "gide", "goths", "harpy", "jack-o", "kinny", "medy", "mia", "mummy",
        "neroa", "reaper", "skelly", "spookey", "vampy", "werfa", "wivy"
    ]
    static var characterIDs: [String] { characterAssetNames.map { "halloween_\($0)" } }

    static func localDayKey(at date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func availableSRIDs(counts: [String: Int]) -> [String] {
        srIDs.filter { max(0, counts[$0] ?? 0) < Halloween2026Configuration.srDailyLimits[$0]! }
    }

    static func weightedIndex(_ weights: [Int], random: () -> Double) -> Int {
        let total = weights.reduce(0, +)
        let value = random()
        let roll = (value.isFinite ? min(max(0, value), 0.9999999999999999) : 0) * Double(total)
        var accumulated = 0
        for (index, weight) in weights.enumerated() {
            accumulated += weight
            if roll < Double(accumulated) { return index }
        }
        return weights.count - 1
    }

    static func roll(counts: [String: Int], random: () -> Double) -> (HalloweenGachaReward.Kind, String, String, Int) {
        let availableSR = availableSRIDs(counts: counts)
        let weights = Halloween2026Configuration.rarityWeights
        let rarity = weightedIndex(availableSR.isEmpty ? Array(weights.prefix(2)) : weights, random: random)
        if rarity == 0 {
            let pool = normalFoodIDs.filter { FoodCatalog.byId($0) != nil }
            return (.food, pool[weightedIndex(Array(repeating: 1, count: pool.count), random: random)], "N", 1)
        }
        if rarity == 1 {
            let pool = rareFoodIDs.filter { FoodCatalog.byId($0) != nil } + ["wc"]
            let id = pool[weightedIndex(Array(repeating: 1, count: pool.count), random: random)]
            return (id == "wc" ? .item : .food, id, "R", 1)
        }
        let srWeights = availableSR.map { Halloween2026Configuration.srWeights[srIDs.firstIndex(of: $0)!] }
        let id = availableSR[weightedIndex(srWeights, random: random)]
        switch id {
        case "yakiniku": return (.food, id, "SR", 1)
        case "fishingPoints500": return (.fishingPoints, id, "SR", Halloween2026Configuration.fishingPointsPerReward)
        default: return (.item, id, "SR", 1)
        }
    }

    static func addingClamped(_ value: Int, _ amount: Int) -> Int {
        let (result, overflow) = max(0, value).addingReportingOverflow(max(0, amount))
        return overflow ? Int.max : result
    }
}
