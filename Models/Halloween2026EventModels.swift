//
//  Halloween2026EventModels.swift
//  MeMo
//
//  Halloween 2026 の報酬・交換所・ランゲーム結果モデル。
//

import Foundation

enum HalloweenRewardTrack: String, CaseIterable, Identifiable, Codable {
    case highScore
    case totalDistance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highScore:
            return "ハイスコア"
        case .totalDistance:
            return "累計距離"
        }
    }
}

enum HalloweenRewardContent: Hashable, Codable {
    case candy(Int)
    case food(foodID: String, count: Int)
    case toilet(count: Int)
    case steps(Int)

    var displayName: String {
        switch self {
        case .candy(let count):
            return "キャンディ ×\(count)"
        case .food(let foodID, let count):
            let foodName = FoodCatalog.byId(foodID)?.name ?? "ごはん"
            return "\(foodName) ×\(count)"
        case .toilet(let count):
            return "トイレチケット ×\(count)"
        case .steps(let amount):
            return "\(amount)歩"
        }
    }

    var assetName: String? {
        switch self {
        case .food(let foodID, _):
            return FoodCatalog.byId(foodID)?.assetName
        case .toilet:
            return "wc"
        case .candy, .steps:
            return nil
        }
    }

    var systemImageName: String? {
        switch self {
        case .candy:
            return "birthday.cake.fill"
        case .steps:
            return "figure.walk"
        case .food, .toilet:
            return nil
        }
    }

    func multiplied(by quantity: Int) -> HalloweenRewardContent? {
        let safeQuantity = max(0, quantity)
        guard safeQuantity > 0 else { return nil }

        switch self {
        case .candy(let count):
            let (value, overflow) = count.multipliedReportingOverflow(by: safeQuantity)
            guard !overflow, value > 0 else { return nil }
            return .candy(value)

        case .food(let foodID, let count):
            let (value, overflow) = count.multipliedReportingOverflow(by: safeQuantity)
            guard !overflow, value > 0 else { return nil }
            return .food(foodID: foodID, count: value)

        case .toilet(let count):
            let (value, overflow) = count.multipliedReportingOverflow(by: safeQuantity)
            guard !overflow, value > 0 else { return nil }
            return .toilet(count: value)

        case .steps(let amount):
            let (value, overflow) = amount.multipliedReportingOverflow(by: safeQuantity)
            guard !overflow, value > 0 else { return nil }
            return .steps(value)
        }
    }
}

struct HalloweenDistanceReward: Identifiable, Hashable {
    let id: String
    let track: HalloweenRewardTrack
    let targetDistance: Int
    let reward: HalloweenRewardContent

    func currentDistance(in store: Halloween2026EventStore) -> Int {
        switch track {
        case .highScore:
            return store.bestDistance
        case .totalDistance:
            return store.totalDistance
        }
    }

    func isReached(in store: Halloween2026EventStore) -> Bool {
        currentDistance(in: store) >= targetDistance
    }

    func isClaimed(in store: Halloween2026EventStore) -> Bool {
        store.isRewardClaimed(id: id)
    }
}

enum Halloween2026RewardCatalog {
    static let highScoreRewards: [HalloweenDistanceReward] = [
        .init(id: "hs_0250", track: .highScore, targetDistance: 250, reward: .candy(10)),
        .init(id: "hs_0500", track: .highScore, targetDistance: 500, reward: .food(foodID: "onigiri", count: 1)),
        .init(id: "hs_1000", track: .highScore, targetDistance: 1_000, reward: .candy(25)),
        .init(id: "hs_1500", track: .highScore, targetDistance: 1_500, reward: .toilet(count: 1)),
        .init(id: "hs_2000", track: .highScore, targetDistance: 2_000, reward: .candy(50)),
        .init(id: "hs_3000", track: .highScore, targetDistance: 3_000, reward: .food(foodID: "shineMuscat", count: 1)),
        .init(id: "hs_5000", track: .highScore, targetDistance: 5_000, reward: .food(foodID: "yakiniku", count: 1)),
    ]

    static let totalDistanceRewards: [HalloweenDistanceReward] = [
        .init(id: "total_01000", track: .totalDistance, targetDistance: 1_000, reward: .candy(15)),
        .init(id: "total_03000", track: .totalDistance, targetDistance: 3_000, reward: .steps(300)),
        .init(id: "total_06000", track: .totalDistance, targetDistance: 6_000, reward: .candy(40)),
        .init(id: "total_10000", track: .totalDistance, targetDistance: 10_000, reward: .food(foodID: "cake", count: 2)),
        .init(id: "total_15000", track: .totalDistance, targetDistance: 15_000, reward: .toilet(count: 2)),
        .init(id: "total_25000", track: .totalDistance, targetDistance: 25_000, reward: .candy(120)),
        .init(id: "total_40000", track: .totalDistance, targetDistance: 40_000, reward: .food(foodID: "yakiniku", count: 1)),
    ]

    static func rewards(for track: HalloweenRewardTrack) -> [HalloweenDistanceReward] {
        switch track {
        case .highScore:
            return highScoreRewards
        case .totalDistance:
            return totalDistanceRewards
        }
    }

    static var allRewards: [HalloweenDistanceReward] {
        highScoreRewards + totalDistanceRewards
    }
}

struct HalloweenExchangeOffer: Identifiable, Hashable {
    let id: String
    let title: String
    let reward: HalloweenRewardContent
    let candyPrice: Int
    /// nil = 無制限。値あり = イベント期間中の最大交換回数。
    let maxExchangeCount: Int?

    var assetName: String? { reward.assetName }
    var systemImageName: String? { reward.systemImageName }
}

enum Halloween2026ExchangeCatalog {
    static let offers: [HalloweenExchangeOffer] = [
        .init(
            id: "exchange_onigiri",
            title: "おにぎり",
            reward: .food(foodID: "onigiri", count: 1),
            candyPrice: 15,
            maxExchangeCount: nil
        ),
        .init(
            id: "exchange_cake",
            title: "いちごケーキ",
            reward: .food(foodID: "cake", count: 1),
            candyPrice: 25,
            maxExchangeCount: nil
        ),
        .init(
            id: "exchange_otoro",
            title: "大トロ",
            reward: .food(foodID: "otoro", count: 1),
            candyPrice: 60,
            maxExchangeCount: nil
        ),
        .init(
            id: "exchange_wc",
            title: "トイレチケット",
            reward: .toilet(count: 1),
            candyPrice: 40,
            maxExchangeCount: nil
        ),
        .init(
            id: "exchange_steps_500",
            title: "500歩",
            reward: .steps(500),
            candyPrice: 80,
            maxExchangeCount: 10
        ),
        .init(
            id: "exchange_yakiniku",
            title: "焼肉定食",
            reward: .food(foodID: "yakiniku", count: 1),
            candyPrice: 150,
            maxExchangeCount: 3
        ),
    ]
}

struct HalloweenRunResult: Equatable {
    let distance: Int
    let candyCount: Int
}

enum HalloweenRunGameState: Equatable {
    case countdown(Int)
    case playing
    case gameOver
}
