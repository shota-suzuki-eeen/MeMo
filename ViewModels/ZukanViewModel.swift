//
//  ZukanViewModel.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation
import Combine

struct ZukanPetRow: Identifiable {
    let id: String
    let name: String
    let isCurrentPet: Bool
}

// ✅ 図鑑グリッド表示用
struct ZukanPetSlot: Identifiable, Equatable {
    let id: String
    let name: String
    let imageName: String
    let isOwned: Bool
    let isCurrentPet: Bool
}

@MainActor
final class ZukanViewModel: ObservableObject {

    /// ✅ 1ページあたり 3 x 3 = 9マス
    let pageSize: Int = 9

    /// ✅ pet_011 は未実装のため図鑑表示から除外
    /// - 正本は AppState.initialZukanPetIDs
    var initialPetIDs: [String] {
        AppState.initialZukanPetIDs.filter { $0 != "pet_011" }
    }

    /// 既存：所持キャラ一覧（現状UIで使っているので残す）
    func makePetRows(state: AppState) -> [ZukanPetRow] {
        state.ownedPetIDs().map { id in
            .init(
                id: id,
                name: PetMaster.all.first(where: { $0.id == id })?.name ?? id,
                isCurrentPet: id == state.currentPetID
            )
        }
    }

    /// ✅ 図鑑グリッド用スロットを返す
    /// - 未獲得：CalPet_secret を表示
    /// - 獲得済み：PetMaster.assetName(for:) を表示
    func makeZukanSlots(state: AppState) -> [ZukanPetSlot] {
        let owned = Set(state.ownedPetIDs())
        let current = state.normalizedCurrentPetID

        return initialPetIDs.map { id in
            let isOwned = owned.contains(id)
            let name = isOwned
                ? (PetMaster.all.first(where: { $0.id == id })?.name ?? id)
                : "？？？"
            let imageName = isOwned ? PetMaster.assetName(for: id) : "CalPet_secret"

            return ZukanPetSlot(
                id: id,
                name: name,
                imageName: imageName,
                isOwned: isOwned,
                isCurrentPet: (current == id)
            )
        }
    }

    /// ✅ 全スロットを 9件ずつに分割して返す
    func makePagedZukanSlots(state: AppState) -> [[ZukanPetSlot]] {
        let slots = makeZukanSlots(state: state)
        guard !slots.isEmpty else { return [[]] }

        return stride(from: 0, to: slots.count, by: pageSize).map { start in
            let end = min(start + pageSize, slots.count)
            return Array(slots[start..<end])
        }
    }

    /// ✅ 総ページ数を返す
    func pageCount(state: AppState) -> Int {
        let count = makeZukanSlots(state: state).count
        return max(1, Int(ceil(Double(count) / Double(pageSize))))
    }

    /// ✅ 現在お世話中のキャラが存在するページ番号を返す
    /// - 見つからない場合は 0
    func initialPageIndex(state: AppState) -> Int {
        let currentPetID = state.normalizedCurrentPetID

        guard let currentIndex = initialPetIDs.firstIndex(of: currentPetID) else {
            return 0
        }

        return currentIndex / pageSize
    }

    /// ✅ 指定ページに表示するスロット一覧を返す
    func slotsForPage(state: AppState, page: Int) -> [ZukanPetSlot] {
        let pagedSlots = makePagedZukanSlots(state: state)
        guard !pagedSlots.isEmpty else { return [] }

        let safePage = min(max(0, page), pagedSlots.count - 1)
        return pagedSlots[safePage]
    }
}
