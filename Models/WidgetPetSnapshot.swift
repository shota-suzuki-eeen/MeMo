//
//  WidgetPetSnapshot.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation

struct WidgetPetSnapshot: Equatable {
    let toiletFlag: Bool
    let bathFlag: Bool
    let currentPetID: String
    let todaySteps: Int

    static let `default` = WidgetPetSnapshot(
        toiletFlag: false,
        bathFlag: false,
        currentPetID: "pet_000",
        todaySteps: 0
    )

    var isToiletFlagged: Bool { toiletFlag }
    var isBathFlagged: Bool { bathFlag }

    var displayAssetName: String {
        let base = WidgetPetAssetMap.assetName(for: currentPetID)
        if toiletFlag, WidgetPetAssetMap.hasToiletVariant(baseAssetName: base) {
            return "\(base)_wc"
        }
        return base
    }
}

enum WidgetPetAssetMap {
    static func assetName(for petIDOrAssetName: String) -> String {
        switch petIDOrAssetName.trimmingCharacters(in: .whitespacesAndNewlines) {
        // petID形式
        case "pet_000": return "purpor"
        case "pet_001": return "beat"
        case "pet_002": return "biniki"
        case "pet_003": return "himei"
        case "pet_004": return "kakke"
        case "pet_005": return "kepyon"
        case "pet_006": return "ninjin"
        case "pet_007": return "obaoru"
        case "pet_008": return "sun"
        case "pet_009": return "wanigeeta"
        case "pet_010": return "wareware"
        case "pet_011": return "purpor"

        // asset名形式も許容
        case "purpor": return "purpor"
        case "beat": return "beat"
        case "biniki": return "biniki"
        case "himei": return "himei"
        case "kakke": return "kakke"
        case "kepyon": return "kepyon"
        case "ninjin": return "ninjin"
        case "obaoru": return "obaoru"
        case "sun": return "sun"
        case "wanigeeta": return "wanigeeta"
        case "wareware": return "wareware"

        default:
            return "purpor"
        }
    }

    static func hasToiletVariant(baseAssetName: String) -> Bool {
        [
            "beat",
            "biniki",
            "himei",
            "kakke",
            "kepyon",
            "ninjin",
            "obaoru",
            "purpor",
            "sun",
            "wanigeeta",
            "wareware"
        ].contains(baseAssetName)
    }
}
