//
//  StepView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import SwiftUI
import SwiftData
import UIKit

struct StepView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var bgmManager: BGMManager

    let state: AppState
    @ObservedObject var hk: HealthKitManager
    let onSave: () -> Void

    @StateObject private var viewModel = StepViewModel()

    private let runningMovieAssetName = "running_movie"

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 20) {
                headerView

                Spacer(minLength: 0)

                contentView

                Spacer(minLength: 12)

                CharacterVideoPlayerView(
                    assetName: runningMovieAssetName,
                    isPlaying: viewModel.shouldPlayCharacterVideo,
                    waitingTitle: "READY",
                    runningTitle: "RUNNING"
                )
                .frame(height: 230)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
        .navigationBarHidden(true)
        .task {
            viewModel.configureIfNeeded()
            _ = hk.todaySteps
        }
        .onChange(of: scenePhase) { _, newValue in
            viewModel.handleScenePhase(newValue)
        }
    }

    private var backgroundView: some View {
        ZStack {
            Image("Step_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.20),
                    Color.black.opacity(0.36)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var headerView: some View {
        HStack {
            Button {
                bgmManager.playSE(.push)
                dismiss()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.32), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("ステップ")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.sessionState {
        case .idle, .waitingForPermission:
            idleContentView
        case .running, .paused:
            activeContentView
        case .finished:
            finishedContentView
        }
    }

    private var idleContentView: some View {
        VStack(spacing: 26) {
            VStack(spacing: 10) {
                Text("Nike Run 風のワークアウト開始画面")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))

                Text("STEP WORKOUT")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(1.4)

                Text("経過時間と距離だけを、シンプルに計測します")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.86))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            VStack(spacing: 14) {
                Button {
                    bgmManager.playSE(.push)
                    viewModel.handlePrimaryAction()
                } label: {
                    Text(viewModel.primaryActionTitle)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 96)
                        .background(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.orange.opacity(0.96),
                                            Color(red: 0.98, green: 0.42, blue: 0.16)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: .orange.opacity(0.32), radius: 22, x: 0, y: 12)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.sessionState == .waitingForPermission)

                Text(viewModel.permissionMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.horizontal, 28)

            if viewModel.shouldShowPermissionGuide {
                permissionGuideCard
                    .padding(.horizontal, 20)
            }
        }
    }

    private var permissionGuideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("位置情報の許可が必要です")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text("距離表示とルート保存のため、位置情報を利用します。設定アプリで「位置情報」を許可してください。")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                bgmManager.playSE(.push)
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            } label: {
                Text("設定を開く")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var activeContentView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("経過時間")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))

                Text(viewModel.formattedElapsedTime)
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(viewModel.formattedDistanceKilometers)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .monospacedDigit()
            }
            .padding(.top, 4)

            WorkoutRouteMapView(points: viewModel.routePoints)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal, 20)

            if let accuracyMessage = viewModel.accuracyMessage {
                Text(accuracyMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.86))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            HStack(spacing: 14) {
                Button {
                    bgmManager.playSE(.push)
                    viewModel.togglePause()
                } label: {
                    Text(viewModel.pauseButtonTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    bgmManager.playSE(.push)
                    viewModel.finishWorkout()
                } label: {
                    Text("終了")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
    }

    private var finishedContentView: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("WORKOUT SUMMARY")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .tracking(1.2)

                Text(viewModel.summaryElapsedText)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text(viewModel.summaryDistanceText)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))
                    .monospacedDigit()
            }

            WorkoutRouteMapView(points: viewModel.finishedSession?.routePoints ?? viewModel.routePoints)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal, 20)

            if let saveMessage = viewModel.saveMessage {
                Text(saveMessage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 14) {
                Button {
                    bgmManager.playSE(.push)
                    viewModel.saveFinishedWorkout(
                        modelContext: modelContext,
                        characterID: state.normalizedCurrentPetID
                    )
                    onSave()
                } label: {
                    Text(saveButtonTitle)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(saveButtonForegroundColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(saveButtonBackground)
                }
                .buttonStyle(.plain)
                .disabled(!canTapSaveButton)

                Button {
                    bgmManager.playSE(.push)
                    viewModel.handlePrimaryAction()
                } label: {
                    Text("もう一度")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
        }
    }

    private var canTapSaveButton: Bool {
        if case .saving = viewModel.saveState { return false }
        if case .saved = viewModel.saveState { return false }
        return true
    }

    private var saveButtonTitle: String {
        switch viewModel.saveState {
        case .idle, .failed:
            return "ルートを保存"
        case .saving:
            return "保存中..."
        case .saved:
            return "保存済み"
        }
    }

    private var saveButtonForegroundColor: Color {
        switch viewModel.saveState {
        case .saved:
            return .white
        default:
            return .black
        }
    }

    @ViewBuilder
    private var saveButtonBackground: some View {
        switch viewModel.saveState {
        case .saved:
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.green.opacity(0.82))
        default:
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        }
    }
}
