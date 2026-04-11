//
//  FoodCatalog.swift
//  MeMo
//
//  Updated for gacha food integration and happiness bonus support.
//

import Foundation

enum FoodCatalog {
    struct FoodItem: Identifiable, Hashable {
        let id: String
        let name: String

        // NOTE:
        // 既存コード互換のためプロパティ名は維持する。
        // 仕様上の意味は「販売価格（=消費する所持歩数）」。
        let priceKcal: Int

        let assetName: String
        let isShopEligible: Bool
        let happinessBonusPoints: Int

        init(
            id: String,
            name: String,
            priceKcal: Int,
            assetName: String,
            isShopEligible: Bool,
            happinessBonusPoints: Int = 0
        ) {
            self.id = id
            self.name = name
            self.priceKcal = priceKcal
            self.assetName = assetName
            self.isShopEligible = isShopEligible
            self.happinessBonusPoints = max(0, happinessBonusPoints)
        }

        var priceSteps: Int {
            max(0, priceKcal)
        }

        var grantsHappinessBonus: Bool {
            happinessBonusPoints > 0
        }
    }

    static let all: [FoodItem] = [
        // N（ショップ対象）
        .init(id: "barger",      name: "ハンバーガー",   priceKcal: 490, assetName: "food_barger",      isShopEligible: true),
        .init(id: "beer",        name: "ビール",         priceKcal: 135, assetName: "food_beer",        isShopEligible: true),
        .init(id: "cake",        name: "いちごケーキ",   priceKcal: 480, assetName: "food_cake",        isShopEligible: true),
        .init(id: "carry",       name: "カレー",         priceKcal: 750, assetName: "food_carry",       isShopEligible: true),
        .init(id: "coffee",      name: "コーヒー",       priceKcal:   8, assetName: "food_coffee",      isShopEligible: true),
        .init(id: "coke",        name: "コーラ",         priceKcal: 160, assetName: "food_coke",        isShopEligible: true),
        .init(id: "gyuudon",     name: "牛丼",           priceKcal: 650, assetName: "food_gyuudon",     isShopEligible: true),
        .init(id: "icecream",    name: "ソフトクリーム", priceKcal: 250, assetName: "food_icecream",    isShopEligible: true),
        .init(id: "karaage",     name: "唐揚げ",         priceKcal: 450, assetName: "food_karaage",     isShopEligible: true),
        .init(id: "nabe",        name: "お鍋",           priceKcal: 500, assetName: "food_nabe",        isShopEligible: true),
        .init(id: "onigiri",     name: "おにぎり",       priceKcal: 190, assetName: "food_onigiri",     isShopEligible: true),
        .init(id: "pan",         name: "パン",           priceKcal: 150, assetName: "food_pan",         isShopEligible: true),
        .init(id: "pizza",       name: "ピザ",           priceKcal: 640, assetName: "food_pizza",       isShopEligible: true),
        .init(id: "poteti",      name: "ポテトチップス", priceKcal: 325, assetName: "food_poteti",      isShopEligible: true),
        .init(id: "ra-men",      name: "ラーメン",       priceKcal: 480, assetName: "food_ra-men",      isShopEligible: true),
        .init(id: "sandowitch",  name: "サンドウィッチ", priceKcal: 380, assetName: "food_sandowitch",  isShopEligible: true),
        .init(id: "sarad",       name: "サラダ",         priceKcal: 150, assetName: "food_sarad",       isShopEligible: true),
        .init(id: "sute-ki",     name: "ステーキ",       priceKcal: 550, assetName: "food_sute-ki",     isShopEligible: true),
        .init(id: "yo-guruto",   name: "ヨーグルト",     priceKcal:  56, assetName: "food_yo-guruto",   isShopEligible: true),

        // R（ガチャ専用 / 幸せ度ボーナス対象）
        .init(id: "matsuzakaBeef", name: "松坂牛",             priceKcal: 0, assetName: "food_matsuzakaBeef", isShopEligible: false, happinessBonusPoints: 10),
        .init(id: "spinyLobster",  name: "伊勢海老",           priceKcal: 0, assetName: "food_spinyLobster",  isShopEligible: false, happinessBonusPoints: 10),
        .init(id: "shineMuscat",   name: "シャインマスカット", priceKcal: 0, assetName: "food_shineMuscat",   isShopEligible: false, happinessBonusPoints: 10),
        .init(id: "eel",           name: "鰻",                 priceKcal: 0, assetName: "food_eel",           isShopEligible: false, happinessBonusPoints: 10),
        .init(id: "snowCrab",      name: "ズワイガニ",         priceKcal: 0, assetName: "food_snowCrab",      isShopEligible: false, happinessBonusPoints: 10),
        .init(id: "otoro",         name: "大トロ",             priceKcal: 0, assetName: "food_otoro",         isShopEligible: false, happinessBonusPoints: 10),
        .init(id: "cantaloupe",    name: "マスクメロン",       priceKcal: 0, assetName: "food_cantaloupe",    isShopEligible: false, happinessBonusPoints: 10),
        .init(id: "matsutake",     name: "松茸",               priceKcal: 0, assetName: "food_matsutake",     isShopEligible: false, happinessBonusPoints: 10),
    ]

    static var shopEligibleItems: [FoodItem] {
        all.filter(\.isShopEligible)
    }

    static var happinessRewardEligibleItems: [FoodItem] {
        all.filter(\.grantsHappinessBonus)
    }

    static func byId(_ id: String) -> FoodItem? {
        all.first { $0.id == id }
    }
}
