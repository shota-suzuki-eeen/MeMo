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
        var completedStageCount: Int = 0
        var endlessUnlocked: Bool = false
        var wallpaperGranted: Bool = false
        var activeSession: HalloweenRunSession? = nil
        var finalizedSessionIDs: Set<String> = []
        var gachaDrawProgress: Int = 0
        var gachaTotalDraws: Int = 0
        var srDayKey: String = ""
        var srDailyCounts: [String: Int] = [:]
        var eventAdDayKey: String = ""
        var usedEventAdSlots: Set<String> = []

        init() {}

        private enum CodingKeys: String, CodingKey {
            case eventID
            case bestDistance
            case totalDistance
            case candyCount
            case claimedRewardIDs
            case exchangedCounts
            case completedStageCount
            case endlessUnlocked
            case wallpaperGranted
            case activeSession
            case finalizedSessionIDs
            case gachaDrawProgress
            case gachaTotalDraws
            case srDayKey
            case srDailyCounts
            case eventAdDayKey
            case usedEventAdSlots
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            eventID = try values.decodeIfPresent(EventID.self, forKey: .eventID) ?? .halloween2026
            bestDistance = try values.decodeIfPresent(Int.self, forKey: .bestDistance) ?? 0
            totalDistance = try values.decodeIfPresent(Int.self, forKey: .totalDistance) ?? 0
            candyCount = try values.decodeIfPresent(Int.self, forKey: .candyCount) ?? 0
            claimedRewardIDs = try values.decodeIfPresent(Set<String>.self, forKey: .claimedRewardIDs) ?? []
            exchangedCounts = try values.decodeIfPresent([String: Int].self, forKey: .exchangedCounts) ?? [:]
            completedStageCount = try values.decodeIfPresent(Int.self, forKey: .completedStageCount) ?? 0
            endlessUnlocked = try values.decodeIfPresent(Bool.self, forKey: .endlessUnlocked) ?? false
            wallpaperGranted = try values.decodeIfPresent(Bool.self, forKey: .wallpaperGranted) ?? false
            activeSession = try values.decodeIfPresent(HalloweenRunSession.self, forKey: .activeSession)
            finalizedSessionIDs = try values.decodeIfPresent(Set<String>.self, forKey: .finalizedSessionIDs) ?? []
            gachaDrawProgress = try values.decodeIfPresent(Int.self, forKey: .gachaDrawProgress) ?? 0
            gachaTotalDraws = try values.decodeIfPresent(Int.self, forKey: .gachaTotalDraws) ?? 0
            srDayKey = try values.decodeIfPresent(String.self, forKey: .srDayKey) ?? ""
            srDailyCounts = try values.decodeIfPresent([String: Int].self, forKey: .srDailyCounts) ?? [:]
            eventAdDayKey = try values.decodeIfPresent(String.self, forKey: .eventAdDayKey) ?? ""
            usedEventAdSlots = try values.decodeIfPresent(Set<String>.self, forKey: .usedEventAdSlots) ?? []
        }
    }

    private let defaults: UserDefaults
    private let storageKey = "memo.event.halloween2026.progress.v1"

    @Published private(set) var bestDistance: Int = 0
    @Published private(set) var totalDistance: Int = 0
    @Published private(set) var candyCount: Int = 0
    @Published private(set) var claimedRewardIDs: Set<String> = []
    @Published private(set) var exchangedCounts: [String: Int] = [:]
    @Published private(set) var completedStageCount: Int = 0
    @Published private(set) var endlessUnlocked: Bool = false
    @Published private(set) var wallpaperGranted: Bool = false
    @Published private(set) var activeSession: HalloweenRunSession? = nil
    @Published private(set) var finalizedSessionIDs: Set<String> = []
    @Published private(set) var gachaDrawProgress: Int = 0
    @Published private(set) var gachaTotalDraws: Int = 0
    @Published private(set) var srDayKey: String = ""
    @Published private(set) var srDailyCounts: [String: Int] = [:]
    @Published private(set) var eventAdDayKey: String = ""
    @Published private(set) var usedEventAdSlots: Set<String> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        ensureCompletionWallpaper()
    }

    var currentStageNumber: Int { min(Halloween2026Configuration.stageCount, completedStageCount + 1) }

    var nextRunMode: HalloweenRunMode {
        endlessUnlocked ? .endless : (Halloween2026Configuration.isBonusStage(currentStageNumber) ? .bonus : .stage)
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

    /// Start authority is saved with the session, so an admitted run can finish after Nov 1.
    @discardableResult
    func beginSession(mode: HalloweenRunMode, at date: Date = Date()) -> HalloweenRunSession? {
        guard EventManager.isActive(.halloween2026, at: date), activeSession == nil else { return nil }
        if mode == .endless {
            guard endlessUnlocked else { return nil }
        } else {
            guard !endlessUnlocked else { return nil }
            let expectedMode: HalloweenRunMode = Halloween2026Configuration.isBonusStage(currentStageNumber) ? .bonus : .stage
            guard mode == expectedMode else { return nil }
        }
        let session = HalloweenRunSession(id: UUID().uuidString, mode: mode,
            stageNumber: mode == .endless ? nil : currentStageNumber,
            startedAt: date, distance: 0, candyCount: 0)
        activeSession = session
        save()
        return session
    }

    func checkpointSession(id: String, distance: Int, candy: Int) {
        guard var session = activeSession, session.id == id,
              !finalizedSessionIDs.contains(id) else { return }
        session.distance = max(session.distance, max(0, distance))
        let safeCandy = session.mode == .stage ? 0 : max(0, candy)
        session.candyCount = max(session.candyCount, session.mode == .bonus
            ? min(Halloween2026Configuration.bonusCandyLimit, safeCandy) : safeCandy)
        activeSession = session
        save()
    }

    /// One write contains the reward, stage advancement and idempotency marker.
    @discardableResult
    func finalizeSession(id: String, distance: Int, candy: Int, clearedStage: Bool = false) -> Bool {
        guard let session = activeSession, session.id == id,
              !finalizedSessionIDs.contains(id),
              EventManager.halloween2026.canFinishRun(startedAt: session.startedAt) else { return false }
        if session.mode == .endless {
            let safeDistance = max(session.distance, max(0, distance))
            bestDistance = max(bestDistance, safeDistance)
            totalDistance = totalDistance.addingClamped(safeDistance)
            candyCount = candyCount.addingClamped(max(session.candyCount, max(0, candy)))
        } else if clearedStage, session.stageNumber == currentStageNumber {
            let reward = session.mode == .bonus
                ? min(Halloween2026Configuration.bonusCandyLimit, max(session.candyCount, max(0, candy)))
                : Halloween2026Configuration.normalStageCandyReward
            candyCount = candyCount.addingClamped(reward)
            completedStageCount += 1
            endlessUnlocked = completedStageCount == Halloween2026Configuration.stageCount
        }
        finalizedSessionIDs.insert(id)
        activeSession = nil
        save()
        ensureCompletionWallpaper()
        return true
    }

    /// Progress is committed first. If termination occurs between the two writes,
    /// loading the completed progress repairs ownership without another reward.
    private func ensureCompletionWallpaper() {
        guard completedStageCount == Halloween2026Configuration.stageCount else { return }
        WallpaperCatalog.grantHalloween2026Wallpaper(defaults: defaults)
        if !wallpaperGranted {
            wallpaperGranted = true
            save()
        }
    }

    /// Only unfinished stage/bonus attempts are discarded; confirmed rewards stay intact.
    func discardStageSession(id: String) {
        guard let session = activeSession, session.id == id, session.mode != .endless else { return }
        activeSession = nil
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
        completedStageCount = min(Halloween2026Configuration.stageCount, max(0, payload.completedStageCount))
        endlessUnlocked = payload.endlessUnlocked || completedStageCount == Halloween2026Configuration.stageCount
        if endlessUnlocked { completedStageCount = Halloween2026Configuration.stageCount }
        wallpaperGranted = payload.wallpaperGranted
        finalizedSessionIDs = payload.finalizedSessionIDs
        activeSession = payload.activeSession
        if var session = activeSession {
            if finalizedSessionIDs.contains(session.id) {
                activeSession = nil
            } else {
                session.distance = max(0, session.distance)
                session.candyCount = max(0, session.candyCount)
                if session.mode == .stage { session.candyCount = 0 }
                if session.mode == .bonus { session.candyCount = min(Halloween2026Configuration.bonusCandyLimit, session.candyCount) }
                activeSession = session
            }
        }
        gachaDrawProgress = max(0, payload.gachaDrawProgress) % Halloween2026Configuration.lastOneInterval
        gachaTotalDraws = max(0, payload.gachaTotalDraws)
        srDayKey = payload.srDayKey
        srDailyCounts = payload.srDailyCounts.mapValues { max(0, $0) }
        eventAdDayKey = payload.eventAdDayKey
        usedEventAdSlots = payload.usedEventAdSlots
    }

    private func save() {
        var payload = Payload()
        payload.eventID = .halloween2026
        payload.bestDistance = bestDistance
        payload.totalDistance = totalDistance
        payload.candyCount = candyCount
        payload.claimedRewardIDs = claimedRewardIDs
        payload.exchangedCounts = exchangedCounts
        payload.completedStageCount = completedStageCount
        payload.endlessUnlocked = endlessUnlocked
        payload.wallpaperGranted = wallpaperGranted
        payload.activeSession = activeSession
        payload.finalizedSessionIDs = finalizedSessionIDs
        payload.gachaDrawProgress = gachaDrawProgress
        payload.gachaTotalDraws = gachaTotalDraws
        payload.srDayKey = srDayKey
        payload.srDailyCounts = srDailyCounts
        payload.eventAdDayKey = eventAdDayKey
        payload.usedEventAdSlots = usedEventAdSlots

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
