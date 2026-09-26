//
//  Halloween2026EventStore.swift
//  MeMo
//
//  Halloween 2026 の進捗をUserDefaultsへローカル保存するストア。
//  イベントIDをデータ内・保存キーの双方に保持し、他イベントと分離する。
//

import Foundation
import Combine

final class Halloween2026EventStore: ObservableObject {
    static let shared = Halloween2026EventStore()

    private struct Payload: Codable {
        var eventID: EventID = .halloween2026
        var bestDistance: Int = 0
        var totalDistance: Int = 0
        var candyCount: Int = 0
        var claimedRewardIDs: Set<String> = []
        var exchangedCounts: [String: Int] = [:]
    }

    private let defaults: UserDefaults
    private let storageKey = "memo.event.halloween2026.progress.v1"

    @Published private(set) var bestDistance: Int = 0
    @Published private(set) var totalDistance: Int = 0
    @Published private(set) var candyCount: Int = 0
    @Published private(set) var claimedRewardIDs: Set<String> = []
    @Published private(set) var exchangedCounts: [String: Int] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    var hasClaimableReward: Bool {
        Halloween2026RewardCatalog.allRewards.contains { reward in
            reward.isReached(in: self) && !reward.isClaimed(in: self)
        }
    }

    func recordRun(distance: Int, candy: Int) {
        let safeDistance = max(0, distance)
        let safeCandy = max(0, candy)

        bestDistance = max(bestDistance, safeDistance)
        totalDistance = totalDistance.addingClamped(safeDistance)
        candyCount = candyCount.addingClamped(safeCandy)
        save()
    }

    func addCandy(_ amount: Int) {
        let safeAmount = max(0, amount)
        guard safeAmount > 0 else { return }
        candyCount = candyCount.addingClamped(safeAmount)
        save()
    }

    @discardableResult
    func spendCandy(_ amount: Int) -> Bool {
        let safeAmount = max(0, amount)
        guard safeAmount > 0 else { return false }
        guard candyCount >= safeAmount else { return false }

        candyCount -= safeAmount
        save()
        return true
    }

    func isRewardClaimed(id: String) -> Bool {
        claimedRewardIDs.contains(id)
    }

    func markRewardClaimed(id: String) {
        claimedRewardIDs.insert(id)
        save()
    }

    func exchangeCount(for offerID: String) -> Int {
        max(0, exchangedCounts[offerID] ?? 0)
    }

    func registerExchange(offerID: String, quantity: Int) {
        let safeQuantity = max(0, quantity)
        guard safeQuantity > 0 else { return }

        let current = exchangeCount(for: offerID)
        exchangedCounts[offerID] = current.addingClamped(safeQuantity)
        save()
    }

    func maximumExchangeQuantity(for offer: HalloweenExchangeOffer) -> Int {
        let unitPrice = max(0, offer.candyPrice)
        guard unitPrice > 0 else { return 0 }

        var maximum = candyCount / unitPrice

        if let limit = offer.maxExchangeCount {
            let remaining = max(0, limit - exchangeCount(for: offer.id))
            maximum = min(maximum, remaining)
        }

        return max(0, maximum)
    }

    func nextReward(for track: HalloweenRewardTrack) -> HalloweenDistanceReward? {
        Halloween2026RewardCatalog.rewards(for: track).first { reward in
            !reward.isClaimed(in: self)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.eventID == .halloween2026
        else {
            return
        }

        bestDistance = max(0, payload.bestDistance)
        totalDistance = max(0, payload.totalDistance)
        candyCount = max(0, payload.candyCount)
        claimedRewardIDs = payload.claimedRewardIDs
        exchangedCounts = payload.exchangedCounts.mapValues { max(0, $0) }
    }

    private func save() {
        let payload = Payload(
            eventID: .halloween2026,
            bestDistance: bestDistance,
            totalDistance: totalDistance,
            candyCount: candyCount,
            claimedRewardIDs: claimedRewardIDs,
            exchangedCounts: exchangedCounts
        )

        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

private extension Int {
    func addingClamped(_ other: Int) -> Int {
        let (value, overflow) = addingReportingOverflow(other)
        return overflow ? Int.max : Swift.max(0, value)
    }
}
