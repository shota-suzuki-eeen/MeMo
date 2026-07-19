//
//  MeMoWatchCharacterSpriteView.swift
//  MeMo Watch App
//
//  SpriteKit-based character presentation for Apple Watch.
//  Mirrors the iPhone Home character idle behavior:
//  subtle breathing, random blinking, occasional double blinking,
//  and smooth return to the neutral pose.
//

import SpriteKit
import SwiftUI

@MainActor
struct MeMoWatchCharacterSpriteView: View {
    let assetName: String
    let baseAssetName: String
    let isIdleEnabled: Bool
    let maxDisplaySize: CGSize

    @State private var scene = MeMoWatchCharacterSpriteScene(
        size: CGSize(width: 512, height: 512)
    )

    private var fittedVisualSize: CGSize {
        let texture = SKTexture(imageNamed: baseAssetName)
        let sourceSize = texture.size()

        guard sourceSize.width > 0,
              sourceSize.height > 0,
              maxDisplaySize.width > 0,
              maxDisplaySize.height > 0 else {
            return maxDisplaySize
        }

        let scale = min(
            maxDisplaySize.width / sourceSize.width,
            maxDisplaySize.height / sourceSize.height
        )

        return CGSize(
            width: max(1, sourceSize.width * scale),
            height: max(1, sourceSize.height * scale)
        )
    }

    private var configuration: MeMoWatchCharacterSpriteScene.Configuration {
        MeMoWatchCharacterSpriteScene.Configuration(
            assetName: assetName,
            baseAssetName: baseAssetName,
            isIdleEnabled: isIdleEnabled,
            visualSize: fittedVisualSize
        )
    }

    var body: some View {
        SpriteView(
            scene: scene,
            preferredFramesPerSecond: 30
        )
        .frame(
            width: max(1, maxDisplaySize.width),
            height: max(1, maxDisplaySize.height)
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
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

@MainActor
final class MeMoWatchCharacterSpriteScene: SKScene {
    struct Configuration: Equatable {
        let assetName: String
        let baseAssetName: String
        let isIdleEnabled: Bool
        let visualSize: CGSize
    }

    private enum ActionKey {
        static let breathe = "memo.watch.character.idle.breathe"
        static let settle = "memo.watch.character.idle.settle"
    }

    private let breathNode = SKNode()
    private let spriteNode = SKSpriteNode()

    private var configuration: Configuration?
    private var currentTextureAssetName: String?
    private var blinkTask: Task<Void, Never>?
    private var textureCache: [String: SKTexture] = [:]

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
        let visualSizeChanged = previousConfiguration?.visualSize != newConfiguration.visualSize
        configuration = newConfiguration

        if baseAssetChanged {
            cancelIdleTasks()
            removeIdleActions()
            resetMotionImmediately()
            currentTextureAssetName = nil
        }

        layoutSpriteForCurrentConfiguration()

        let shouldIdle = shouldRunIdle(for: newConfiguration)
        if !shouldIdle {
            cancelIdleTasks()
        }

        setTexture(named: newConfiguration.assetName)

        if shouldIdle {
            if baseAssetChanged || visualSizeChanged {
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

        // The bottom-center pivot keeps the feet fixed while breathing.
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

    private func texture(named assetName: String) -> SKTexture {
        if let cached = textureCache[assetName] {
            return cached
        }

        let texture = SKTexture(imageNamed: assetName)
        texture.filteringMode = .linear
        textureCache[assetName] = texture
        return texture
    }

    private func textureIsAvailable(named assetName: String) -> Bool {
        let size = texture(named: assetName).size()
        return size.width > 1 && size.height > 1
    }

    private func setTexture(named assetName: String) {
        guard currentTextureAssetName != assetName else { return }
        guard textureIsAvailable(named: assetName) else { return }

        currentTextureAssetName = assetName
        spriteNode.texture = texture(named: assetName)
    }

    private func layoutSpriteForCurrentConfiguration() {
        guard let configuration else { return }

        spriteNode.size = CGSize(
            width: max(1, configuration.visualSize.width),
            height: max(1, configuration.visualSize.height)
        )
        updateBreathingPivotPosition()
    }

    private func updateBreathingPivotPosition() {
        guard let configuration else {
            breathNode.position = .zero
            return
        }

        let height = max(1, configuration.visualSize.height)
        breathNode.position = CGPoint(x: 0, y: -(height * 0.5))
    }

    private func startContinuousIdleMotionIfNeeded() {
        breathNode.removeAction(forKey: ActionKey.settle)

        guard breathNode.action(forKey: ActionKey.breathe) == nil else { return }

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

        return textureIsAvailable(
            named: "\(configuration.baseAssetName)_idle_blink_0001"
        ) && textureIsAvailable(
            named: "\(configuration.baseAssetName)_idle_blink_0002"
        )
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
