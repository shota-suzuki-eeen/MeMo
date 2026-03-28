//
//  PetMaster.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation

// MARK: - Master Item

struct PetMasterItem: Identifiable, Codable, Equatable {
    let id: String
    let name: String

    // 将来的に「好物/大好物」倍率を入れる可能性があるので枠だけ用意（現状ロジック未使用）
    // 既存の .init(id:name:personality:) を壊さないためデフォルト値を付与
    // Codable 警告回避のため let + 初期値 ではなく var にする
    var favoriteFoodKind: FoodKind? = nil
    var superFavoriteFoodKind: FoodKind? = nil
}

// MARK: - Care / Friendship (Spec v6)

enum FriendshipSpec {
    static let maxPoint: Int = 100

    static let cardThreshold: Int = 100

    static let foodNormal: Int = 10
    static let foodFavorite: Int = 20
    static let foodSuperFavorite: Int = 30

    static let bathGain: Int = 15
    static let bathCooldownHours: Int = 8
    static let bathAdReduceHoursPerWatch: Int = 4
    static let bathAdLimitPerDay: Int = 2

    static let toiletNormal: Int = 10
    static let toiletWithin1h: Int = 20
    static let toiletBonusWindowSeconds: TimeInterval = 60 * 60
}

enum FoodKind: String, Codable, CaseIterable {
    case normal
    case favorite
    case superFavorite

    var gainPoint: Int {
        switch self {
        case .normal: return FriendshipSpec.foodNormal
        case .favorite: return FriendshipSpec.foodFavorite
        case .superFavorite: return FriendshipSpec.foodSuperFavorite
        }
    }
}

enum FoodTimeSlot: String, Codable, CaseIterable {
    case morning
    case noon
    case night
}

// MARK: - Master List

enum PetMaster {

    static let all: [PetMasterItem] = [
        .init(id: "pet_000", name: "パーソン"),
        .init(id: "pet_001", name: "ドッグ"),
        .init(id: "pet_002", name: "キャット"),
        .init(id: "pet_003", name: "チキン"),
        .init(id: "pet_004", name: "モンキー"),
        .init(id: "pet_005", name: "ラビット"),
        .init(id: "pet_006", name: "フロッグ"),
        .init(id: "pet_007", name: "ペンギン"),
        .init(id: "pet_008", name: "シープ"),
        .init(id: "pet_009", name: "シャーク"),
        .init(id: "pet_010", name: "タートル"),
        .init(id: "pet_011", name: "*"),
        .init(id: "pet_012", name: "*"),
        .init(id: "pet_013", name: "*"),
        .init(id: "pet_014", name: "*"),
        .init(id: "pet_015", name: "*"),
        .init(id: "pet_016", name: "*"),
        .init(id: "pet_017", name: "*"),
        .init(id: "pet_018", name: "*"),
        .init(id: "pet_019", name: "*"),
        .init(id: "pet_020", name: "*"),
        .init(id: "pet_021", name: "*"),
        .init(id: "pet_022", name: "*"),
        .init(id: "pet_023", name: "*"),
        .init(id: "pet_024", name: "*"),
        .init(id: "pet_025", name: "トリケラトプス"),
        .init(id: "pet_026", name: "*"),
        .init(id: "pet_027", name: "*"),
        .init(id: "pet_028", name: "*"),
        .init(id: "pet_029", name: "*"),
        .init(id: "pet_030", name: "*"),
        .init(id: "pet_031", name: "*"),
        .init(id: "pet_032", name: "*"),
        .init(id: "pet_033", name: "*"),
        .init(id: "pet_034", name: "*"),
        .init(id: "pet_035", name: "*"),
        .init(id: "pet_036", name: "*"),
        .init(id: "pet_037", name: "*"),
        .init(id: "pet_038", name: "*"),
        .init(id: "pet_039", name: "*"),
        .init(id: "pet_040", name: "*"),
        .init(id: "pet_041", name: "*"),
        .init(id: "pet_042", name: "*"),
        .init(id: "pet_043", name: "*"),
        .init(id: "pet_044", name: "*"),
        .init(id: "pet_045", name: "*"),
        .init(id: "pet_046", name: "*"),
        .init(id: "pet_047", name: "*"),
        .init(id: "pet_048", name: "*"),
        .init(id: "pet_048", name: "*"),
    ]

    // ✅ ペットID → アセット名（修正版）
    static func assetName(for petID: String) -> String {
        switch petID {
        case "pet_000": return "person"
        case "pet_001": return "dog"
        case "pet_002": return "cat"
        case "pet_003": return "chicken"
        case "pet_004": return "monkey"
        case "pet_005": return "rabbit"
        case "pet_006": return "frog"
        case "pet_007": return "penguin"
        case "pet_008": return "sheep"
        case "pet_009": return "shark"
        case "pet_010": return "turtle"
        case "pet_011": return "dolphin"
        case "pet_012": return "Sloth"
        case "pet_013": return "baku"
        case "pet_014": return "blackGibbon"
        case "pet_015": return "bulldog"
        case "pet_016": return "deer"
        case "pet_017": return "fox"
        case "pet_018": return "frilledLizard"
        case "pet_019": return "giraffe"
        case "pet_020": return "koala"
        case "pet_021": return "okapi"
        case "pet_022": return "platypus"
        case "pet_023": return "raccoon"
        case "pet_024": return "Shoebill"
        case "pet_025": return "Triceratops"
        case "pet_026": return "bee"
        case "pet_027": return "amesho"
        case "pet_028": return "barinys"
        case "pet_029": return "blue"
        case "pet_030": return "shiba"
        case "pet_031": return "gorilla"
        case "pet_032": return "lizard"
        case "pet_033": return "meerkat"
        case "pet_034": return "otter"
        case "pet_035": return "owl"
        case "pet_036": return "parakeet"
        case "pet_037": return "peacock"
        case "pet_038": return "pig"
        case "pet_039": return "raccoonDog"
        case "pet_040": return "redPanda"
        case "pet_041": return "seal"
        case "pet_042": return "seaOtter"
        case "pet_043": return "skunk"
        case "pet_044": return "swallow"
        case "pet_045": return "tiger"
        case "pet_046": return "whiteTiger"
        case "pet_047": return "zebra"
        case "pet_048": return "wolf"
        default:
            return "purpor" // 安全フォールバック
        }
    }

    // MARK: - ✅ Super Favorite (Master)

    /// ✅ 各キャラの「大好物」名称（マスタ）
    static func superFavoriteFoodName(for petID: String) -> String {
        switch petID {
        case "pet_000": return "おにぎり"
        case "pet_001": return "ラーメン"
        case "pet_002": return "ソフトクリーム"
        case "pet_003": return "ハンバーガー"
        case "pet_004": return "コーラ"
        case "pet_005": return "ヨーグルト"
        case "pet_006": return "サラダ"
        case "pet_007": return "コーヒー"
        case "pet_008": return "お鍋"
        case "pet_009": return "ステーキ"
        case "pet_010": return "ピザ"
        default:
            return "？？？"
        }
    }

    /// ✅ 説明文の本文（大好物行は別で付与する）
    private static func baseDescriptionText(for petID: String) -> String {
        switch petID {
        case "pet_000":
            return "*"
        case "pet_001":
            return "*"
        case "pet_002":
            return "*"
        case "pet_003":
            return "*"
        case "pet_004":
            return "*"
        case "pet_005":
            return "*"
        case "pet_006":
            return "*"
        case "pet_007":
            return "*"
        case "pet_008":
            return "*"
        case "pet_009":
            return "*"
        case "pet_010":
            return "*"
        default:
            return "今後記載予定"
        }
    }

    // MARK: - Description API

    /// ✅ 既存互換：stateを渡さない場合は常に「？？？」表示（初期状態と同じ）
    static func description(for petID: String) -> String {
        let base = baseDescriptionText(for: petID)
        return base + "\n\n【大好物】？？？"
    }

    /// ✅ 追加：図鑑の表示用（判明済みなら大好物名を表示）
    static func description(for petID: String, state: AppState) -> String {
        let base = baseDescriptionText(for: petID)

        let revealed = state.isSuperFavoriteRevealed(petID: petID)
        let foodText = revealed ? superFavoriteFoodName(for: petID) : "？？？"

        return base + "\n\n【大好物】" + foodText
    }
}
