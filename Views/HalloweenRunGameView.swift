//
//  HalloweenRunGameView.swift
//  MeMo
//
//  SpriteKitランゲームをSwiftUIから表示し、HUD・結果画面・再挑戦を管理する。
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
    @State private var distance: Int = 0
    @State private var sessionCandy: Int = 0
    @State private var countdown: Int? = 3
    @State private var result: HalloweenRunResult?
    @State private var wasNewHighScore = false

    init(
        store: Halloween2026EventStore,
        onClose: @escaping () -> Void
    ) {
        self.store = store
        self.onClose = onClose

        let initialSize = UIScreen.main.bounds.size
        _scene = State(initialValue: HalloweenRunGameScene(size: initialSize))
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene, options: [.allowsTransparency])
                // 「もう一度」で新しいSKSceneへ切り替える際、SpriteView自体も再生成する。
                // Sceneだけを差し替えると、環境によっては旧GAME OVER Sceneを保持することがある。
                .id(sceneIdentity)
                .ignoresSafeArea()

            hud

            if let countdown {
                countdownOverlay(countdown)
            }

            if let result {
                resultOverlay(result)
                    .zIndex(20_000)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
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

    private var hud: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
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

                Spacer()

                VStack(spacing: 2) {
                    Text("DISTANCE")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                    Text("\(distance.formatted())m")
                        .font(.system(size: 25, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.44), in: Capsule())

                Spacer()

                HStack(spacing: 4) {
                    HalloweenCandyIcon(size: 21)
                    Text("\(sessionCandy)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(.white)
                .frame(minWidth: 70, minHeight: 42)
                .background(Color.black.opacity(0.48), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 52)

            Spacer()

            if result == nil {
                HStack {
                    Label("左タップ", systemImage: "arrow.left")
                    Spacer()
                    Label("右タップ", systemImage: "arrow.right")
                }
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.66))
                .padding(.horizontal, 26)
                .padding(.bottom, 32)
                .allowsHitTesting(false)
            }
        }
        .allowsHitTesting(true)
    }

    private func countdownOverlay(_ value: Int) -> some View {
        VStack(spacing: 10) {
            Text("\(value)")
                .font(.system(size: 88, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .shadow(color: .black.opacity(0.50), radius: 12, x: 0, y: 5)

            Text("READY")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundStyle(Color.orange)
        }
        .allowsHitTesting(false)
    }

    private func resultOverlay(_ result: HalloweenRunResult) -> some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(wasNewHighScore ? "NEW RECORD!" : "GAME OVER")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(wasNewHighScore ? Color.orange : Color.primary)

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
                    resultStat(title: "BEST", value: "\(store.bestDistance.formatted())m")
                    resultStat(title: "TOTAL", value: "\(store.totalDistance.formatted())m")
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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: .black.opacity(0.36), radius: 28, x: 0, y: 16)
            .padding(.horizontal, 24)
        }
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

    private func configureScene(_ scene: HalloweenRunGameScene) {
        scene.onDistanceChanged = { newDistance in
            distance = newDistance
        }

        scene.onCandyChanged = { newCandy in
            sessionCandy = newCandy
        }

        scene.onCountdownChanged = { newCountdown in
            withAnimation(.easeInOut(duration: 0.12)) {
                countdown = newCountdown
            }
        }

        scene.onGameOver = { runResult in
            guard result == nil else { return }

            let newRecord = runResult.distance > store.bestDistance
            store.recordRun(distance: runResult.distance, candy: runResult.candyCount)

            wasNewHighScore = newRecord
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                result = runResult
            }
        }
    }

    private func startNewRun() {
        guard EventManager.isActive(.halloween2026) else { return }

        // 旧SceneはGAME OVER状態のままSpriteViewに保持される場合があるため、
        // コールバックを切って完全に停止してから新しいSceneへ切り替える。
        disconnectScene(scene)

        distance = 0
        sessionCandy = 0
        countdown = 3
        result = nil
        wasNewHighScore = false

        let newScene = HalloweenRunGameScene(size: UIScreen.main.bounds.size)
        configureScene(newScene)

        scene = newScene

        // SpriteViewのidentityも更新し、内部SKViewが旧Sceneを再利用しないようにする。
        sceneIdentity = UUID()
    }

    private func disconnectScene(_ scene: HalloweenRunGameScene) {
        scene.isPaused = true
        scene.removeAllActions()
        scene.onDistanceChanged = nil
        scene.onCandyChanged = nil
        scene.onCountdownChanged = nil
        scene.onGameOver = nil
    }
}
