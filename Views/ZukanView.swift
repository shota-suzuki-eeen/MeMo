//
//  ZukanView.swift
//  MeMo
//
//  Updated for character / wallpaper switching UI.
//

import SwiftUI
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

struct ZukanView: View {
    @Query private var appStates: [AppState]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var bgmManager: BGMManager
    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false
    @AppStorage(WallpaperCatalog.selectedHomeWallpaperAssetNameKey)
    private var currentHomeWallpaperAssetName: String = WallpaperCatalog.defaultWallpaper.assetName

    @StateObject private var viewModel = ZukanViewModel()
    @State private var selectedPetID: String? = nil
    @State private var selectedWallpaperAssetName: String? = nil
    @State private var selectedSection: ZukanSection = .character
    @State private var characterCurrentPage: Int = 0
    @State private var wallpaperCurrentPage: Int = 0

    private var state: AppState? { appStates.first }

    private let characterColumns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 3
    )

    private let wallpaperColumns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 3
    )

    private var ownedWallpapers: [WallpaperCatalog.WallpaperItem] {
        WallpaperCatalog.ownedWallpapers()
    }

    private var effectiveCurrentHomeWallpaperAssetName: String {
        let ownedAssetNames = Set(ownedWallpapers.map(\.assetName))
        if ownedAssetNames.contains(currentHomeWallpaperAssetName) {
            return currentHomeWallpaperAssetName
        }
        return WallpaperCatalog.defaultWallpaper.assetName
    }

    private var selectedWallpaper: WallpaperCatalog.WallpaperItem? {
        let preferredAssetName = selectedWallpaperAssetName ?? effectiveCurrentHomeWallpaperAssetName
        return WallpaperCatalog.item(for: preferredAssetName) ?? ownedWallpapers.first
    }

    private var activeCurrentPage: Int {
        switch selectedSection {
        case .character:
            return characterCurrentPage
        case .wallpaper:
            return wallpaperCurrentPage
        }
    }

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()

            if let state {
                VStack(spacing: 16) {
                    ZukanSectionTabs(
                        selectedSection: selectedSection,
                        onSelect: { section in
                            guard selectedSection != section else { return }
                            bgmManager.playSE(.push)
                            selectedSection = section
                            clampPages(state: state)
                        }
                    )

                    currentSelectionCard(state: state)
                    ownedItemsPanel(state: state)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                VStack {
                    Spacer(minLength: 0)
                    Text("（準備中）")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
        }
        .background(
            ZStack {
                Image("zukan_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.18)
                    .ignoresSafeArea()
            }
        )
        .navigationTitle("図鑑")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            bgmManager.switchBackground(to: .zukan)
            guard let state else { return }

            state.ensureInitialPetsIfNeeded()
            syncCharacterSelectionAndPage(state: state)
            syncWallpaperSelectionAndPage()
            clampPages(state: state)
            updateWidgetSnapshot(state: state, forceReload: true)
        }
        .onDisappear {
            bgmManager.restoreDefaultBackground()
        }
        .onChange(of: state?.normalizedCurrentPetID) { _, _ in
            guard let state else { return }
            syncCharacterSelectionAndPage(state: state)
        }
        .onChange(of: state?.ownedPetIDsData) { _, _ in
            guard let state else { return }
            syncCharacterSelectionAndPage(state: state)
        }
        .onChange(of: currentHomeWallpaperAssetName) { _, _ in
            syncWallpaperSelectionAndPage()
        }
    }

    @ViewBuilder
    private func currentSelectionCard(state: AppState) -> some View {
        switch selectedSection {
        case .character:
            let selectedPetID = selectedPetID ?? state.normalizedCurrentPetID
            let selectedName = PetMaster.all.first(where: { $0.id == selectedPetID })?.name ?? selectedPetID
            let selectedImageName = PetMaster.assetName(for: selectedPetID)
            let descriptionText = PetMaster.description(for: selectedPetID)
            let isCurrentPet = state.normalizedCurrentPetID == selectedPetID

            VStack(alignment: .leading, spacing: 12) {
                Text("現在選択中のキャラクター")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)

                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.blue.opacity(0.14))

                        Image(selectedImageName)
                            .resizable()
                            .scaledToFit()
                            .padding(18)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 240)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(selectedName)
                            .font(.title3.weight(.bold))

                        Text(descriptionText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer(minLength: 0)

                        Button {
                            handleTrainTapped(state: state, id: selectedPetID)
                        } label: {
                            Text(
                                isCurrentPet
                                ? "\(selectedName) をお世話中"
                                : (
                                    isDeveloperMode
                                    ? "\(selectedName) をお世話する（広告なし）"
                                    : "\(selectedName) をお世話する"
                                )
                            )
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isCurrentPet)
                        .opacity(isCurrentPet ? 0.65 : 1.0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200, maxHeight: 240, alignment: .topLeading)
                }
            }
            .padding(16)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))

        case .wallpaper:
            let selectedWallpaper = selectedWallpaper ?? WallpaperCatalog.defaultWallpaper
            let isCurrentWallpaper = selectedWallpaper.assetName == effectiveCurrentHomeWallpaperAssetName

            VStack(alignment: .leading, spacing: 12) {
                Text("現在選択中の壁紙")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)

                VStack(spacing: 14) {
                    ZStack(alignment: .bottomLeading) {
                        Image(selectedWallpaper.assetName)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, minHeight: 210, maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 18))

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.46)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedWallpaper.name)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)

                            Text(isCurrentWallpaper ? "現在設定中" : "プレビュー中")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(16)
                    }

                    Button {
                        handleWallpaperSetTapped()
                    } label: {
                        Text(
                            isCurrentWallpaper
                            ? "\(selectedWallpaper.name) を設定中"
                            : "\(selectedWallpaper.name) を設定する"
                        )
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCurrentWallpaper)
                    .opacity(isCurrentWallpaper ? 0.65 : 1.0)
                }
            }
            .padding(16)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    private func ownedItemsPanel(state: AppState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedSection == .character ? "所持しているキャラクター" : "所持している壁紙")
                    .font(.headline.weight(.bold))

                Spacer()

                ZukanPageControl(
                    currentPage: activeCurrentPage,
                    pageCount: activePageCount(state: state),
                    onPrevious: {
                        guard activeCurrentPage > 0 else { return }
                        bgmManager.playSE(.push)
                        updateActivePage(activeCurrentPage - 1)
                    },
                    onNext: {
                        let pageCount = activePageCount(state: state)
                        guard activeCurrentPage < pageCount - 1 else { return }
                        bgmManager.playSE(.push)
                        updateActivePage(activeCurrentPage + 1)
                    }
                )
            }

            if selectedSection == .character {
                let slots = viewModel.slotsForPage(state: state, page: characterCurrentPage)

                LazyVGrid(columns: characterColumns, spacing: 10) {
                    ForEach(slots) { slot in
                        ZukanCharacterCell(
                            petID: slot.id,
                            isCurrent: slot.isCurrentPet,
                            isSelected: selectedPetID == slot.id,
                            onTap: {
                                bgmManager.playSE(.push)
                                selectedPetID = slot.id
                            }
                        )
                    }
                }
            } else {
                let wallpaperItems = viewModel.wallpaperItemsForPage(ownedWallpapers, page: wallpaperCurrentPage)

                LazyVGrid(columns: wallpaperColumns, spacing: 10) {
                    ForEach(wallpaperItems) { item in
                        ZukanWallpaperCell(
                            wallpaper: item,
                            isCurrent: item.assetName == effectiveCurrentHomeWallpaperAssetName,
                            isSelected: item.assetName == selectedWallpaperAssetName,
                            onTap: {
                                bgmManager.playSE(.push)
                                selectedWallpaperAssetName = item.assetName
                            }
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func activePageCount(state: AppState) -> Int {
        switch selectedSection {
        case .character:
            return viewModel.pageCount(state: state)
        case .wallpaper:
            return viewModel.wallpaperPageCount(for: ownedWallpapers)
        }
    }

    private func updateActivePage(_ nextPage: Int) {
        switch selectedSection {
        case .character:
            characterCurrentPage = max(0, nextPage)
        case .wallpaper:
            wallpaperCurrentPage = max(0, nextPage)
        }
    }

    private func clampPages(state: AppState) {
        let characterMaxPage = max(0, viewModel.pageCount(state: state) - 1)
        characterCurrentPage = min(max(0, characterCurrentPage), characterMaxPage)

        let wallpaperMaxPage = max(0, viewModel.wallpaperPageCount(for: ownedWallpapers) - 1)
        wallpaperCurrentPage = min(max(0, wallpaperCurrentPage), wallpaperMaxPage)
    }

    private func handleTrainTapped(state: AppState, id: String) {
        bgmManager.playSE(.push)

        state.currentPetID = id
        selectedPetID = id
        characterCurrentPage = viewModel.pageIndex(for: id, state: state)
        save(state: state, forceWidgetReload: true)
    }

    private func handleWallpaperSetTapped() {
        guard let selectedWallpaperAssetName else { return }
        bgmManager.playSE(.push)
        currentHomeWallpaperAssetName = selectedWallpaperAssetName
        syncWallpaperSelectionAndPage()
    }

    private func syncCharacterSelectionAndPage(state: AppState) {
        let visiblePetIDs = viewModel.visiblePetIDs(state: state)

        guard !visiblePetIDs.isEmpty else {
            selectedPetID = nil
            characterCurrentPage = 0
            return
        }

        let preferredPetID: String
        if let selectedPetID, visiblePetIDs.contains(selectedPetID) {
            preferredPetID = selectedPetID
        } else if visiblePetIDs.contains(state.normalizedCurrentPetID) {
            preferredPetID = state.normalizedCurrentPetID
        } else {
            preferredPetID = visiblePetIDs[0]
        }

        selectedPetID = preferredPetID
        let pageCount = viewModel.pageCount(state: state)
        let pageIndex = viewModel.pageIndex(for: preferredPetID, state: state)
        characterCurrentPage = min(max(0, pageIndex), max(0, pageCount - 1))
    }

    private func syncWallpaperSelectionAndPage() {
        guard !ownedWallpapers.isEmpty else {
            selectedWallpaperAssetName = nil
            wallpaperCurrentPage = 0
            return
        }

        let ownedAssetNames = Set(ownedWallpapers.map(\.assetName))
        let preferredAssetName: String
        if let selectedWallpaperAssetName, ownedAssetNames.contains(selectedWallpaperAssetName) {
            preferredAssetName = selectedWallpaperAssetName
        } else if ownedAssetNames.contains(effectiveCurrentHomeWallpaperAssetName) {
            preferredAssetName = effectiveCurrentHomeWallpaperAssetName
        } else {
            preferredAssetName = ownedWallpapers[0].assetName
        }

        selectedWallpaperAssetName = preferredAssetName
        let pageCount = viewModel.wallpaperPageCount(for: ownedWallpapers)
        let pageIndex = viewModel.wallpaperPageIndex(
            for: preferredAssetName,
            in: ownedWallpapers.map(\.assetName)
        )
        wallpaperCurrentPage = min(max(0, pageIndex), max(0, pageCount - 1))
    }

    private func save(state: AppState, forceWidgetReload: Bool = false) {
        do {
            try modelContext.save()
            updateWidgetSnapshot(state: state, forceReload: forceWidgetReload)
        } catch {
            print("❌ ZukanView save error:", error)
        }
    }

    private func updateWidgetSnapshot(state: AppState, forceReload: Bool = false) {
        let widgetState = state.makeWidgetStateSnapshot()
        let changed = ZukanWidgetBridge.save(widgetState: widgetState)

        #if canImport(WidgetKit)
        if forceReload || changed {
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
}

private enum ZukanSection: String, CaseIterable, Identifiable {
    case character = "キャラクター"
    case wallpaper = "壁紙"

    var id: String { rawValue }
}

private enum ZukanWidgetBridge {
    static let appGroupID = "group.com.shota.CalPet"
    static let widgetKind = "CalPetMediumWidget"

    private static let toiletFlagKey = "toiletFlag"
    private static let bathFlagKey = "bathFlag"
    private static let currentPetIDKey = "currentPetID"
    private static let todayStepsKey = "todaySteps"
    private static let lastSignatureKey = "zukanWidgetLastSignature"

    static func save(widgetState: AppState.WidgetStateSnapshot) -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            print("❌ ZukanWidgetBridge defaults is nil. appGroupID:", appGroupID)
            return false
        }

        let normalizedPetID = widgetState.currentPetID.trimmingCharacters(in: .whitespacesAndNewlines)
        let safePetID = normalizedPetID.isEmpty ? "pet_000" : normalizedPetID
        let safeSteps = max(0, widgetState.todaySteps)

        let signature = "\(widgetState.toiletFlag)|\(widgetState.bathFlag)|\(safePetID)|\(safeSteps)"
        let previousSignature = defaults.string(forKey: lastSignatureKey)

        defaults.set(widgetState.toiletFlag, forKey: toiletFlagKey)
        defaults.set(widgetState.bathFlag, forKey: bathFlagKey)
        defaults.set(safePetID, forKey: currentPetIDKey)
        defaults.set(safeSteps, forKey: todayStepsKey)
        defaults.set(signature, forKey: lastSignatureKey)

        defaults.synchronize()

        return previousSignature != signature
    }
}

private struct ZukanSectionTabs: View {
    let selectedSection: ZukanSection
    let onSelect: (ZukanSection) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(ZukanSection.allCases) { section in
                Button {
                    onSelect(section)
                } label: {
                    Text(section.rawValue)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(selectedSection == section ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedSection == section ? Color.accentColor : Color.white.opacity(0.72))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct ZukanPageControl: View {
    let currentPage: Int
    let pageCount: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.75))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(currentPage <= 0)
            .opacity(currentPage <= 0 ? 0.35 : 1.0)

            Text("\(currentPage + 1) / \(max(1, pageCount))")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.75))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= pageCount - 1)
            .opacity(currentPage >= pageCount - 1 ? 0.35 : 1.0)
        }
    }
}

private struct ZukanCharacterCell: View {
    let petID: String
    let isCurrent: Bool
    let isSelected: Bool
    let onTap: () -> Void

    private var displayName: String {
        PetMaster.all.first(where: { $0.id == petID })?.name ?? petID
    }

    private var imageName: String {
        PetMaster.assetName(for: petID)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 58)
                    .padding(.top, 12)

                Text(displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isCurrent ? Color.blue.opacity(0.22) : Color.white.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.orange : (isCurrent ? Color.blue : Color.clear), lineWidth: isSelected ? 3 : 2)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ZukanWallpaperCell: View {
    let wallpaper: WallpaperCatalog.WallpaperItem
    let isCurrent: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(wallpaper.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 10)
                    .padding(.horizontal, 10)

                Text(wallpaper.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isCurrent ? Color.blue.opacity(0.22) : Color.white.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.orange : (isCurrent ? Color.blue : Color.clear), lineWidth: isSelected ? 3 : 2)
            )
        }
        .buttonStyle(.plain)
    }
}
