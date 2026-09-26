//
//  ZukanViewModel.swift
//  MeMo
//
//  Updated for character / wallpaper switching UI.
//

import Foundation
import Combine

struct ZukanPetRow: Identifiable {
    let id: String
    let name: String
    let isCurrentPet: Bool
}

struct ZukanPetSlot: Identifiable, Equatable {
    let id: String
    let name: String
    let imageName: String
    let isOwned: Bool
    let isCurrentPet: Bool
}

@MainActor
final class ZukanViewModel: ObservableObject {
    let characterPageSize: Int = 6
    let wallpaperPageSize: Int = 3

    /// 図鑑に表示できるキャラクターID一覧。
    /// ガチャで獲得したキャラクターも図鑑に反映されるよう、PetMaster に登録されている全キャラクターを対象にする。
    var initialPetIDs: [String] {
        PetMaster.all.map(\.id)
    }

    func makePetRows(state: AppState) -> [ZukanPetRow] {
        visiblePetIDs(state: state).map { id in
            .init(
                id: id,
                name: PetMaster.all.first(where: { $0.id == id })?.name ?? id,
                isCurrentPet: id == state.currentPetID
            )
        }
    }

    func visiblePetIDs(state: AppState) -> [String] {
        let initialSet = Set(initialPetIDs)
        var seenIDs = Set<String>()

        return state.ownedPetIDs().filter { id in
            guard initialSet.contains(id) else { return false }
            return seenIDs.insert(id).inserted
        }
    }

    func makeZukanSlots(state: AppState) -> [ZukanPetSlot] {
        let current = state.normalizedCurrentPetID

        return visiblePetIDs(state: state).map { id in
            let name = PetMaster.all.first(where: { $0.id == id })?.name ?? id
            let imageName = PetMaster.assetName(for: id)

            return ZukanPetSlot(
                id: id,
                name: name,
                imageName: imageName,
                isOwned: true,
                isCurrentPet: current == id
            )
        }
    }

    func makePagedZukanSlots(state: AppState) -> [[ZukanPetSlot]] {
        let slots = makeZukanSlots(state: state)
        return pagedItems(slots, pageSize: characterPageSize)
    }

    func pageCount(state: AppState) -> Int {
        pageCount(for: makeZukanSlots(state: state), pageSize: characterPageSize)
    }

    func wallpaperPageCount(for items: [WallpaperCatalog.WallpaperItem]) -> Int {
        pageCount(for: items, pageSize: wallpaperPageSize)
    }

    func initialPageIndex(state: AppState) -> Int {
        pageIndex(for: state.normalizedCurrentPetID, state: state)
    }

    func pageIndex(for petID: String, state: AppState) -> Int {
        pageIndex(for: petID, in: visiblePetIDs(state: state), pageSize: characterPageSize)
    }

    func wallpaperPageIndex(for assetName: String, in assetNames: [String]) -> Int {
        pageIndex(for: assetName, in: assetNames, pageSize: wallpaperPageSize)
    }

    func slotsForPage(state: AppState, page: Int) -> [ZukanPetSlot] {
        itemsForPage(makeZukanSlots(state: state), page: page, pageSize: characterPageSize)
    }

    func wallpaperItemsForPage(_ items: [WallpaperCatalog.WallpaperItem], page: Int) -> [WallpaperCatalog.WallpaperItem] {
        itemsForPage(items, page: page, pageSize: wallpaperPageSize)
    }

    private func pageCount<Item>(for items: [Item], pageSize: Int) -> Int {
        max(1, Int(ceil(Double(items.count) / Double(max(pageSize, 1)))))
    }

    private func pageIndex(for id: String, in ids: [String], pageSize: Int) -> Int {
        guard let index = ids.firstIndex(of: id) else {
            return 0
        }
        return index / max(pageSize, 1)
    }

    private func itemsForPage<Item>(_ items: [Item], page: Int, pageSize: Int) -> [Item] {
        guard !items.isEmpty else { return [] }

        let resolvedPageSize = max(pageSize, 1)
        let totalPages = pageCount(for: items, pageSize: resolvedPageSize)
        let safePage = min(max(0, page), totalPages - 1)
        let start = safePage * resolvedPageSize
        let end = min(start + resolvedPageSize, items.count)
        return Array(items[start..<end])
    }

    private func pagedItems<Item>(_ items: [Item], pageSize: Int) -> [[Item]] {
        guard !items.isEmpty else { return [[]] }

        let resolvedPageSize = max(pageSize, 1)
        return stride(from: 0, to: items.count, by: resolvedPageSize).map { start in
            let end = min(start + resolvedPageSize, items.count)
            return Array(items[start..<end])
        }
    }
}
