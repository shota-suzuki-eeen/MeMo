//
//  MeMoWatchApp.swift
//  MeMo Watch App
//

import SwiftUI

@main
struct MeMoWatchApp: App {
    var body: some Scene {
        WindowGroup {
            MeMoWatchFoodEnabledHomeView()
        }
    }
}

// MARK: - Food-enabled Watch home container

private struct MeMoWatchFoodEnabledHomeView: View {
    @StateObject private var foodViewModel = MeMoWatchHomeViewModel()

    private let referenceSize = CGSize(width: 368, height: 448)

    var body: some View {
        ZStack {
            // The existing home view is kept intact. In particular, its step meter
            // implementation and layout are not modified by the food feature.
            MeMoWatchHomeView()

            GeometryReader { geometry in
                let width = geometry.size.width
                let safeHeight = geometry.size.height
                let scale = width / referenceSize.width
                let layoutHeight = max(safeHeight, referenceSize.height * scale)
                let layoutWidth = referenceSize.width * scale

                ZStack(alignment: .topLeading) {
                    if foodViewModel.hasToiletFlag {
                        WatchFloatingThoughtButton(
                            imageName: "wc_button",
                            size: 88 * scale,
                            amplitude: 5 * scale,
                            action: {
                                foodViewModel.refreshToiletState()
                            }
                        )
                        .position(
                            x: layoutWidth - (78 * scale),
                            y: 165 * scale
                        )
                        .zIndex(24)

                        WatchToiletPoopsLayer(
                            viewModel: foodViewModel,
                            layoutWidth: layoutWidth,
                            layoutHeight: layoutHeight,
                            scale: scale
                        )
                        .zIndex(28)
                    } else if foodViewModel.isFoodSelectorPresented {
                        // ごはん一覧の表示中は、ホーム画面の歩数メーターとキャラクターだけを
                        // 同じ背景画像で覆います。下部の幸せ度・満腹度ゲージはそのまま残します。
                        WatchFoodSelectorHomeContentCover(
                            backgroundAssetName: foodViewModel.backgroundAssetName,
                            layoutWidth: layoutWidth,
                            layoutHeight: layoutHeight,
                            scale: scale
                        )
                        .allowsHitTesting(false)
                        .zIndex(29)

                        WatchFoodSelectorOverlay(
                            viewModel: foodViewModel,
                            layoutWidth: layoutWidth,
                            layoutHeight: layoutHeight,
                            scale: scale
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(30)
                    } else if let pendingFood = foodViewModel.pendingFood {
                        WatchPendingFoodDecisionOverlay(
                            item: pendingFood,
                            dragOffsetY: foodViewModel.pendingFoodDragOffsetY,
                            isFeeding: foodViewModel.isFoodFeedingAnimationRunning,
                            scale: scale,
                            onDragChanged: { translationY in
                                foodViewModel.updatePendingFoodDrag(
                                    translationY: translationY
                                )
                            },
                            onDragEnded: { translationY, predictedEndTranslationY in
                                foodViewModel.endPendingFoodDrag(
                                    translationY: translationY,
                                    predictedEndTranslationY: predictedEndTranslationY
                                )
                            }
                        )
                        .frame(width: layoutWidth, height: layoutHeight)
                        .zIndex(25)
                    } else if foodViewModel.canShowFoodBubble {
                        WatchDesiredFoodThoughtButton(
                            desiredFoodAssetName: foodViewModel.desiredFoodAssetName,
                            size: 88 * scale,
                            amplitude: 5 * scale,
                            action: {
                                foodViewModel.openFoodSelector()
                            }
                        )
                        .position(x: 78 * scale, y: 165 * scale)
                        .zIndex(20)
                    }
                }
                .frame(width: layoutWidth, height: layoutHeight)
                .position(x: width * 0.5, y: layoutHeight * 0.5)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .task {
            await foodViewModel.start()
        }
    }
}

// MARK: - Toilet flag / poop interaction

private struct WatchFloatingThoughtButton: View {
    let imageName: String
    let size: CGFloat
    let amplitude: CGFloat
    let action: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFloating = false

    var body: some View {
        Button(action: action) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .contentShape(Rectangle())
                .offset(y: floatingOffset)
        }
        .buttonStyle(.plain)
        .onAppear {
            updateFloatingAnimation()
        }
        .onChange(of: scenePhase) { _, _ in
            updateFloatingAnimation()
        }
        .onChange(of: reduceMotion) { _, _ in
            updateFloatingAnimation()
        }
        .accessibilityLabel("トイレ")
    }

    private var floatingOffset: CGFloat {
        guard scenePhase == .active, !reduceMotion else { return 0 }
        return isFloating ? -amplitude : amplitude
    }

    private func updateFloatingAnimation() {
        guard scenePhase == .active, !reduceMotion, amplitude > 0 else {
            isFloating = false
            return
        }

        isFloating = false
        DispatchQueue.main.async {
            withAnimation(
                .easeInOut(duration: 0.85)
                    .repeatForever(autoreverses: true)
            ) {
                isFloating = true
            }
        }
    }
}

private struct WatchToiletPoopsLayer: View {
    @ObservedObject var viewModel: MeMoWatchHomeViewModel

    let layoutWidth: CGFloat
    let layoutHeight: CGFloat
    let scale: CGFloat

    @State private var lastGesturePoint: CGPoint?
    @State private var dirtyPoopIDs: Set<String> = []

    private var visiblePoops: [MeMoWatchToiletPoopSnapshot] {
        viewModel.visibleToiletPoops
    }

    private var poopSize: CGFloat {
        96 * scale
    }

    private var hitSize: CGFloat {
        116 * scale
    }

    private var scratchDistanceToClear: CGFloat {
        max(1, 420 * scale)
    }

    private var gestureMoveThreshold: CGFloat {
        max(2, 8 * scale)
    }

    private var tapDistanceThreshold: CGFloat {
        max(3, 10 * scale)
    }

    private var contentTopInset: CGFloat {
        88 * scale
    }

    var body: some View {
        ZStack {
            ForEach(visiblePoops) { poop in
                WatchToiletPoopView(
                    item: poop,
                    size: poopSize,
                    hitSize: hitSize
                )
                .position(position(for: poop))
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.82)))
            }

            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged(handleGestureChanged)
                        .onEnded(handleGestureEnded)
                )
        }
        .frame(width: layoutWidth, height: layoutHeight)
        .clipped()
    }

    private func position(
        for poop: MeMoWatchToiletPoopSnapshot
    ) -> CGPoint {
        let contentHeight = max(1, layoutHeight - contentTopInset)
        let x = min(
            layoutWidth - (hitSize * 0.5),
            max(
                hitSize * 0.5,
                CGFloat(poop.centerXRatio) * layoutWidth
            )
        )
        let y = min(
            layoutHeight - (hitSize * 0.5),
            max(
                contentTopInset + (hitSize * 0.5),
                contentTopInset
                    + (CGFloat(poop.centerYRatio) * contentHeight)
            )
        )
        return CGPoint(x: x, y: y)
    }

    private func hitRect(
        for poop: MeMoWatchToiletPoopSnapshot
    ) -> CGRect {
        let center = position(for: poop)
        return CGRect(
            x: center.x - (hitSize * 0.5),
            y: center.y - (hitSize * 0.5),
            width: hitSize,
            height: hitSize
        )
    }

    private func scratchRect(
        for poop: MeMoWatchToiletPoopSnapshot
    ) -> CGRect {
        hitRect(for: poop).insetBy(
            dx: 5 * scale,
            dy: 5 * scale
        )
    }

    private func handleGestureChanged(
        _ value: DragGesture.Value
    ) {
        let point = value.location
        let previousPoint = lastGesturePoint
        let movedDistanceFromStart = hypot(
            point.x - value.startLocation.x,
            point.y - value.startLocation.y
        )

        defer {
            lastGesturePoint = point
        }

        guard movedDistanceFromStart >= gestureMoveThreshold else {
            return
        }

        for poop in visiblePoops {
            let rect = scratchRect(for: poop)
            let isInside = rect.contains(point)
            let wasInside = previousPoint.map {
                rect.contains($0)
            } ?? false

            guard isInside || wasInside else {
                continue
            }

            guard let previousPoint else {
                continue
            }

            let segmentDistance = distanceInsideRect(
                from: previousPoint,
                to: point,
                rect: rect
            )
            guard segmentDistance > 0 else {
                continue
            }

            let current = viewModel.toiletPoopProgress(id: poop.id)
            let next = min(
                1,
                current + Double(segmentDistance / scratchDistanceToClear)
            )

            viewModel.previewToiletPoopProgress(
                id: poop.id,
                progress: next
            )
            dirtyPoopIDs.insert(poop.id)
        }
    }

    private func handleGestureEnded(
        _ value: DragGesture.Value
    ) {
        defer {
            lastGesturePoint = nil
            dirtyPoopIDs.removeAll()
        }

        let totalDistance = hypot(
            value.location.x - value.startLocation.x,
            value.location.y - value.startLocation.y
        )

        if totalDistance < tapDistanceThreshold {
            guard let poop = visiblePoops.reversed().first(where: {
                hitRect(for: $0).contains(value.location)
            }) else {
                return
            }

            viewModel.tapToiletPoop(id: poop.id)
            return
        }

        for poopID in dirtyPoopIDs {
            viewModel.commitToiletPoopProgress(
                id: poopID,
                progress: viewModel.toiletPoopProgress(id: poopID)
            )
        }
    }

    private func distanceInsideRect(
        from start: CGPoint,
        to end: CGPoint,
        rect: CGRect
    ) -> CGFloat {
        let totalDistance = hypot(
            end.x - start.x,
            end.y - start.y
        )
        guard totalDistance > 0 else { return 0 }

        let sampleCount = 12
        var insideDistance: CGFloat = 0
        var previous = start
        var previousInside = rect.contains(previous)

        for index in 1...sampleCount {
            let t = CGFloat(index) / CGFloat(sampleCount)
            let current = CGPoint(
                x: start.x + ((end.x - start.x) * t),
                y: start.y + ((end.y - start.y) * t)
            )
            let currentInside = rect.contains(current)

            if previousInside || currentInside {
                insideDistance += hypot(
                    current.x - previous.x,
                    current.y - previous.y
                )
            }

            previous = current
            previousInside = currentInside
        }

        return insideDistance
    }
}

private struct WatchToiletPoopView: View {
    let item: MeMoWatchToiletPoopSnapshot
    let size: CGFloat
    let hitSize: CGFloat

    private var opacity: Double {
        max(0, min(1, 1 - item.cleanedProgress))
    }

    var body: some View {
        Image("poop")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(
                x: item.isFlippedHorizontally ? -1 : 1,
                y: 1
            )
            .rotationEffect(.degrees(item.rotationDegrees))
            .opacity(opacity)
            .animation(.easeOut(duration: 0.20), value: opacity)
            .frame(width: hitSize, height: hitSize)
            .contentShape(Rectangle())
    }
}
// MARK: - Selector-only home content cover

private struct WatchFoodSelectorHomeContentCover: View {
    let backgroundAssetName: String
    let layoutWidth: CGFloat
    let layoutHeight: CGFloat
    let scale: CGFloat

    var body: some View {
        Image(backgroundAssetName)
            .resizable()
            .scaledToFill()
            .frame(width: layoutWidth, height: layoutHeight)
            .clipped()
            .background(Color(red: 0.95, green: 0.88, blue: 0.78))
            .mask {
                ZStack {
                    // 既存の歩数メーター領域だけを背景で隠す。
                    RoundedRectangle(cornerRadius: 30 * scale, style: .continuous)
                        .frame(width: 306 * scale, height: 104 * scale)
                        .position(x: layoutWidth * 0.5, y: 76 * scale)

                    // キャラクター上半身〜胴体。下部ゲージへ被らない高さまで広く覆う。
                    RoundedRectangle(cornerRadius: 34 * scale, style: .continuous)
                        .frame(width: 232 * scale, height: 205 * scale)
                        .position(x: layoutWidth * 0.5, y: 205 * scale)

                    // キャラクター下半身と影。左右のステータスゲージを残すため幅を絞る。
                    RoundedRectangle(cornerRadius: 28 * scale, style: .continuous)
                        .frame(width: 132 * scale, height: 185 * scale)
                        .position(x: layoutWidth * 0.5, y: 340 * scale)
                }
            }
    }
}

// MARK: - Desired food thought bubble

private struct WatchDesiredFoodThoughtButton: View {
    let desiredFoodAssetName: String?
    let size: CGFloat
    let amplitude: CGFloat
    let action: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFloating = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Image("food_button")
                    .resizable()
                    .scaledToFit()

                if let desiredFoodAssetName {
                    Image(desiredFoodAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * 0.54, height: size * 0.54)
                        .offset(y: -size * 0.10)
                }
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .offset(y: floatingOffset)
        }
        .buttonStyle(.plain)
        .onAppear {
            updateFloatingAnimation()
        }
        .onChange(of: scenePhase) { _, _ in
            updateFloatingAnimation()
        }
        .onChange(of: reduceMotion) { _, _ in
            updateFloatingAnimation()
        }
        .accessibilityLabel("ごはんを選ぶ")
    }

    private var floatingOffset: CGFloat {
        guard scenePhase == .active, !reduceMotion else { return 0 }
        return isFloating ? -amplitude : amplitude
    }

    private func updateFloatingAnimation() {
        guard scenePhase == .active, !reduceMotion, amplitude > 0 else {
            isFloating = false
            return
        }

        isFloating = false
        DispatchQueue.main.async {
            withAnimation(
                .easeInOut(duration: 0.85)
                    .repeatForever(autoreverses: true)
            ) {
                isFloating = true
            }
        }
    }
}

// MARK: - Owned-food selector

private struct WatchFoodSelectorOverlay: View {
    @ObservedObject var viewModel: MeMoWatchHomeViewModel

    let layoutWidth: CGFloat
    let layoutHeight: CGFloat
    let scale: CGFloat

    @FocusState private var isCrownFocused: Bool

    private struct VisibleFoodCard: Identifiable {
        let item: MeMoWatchFoodItemSnapshot
        let relativeIndex: Int

        var id: String {
            item.id
        }
    }

    private var foods: [MeMoWatchFoodItemSnapshot] {
        viewModel.currentFoodSelectorFoods
    }

    private var selectedIndex: Int {
        viewModel.selectedFoodIndex
    }

    private var crownPosition: Binding<Double> {
        Binding(
            get: {
                Double(viewModel.selectedFoodIndex)
            },
            set: { newValue in
                guard !foods.isEmpty else { return }
                viewModel.selectFood(at: Int(newValue.rounded()))
            }
        )
    }

    private var crownUpperBound: Double {
        Double(max(1, foods.count - 1))
    }

    private var visibleCards: [VisibleFoodCard] {
        guard !foods.isEmpty else { return [] }

        let candidateRelativeIndexes = [0, -1, 1, -2, 2]
        var usedIndexes = Set<Int>()
        var cards: [VisibleFoodCard] = []

        for relativeIndex in candidateRelativeIndexes {
            let index = positiveModulo(selectedIndex + relativeIndex, foods.count)
            guard usedIndexes.insert(index).inserted else { continue }
            cards.append(
                VisibleFoodCard(
                    item: foods[index],
                    relativeIndex: relativeIndex
                )
            )
        }

        return cards.sorted {
            abs($0.relativeIndex) > abs($1.relativeIndex)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.10)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.closeFoodSelector()
                }

            if foods.isEmpty {
                WatchFoodSelectorEmptyState(
                    message: viewModel.selectedFoodRarityTab.emptyMessage,
                    scale: scale
                )
                .position(x: layoutWidth * 0.5, y: layoutHeight * 0.54)
            } else {
                ForEach(visibleCards) { card in
                    WatchFoodSelectorCard(
                        item: card.item,
                        relativeIndex: card.relativeIndex,
                        scale: scale,
                        isSelected: card.item.id == viewModel.selectedFoodID,
                        onTap: {
                            if card.item.id == viewModel.selectedFoodID {
                                viewModel.confirmSelectedFood()
                            } else {
                                viewModel.selectFood(id: card.item.id)
                            }
                        }
                    )
                    .position(
                        x: layoutWidth * 0.5,
                        y: selectorCardCenterY(for: card.relativeIndex)
                    )
                }

                VStack(spacing: 2 * scale) {
                    Text(viewModel.selectedFood?.name ?? "")
                        .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("スワイプ / Digital Crown")
                        .font(.system(size: 8.5 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                }
                .frame(width: 210 * scale)
                .position(x: layoutWidth * 0.5, y: layoutHeight - (33 * scale))
                .allowsHitTesting(false)
            }

            WatchFoodRarityToggleButton(
                selectedTab: viewModel.selectedFoodRarityTab,
                scale: scale,
                action: {
                    viewModel.toggleFoodRarity()
                }
            )
            .position(
                x: layoutWidth - (86 * scale),
                y: 96 * scale
            )
            .zIndex(100)
        }
        .frame(width: layoutWidth, height: layoutHeight)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 16 * scale)
                .onEnded { value in
                    guard !foods.isEmpty else { return }

                    let vertical = value.translation.height
                    let horizontal = value.translation.width
                    guard abs(vertical) > abs(horizontal) else { return }

                    if vertical < 0 {
                        viewModel.moveFoodSelection(1)
                    } else {
                        viewModel.moveFoodSelection(-1)
                    }
                }
        )
        .focusable(true)
        .focused($isCrownFocused)
        .digitalCrownRotation(
            crownPosition,
            from: 0,
            through: crownUpperBound,
            by: 1,
            sensitivity: .medium,
            isContinuous: foods.count > 1,
            isHapticFeedbackEnabled: true
        )
        .onAppear {
            isCrownFocused = true
        }
        .onChange(of: viewModel.selectedFoodRarityTab) { _, _ in
            isCrownFocused = true
        }
    }

    private func selectorCardCenterY(for relativeIndex: Int) -> CGFloat {
        let centerY = layoutHeight * 0.55
        let distance = 84 * scale
        return centerY + (CGFloat(relativeIndex) * distance)
    }

    private func positiveModulo(_ value: Int, _ modulus: Int) -> Int {
        guard modulus > 0 else { return value }
        let remainder = value % modulus
        return remainder >= 0 ? remainder : remainder + modulus
    }
}

private struct WatchFoodSelectorCard: View {
    let item: MeMoWatchFoodItemSnapshot
    let relativeIndex: Int
    let scale: CGFloat
    let isSelected: Bool
    let onTap: () -> Void

    private var distance: CGFloat {
        CGFloat(abs(relativeIndex))
    }

    private var cardSide: CGFloat {
        switch abs(relativeIndex) {
        case 0:
            // 中央の選択中カードは、皿とごはんを元サイズの1.5倍で表示する。
            return 128 * 1.5 * scale
        case 1:
            return 82 * scale
        default:
            return 58 * scale
        }
    }

    private var foodImageSide: CGFloat {
        // ごはんも皿と同じ倍率で拡大されるよう、常にカードサイズ基準にする。
        cardSide * 0.66
    }

    private var opacity: Double {
        switch abs(relativeIndex) {
        case 0:
            return 1.0
        case 1:
            return 0.92
        default:
            return 0.66
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Image("dish")
                    .resizable()
                    .scaledToFit()
                    .frame(width: cardSide, height: cardSide)

                Circle()
                    .fill(rarityAccent.opacity(isSelected ? 0.20 : 0.08))
                    .frame(width: cardSide * 0.66, height: cardSide * 0.66)
                    .blur(radius: 7 * scale)

                Image(item.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: foodImageSide, height: foodImageSide)
            }
            .frame(width: cardSide, height: cardSide)
            .overlay(alignment: .bottomTrailing) {
                Text("x\(max(0, item.count))")
                    .font(.system(size: max(7, 10 * scale), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6 * scale)
                    .padding(.vertical, 3 * scale)
                    .background(Color.black.opacity(0.70), in: Capsule())
                    .offset(x: 4 * scale, y: 4 * scale)
            }
            .shadow(
                color: isSelected ? rarityAccent.opacity(0.34) : .black.opacity(0.10),
                radius: isSelected ? 11 * scale : 4 * scale,
                x: 0,
                y: 4 * scale
            )
            .opacity(opacity)
            .scaleEffect(isSelected ? 1.0 : max(0.82, 1.0 - (distance * 0.04)))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.26, dampingFraction: 0.84), value: relativeIndex)
        .animation(.spring(response: 0.26, dampingFraction: 0.84), value: isSelected)
        .accessibilityLabel("\(item.name)、\(item.count)個")
        .accessibilityHint(isSelected ? "タップして仮決定" : "タップして選択")
    }

    private var rarityAccent: Color {
        item.isRare
            ? Color(red: 0.97, green: 0.34, blue: 0.38)
            : Color(red: 0.24, green: 0.56, blue: 0.98)
    }
}

private struct WatchFoodRarityToggleButton: View {
    let selectedTab: MeMoWatchFoodRarityTab
    let scale: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Color.black.opacity(0.001)

                HStack(spacing: 7 * scale) {
                    rarityPill(
                        title: selectedTab.rawValue,
                        isActive: true
                    )

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14 * scale, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))

                    rarityPill(
                        title: selectedTab.next.rawValue,
                        isActive: false
                    )
                }
                .padding(.horizontal, 10 * scale)
                .padding(.vertical, 8 * scale)
                .background(
                    Color.black.opacity(0.52),
                    in: Capsule()
                )
            }
            .frame(
                width: 148 * scale,
                height: 68 * scale
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("NとRを切り替える")
    }

    @ViewBuilder
    private func rarityPill(title: String, isActive: Bool) -> some View {
        Text(title)
            .font(.system(size: 16 * scale, weight: .black, design: .rounded))
            .foregroundStyle(isActive ? .white : .white.opacity(0.72))
            .frame(width: 38 * scale, height: 38 * scale)
            .background(
                isActive ? selectedAccent : Color.white.opacity(0.16),
                in: Circle()
            )
    }

    private var selectedAccent: Color {
        selectedTab == .normal
            ? Color(red: 0.24, green: 0.56, blue: 0.98)
            : Color(red: 0.97, green: 0.34, blue: 0.38)
    }
}

private struct WatchFoodSelectorEmptyState: View {
    let message: String
    let scale: CGFloat

    var body: some View {
        VStack(spacing: 8 * scale) {
            Image(systemName: "takeoutbag.and.cup.and.straw")
                .font(.system(size: 24 * scale, weight: .semibold))
                .foregroundStyle(.white.opacity(0.90))

            Text(message)
                .font(.system(size: 12 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 18 * scale)
        .padding(.vertical, 14 * scale)
        .background(Color.black.opacity(0.44), in: RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
    }
}

// MARK: - Pending feed decision on home

private struct WatchPendingFoodDecisionOverlay: View {
    let item: MeMoWatchFoodItemSnapshot
    let dragOffsetY: CGFloat
    let isFeeding: Bool
    let scale: CGFloat
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: (CGFloat, CGFloat) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFloating = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .contentShape(Rectangle())

            VStack(spacing: 0) {
                Text("↑ あげる")
                    .font(.system(size: 11 * scale, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10 * scale)
                    .padding(.vertical, 5 * scale)
                    .background(Color.black.opacity(0.48), in: Capsule())
                    .opacity(dragOffsetY < -8 ? 1.0 : 0.72)

                Spacer()

                Text("↓ キャンセル")
                    .font(.system(size: 10 * scale, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.94))
                    .padding(.horizontal, 10 * scale)
                    .padding(.vertical, 5 * scale)
                    .background(Color.black.opacity(0.42), in: Capsule())
                    .opacity(dragOffsetY > 8 ? 1.0 : 0.66)
            }
            .padding(.top, 104 * scale)
            .padding(.bottom, 74 * scale)
            .allowsHitTesting(false)

            ZStack {
                Image("dish")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 128 * scale, height: 128 * scale)

                Circle()
                    .fill(rarityAccent.opacity(0.18))
                    .frame(width: 88 * scale, height: 88 * scale)
                    .blur(radius: 8 * scale)

                Image(item.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 86 * scale, height: 86 * scale)
            }
            .overlay(alignment: .bottomTrailing) {
                Text("x\(max(0, item.count))")
                    .font(.system(size: 10 * scale, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7 * scale)
                    .padding(.vertical, 4 * scale)
                    .background(Color.black.opacity(0.72), in: Capsule())
                    .offset(x: 5 * scale, y: 5 * scale)
            }
            .position(x: 184 * scale, y: 260 * scale)
            .offset(y: visualOffsetY)
            .scaleEffect(isFeeding ? 1.08 : 1.0)
            .opacity(isFeeding ? 0.15 : 1.0)
            .shadow(color: rarityAccent.opacity(0.28), radius: 12 * scale, x: 0, y: 5 * scale)
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 8 * scale)
                .onChanged { value in
                    onDragChanged(value.translation.height)
                }
                .onEnded { value in
                    onDragEnded(
                        value.translation.height,
                        value.predictedEndTranslation.height
                    )
                }
        )
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 0.90)
                    .repeatForever(autoreverses: true)
            ) {
                isFloating = true
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.80), value: dragOffsetY)
        .animation(.easeOut(duration: 0.18), value: isFeeding)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name)を仮決定中")
        .accessibilityHint("上にスワイプしてあげる、下にスワイプしてキャンセル")
    }

    private var visualOffsetY: CGFloat {
        let floatOffset: CGFloat
        if reduceMotion || isFeeding || abs(dragOffsetY) > 1 {
            floatOffset = 0
        } else {
            floatOffset = isFloating ? -(4 * scale) : (4 * scale)
        }
        return dragOffsetY + floatOffset
    }

    private var rarityAccent: Color {
        item.isRare
            ? Color(red: 0.97, green: 0.34, blue: 0.38)
            : Color(red: 0.24, green: 0.56, blue: 0.98)
    }
}
