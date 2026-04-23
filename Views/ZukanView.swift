//
//  ZukanView.swift
//  MeMo
//
//  Updated for screen BGM switching.
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

    @StateObject private var viewModel = ZukanViewModel()
    @State private var selectedPetID: String? = nil
    @State private var currentPage: Int = 0

    private var state: AppState? { appStates.first }

    private let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 3
    )

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()

            VStack(spacing: 14) {
                if let state {
                    let slots = viewModel.slotsForPage(state: state, page: currentPage)
                    let pageCount = viewModel.pageCount(state: state)

                    ZukanGrid(
                        slots: slots,
                        columns: columns,
                        currentPage: currentPage,
                        pageCount: pageCount,
                        selectedPetID: selectedPetID,
                        onPreviousPage: {
                            guard currentPage > 0 else { return }
                            bgmManager.playSE(.push)
                            currentPage -= 1
                        },
                        onNextPage: {
                            guard currentPage < pageCount - 1 else { return }
                            bgmManager.playSE(.push)
                            currentPage += 1
                        },
                        onSelect: { id in
                            selectedPetID = id
                        }
                    )
                    .padding(.top, 6)

                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)

                    Text("（準備中）")
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 16)
        }
        .background(
            ZStack {
                Image("Zukan_background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                Color.black.opacity(0.25)
                    .ignoresSafeArea()
            }
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let state {
                ZukanDetailPanel(
                    selectedPetID: selectedPetID ?? state.normalizedCurrentPetID,
                    onTrain: { id in
                        handleTrainTapped(state: state, id: id)
                    },
                    isDeveloperMode: isDeveloperMode,
                    isCurrentPet: state.normalizedCurrentPetID == (selectedPetID ?? state.normalizedCurrentPetID)
                )
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 16)
                .background(Color.clear)
            }
        }
        .navigationTitle("図鑑")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            bgmManager.switchBackground(to: .zukan)
            guard let state else { return }

            state.ensureInitialPetsIfNeeded()
            syncSelectionAndPage(state: state)
            updateWidgetSnapshot(state: state, forceReload: true)
        }
        .onDisappear {
            bgmManager.restoreDefaultBackground()
        }
        .onChange(of: state?.normalizedCurrentPetID) { _, _ in
            guard let state else { return }
            syncSelectionAndPage(state: state)
        }
        .onChange(of: state?.ownedPetIDsData) { _, _ in
            guard let state else { return }
            syncSelectionAndPage(state: state)
        }
    }

    private func handleTrainTapped(state: AppState, id: String) {
        bgmManager.playSE(.push)

        let switchPet: () -> Void = {
            print("----- switchPet start -----")
            print("✅ tapped id:", id)
            print("✅ before state.currentPetID:", state.currentPetID)
            print("✅ before state.normalizedCurrentPetID:", state.normalizedCurrentPetID)

            state.currentPetID = id
            selectedPetID = id
            currentPage = viewModel.pageIndex(for: id, state: state)

            print("✅ after state.currentPetID:", state.currentPetID)
            print("✅ after state.normalizedCurrentPetID:", state.normalizedCurrentPetID)

            save(state: state, forceWidgetReload: true)

            print("----- switchPet end -----")
        }

        switchPet()
    }

    private func syncSelectionAndPage(state: AppState) {
        let visiblePetIDs = viewModel.visiblePetIDs(state: state)

        guard !visiblePetIDs.isEmpty else {
            selectedPetID = nil
            currentPage = 0
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

        self.selectedPetID = preferredPetID

        let pageCount = viewModel.pageCount(state: state)
        let pageIndex = viewModel.pageIndex(for: preferredPetID, state: state)
        currentPage = min(max(0, pageIndex), max(0, pageCount - 1))
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
        print("✅ updateWidgetSnapshot currentPetID:", widgetState.currentPetID)
        print("✅ updateWidgetSnapshot todaySteps:", widgetState.todaySteps)

        let changed = ZukanWidgetBridge.save(widgetState: widgetState)

        #if canImport(WidgetKit)
        if forceReload || changed {
            WidgetCenter.shared.reloadAllTimelines()
            print("✅ WidgetCenter.reloadAllTimelines called")
        } else {
            print("ℹ️ Widget snapshot unchanged, reload skipped")
        }
        #endif
    }
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

        print("----- ZukanWidgetBridge.save start -----")
        print("✅ widgetState.currentPetID:", widgetState.currentPetID)
        print("✅ safePetID:", safePetID)
        print("✅ widgetState.todaySteps:", widgetState.todaySteps)

        let signature = "\(widgetState.toiletFlag)|\(widgetState.bathFlag)|\(safePetID)|\(safeSteps)"
        let previousSignature = defaults.string(forKey: lastSignatureKey)

        defaults.set(widgetState.toiletFlag, forKey: toiletFlagKey)
        defaults.set(widgetState.bathFlag, forKey: bathFlagKey)
        defaults.set(safePetID, forKey: currentPetIDKey)
        defaults.set(safeSteps, forKey: todayStepsKey)
        defaults.set(signature, forKey: lastSignatureKey)

        defaults.synchronize()

        print("✅ saved currentPetID:", defaults.string(forKey: currentPetIDKey) ?? "nil")
        print("✅ saved todaySteps:", defaults.object(forKey: todayStepsKey) ?? "nil")
        print("✅ previousSignature:", previousSignature ?? "nil")
        print("✅ newSignature:", signature)
        print("----- ZukanWidgetBridge.save end -----")

        return previousSignature != signature
    }
}

private struct ZukanGrid: View {
    @EnvironmentObject private var bgmManager: BGMManager

    let slots: [ZukanPetSlot]
    let columns: [GridItem]
    let currentPage: Int
    let pageCount: Int
    let selectedPetID: String?
    let onPreviousPage: () -> Void
    let onNextPage: () -> Void
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: onPreviousPage) {
                    Text("<")
                        .font(.headline.weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(.thinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(currentPage <= 0)
                .opacity(currentPage <= 0 ? 0.35 : 1.0)

                Spacer()

                Text("\(currentPage + 1) / \(pageCount)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: onNextPage) {
                    Text(">")
                        .font(.headline.weight(.bold))
                        .frame(width: 36, height: 36)
                        .background(.thinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(currentPage >= pageCount - 1)
                .opacity(currentPage >= pageCount - 1 ? 0.35 : 1.0)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(slots) { slot in
                    ZukanCell(
                        petID: slot.id,
                        isOwned: slot.isOwned,
                        isCurrent: slot.isCurrentPet,
                        isSelected: (selectedPetID == slot.id),
                        onTap: {
                            guard slot.isOwned else { return }
                            bgmManager.playSE(.push)
                            onSelect(slot.id)
                        }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ZukanCell: View {
    let petID: String
    let isOwned: Bool
    let isCurrent: Bool
    let isSelected: Bool
    let onTap: () -> Void

    private var displayName: String {
        guard isOwned else { return "？？？" }
        return PetMaster.all.first(where: { $0.id == petID })?.name ?? petID
    }

    private var imageName: String {
        isOwned ? PetMaster.assetName(for: petID) : "CalPet_secret"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 52)
                    .padding(.top, 10)

                Text(displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(isOwned ? .primary : .secondary)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                if isCurrent {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.black, lineWidth: 3)
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.black.opacity(0.18), lineWidth: 1)
                }
            }
            .opacity(isOwned ? 1.0 : 0.7)
        }
        .buttonStyle(.plain)
        .disabled(!isOwned)
    }
}

private struct ZukanDetailPanel: View {
    let selectedPetID: String
    let onTrain: (String) -> Void
    let isDeveloperMode: Bool
    let isCurrentPet: Bool

    private var selectedName: String {
        PetMaster.all.first(where: { $0.id == selectedPetID })?.name ?? selectedPetID
    }

    private var selectedImageName: String {
        PetMaster.assetName(for: selectedPetID)
    }

    private var descriptionText: String {
        PetMaster.description(for: selectedPetID)
    }

    var body: some View {
        VStack(spacing: 12) {
            Button {
                onTrain(selectedPetID)
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
            .opacity(isCurrentPet ? 0.6 : 1.0)

            HStack(spacing: 12) {
                VStack {
                    Image(selectedImageName)
                        .resizable()
                        .scaledToFit()
                        .padding(18)
                }
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 260)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedName)
                        .font(.headline)

                    Text(descriptionText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 260, alignment: .topLeading)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
