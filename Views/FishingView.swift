//
//  FishingView.swift
//  MeMo
//
//  放置釣り機能を提供する独立した釣り画面。
//

import SwiftUI
import UIKit
import MetalKit
import SpriteKit
import Combine
import QuartzCore

// MARK: - Fish catalog

enum FishRarity: String, Codable, CaseIterable, Hashable {
    case normal = "N"
    case rare = "R"
    case superRare = "SR"

    var displayName: String { rawValue }

    var accentColor: Color {
        switch self {
        case .normal:
            return Color(red: 0.28, green: 0.60, blue: 0.96)
        case .rare:
            return Color(red: 0.98, green: 0.47, blue: 0.24)
        case .superRare:
            return Color(red: 0.72, green: 0.34, blue: 0.96)
        }
    }
}

struct FishDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let rarity: FishRarity
    let pointValue: Int
    let assetName: String
    let drawWeight: Int
}

enum FishCatalog {
    static let all: [FishDefinition] = [
        FishDefinition(id: "medaka", name: "メダカ", rarity: .normal, pointValue: 1, assetName: "medaka", drawWeight: 28),
        FishDefinition(id: "funa", name: "フナ", rarity: .normal, pointValue: 2, assetName: "funa", drawWeight: 22),
        FishDefinition(id: "aji", name: "アジ", rarity: .normal, pointValue: 3, assetName: "aji", drawWeight: 17),
        FishDefinition(id: "saba", name: "サバ", rarity: .normal, pointValue: 4, assetName: "saba", drawWeight: 13),
        FishDefinition(id: "tai", name: "タイ", rarity: .rare, pointValue: 10, assetName: "tai", drawWeight: 9),
        FishDefinition(id: "maguro", name: "マグロ", rarity: .rare, pointValue: 15, assetName: "maguro", drawWeight: 6),
        FishDefinition(id: "gold", name: "金のコイ", rarity: .rare, pointValue: 20, assetName: "gold", drawWeight: 4),
        FishDefinition(id: "rainbow", name: "虹のアロワナ", rarity: .superRare, pointValue: 50, assetName: "rainbow", drawWeight: 1)
    ]

    static func fish(id: String) -> FishDefinition? {
        all.first(where: { $0.id == id })
    }

    static func drawRandomFish() -> FishDefinition {
        let totalWeight = max(1, all.reduce(0) { $0 + max(0, $1.drawWeight) })
        var value = Int.random(in: 0..<totalWeight)

        for fish in all {
            let weight = max(0, fish.drawWeight)
            if value < weight {
                return fish
            }
            value -= weight
        }

        return all[0]
    }
}

// MARK: - Fishing result models

struct FishingCatchSummary: Identifiable, Hashable {
    let fish: FishDefinition
    let count: Int

    var id: String { fish.id }
    var earnedPoints: Int { max(0, count) * max(0, fish.pointValue) }
}

struct FishingClaimResult: Identifiable, Hashable {
    let id = UUID()
    let summaries: [FishingCatchSummary]
    let previousPointBalance: Int
    let earnedPoints: Int
    let newPointBalance: Int
}

struct FishingSingleClaimResult: Identifiable, Hashable {
    let id = UUID()
    let fish: FishDefinition
    let previousPointBalance: Int
    let earnedPoints: Int
    let newPointBalance: Int
}

// MARK: - Fishing persistence

final class FishingStore: ObservableObject {
    static let shared = FishingStore()

    static let catchInterval: TimeInterval = 20 * 60
    static let maximumAwayDuration: TimeInterval = 8 * 60 * 60
    static let basketCapacity: Int = 20

    @Published private(set) var pointBalance: Int = 0
    @Published private(set) var pendingCounts: [String: Int] = [:]
    @Published private(set) var lifetimeCaughtCounts: [String: Int] = [:]
    @Published private(set) var firstCaughtDates: [String: Date] = [:]
    @Published private(set) var lastCalculatedAt: Date?

    private enum Key {
        static let pointBalance = "memo.fishing.pointBalance"
        static let pendingCounts = "memo.fishing.pendingCounts"
        static let lifetimeCaughtCounts = "memo.fishing.lifetimeCaughtCounts"
        static let firstCaughtDates = "memo.fishing.firstCaughtDates"
        static let lastCalculatedAt = "memo.fishing.lastCalculatedAt"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
        bootstrapIfNeeded(now: Date())
        refresh(now: Date())
    }

    var pendingCatchCount: Int {
        pendingCounts.values.reduce(0) { $0 + max(0, $1) }
    }

    var isBasketFull: Bool {
        pendingCatchCount >= Self.basketCapacity
    }

    var pendingEstimatedMinimumPoints: Int {
        pendingCounts.reduce(0) { partial, entry in
            guard let fish = FishCatalog.fish(id: entry.key) else { return partial }
            return partial + max(0, entry.value) * fish.pointValue
        }
    }

    func secondsUntilNextCatch(now: Date = Date()) -> TimeInterval? {
        guard !isBasketFull else { return nil }
        guard let lastCalculatedAt else { return Self.catchInterval }

        // lastCalculatedAt は釣果生成のたびに次の区間へ進む基準日時。
        // refresh前に境界を越えている場合は20:00へ巻き戻さず、0秒として表示する。
        let elapsed = max(0, now.timeIntervalSince(lastCalculatedAt))
        guard elapsed < Self.catchInterval else { return 0 }
        return max(0, Self.catchInterval - elapsed)
    }

    /// 次の釣果までの経過時間を進める。
    /// 画面タップ用だが、保存基準日時を更新するためアプリ終了後も短縮結果を維持する。
    /// 既に満杯の場合は釣りが停止しているため短縮しない。
    @discardableResult
    func shortenNextCatch(
        by seconds: TimeInterval = 1,
        now: Date = Date()
    ) -> Bool {
        let safeSeconds = max(0, seconds)
        guard safeSeconds > 0 else { return false }
        guard !isBasketFull else { return false }

        bootstrapIfNeeded(now: now)
        guard let lastCalculatedAt else { return false }

        self.lastCalculatedAt = lastCalculatedAt.addingTimeInterval(-safeSeconds)
        persist()
        refresh(now: now)
        return true
    }

    func refresh(now: Date = Date()) {
        bootstrapIfNeeded(now: now)
        guard !isBasketFull else { return }
        guard let lastCalculatedAt else { return }

        let rawElapsed = now.timeIntervalSince(lastCalculatedAt)
        if rawElapsed < 0 {
            self.lastCalculatedAt = now
            persist()
            return
        }

        let elapsed = min(rawElapsed, Self.maximumAwayDuration)
        let generatedCount = Int(elapsed / Self.catchInterval)
        guard generatedCount > 0 else { return }

        let availableSpace = max(0, Self.basketCapacity - pendingCatchCount)
        let actualCount = min(generatedCount, availableSpace)
        guard actualCount > 0 else { return }

        var nextCounts = pendingCounts
        for _ in 0..<actualCount {
            let fish = FishCatalog.drawRandomFish()
            nextCounts[fish.id, default: 0] += 1
        }

        pendingCounts = nextCounts

        if pendingCatchCount >= Self.basketCapacity {
            // 満杯以降の時間は報酬へ変換しない。受け取り時から釣りを再開する。
            self.lastCalculatedAt = now
        } else {
            self.lastCalculatedAt = lastCalculatedAt.addingTimeInterval(
                TimeInterval(actualCount) * Self.catchInterval
            )
        }

        persist()
    }

    /// 保留中の魚から1匹をランダムに選び、1匹分だけ受け取る。
    /// 満杯状態から受け取った場合は、その時点から次の20分計測を再開する。
    @discardableResult
    func claimOnePendingCatch(now: Date = Date()) -> FishingSingleClaimResult? {
        refresh(now: now)

        let totalCount = pendingCatchCount
        guard totalCount > 0 else { return nil }

        let wasBasketFull = isBasketFull
        var selectedIndex = Int.random(in: 0..<totalCount)
        var selectedFish: FishDefinition?

        for fish in FishCatalog.all {
            let count = max(0, pendingCounts[fish.id] ?? 0)
            guard count > 0 else { continue }

            if selectedIndex < count {
                selectedFish = fish
                break
            }
            selectedIndex -= count
        }

        guard let fish = selectedFish else { return nil }

        var nextPendingCounts = pendingCounts
        let remainingCount = max(0, (nextPendingCounts[fish.id] ?? 0) - 1)
        if remainingCount == 0 {
            nextPendingCounts.removeValue(forKey: fish.id)
        } else {
            nextPendingCounts[fish.id] = remainingCount
        }
        pendingCounts = nextPendingCounts

        let previousBalance = max(0, pointBalance)
        let earnedPoints = max(0, fish.pointValue)
        pointBalance = previousBalance + earnedPoints

        var nextLifetime = lifetimeCaughtCounts
        nextLifetime[fish.id, default: 0] += 1
        lifetimeCaughtCounts = nextLifetime

        if firstCaughtDates[fish.id] == nil {
            var nextFirstDates = firstCaughtDates
            nextFirstDates[fish.id] = now
            firstCaughtDates = nextFirstDates
        }

        if wasBasketFull {
            lastCalculatedAt = now
        }

        persist()

        return FishingSingleClaimResult(
            fish: fish,
            previousPointBalance: previousBalance,
            earnedPoints: earnedPoints,
            newPointBalance: pointBalance
        )
    }

    /// 旧UIとの互換性を維持するため、一括受取APIも残す。
    @discardableResult
    func claimPendingCatches(now: Date = Date()) -> FishingClaimResult? {
        refresh(now: now)
        guard pendingCatchCount > 0 else { return nil }

        let summaries = FishCatalog.all.compactMap { fish -> FishingCatchSummary? in
            let count = max(0, pendingCounts[fish.id] ?? 0)
            guard count > 0 else { return nil }
            return FishingCatchSummary(fish: fish, count: count)
        }

        let earnedPoints = summaries.reduce(0) { $0 + $1.earnedPoints }
        let previousBalance = max(0, pointBalance)
        pointBalance = previousBalance + max(0, earnedPoints)

        var nextLifetime = lifetimeCaughtCounts
        var nextFirstDates = firstCaughtDates

        for summary in summaries {
            nextLifetime[summary.fish.id, default: 0] += summary.count
            if nextFirstDates[summary.fish.id] == nil {
                nextFirstDates[summary.fish.id] = now
            }
        }

        lifetimeCaughtCounts = nextLifetime
        firstCaughtDates = nextFirstDates
        pendingCounts = [:]
        lastCalculatedAt = now
        persist()

        return FishingClaimResult(
            summaries: summaries,
            previousPointBalance: previousBalance,
            earnedPoints: earnedPoints,
            newPointBalance: pointBalance
        )
    }

    func isWallpaperUnlocked(assetName: String) -> Bool {
        assetName == WallpaperCatalog.defaultWallpaper.assetName
            || unlockedWallpaperAssetNames().contains(assetName)
    }

    @discardableResult
    func exchangeWallpaper(assetName: String, price: Int) -> Bool {
        let safePrice = max(0, price)
        guard safePrice > 0 else { return false }
        guard !isWallpaperUnlocked(assetName: assetName) else { return false }
        guard pointBalance >= safePrice else { return false }

        pointBalance -= safePrice

        var unlocked = unlockedWallpaperAssetNames()
        unlocked.insert(assetName)
        defaults.set(
            Array(unlocked).sorted(),
            forKey: WallpaperCatalog.focusUnlockedRewardAssetNamesKey
        )

        persist()
        return true
    }

    func lifetimeCaughtCount(fishID: String) -> Int {
        max(0, lifetimeCaughtCounts[fishID] ?? 0)
    }

    private func bootstrapIfNeeded(now: Date) {
        guard lastCalculatedAt == nil else { return }
        lastCalculatedAt = now
        persist()
    }

    private func unlockedWallpaperAssetNames() -> Set<String> {
        Set(defaults.stringArray(forKey: WallpaperCatalog.focusUnlockedRewardAssetNamesKey) ?? [])
    }

    private func load() {
        pointBalance = max(0, defaults.integer(forKey: Key.pointBalance))
        pendingCounts = decode([String: Int].self, key: Key.pendingCounts) ?? [:]
        lifetimeCaughtCounts = decode([String: Int].self, key: Key.lifetimeCaughtCounts) ?? [:]
        firstCaughtDates = decode([String: Date].self, key: Key.firstCaughtDates) ?? [:]
        lastCalculatedAt = defaults.object(forKey: Key.lastCalculatedAt) as? Date
    }

    private func persist() {
        defaults.set(max(0, pointBalance), forKey: Key.pointBalance)
        defaults.set(lastCalculatedAt, forKey: Key.lastCalculatedAt)
        encode(pendingCounts, key: Key.pendingCounts)
        encode(lifetimeCaughtCounts, key: Key.lifetimeCaughtCounts)
        encode(firstCaughtDates, key: Key.firstCaughtDates)
    }

    private func encode<T: Encodable>(_ value: T, key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}

// MARK: - Fishing screen

struct FishingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var bgmManager: BGMManager

    let state: AppState
    @ObservedObject var hk: HealthKitManager
    let onSave: () -> Void

    @ObservedObject private var fishingStore = FishingStore.shared

    @State private var showShop = false
    @State private var showFishingInformation = false
    @State private var floatingRewards: [FishingFloatingReward] = []
    @State private var tapShortenIndicators: [FishingTapShortenIndicator] = []
    @State private var continuousClaimTask: Task<Void, Never>?
    @State private var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled


    private var currentCharacterAssetName: String {
        PetMaster.assetName(for: state.normalizedCurrentPetID)
    }

    private var shouldAnimateLake: Bool {
        scenePhase == .active && !showShop && !showFishingInformation
    }

    private var preferredAnimationFramesPerSecond: Int {
        isLowPowerModeEnabled ? 20 : 30
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                FishingSceneryView(
                    isWaterActive: shouldAnimateLake,
                    preferredFramesPerSecond: preferredAnimationFramesPerSecond
                )

                FishingRodAndBobberView(
                    isActive: shouldAnimateLake,
                    preferredFramesPerSecond: preferredAnimationFramesPerSecond
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)

                // 操作UIより背面に専用タップ面を置く。
                // そのため魚かご・戻る・ショップ・説明の操作時には短縮処理が重複しない。
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                shortenFishingTimer(
                                    at: value.location,
                                    in: geo.size
                                )
                            }
                    )
                    .accessibilityHidden(true)
                    .zIndex(25)

                characterLayer(in: geo.size)

                ForEach(tapShortenIndicators) { indicator in
                    FishingTapShortenIndicatorView(indicator: indicator)
                        .position(indicator.position)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.72).combined(with: .opacity),
                                removal: .offset(y: -28).combined(with: .opacity)
                            )
                        )
                        .allowsHitTesting(false)
                        .zIndex(90)
                }

                interfaceLayer(in: geo)

                if showFishingInformation {
                    FishingInformationOverlay {
                        bgmManager.playSE(.push)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showFishingInformation = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(10_000)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .onAppear {
            isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
            bgmManager.switchBackground(to: .main)
            fishingStore.refresh(now: Date())
        }
        .onDisappear {
            stopContinuousClaiming()
            bgmManager.restoreDefaultBackground()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                stopContinuousClaiming()
                return
            }
            fishingStore.refresh(now: Date())
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .task {
            await runFishingCountdownRefreshLoop()
        }
        .fullScreenCover(isPresented: $showShop) {
            ShopView()
                .environmentObject(bgmManager)
                .memoIPadPresentedPhoneCanvas()
        }
    }

    private func characterLayer(in size: CGSize) -> some View {
        let height = min(max(size.width * 0.48, 150), 230)

        return FishingCharacterSpriteView(
            assetName: currentCharacterAssetName,
            baseAssetName: currentCharacterAssetName,
            isIdleEnabled: shouldAnimateLake,
            displayHeight: height,
            preferredFramesPerSecond: preferredAnimationFramesPerSecond
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, 6)
        .padding(.bottom, max(70, size.height * 0.075))
        .allowsHitTesting(false)
        .zIndex(30)
    }

    private func interfaceLayer(in geo: GeometryProxy) -> some View {
        let windowSafeAreaTop = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.top ?? 0
        let resolvedSafeAreaTop = max(geo.safeAreaInsets.top, windowSafeAreaTop)

        return VStack(spacing: 0) {
            topBar
                .padding(.top, max(resolvedSafeAreaTop, 54) + 30)
                .padding(.horizontal, 18)

            statusArea
                .padding(.top, 18)
                .padding(.horizontal, 18)

            Spacer()

            receiveArea
                .padding(.horizontal, 20)
                .padding(.bottom, max(geo.safeAreaInsets.bottom, 18) + 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .zIndex(100)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                bgmManager.playSE(.push)
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.42), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("ミーモのつりば")
                .font(.system(size: 21, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 6)
                .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                .allowsHitTesting(false)

            Spacer()

            Button {
                bgmManager.playSE(.push)
                showShop = true
            } label: {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.42), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("交換所")
        }
    }

    private var statusArea: some View {
        VStack(alignment: .trailing, spacing: 10) {
            pointBalancePill

            ZStack(alignment: .trailing) {
                // TimelineViewが表示時刻を直接供給するため、画面操作がなくても毎秒再描画される。
                // FishingStoreの更新通知とは独立してカウントダウン表示を進める。
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remainingSeconds = fishingStore.secondsUntilNextCatch(now: context.date) ?? 0

                    FishingNextCatchTimerView(
                        isBasketFull: fishingStore.isBasketFull,
                        timeText: Self.timeText(seconds: remainingSeconds),
                        remainingSeconds: remainingSeconds,
                        totalSeconds: FishingStore.catchInterval
                    )
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 44)

                Button {
                    bgmManager.playSE(.push)
                    stopContinuousClaiming()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showFishingInformation = true
                    }
                } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.black.opacity(0.42), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.32), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("釣りの説明")
            }
        }
    }

    /// ショップ画面の所持フィッシュpt表示と同じ形式。
    private var pointBalancePill: some View {
        HStack(spacing: 7) {
            Image(systemName: "fish.fill")
                .font(.system(size: 15, weight: .black))

            Text("\(fishingStore.pointBalance) pt")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background(Color.black.opacity(0.48), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.32), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("所持フィッシュポイント \(fishingStore.pointBalance)ポイント")
    }

    private var receiveArea: some View {
        ZStack(alignment: .bottom) {
            ForEach(floatingRewards) { reward in
                FishingFloatingRewardView(reward: reward)
                    .offset(x: reward.xOffset, y: reward.yOffset)
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            FishingBucketReceiveControl(
                caughtCount: fishingStore.pendingCatchCount,
                capacity: FishingStore.basketCapacity,
                onTap: claimOneFish,
                onLongPressBegan: startContinuousClaiming,
                onLongPressEnded: stopContinuousClaiming
            )
        }
        .frame(maxWidth: .infinity)
        // 獲得表示を円形メーターの上へ完全に逃がすため、
        // メーター上側に十分な表示領域を確保する。
        .frame(height: 285)
    }

    private func shortenFishingTimer(
        at location: CGPoint,
        in availableSize: CGSize
    ) {
        guard !showShop, !showFishingInformation else { return }
        guard !fishingStore.isBasketFull else { return }

        let shortenedSeconds = 1
        let date = Date()
        guard fishingStore.shortenNextCatch(
            by: TimeInterval(shortenedSeconds),
            now: date
        ) else {
            return
        }

        let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        feedbackGenerator.prepare()
        feedbackGenerator.impactOccurred(intensity: 0.72)

        // タップ地点を起点に、毎回少し異なる位置へ短縮秒数を表示する。
        // 画面端では文字が外へ逃げすぎないよう表示位置だけを制限する。
        let randomX = CGFloat.random(in: -38...38)
        let randomY = CGFloat.random(in: -34...24)
        let horizontalMargin: CGFloat = 30
        let verticalMargin: CGFloat = 24
        let indicatorPosition = CGPoint(
            x: min(
                max(location.x + randomX, horizontalMargin),
                max(horizontalMargin, availableSize.width - horizontalMargin)
            ),
            y: min(
                max(location.y + randomY, verticalMargin),
                max(verticalMargin, availableSize.height - verticalMargin)
            )
        )

        let indicator = FishingTapShortenIndicator(
            position: indicatorPosition,
            shortenedSeconds: shortenedSeconds
        )

        withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
            tapShortenIndicators.append(indicator)
            if tapShortenIndicators.count > 12 {
                tapShortenIndicators.removeFirst(tapShortenIndicators.count - 12)
            }
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 620_000_000)
            withAnimation(.easeOut(duration: 0.24)) {
                tapShortenIndicators.removeAll(where: { $0.id == indicator.id })
            }
        }
    }

    /// 表示用TimelineViewとは別に、釣果生成の判定を毎秒実行する。
    /// Timer.publishへ依存しないため、タップ操作がなくても釣果到達時に状態を更新できる。
    @MainActor
    private func runFishingCountdownRefreshLoop() async {
        while !Task.isCancelled {
            fishingStore.refresh(now: Date())

            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                return
            }
        }
    }

    private func claimOneFish() {
        guard let result = fishingStore.claimOnePendingCatch(now: Date()) else {
            stopContinuousClaiming()
            return
        }

        bgmManager.playSE(.push)

        let reward = FishingFloatingReward(
            result: result,
            xOffset: CGFloat.random(in: -62...62),
            // 円形メーター（174pt）の上端よりさらに上へ配置し、
            // 魚アセット・pt表示がメーターと重ならないようにする。
            yOffset: CGFloat.random(in: -250 ... -200)
        )

        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            floatingRewards.append(reward)
            if floatingRewards.count > 6 {
                floatingRewards.removeFirst(floatingRewards.count - 6)
            }
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            withAnimation(.easeOut(duration: 0.24)) {
                floatingRewards.removeAll(where: { $0.id == reward.id })
            }
        }

        if fishingStore.pendingCatchCount == 0 {
            stopContinuousClaiming()
        }
    }

    private func startContinuousClaiming() {
        guard continuousClaimTask == nil else { return }
        guard fishingStore.pendingCatchCount > 0 else { return }

        claimOneFish()
        guard fishingStore.pendingCatchCount > 0 else { return }

        continuousClaimTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                guard fishingStore.pendingCatchCount > 0 else {
                    continuousClaimTask = nil
                    return
                }
                claimOneFish()
            }
        }
    }

    private func stopContinuousClaiming() {
        continuousClaimTask?.cancel()
        continuousClaimTask = nil
    }

    private static func timeText(seconds: TimeInterval) -> String {
        let safe = max(0, Int(seconds.rounded(.up)))
        let minutes = safe / 60
        let remainingSeconds = safe % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Bucket receive UI

private struct FishingTapShortenIndicator: Identifiable, Hashable {
    let id = UUID()
    let position: CGPoint
    let shortenedSeconds: Int
}

private struct FishingTapShortenIndicatorView: View {
    let indicator: FishingTapShortenIndicator

    var body: some View {
        Text("-\(indicator.shortenedSeconds)秒")
            .font(.system(size: 17, weight: .black, design: .rounded))
            .foregroundStyle(.black)
            .monospacedDigit()
            .accessibilityHidden(true)
    }
}

private struct FishingFloatingReward: Identifiable, Hashable {
    let id = UUID()
    let result: FishingSingleClaimResult
    let xOffset: CGFloat
    let yOffset: CGFloat
}

private struct FishingBucketReceiveControl: View {
    let caughtCount: Int
    let capacity: Int
    let onTap: () -> Void
    let onLongPressBegan: () -> Void
    let onLongPressEnded: () -> Void

    @State private var didRecognizeLongPress = false

    private var safeCount: Int {
        min(max(0, caughtCount), max(1, capacity))
    }

    private var progress: CGFloat {
        CGFloat(safeCount) / CGFloat(max(1, capacity))
    }

    private var bucketAssetName: String {
        if safeCount == 0 {
            return "bucket"
        }
        if safeCount >= max(1, capacity) {
            return "bucket_full"
        }
        return "bucket_mid"
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.32), lineWidth: 9)
                .frame(width: 154, height: 154)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(red: 0.24, green: 0.82, blue: 1.00),
                            Color.white,
                            Color(red: 0.18, green: 0.68, blue: 0.96)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: progress)
                .frame(width: 154, height: 154)
                .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 2)

            Image(bucketAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 124, height: 124)
                .contentShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 6)

            Text("\(max(0, caughtCount))")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(minWidth: 31, minHeight: 31)
                .padding(.horizontal, caughtCount >= 100 ? 4 : 0)
                .background(Color.red, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.32), radius: 4, x: 0, y: 2)
                .offset(x: 57, y: -57)
        }
        .frame(width: 174, height: 174)
        .contentShape(Circle())
        .opacity(caughtCount > 0 ? 1 : 0.82)
        .scaleEffect(didRecognizeLongPress ? 0.96 : 1)
        .animation(.easeInOut(duration: 0.12), value: didRecognizeLongPress)
        .onTapGesture {
            guard !didRecognizeLongPress else { return }
            onTap()
        }
        .onLongPressGesture(
            minimumDuration: 0.35,
            maximumDistance: 55,
            pressing: { isPressing in
                if !isPressing {
                    onLongPressEnded()
                    // 長押し解除直後にTapGestureが発火して余分に1匹取得しないよう、
                    // フラグ解除をわずかに遅らせる。
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        didRecognizeLongPress = false
                    }
                }
            },
            perform: {
                didRecognizeLongPress = true
                onLongPressBegan()
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("釣れた魚を受け取る")
        .accessibilityValue("\(max(0, caughtCount))匹")
        .accessibilityHint("タップで1匹、長押しで連続して受け取ります")
    }
}

private struct FishingFloatingRewardView: View {
    let reward: FishingFloatingReward

    var body: some View {
        HStack(spacing: 8) {
            Image(reward.result.fish.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)

            Text("+\(reward.result.earnedPoints) pt")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.leading, 8)
        .padding(.trailing, 13)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.68), in: Capsule())
        .overlay(
            Capsule()
                .stroke(reward.result.fish.rarity.accentColor.opacity(0.92), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.28), radius: 7, x: 0, y: 4)
    }
}

private struct FishingInformationOverlay: View {
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.60)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)

                VStack(spacing: 14) {
                    HStack {
                        Text("釣りの遊び方")
                            .font(.system(size: 23, weight: .black, design: .rounded))

                        Spacer()

                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(.primary)
                                .frame(width: 34, height: 34)
                                .background(Color.black.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(Color(red: 0.10, green: 0.63, blue: 0.88))

                        Text("魚かごは、タップすると1匹ずつ受け取れます。\n長押しすると連続で受け取れます。")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(13)
                    .background(Color.black.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "timer")
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(Color(red: 0.98, green: 0.47, blue: 0.24))

                        Text("魚かご以外の画面をタップすると、次の釣果までの時間を短縮できます。")
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(13)
                    .background(Color.black.opacity(0.055), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text("魚の種類と獲得ポイント")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 9) {
                            ForEach(FishCatalog.all) { fish in
                                FishingInformationFishRow(fish: fish)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(18)
                .frame(maxWidth: 430)
                .frame(maxHeight: min(geo.size.height * 0.82, 690))
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.32), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.32), radius: 24, x: 0, y: 14)
                .padding(.horizontal, 18)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

private struct FishingInformationFishRow: View {
    let fish: FishDefinition

    var body: some View {
        HStack(spacing: 12) {
            Image(fish.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .padding(4)
                .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(fish.name)
                    .font(.system(size: 16, weight: .black, design: .rounded))

                Text(fish.rarity.displayName)
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(fish.rarity.accentColor, in: Capsule())
            }

            Spacer(minLength: 8)

            Text("+\(fish.pointValue) pt")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(fish.rarity.accentColor.opacity(0.24), lineWidth: 1)
        )
    }
}

// MARK: - Fishing scene views

private struct FishingNextCatchTimerView: View {
    let isBasketFull: Bool
    let timeText: String
    let remainingSeconds: TimeInterval
    let totalSeconds: TimeInterval

    private var title: String {
        isBasketFull ? "釣りは停止中" : "次の釣果まで"
    }

    private var displayedValue: String {
        isBasketFull ? "満杯" : timeText
    }

    /// 20分から0秒へ向かって減少する、カウントダウンの残量。
    private var countdownProgress: CGFloat {
        guard !isBasketFull else { return 1 }

        let safeTotal = max(1, totalSeconds)
        let normalized = remainingSeconds / safeTotal
        return CGFloat(min(max(normalized, 0), 1))
    }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: isBasketFull ? "pause.fill" : "timer")
                    .font(.system(size: 14, weight: .black))

                Text(title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.98))

            ClayTimerText(text: displayedValue)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.20))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.96),
                                    Color(red: 0.36, green: 0.86, blue: 1.00)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * countdownProgress)
                }
            }
            .frame(height: 7)
            .opacity(isBasketFull ? 0.48 : 1)
            .animation(.linear(duration: 0.20), value: countdownProgress)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: 260, minHeight: 110)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.61, blue: 0.94),
                    Color(red: 0.04, green: 0.29, blue: 0.68)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 25, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(Color.white.opacity(0.48), lineWidth: 1.2)
        }
        .shadow(color: Color(red: 0.01, green: 0.14, blue: 0.36).opacity(0.42), radius: 11, x: 0, y: 7)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) 残り\(displayedValue)")
    }
}

/// 丸い太字・下側の厚み・表面の光沢を重ね、青い粘土を盛ったように見せる。
private struct ClayTimerText: View {
    let text: String

    var body: some View {
        ZStack {
            Text(text)
                .foregroundStyle(Color(red: 0.01, green: 0.13, blue: 0.36))
                .offset(y: 5)

            Text(text)
                .foregroundStyle(Color(red: 0.04, green: 0.34, blue: 0.73))
                .offset(y: 2)

            Text(text)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.78, green: 0.96, blue: 1.00),
                            Color(red: 0.23, green: 0.72, blue: 0.98)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .white.opacity(0.68), radius: 0.8, x: 0, y: -1.5)
                .shadow(color: Color(red: 0.01, green: 0.12, blue: 0.34).opacity(0.48), radius: 2.5, x: 0, y: 2)
        }
        .font(.system(size: 48, weight: .black, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.62)
    }
}

private struct FishingSceneryView: View {
    let isWaterActive: Bool
    let preferredFramesPerSecond: Int

    private enum Layout {
        // fishing_background / fishing_lake は同一キャンバス前提。
        // 上側40.5%は空・山・森で、水面描画対象外としてMTKView自体を配置しない。
        // fishing_lake は実際の水面として描画し、同じ画像から境界マスクも生成する。
        static let lakeTopRatio: CGFloat = 0.405

        // fishing_lakeレイヤー全体の縦位置。
        // 負の値ほど上方向、正の値ほど下方向へ移動する。
        static let lakeVerticalOffset: CGFloat = -16
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Image("fishing_background")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: geo.size.height * Layout.lakeTopRatio)

                    FishingLakeMetalView(
                        isActive: isWaterActive,
                        preferredFramesPerSecond: preferredFramesPerSecond,
                        lakeTopRatio: Float(Layout.lakeTopRatio)
                    )
                    .frame(height: geo.size.height * (1 - Layout.lakeTopRatio))
                    .offset(y: Layout.lakeVerticalOffset)
                    .zIndex(20)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}

// 釣り画面専用。ホーム用CharacterSpriteViewの60fps設定は変更せず、
// 釣り中だけ30fps（低電力モードは20fps）で同じSceneを利用する。
@MainActor
private struct FishingCharacterSpriteView: View {
    let assetName: String
    let baseAssetName: String
    let isIdleEnabled: Bool
    let displayHeight: CGFloat
    let preferredFramesPerSecond: Int

    @State private var scene = CharacterSpriteScene(size: CGSize(width: 512, height: 512))

    private let canvasScale: CGFloat = 1.12

    private var configuration: CharacterSpriteScene.Configuration {
        CharacterSpriteScene.Configuration(
            assetName: assetName,
            baseAssetName: baseAssetName,
            isIdleEnabled: isIdleEnabled,
            visualHeight: max(1, displayHeight)
        )
    }

    private var baseAspectRatio: CGFloat {
        let image = UIImage(named: baseAssetName) ?? UIImage(named: assetName)
        guard let image, image.size.height > 0 else { return 1 }
        return image.size.width / image.size.height
    }

    var body: some View {
        SpriteView(
            scene: scene,
            preferredFramesPerSecond: max(1, preferredFramesPerSecond),
            options: [.allowsTransparency]
        )
        .frame(
            width: max(1, displayHeight * baseAspectRatio * canvasScale),
            height: max(1, displayHeight * canvasScale)
        )
        .onAppear {
            scene.apply(configuration)
        }
        .onChange(of: configuration) { _, newConfiguration in
            scene.apply(newConfiguration)
        }
        .onDisappear {
            scene.stopAllAnimation()
        }
        .accessibilityHidden(true)
    }
}

/// 釣り竿・ウキを画像アセットで表示する釣り画面専用レイヤー。
/// 糸は描画せず、ウキは下側をマスクして水中へ沈んでいるように見せる。
private struct FishingRodAndBobberView: View {
    let isActive: Bool
    let preferredFramesPerSecond: Int

    private enum Layout {
        // キャラクターの右手付近に竿の持ち手が来るよう、全体を右下へ寄せる。
        // 併せて竿・ウキともにさらに小さく表示する。
        static let rodWidthRatio: CGFloat = 0.24
        static let rodCenterXRatio: CGFloat = 0.32
        static let rodCenterYRatio: CGFloat = 0.72

        static let bobberWidthRatio: CGFloat = 0.048
        static let bobberCenterXRatio: CGFloat = 0.68
        static let bobberWaterlineYRatio: CGFloat = 0.69

        // アセット比率は初回だけ取得し、TimelineViewのフレーム更新ごとの画像参照を避ける。
        static let bobberAspectRatio: CGFloat = {
            guard let image = UIImage(named: "bobber"), image.size.width > 0 else { return 1 }
            return image.size.height / image.size.width
        }()

        // 上側62%だけを見せ、下側38%は水面より下へ沈んでいる扱いにする。
        static let bobberVisibleRatio: CGFloat = 0.62
    }

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / Double(max(1, preferredFramesPerSecond)),
                paused: !isActive
            )
        ) { timeline in
            GeometryReader { geo in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let activeTime = isActive ? time : 0

                let verticalBob = CGFloat(sin(activeTime * 1.85)) * 2.8
                let horizontalDrift = CGFloat(sin(activeTime * 0.82 + 0.7)) * 1.2
                let rotation = Double(sin(activeTime * 1.25 + 0.45)) * 1.35
                let rippleScale = 1 + CGFloat(sin(activeTime * 1.85)) * 0.045

                let rodWidth = min(max(geo.size.width * Layout.rodWidthRatio, 92), 175)
                let bobberWidth = min(max(geo.size.width * Layout.bobberWidthRatio, 16), 26)
                let bobberHeight = bobberWidth * Layout.bobberAspectRatio
                let visibleBobberHeight = bobberHeight * Layout.bobberVisibleRatio
                let bobberX = geo.size.width * Layout.bobberCenterXRatio + horizontalDrift
                let waterlineY = geo.size.height * Layout.bobberWaterlineYRatio

                ZStack {
                    Image("fishingRod")
                        .resizable()
                        .scaledToFit()
                        .frame(width: rodWidth)
                        .position(
                            x: geo.size.width * Layout.rodCenterXRatio,
                            y: geo.size.height * Layout.rodCenterYRatio
                        )
                        .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)

                    // 波紋は水面位置に固定し、ウキ本体だけがわずかに上下する。
                    Ellipse()
                        .stroke(Color.white.opacity(0.30), lineWidth: 1.1)
                        .frame(width: bobberWidth * 1.28, height: max(4, bobberWidth * 0.20))
                        .scaleEffect(x: rippleScale, y: 1)
                        .position(x: bobberX, y: waterlineY)

                    Image("bobber")
                        .resizable()
                        .scaledToFit()
                        .frame(width: bobberWidth, height: bobberHeight)
                        .rotationEffect(.degrees(rotation), anchor: .bottom)
                        .offset(y: verticalBob)
                        .frame(
                            width: bobberWidth * 1.22,
                            height: visibleBobberHeight,
                            alignment: .top
                        )
                        .clipped()
                        .position(
                            x: bobberX,
                            y: waterlineY - (visibleBobberHeight / 2)
                        )
                        .shadow(color: .black.opacity(0.22), radius: 2.5, x: 0, y: 1.5)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Metal lake water

/// fishing_lake を実際の水面テクスチャとして最前面に表示し、画像そのものをShaderで揺らす。
/// 表示範囲には透過PNG本来のアルファだけを使い、CPU生成マスクや色判定は行わない。
///
/// 負荷対策:
/// - MTKViewは湖が存在する画面下部だけに配置する。
/// - 1パス描画、30fps（低電力モード20fps）。
/// - 透明部分はfragmentを破棄して合成対象を限定する。
/// - バックグラウンド、説明表示、交換所では描画を停止する。
private struct FishingLakeMetalView: UIViewRepresentable {
    let isActive: Bool
    let preferredFramesPerSecond: Int
    let lakeTopRatio: Float

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.isOpaque = false
        view.backgroundColor = .clear
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.contentScaleFactor = min(UIScreen.main.scale, 2.0)
        view.framebufferOnly = true
        view.autoResizeDrawable = true

        // MTKView任せの連続描画では端末やView階層によって更新が止まるケースがあったため、
        // CADisplayLinkから必要なフレームだけ明示的にdraw()する。
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.preferredFramesPerSecond = max(1, preferredFramesPerSecond)

        context.coordinator.attach(
            to: view,
            lakeTopRatio: lakeTopRatio,
            isActive: isActive,
            preferredFramesPerSecond: preferredFramesPerSecond
        )
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.update(
            view: uiView,
            lakeTopRatio: lakeTopRatio,
            isActive: isActive,
            preferredFramesPerSecond: preferredFramesPerSecond
        )
    }

    static func dismantleUIView(_ uiView: MTKView, coordinator: Coordinator) {
        coordinator.stop()
        uiView.isPaused = true
        uiView.delegate = nil
        coordinator.renderer = nil
    }

    final class Coordinator: NSObject {
        var renderer: FishingLakeRenderer?

        private weak var view: MTKView?
        private var displayLink: CADisplayLink?
        private var isActive = false
        private var preferredFramesPerSecond = 30

        func attach(
            to view: MTKView,
            lakeTopRatio: Float,
            isActive: Bool,
            preferredFramesPerSecond: Int
        ) {
            self.view = view
            renderer = FishingLakeRenderer(
                view: view,
                lakeAssetName: "fishing_lake",
                lakeTopRatio: lakeTopRatio
            )
            view.delegate = renderer
            configureDisplayLinkIfNeeded()
            update(
                view: view,
                lakeTopRatio: lakeTopRatio,
                isActive: isActive,
                preferredFramesPerSecond: preferredFramesPerSecond
            )
        }

        func update(
            view: MTKView,
            lakeTopRatio: Float,
            isActive: Bool,
            preferredFramesPerSecond: Int
        ) {
            self.view = view
            self.isActive = isActive
            self.preferredFramesPerSecond = max(1, preferredFramesPerSecond)
            renderer?.lakeTopRatio = lakeTopRatio

            view.preferredFramesPerSecond = self.preferredFramesPerSecond
            displayLink?.preferredFramesPerSecond = self.preferredFramesPerSecond
            displayLink?.isPaused = !isActive

            // 停止時にも現在の静止水面を一度だけ表示する。
            if !isActive {
                view.draw()
            }
        }

        func stop() {
            displayLink?.invalidate()
            displayLink = nil
            view = nil
        }

        private func configureDisplayLinkIfNeeded() {
            guard displayLink == nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
            link.preferredFramesPerSecond = preferredFramesPerSecond
            link.isPaused = true
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        @objc
        private func displayLinkDidFire(_ link: CADisplayLink) {
            guard isActive, let view, view.window != nil else { return }
            view.draw()
        }

        deinit {
            displayLink?.invalidate()
        }
    }
}

private final class FishingLakeRenderer: NSObject, MTKViewDelegate {
    var lakeTopRatio: Float

    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let lakeTexture: MTLTexture
    private let colorSamplerState: MTLSamplerState
    private let startedAt = CACurrentMediaTime()

    init?(
        view: MTKView,
        lakeAssetName: String,
        lakeTopRatio: Float
    ) {
        guard
            let device = view.device,
            let commandQueue = device.makeCommandQueue(),
            let lakeImage = UIImage(named: lakeAssetName)?.cgImage,
            let library = try? device.makeLibrary(source: Self.shaderSource, options: nil),
            let vertexFunction = library.makeFunction(name: "fishingLakeVertex"),
            let fragmentFunction = library.makeFunction(name: "fishingLakeFragment")
        else {
            return nil
        }

        let textureLoader = MTKTextureLoader(device: device)
        let colorOptions: [MTKTextureLoader.Option: Any] = [
            .SRGB: true,
            .origin: MTKTextureLoader.Origin.topLeft,
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue)
        ]

        guard let lakeTexture = try? textureLoader.newTexture(
            cgImage: lakeImage,
            options: colorOptions
        ) else {
            return nil
        }

        let colorSamplerDescriptor = MTLSamplerDescriptor()
        colorSamplerDescriptor.minFilter = .linear
        colorSamplerDescriptor.magFilter = .linear
        colorSamplerDescriptor.mipFilter = .notMipmapped
        colorSamplerDescriptor.sAddressMode = .clampToZero
        colorSamplerDescriptor.tAddressMode = .clampToZero

        guard let colorSamplerState = device.makeSamplerState(descriptor: colorSamplerDescriptor) else {
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat

        if let attachment = descriptor.colorAttachments[0] {
            attachment.isBlendingEnabled = true
            attachment.rgbBlendOperation = .add
            attachment.alphaBlendOperation = .add

            // fishing_lakeのプリマルチプライドアルファをそのまま合成する。
            // RGBへ再度alphaを掛けないため、透明境界の黒化や水色の縁を防げる。
            attachment.sourceRGBBlendFactor = .one
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
            attachment.sourceAlphaBlendFactor = .one
            attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }

        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            return nil
        }

        self.commandQueue = commandQueue
        self.pipelineState = pipelineState
        self.lakeTexture = lakeTexture
        self.colorSamplerState = colorSamplerState
        self.lakeTopRatio = lakeTopRatio
        super.init()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard
            let drawable = view.currentDrawable,
            let passDescriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
        else {
            return
        }

        var time = Float(CACurrentMediaTime() - startedAt)

        // SwiftUIのscaledToFillと同じUV範囲を計算する。
        // MTKViewは湖が存在する下側だけに配置しているため、全画面高を逆算する。
        let safeTopRatio = min(max(lakeTopRatio, 0), 0.95)
        let lakeHeight = Float(max(view.drawableSize.height, 1))
        let fullViewHeight = lakeHeight / max(1 - safeTopRatio, 0.05)
        let fullViewWidth = Float(max(view.drawableSize.width, 1))
        let textureWidth = Float(max(lakeTexture.width, 1))
        let textureHeight = Float(max(lakeTexture.height, 1))

        let fillScale = max(fullViewWidth / textureWidth, fullViewHeight / textureHeight)
        let scaledWidth = textureWidth * fillScale
        let scaledHeight = textureHeight * fillScale
        let cropU = max(0, (scaledWidth - fullViewWidth) / (2 * scaledWidth))
        let cropV = max(0, (scaledHeight - fullViewHeight) / (2 * scaledHeight))
        let visibleU = max(0, 1 - (cropU * 2))
        let visibleV = max(0, 1 - (cropV * 2))

        var uvMinimum = SIMD2<Float>(
            cropU,
            cropV + (safeTopRatio * visibleV)
        )
        var uvMaximum = SIMD2<Float>(
            cropU + visibleU,
            cropV + visibleV
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentTexture(lakeTexture, index: 0)
        encoder.setFragmentSamplerState(colorSamplerState, index: 0)
        encoder.setFragmentBytes(&time, length: MemoryLayout<Float>.size, index: 0)
        encoder.setFragmentBytes(&uvMinimum, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
        encoder.setFragmentBytes(&uvMaximum, length: MemoryLayout<SIMD2<Float>>.size, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private static let shaderSource = #"""
    #include <metal_stdlib>
    using namespace metal;

    struct FishingLakeVertexOut {
        float4 position [[position]];
        float2 uv;
    };

    vertex FishingLakeVertexOut fishingLakeVertex(uint vertexID [[vertex_id]]) {
        float2 positions[3] = {
            float2(-1.0, -1.0),
            float2( 3.0, -1.0),
            float2(-1.0,  3.0)
        };

        float2 uvs[3] = {
            float2(0.0, 1.0),
            float2(2.0, 1.0),
            float2(0.0, -1.0)
        };

        FishingLakeVertexOut out;
        out.position = float4(positions[vertexID], 0.0, 1.0);
        out.uv = uvs[vertexID];
        return out;
    }

    float3 directionalWave(
        float2 point,
        float2 direction,
        float frequency,
        float amplitude,
        float speed,
        float time,
        float phaseOffset
    ) {
        float phase = dot(point, direction) * frequency + time * speed + phaseOffset;
        float sineValue = sin(phase);
        float cosineValue = cos(phase);
        float derivative = cosineValue * amplitude * frequency;

        return float3(
            sineValue * amplitude,
            derivative * direction.x,
            derivative * direction.y
        );
    }

    float3 lakeSurface(float2 localUV, float time) {
        float depth = saturate(localUV.y);
        float perspectiveY = log(1.0 + depth * 3.1);
        float2 point = float2(localUV.x * 6.6, perspectiveY * 4.7);

        float3 surface = float3(0.0);
        surface += directionalWave(point, float2(0.985, 0.174), 0.60, 0.165, 0.48, time, 0.20);
        surface += directionalWave(point, float2(-0.458, 0.889), 0.92, 0.090, -0.37, time, 1.35);
        surface += directionalWave(point, float2(0.721, 0.693), 1.48, 0.043, 0.64, time, 2.10);
        surface += directionalWave(point, float2(-0.936, 0.352), 2.50, 0.017, -0.83, time, 0.75);

        // 大きな面が透明な布のようにゆっくりたわむ成分。
        float clothA = sin(localUV.x * 5.0 + time * 0.68 + sin(localUV.y * 3.8 - time * 0.25) * 0.52);
        float clothB = sin(localUV.x * 2.1 - localUV.y * 5.0 - time * 0.42);
        surface.x += (clothA * 0.052 + clothB * 0.026) * mix(0.42, 1.0, depth);
        surface.y += clothA * 0.034;
        surface.z += clothB * 0.023;
        return surface;
    }

    float3 straightColorFromPremultiplied(half4 sampleValue) {
        float alpha = float(sampleValue.a);
        if (alpha <= 0.0001) {
            return float3(0.0);
        }
        return float3(sampleValue.rgb) / alpha;
    }

    fragment half4 fishingLakeFragment(
        FishingLakeVertexOut in [[stage_in]],
        texture2d<half, access::sample> lakeTexture [[texture(0)]],
        sampler colorSampler [[sampler(0)]],
        constant float &time [[buffer(0)]],
        constant float2 &uvMinimum [[buffer(1)]],
        constant float2 &uvMaximum [[buffer(2)]]
    ) {
        float2 localUV = saturate(in.uv);
        float2 sourceUV = mix(uvMinimum, uvMaximum, localUV);

        // 元PNGのアルファを唯一の表示範囲として使う。
        // CPU生成マスクや色判定は一切行わない。
        half4 originalSample = lakeTexture.sample(colorSampler, sourceUV);
        float originalAlpha = float(originalSample.a);
        if (originalAlpha <= 0.001) {
            discard_fragment();
        }

        float depth = saturate(localUV.y);
        float3 surface = lakeSurface(localUV, time);
        float2 slope = surface.yz;
        float3 normal = normalize(float3(-slope.x * 0.22, -slope.y * 0.12, 1.0));

        // 半透明の輪郭付近は固定し、完全に不透明な湖内部だけを大きく動かす。
        float interiorStrength = smoothstep(0.12, 0.92, originalAlpha);

        float broadWave = surface.x * mix(0.032, 0.088, depth);
        float mediumWave = sin(
            localUV.x * 12.0
            + localUV.y * 4.5
            - time * 0.96
            + sin(localUV.y * 7.4 + time * 0.32) * 0.55
        ) * mix(0.0035, 0.0115, depth);
        float verticalWave = (
            sin(localUV.x * 7.0 + time * 0.76 + localUV.y * 2.4) * 0.0032
            + sin(localUV.x * 3.0 - time * 0.40) * 0.0018
        ) * mix(0.40, 1.0, depth);

        float2 displacement = float2(
            broadWave + mediumWave + normal.x * mix(0.0015, 0.0054, depth),
            verticalWave + normal.y * mix(0.0003, 0.00125, depth)
        ) * interiorStrength;

        float2 candidateUV = clamp(
            sourceUV + displacement,
            uvMinimum + float2(0.0025),
            uvMaximum - float2(0.0025)
        );

        // 変位先が透明領域なら元座標へ戻す。
        // 透明ピクセルの黒RGBを湖へ引き込まない。
        half4 candidateSample = lakeTexture.sample(colorSampler, candidateUV);
        float candidateAlpha = float(candidateSample.a);
        float candidateStrength = smoothstep(0.08, 0.65, candidateAlpha);
        float2 animatedUV = mix(sourceUV, candidateUV, candidateStrength * interiorStrength);

        float horizontalSpread = mix(0.0006, 0.0020, depth) * interiorStrength;
        float2 spreadAxis = float2(horizontalSpread, normal.y * horizontalSpread * 0.18);

        half4 centerSample = lakeTexture.sample(colorSampler, animatedUV);
        half4 leftSample = lakeTexture.sample(colorSampler, animatedUV - spreadAxis);
        half4 rightSample = lakeTexture.sample(colorSampler, animatedUV + spreadAxis);

        // 透明境界のRGBを直接平均せず、プリマルチプライド状態で加重平均する。
        float centerWeight = 0.50;
        float sideWeight = 0.25;
        float sampledAlpha = (
            float(centerSample.a) * centerWeight
            + float(leftSample.a) * sideWeight
            + float(rightSample.a) * sideWeight
        );
        float3 sampledPremultiplied = (
            float3(centerSample.rgb) * centerWeight
            + float3(leftSample.rgb) * sideWeight
            + float3(rightSample.rgb) * sideWeight
        );

        float3 waterColor;
        if (sampledAlpha > 0.0001) {
            waterColor = sampledPremultiplied / sampledAlpha;
        } else {
            waterColor = straightColorFromPremultiplied(originalSample);
        }

        // 白い帯を作らず、面全体にだけごく弱い明暗変化を与える。
        float illumination = (
            sin(localUV.x * 5.8 - time * 0.46 + localUV.y * 2.7)
            + sin(localUV.x * 2.7 + localUV.y * 4.8 + time * 0.31)
        ) * 0.0055 * interiorStrength;
        waterColor += float3(illumination * 0.70, illumination * 0.86, illumination);

        // 出力範囲は元PNGのアルファを維持する。
        // 色を再びプリマルチプライドしてから.oneブレンドで背景へ合成する。
        float outputAlpha = originalAlpha;
        float3 outputPremultiplied = saturate(waterColor) * outputAlpha;
        return half4(half3(outputPremultiplied), half(outputAlpha));
    }
    """#
}
