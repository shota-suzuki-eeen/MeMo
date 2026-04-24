//
//  WallpaperCatalog.swift
//  MeMo
//
//  Added for wallpaper selection support.
//

import Foundation

enum WallpaperCatalog {
    struct WallpaperItem: Identifiable, Hashable, Codable {
        let id: String
        let name: String
        let assetName: String
    }

    static let selectedHomeWallpaperAssetNameKey = "selectedHomeWallpaperAssetName"
    static let focusUnlockedRewardAssetNamesKey = "memo.work.focus.unlockedRewardAssetNames"

    static let all: [WallpaperItem] = [
        .init(id: "wallpaper_home", name: "ホーム", assetName: "Home_background"),
        .init(id: "wallpaper_work_reward_5h", name: "5時間報酬", assetName: "concrete_background"),
        .init(id: "wallpaper_work_reward_10h", name: "10時間報酬", assetName: "field_background"),
        .init(id: "wallpaper_work_reward_15h", name: "15時間報酬", assetName: "beach_background"),
        .init(id: "wallpaper_work_reward_20h", name: "20時間報酬", assetName: "office_background"),
        .init(id: "wallpaper_work_reward_25h", name: "25時間報酬", assetName: "bath_background"),
        .init(id: "wallpaper_work_reward_30h", name: "30時間報酬", assetName: "japanese_background")
    ]

    static let defaultWallpaper: WallpaperItem = all[0]

    static func item(for assetName: String) -> WallpaperItem? {
        all.first(where: { $0.assetName == assetName })
    }

    static func displayName(for assetName: String) -> String {
        item(for: assetName)?.name ?? assetName
    }

    static func ownedWallpapers(defaults: UserDefaults = .standard) -> [WallpaperItem] {
        let unlockedAssets = Set(defaults.stringArray(forKey: focusUnlockedRewardAssetNamesKey) ?? [])
        let ownedAssetNames = Set([defaultWallpaper.assetName]).union(unlockedAssets)
        let wallpapers = all.filter { ownedAssetNames.contains($0.assetName) }
        return wallpapers.isEmpty ? [defaultWallpaper] : wallpapers
    }
}
