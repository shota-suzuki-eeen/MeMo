//
//  MeMoApp.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import SwiftUI
import SwiftData

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct MeMoApp: App {

    // ✅ アプリ全体でBGMを1つだけ管理
    @StateObject private var bgmManager = BGMManager()

    init() {
        // ✅ AdMob 初期化（アプリ起動時に1回だけ）
        #if canImport(GoogleMobileAds)
//        AdMobManager.shared.start()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(bgmManager)
                .onAppear {
                    bgmManager.startIfNeeded()
                }
        }
        .modelContainer(for: [
            AppState.self,
            TodayPhotoEntry.self,
            WorkoutSessionRecord.self
        ])
    }
}
