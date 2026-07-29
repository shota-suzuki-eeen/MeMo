//
//  StepView.swift
//  MeMo
//
//  放置釣り機能。
//  旧ランニング画面の呼び出し口を維持しながら、独立した釣り画面へ置き換える。
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

// MARK: - Fishing persistence

final class FishingStore: ObservableObject {
    static let shared = FishingStore()

    static let catchInterval: TimeInterval = 20 * 60
    static let maximumAwayDuration: TimeInterval = 8 * 60 * 60
    static let basketCapacity: Int = 24

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

        let elapsed = max(0, now.timeIntervalSince(lastCalculatedAt))
        let remainder = elapsed.truncatingRemainder(dividingBy: Self.catchInterval)
        if remainder == 0, elapsed > 0 {
            return Self.catchInterval
        }
        return max(0, Self.catchInterval - remainder)
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

struct StepView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var bgmManager: BGMManager

    let state: AppState
    @ObservedObject var hk: HealthKitManager
    let onSave: () -> Void

    @ObservedObject private var fishingStore = FishingStore.shared

    @State private var now = Date()
    @State private var claimResult: FishingClaimResult?
    @State private var showExchange = false
    @State private var isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

    private let secondTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var currentCharacterAssetName: String {
        PetMaster.assetName(for: state.normalizedCurrentPetID)
    }

    private var shouldAnimateLake: Bool {
        scenePhase == .active && claimResult == nil && !showExchange
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

                characterLayer(in: geo.size)
                interfaceLayer(in: geo)

                if let claimResult {
                    FishingResultOverlay(result: claimResult) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.claimResult = nil
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
            now = Date()
            fishingStore.refresh(now: now)
        }
        .onDisappear {
            bgmManager.restoreDefaultBackground()
        }
        .onReceive(secondTimer) { date in
            now = date
            fishingStore.refresh(now: date)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            now = Date()
            fishingStore.refresh(now: now)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .fullScreenCover(isPresented: $showExchange) {
            WorkTimerPreparationView()
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
                .padding(.top, 26)
                .padding(.horizontal, 18)

            Spacer()

            receiveArea
                .padding(.horizontal, 20)
                .padding(.bottom, max(geo.safeAreaInsets.bottom, 18) + 12)
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

            Spacer()

            Button {
                bgmManager.playSE(.push)
                showExchange = true
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
        HStack(spacing: 10) {
            FishingStatusCard(
                icon: "fish.fill",
                title: "魚かご",
                value: "\(fishingStore.pendingCatchCount) / \(FishingStore.basketCapacity)"
            )

            FishingStatusCard(
                icon: "clock.fill",
                title: fishingStore.isBasketFull ? "釣りは停止中" : "次の釣果",
                value: fishingStore.isBasketFull
                    ? "満杯"
                    : Self.timeText(seconds: fishingStore.secondsUntilNextCatch(now: now) ?? 0)
            )

            FishingStatusCard(
                icon: "sparkles",
                title: "フィッシュpt",
                value: "\(fishingStore.pointBalance)"
            )
        }
    }

    private var receiveArea: some View {
        VStack(spacing: 9) {
            if fishingStore.pendingCatchCount > 0 {
                Text("魚の種類ごとに釣果を確認できます")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.3), radius: 3)
            } else {
                Text("20分ごとに魚が1匹釣れます")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.3), radius: 3)
            }

            Button {
                bgmManager.playSE(.push)
                guard let result = fishingStore.claimPendingCatches(now: Date()) else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    claimResult = result
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "basket.fill")
                    Text(fishingStore.pendingCatchCount > 0 ? "釣果を受け取る" : "釣り中…")
                }
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(fishingStore.pendingCatchCount > 0 ? Color.white : Color.white.opacity(0.72))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            fishingStore.pendingCatchCount > 0
                                ? Color(red: 0.10, green: 0.63, blue: 0.88)
                                : Color.black.opacity(0.38)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.48), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.24), radius: 12, x: 0, y: 7)
            }
            .buttonStyle(.plain)
            .disabled(fishingStore.pendingCatchCount == 0)
        }
    }

    private static func timeText(seconds: TimeInterval) -> String {
        let safe = max(0, Int(seconds.rounded(.up)))
        let minutes = safe / 60
        let remainingSeconds = safe % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

// MARK: - Fishing scene views

private struct FishingStatusCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))

            Text(title)
                .font(.system(size: 10, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .padding(.horizontal, 5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 5)
    }
}

private struct FishingSceneryView: View {
    let isWaterActive: Bool
    let preferredFramesPerSecond: Int

    private enum Layout {
        // fishing_background / fishing_lake は同一キャンバス前提。
        // 上側43%は空・山・森で、水面描画対象外としてMTKView自体を配置しない。
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

private struct FishingRodAndBobberView: View {
    let isActive: Bool
    let preferredFramesPerSecond: Int

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / Double(max(1, preferredFramesPerSecond)),
                paused: !isActive
            )
        ) { timeline in
            GeometryReader { geo in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let bob = CGFloat(sin(time * 2.1)) * 3.2
                let tip = CGPoint(x: geo.size.width * 0.42, y: geo.size.height * 0.48)
                let handle = CGPoint(x: geo.size.width * 0.28, y: geo.size.height * 0.78)
                let bobber = CGPoint(x: geo.size.width * 0.67, y: geo.size.height * 0.61 + bob)

                ZStack {
                    Path { path in
                        path.move(to: handle)
                        path.addQuadCurve(
                            to: tip,
                            control: CGPoint(x: geo.size.width * 0.37, y: geo.size.height * 0.60)
                        )
                    }
                    .stroke(
                        LinearGradient(
                            colors: [Color(red: 0.34, green: 0.17, blue: 0.06), Color(red: 0.70, green: 0.42, blue: 0.16)],
                            startPoint: .bottom,
                            endPoint: .top
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )

                    Path { path in
                        path.move(to: tip)
                        path.addQuadCurve(
                            to: bobber,
                            control: CGPoint(x: geo.size.width * 0.56, y: geo.size.height * 0.50)
                        )
                    }
                    .stroke(Color.white.opacity(0.86), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))

                    Capsule()
                        .fill(Color.red)
                        .overlay(
                            Capsule()
                                .fill(Color.white)
                                .frame(height: 10)
                                .offset(y: 5)
                        )
                        .frame(width: 13, height: 25)
                        .position(bobber)
                        .shadow(color: .black.opacity(0.26), radius: 3, x: 0, y: 2)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Catch result overlay

private struct FishingResultOverlay: View {
    let result: FishingClaimResult
    let onClose: () -> Void

    @State private var visibleRowCount = 0
    @State private var displayedEarnedPoints = 0
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.58)
                    .ignoresSafeArea()
                    .onTapGesture { finishAnimations() }

                VStack(spacing: 16) {
                    Text("釣果発表！")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(result.summaries.enumerated()), id: \.element.id) { index, summary in
                                FishingResultRow(summary: summary)
                                    .opacity(index < visibleRowCount ? 1 : 0)
                                    .offset(y: index < visibleRowCount ? 0 : 16)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    VStack(spacing: 8) {
                        HStack {
                            Text("獲得ポイント")
                            Spacer()
                            Text("+\(displayedEarnedPoints) pt")
                                .monospacedDigit()
                        }
                        .font(.system(size: 20, weight: .black, design: .rounded))

                        HStack {
                            Text("所持ポイント")
                            Spacer()
                            Text("\(result.previousPointBalance) → \(result.previousPointBalance + displayedEarnedPoints) pt")
                                .monospacedDigit()
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.90), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Button {
                        finishAnimations()
                        onClose()
                    } label: {
                        Text(displayedEarnedPoints >= result.earnedPoints ? "受け取った！" : "スキップ")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color(red: 0.10, green: 0.63, blue: 0.88), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, max(geo.safeAreaInsets.top, 18) + 10)
                .padding(.bottom, max(geo.safeAreaInsets.bottom, 18) + 4)
                .frame(maxWidth: 440, maxHeight: geo.size.height * 0.92)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.30), lineWidth: 1)
                )
                .padding(.horizontal, 14)
            }
        }
        .onAppear { startAnimations() }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    private func startAnimations() {
        animationTask?.cancel()
        visibleRowCount = 0
        displayedEarnedPoints = 0

        animationTask = Task { @MainActor in
            for index in result.summaries.indices {
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                    visibleRowCount = index + 1
                }
                try? await Task.sleep(nanoseconds: 130_000_000)
            }

            let target = max(0, result.earnedPoints)
            let steps = min(max(target, 1), 32)
            for step in 1...steps {
                guard !Task.isCancelled else { return }
                displayedEarnedPoints = Int((Double(target) * Double(step) / Double(steps)).rounded())
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
            displayedEarnedPoints = target
        }
    }

    private func finishAnimations() {
        animationTask?.cancel()
        animationTask = nil
        visibleRowCount = result.summaries.count
        displayedEarnedPoints = result.earnedPoints
    }
}

private struct FishingResultRow: View {
    let summary: FishingCatchSummary

    var body: some View {
        HStack(spacing: 14) {
            Image(summary.fish.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 82, height: 82)
                .padding(5)
                .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(summary.fish.name)
                        .font(.system(size: 18, weight: .black, design: .rounded))

                    Text(summary.fish.rarity.displayName)
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(summary.fish.rarity.accentColor, in: Capsule())
                }

                Text("× \(summary.count)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .monospacedDigit()

                Text("\(summary.fish.pointValue) pt × \(summary.count) ＝ +\(summary.earnedPoints) pt")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.white.opacity(0.90), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(summary.fish.rarity.accentColor.opacity(0.30), lineWidth: 1.5)
        )
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
/// - バックグラウンド、釣果表示、交換所では描画を停止する。
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
