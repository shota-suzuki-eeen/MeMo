//
//  DesiredFoodThoughtButton.swift
//  MeMo
//
//  Displays the current desired food on top of food_button.
//
//  2026/07/15 sync fix:
//  food_buttonと食べ物アセットを同じUIView階層へまとめ、
//  親contentViewのレイヤーだけを上下移動させる構成に変更しました。
//  ご飯フラグ成立時や食事後のアセット切り替え時にも、
//  吹き出しと食べ物が別々の位置・位相で動くことを防止します。
//
//  2026/07/15 smooth animation fix:
//  TimelineViewによる15fps再描画を撤去しました。
//  静止した2枚のアセットをCore Animationで合成レイヤーごと動かすため、
//  画面のリフレッシュレートに合わせて滑らかに表示しながら、
//  SwiftUI Viewと画像を毎フレーム再構築しない低負荷な構成です。
//

import SwiftUI
import UIKit
import QuartzCore

struct DesiredFoodThoughtButton: View {
    let desiredFood: FoodCatalog.FoodItem?
    let size: CGFloat
    let amplitude: CGFloat
    let duration: Double
    let action: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shouldAnimate: Bool {
        scenePhase == .active &&
        !reduceMotion &&
        amplitude > 0 &&
        duration > 0
    }

    var body: some View {
        Button(action: action) {
            FoodThoughtBubbleArtwork(
                desiredFoodAssetName: desiredFood?.assetName,
                amplitude: amplitude,
                duration: duration,
                isAnimating: shouldAnimate
            )
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
    }
}

private struct FoodThoughtBubbleArtwork: UIViewRepresentable {
    let desiredFoodAssetName: String?
    let amplitude: CGFloat
    let duration: Double
    let isAnimating: Bool

    func makeUIView(context: Context) -> FoodThoughtBubbleUIView {
        let view = FoodThoughtBubbleUIView()
        view.configure(
            desiredFoodAssetName: desiredFoodAssetName,
            amplitude: amplitude,
            duration: duration,
            isAnimating: isAnimating
        )
        return view
    }

    func updateUIView(_ uiView: FoodThoughtBubbleUIView, context: Context) {
        uiView.configure(
            desiredFoodAssetName: desiredFoodAssetName,
            amplitude: amplitude,
            duration: duration,
            isAnimating: isAnimating
        )
    }

    static func dismantleUIView(_ uiView: FoodThoughtBubbleUIView, coordinator: Void) {
        uiView.stopFloating(resetPosition: true)
    }
}

private final class FoodThoughtBubbleUIView: UIView {
    private enum Constants {
        static let floatingAnimationKey = "memo.foodThoughtBubble.floating"
        static let minimumDuration: Double = 0.80
        static let foodScale: CGFloat = 0.54
        static let foodVerticalOffsetRatio: CGFloat = -0.10
    }

    private let contentView = UIView()
    private let bubbleImageView = UIImageView()
    private let foodImageView = UIImageView()

    private var currentFoodAssetName: String?
    private var currentAmplitude: CGFloat = -1
    private var currentDuration: Double = -1
    private var floatingEnabled = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViewHierarchy()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpViewHierarchy()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView.frame = bounds
        bubbleImageView.frame = contentView.bounds

        let foodSide = min(contentView.bounds.width, contentView.bounds.height) * Constants.foodScale
        foodImageView.frame = CGRect(
            x: (contentView.bounds.width - foodSide) * 0.5,
            y: (contentView.bounds.height - foodSide) * 0.5
                + contentView.bounds.height * Constants.foodVerticalOffsetRatio,
            width: foodSide,
            height: foodSide
        )

        contentView.layer.rasterizationScale = window?.screen.scale ?? UIScreen.main.scale
    }

    func configure(
        desiredFoodAssetName: String?,
        amplitude: CGFloat,
        duration: Double,
        isAnimating: Bool
    ) {
        updateFoodAssetIfNeeded(desiredFoodAssetName)

        let safeAmplitude = max(0, amplitude)
        let safeDuration = max(duration, Constants.minimumDuration)
        let animationConfigurationChanged =
            abs(currentAmplitude - safeAmplitude) > 0.001 ||
            abs(currentDuration - safeDuration) > 0.001

        currentAmplitude = safeAmplitude
        currentDuration = safeDuration

        guard isAnimating, safeAmplitude > 0 else {
            floatingEnabled = false
            stopFloating(resetPosition: true)
            return
        }

        if !floatingEnabled ||
            animationConfigurationChanged ||
            contentView.layer.animation(forKey: Constants.floatingAnimationKey) == nil {
            floatingEnabled = true
            startFloating(amplitude: safeAmplitude, duration: safeDuration)
        }
    }

    func stopFloating(resetPosition: Bool) {
        contentView.layer.removeAnimation(forKey: Constants.floatingAnimationKey)

        if resetPosition {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            contentView.layer.transform = CATransform3DIdentity
            CATransaction.commit()
        }
    }

    private func setUpViewHierarchy() {
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        clipsToBounds = false

        contentView.backgroundColor = .clear
        contentView.isOpaque = false
        contentView.isUserInteractionEnabled = false
        contentView.clipsToBounds = false

        // 2枚の静止画像を一度ラスタライズし、その合成結果だけを移動します。
        // アニメーション中に画像やSwiftUI Viewを毎フレーム再描画しません。
        contentView.layer.shouldRasterize = true
        contentView.layer.rasterizationScale = UIScreen.main.scale

        bubbleImageView.image = UIImage(named: "food_button")
        bubbleImageView.contentMode = .scaleAspectFit
        bubbleImageView.backgroundColor = .clear
        bubbleImageView.isOpaque = false
        bubbleImageView.isUserInteractionEnabled = false

        foodImageView.contentMode = .scaleAspectFit
        foodImageView.backgroundColor = .clear
        foodImageView.isOpaque = false
        foodImageView.isUserInteractionEnabled = false

        addSubview(contentView)
        // 追加順により、ご飯アセットは常に吹き出しの前面へ表示されます。
        contentView.addSubview(bubbleImageView)
        contentView.addSubview(foodImageView)
    }

    private func updateFoodAssetIfNeeded(_ assetName: String?) {
        guard currentFoodAssetName != assetName else { return }
        currentFoodAssetName = assetName

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        foodImageView.image = assetName.flatMap { UIImage(named: $0) }
        foodImageView.isHidden = assetName == nil
        CATransaction.commit()

        // 食べ物だけが別タイミングで補間されないよう、変更時は即時再ラスタライズします。
        contentView.layer.setNeedsDisplay()
    }

    private func startFloating(amplitude: CGFloat, duration: Double) {
        contentView.layer.removeAnimation(forKey: Constants.floatingAnimationKey)

        let animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
        animation.values = [
            CGFloat.zero,
            -amplitude,
            CGFloat.zero,
            amplitude,
            CGFloat.zero
        ]
        animation.keyTimes = [0.0, 0.25, 0.5, 0.75, 1.0]
        animation.timingFunctions = Array(
            repeating: CAMediaTimingFunction(name: .easeInEaseOut),
            count: 4
        )
        animation.calculationMode = .cubic
        animation.duration = duration
        animation.repeatCount = .infinity
        animation.isRemovedOnCompletion = false
        animation.beginTime = contentView.layer.convertTime(CACurrentMediaTime(), from: nil)

        contentView.layer.add(animation, forKey: Constants.floatingAnimationKey)
    }
}
