//
//  FoodCatalog.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation

enum FoodCatalog {
    struct FoodItem: Identifiable, Hashable {
        let id: String          // 安定ID（保存用）
        let name: String

        // NOTE:
        // 既存コード互換のためプロパティ名は残す。
        // 仕様上の意味は「販売価格（=消費する所持歩数）」。
        let priceKcal: Int

        let assetName: String

        var priceSteps: Int {
            max(0, priceKcal)
        }
    }

    static let all: [FoodItem] = [
        .init(id: "onigiri",     name: "おにぎり",       priceKcal: 190, assetName: "food_onigiri"),
        .init(id: "gyuudon",     name: "牛丼",           priceKcal: 650, assetName: "food_gyuudon"),
        .init(id: "karaage",     name: "唐揚げ",         priceKcal: 450, assetName: "food_karaage"),
        .init(id: "sandowitch",  name: "サンドウィッチ", priceKcal: 380, assetName: "food_sandowitch"),
        .init(id: "nabe",        name: "お鍋",           priceKcal: 500, assetName: "food_nabe"),
        .init(id: "barger",      name: "ハンバーガー",   priceKcal: 490, assetName: "food_barger"),
        .init(id: "ra-men",      name: "ラーメン",       priceKcal: 480, assetName: "food_ra-men"),
        .init(id: "sute-ki",     name: "ステーキ",       priceKcal: 550, assetName: "food_sute-ki"),
        .init(id: "pizza",       name: "ピザ",           priceKcal: 640, assetName: "food_pizza"),
        .init(id: "cake",        name: "ケーキ",         priceKcal: 480, assetName: "food_cake"),
        .init(id: "poteti",      name: "ポテトチップス", priceKcal: 325, assetName: "food_poteti"),
        .init(id: "icecream",    name: "ソフトクリーム", priceKcal: 250, assetName: "food_icecream"),
        .init(id: "coffee",      name: "コーヒー",       priceKcal: 8,   assetName: "food_coffee"),
        .init(id: "coke",        name: "コーラ",         priceKcal: 160, assetName: "food_coke"),
        .init(id: "carry",       name: "カレーライス",   priceKcal: 750, assetName: "food_carry"),
        .init(id: "sarad",       name: "サラダ",         priceKcal: 150, assetName: "food_sarad"),
        .init(id: "yo-guruto",   name: "ヨーグルト",     priceKcal: 56,  assetName: "food_yo-guruto"),
        .init(id: "pan",         name: "パン",           priceKcal: 150, assetName: "food_pan"),
        .init(id: "beer",        name: "ビール",         priceKcal: 135, assetName: "food_beer"),
    ]

    static func byId(_ id: String) -> FoodItem? {
        all.first { $0.id == id }
    }
}
