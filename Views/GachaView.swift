//
//  GachaView.swift
//  MeMo
//
//  Updated for the multi-gacha specification.
//  Adds フードガチャ using gatyaMachine_food and keeps いつでもガチャ as the initial machine.
//  Pity counter is tracked independently for each gacha definition.
//

import SwiftUI
import SwiftData
import UIKit

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

    var openedCapsuleAssetName: String { "\(capsuleAssetName)_open" }

    var resultBackgroundAssetName: String {
        switch self {
        case .blue: return "blue_block"
        case .red: return "red_block"
        case .gold: return "gold_block"
        }
    }

    /// 仕様: N 66%, R 30%, SR 3%。
    /// フードガチャでも N/R はいつでもガチャと同じ内容、キャラクターは SR のみで排出する。
    var baseWeight: Double {
        switch self {
        case .blue: return 66
        case .red: return 30
        case .gold: return 3
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

    var categoryDisplayName: String {
        switch kind {
        case .food: return "ごはん"
        case .character: return "キャラクター"
        case .specialItem: return "スペシャル"
        }
    }
}

fileprivate struct GachaProbabilityRow: Identifiable {
    let rarity: GachaRarity
    let percentageText: String
    var id: String { rarity.id }
}

fileprivate struct GachaEmissionCharacter: Identifiable, Hashable {
    let id: String
    let name: String
    let imageName: String
}

fileprivate enum GachaRewardPool: Hashable {
    case normalCharacters
    case foodCharacters
}

fileprivate struct FoodGachaCharacter: Identifiable, Hashable {
    let id: String
    let name: String
    let assetName: String
    let rarity: GachaRarity
}

fileprivate struct GachaDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let machineAssetName: String
    let rewardPool: GachaRewardPool

    var emissionCharacters: [GachaEmissionCharacter] {
        switch rewardPool {
        case .normalCharacters:
            return PetMaster.all
                .filter { GachaCatalog.isGachaCharacter($0) }
                .map {
                    GachaEmissionCharacter(
                        id: $0.id,
                        name: GachaCatalog.resolvedCharacterName(for: $0),
                        imageName: PetMaster.assetName(for: $0.id)
                    )
                }

        case .foodCharacters:
            return GachaCatalog.foodCharacters.map {
                GachaEmissionCharacter(id: $0.id, name: $0.name, imageName: $0.assetName)
            }
        }
    }
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
    static let initialDistributionPetID: String = "pet_000"

    static let foodCharacters: [FoodGachaCharacter] = [
        .init(id: "food_taiyaki", name: "たい焼き", assetName: "taiyaki", rarity: .gold),
        .init(id: "food_soft_cream", name: "ソフトクリーム", assetName: "soft_cream", rarity: .gold),
        .init(id: "food_hotdog", name: "ホットドッグ", assetName: "hotdog", rarity: .gold),
        .init(id: "food_macaron", name: "マカロン", assetName: "macaron", rarity: .gold),
        .init(id: "food_bao", name: "小籠包", assetName: "bao", rarity: .gold),
        .init(id: "food_cherry", name: "チェリー", assetName: "cherry", rarity: .gold),
        .init(id: "food_coffee", name: "コーヒー", assetName: "coffee", rarity: .gold),
        .init(id: "food_donut", name: "ドーナツ", assetName: "donut", rarity: .gold),
        .init(id: "food_egg", name: "目玉焼き", assetName: "egg", rarity: .gold),
        .init(id: "food_gyoza", name: "餃子", assetName: "gyoza", rarity: .gold),
        .init(id: "food_hamburger", name: "ハンバーガー", assetName: "hamburger", rarity: .gold),
        .init(id: "food_juice", name: "オレンジジュース", assetName: "juice", rarity: .gold),
        .init(id: "food_maguro", name: "マグロ寿司", assetName: "maguro", rarity: .gold),
        .init(id: "food_pancake", name: "パンケーキ", assetName: "pancake", rarity: .gold),
        .init(id: "food_pizza", name: "ピザ", assetName: "pizza", rarity: .gold),
        .init(id: "food_poteto", name: "ポテト", assetName: "poteto", rarity: .gold),
        .init(id: "food_satumaimo", name: "さつまいも", assetName: "satumaimo", rarity: .gold),
        .init(id: "food_shumai", name: "焼売", assetName: "shumai", rarity: .gold),
        .init(id: "food_tacos", name: "タコス", assetName: "tacos", rarity: .gold),
        .init(id: "food_takoyaki", name: "たこ焼き", assetName: "takoyaki", rarity: .gold)
    ]

    static let gachas: [GachaDefinition] = [
        GachaDefinition(
            id: "always",
            title: "いつでもガチャ",
            machineAssetName: "gatyaMachine",
            rewardPool: .normalCharacters
        ),
        GachaDefinition(
            id: "food",
            title: "フードガチャ",
            machineAssetName: "gatyaMachine_food",
            rewardPool: .foodCharacters
        )
    ]

    static func isGachaCharacter(_ pet: PetMasterItem) -> Bool {
        pet.id != initialDistributionPetID
            && !PetMaster.isHappinessRewardPetID(pet.id)
            && !foodCharacters.contains(where: { $0.id == pet.id })
    }

    static func resolvedCharacterName(for pet: PetMasterItem) -> String {
        let trimmed = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "*" { return PetMaster.assetName(for: pet.id) }
        return trimmed
    }

    /// 「いつでもガチャ」のSR排出対象キャラクター。
    /// 初期配布、なつき度報酬、フードガチャ専用キャラクターを除外し、
    /// 初回限定SR確定枠に「いつでもガチャ」以外のキャラクターが混入しないようにする。
    static func alwaysGachaCharacterCandidates() -> [PetMasterItem] {
        PetMaster.all.filter { isGachaCharacter($0) }
    }

    static func remainingNormalCharacters(state: AppState) -> [PetMasterItem] {
        let owned = Set(state.ownedPetIDs())
        return alwaysGachaCharacterCandidates().filter { !owned.contains($0.id) }
    }

    static func remainingFoodCharacters(state: AppState, rarity: GachaRarity? = nil) -> [FoodGachaCharacter] {
        let owned = Set(state.ownedPetIDs())
        return foodCharacters.filter {
            !owned.contains($0.id) && (rarity == nil || $0.rarity == rarity)
        }
    }

    static func canGoldAppear(in gacha: GachaDefinition, state: AppState) -> Bool {
        switch gacha.rewardPool {
        case .normalCharacters:
            return !remainingNormalCharacters(state: state).isEmpty
        case .foodCharacters:
            return !remainingFoodCharacters(state: state, rarity: .gold).isEmpty
        }
    }

    static func makeReward(for rarity: GachaRarity, gacha: GachaDefinition, state: AppState) -> GachaReward? {
        switch gacha.rewardPool {
        case .normalCharacters:
            return makeAlwaysGachaReward(for: rarity, state: state)
        case .foodCharacters:
            return makeFoodGachaReward(for: rarity, state: state)
        }
    }

    private static func makeAlwaysGachaReward(for rarity: GachaRarity, state: AppState) -> GachaReward? {
        switch rarity {
        case .blue:
            guard let foodID = normalFoodIDs.randomElement(), let food = FoodCatalog.byId(foodID) else { return nil }
            return GachaReward(rarity: .blue, kind: .food(foodID: food.id), title: food.name, subtitle: "ごはん / N", imageName: food.assetName)

        case .red:
            let redPool: [GachaReward] = rareFoodIDs.compactMap {
                guard let food = FoodCatalog.byId($0) else { return nil }
                return GachaReward(rarity: .red, kind: .food(foodID: food.id), title: food.name, subtitle: "ごはん / R", imageName: food.assetName)
            } + [
                GachaReward(rarity: .red, kind: .specialItem(id: toiletItemID), title: "トイレ", subtitle: "スペシャル / R", imageName: toiletItemID)
            ]
            return redPool.randomElement()

        case .gold:
            guard let pet = remainingNormalCharacters(state: state).randomElement() else { return nil }
            return GachaReward(rarity: .gold, kind: .character(petID: pet.id), title: resolvedCharacterName(for: pet), subtitle: "キャラクター / SR", imageName: PetMaster.assetName(for: pet.id))
        }
    }

    static func makeAlwaysGachaGuaranteedGoldReward(state: AppState) -> GachaReward? {
        // 初回限定のSR確定枠は「いつでもガチャ」のラインナップだけから抽選する。
        // すでに全員所持済みの場合のみ、重複排出として同じ「いつでもガチャ」ラインナップ全体から抽選する。
        let remaining = remainingNormalCharacters(state: state)
        let alwaysOnlyCandidates = alwaysGachaCharacterCandidates()
        let pool = remaining.isEmpty ? alwaysOnlyCandidates : remaining
        guard let pet = pool.randomElement() else { return nil }
        return GachaReward(
            rarity: .gold,
            kind: .character(petID: pet.id),
            title: resolvedCharacterName(for: pet),
            subtitle: "キャラクター / SR",
            imageName: PetMaster.assetName(for: pet.id)
        )
    }

    private static func makeFoodGachaReward(for rarity: GachaRarity, state: AppState) -> GachaReward? {
        switch rarity {
        case .blue, .red:
            // フードガチャの N/R は、いつでもガチャと同じ排出内容にする。
            return makeAlwaysGachaReward(for: rarity, state: state)

        case .gold:
            // フードガチャのキャラクターは SR のみで排出する。
            let candidates = remainingFoodCharacters(state: state, rarity: .gold)
            let pool = candidates.isEmpty ? foodCharacters : candidates
            guard let foodCharacter = pool.randomElement() else { return nil }
            return GachaReward(
                rarity: .gold,
                kind: .character(petID: foodCharacter.id),
                title: foodCharacter.name,
                subtitle: "フードキャラクター / SR",
                imageName: foodCharacter.assetName
            )
        }
    }
}

struct GachaView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var bgmManager: BGMManager
    @Query private var states: [AppState]

    @ObservedObject private var rewardedAdManager = AdMobManager.shared.rewardGacha

    private let isTutorialMode: Bool
    private let onTutorialFinished: (() -> Void)?

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
    @State private var tutorialFreeTenDrawStarted: Bool = false
    @State private var selectedGachaIndex: Int = 0
    @State private var showsEmissionList: Bool = false

    private static let pityThreshold = 100

    init(isTutorialMode: Bool = false, onTutorialFinished: (() -> Void)? = nil) {
        self.isTutorialMode = isTutorialMode
        self.onTutorialFinished = onTutorialFinished
    }

    private enum Phase {
        case idle, rolling, waitingTap, openingSingle, showingSingleResult, openingTen, showingTenResult
    }

    private enum DrawMode {
        case single, ten
        var count: Int { self == .single ? 1 : 10 }
        var cost: Int { self == .single ? 500 : 5_000 }
        var title: String { self == .single ? "1回" : "10回" }
    }

    private enum Layout {
        static let backgroundAssetName = "gacha_background"
        static let horizontalPadding: CGFloat = 20
        static let contentMaxWidth: CGFloat = 430
        static let buttonHeight: CGFloat = 58
        static let buttonCornerRadius: CGFloat = 18
        static let singleCapsuleMaxSize: CGFloat = 220
        static let singleResultCardWidth: CGFloat = 290
        static let enlargedResultCardHeight: CGFloat = 360
        static let enlargedResultImageSize: CGFloat = 210
        static let gridSpacing: CGFloat = 10
        static let gridCornerRadius: CGFloat = 18
    }

    private var state: AppState? { states.first }

    /// ガチャ選択を「いつでもガチャ」に固定する必要がある状態。
    /// - チュートリアル中: SR確定無料10回は「いつでもガチャ」限定。
    /// - iPad初回無料10回の未消費中: iPadにはチュートリアルがないため、初回無料10回を引くまでは通常画面側で「いつでもガチャ」のみに制限する。
    private var isAlwaysGachaOnlyMode: Bool {
        isTutorialMode || isInitialIPadFreeTenDrawPending
    }

    private var alwaysGacha: GachaDefinition {
        GachaCatalog.gachas.first(where: { $0.id == "always" }) ?? GachaCatalog.gachas[0]
    }

    private var availableGachas: [GachaDefinition] {
        isAlwaysGachaOnlyMode ? [alwaysGacha] : GachaCatalog.gachas
    }

    private var selectedGacha: GachaDefinition {
        let gachas = availableGachas
        let safeIndex = min(max(0, selectedGachaIndex), max(0, gachas.count - 1))
        return gachas[safeIndex]
    }

    private var canSelectPreviousGacha: Bool { availableGachas.indices.contains(selectedGachaIndex - 1) }
    private var canSelectNextGacha: Bool { availableGachas.indices.contains(selectedGachaIndex + 1) }
    private var isOverlayVisible: Bool { phase != .idle }
    private var isIPadDevice: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// iPad初回無料10回が未消費かどうか。
    /// phase には依存させず、初回無料10回を消費するまではガチャ選択UIを固定する。
    private var isInitialIPadFreeTenDrawPending: Bool {
        guard !isTutorialMode, isIPadDevice else { return false }
        guard let state else { return true }
        return state.gachaCanUseInitialIPadFreeTenDraw(isPad: true)
    }

    private var isInitialIPadFreeTenDrawAvailable: Bool {
        phase == .idle && isInitialIPadFreeTenDrawPending
    }

    private var canGoldAppear: Bool {
        guard let state else { return false }
        return GachaCatalog.canGoldAppear(in: selectedGacha, state: state)
    }

    private var probabilityRows: [GachaProbabilityRow] {
        let eligibleRarities: [GachaRarity] = canGoldAppear ? [.blue, .red, .gold] : [.blue, .red]
        return eligibleRarities.map { GachaProbabilityRow(rarity: $0, percentageText: formattedProbability($0.baseWeight)) }
    }

    private var walletStepsText: String { state.map { "\($0.walletSteps)歩" } ?? "-" }

    private var pityDescriptionText: String {
        guard let state else { return "-" }
        if canGoldAppear == false { return "全キャラ獲得済み / SR排出なし" }
        if state.gachaGuaranteedGoldNext(for: selectedGacha.id) { return "次回SR確定" }
        return "\(state.gachaPityCounter(for: selectedGacha.id))/\(Self.pityThreshold)"
    }

    private var freeSlotStatusText: String {
        if isTutorialMode { return "チュートリアル限定：広告なしで無料10回を体験できます" }
        guard let state else { return "-" }
        let now = Date()
        if state.gachaCanUseInitialIPadFreeTenDraw(isPad: isIPadDevice) { return "iPad初回特典：いつでもガチャ限定 / SR1体確定" }
        if let slot = state.gachaAvailableFreeAdSlot(now: now) { return "\(slot.title)の枠が利用可能（\(slot.windowText)）" }
        if let current = GachaFreeAdSlot.current(at: now) { return "\(current.title)の枠は使用済み（\(current.windowText)）" }
        return "無料枠外です（5:00-10:00 / 10:00-15:00 / 15:00-23:00）"
    }

    private var wcCountText: String { state.map { "\($0.gachaSpecialItemCount(id: GachaCatalog.toiletItemID))" } ?? "0" }
    private var canSingleDraw: Bool { state.map { !isTutorialMode && phase == .idle && $0.walletSteps >= DrawMode.single.cost } ?? false }
    private var canTenDraw: Bool { state.map { !isTutorialMode && phase == .idle && $0.walletSteps >= DrawMode.ten.cost } ?? false }

    private var canFreeTenDraw: Bool {
        guard let state else { return false }
        if isTutorialMode { return phase == .idle && tutorialFreeTenDrawStarted == false }
        return phase == .idle && (state.gachaCanUseInitialIPadFreeTenDraw(isPad: isIPadDevice) || state.gachaCanUseFreeTenDraw(now: Date()))
    }

    private var freeTenDrawButtonTitle: String {
        if isTutorialMode { return tutorialFreeTenDrawStarted ? "無料10回（体験済み）" : "無料10回" }
        if isInitialIPadFreeTenDrawAvailable { return "初回無料10回（SR確定）" }
        return canFreeTenDraw ? "広告視聴で無料10回" : "広告無料10回（時間外 / 使用済み）"
    }

    var body: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            let safeBottom = proxy.safeAreaInsets.bottom
            let availableHeight = proxy.size.height
            let machineWidth = min(proxy.size.width * 0.94, proxy.size.height * 0.50, 470)
            let contentWidth = min(proxy.size.width - (Layout.horizontalPadding * 2), Layout.contentMaxWidth)

            ZStack {
                backgroundView

                VStack(spacing: 0) {
                    topBar(topInset: safeTop)
                    gachaMachineSelector(machineWidth: machineWidth, contentWidth: contentWidth)
                    idleContent(contentWidth: contentWidth, bottomInset: safeBottom)
                }

                if isOverlayVisible {
                    overlayView(proxy: proxy, machineWidth: machineWidth, contentWidth: contentWidth, safeTop: safeTop, safeBottom: safeBottom, availableHeight: availableHeight)
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea()
        }
        .statusBarHidden()
        .sheet(isPresented: $showsEmissionList) { GachaEmissionListView(gacha: selectedGacha) }
        .onAppear {
            bgmManager.switchBackground(to: .gacha)
            tapPromptAnimating = true
            state?.ensureInitialPetsIfNeeded()
            state?.gachaResetIfNeeded(now: Date())
            if isAlwaysGachaOnlyMode { selectedGachaIndex = 0 }
            if isTutorialMode == false { rewardedAdManager.loadIfNeeded() } else { state?.memoMarkFirstVisitFreeTenDrawOffered() }
        }
        .onChange(of: isAlwaysGachaOnlyMode) { _, newValue in
            if newValue { selectedGachaIndex = 0 }
        }
        .onDisappear {
            rollTask?.cancel(); rollTask = nil
            openingTask?.cancel(); openingTask = nil
            bgmManager.restoreDefaultBackground()
        }
    }

    private var backgroundView: some View {
        ZStack {
            Image(Layout.backgroundAssetName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(colors: [Color.black.opacity(0.18), Color.black.opacity(0.38)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }

    private func topBar(topInset: CGFloat) -> some View {
        HStack {
            if isTutorialMode {
                Color.clear.frame(width: 42, height: 42)
            } else {
                Button {
                    if phase == .idle { bgmManager.playSE(.push); dismiss() }
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
            }

            Spacer()
            Text("ガチャ").font(.system(size: 28, weight: .black)).foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 42, height: 42)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, topInset + 10)
        .padding(.bottom, 4)
    }

    private func gachaMachineSelector(machineWidth: CGFloat, contentWidth: CGFloat) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(selectedGacha.machineAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: machineWidth)
                    .padding(.top, 2)
                    .frame(maxWidth: contentWidth)

                if availableGachas.count > 1 {
                    HStack {
                        gachaArrowButton(systemName: "chevron.left", isEnabled: canSelectPreviousGacha) { selectGacha(offset: -1) }
                        Spacer()
                        gachaArrowButton(systemName: "chevron.right", isEnabled: canSelectNextGacha) { selectGacha(offset: 1) }
                    }
                    .frame(maxWidth: contentWidth)
                    .padding(.horizontal, 2)
                    .padding(.top, max(18, machineWidth * 0.30))
                }

                Button {
                    guard phase == .idle else { return }
                    bgmManager.playSE(.push)
                    showsEmissionList = true
                } label: {
                    Text("排出リスト")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.54), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.42), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(phase != .idle)
                .opacity(phase == .idle ? 1 : 0.5)
                .padding(.trailing, 8)
                .padding(.top, 8)
            }

            Text(selectedGacha.title)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 7)
                .background(Color.black, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))
                .shadow(color: .black.opacity(0.42), radius: 3, y: 2)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.bottom, 8)
    }

    private func gachaArrowButton(systemName: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 42, height: 54)
                .background(Color.black.opacity(0.46), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || phase != .idle)
        .opacity(isEnabled && phase == .idle ? 1 : 0.28)
    }

    private func selectGacha(offset: Int) {
        guard phase == .idle else { return }
        let nextIndex = selectedGachaIndex + offset
        guard availableGachas.indices.contains(nextIndex) else { return }
        bgmManager.playSE(.push)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { selectedGachaIndex = nextIndex }
    }

    private func idleContent(contentWidth: CGFloat, bottomInset: CGFloat) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                if isTutorialMode { TutorialGachaTeacherNote().frame(maxWidth: contentWidth) }
                actionButtons.frame(maxWidth: contentWidth)
                statusPanel.frame(maxWidth: contentWidth)
                probabilityPanel.frame(maxWidth: contentWidth)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, 8)
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
            Text("排出確率").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
            ForEach(probabilityRows) { row in
                HStack(spacing: 10) {
                    Circle().fill(row.rarity.accentColor).frame(width: 10, height: 10)
                    Text("\(row.rarity.displayName) : \(row.percentageText)").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
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
        let buttonsOpacity: Double = phase == .idle ? 1.0 : 0.5
        let freeTenDrawAction: () -> Void = {
            if isTutorialMode { beginTutorialFreeTenDraw() }
            else if isInitialIPadFreeTenDrawAvailable { beginInitialIPadFreeTenDraw() }
            else { performRewardedAdThenFreeTenDraw() }
        }

        return VStack(spacing: 12) {
            HStack(spacing: 14) {
                drawButton(title: "1回 / 500歩", accent: .white, isEnabled: canSingleDraw) { startPaidDraw(mode: .single) }
                drawButton(title: "10回 / 5,000歩", accent: Color(red: 1.0, green: 0.86, blue: 0.24), isEnabled: canTenDraw) { startPaidDraw(mode: .ten) }
            }
            drawButton(title: freeTenDrawButtonTitle, accent: Color(red: 0.45, green: 1.0, blue: 0.78), isEnabled: canFreeTenDraw, action: freeTenDrawAction)
        }
        .opacity(buttonsOpacity)
    }

    private func drawButton(title: String, accent: Color, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.buttonCornerRadius, style: .continuous).fill(Color.black.opacity(0.48))
                RoundedRectangle(cornerRadius: Layout.buttonCornerRadius, style: .continuous).stroke(accent.opacity(0.95), lineWidth: 2)
                Text(title).font(.system(size: 20, weight: .black)).foregroundStyle(accent).multilineTextAlignment(.center).padding(.horizontal, 10)
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
            Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.88)).frame(width: 78, alignment: .leading)
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
    }

    private func startPaidDraw(mode: DrawMode) {
        guard let state else { return }
        guard phase == .idle, isTutorialMode == false else { return }
        guard state.walletSteps >= mode.cost else { showToast("歩数が足りません"); return }
        if isAlwaysGachaOnlyMode { selectedGachaIndex = 0 }
        bgmManager.playSE(.gacha)
        state.gachaResetIfNeeded(now: Date())
        state.walletSteps -= mode.cost
        beginDraw(mode: mode, isFreeAd: false, freeSlot: nil)
    }

    private func performRewardedAdThenFreeTenDraw() {
        guard canFreeTenDraw else { showToast("現在利用できる無料10回はありません"); return }
        rewardedAdManager.show(
            onReward: { beginFreeTenDraw() },
            onUnavailable: {
                rewardedAdManager.loadIfNeeded()
                showToast("広告を読み込み中です。少し待ってからもう一度お試しください")
            }
        )
    }

    private func beginFreeTenDraw() {
        guard let state, phase == .idle else { return }
        state.gachaResetIfNeeded(now: Date())
        guard let slot = state.gachaConsumeFreeTenDraw(now: Date()) else { showToast("現在利用できる無料10回はありません"); return }
        beginDraw(mode: .ten, isFreeAd: true, freeSlot: slot)
    }

    private func beginInitialIPadFreeTenDraw() {
        guard let state, phase == .idle else { return }
        // iPad初回無料10回はチュートリアルの代替導線として扱い、必ず「いつでもガチャ」で実行する。
        selectedGachaIndex = 0
        guard state.gachaConsumeInitialIPadFreeTenDraw(isPad: isIPadDevice) else { showToast("初回無料10回は使用済みです"); return }
        beginDraw(mode: .ten, isFreeAd: true, freeSlot: nil, usesInitialIPadGuaranteedSR: true)
    }

    private func beginTutorialFreeTenDraw() {
        guard phase == .idle, tutorialFreeTenDrawStarted == false else { return }
        tutorialFreeTenDrawStarted = true
        beginDraw(mode: .ten, isFreeAd: true, freeSlot: nil)
    }

    private func beginDraw(mode: DrawMode, isFreeAd: Bool, freeSlot: GachaFreeAdSlot?, usesInitialIPadGuaranteedSR: Bool = false) {
        guard let state else { return }
        rollTask?.cancel(); rollTask = nil
        openingTask?.cancel(); openingTask = nil
        drawMode = mode
        lastDrawWasFreeAd = isFreeAd
        lastFreeAdSlot = freeSlot
        phase = .rolling
        if isTutorialMode && isFreeAd {
            rewards = makeTutorialRewards(state: state)
        } else if usesInitialIPadGuaranteedSR {
            rewards = makeInitialIPadFreeTenDrawRewards(state: state)
        } else {
            rewards = makeRewards(count: mode.count, state: state)
        }
        revealOverlayReward = nil
        machineAnimationStart = Date()
        tapPromptAnimating = true
        bgmManager.playSE(.gachaDo)
        withAnimation(.easeOut(duration: 0.2)) { overlayOpacity = 0.82 }
        rollTask = Task {
            try? await Task.sleep(nanoseconds: 1_150_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { phase = .waitingTap }
        }
    }

    private func makeRewards(count: Int, state: AppState) -> [GachaReward] {
        guard count > 0 else { return [] }
        return (0..<count).compactMap { _ in
            let rarity = rollRarity(state: state)
            guard let reward = GachaCatalog.makeReward(for: rarity, gacha: selectedGacha, state: state) else { return nil }
            applyReward(reward, state: state)
            return reward
        }
    }

    private func makeInitialIPadFreeTenDrawRewards(state: AppState) -> [GachaReward] {
        var generatedRewards: [GachaReward] = []

        // iPad初回限定のSR確定枠は、「いつでもガチャ」のSRキャラクターラインナップから1体ランダム確定。
        if let guaranteedSR = GachaCatalog.makeAlwaysGachaGuaranteedGoldReward(state: state) {
            applyReward(guaranteedSR, state: state, gachaID: alwaysGacha.id)
            generatedRewards.append(guaranteedSR)
        }

        let remainingCount = max(0, DrawMode.ten.count - generatedRewards.count)
        for _ in 0..<remainingCount {
            let rarity = rollNonGoldRarity()
            guard let reward = GachaCatalog.makeReward(for: rarity, gacha: alwaysGacha, state: state) else { continue }
            applyReward(reward, state: state, gachaID: alwaysGacha.id)
            generatedRewards.append(reward)
        }

        state.gachaResetPity(for: alwaysGacha.id)
        return generatedRewards.shuffled()
    }

    private func makeTutorialRewards(state: AppState) -> [GachaReward] {
        _ = state.memoMarkFirstVisitFreeTenDrawOffered()
        _ = state.memoConsumeFirstVisitFreeTenDraw()
        let petID = state.memoAwardTutorialGachaCharacterIfNeeded()
        let petName = PetMaster.all.first(where: { $0.id == petID })?.name ?? "新しいキャラクター"
        let characterReward = GachaReward(rarity: .gold, kind: .character(petID: petID), title: petName, subtitle: "キャラクター / SR", imageName: PetMaster.assetName(for: petID))
        let foodRewards: [GachaReward] = (0..<9).compactMap { _ in
            guard let food = FoodCatalog.all.randomElement() else { return nil }
            _ = state.addFood(foodId: food.id, count: 1)
            return GachaReward(rarity: food.isShopEligible ? .blue : .red, kind: .food(foodID: food.id), title: food.name, subtitle: food.isShopEligible ? "ごはん / N" : "ごはん / R", imageName: food.assetName)
        }
        state.gachaResetPity(for: selectedGacha.id)
        _ = state.memoMarkFirstVisitFreeTenDrawCompleted()
        return ([characterReward] + foodRewards).shuffled()
    }

    private func rollNonGoldRarity() -> GachaRarity {
        let eligible: [GachaRarity] = [.blue, .red]
        let totalWeight = eligible.map(\.baseWeight).reduce(0, +)
        let roll = Double.random(in: 0..<totalWeight)
        var cumulative: Double = 0
        for rarity in eligible {
            cumulative += rarity.baseWeight
            if roll < cumulative { return rarity }
        }
        return .blue
    }

    private func rollRarity(state: AppState) -> GachaRarity {
        let hasGold = GachaCatalog.canGoldAppear(in: selectedGacha, state: state)
        if hasGold, state.gachaGuaranteedGoldNext(for: selectedGacha.id) { return .gold }
        let eligible: [GachaRarity] = hasGold ? [.blue, .red, .gold] : [.blue, .red]
        let totalWeight = eligible.map(\.baseWeight).reduce(0, +)
        let roll = Double.random(in: 0..<totalWeight)
        var cumulative: Double = 0
        for rarity in eligible {
            cumulative += rarity.baseWeight
            if roll < cumulative { return rarity }
        }
        return eligible.last ?? .blue
    }

    private func applyReward(_ reward: GachaReward, state: AppState, gachaID: String? = nil) {
        let targetGachaID = gachaID ?? selectedGacha.id
        switch reward.kind {
        case .food(let foodID):
            _ = state.addFood(foodId: foodID, count: 1)
            state.gachaAdvancePityAfterNonGold(for: targetGachaID, threshold: Self.pityThreshold)
        case .specialItem(let id):
            _ = state.gachaAddSpecialItem(id: id, count: 1)
            state.gachaAdvancePityAfterNonGold(for: targetGachaID, threshold: Self.pityThreshold)
        case .character(let petID):
            var owned = state.ownedPetIDs()
            if !owned.contains(petID) { owned.append(petID); state.setOwnedPetIDs(owned) }
            if reward.rarity == .gold { state.gachaResetPity(for: targetGachaID) } else { state.gachaAdvancePityAfterNonGold(for: targetGachaID, threshold: Self.pityThreshold) }
        }
    }

    @ViewBuilder
    private func overlayView(proxy: GeometryProxy, machineWidth: CGFloat, contentWidth: CGFloat, safeTop: CGFloat, safeBottom: CGFloat, availableHeight: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(max(overlayOpacity, 0.6)).ignoresSafeArea().contentShape(Rectangle()).onTapGesture { handleOverlayTap() }
            switch phase {
            case .rolling:
                rollingMachine(machineWidth: machineWidth, safeTop: safeTop, safeBottom: safeBottom)
            case .waitingTap:
                interactiveOverlayContainer(safeTop: safeTop, safeBottom: safeBottom, availableHeight: availableHeight) { waitingTapView(proxy: proxy, contentWidth: contentWidth) }
            case .openingSingle:
                overlayScrollContainer(safeTop: safeTop, safeBottom: safeBottom, availableHeight: availableHeight) { openingSingleView }
            case .showingSingleResult:
                interactiveOverlayContainer(safeTop: safeTop, safeBottom: safeBottom, availableHeight: availableHeight) { singleResultView }
            case .openingTen:
                overlayScrollContainer(safeTop: safeTop, safeBottom: safeBottom, availableHeight: availableHeight) { openingTenView(contentWidth: contentWidth) }
            case .showingTenResult:
                interactiveOverlayContainer(safeTop: safeTop, safeBottom: safeBottom, availableHeight: availableHeight) { tenResultView(contentWidth: contentWidth) }
            case .idle:
                EmptyView()
            }
        }
        .transition(.opacity)
        .zIndex(30)
    }

    private func overlayScrollContainer<Content: View>(safeTop: CGFloat, safeBottom: CGFloat, availableHeight: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        let minHeight = max(0, availableHeight - safeTop - safeBottom)
        return ScrollView(showsIndicators: false) {
            VStack { content() }
                .frame(maxWidth: .infinity)
                .frame(minHeight: minHeight, alignment: .center)
                .padding(.top, safeTop + 18)
                .padding(.bottom, max(safeBottom, 16) + 20)
                .padding(.horizontal, 18)
        }
    }

    private func interactiveOverlayContainer<Content: View>(safeTop: CGFloat, safeBottom: CGFloat, availableHeight: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        let minHeight = max(0, availableHeight - safeTop - safeBottom)
        return ScrollView(showsIndicators: false) {
            VStack { content() }
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(minHeight: minHeight, alignment: .center)
                .padding(.top, safeTop + 18)
                .padding(.bottom, max(safeBottom, 16) + 20)
                .padding(.horizontal, 18)
                .contentShape(Rectangle())
                .onTapGesture { handleOverlayTap() }
        }
    }

    private func rollingMachine(machineWidth: CGFloat, safeTop: CGFloat, safeBottom: CGFloat) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: safeTop + 24)
            RollingMachineView(assetName: selectedGacha.machineAssetName, width: machineWidth, startDate: machineAnimationStart)
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
                capsuleGrid(rewards: rewards, opened: false, simultaneousOpen: false, contentWidth: contentWidth)
            }
            VStack(spacing: 10) {
                TapPromptView(isAnimating: tapPromptAnimating, count: 1)
                if isTutorialMode { Text("チュートリアル限定 / 広告なし").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.86)) }
                else if let slot = lastFreeAdSlot, lastDrawWasFreeAd { Text("無料10回（\(slot.windowText)）").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.86)) }
                else if lastDrawWasFreeAd && isIPadDevice { Text("iPad初回特典 / 広告なし").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.86)) }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 0, alignment: .center)
    }

    private var openingSingleView: some View {
        VStack(spacing: 18) {
            if let reward = rewards.first {
                Image(reward.rarity.openedCapsuleAssetName).resizable().scaledToFit().frame(width: Layout.singleCapsuleMaxSize).shadow(color: reward.rarity.accentColor.opacity(0.72), radius: 28)
                Text("OPEN!").font(.system(size: 30, weight: .black)).foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 0, alignment: .center)
    }

    private var singleResultView: some View {
        VStack(spacing: 18) { if let reward = rewards.first { unifiedLargeRewardView(reward: reward) } }
            .frame(maxWidth: .infinity)
    }

    private func unifiedLargeRewardView(reward: GachaReward) -> some View {
        VStack(spacing: 18) {
            ResultHeadlineView(reward: reward)
            ResultRewardCard(reward: reward, isLarge: true, showsText: true, showsAccentBorder: false, usesRarityBackgroundAsset: true, largeImageSizeOverride: Layout.enlargedResultImageSize)
                .frame(width: Layout.singleResultCardWidth, height: Layout.enlargedResultCardHeight)
                .onTapGesture { }
            Text("画面をタップで戻る").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.88))
        }
    }

    private func openingTenView(contentWidth: CGFloat) -> some View {
        VStack(spacing: 18) {
            Text("OPEN!").font(.system(size: 26, weight: .black)).foregroundStyle(.white)
            capsuleGrid(rewards: rewards, opened: true, simultaneousOpen: true, contentWidth: contentWidth)
        }
        .frame(maxWidth: .infinity)
    }

    private func tenResultView(contentWidth: CGFloat) -> some View {
        VStack(spacing: 16) {
            Text("獲得結果").font(.system(size: 28, weight: .black)).foregroundStyle(.white)
            capsuleResultGrid(rewards: rewards, contentWidth: contentWidth)
            Text("画面をタップで戻る / カード長押しで詳細").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.88)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func capsuleGrid(rewards: [GachaReward], opened: Bool, simultaneousOpen: Bool, contentWidth: CGFloat) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Layout.gridSpacing), count: 5)
        let side = max(46, min(68, (contentWidth - (Layout.gridSpacing * 4)) / 5))
        return LazyVGrid(columns: columns, spacing: Layout.gridSpacing) {
            ForEach(rewards, id: \.id) { reward in
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(opened ? 0.10 : 0.08))
                    Image(opened ? reward.rarity.openedCapsuleAssetName : reward.rarity.capsuleAssetName).resizable().scaledToFit().padding(opened ? 6 : 7).scaleEffect(simultaneousOpen ? 1.02 : 1.0)
                }
                .frame(width: side, height: side)
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func capsuleResultGrid(rewards: [GachaReward], contentWidth: CGFloat) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Layout.gridSpacing), count: 5)
        let side = max(54, min(64, (contentWidth - (Layout.gridSpacing * 4)) / 5))
        return LazyVGrid(columns: columns, spacing: Layout.gridSpacing) {
            ForEach(rewards, id: \.id) { reward in
                ResultRewardCard(reward: reward, isLarge: false, showsText: false, showsAccentBorder: false, usesRarityBackgroundAsset: true)
                    .frame(width: side, height: side)
                    .contentShape(RoundedRectangle(cornerRadius: Layout.gridCornerRadius, style: .continuous))
                    .onLongPressGesture(minimumDuration: 0.28) {
                        bgmManager.playSE(.push)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { revealOverlayReward = reward }
                    }
                    .onTapGesture { }
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private func enlargedRewardOverlay(reward: GachaReward, safeTop: CGFloat, safeBottom: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea().contentShape(Rectangle()).onTapGesture { withAnimation(.easeOut(duration: 0.18)) { revealOverlayReward = nil } }
            VStack(spacing: 18) {
                ResultHeadlineView(reward: reward)
                ResultRewardCard(reward: reward, isLarge: true, showsText: true, showsAccentBorder: false, usesRarityBackgroundAsset: true, largeImageSizeOverride: Layout.enlargedResultImageSize)
                    .frame(width: Layout.singleResultCardWidth, height: Layout.enlargedResultCardHeight)
                    .onTapGesture { }
                Text("画面をタップで閉じる").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.88))
            }
            .padding(.top, safeTop + 18)
            .padding(.bottom, safeBottom + 18)
            .padding(.horizontal, 22)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .zIndex(50)
    }

    private func handleOverlayTap() {
        if revealOverlayReward != nil { withAnimation(.easeOut(duration: 0.18)) { revealOverlayReward = nil }; return }
        switch phase {
        case .waitingTap: startOpeningSequence()
        case .showingSingleResult, .showingTenResult: finishOverlay()
        case .rolling, .openingSingle, .openingTen, .idle: break
        }
    }

    private func startOpeningSequence() {
        guard phase == .waitingTap else { return }
        openingTask?.cancel(); openingTask = nil
        bgmManager.playSE(.push)
        switch drawMode {
        case .single:
            phase = .openingSingle
            openingTask = Task {
                try? await Task.sleep(nanoseconds: 620_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { phase = .showingSingleResult }
            }
        case .ten:
            phase = .openingTen
            openingTask = Task {
                try? await Task.sleep(nanoseconds: 820_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { phase = .showingTenResult }
            }
        }
    }

    private func finishOverlay() {
        rollTask?.cancel(); rollTask = nil
        openingTask?.cancel(); openingTask = nil
        revealOverlayReward = nil
        persistState()
        withAnimation(.easeOut(duration: 0.18)) { overlayOpacity = 0.0; phase = .idle }
        rewards = []
        lastFreeAdSlot = nil
        lastDrawWasFreeAd = false
        if isTutorialMode { onTutorialFinished?() } else { rewardedAdManager.loadIfNeeded() }
    }

    private func persistState() {
        do { try modelContext.save() } catch { showToast("保存に失敗しました") }
    }

    private func formattedProbability(_ value: Double) -> String {
        if value >= 1 { return String(format: "%.0f%%", value) }
        return String(format: "%.1f%%", value)
    }

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation(.easeOut(duration: 0.2)) { showToast = true }
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            await MainActor.run { withAnimation(.easeIn(duration: 0.2)) { showToast = false } }
        }
    }
}

fileprivate struct TutorialGachaTeacherNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("👩‍🏫").font(.system(size: 24))
                Text("ガチャを体験してみよう").font(.system(size: 18, weight: .black)).foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            Text("ガチャは集めた歩数を消費してごはんやキャラクターを獲得できるよ！\n今回はチュートリアル限定で、無料で10回を引けるようにしておいたよ！\nガチャを引いてみよう！")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .lineSpacing(3)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.45), lineWidth: 1))
    }
}

fileprivate struct ResultHeadlineView: View {
    let reward: GachaReward
    var body: some View {
        VStack(spacing: 6) {
            Text(reward.rarity.displayName).font(.system(size: 22, weight: .black)).foregroundStyle(.white).padding(.horizontal, 18).padding(.vertical, 6).background(reward.rarity.accentColor.opacity(0.88), in: Capsule())
            Text(reward.categoryDisplayName).font(.system(size: 24, weight: .black)).foregroundStyle(.white).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.72).shadow(color: .black.opacity(0.35), radius: 3, y: 2)
        }
    }
}

fileprivate struct ResultRewardCard: View {
    let reward: GachaReward
    let isLarge: Bool
    let showsText: Bool
    let showsAccentBorder: Bool
    let usesRarityBackgroundAsset: Bool
    let largeImageSizeOverride: CGFloat?

    init(reward: GachaReward, isLarge: Bool, showsText: Bool, showsAccentBorder: Bool, usesRarityBackgroundAsset: Bool, largeImageSizeOverride: CGFloat? = nil) {
        self.reward = reward
        self.isLarge = isLarge
        self.showsText = showsText
        self.showsAccentBorder = showsAccentBorder
        self.usesRarityBackgroundAsset = usesRarityBackgroundAsset
        self.largeImageSizeOverride = largeImageSizeOverride
    }

    private var cornerRadius: CGFloat { isLarge ? 26 : 18 }
    private var imageSize: CGFloat { isLarge ? (largeImageSizeOverride ?? 176) : 52 }
    private var textSize: CGFloat { isLarge ? 21 : 9 }
    private var verticalSpacing: CGFloat { isLarge ? 14 : 3 }

    var body: some View {
        ZStack {
            background
            VStack(spacing: verticalSpacing) {
                Spacer(minLength: 0)
                Image(reward.imageName).resizable().scaledToFit().frame(width: imageSize, height: imageSize).shadow(color: .black.opacity(0.18), radius: isLarge ? 10 : 3, y: isLarge ? 6 : 2)
                if showsText {
                    Text(reward.title).font(.system(size: textSize, weight: .black)).foregroundStyle(.white).lineLimit(isLarge ? 2 : 2).minimumScaleFactor(0.62).multilineTextAlignment(.center).padding(.horizontal, isLarge ? 8 : 2).shadow(color: .black.opacity(0.42), radius: 2, y: 1)
                }
                Spacer(minLength: 0)
            }
            .padding(isLarge ? 18 : 5)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            if showsAccentBorder { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(reward.rarity.accentColor.opacity(0.92), lineWidth: isLarge ? 3 : 1.5) }
        }
        .shadow(color: reward.rarity.accentColor.opacity(isLarge ? 0.34 : 0.18), radius: isLarge ? 18 : 6, y: isLarge ? 9 : 3)
    }

    @ViewBuilder
    private var background: some View {
        if usesRarityBackgroundAsset {
            Image(reward.rarity.resultBackgroundAssetName).resizable().aspectRatio(contentMode: isLarge ? .fill : .fit).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Color.white.opacity(0.16))
                RadialGradient(colors: [reward.rarity.accentColor.opacity(0.32), Color.black.opacity(0.18)], center: .center, startRadius: 4, endRadius: isLarge ? 170 : 58)
            }
        }
    }
}

fileprivate struct RollingMachineView: View {
    let assetName: String
    let width: CGFloat
    let startDate: Date
    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            let shake = sin(elapsed * 28) * 7
            let rotation = sin(elapsed * 22) * 4
            Image(assetName).resizable().scaledToFit().frame(width: width).rotationEffect(.degrees(rotation)).offset(x: shake).shadow(color: .black.opacity(0.34), radius: 18, y: 10)
        }
    }
}

fileprivate struct TapPromptView: View {
    let isAnimating: Bool
    let count: Int
    var body: some View {
        VStack(spacing: 8) {
            Text("タップしてOPEN").font(.system(size: 24, weight: .black)).foregroundStyle(.white)
            HStack(spacing: 4) {
                ForEach(0..<max(count, 1), id: \.self) { _ in
                    Image(systemName: "hand.tap.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .scaleEffect(isAnimating ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true), value: isAnimating)
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.38), in: Capsule())
    }
}

fileprivate struct ToastView: View {
    let message: String
    var body: some View {
        Text(message).font(.system(size: 14, weight: .bold)).foregroundStyle(.white).multilineTextAlignment(.center).padding(.horizontal, 18).padding(.vertical, 12).background(Color.black.opacity(0.76), in: Capsule()).padding(.horizontal, 20)
    }
}

fileprivate struct GachaEmissionListView: View {
    @Environment(\.dismiss) private var dismiss
    let gacha: GachaDefinition
    private let columns: [GridItem] = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ZStack {
                emissionListBackground
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(gacha.emissionCharacters) { character in
                            VStack(spacing: 10) {
                                Image(character.imageName).resizable().scaledToFit().frame(width: 104, height: 104).padding(12).frame(maxWidth: .infinity).background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                Text(character.name).font(.system(size: 13, weight: .black)).foregroundStyle(.primary).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.72)
                            }
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 100)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("排出リスト")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }.font(.system(size: 15, weight: .bold))
                }
            }
        }
    }

    private var emissionListBackground: some View {
        ZStack {
            Image("gacha_background").resizable().scaledToFill().ignoresSafeArea()
            LinearGradient(colors: [Color.black.opacity(0.18), Color.black.opacity(0.38)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        }
    }
}
