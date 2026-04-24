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
    let pageSize: Int = 9

    var initialPetIDs: [String] {
        PetMaster.all.map(\.id).filter { $0 != "pet_011" }
    }

    func makePetRows(state: AppState) -> [ZukanPetRow] {
        state.ownedPetIDs().map { id in
            .init(
                id: id,
                name: PetMaster.all.first(where: { $0.id == id })?.name ?? id,
                isCurrentPet: id == state.currentPetID
            )
        }
    }

    func visiblePetIDs(state: AppState) -> [String] {
        let owned = Set(state.ownedPetIDs())
        return initialPetIDs.filter { owned.contains($0) }
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
                isCurrentPet: (current == id)
            )
        }
    }

    func makePagedZukanSlots(state: AppState) -> [[ZukanPetSlot]] {
        let slots = makeZukanSlots(state: state)
        guard !slots.isEmpty else { return [[]] }

        return stride(from: 0, to: slots.count, by: pageSize).map { start in
            let end = min(start + pageSize, slots.count)
            return Array(slots[start..<end])
        }
    }

    func pageCount(state: AppState) -> Int {
        pageCount(for: makeZukanSlots(state: state))
    }

    func pageCount<Item>(for items: [Item]) -> Int {
        max(1, Int(ceil(Double(items.count) / Double(pageSize))))
    }

    func initialPageIndex(state: AppState) -> Int {
        pageIndex(for: state.normalizedCurrentPetID, state: state)
    }

    func pageIndex(for petID: String, state: AppState) -> Int {
        pageIndex(for: petID, in: visiblePetIDs(state: state))
    }

    func pageIndex(for id: String, in ids: [String]) -> Int {
        guard let index = ids.firstIndex(of: id) else {
            return 0
        }

        return index / pageSize
    }

    func slotsForPage(state: AppState, page: Int) -> [ZukanPetSlot] {
        let pagedSlots = makePagedZukanSlots(state: state)
        guard !pagedSlots.isEmpty else { return [] }

        let safePage = min(max(0, page), pagedSlots.count - 1)
        return pagedSlots[safePage]
    }

    func itemsForPage<Item>(_ items: [Item], page: Int) -> [Item] {
        guard !items.isEmpty else { return [] }

        let pageCount = pageCount(for: items)
        let safePage = min(max(0, page), pageCount - 1)

        let start = safePage * pageSize
        let end = min(start + pageSize, items.count)
        return Array(items[start..<end])
    }
}
