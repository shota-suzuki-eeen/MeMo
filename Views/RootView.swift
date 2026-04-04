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

    // ✅ 起動時処理が多重実行されないようにする（VM側でガード）
    @StateObject private var viewModel = RootViewModel()

    // ✅ BGM（App側でenvironmentObject注入している前提）
    @EnvironmentObject private var bgmManager: BGMManager

    // ✅ フォア/バックの監視
    @Environment(\.scenePhase) private var scenePhase

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
                    // ✅ 重要：引数順は state → hk
                    HomeView(state: sharedState, hk: hk)
                } else {
                    ProgressView()
                }
            }
        }
        // ✅ boot処理（VM側で「多重実行しない」ガードを持つ想定）
        .task {
            await viewModel.bootIfNeeded(
                appStates: appStates,
                modelContext: modelContext,
                hk: hk,
                bgmManager: bgmManager
            )

            if hk.authState == .authorized {
                await hk.startStepUpdatesIfNeeded()
                await hk.refreshTodayStepsForWidget()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // ✅ 復帰時に再生が止まっていたら再開
                bgmManager.startIfNeeded()

                // ✅ 復帰時に歩数監視を再確認し、Widget 用の歩数も更新
                Task {
                    await hk.startStepUpdatesIfNeeded()
                    await hk.refreshTodayStepsForWidget()
                }

            case .background:
                // ✅ 常時再生したい場合でも、ここで止めない（仕様：無限ループ再生）
                break

            case .inactive:
                break

            @unknown default:
                break
            }
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
