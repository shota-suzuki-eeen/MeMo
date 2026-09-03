//
//  HalloweenRunGameView.swift
//  MeMo
//
//  SpriteKitランゲームをSwiftUIから表示し、結果画面・再挑戦だけを管理する。
//  2026/09 performance v5:
//  SwiftUI.SpriteViewを使わずUIViewRepresentable経由でSKViewを直接ホスト。
//  プレイ中のSwiftUI State更新は行わず、GAME OVER時のみ結果を受け取る。
//

import SwiftUI
import SpriteKit
import UIKit

struct HalloweenRunGameView: View {
    @EnvironmentObject private var bgmManager: BGMManager

    @ObservedObject var store: Halloween2026EventStore
    let onClose: () -> Void

    @State private var scene: HalloweenRunGameScene
    @State private var sceneIdentity = UUID()

    // ゲーム中は変化しない。GAME OVER時だけ更新。
    @State private var result: HalloweenRunResult?
    @State private var wasNewHighScore = false

    init(
        store: Halloween2026EventStore,
        onClose: @escaping () -> Void
    ) {
        self.store = store
        self.onClose = onClose

        _scene = State(
            initialValue: HalloweenRunGameScene(size: UIScreen.main.bounds.size)
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            HalloweenRunSKView(scene: scene)
                .id(sceneIdentity)
                .ignoresSafeArea()

            closeButton
                .padding(.leading, 16)
                .padding(.top, 52)
                .zIndex(10_000)

            if let result {
                resultOverlay(result)
                    .zIndex(20_000)
                    .transition(
                        .opacity.combined(
                            with: .scale(scale: 0.94)
                        )
                    )
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .onAppear {
            configureScene(scene)
            bgmManager.switchBackground(to: .fishing)
        }
        .onDisappear {
            disconnectScene(scene)
        }
    }

    private var closeButton: some View {
        Button {
            bgmManager.playSE(.push)
            onClose()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.black.opacity(0.48), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("イベント画面へ戻る")
    }

    // MARK: - Result

    private func resultOverlay(_ result: HalloweenRunResult) -> some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(wasNewHighScore ? "NEW RECORD!" : "GAME OVER")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(
                        wasNewHighScore
                            ? Color.orange
                            : Color.primary
                    )

                VStack(spacing: 8) {
                    Text("今回の記録")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text("\(result.distance.formatted())m")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .monospacedDigit()

                    HStack(spacing: 6) {
                        HalloweenCandyIcon(size: 24)

                        Text("+\(result.candyCount)")
                            .font(.system(size: 21, weight: .black, design: .rounded))
                            .monospacedDigit()
                    }
                }

                Divider()

                HStack {
                    resultStat(
                        title: "BEST",
                        value: "\(store.bestDistance.formatted())m"
                    )

                    resultStat(
                        title: "TOTAL",
                        value: "\(store.totalDistance.formatted())m"
                    )
                }

                Button {
                    bgmManager.playSE(.push)
                    startNewRun()
                } label: {
                    Text("もう一度")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.orange, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!EventManager.isActive(.halloween2026))

                Button {
                    bgmManager.playSE(.push)
                    onClose()
                } label: {
                    Text("イベント画面へ")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: 340)
            .background(
                .regularMaterial,
                in: RoundedRectangle(
                    cornerRadius: 30,
                    style: .continuous
                )
            )
            .shadow(
                color: .black.opacity(0.36),
                radius: 28,
                x: 0,
                y: 16
            )
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func resultStat(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scene

    private func configureScene(_ scene: HalloweenRunGameScene) {
        scene.onGameOver = { runResult in
            guard result == nil else { return }

            let newRecord = runResult.distance > store.bestDistance

            // EventStoreへの保存はGAME OVER時の1回だけ。
            store.recordRun(
                distance: runResult.distance,
                candy: runResult.candyCount
            )

            wasNewHighScore = newRecord

            withAnimation(
                .spring(response: 0.34, dampingFraction: 0.82)
            ) {
                result = runResult
            }
        }
    }

    private func startNewRun() {
        guard EventManager.isActive(.halloween2026) else { return }

        disconnectScene(scene)

        result = nil
        wasNewHighScore = false

        let newScene = HalloweenRunGameScene(
            size: UIScreen.main.bounds.size
        )
        configureScene(newScene)

        scene = newScene

        // SKViewごと新規生成し、旧GAME OVER Sceneを一切再利用しない。
        sceneIdentity = UUID()
    }

    private func disconnectScene(_ scene: HalloweenRunGameScene) {
        scene.shutdown()
    }
}

// MARK: - Direct SKView host

private struct HalloweenRunSKView: UIViewRepresentable {
    let scene: HalloweenRunGameScene

    final class Coordinator {
        weak var presentedScene: HalloweenRunGameScene?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SKView {
        let skView = SKView(frame: .zero)

        skView.backgroundColor = scene.backgroundColor
        skView.preferredFramesPerSecond = 60
        skView.ignoresSiblingOrder = true
        skView.shouldCullNonVisibleNodes = true
        skView.isMultipleTouchEnabled = false

        skView.presentScene(scene)
        context.coordinator.presentedScene = scene

        return skView
    }

    func updateUIView(_ skView: SKView, context: Context) {
        guard context.coordinator.presentedScene !== scene else { return }

        context.coordinator.presentedScene?.shutdown()

        skView.presentScene(scene)
        skView.isPaused = false
        context.coordinator.presentedScene = scene
    }

    static func dismantleUIView(
        _ skView: SKView,
        coordinator: Coordinator
    ) {
        coordinator.presentedScene?.shutdown()
        coordinator.presentedScene = nil

        skView.presentScene(nil)
        skView.isPaused = true
    }
}
