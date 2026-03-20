//
//  ZukanView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
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

    private var state: AppState? { appStates.first }

    // ✅ pet_011 は未実装のため図鑑表示から除外
    private var initialPetIDs: [String] {
        AppState.initialZukanPetIDs.filter { $0 != "pet_011" }
    }
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    @State private var selectedPetID: String? = nil

    // ✅ 追加：インタースティシャル（キャラ切替用）
    // 一旦 AdMob 周りを止めるためコメントアウト
    // @ObservedObject private var interstitial = AdMobManager.shared.interstitialCharacterSet

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()

            VStack(spacing: 14) {
                if let state {
                    ZukanGrid(
                        petIDs: initialPetIDs,
                        ownedIDs: Set(state.ownedPetIDs()),
                        currentPetID: state.normalizedCurrentPetID,
                        columns: columns,
                        selectedPetID: selectedPetID,
                        onSelect: { id in
                            selectedPetID = id
                        }
                    )
                    .padding(.top, 6)

                    ZukanDetailPanel(
                        state: state,
                        selectedPetID: selectedPetID ?? state.normalizedCurrentPetID,
                        onTrain: { id in
                            handleTrainTapped(state: state, id: id)
                        },
                        isDeveloperMode: isDeveloperMode
                    )
                    .padding(.top, 6)

                } else {
                    Text("（準備中）")
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
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
        .navigationTitle("図鑑")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let state else { return }
            state.ensureInitialPetsIfNeeded()

            if selectedPetID == nil || selectedPetID == "pet_011" {
                selectedPetID = initialPetIDs.contains(state.normalizedCurrentPetID)
                    ? state.normalizedCurrentPetID
                    : initialPetIDs.first
            }

            updateWidgetSnapshot(state: state, forceReload: true)

            // ✅ AdMob のロードは一旦停止
            // interstitial.load()
        }
    }

    // MARK: - Train Action

    private func handleTrainTapped(state: AppState, id: String) {
        bgmManager.playSE(.push)

        let switchPet: () -> Void = {
            print("----- switchPet start -----")
            print("✅ tapped id:", id)
            print("✅ before state.currentPetID:", state.currentPetID)
            print("✅ before state.normalizedCurrentPetID:", state.normalizedCurrentPetID)

            state.currentPetID = id
            selectedPetID = id

            print("✅ after state.currentPetID:", state.currentPetID)
            print("✅ after state.normalizedCurrentPetID:", state.normalizedCurrentPetID)

            save(state: state, forceWidgetReload: true)

            print("----- switchPet end -----")
        }

        // ✅ AdMob を一旦停止中のため、そのまま切替
        switchPet()
    }

    // MARK: - Persistence

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

// MARK: - Widget Bridge

private enum ZukanWidgetBridge {
    // ⚠️ HomeView / Widget 側と同じ App Group ID を設定してください
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

// MARK: - Grid

private struct ZukanGrid: View {
    @EnvironmentObject private var bgmManager: BGMManager

    let petIDs: [String]
    let ownedIDs: Set<String>
    let currentPetID: String
    let columns: [GridItem]
    let selectedPetID: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(petIDs, id: \.self) { id in
                    let isOwned = ownedIDs.contains(id)
                    let isCurrent = (currentPetID == id)

                    ZukanCell(
                        petID: id,
                        isOwned: isOwned,
                        isCurrent: isCurrent,
                        isSelected: (selectedPetID == id),
                        onTap: {
                            guard isOwned else { return }
                            bgmManager.playSE(.push)
                            onSelect(id)
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

// MARK: - Detail (Lower half)

private struct ZukanDetailPanel: View {
    let state: AppState
    let selectedPetID: String
    let onTrain: (String) -> Void
    let isDeveloperMode: Bool

    private var selectedName: String {
        PetMaster.all.first(where: { $0.id == selectedPetID })?.name ?? selectedPetID
    }

    private var selectedImageName: String {
        PetMaster.assetName(for: selectedPetID)
    }

    private var isCurrent: Bool {
        state.normalizedCurrentPetID == selectedPetID
    }

    private var superFavoriteDisplayText: String {
        state.isSuperFavoriteRevealed(petID: selectedPetID)
        ? PetMaster.superFavoriteFoodName(for: selectedPetID)
        : "？？？"
    }

    private var descriptionBodyText: String {
        let full = PetMaster.description(for: selectedPetID, state: state)
        let parts = full.components(separatedBy: "\n\n【大好物】")
        return parts.first ?? full
    }

    var body: some View {
        VStack(spacing: 12) {
            Button {
                onTrain(selectedPetID)
            } label: {
                Text(
                    isCurrent
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
            .disabled(isCurrent)
            .opacity(isCurrent ? 0.6 : 1.0)

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

                    Text(descriptionBodyText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("【大好物】\(superFavoriteDisplayText)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
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
