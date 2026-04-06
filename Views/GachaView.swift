//
//  GachaView.swift
//  MeMo
//
//  Updated on 2026/04/06.
//

import SwiftUI

fileprivate enum GachaRarity: String, CaseIterable, Identifiable {
    case blue
    case red
    case gold

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue: return "ブルー"
        case .red: return "レッド"
        case .gold: return "ゴールド"
        }
    }

    var itemRankText: String {
        switch self {
        case .blue: return "N"
        case .red: return "R"
        case .gold: return "SSR"
        }
    }

    var probability: Double {
        switch self {
        case .blue: return 0.66
        case .red: return 0.33
        case .gold: return 0.01
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

    var accentColor: Color {
        switch self {
        case .blue: return Color(red: 0.34, green: 0.67, blue: 1.0)
        case .red: return Color(red: 1.0, green: 0.39, blue: 0.35)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.18)
        }
    }

    var dummyNames: [String] {
        switch self {
        case .blue:
            return ["ふつうのメモ", "ちいさなメモ", "あおいしるし", "みならいバッジ", "いつものかけら"]
        case .red:
            return ["きらめきメモ", "なかよしバッジ", "レアなかけら", "しあわせのしるし", "ひみつのしおり"]
        case .gold:
            return ["でんせつのメモ", "ゴールドバッジ", "まぼろしのかけら", "きせきのしおり", "ひかりのしるし"]
        }
    }
}

fileprivate struct GachaReward: Identifiable, Hashable {
    let id = UUID()
    let rarity: GachaRarity
    let title: String
    let subtitle: String
    let imageName: String
}

struct GachaView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var phase: Phase = .idle
    @State private var drawMode: DrawMode = .single
    @State private var rewards: [GachaReward] = []
    @State private var revealOverlayReward: GachaReward?
    @State private var machineAnimationStart = Date()
    @State private var tapPromptAnimating = false
    @State private var overlayOpacity: Double = 0.0
    @State private var rollTask: Task<Void, Never>?

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
    }

    private enum Layout {
        static let backgroundAssetName = "Home_background"
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
        static let zoomCardMaxWidth: CGFloat = 300
    }

    private var isOverlayVisible: Bool {
        phase != .idle
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
            }
            .ignoresSafeArea()
        }
        .statusBarHidden()
        .onAppear {
            tapPromptAnimating = true
        }
        .onDisappear {
            rollTask?.cancel()
            rollTask = nil
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

                descriptionPanel
                    .frame(maxWidth: contentWidth)

                actionButtons
                    .frame(maxWidth: contentWidth)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, max(bottomInset, 16) + 24)
        }
    }

    private var descriptionPanel: some View {
        VStack(spacing: 10) {
            Text("カプセルを回してダミーアイテムを獲得しよう")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 6) {
                rarityRow(rarity: .blue, text: "66%")
                rarityRow(rarity: .red, text: "33%")
                rarityRow(rarity: .gold, text: "1%")
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func rarityRow(rarity: GachaRarity, text: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(rarity.accentColor)
                .frame(width: 10, height: 10)

            Text("\(rarity.displayName) : \(text)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 14) {
            drawButton(title: "1回", accent: .white, mode: .single)
            drawButton(title: "10回", accent: Color(red: 1.0, green: 0.86, blue: 0.24), mode: .ten)
        }
        .disabled(phase != .idle)
        .opacity(phase == .idle ? 1 : 0.5)
    }

    private func drawButton(title: String, accent: Color, mode: DrawMode) -> some View {
        Button {
            startDraw(mode: mode)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.buttonCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.48))

                RoundedRectangle(cornerRadius: Layout.buttonCornerRadius, style: .continuous)
                    .stroke(accent.opacity(0.95), lineWidth: 2)

                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(accent)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Layout.buttonHeight)
        }
        .buttonStyle(.plain)
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

            Text(drawMode == .single ? "ガチャを回しています…" : "10連ガチャを回しています…")
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

            TapPromptView(isAnimating: tapPromptAnimating, count: 1)
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
                    showsAccentBorder: false
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
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    revealOverlayReward = nil
                }

            ScrollView(showsIndicators: false) {
                VStack {
                    unifiedLargeRewardView(reward: reward)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, safeTop + 18)
                .padding(.bottom, max(safeBottom, 16) + 20)
                .padding(.horizontal, 18)
                .frame(minHeight: UIScreen.main.bounds.height - safeTop - safeBottom)
                .contentShape(Rectangle())
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    revealOverlayReward = nil
                }
            )
        }
        .transition(.opacity)
        .zIndex(50)
    }

    private func startDraw(mode: DrawMode) {
        rollTask?.cancel()
        rollTask = nil
        drawMode = mode
        phase = .rolling
        rewards = makeRewards(count: mode.count)
        revealOverlayReward = nil
        machineAnimationStart = Date()
        tapPromptAnimating = true

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

    private func handleOverlayTap() {
        guard revealOverlayReward == nil else {
            revealOverlayReward = nil
            return
        }

        switch phase {
        case .waitingTap:
            if drawMode == .single {
                openSingleSequence()
            } else {
                openTenSequence()
            }

        case .showingSingleResult, .showingTenResult:
            closeOverlay()

        case .idle, .rolling, .openingSingle, .openingTen:
            break
        }
    }

    private func openSingleSequence() {
        rollTask?.cancel()
        rollTask = Task {
            await MainActor.run {
                phase = .openingSingle
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                phase = .showingSingleResult
            }
        }
    }

    private func openTenSequence() {
        rollTask?.cancel()
        rollTask = Task {
            await MainActor.run {
                phase = .openingTen
            }
            try? await Task.sleep(nanoseconds: 480_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                phase = .showingTenResult
            }
        }
    }

    private func closeOverlay() {
        rollTask?.cancel()
        rollTask = nil
        revealOverlayReward = nil

        withAnimation(.easeOut(duration: 0.18)) {
            overlayOpacity = 0.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            phase = .idle
        }
    }

    private func makeRewards(count: Int) -> [GachaReward] {
        (0..<count).map { _ in
            let rarity = rollRarity()
            let itemName = rarity.dummyNames.randomElement() ?? "ダミーアイテム"
            return GachaReward(
                rarity: rarity,
                title: itemName,
                subtitle: "ダミー報酬 / \(rarity.itemRankText)",
                imageName: rarity.openedCapsuleAssetName
            )
        }
    }

    private func rollRarity() -> GachaRarity {
        let value = Double.random(in: 0..<1)
        if value < GachaRarity.gold.probability {
            return .gold
        }
        if value < GachaRarity.gold.probability + GachaRarity.red.probability {
            return .red
        }
        return .blue
    }
}

private struct RollingMachineView: View {
    let assetName: String
    let width: CGFloat
    let startDate: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let angle = sin(elapsed * 11.0) * 9.0
            let xOffset = sin(elapsed * 13.0) * 9.0

            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: width)
                .rotationEffect(.degrees(angle), anchor: .init(x: 0.5, y: 0.88))
                .offset(x: xOffset)
                .shadow(color: .black.opacity(0.28), radius: 22, y: 12)
        }
    }
}

private struct TapPromptView: View {
    let isAnimating: Bool
    let count: Int

    @State private var phase = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<count, id: \.self) { _ in
                Text("TAP!")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
                    .scaleEffect(phase ? 1.08 : 0.94)
                    .offset(y: phase ? -5 : 5)
            }
        }
        .shadow(color: .white.opacity(0.28), radius: 10)
        .onAppear {
            guard isAnimating else { return }
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                phase = true
            }
        }
    }
}

private struct ResultHeadlineView: View {
    let reward: GachaReward

    var body: some View {
        VStack(spacing: 8) {
            Text(reward.rarity.itemRankText)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(reward.rarity.accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1), in: Capsule())

            Text("\(reward.title) をゲット！")
                .font(.system(size: 24, weight: .black))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
    }
}

private struct ResultRewardCard: View {
    let reward: GachaReward
    let isLarge: Bool
    let showsText: Bool
    let showsAccentBorder: Bool

    var body: some View {
        VStack(spacing: showsText ? (isLarge ? 14 : 10) : 0) {
            Spacer(minLength: 0)

            Image(reward.imageName)
                .resizable()
                .scaledToFit()
                .frame(
                    maxWidth: isLarge ? 180 : 54,
                    maxHeight: isLarge ? 180 : 54
                )
                .shadow(color: reward.rarity.accentColor.opacity(isLarge ? 0.55 : 0.28), radius: isLarge ? 22 : 8)

            if showsText {
                VStack(spacing: 6) {
                    Text(reward.title)
                        .font(.system(size: isLarge ? 22 : 16, weight: .black))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(reward.subtitle)
                        .font(.system(size: isLarge ? 14 : 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(isLarge ? 22 : 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(isLarge ? 0.36 : 0.18))
        )
        .overlay {
            if showsAccentBorder {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(reward.rarity.accentColor.opacity(0.95), lineWidth: isLarge ? 2.5 : 1.6)
            }
        }
        .shadow(color: .black.opacity(0.22), radius: 12, y: 8)
    }
}

#Preview {
    GachaView()
}
