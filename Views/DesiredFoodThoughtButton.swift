//
//  DesiredFoodThoughtButton.swift
//  MeMo
//
//  Displays the current desired food on top of food_button.
//
//  2026/07/14 update:
//  60fpsのTimelineViewと毎フレームのsin計算を撤去し、
//  単純なオフセットアニメーションへ変更しました。
//  バックグラウンド・Reduce Motion時は自動停止します。
//
//  2026/07/15 fix:
//  food_buttonと食べ物アセットを先に1つの描画グループへまとめ、
//  その外側だけに浮遊アニメーションを適用します。
//  食べ物切り替え時のtransitionが浮遊アニメーションへ巻き込まれ、
//  2つのアセットが別々に移動して見える現象を防止します。
//

import SwiftUI

struct DesiredFoodThoughtButton: View {
    let desiredFood: FoodCatalog.FoodItem?
    let size: CGFloat
    let amplitude: CGFloat
    let duration: Double
    let action: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isFloating = false

    private var shouldAnimate: Bool {
        scenePhase == .active &&
        !reduceMotion &&
        amplitude > 0 &&
        duration > 0
    }

    private var yOffset: CGFloat {
        guard shouldAnimate else { return 0 }
        return isFloating ? amplitude : -amplitude
    }

    private var floatingAnimation: Animation {
        .easeInOut(duration: max(duration * 0.5, 0.20))
        .repeatForever(autoreverses: true)
    }

    var body: some View {
        Button(action: action) {
            thoughtBubbleContent
                // 吹き出しと食べ物を先に一体化してから、外側を移動させます。
                // これにより両アセットの浮遊位相と位置が常に完全一致します。
                .compositingGroup()
        }
        .buttonStyle(.plain)
        .offset(y: yOffset)
        .animation(
            shouldAnimate ? floatingAnimation : nil,
            value: isFloating
        )
        .onAppear {
            restartFloatingAnimation()
        }
        .onDisappear {
            stopFloatingAnimation()
        }
        .onChange(of: scenePhase) { _, _ in
            restartFloatingAnimation()
        }
        .onChange(of: reduceMotion) { _, _ in
            restartFloatingAnimation()
        }
        .onChange(of: amplitude) { _, _ in
            restartFloatingAnimation()
        }
        .onChange(of: duration) { _, _ in
            restartFloatingAnimation()
        }
    }

    private var thoughtBubbleContent: some View {
        ZStack {
            Image("food_button")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)

            if let desiredFood {
                Image(desiredFood.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: size * 0.54,
                        height: size * 0.54
                    )
                    .offset(y: -size * 0.10)
                    // 食べ物画像単体には浮遊・位置アニメーションを付けません。
                    // アセット変更時も親グループの現在位置に即座に追従します。
                    .id(desiredFood.id)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
    }

    private func restartFloatingAnimation() {
        stopFloatingAnimation()
        guard shouldAnimate else { return }

        DispatchQueue.main.async {
            guard shouldAnimate else { return }
            isFloating = true
        }
    }

    private func stopFloatingAnimation() {
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            isFloating = false
        }
    }
}
