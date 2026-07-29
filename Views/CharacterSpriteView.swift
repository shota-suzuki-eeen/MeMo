//
//  CharacterSpriteView.swift
//  MeMo
//
//  SpriteKit-based character presentation for the Home screen.
//  Phase 1: breathing, random blinking, double blinking and smooth idle recovery.
//

import SwiftUI
import SpriteKit
import UIKit

@MainActor
struct CharacterSpriteView: View {
    let assetName: String
    let baseAssetName: String
    let isIdleEnabled: Bool
    let displayHeight: CGFloat

    @State private var scene = CharacterSpriteScene(size: CGSize(width: 512, height: 512))

    private let canvasScale: CGFloat = 1.12

    private var configuration: CharacterSpriteScene.Configuration {
        CharacterSpriteScene.Configuration(
            assetName: assetName,
            baseAssetName: baseAssetName,
            isIdleEnabled: isIdleEnabled,
            visualHeight: max(1, displayHeight)
        )
    }

    private var baseAspectRatio: CGFloat {
        let image = UIImage(named: baseAssetName) ?? UIImage(named: assetName)
        guard let image, image.size.height > 0 else { return 1 }
        return image.size.width / image.size.height
    }

    var body: some View {
        SpriteView(
            scene: scene,
            preferredFramesPerSecond: 30,
            options: [.allowsTransparency]
        )
        .frame(
            width: max(1, displayHeight * baseAspectRatio * canvasScale),
            height: max(1, displayHeight * canvasScale)
        )
        .onAppear {
            scene.apply(configuration)
        }
        .onChange(of: configuration) { _, newConfiguration in
            scene.apply(newConfiguration)
        }
        .onDisappear {
            scene.stopAllAnimation()
        }
        .accessibilityHidden(true)
    }
}

@MainActor
final class CharacterSpriteScene: SKScene {
    struct Configuration: Equatable {
        let assetName: String
        let baseAssetName: String
        let isIdleEnabled: Bool
        let visualHeight: CGFloat
    }

    private enum ActionKey {
        static let breathe = "character.idle.breathe"
        static let settle = "character.idle.settle"
    }

    // The character remains positionally fixed.
    // Only subtle non-uniform scaling is used for breathing.
    private let breathNode = SKNode()
    private let spriteNode = SKSpriteNode()

    private var configuration: Configuration?
    private var currentTextureAssetName: String?
    private var blinkTask: Task<Void, Never>?

    override init(size: CGSize) {
        super.init(size: size)
        configureScene()
    }


    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureScene()
    }

    func apply(_ newConfiguration: Configuration) {
        guard configuration != newConfiguration else { return }

        let previousConfiguration = configuration
        let baseAssetChanged = previousConfiguration?.baseAssetName != newConfiguration.baseAssetName
        let visualHeightChanged = previousConfiguration?.visualHeight != newConfiguration.visualHeight
        configuration = newConfiguration

        if baseAssetChanged {
            cancelIdleTasks()
            removeIdleActions()
            resetMotionImmediately()
        }

        let shouldIdle = shouldRunIdle(for: newConfiguration)
        if !shouldIdle {
            // Cancel first so an in-flight blink can never restore the base texture
            // after an external state (WC, action, etc.) has supplied another asset.
            cancelIdleTasks()
        }

        setTexture(named: newConfiguration.assetName)

        if shouldIdle {
            if baseAssetChanged || visualHeightChanged {
                restartContinuousIdleMotion()
            } else {
                startContinuousIdleMotionIfNeeded()
            }
            startBlinkLoopIfNeeded()
        } else {
            removeIdleActions()
            settleToNeutralPose(animated: true)
        }
    }

    func stopAllAnimation() {
        cancelIdleTasks()
        removeIdleActions()
        resetMotionImmediately()
    }

    private func configureScene() {
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        removeAllChildren()

        addChild(breathNode)
        breathNode.addChild(spriteNode)

        // Breathing must not move the character's feet.
        // Use the bottom-center of the sprite as the transform pivot.
        spriteNode.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        spriteNode.position = .zero
        resetMotionImmediately()
    }

    private func shouldRunIdle(for configuration: Configuration) -> Bool {
        configuration.isIdleEnabled
            && configuration.assetName == configuration.baseAssetName
    }

    private var canRunCurrentIdle: Bool {
        guard let configuration else { return false }
        return shouldRunIdle(for: configuration)
    }

    private func setTexture(named assetName: String) {
        guard currentTextureAssetName != assetName else {
            layoutSpriteForCurrentConfiguration()
            return
        }

        guard let image = UIImage(named: assetName) else {
            currentTextureAssetName = nil
            spriteNode.texture = nil
            spriteNode.size = .zero
            return
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .linear

        currentTextureAssetName = assetName
        spriteNode.texture = texture
        layoutSprite(imageSize: image.size)
    }

    private func layoutSpriteForCurrentConfiguration() {
        guard
            let currentTextureAssetName,
            let image = UIImage(named: currentTextureAssetName)
        else { return }

        layoutSprite(imageSize: image.size)
    }

    private func layoutSprite(imageSize: CGSize) {
        guard let configuration else { return }

        let height = max(1, configuration.visualHeight)
        let aspectRatio = imageSize.height > 0 ? imageSize.width / imageSize.height : 1
        spriteNode.size = CGSize(
            width: max(1, height * aspectRatio),
            height: height
        )

        updateBreathingPivotPosition()
    }

    /// Keeps the sprite's bottom edge fixed while breathing.
    /// The previous center-anchored layout occupied -height/2 ... +height/2,
    /// so placing the bottom pivot at -height/2 preserves the same resting position.
    private func updateBreathingPivotPosition() {
        guard let configuration else {
            breathNode.position = .zero
            return
        }

        let height = max(1, configuration.visualHeight)
        breathNode.position = CGPoint(x: 0, y: -(height * 0.5))
    }

    private func startContinuousIdleMotionIfNeeded() {
        breathNode.removeAction(forKey: ActionKey.settle)

        if breathNode.action(forKey: ActionKey.breathe) == nil {
            // Keep the character's center point completely fixed.
            // A very small, non-uniform scale change creates a soft breathing effect.
            let inhale = eased(
                SKAction.scaleX(to: 1.004, y: 1.008, duration: 1.55)
            )
            let softRelease = eased(
                SKAction.scaleX(to: 0.999, y: 0.997, duration: 1.35)
            )
            let neutral = eased(
                SKAction.scaleX(to: 1.0, y: 1.0, duration: 0.72)
            )

            breathNode.run(
                .repeatForever(.sequence([inhale, softRelease, neutral])),
                withKey: ActionKey.breathe
            )
        }
    }

    private func restartContinuousIdleMotion() {
        removeContinuousIdleActions()
        settleToNeutralPose(animated: false)
        startContinuousIdleMotionIfNeeded()
    }

    private func startBlinkLoopIfNeeded() {
        guard blinkTask == nil else { return }
        guard blinkTexturesAreAvailable else { return }

        blinkTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let wait = Double.random(in: 2.2...6.0)
                guard await self.sleep(seconds: wait) else { break }
                guard self.canRunCurrentIdle else { break }

                let shouldDoubleBlink = Double.random(in: 0...1) < 0.18
                guard await self.playBlinkSequence() else { break }

                if shouldDoubleBlink {
                    let gap = Double.random(in: 0.18...0.45)
                    guard await self.sleep(seconds: gap) else { break }
                    guard self.canRunCurrentIdle else { break }
                    guard await self.playBlinkSequence() else { break }
                }
            }

            self.blinkTask = nil
        }
    }

    private var blinkTexturesAreAvailable: Bool {
        guard let configuration else { return false }
        return UIImage(named: "\(configuration.baseAssetName)_idle_blink_0001") != nil
            && UIImage(named: "\(configuration.baseAssetName)_idle_blink_0002") != nil
    }

    private func playBlinkSequence() async -> Bool {
        guard let configuration else { return false }
        let baseAssetName = configuration.baseAssetName
        let halfClosedAssetName = "\(baseAssetName)_idle_blink_0001"
        let closedAssetName = "\(baseAssetName)_idle_blink_0002"

        guard canContinueBlink(for: baseAssetName) else { return false }
        setTexture(named: halfClosedAssetName)

        guard await sleep(seconds: 0.070) else { return false }
        guard canContinueBlink(for: baseAssetName) else { return false }
        setTexture(named: closedAssetName)

        guard await sleep(seconds: 0.060) else { return false }
        guard canContinueBlink(for: baseAssetName) else { return false }
        setTexture(named: halfClosedAssetName)

        guard await sleep(seconds: 0.072) else { return false }
        guard canContinueBlink(for: baseAssetName) else { return false }
        setTexture(named: baseAssetName)
        return true
    }

    private func canContinueBlink(for baseAssetName: String) -> Bool {
        guard !Task.isCancelled else { return false }
        guard let configuration else { return false }
        return shouldRunIdle(for: configuration)
            && configuration.baseAssetName == baseAssetName
    }

    private func cancelIdleTasks() {
        blinkTask?.cancel()
        blinkTask = nil
    }

    private func removeContinuousIdleActions() {
        breathNode.removeAction(forKey: ActionKey.breathe)
    }

    private func removeIdleActions() {
        removeContinuousIdleActions()
        breathNode.removeAction(forKey: ActionKey.settle)
    }

    private func settleToNeutralPose(animated: Bool) {
        guard animated else {
            resetMotionImmediately()
            return
        }

        breathNode.run(
            eased(.scaleX(to: 1.0, y: 1.0, duration: 0.30)),
            withKey: ActionKey.settle
        )
    }

    private func resetMotionImmediately() {
        breathNode.zRotation = 0
        breathNode.xScale = 1
        breathNode.yScale = 1
        spriteNode.position = .zero
        updateBreathingPivotPosition()
    }

    private func eased(_ action: SKAction) -> SKAction {
        action.timingMode = .easeInEaseOut
        return action
    }

    private func sleep(seconds: Double) async -> Bool {
        do {
            let nanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}
