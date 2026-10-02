//
//  HalloweenRunGameScene.swift
//  MeMo
//
//  3レーン縦スクロールランゲーム本体。
//  2026/09 performance v5:
//  - SKPhysicsを使用せず、少数ノードへの手動衝突判定に変更。
//  - 距離・キャンディ・カウントダウンHUDはSpriteKit内で完結。
//  - SwiftUIへの通知はGAME OVER時の1回だけ。
//  - 登録済みテクスチャと上限付き回収エフェクトで軽量描画。
//

import SpriteKit
import UIKit

final class HalloweenRunGameScene: SKScene {
    private enum Config {
        static let preferredFramesPerSecond = 60

        static let playerYRatio: CGFloat = 0.18
        static let laneXRatio: [CGFloat] = [0.24, 0.50, 0.76]
        static let obstacleHeight: CGFloat = 72
        static let obstacleWidthRatio: CGFloat = 0.56

        // 手動衝突判定用。playerNodeの見た目より少し小さくして理不尽な接触を防ぐ。
        static let playerCollisionHalfWidth: CGFloat = 19
        static let playerCollisionHalfHeight: CGFloat = 25
        static let obstacleCollisionHalfHeight: CGFloat = 30
        static let candyCollisionHalfSize: CGFloat = 18

    }

    /// Results and throttled endless checkpoints are delivered outside the frame update.
    var onGameOver: ((HalloweenRunResult) -> Void)?
    var onCheckpoint: ((HalloweenRunResult) -> Void)?
    var onCandyCollected: (() -> Void)?
    let runMode: HalloweenRunMode
    private let playerAssetName: String
    private var stageAttempt: HalloweenStageAttempt?
    private var stageLevel: Int {
        Halloween2026Configuration.level(forStage: stageAttempt?.number ?? 1)
    }

    // MARK: - Layers

    private let roadMarkLayer = SKNode()
    private let movingLayer = SKNode()
    private let hudLayer = SKNode()
    private let backgroundLayer = SKNode()
    private let collectionLayer = SKNode()
    private let hudPanel = SKShapeNode()
    private var pumpkinNodes: [SKSpriteNode] = []
    private var safeAreaInsets: UIEdgeInsets = .zero
    private lazy var runTexture = SKTexture(imageNamed: "halloween_run")
    private lazy var candyTexture = SKTexture(imageNamed: "halloween_candy")
    private lazy var woodTexture = SKTexture(imageNamed: "halloween_wood")
    private lazy var pumpkinTexture = SKTexture(imageNamed: "halloween_level_pumpkin")
    private var layout: HalloweenRunHUDLayout {
        .init(width: Double(size.width), height: Double(size.height), safeTop: Double(safeAreaInsets.top))
    }
    private var lastCollectionSoundTime: TimeInterval = -1

    // MARK: - Player

    private let playerNode = SKSpriteNode(
        color: UIColor(white: 0.96, alpha: 1),
        size: CGSize(width: 52, height: 62)
    )

    private var lanePositions: [CGFloat] = []
    private var playerLane = 1
    private var obstaclePlanner = HalloweenObstaclePlanner()
    private var randomGenerator = SystemRandomNumberGenerator()
    private var runDifficulty = HalloweenRunDifficulty()
    private var currentLevel: Int { runMode == .endless ? runDifficulty.level : stageLevel }

    // MARK: - HUD

    private let distanceTitleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let distanceLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let candyLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let levelLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let oldLevelAnnouncement = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let newLevelAnnouncement = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let countdownLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let readyLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    // MARK: - Runtime

    private var previousUpdateTime: TimeInterval?
    private var countdownRemaining: TimeInterval = 3
    private var lastDisplayedCountdown: Int?

    private var elapsedTime: TimeInterval = 0
    private var obstacleSpawnAccumulator: TimeInterval = 0
    private var candySpawnAccumulator: TimeInterval = 0

    private var distanceMeters: Double = 0
    private var candyCount = 0
    private var lastDisplayedDistance = -1

    private var isGameOver = false
    private var hasShutDown = false
    private var interruption = HalloweenRunInterruption()
    private var checkpointAccumulator: TimeInterval = 0
    private var lifecycleObservers: [NSObjectProtocol] = []

    var currentRunProgress: HalloweenRunResult {
        HalloweenRunResult(distance: max(0, Int(distanceMeters.rounded(.down))),
            candyCount: candyCount, mode: runMode, stageNumber: stageAttempt?.number,
            clearedStage: stageAttempt?.isCleared ?? false)
    }

    // 生成器をタップごとに作らず使い回す。
    private let moveHaptic = UIImpactFeedbackGenerator(style: .light)
    private let candyHaptic = UIImpactFeedbackGenerator(style: .soft)
    private let gameOverHaptic = UINotificationFeedbackGenerator()

    init(size: CGSize, mode: HalloweenRunMode, stageNumber: Int?, playerAssetName: String) {
        runMode = mode
        self.playerAssetName = playerAssetName
        stageAttempt = mode == .endless ? nil : HalloweenStageAttempt(number: stageNumber ?? 1)
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.08, green: 0.04, blue: 0.15, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("Use init(size:mode:stageNumber:)")
    }

    override func didMove(to view: SKView) {
        view.preferredFramesPerSecond = Config.preferredFramesPerSecond
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = true
        view.isMultipleTouchEnabled = false
        view.backgroundColor = backgroundColor

        removeAllChildren()
        setupLayers()
        setupRoad()
        setupPlayer()
        setupHUD()
        levelLabel.fontSize = 15
        levelLabel.fontColor = .orange
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.isHidden = runMode == .bonus
        hudLayer.addChild(levelLabel)
        levelLabel.text = "Lv\(currentLevel)"
        pumpkinNodes = (0..<5).map { _ in
            let node = SKSpriteNode(texture: pumpkinTexture)
            node.size = CGSize(width: 18, height: 18)
            node.isHidden = runMode == .bonus
            hudLayer.addChild(node)
            return node
        }
        updatePumpkins()
        for announcement in [oldLevelAnnouncement, newLevelAnnouncement] {
            announcement.fontSize = 26
            announcement.fontColor = .orange
            announcement.isHidden = true
            hudLayer.addChild(announcement)
        }
        updateHUDPositions()
        if let attempt = stageAttempt {
            distanceTitleLabel.text = attempt.mode == .bonus ? "BONUS \(attempt.number) · Lv\(stageLevel)" : "STAGE \(attempt.number)"
            distanceLabel.text = "\(Int(attempt.duration))秒"
            candyLabel.isHidden = attempt.mode == .stage
        }

        moveHaptic.prepare()
        candyHaptic.prepare()
        gameOverHaptic.prepare()
        observeApplicationLifecycle()
        setAppActive(UIApplication.shared.applicationState == .active)
    }

    deinit { lifecycleObservers.forEach(NotificationCenter.default.removeObserver) }

    private func observeApplicationLifecycle() {
        guard lifecycleObservers.isEmpty else { return }
        for name in [UIApplication.willResignActiveNotification, UIApplication.didEnterBackgroundNotification] {
            lifecycleObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.setAppActive(false)
            })
        }
        lifecycleObservers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.setAppActive(true)
        })
    }

    func setAppActive(_ active: Bool) {
        guard !isGameOver, !hasShutDown else { return }
        interruption.setActive(active)
        previousUpdateTime = nil
        if !active {
            countdownRemaining = 0
            onCheckpoint?(currentRunProgress)
        }
        setGameplayActionsPaused(!interruption.canSimulate)
        if !interruption.canSimulate { updateResumeHUD() }
    }

    private func setGameplayActionsPaused(_ paused: Bool) {
        for node in [playerNode, movingLayer, roadMarkLayer, hudLayer, collectionLayer] { node.isPaused = paused }
    }

    private func updateResumeHUD() {
        countdownLabel.isHidden = interruption.isSuspended
        countdownLabel.text = "\(max(1, Int(ceil(interruption.resumeRemaining))))"
        readyLabel.text = interruption.isSuspended ? "PAUSED" : "再開まで"
        readyLabel.isHidden = false
    }

    private func queueCheckpoint() {
        guard runMode == .endless else { return }
        let progress = currentRunProgress
        let callback = onCheckpoint
        DispatchQueue.main.async { callback?(progress) }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard !lanePositions.isEmpty else { return }

        lanePositions = Config.laneXRatio.map { size.width * $0 }
        playerNode.position = CGPoint(
            x: lanePositions[min(max(0, playerLane), lanePositions.count - 1)],
            y: size.height * Config.playerYRatio
        )
        updateHUDPositions()
        layoutBackground()
    }

    // MARK: - Setup

    private func setupLayers() {
        backgroundLayer.removeAllChildren()
        backgroundLayer.zPosition = -20
        addChild(backgroundLayer)
        collectionLayer.removeAllChildren()
        collectionLayer.zPosition = 90
        addChild(collectionLayer)
        roadMarkLayer.zPosition = -5
        addChild(roadMarkLayer)

        movingLayer.zPosition = 10
        addChild(movingLayer)

        hudLayer.zPosition = 100
        addChild(hudLayer)
    }

    private func setupRoad() {
        lanePositions = Config.laneXRatio.map { size.width * $0 }

        for _ in 0..<2 { backgroundLayer.addChild(SKSpriteNode(texture: runTexture)) }
        layoutBackground()

        let dividerXs = [
            (lanePositions[0] + lanePositions[1]) * 0.5,
            (lanePositions[1] + lanePositions[2]) * 0.5,
        ]

        for dividerX in dividerXs {
            for index in 0..<12 {
                let mark = SKSpriteNode(
                    color: UIColor.white.withAlphaComponent(0.16),
                    size: CGSize(width: 4, height: 38)
                )
                mark.position = CGPoint(
                    x: dividerX,
                    y: CGFloat(index) * (size.height / 10) - 30
                )
                roadMarkLayer.addChild(mark)
            }
        }
    }

    private func setupPlayer() {
        playerNode.removeFromParent()
        playerNode.removeAllChildren()

        playerLane = 1
        obstaclePlanner = HalloweenObstaclePlanner()

        playerNode.position = CGPoint(
            x: lanePositions[playerLane],
            y: size.height * Config.playerYRatio
        )
        playerNode.zPosition = 20
        playerNode.name = "player"

        let texture = SKTexture(imageNamed: playerAssetName)
        playerNode.texture = texture
        playerNode.size = fittedSize(texture: texture, bounds: CGSize(width: 52, height: 62))

        addChild(playerNode)
    }

    private func fittedSize(texture: SKTexture, bounds: CGSize) -> CGSize {
        let dimensions = texture.size()
        let scale = min(bounds.width / max(1, dimensions.width), bounds.height / max(1, dimensions.height))
        return CGSize(width: dimensions.width * scale, height: dimensions.height * scale)
    }

    private func layoutBackground() {
        let dimensions = runTexture.size()
        let scale = max(size.width / max(1, dimensions.width), size.height / max(1, dimensions.height))
        let tileSize = CGSize(width: dimensions.width * scale, height: dimensions.height * scale)
        for (index, child) in backgroundLayer.children.enumerated() {
            guard let node = child as? SKSpriteNode else { continue }
            node.size = tileSize
            node.position = CGPoint(x: size.width / 2, y: tileSize.height * (CGFloat(index) + 0.5))
        }
    }

    func updateSafeArea(_ insets: UIEdgeInsets) {
        guard insets != safeAreaInsets else { return }
        safeAreaInsets = insets
        updateHUDPositions()
    }

    private func updatePumpkins() {
        for (index, node) in pumpkinNodes.enumerated() {
            node.color = .black
            node.colorBlendFactor = index < currentLevel ? 0 : 1
        }
    }

    private func setupHUD() {
        distanceTitleLabel.text = "DISTANCE"
        distanceTitleLabel.fontSize = 10
        distanceTitleLabel.fontColor = UIColor.white.withAlphaComponent(0.62)
        distanceTitleLabel.horizontalAlignmentMode = .center
        distanceTitleLabel.verticalAlignmentMode = .center

        distanceLabel.text = "0m"
        distanceLabel.fontSize = 25
        distanceLabel.fontColor = .white
        distanceLabel.horizontalAlignmentMode = .center
        distanceLabel.verticalAlignmentMode = .center

        candyLabel.text = "CANDY  0"
        candyLabel.fontSize = 17
        candyLabel.fontColor = .white
        candyLabel.horizontalAlignmentMode = runMode == .bonus ? .center : .right
        candyLabel.verticalAlignmentMode = .center

        countdownLabel.text = "3"
        countdownLabel.fontSize = 88
        countdownLabel.fontColor = .white
        countdownLabel.horizontalAlignmentMode = .center
        countdownLabel.verticalAlignmentMode = .center

        readyLabel.text = "READY"
        readyLabel.fontSize = 18
        readyLabel.fontColor = .orange
        readyLabel.horizontalAlignmentMode = .center
        readyLabel.verticalAlignmentMode = .center

        hudPanel.fillColor = UIColor.black.withAlphaComponent(0.62)
        hudPanel.strokeColor = UIColor.white.withAlphaComponent(0.16)
        hudPanel.zPosition = -1
        hudLayer.addChild(hudPanel)
        hudLayer.addChild(distanceTitleLabel)
        hudLayer.addChild(distanceLabel)
        hudLayer.addChild(candyLabel)
        hudLayer.addChild(countdownLabel)
        hudLayer.addChild(readyLabel)

        updateHUDPositions()
        updateCountdownHUD(force: true)
    }

    private func updateHUDPositions() {
        let hud = layout
        hudPanel.path = CGPath(roundedRect: CGRect(x: 10, y: size.height - CGFloat(hud.headerClearance),
            width: max(1, size.width - 20), height: 118), cornerWidth: 20, cornerHeight: 20, transform: nil)
        levelLabel.position = CGPoint(x: 20, y: hud.levelY)
        for (index, node) in pumpkinNodes.enumerated() {
            node.position = CGPoint(x: hud.pumpkinCenters[index], y: hud.pumpkinY)
        }
        oldLevelAnnouncement.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        newLevelAnnouncement.position = oldLevelAnnouncement.position

        distanceTitleLabel.position = CGPoint(x: size.width * 0.5, y: hud.titleY)
        distanceLabel.position = CGPoint(x: size.width * 0.5, y: hud.valueY)
        candyLabel.position = CGPoint(x: runMode == .bonus ? CGFloat(hud.candyCenterX) : size.width - 22, y: hud.candyY)

        countdownLabel.position = CGPoint(x: size.width * 0.5, y: size.height * 0.56)
        readyLabel.position = CGPoint(x: size.width * 0.5, y: size.height * 0.56 - 72)


    }

    // MARK: - Frame update

    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver, !hasShutDown else { return }
        guard !interruption.isSuspended else { previousUpdateTime = nil; return }

        guard let previousUpdateTime else {
            self.previousUpdateTime = currentTime
            return
        }

        var deltaTime = currentTime - previousUpdateTime
        self.previousUpdateTime = currentTime
        deltaTime = min(max(0, deltaTime), Halloween2026Configuration.maximumFrameStep)
        if !interruption.canSimulate {
            interruption.advanceCountdown(by: deltaTime)
            updateResumeHUD()
            if interruption.canSimulate {
                countdownLabel.isHidden = true
                readyLabel.isHidden = true
                readyLabel.text = "READY"
                setGameplayActionsPaused(false)
            }
            return
        }
        if let attempt = stageAttempt { deltaTime = min(deltaTime, attempt.remaining) }

        // The start gate admits the run; crossing the event end must not end it.

        if countdownRemaining > 0 {
            countdownRemaining = max(0, countdownRemaining - deltaTime)
            updateCountdownHUD()

            if countdownRemaining <= 0 {
                countdownLabel.isHidden = true
                readyLabel.isHidden = true
            }
            return
        }

        elapsedTime += deltaTime

        let scrollSpeed = currentScrollSpeed

        updateRoadMarks(deltaTime: deltaTime, speed: scrollSpeed)
        updateMovingNodesAndCollisions(deltaTime: deltaTime, speed: scrollSpeed)

        guard !isGameOver else { return }

        updateDistance(deltaTime: deltaTime)
        if runMode == .endless {
            checkpointAccumulator += deltaTime
            if checkpointAccumulator >= Halloween2026Configuration.runCheckpointInterval {
                checkpointAccumulator = 0
                queueCheckpoint()
            }
        }
        if runMode == .endless {
            let previousLevel = runDifficulty.level
            let resumed = runDifficulty.advance(distance: Int(distanceMeters),
                objectsAreEmpty: movingLayer.children.isEmpty, seconds: deltaTime)
            if runDifficulty.level != previousLevel { announceLevel(from: previousLevel); updatePumpkins() }
            if case let .draining(target) = runDifficulty.phase {
                levelLabel.text = "Lv\(currentLevel) → Lv\(target)"
            } else { levelLabel.text = "Lv\(currentLevel)" }
            if resumed {
                obstacleSpawnAccumulator = 0
                candySpawnAccumulator = 0
                return
            }
        }
        let maySpawn = elapsedTime >= Halloween2026Configuration.startSafetyDuration
            && (runMode != .endless || runDifficulty.canSpawn)
        if runMode != .bonus, maySpawn { updateObstacleSpawning(deltaTime: deltaTime) }
        if runMode == .bonus || (runMode == .endless && maySpawn) { updateCandySpawning(deltaTime: deltaTime) }
        if stageAttempt != nil {
            stageAttempt?.advance(by: deltaTime)
            distanceLabel.text = "\(Int(ceil(stageAttempt!.remaining)))秒"
            if stageAttempt!.isCleared { finishGame(clearedStage: true) }
        }
    }

    private func scrollSpeed(for level: Int) -> Double {
        Halloween2026Configuration.scrollSpeed(forLevel: level, sceneHeight: Double(size.height),
            playerY: Double(playerNode.position.y), collisionHalfHeight: 55, headerClearance: layout.headerClearance)
    }

    private var currentScrollSpeed: CGFloat {
        let level = runMode == .bonus ? 1 : currentLevel
        let previous = runMode == .endless ? runDifficulty.previousSpeedLevel : level
        let fraction = runMode == .endless ? runDifficulty.speedFraction : 1
        return CGFloat(scrollSpeed(for: previous) + (scrollSpeed(for: level) - scrollSpeed(for: previous)) * fraction)
    }

    private func updateDistance(deltaTime: TimeInterval) {
        let previous = runMode == .endless ? runDifficulty.previousSpeedLevel : currentLevel
        let fraction = runMode == .endless ? runDifficulty.speedFraction : 1
        let speeds = Halloween2026Configuration.distanceSpeeds
        let metersPerSecond = speeds[previous - 1] + (speeds[currentLevel - 1] - speeds[previous - 1]) * fraction

        distanceMeters += metersPerSecond * deltaTime

        let integerDistance = max(0, Int(distanceMeters.rounded(.down)))
        guard integerDistance != lastDisplayedDistance else { return }

        lastDisplayedDistance = integerDistance
        if runMode == .endless { distanceLabel.text = "\(integerDistance)m" }
    }

    private func announceLevel(from previous: Int) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.62)
        oldLevelAnnouncement.removeAllActions()
        newLevelAnnouncement.removeAllActions()
        oldLevelAnnouncement.text = "LEVEL \(previous)"
        oldLevelAnnouncement.position = center
        oldLevelAnnouncement.alpha = 1
        oldLevelAnnouncement.isHidden = false
        newLevelAnnouncement.text = "LEVEL \(currentLevel)"
        newLevelAnnouncement.position = CGPoint(x: center.x, y: center.y + 38)
        newLevelAnnouncement.alpha = 1
        newLevelAnnouncement.isHidden = false
        oldLevelAnnouncement.run(.sequence([
            .group([.moveBy(x: 0, y: -38, duration: Halloween2026Configuration.levelPushDuration),
                    .fadeOut(withDuration: Halloween2026Configuration.levelPushDuration)]),
            .hide()
        ]))
        newLevelAnnouncement.run(.sequence([
            .move(to: center, duration: Halloween2026Configuration.levelPushDuration),
            .wait(forDuration: Halloween2026Configuration.levelReadDuration),
            .group([.moveBy(x: 0, y: -20, duration: Halloween2026Configuration.levelExitDuration),
                    .fadeOut(withDuration: Halloween2026Configuration.levelExitDuration)]),
            .hide()
        ]))
    }

    private func updateCountdownHUD(force: Bool = false) {
        guard countdownRemaining > 0 else {
            countdownLabel.isHidden = true
            readyLabel.isHidden = true
            lastDisplayedCountdown = nil
            return
        }

        let value = max(1, Int(ceil(countdownRemaining)))
        guard force || value != lastDisplayedCountdown else { return }

        lastDisplayedCountdown = value
        countdownLabel.text = "\(value)"
        countdownLabel.isHidden = false
        readyLabel.isHidden = false
    }

    // MARK: - Obstacles

    private func updateObstacleSpawning(deltaTime: TimeInterval) {
        obstacleSpawnAccumulator += deltaTime
        let interval = Halloween2026Configuration.obstacleIntervals[currentLevel - 1]

        guard obstacleSpawnAccumulator >= interval else { return }
        obstacleSpawnAccumulator -= interval
        spawnObstacleRow()
    }

    private func spawnObstacleRow() {
        let spawnY = size.height + 76
        let separation = Halloween2026Configuration.candyObstacleSeparation(scrollSpeed: Double(currentScrollSpeed))
        let candyLanes = Set(movingLayer.children.compactMap { node -> Int? in
            guard node.name == "candy", abs(Double(node.position.y - spawnY)) < separation else { return nil }
            return node.userData?["lane"] as? Int
        })
        let blocked = obstaclePlanner.nextRow(level: currentLevel, scrollSpeed: Double(currentScrollSpeed),
            collisionBandHeight: Double(2 * (Config.obstacleCollisionHalfHeight + Config.playerCollisionHalfHeight)),
            candyLanes: candyLanes, using: &randomGenerator)
        for lane in blocked { spawnObstacle(lane: lane, y: spawnY) }
    }

    private func spawnObstacle(lane: Int, y: CGFloat) {
        guard lanePositions.indices.contains(lane) else { return }

        let laneWidth = size.width * 0.26
        let obstacleSize = CGSize(
            width: laneWidth * Config.obstacleWidthRatio,
            height: Config.obstacleHeight
        )

        let node = SKSpriteNode(texture: woodTexture)
        node.size = fittedSize(texture: woodTexture, bounds: obstacleSize)
        node.position = CGPoint(x: lanePositions[lane], y: y)
        node.name = "obstacle"
        node.userData = NSMutableDictionary()
        node.userData?["lane"] = lane

        movingLayer.addChild(node)
    }

    // MARK: - Candy

    private func updateCandySpawning(deltaTime: TimeInterval) {
        candySpawnAccumulator += deltaTime

        if runMode == .bonus {
            guard candyCount < Halloween2026Configuration.bonusCandyLimit,
                  candySpawnAccumulator >= 0.45 else { return }
            candySpawnAccumulator -= 0.45
            // Broad waves give time to change lanes; only touched sprites count.
            let waveLanes = [1, 0, 1, 2]
            let lane = waveLanes[Int(elapsedTime / 3) % waveLanes.count]
            for index in 0..<8 {
                spawnCandy(lane: lane, y: size.height + 52 + CGFloat(index * 44))
            }
            return
        }

        let interval = Halloween2026Configuration.candyIntervals[currentLevel - 1]
        guard candySpawnAccumulator >= interval else { return }
        candySpawnAccumulator -= interval
        guard Double.random(in: 0..<1, using: &randomGenerator) < Halloween2026Configuration.candySpawnProbability else { return }

        let spawnY = size.height + 52
        let column = Double.random(in: 0..<1, using: &randomGenerator) < Halloween2026Configuration.candyColumnProbability
        let positions = (0..<(column ? 3 : 1)).map { spawnY + CGFloat($0 * 58) }
        let availableLanes = candyAvailableLanes(around: positions)
        guard let lane = availableLanes.randomElement(using: &randomGenerator) else { return }
        for y in positions { spawnCandy(lane: lane, y: y) }
    }

    private func candyAvailableLanes(around positions: [CGFloat]) -> [Int] {
        var blockedLanes = Set<Int>()
        let separation = Halloween2026Configuration.candyObstacleSeparation(scrollSpeed: Double(currentScrollSpeed))
        for node in movingLayer.children where node.name == "obstacle" {
            guard positions.contains(where: { abs(Double(node.position.y - $0)) < separation }) else { continue }
            if let lane = node.userData?["lane"] as? Int { blockedLanes.insert(lane) }
        }
        return (0...2).filter { !blockedLanes.contains($0) }
    }

    private func spawnCandy(lane: Int, y: CGFloat) {
        guard lanePositions.indices.contains(lane) else { return }

        let node = SKSpriteNode(texture: candyTexture)
        node.size = fittedSize(texture: candyTexture, bounds: CGSize(width: 30, height: 30))
        node.position = CGPoint(x: lanePositions[lane], y: y)
        node.name = "candy"
        node.userData = NSMutableDictionary()
        node.userData?["lane"] = lane

        movingLayer.addChild(node)
    }

    // MARK: - Manual movement / collision

    private func updateMovingNodesAndCollisions(
        deltaTime: TimeInterval,
        speed: CGFloat
    ) {
        let deltaY = speed * CGFloat(deltaTime)
        let obstacleHalfWidth =
            size.width * 0.26 * Config.obstacleWidthRatio * 0.42

        // childrenはArrayのスナップショットなので、ループ中にremoveしても安全。
        for node in movingLayer.children {
            node.position.y -= deltaY
            // Spawns enter the visible playfield below the HUD; the reaction-time
            // clamp uses this same edge. Collection effects may reach the counter.
            node.isHidden = node.position.y > size.height - CGFloat(layout.headerClearance)

            if node.name == "obstacle" {
                let xDistance = abs(node.position.x - playerNode.position.x)
                let yDistance = abs(node.position.y - playerNode.position.y)

                let hitX =
                    xDistance
                    <= obstacleHalfWidth + Config.playerCollisionHalfWidth
                let hitY =
                    yDistance
                    <= Config.obstacleCollisionHalfHeight
                        + Config.playerCollisionHalfHeight

                if hitX && hitY {
                    finishGame()
                    return
                }
            } else if node.name == "candy" {
                let xDistance = abs(node.position.x - playerNode.position.x)
                let yDistance = abs(node.position.y - playerNode.position.y)

                let hitX =
                    xDistance
                    <= Config.candyCollisionHalfSize
                        + Config.playerCollisionHalfWidth
                let hitY =
                    yDistance
                    <= Config.candyCollisionHalfSize
                        + Config.playerCollisionHalfHeight

                if hitX && hitY {
                    collectCandy(node)
                    continue
                }
            }

            if node.position.y < -100 {
                node.removeFromParent()
            }
        }
    }

    private func collectCandy(_ node: SKNode) {
        guard node.parent != nil else { return }
        let origin = node.position
        node.removeFromParent()
        if runMode == .bonus {
            stageAttempt?.collectCandy()
            candyCount = stageAttempt?.collectedCandy ?? 0
        } else {
            candyCount += 1
        }
        candyLabel.text = "CANDY  \(candyCount)"
        queueCheckpoint()
        if elapsedTime - lastCollectionSoundTime >= 0.09 {
            lastCollectionSoundTime = elapsedTime
            onCandyCollected?()
        }
        if runMode == .bonus, !UIAccessibility.isReduceMotionEnabled, collectionLayer.children.count < 10 {
            let flying = SKSpriteNode(texture: candyTexture)
            flying.size = CGSize(width: 24, height: 20)
            flying.position = origin
            collectionLayer.addChild(flying)
            let move = SKAction.move(to: candyLabel.position, duration: 0.34)
            move.timingMode = .easeOut
            flying.run(.sequence([.group([move, .scale(to: 0.28, duration: 0.34)]), .removeFromParent()]))
            candyLabel.run(.sequence([.scale(to: 1.08, duration: 0.08), .scale(to: 1, duration: 0.12)]), withKey: "collectionPulse")
            candyLabel.fontColor = .yellow
            candyLabel.run(.sequence([.wait(forDuration: 0.15), .run { [weak self] in self?.candyLabel.fontColor = .white }]), withKey: "collectionLight")
        }

        candyHaptic.impactOccurred(intensity: 0.64)
    }

    private func updateRoadMarks(deltaTime: TimeInterval, speed: CGFloat) {
        let deltaY = speed * CGFloat(deltaTime)
        for child in backgroundLayer.children {
            guard let tile = child as? SKSpriteNode else { continue }
            tile.position.y -= deltaY
            if tile.position.y + tile.size.height / 2 < 0 { tile.position.y += tile.size.height * 2 }
        }
        let resetY = size.height + 80

        for node in roadMarkLayer.children {
            node.position.y -= deltaY

            if node.position.y < -60 {
                node.position.y = resetY
            }
        }
    }

    // MARK: - Input

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameOver, !hasShutDown, countdownRemaining <= 0, interruption.canSimulate else {
            return
        }
        guard let touch = touches.first else { return }

        let location = touch.location(in: self)

        if location.x < size.width * 0.5 {
            movePlayer(by: -1)
        } else {
            movePlayer(by: 1)
        }
    }

    private func movePlayer(by delta: Int) {
        let targetLane = min(2, max(0, playerLane + delta))
        guard targetLane != playerLane else { return }

        playerLane = targetLane

        playerNode.removeAction(forKey: "laneMove")

        let move = SKAction.moveTo(
            x: lanePositions[targetLane],
            duration: Halloween2026Configuration.laneMoveDuration
        )
        move.timingMode = .easeOut
        playerNode.run(move, withKey: "laneMove")

        moveHaptic.impactOccurred(intensity: 0.72)
    }

    func requestLaneMove(by delta: Int) {
        guard !isGameOver, !hasShutDown, countdownRemaining <= 0, interruption.canSimulate else { return }
        movePlayer(by: delta < 0 ? -1 : 1)
    }

    // MARK: - Finish / cleanup

    private func finishGame(clearedStage: Bool = false) {
        guard !isGameOver, !hasShutDown else { return }

        isGameOver = true
        previousUpdateTime = nil
        playerNode.removeAllActions()

        if !clearedStage { stageAttempt?.collide() }
        gameOverHaptic.notificationOccurred(clearedStage ? .success : .error)

        let result = HalloweenRunResult(
            distance: max(0, Int(distanceMeters.rounded(.down))),
            candyCount: stageAttempt?.confirmedCandy ?? max(0, candyCount),
            mode: runMode,
            stageNumber: stageAttempt?.number,
            clearedStage: stageAttempt?.isCleared ?? false
        )

        let callback = onGameOver

        // Scene更新処理の途中でSwiftUI Stateを直接変更しない。
        DispatchQueue.main.async {
            callback?(result)
        }
    }

    func shutdown() {
        guard !hasShutDown else { return }

        hasShutDown = true
        isGameOver = true
        onGameOver = nil
        onCheckpoint = nil
        onCandyCollected = nil
        lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
        lifecycleObservers.removeAll()
        previousUpdateTime = nil

        playerNode.removeAllActions()
        removeAllActions()
        movingLayer.removeAllActions()
        roadMarkLayer.removeAllActions()
        hudLayer.removeAllActions()
        collectionLayer.removeAllChildren()

        isPaused = true
    }
}
