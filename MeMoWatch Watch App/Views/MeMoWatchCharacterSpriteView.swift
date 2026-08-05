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

    @ObservedObject private var assetCache = MeMoWatchDynamicAssetCache.shared
    @State private var scene = MeMoWatchCharacterSpriteScene(
        size: CGSize(width: 512, height: 512)
    )

    private var fittedVisualSize: CGSize {
        let sourceSize: CGSize

        if let cgImage = assetCache.cgImage(named: assetName)
            ?? assetCache.cgImage(named: baseAssetName) {
            sourceSize = CGSize(
                width: cgImage.width,
                height: cgImage.height
            )
        } else {
            sourceSize = maxDisplaySize
        }

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
        .onChange(of: assetCache.revision) { _, _ in
            guard let updatedAssetName = assetCache.lastStoredAssetName else {
                return
            }

            scene.refreshDynamicAsset(
                named: updatedAssetName,
                configuration: configuration
            )
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
    private var pendingConfiguration: Configuration?
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

    func apply(
        _ newConfiguration: Configuration,
        forceReload: Bool = false
    ) {
        if forceReload {
            textureCache.removeAll()
            currentTextureAssetName = nil
        }

        // キャラクター本体が届いた時点で切り替える。
        // 瞬き画像は切替条件に含めず、後着した時点で瞬きループを開始する。
        guard isConfigurationReadyForActivation(newConfiguration) else {
            pendingConfiguration = newConfiguration

            if configuration == nil {
                spriteNode.isHidden = true
            }
            return
        }

        pendingConfiguration = nil
        activate(newConfiguration, forceReload: forceReload)
    }

    private func activate(
        _ newConfiguration: Configuration,
        forceReload: Bool
    ) {
        guard forceReload || configuration != newConfiguration else {
            if shouldRunIdle(for: newConfiguration) {
                startContinuousIdleMotionIfNeeded()
                startBlinkLoopIfNeeded()
            }
            return
        }

        let previousConfiguration = configuration
        let baseAssetChanged = previousConfiguration?.baseAssetName
            != newConfiguration.baseAssetName
        let visualSizeChanged = previousConfiguration?.visualSize
            != newConfiguration.visualSize
        let presentationChanged = previousConfiguration?.assetName
            != newConfiguration.assetName
            || previousConfiguration?.isIdleEnabled
            != newConfiguration.isIdleEnabled

        configuration = newConfiguration

        if forceReload {
            cancelIdleTasks()
        }

        if baseAssetChanged || presentationChanged {
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
            if baseAssetChanged || visualSizeChanged || presentationChanged || forceReload {
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

    func refreshDynamicAsset(
        named updatedAssetName: String,
        configuration newConfiguration: Configuration
    ) {
        textureCache.removeValue(forKey: updatedAssetName)
        apply(newConfiguration)

        if let pendingConfiguration,
           isConfigurationReadyForActivation(pendingConfiguration) {
            self.pendingConfiguration = nil
            activate(pendingConfiguration, forceReload: false)
        }

        guard let configuration else { return }
        let relevantAssetNames = assetNamesUsedByPresentation(configuration)
        guard relevantAssetNames.contains(updatedAssetName) else { return }

        if updatedAssetName == configuration.assetName
            || updatedAssetName == configuration.baseAssetName {
            currentTextureAssetName = nil
            setTexture(named: configuration.assetName)
        }

        if shouldRunIdle(for: configuration) {
            startContinuousIdleMotionIfNeeded()
            // 2枚の瞬き画像が後から揃った場合、ここで初めて開始される。
            startBlinkLoopIfNeeded()
        }
    }

    private func isConfigurationReadyForActivation(
        _ configuration: Configuration
    ) -> Bool {
        textureIsAvailable(named: configuration.assetName)
    }

    private func assetNamesUsedByPresentation(
        _ configuration: Configuration
    ) -> Set<String> {
        var names: Set<String> = [configuration.assetName]

        if shouldRunIdle(for: configuration) {
            names.insert(configuration.baseAssetName)
        }

        if shouldRunBlink(for: configuration) {
            names.insert("\(configuration.baseAssetName)_idle_blink_0001")
            names.insert("\(configuration.baseAssetName)_idle_blink_0002")
        }

        return names
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

    private func shouldRunBlink(for configuration: Configuration) -> Bool {
        shouldRunIdle(for: configuration)
            && !configuration.assetName.hasSuffix("_wc")
    }

    private var canRunCurrentBlink: Bool {
        guard let configuration else { return false }
        return shouldRunBlink(for: configuration)
    }

    private func texture(named assetName: String) -> SKTexture? {
        if let cached = textureCache[assetName] {
            return cached
        }

        guard let cgImage = MeMoWatchDynamicAssetCache.shared.cgImage(named: assetName) else {
            return nil
        }

        let texture = SKTexture(cgImage: cgImage)
        texture.filteringMode = .linear
        textureCache[assetName] = texture
        return texture
    }

    private func textureIsAvailable(named assetName: String) -> Bool {
        texture(named: assetName) != nil
    }

    private func setTexture(named assetName: String) {
        guard currentTextureAssetName != assetName else { return }

        guard let texture = texture(named: assetName) else {
            currentTextureAssetName = nil

            if spriteNode.texture == nil {
                spriteNode.isHidden = true
            }
            return
        }

        currentTextureAssetName = assetName
        spriteNode.texture = texture
        spriteNode.isHidden = false
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
        guard canRunCurrentBlink else { return }
        guard blinkTexturesAreAvailable else { return }

        blinkTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let wait = Double.random(in: 2.2...6.0)
                guard await self.sleep(seconds: wait) else { break }
                guard self.canRunCurrentBlink else { break }

                let shouldDoubleBlink = Double.random(in: 0...1) < 0.18
                guard await self.playBlinkSequence() else { break }

                if shouldDoubleBlink {
                    let gap = Double.random(in: 0.18...0.45)
                    guard await self.sleep(seconds: gap) else { break }
                    guard self.canRunCurrentBlink else { break }
                    guard await self.playBlinkSequence() else { break }
                }
            }

            self.blinkTask = nil
        }
    }

    private var blinkTexturesAreAvailable: Bool {
        guard let configuration else { return false }
        guard shouldRunBlink(for: configuration) else { return false }

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

        return shouldRunBlink(for: configuration)
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

    deinit {
        blinkTask?.cancel()
    }
}
