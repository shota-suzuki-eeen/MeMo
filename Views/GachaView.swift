//
//  GachaView.swift
//  MeMo
//
//  Updated for the step-based gacha specification with screen BGM switching and AdMob rewarded ads.
//

import SwiftUI
import SwiftData

fileprivate enum GachaRarity: String, CaseIterable, Identifiable {
    case blue
    case red
    case gold

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue: return "N"
        case .red: return "R"
        case .gold: return "SR"
        }
    }

    var accentColor: Color {
        switch self {
        case .blue: return Color(red: 0.34, green: 0.67, blue: 1.0)
        case .red: return Color(red: 1.0, green: 0.39, blue: 0.35)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.18)
        }
    }

    var capsuleAssetName: String {
        switch self {
        case .blue: return "capsule_blue"
        case .red: return "capsule_red"
        case .gold: return "capsule_gold"
        }
    }

    var openedCapsuleAssetName: String {
        "\(capsuleAssetName)_open"
    }

    var baseWeight: Double {
        switch self {
        case .blue: return 66
        case .red: return 33
        case .gold: return 1
        }
    }
}

fileprivate enum GachaRewardKind: Hashable {
    case food(foodID: String)
    case character(petID: String)
    case specialItem(id: String)
}

fileprivate struct GachaReward: Identifiable, Hashable {
    let id = UUID()
    let rarity: GachaRarity
    let kind: GachaRewardKind
    let title: String
    let subtitle: String
    let imageName: String
}

fileprivate struct GachaProbabilityRow: Identifiable {
    let rarity: GachaRarity
    let percentageText: String

    var id: String { rarity.id }
}

fileprivate enum GachaCatalog {
    static let normalFoodIDs: [String] = [
        "barger", "beer", "cake", "carry", "coffee", "coke", "gyuudon", "icecream", "karaage",
        "nabe", "onigiri", "pan", "pizza", "poteti", "ra-men", "sandowitch", "sarad", "sute-ki", "yo-guruto"
    ]

    static let rareFoodIDs: [String] = [
        "matsuzakaBeef", "spinyLobster", "shineMuscat", "eel", "snowCrab", "otoro", "cantaloupe", "matsutake"
    ]

    static let toiletItemID: String = "wc"

    static func remainingCharacters(state: AppState) -> [PetMasterItem] {
        let owned = Set(state.ownedPetIDs())
        return PetMaster.all.filter {
            !owned.contains($0.id) && !PetMaster.isHappinessRewardPetID($0.id)
        }
    }

    static func makeReward(for rarity: GachaRarity, state: AppState) -> GachaReward? {
        switch rarity {
        case .blue:
            guard let foodID = normalFoodIDs.randomElement(),
                  let food = FoodCatalog.byId(foodID) else { return nil }
            return GachaReward(
                rarity: .blue,
                kind: .food(foodID: food.id),
                title: food.name,
                subtitle: "ごはん / N",
                imageName: food.assetName
            )

        case .red:
            let redPool: [GachaReward] = rareFoodIDs.compactMap {
                guard let food = FoodCatalog.byId($0) else { return nil }
                return GachaReward(
                    rarity: .red,
                    kind: .food(foodID: food.id),
                    title: food.name,
                    subtitle: "ごはん / R",
                    imageName: food.assetName
                )
            } + [
                GachaReward(
                    rarity: .red,
                    kind: .specialItem(id: toiletItemID),
                    title: "トイレ",
                    subtitle: "スペシャル / R",
                    imageName: toiletItemID
                )
            ]
            return redPool.randomElement()

        case .gold:
            let candidates = remainingCharacters(state: state)
            guard let pet = candidates.randomElement() else { return nil }

            let resolvedName: String = {
                let trimmed = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty || trimmed == "*" {
                    return PetMaster.assetName(for: pet.id)
                }
                return trimmed
            }()

            return GachaReward(
                rarity: .gold,
                kind: .character(petID: pet.id),
                title: resolvedName,
                subtitle: "キャラクター / SR",
                imageName: PetMaster.assetName(for: pet.id)
            )
        }
    }
}

struct GachaView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var bgmManager: BGMManager
    @Query private var states: [AppState]

    // アプリ起動時に AdMobManager.shared.start() で事前ロードされた広告をそのまま利用する
    @ObservedObject private var rewardedAdManager = AdMobManager.shared.rewardGacha

    @State private var phase: Phase = .idle
    @State private var drawMode: DrawMode = .single
    @State private var rewards: [GachaReward] = []
    @State private var revealOverlayReward: GachaReward?
    @State private var machineAnimationStart = Date()
    @State private var tapPromptAnimating = false
    @State private var overlayOpacity: Double = 0.0
    @State private var rollTask: Task<Void, Never>?
    @State private var openingTask: Task<Void, Never>?
    @State private var lastFreeAdSlot: GachaFreeAdSlot?
    @State private var lastDrawWasFreeAd: Bool = false
    @State private var toastMessage: String?
    @State private var showToast: Bool = false

    private static let pityThreshold = 100

    private enum Phase {
        case idle
        case rolling
        case waitingTap
        case openingSingle
        case showingSingleResult
        case openingTen
        case showingTenResult
    }

    private enum DrawMode {
        case single
        case ten

        var count: Int {
            switch self {
            case .single: return 1
            case .ten: return 10
            }
        }

        var cost: Int {
            switch self {
            case .single: return 500
            case .ten: return 5_000
            }
        }

        var title: String {
            switch self {
            case .single: return "1回"
            case .ten: return "10回"
            }
        }
    }

    private enum Layout {
        static let backgroundAssetName = "gacha_background"
        static let machineAssetName = "gatyaMachine"
        static let horizontalPadding: CGFloat = 20
        static let contentMaxWidth: CGFloat = 430

        static let buttonHeight: CGFloat = 58
        static let buttonCornerRadius: CGFloat = 18

        static let singleCapsuleMaxSize: CGFloat = 220
        static let singleResultCardWidth: CGFloat = 290
        static let singleResultCardHeight: CGFloat = 340

        static let gridSpacing: CGFloat = 10
        static let gridCornerRadius: CGFloat = 18
    }

    private var state: AppState? {
        states.first
    }

    private var isOverlayVisible: Bool {
        phase != .idle
    }

    private var canGoldAppear: Bool {
        guard let state else { return false }
        return !GachaCatalog.remainingCharacters(state: state).isEmpty
    }

    private var probabilityRows: [GachaProbabilityRow] {
        let eligibleRarities: [GachaRarity] = canGoldAppear ? [.blue, .red, .gold] : [.blue, .red]
        let totalWeight = eligibleRarities.map(\.baseWeight).reduce(0, +)

        return eligibleRarities.map { rarity in
            let percentage = totalWeight > 0 ? (rarity.baseWeight / totalWeight) * 100 : 0
            return GachaProbabilityRow(rarity: rarity, percentageText: formattedProbability(percentage))
        }
    }

    private var walletStepsText: String {
        guard let state else { return "-" }
        return "\(state.walletSteps)歩"
    }

    private var pityDescriptionText: String {
        guard let state else { return "-" }
        if canGoldAppear == false {
            return "全キャラ獲得済み / SR排出なし"
        }
        if state.gachaGuaranteedGoldNext {
            return "次回SR確定"
        }
        return "\(state.gachaPityCounter)/\(Self.pityThreshold)"
    }

    private var freeSlotStatusText: String {
        guard let state else { return "-" }
        let now = Date()
        state.gachaResetIfNeeded(now: now)

        if let slot = state.gachaAvailableFreeAdSlot(now: now) {
            return "\(slot.title)の枠が利用可能（\(slot.windowText)）"
        }
        if let current = GachaFreeAdSlot.current(at: now) {
            return "\(current.title)の枠は使用済み（\(current.windowText)）"
        }
        return "無料枠外です（5:00-10:00 / 10:00-15:00 / 15:00-23:00）"
    }

    private var wcCountText: String {
        guard let state else { return "0" }
        return "\(state.gachaSpecialItemCount(id: GachaCatalog.toiletItemID))"
    }

    private var canSingleDraw: Bool {
        guard let state else { return false }
        return phase == .idle && state.walletSteps >= DrawMode.single.cost
    }

    private var canTenDraw: Bool {
        guard let state else { return false }
        return phase == .idle && state.walletSteps >= DrawMode.ten.cost
    }

    private var canFreeTenDraw: Bool {
        guard let state else { return false }
        return phase == .idle && state.gachaCanUseFreeTenDraw(now: Date())
    }

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let safeBottom = proxy.safeAreaInsets.bottom
            let machineWidth = min(proxy.size.width * 0.72, proxy.size.height * 0.34, 320)
            let contentWidth = min(proxy.size.width - (Layout.horizontalPadding * 2), Layout.contentMaxWidth)

            ZStack {
                backgroundView

                VStack(spacing: 0) {
                    topBar(topInset: safeTop)
                    idleContent(
                        machineWidth: machineWidth,
                        contentWidth: contentWidth,
                        bottomInset: safeBottom
                    )
                }

                if isOverlayVisible {
                    overlayView(
                        proxy: proxy,
                        machineWidth: machineWidth,
                        contentWidth: contentWidth,
                        safeTop: safeTop,
                        safeBottom: safeBottom
                    )
                }

                if let reward = revealOverlayReward {
                    enlargedRewardOverlay(reward: reward, safeTop: safeTop, safeBottom: safeBottom)
                }

                if showToast, let toastMessage {
                    VStack {
                        Spacer()
                        ToastView(message: toastMessage)
                            .padding(.bottom, max(24, safeBottom + 12))
                    }
                    .transition(.move(edge: Edge.bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea()
        }
        .statusBarHidden()
        .onAppear {
            bgmManager.switchBackground(to: .gacha)
            tapPromptAnimating = true
            state?.ensureInitialPetsIfNeeded()
            state?.gachaResetIfNeeded(now: Date())
            rewardedAdManager.loadIfNeeded()
        }
        .onDisappear {
            rollTask?.cancel()
            rollTask = nil
            openingTask?.cancel()
            openingTask = nil
            bgmManager.restoreDefaultBackground()
        }
    }

    private var backgroundView: some View {
        ZStack {
            Image(Layout.backgroundAssetName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.38)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private func topBar(topInset: CGFloat) -> some View {
        HStack {
            Button {
                if phase == .idle {
                    bgmManager.playSE(.push)
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.black.opacity(0.42), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(phase != .idle)
            .opacity(phase == .idle ? 1 : 0.45)

            Spacer()

            Text("ガチャ")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(.white)

            Spacer()

            Color.clear
                .frame(width: 42, height: 42)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, topInset + 10)
        .padding(.bottom, 10)
    }

    private func idleContent(machineWidth: CGFloat, contentWidth: CGFloat, bottomInset: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Spacer(minLength: 8)

                Image(Layout.machineAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: machineWidth)
                    .padding(.top, 4)

                actionButtons
                    .frame(maxWidth: contentWidth)

                statusPanel
                    .frame(maxWidth: contentWidth)

                probabilityPanel
                    .frame(maxWidth: contentWidth)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, max(bottomInset, 16) + 24)
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusRow(title: "所持歩数", value: walletStepsText)
            statusRow(title: "天井", value: pityDescriptionText)
            statusRow(title: "無料10回", value: freeSlotStatusText)
            statusRow(title: "トイレ所持数", value: wcCountText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var probabilityPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("排出確率")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            ForEach(probabilityRows) { row in
                HStack(spacing: 10) {
                    Circle()
                        .fill(row.rarity.accentColor)
                        .frame(width: 10, height: 10)

                    Text("\(row.rarity.displayName) : \(row.percentageText)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()
                }
            }

            if canGoldAppear == false {
                Text("※ 全キャラクター獲得済みのため、現在はSRが排出されません。")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                drawButton(
                    title: "1回 / 500歩",
                    accent: .white,
                    isEnabled: canSingleDraw,
                    action: { startPaidDraw(mode: .single) }
                )

                drawButton(
                    title: "10回 / 5,000歩",
                    accent: Color(red: 1.0, green: 0.86, blue: 0.24),
                    isEnabled: canTenDraw,
                    action: { startPaidDraw(mode: .ten) }
                )
            }

            drawButton(
                title: canFreeTenDraw ? "広告視聴で無料10回" : "広告無料10回（時間外 / 使用済み）",
                accent: Color(red: 0.45, green: 1.0, blue: 0.78),
                isEnabled: canFreeTenDraw,
                action: performRewardedAdThenFreeTenDraw
            )
        }
        .opacity(phase == .idle ? 1 : 0.5)
    }

    private func drawButton(title: String, accent: Color, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.buttonCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.48))

                RoundedRectangle(cornerRadius: Layout.buttonCornerRadius, style: .continuous)
                    .stroke(accent.opacity(0.95), lineWidth: 2)

                Text(title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(accent)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Layout.buttonHeight)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func statusRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 78, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
    }

    private func startPaidDraw(mode: DrawMode) {
        guard let state else { return }
        guard phase == .idle else { return }
        guard state.walletSteps >= mode.cost else {
            showToast("歩数が足りません")
            return
        }

        bgmManager.playSE(.gacha)
        state.gachaResetIfNeeded(now: Date())
        state.walletSteps -= mode.cost
        beginDraw(mode: mode, isFreeAd: false, freeSlot: nil)
    }

    private func performRewardedAdThenFreeTenDraw() {
        guard canFreeTenDraw else {
            showToast("現在利用できる無料10回はありません")
            return
        }

        rewardedAdManager.show(
            onReward: {
                beginFreeTenDraw()
            },
            onUnavailable: {
                rewardedAdManager.loadIfNeeded()
                showToast("広告を読み込み中です。少し待ってからもう一度お試しください")
            }
        )
    }

    private func beginFreeTenDraw() {
        guard let state else { return }
        guard phase == .idle else { return }

        state.gachaResetIfNeeded(now: Date())
        guard let slot = state.gachaConsumeFreeTenDraw(now: Date()) else {
            showToast("現在利用できる無料10回はありません")
            return
        }

        beginDraw(mode: .ten, isFreeAd: true, freeSlot: slot)
    }

    private func beginDraw(mode: DrawMode, isFreeAd: Bool, freeSlot: GachaFreeAdSlot?) {
        guard let state else { return }

        rollTask?.cancel()
        rollTask = nil
        openingTask?.cancel()
        openingTask = nil

        drawMode = mode
        lastDrawWasFreeAd = isFreeAd
        lastFreeAdSlot = freeSlot
        phase = .rolling
        rewards = makeRewards(count: mode.count, state: state)
        revealOverlayReward = nil
        machineAnimationStart = Date()
        tapPromptAnimating = true
        bgmManager.playSE(.gachaDo)

        withAnimation(.easeOut(duration: 0.2)) {
            overlayOpacity = 0.82
        }

        rollTask = Task {
            try? await Task.sleep(nanoseconds: 1_150_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                phase = .waitingTap
            }
        }
    }

    private func makeRewards(count: Int, state: AppState) -> [GachaReward] {
        guard count > 0 else { return [] }

        return (0..<count).compactMap { _ in
            let rarity = rollRarity(state: state)
            guard let reward = GachaCatalog.makeReward(for: rarity, state: state) else { return nil }
            applyReward(reward, state: state)
            return reward
        }
    }

    private func rollRarity(state: AppState) -> GachaRarity {
        let goldCandidates = GachaCatalog.remainingCharacters(state: state)
        let hasGold = !goldCandidates.isEmpty

        if hasGold, state.gachaGuaranteedGoldNext {
            return .gold
        }

        let eligible: [GachaRarity] = hasGold ? [.blue, .red, .gold] : [.blue, .red]
        let totalWeight = eligible.map(\.baseWeight).reduce(0, +)
        let roll = Double.random(in: 0..<totalWeight)

        var cumulative: Double = 0
        for rarity in eligible {
            cumulative += rarity.baseWeight
            if roll < cumulative {
                return rarity
            }
        }
        return eligible.last ?? .blue
    }

    private func applyReward(_ reward: GachaReward, state: AppState) {
        switch reward.kind {
        case .food(let foodID):
            _ = state.addFood(foodId: foodID, count: 1)
            state.gachaAdvancePityAfterNonGold(threshold: Self.pityThreshold)

        case .specialItem(let id):
            _ = state.gachaAddSpecialItem(id: id, count: 1)
            state.gachaAdvancePityAfterNonGold(threshold: Self.pityThreshold)

        case .character(let petID):
            var owned = state.ownedPetIDs()
            if !owned.contains(petID) {
                owned.append(petID)
                state.setOwnedPetIDs(owned)
            }
            state.gachaResetPity()
        }
    }

    @ViewBuilder
    private func overlayView(
        proxy: GeometryProxy,
        machineWidth: CGFloat,
        contentWidth: CGFloat,
        safeTop: CGFloat,
        safeBottom: CGFloat
    ) -> some View {
        ZStack {
            Color.black
                .opacity(max(overlayOpacity, 0.6))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    handleOverlayTap()
                }

            switch phase {
            case .rolling:
                rollingMachine(machineWidth: machineWidth, safeTop: safeTop, safeBottom: safeBottom)

            case .waitingTap:
                interactiveOverlayContainer(safeTop: safeTop, safeBottom: safeBottom) {
                    waitingTapView(proxy: proxy, contentWidth: contentWidth)
                }

            case .openingSingle:
                overlayScrollContainer(safeTop: safeTop, safeBottom: safeBottom) {
                    openingSingleView
                }

            case .showingSingleResult:
                interactiveOverlayContainer(safeTop: safeTop, safeBottom: safeBottom) {
                    singleResultView
                }

            case .openingTen:
                overlayScrollContainer(safeTop: safeTop, safeBottom: safeBottom) {
                    openingTenView(contentWidth: contentWidth)
                }

            case .showingTenResult:
                interactiveOverlayContainer(safeTop: safeTop, safeBottom: safeBottom) {
                    tenResultView(contentWidth: contentWidth)
                }

            case .idle:
                EmptyView()
            }
        }
        .transition(.opacity)
        .zIndex(30)
    }

    private func overlayScrollContainer<Content: View>(
        safeTop: CGFloat,
        safeBottom: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView(showsIndicators: false) {
            VStack {
                content()
            }
            .frame(maxWidth: .infinity)
            .padding(.top, safeTop + 18)
            .padding(.bottom, max(safeBottom, 16) + 20)
            .padding(.horizontal, 18)
            .frame(minHeight: UIScreen.main.bounds.height - safeTop - safeBottom)
        }
    }

    private func interactiveOverlayContainer<Content: View>(
        safeTop: CGFloat,
        safeBottom: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView(showsIndicators: false) {
            VStack {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, safeTop + 18)
            .padding(.bottom, max(safeBottom, 16) + 20)
            .padding(.horizontal, 18)
            .frame(minHeight: UIScreen.main.bounds.height - safeTop - safeBottom)
            .contentShape(Rectangle())
            .onTapGesture {
                handleOverlayTap()
            }
        }
    }

    private func rollingMachine(machineWidth: CGFloat, safeTop: CGFloat, safeBottom: CGFloat) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: safeTop + 24)

            RollingMachineView(
                assetName: Layout.machineAssetName,
                width: machineWidth,
                startDate: machineAnimationStart
            )

            Text(lastDrawWasFreeAd ? "無料10回を回しています…" : "\(drawMode.title)ガチャを回しています…")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.42), in: Capsule())

            Spacer(minLength: safeBottom + 24)
        }
        .padding(.horizontal, 18)
    }

    @ViewBuilder
    private func waitingTapView(proxy: GeometryProxy, contentWidth: CGFloat) -> some View {
        VStack(spacing: 20) {
            if drawMode == .single {
                if let reward = rewards.first {
                    Image(reward.rarity.capsuleAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: min(proxy.size.width * 0.52, Layout.singleCapsuleMaxSize))
                        .shadow(color: reward.rarity.accentColor.opacity(0.6), radius: 24)
                }
            } else {
                capsuleGrid(
                    rewards: rewards,
                    opened: false,
                    simultaneousOpen: false,
                    contentWidth: contentWidth
                )
            }

            VStack(spacing: 10) {
                TapPromptView(isAnimating: tapPromptAnimating, count: 1)

                if let slot = lastFreeAdSlot, lastDrawWasFreeAd {
                    Text("無料10回（\(slot.windowText)）")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.86))
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 0, alignment: .center)
    }

    private var openingSingleView: some View {
        VStack(spacing: 18) {
            if let reward = rewards.first {
                Image(reward.rarity.openedCapsuleAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: Layout.singleCapsuleMaxSize)
                    .shadow(color: reward.rarity.accentColor.opacity(0.72), radius: 28)

                Text("OPEN!")
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 0, alignment: .center)
    }

    private var singleResultView: some View {
        VStack(spacing: 18) {
            if let reward = rewards.first {
                unifiedLargeRewardView(reward: reward)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func unifiedLargeRewardView(reward: GachaReward) -> some View {
        VStack(spacing: 18) {
            ResultHeadlineView(reward: reward)

            ResultRewardCard(
                reward: reward,
                isLarge: true,
                showsText: true,
                showsAccentBorder: true
            )
            .frame(width: Layout.singleResultCardWidth, height: Layout.singleResultCardHeight)
            .onTapGesture { }

            Text("画面をタップで戻る")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
        }
    }

    private func openingTenView(contentWidth: CGFloat) -> some View {
        VStack(spacing: 18) {
            Text("OPEN!")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.white)

            capsuleGrid(
                rewards: rewards,
                opened: true,
                simultaneousOpen: true,
                contentWidth: contentWidth
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func tenResultView(contentWidth: CGFloat) -> some View {
        VStack(spacing: 16) {
            Text("獲得結果")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(.white)

            capsuleResultGrid(rewards: rewards, contentWidth: contentWidth)

            Text("アイテム以外の場所をタップで閉じる / 長押しで拡大")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func capsuleGrid(
        rewards: [GachaReward],
        opened: Bool,
        simultaneousOpen: Bool,
        contentWidth: CGFloat
    ) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Layout.gridSpacing), count: 5)
        let side = max(46, min(68, (contentWidth - (Layout.gridSpacing * 4)) / 5))

        return LazyVGrid(columns: columns, spacing: Layout.gridSpacing) {
            ForEach(rewards, id: \.id) { reward in
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(opened ? 0.10 : 0.08))

                    Image(opened ? reward.rarity.openedCapsuleAssetName : reward.rarity.capsuleAssetName)
                        .resizable()
                        .scaledToFit()
                        .padding(opened ? 6 : 7)
                        .scaleEffect(simultaneousOpen ? 1.02 : 1.0)
                }
                .frame(width: side, height: side)
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func capsuleResultGrid(rewards: [GachaReward], contentWidth: CGFloat) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Layout.gridSpacing), count: 5)
        let side = max(48, min(72, (contentWidth - (Layout.gridSpacing * 4)) / 5))

        return LazyVGrid(columns: columns, spacing: Layout.gridSpacing) {
            ForEach(rewards, id: \.id) { reward in
                ResultRewardCard(
                    reward: reward,
                    isLarge: false,
                    showsText: false,
                    showsAccentBorder: true
                )
                .frame(width: side, height: side)
                .contentShape(RoundedRectangle(cornerRadius: Layout.gridCornerRadius, style: .continuous))
                .onTapGesture { }
                .onLongPressGesture(minimumDuration: 0.35) {
                    revealOverlayReward = reward
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func enlargedRewardOverlay(reward: GachaReward, safeTop: CGFloat, safeBottom: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    ResultHeadlineView(reward: reward)

                    ResultRewardCard(
                        reward: reward,
                        isLarge: true,
                        showsText: true,
                        showsAccentBorder: true
                    )
                    .frame(width: Layout.singleResultCardWidth, height: Layout.singleResultCardHeight)

                    Text("タップで閉じる")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, safeTop + 26)
                .padding(.bottom, max(safeBottom, 16) + 26)
                .padding(.horizontal, 20)
                .frame(minHeight: UIScreen.main.bounds.height - safeTop - safeBottom)
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                closeEnlargedRewardOverlay()
            }
        )
        .transition(.opacity)
        .zIndex(60)
    }

    private func closeEnlargedRewardOverlay() {
        withAnimation(.easeOut(duration: 0.18)) {
            revealOverlayReward = nil
        }
    }

    private func handleOverlayTap() {
        switch phase {
        case .idle, .rolling, .openingSingle, .openingTen:
            return

        case .waitingTap:
            bgmManager.playSE(.open)
            openingTask?.cancel()

            if drawMode == .single {
                phase = .openingSingle
                openingTask = Task {
                    try? await Task.sleep(nanoseconds: 520_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        if phase == .openingSingle {
                            phase = .showingSingleResult
                        }
                    }
                }
            } else {
                phase = .openingTen
                openingTask = Task {
                    try? await Task.sleep(nanoseconds: 650_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        if phase == .openingTen {
                            phase = .showingTenResult
                        }
                    }
                }
            }

        case .showingSingleResult, .showingTenResult:
            finishDrawAndReturnToIdle()
        }
    }

    private func finishDrawAndReturnToIdle() {
        openingTask?.cancel()
        openingTask = nil
        rollTask?.cancel()
        rollTask = nil
        revealOverlayReward = nil

        do {
            try modelContext.save()
        } catch {
            print("❌ ガチャ結果の保存に失敗しました: \(error.localizedDescription)")
        }

        withAnimation(.easeOut(duration: 0.2)) {
            overlayOpacity = 0.0
            phase = .idle
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            if phase == .idle {
                rewards = []
                lastFreeAdSlot = nil
                lastDrawWasFreeAd = false
                rewardedAdManager.loadIfNeeded()
            }
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message

        withAnimation(.easeInOut(duration: 0.18)) {
            showToast = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            withAnimation(.easeInOut(duration: 0.18)) {
                showToast = false
            }
        }
    }

    private func formattedProbability(_ value: Double) -> String {
        if value >= 10 || value.rounded(.towardZero) == value {
            return "\(Int(value.rounded()))%"
        }
        return String(format: "%.1f%%", value)
    }
}

private struct RollingMachineView: View {
    let assetName: String
    let width: CGFloat
    let startDate: Date

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let rotation = sin(elapsed * 18.0) * 4.5
            let xOffset = sin(elapsed * 28.0) * 3.5

            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: width)
                .rotationEffect(.degrees(rotation))
                .offset(x: xOffset)
                .shadow(color: .white.opacity(0.22), radius: 24)
        }
    }
}

private struct TapPromptView: View {
    let isAnimating: Bool
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(1, count), id: \.self) { _ in
                Text("TAP")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.14), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.86), lineWidth: 2)
                    )
                    .scaleEffect(isAnimating ? 1.04 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.62).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
        }
    }
}

private struct ResultHeadlineView: View {
    let reward: GachaReward

    var body: some View {
        VStack(spacing: 8) {
            Text(reward.rarity.displayName)
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(reward.rarity.accentColor)
                .shadow(color: reward.rarity.accentColor.opacity(0.55), radius: 12)

            Text(reward.subtitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
        }
    }
}

private struct ResultRewardCard: View {
    let reward: GachaReward
    let isLarge: Bool
    let showsText: Bool
    let showsAccentBorder: Bool

    private var cornerRadius: CGFloat {
        isLarge ? 26 : 16
    }

    private var backgroundOpacity: Double {
        isLarge ? 0.92 : 0.88
    }

    private var rarityGlowSize: CGFloat {
        isLarge ? 178 : 58
    }

    private var rarityGlowBlur: CGFloat {
        isLarge ? 24 : 10
    }

    private var imagePadding: CGFloat {
        isLarge ? 18 : 7
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(backgroundOpacity))

            if showsAccentBorder {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(reward.rarity.accentColor.opacity(0.96), lineWidth: isLarge ? 3 : 2.2)
            }

            VStack(spacing: isLarge ? 14 : 0) {
                ZStack {
                    Circle()
                        .fill(reward.rarity.accentColor.opacity(isLarge ? 0.32 : 0.34))
                        .frame(width: rarityGlowSize, height: rarityGlowSize)
                        .blur(radius: rarityGlowBlur)

                    Circle()
                        .fill(reward.rarity.accentColor.opacity(isLarge ? 0.16 : 0.18))
                        .frame(width: rarityGlowSize * 0.68, height: rarityGlowSize * 0.68)
                        .blur(radius: rarityGlowBlur * 0.55)

                    Image(reward.imageName)
                        .resizable()
                        .scaledToFit()
                        .padding(imagePadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: isLarge ? 208 : .infinity)

                if showsText {
                    VStack(spacing: 5) {
                        Text(reward.title)
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(.white.opacity(0.94))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)

                        Text(reward.subtitle)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 18)
                }
            }
            .padding(isLarge ? 0 : 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: reward.rarity.accentColor.opacity(isLarge ? 0.35 : 0.16), radius: isLarge ? 20 : 8)
    }
}

private struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(Color.black.opacity(0.78), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            )
            .shadow(radius: 10)
    }
}
