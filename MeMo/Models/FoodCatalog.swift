//
//  FoodCatalog.swift
//  MeMo
//
//  N / R / SP の明示的なレアリティ管理に対応。
//  SPは食べたいご飯に関係なく幸せ度25を獲得し、満腹度を最大にする。
//

import Foundation

enum FoodCatalog {
    enum FoodRarity: String, CaseIterable, Codable, Hashable {
        case normal = "N"
        case rare = "R"
        case special = "SP"
    }

    struct FoodItem: Identifiable, Hashable {
        let id: String
        let name: String
        let assetName: String
        let rarity: FoodRarity
        let happinessBonusPoints: Int
        let fillsFullnessToMaximum: Bool

        init(
            id: String,
            name: String,
            assetName: String,
            rarity: FoodRarity,
            happinessBonusPoints: Int = 0,
            fillsFullnessToMaximum: Bool = false
        ) {
            self.id = id
            self.name = name
            self.assetName = assetName
            self.rarity = rarity
            self.happinessBonusPoints = max(0, happinessBonusPoints)
            self.fillsFullnessToMaximum = fillsFullnessToMaximum
        }

        /// 既存コードとの互換性維持。
        /// 従来は true=N、false=R として使用されていた。
        var isShopEligible: Bool {
            rarity == .normal
        }

        var grantsHappinessBonus: Bool {
            happinessBonusPoints > 0
        }

        var isSpecial: Bool {
            rarity == .special
        }
    }

    /// 既存のN・R一覧。
    /// チュートリアルや既存ガチャがSPを誤って抽選しないよう、従来のallにはSPを含めない。
    static let all: [FoodItem] = [
        // N（通常ご飯）
        .init(id: "barger",      name: "ハンバーガー",   assetName: "food_barger",      rarity: .normal),
        .init(id: "beer",        name: "ビール",         assetName: "food_beer",        rarity: .normal),
        .init(id: "cake",        name: "いちごケーキ",   assetName: "food_cake",        rarity: .normal),
        .init(id: "carry",       name: "カレー",         assetName: "food_carry",       rarity: .normal),
        .init(id: "coffee",      name: "コーヒー",       assetName: "food_coffee",      rarity: .normal),
        .init(id: "coke",        name: "コーラ",         assetName: "food_coke",        rarity: .normal),
        .init(id: "gyuudon",     name: "牛丼",           assetName: "food_gyuudon",     rarity: .normal),
        .init(id: "icecream",    name: "ソフトクリーム", assetName: "food_icecream",    rarity: .normal),
        .init(id: "karaage",     name: "唐揚げ",         assetName: "food_karaage",     rarity: .normal),
        .init(id: "nabe",        name: "お鍋",           assetName: "food_nabe",        rarity: .normal),
        .init(id: "onigiri",     name: "おにぎり",       assetName: "food_onigiri",     rarity: .normal),
        .init(id: "pan",         name: "パン",           assetName: "food_pan",         rarity: .normal),
        .init(id: "pizza",       name: "ピザ",           assetName: "food_pizza",       rarity: .normal),
        .init(id: "poteti",      name: "ポテトチップス", assetName: "food_poteti",      rarity: .normal),
        .init(id: "ra-men",      name: "ラーメン",       assetName: "food_ra-men",      rarity: .normal),
        .init(id: "sandowitch",  name: "サンドウィッチ", assetName: "food_sandowitch",  rarity: .normal),
        .init(id: "sarad",       name: "サラダ",         assetName: "food_sarad",       rarity: .normal),
        .init(id: "sute-ki",     name: "ステーキ",       assetName: "food_sute-ki",     rarity: .normal),
        .init(id: "yo-guruto",   name: "ヨーグルト",     assetName: "food_yo-guruto",   rarity: .normal),

        // R（ガチャ専用 / 幸せ度ボーナス対象）
        .init(id: "matsuzakaBeef", name: "松坂牛",             assetName: "food_matsuzakaBeef", rarity: .rare, happinessBonusPoints: 10),
        .init(id: "spinyLobster",  name: "伊勢海老",           assetName: "food_spinyLobster",  rarity: .rare, happinessBonusPoints: 10),
        .init(id: "shineMuscat",   name: "シャインマスカット", assetName: "food_shineMuscat",   rarity: .rare, happinessBonusPoints: 10),
        .init(id: "eel",           name: "鰻",                 assetName: "food_eel",           rarity: .rare, happinessBonusPoints: 10),
        .init(id: "snowCrab",      name: "ズワイガニ",         assetName: "food_snowCrab",      rarity: .rare, happinessBonusPoints: 10),
        .init(id: "otoro",         name: "大トロ",             assetName: "food_otoro",         rarity: .rare, happinessBonusPoints: 10),
        .init(id: "cantaloupe",    name: "マスクメロン",       assetName: "food_cantaloupe",    rarity: .rare, happinessBonusPoints: 10),
        .init(id: "matsutake",     name: "松茸",               assetName: "food_matsutake",     rarity: .rare, happinessBonusPoints: 10),
    ]

    /// フィッシュポイントショップ限定のSP一覧。
    static let specialItems: [FoodItem] = [
        .init(
            id: "yakiniku",
            name: "焼肉定食",
            assetName: "food_yakiniku",
            rarity: .special,
            happinessBonusPoints: 25,
            fillsFullnessToMaximum: true
        ),
    ]

    /// ホーム画面の所持ご飯一覧など、SPを含めて表示する箇所で使用する。
    static var allIncludingSpecial: [FoodItem] {
        all + specialItems
    }

    /// 既存のRご飯だけを返す。SPはチュートリアル用R候補へ混入させない。
    static var happinessRewardEligibleItems: [FoodItem] {
        all.filter { $0.rarity == .rare && $0.grantsHappinessBonus }
    }

    static func byId(_ id: String) -> FoodItem? {
        allIncludingSpecial.first { $0.id == id }
    }
}
