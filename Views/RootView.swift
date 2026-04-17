//
//  RootView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import SwiftUI
import SwiftData
import UIKit

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var appStates: [AppState]
    @StateObject private var hk = HealthKitManager()

    // 起動処理の多重実行防止は ViewModel 側で担保
    @StateObject private var viewModel = RootViewModel()

    // App 側で environmentObject 注入済み
    @EnvironmentObject private var bgmManager: BGMManager

    var body: some View {
        Group {
            switch hk.authState {
            case .unknown:
                AuthRequestView(
                    onAuthorize: { Task { await viewModel.startAuthorizationIfNeeded(hk: hk) } },
                    errorMessage: hk.errorMessage
                )

            case .denied:
                DeniedView()

            case .authorized:
                if let sharedState = viewModel.sharedState {
                    HomeView(state: sharedState, hk: hk)
                } else {
                    ProgressView()
                }
            }
        }
        .task {
            await viewModel.bootIfNeeded(
                appStates: appStates,
                modelContext: modelContext,
                hk: hk,
                bgmManager: bgmManager
            )
        }
    }
}

// MARK: - Shared views

private struct AuthRequestView: View {
    let onAuthorize: () -> Void
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Health連動が必要です")
                .font(.title2)
                .bold()

            Text("歩数を取得します。\n許可しない場合は利用できません。")
                .multilineTextAlignment(.center)

            Button("許可してはじめる") {
                onAuthorize()
            }
            .buttonStyle(.borderedProminent)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

private struct DeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            Text("Healthの許可が必要です")
                .font(.title2)
                .bold()

            Text("設定アプリで歩数のHealthアクセスを許可してください。\n許可されない場合、このアプリは利用できません。")
                .multilineTextAlignment(.center)

            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
