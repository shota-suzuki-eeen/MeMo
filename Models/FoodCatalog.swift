//
//  FoodCatalog.swift
//  MeMo
//
//  Updated for gacha food integration and happiness bonus support.
//  Shop-related price handling removed because the shop feature has been discontinued.
//

import Foundation

enum FoodCatalog {
    struct FoodItem: Identifiable, Hashable {
        let id: String
        let name: String
        let assetName: String
        let isShopEligible: Bool
        let happinessBonusPoints: Int

        init(
            id: String,
            name: String,
            assetName: String,
            isShopEligible: Bool,
            happinessBonusPoints: Int = 0
        ) {
            self.id = id
            self.name = name
            self.assetName = assetName
            self.isShopEligible = isShopEligible
            self.happinessBonusPoints = max(0, happinessBonusPoints)
        }

        var grantsHappinessBonus: Bool {
            happinessBonusPoints > 0
        }
    }

    static let all: [FoodItem] = [
        // N（通常ご飯）
        .init(id: "barger",      name: "ハンバーガー",   assetName: "food_barger",      isShopEligible: true),
        .init(id: "beer",        name: "ビール",         assetName: "food_beer",        isShopEligible: true),
        .init(id: "cake",        name: "いちごケーキ",   assetName: "food_cake",        isShopEligible: true),
        .init(id: "carry",       name: "カレー",         assetName: "food_carry",       isShopEligible: true),
        .init(id: "coffee",      name: "コーヒー",       assetName: "food_coffee",      isShopEligible: true),
        .init(id: "coke",        name: "コーラ",         assetName: "food_coke",        isShopEligible: true),
        .init(id: "gyuudon",     name: "牛丼",           assetName: "food_gyuudon",     isShopEligible: true),
        .init(id: "icecream",    name: "ソフトクリーム", assetName: "food_icecream",    isShopEligible: true),
        .init(id: "karaage",     name: "唐揚げ",         assetName: "food_karaage",     isShopEligible: true),
        .init(id: "nabe",        name: "お鍋",           assetName: "food_nabe",        isShopEligible: true),
        .init(id: "onigiri",     name: "おにぎり",       assetName: "food_onigiri",     isShopEligible: true),
        .init(id: "pan",         name: "パン",           assetName: "food_pan",         isShopEligible: true),
        .init(id: "pizza",       name: "ピザ",           assetName: "food_pizza",       isShopEligible: true),
        .init(id: "poteti",      name: "ポテトチップス", assetName: "food_poteti",      isShopEligible: true),
        .init(id: "ra-men",      name: "ラーメン",       assetName: "food_ra-men",      isShopEligible: true),
        .init(id: "sandowitch",  name: "サンドウィッチ", assetName: "food_sandowitch",  isShopEligible: true),
        .init(id: "sarad",       name: "サラダ",         assetName: "food_sarad",       isShopEligible: true),
        .init(id: "sute-ki",     name: "ステーキ",       assetName: "food_sute-ki",     isShopEligible: true),
        .init(id: "yo-guruto",   name: "ヨーグルト",     assetName: "food_yo-guruto",   isShopEligible: true),

        // R（ガチャ専用 / 幸せ度ボーナス対象）
        .init(id: "matsuzakaBeef", name: "松坂牛",             assetName: "food_matsuzakaBeef", isShopEligible: false, happinessBonusPoints: 10),
        .init(id: "spinyLobster",  name: "伊勢海老",           assetName: "food_spinyLobster",  isShopEligible: false, happinessBonusPoints: 10),
        .init(id: "shineMuscat",   name: "シャインマスカット", assetName: "food_shineMuscat",   isShopEligible: false, happinessBonusPoints: 10),
        .init(id: "eel",           name: "鰻",                 assetName: "food_eel",           isShopEligible: false, happinessBonusPoints: 10),
        .init(id: "snowCrab",      name: "ズワイガニ",         assetName: "food_snowCrab",      isShopEligible: false, happinessBonusPoints: 10),
        .init(id: "otoro",         name: "大トロ",             assetName: "food_otoro",         isShopEligible: false, happinessBonusPoints: 10),
        .init(id: "cantaloupe",    name: "マスクメロン",       assetName: "food_cantaloupe",    isShopEligible: false, happinessBonusPoints: 10),
        .init(id: "matsutake",     name: "松茸",               assetName: "food_matsutake",     isShopEligible: false, happinessBonusPoints: 10),
    ]

    static var happinessRewardEligibleItems: [FoodItem] {
        all.filter(\.grantsHappinessBonus)
    }

    static func byId(_ id: String) -> FoodItem? {
        all.first { $0.id == id }
    }
}
