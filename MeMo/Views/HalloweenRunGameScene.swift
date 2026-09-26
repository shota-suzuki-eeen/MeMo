//
//  HalloweenRunGameScene.swift
//  MeMo
//
//  3レーン縦スクロールランゲーム本体。
//  2026/09 performance v5:
//  - SKPhysicsを使用せず、少数ノードへの手動衝突判定に変更。
//  - 距離・キャンディ・カウントダウンHUDはSpriteKit内で完結。
//  - SwiftUIへの通知はGAME OVER時の1回だけ。
//  - 仮アセットはSKSpriteNode中心の軽量描画。
//

import SpriteKit
import UIKit

final class HalloweenRunGameScene: SKScene {
    private enum Config {
        static let preferredFramesPerSecond = 60

        static let laneMoveDuration: TimeInterval = 0.14

        static let baseScrollSpeed: CGFloat = 260
        static let maxScrollSpeed: CGFloat = 520
        static let maxDifficultyReachTime: TimeInterval = 180

        static let baseObstacleSpawnInterval: TimeInterval = 1.45
        static let minimumObstacleSpawnInterval: TimeInterval = 0.90
        static let doubleObstacleStartTime: TimeInterval = 30
        static let maximumDoubleObstacleChance: Double = 0.58

        static let candySpawnInterval: TimeInterval = 1.60
        static let candySpawnChance: Double = 0.78
        static let candyTrailChance: Double = 0.24

        static let playerYRatio: CGFloat = 0.18
        static let laneXRatio: [CGFloat] = [0.24, 0.50, 0.76]
        static let obstacleHeight: CGFloat = 72
        static let obstacleWidthRatio: CGFloat = 0.56

        // 手動衝突判定用。playerNodeの見た目より少し小さくして理不尽な接触を防ぐ。
        static let playerCollisionHalfWidth: CGFloat = 19
        static let playerCollisionHalfHeight: CGFloat = 25
        static let obstacleCollisionHalfHeight: CGFloat = 30
        static let candyCollisionHalfSize: CGFloat = 18

        // 0秒時点で約8m/s、3分時点で約16m/s。
        static let baseMetersPerSecond: Double = 8
        static let maxMetersPerSecond: Double = 16

        // Date()を毎フレーム呼ばず、イベント終了だけ1秒ごとに確認。
        static let eventEndCheckInterval: TimeInterval = 1.0
    }

    /// SwiftUI側へ渡すのはプレイ終了時だけ。
    var onGameOver: ((HalloweenRunResult) -> Void)?

    // MARK: - Layers

    private let roadMarkLayer = SKNode()
    private let movingLayer = SKNode()
    private let hudLayer = SKNode()

    // MARK: - Player

    private let playerNode = SKSpriteNode(
        color: UIColor(white: 0.96, alpha: 1),
        size: CGSize(width: 52, height: 62)
    )

    private var lanePositions: [CGFloat] = []
    private var playerLane = 1
    private var preferredSafeLane = 1

    // MARK: - HUD

    private let distanceTitleLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let distanceLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let candyLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let countdownLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let readyLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let leftHintLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let rightHintLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")

    // MARK: - Runtime

    private var previousUpdateTime: TimeInterval?
    private var countdownRemaining: TimeInterval = 3
    private var lastDisplayedCountdown: Int?

    private var elapsedTime: TimeInterval = 0
    private var obstacleSpawnAccumulator: TimeInterval = 0
    private var candySpawnAccumulator: TimeInterval = 0
    private var eventEndCheckAccumulator: TimeInterval = 0

    private var distanceMeters: Double = 0
    private var candyCount = 0
    private var lastDisplayedDistance = -1

    private var isGameOver = false
    private var hasShutDown = false

    // 生成器をタップごとに作らず使い回す。
    private let moveHaptic = UIImpactFeedbackGenerator(style: .light)
    private let candyHaptic = UIImpactFeedbackGenerator(style: .soft)
    private let gameOverHaptic = UINotificationFeedbackGenerator()

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.08, green: 0.04, blue: 0.15, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
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

        moveHaptic.prepare()
        candyHaptic.prepare()
        gameOverHaptic.prepare()
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
    }

    // MARK: - Setup

    private func setupLayers() {
        roadMarkLayer.zPosition = -5
        addChild(roadMarkLayer)

        movingLayer.zPosition = 10
        addChild(movingLayer)

        hudLayer.zPosition = 100
        addChild(hudLayer)
    }

    private func setupRoad() {
        lanePositions = Config.laneXRatio.map { size.width * $0 }

        let road = SKSpriteNode(
            color: UIColor(red: 0.13, green: 0.09, blue: 0.21, alpha: 1),
            size: CGSize(width: size.width * 0.86, height: size.height * 1.1)
        )
        road.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        road.zPosition = -10
        addChild(road)

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
        preferredSafeLane = 1

        playerNode.position = CGPoint(
            x: lanePositions[playerLane],
            y: size.height * Config.playerYRatio
        )
        playerNode.zPosition = 20
        playerNode.name = "player"

        // 仮キャラクターの目。2ノードだけなので負荷は無視できる。
        let leftEye = SKShapeNode(circleOfRadius: 5)
        leftEye.fillColor = .black
        leftEye.strokeColor = .clear
        leftEye.position = CGPoint(x: -10, y: 10)
        playerNode.addChild(leftEye)

        let rightEye = SKShapeNode(circleOfRadius: 5)
        rightEye.fillColor = .black
        rightEye.strokeColor = .clear
        rightEye.position = CGPoint(x: 10, y: 10)
        playerNode.addChild(rightEye)

        addChild(playerNode)
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
        candyLabel.horizontalAlignmentMode = .right
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

        leftHintLabel.text = "← LEFT"
        leftHintLabel.fontSize = 11
        leftHintLabel.fontColor = UIColor.white.withAlphaComponent(0.62)
        leftHintLabel.horizontalAlignmentMode = .left
        leftHintLabel.verticalAlignmentMode = .center

        rightHintLabel.text = "RIGHT →"
        rightHintLabel.fontSize = 11
        rightHintLabel.fontColor = UIColor.white.withAlphaComponent(0.62)
        rightHintLabel.horizontalAlignmentMode = .right
        rightHintLabel.verticalAlignmentMode = .center

        hudLayer.addChild(distanceTitleLabel)
        hudLayer.addChild(distanceLabel)
        hudLayer.addChild(candyLabel)
        hudLayer.addChild(countdownLabel)
        hudLayer.addChild(readyLabel)
        hudLayer.addChild(leftHintLabel)
        hudLayer.addChild(rightHintLabel)

        updateHUDPositions()
        updateCountdownHUD(force: true)
    }

    private func updateHUDPositions() {
        let topY = size.height - 68

        distanceTitleLabel.position = CGPoint(x: size.width * 0.5, y: topY + 10)
        distanceLabel.position = CGPoint(x: size.width * 0.5, y: topY - 14)
        candyLabel.position = CGPoint(x: size.width - 18, y: topY - 3)

        countdownLabel.position = CGPoint(x: size.width * 0.5, y: size.height * 0.56)
        readyLabel.position = CGPoint(x: size.width * 0.5, y: size.height * 0.56 - 72)

        leftHintLabel.position = CGPoint(x: 26, y: 34)
        rightHintLabel.position = CGPoint(x: size.width - 26, y: 34)
    }

    // MARK: - Frame update

    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver, !hasShutDown else { return }

        guard let previousUpdateTime else {
            self.previousUpdateTime = currentTime
            return
        }

        var deltaTime = currentTime - previousUpdateTime
        self.previousUpdateTime = currentTime
        deltaTime = min(max(0, deltaTime), 0.05)

        eventEndCheckAccumulator += deltaTime
        if eventEndCheckAccumulator >= Config.eventEndCheckInterval {
            eventEndCheckAccumulator = 0
            if EventManager.hasEnded(.halloween2026) {
                finishGame()
                return
            }
        }

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

        let difficulty = difficultyProgress
        let scrollSpeed = currentScrollSpeed(difficulty: difficulty)

        updateRoadMarks(deltaTime: deltaTime, speed: scrollSpeed)
        updateMovingNodesAndCollisions(deltaTime: deltaTime, speed: scrollSpeed)

        guard !isGameOver else { return }

        updateDistance(deltaTime: deltaTime, difficulty: difficulty)
        updateObstacleSpawning(deltaTime: deltaTime, difficulty: difficulty)
        updateCandySpawning(deltaTime: deltaTime)
    }

    private var difficultyProgress: Double {
        min(1, max(0, elapsedTime / Config.maxDifficultyReachTime))
    }

    private func currentScrollSpeed(difficulty: Double) -> CGFloat {
        Config.baseScrollSpeed
            + (Config.maxScrollSpeed - Config.baseScrollSpeed) * CGFloat(difficulty)
    }

    private func currentObstacleSpawnInterval(difficulty: Double) -> TimeInterval {
        Config.baseObstacleSpawnInterval
            - (Config.baseObstacleSpawnInterval - Config.minimumObstacleSpawnInterval) * difficulty
    }

    private func updateDistance(deltaTime: TimeInterval, difficulty: Double) {
        let metersPerSecond = Config.baseMetersPerSecond
            + (Config.maxMetersPerSecond - Config.baseMetersPerSecond) * difficulty

        distanceMeters += metersPerSecond * deltaTime

        let integerDistance = max(0, Int(distanceMeters.rounded(.down)))
        guard integerDistance != lastDisplayedDistance else { return }

        lastDisplayedDistance = integerDistance
        distanceLabel.text = "\(integerDistance)m"
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

    private func updateObstacleSpawning(deltaTime: TimeInterval, difficulty: Double) {
        obstacleSpawnAccumulator += deltaTime
        let interval = currentObstacleSpawnInterval(difficulty: difficulty)

        guard obstacleSpawnAccumulator >= interval else { return }
        obstacleSpawnAccumulator -= interval
        spawnObstacleRow(difficulty: difficulty)
    }

    private func spawnObstacleRow(difficulty: Double) {
        let spawnY = size.height + 76

        let doubleChance: Double
        if elapsedTime < Config.doubleObstacleStartTime {
            doubleChance = 0
        } else {
            let denominator = max(
                1,
                Config.maxDifficultyReachTime - Config.doubleObstacleStartTime
            )
            let afterStart = min(
                1,
                max(
                    0,
                    (elapsedTime - Config.doubleObstacleStartTime) / denominator
                )
            )
            doubleChance = 0.12
                + ((Config.maximumDoubleObstacleChance - 0.12) * afterStart)
        }

        if Double.random(in: 0...1) < doubleChance {
            let candidates = [
                preferredSafeLane - 1,
                preferredSafeLane,
                preferredSafeLane + 1,
            ]
            .filter { (0...2).contains($0) }

            let nextSafeLane = candidates.randomElement() ?? preferredSafeLane
            preferredSafeLane = nextSafeLane

            for lane in 0...2 where lane != nextSafeLane {
                spawnObstacle(lane: lane, y: spawnY)
            }
        } else {
            let blockedCandidates = (0...2).filter { $0 != preferredSafeLane }
            let blockedLane = blockedCandidates.randomElement() ?? 0

            spawnObstacle(lane: blockedLane, y: spawnY)

            if difficulty > 0.20, Double.random(in: 0...1) < 0.30 {
                let candidates = [
                    preferredSafeLane - 1,
                    preferredSafeLane + 1,
                ]
                .filter { (0...2).contains($0) && $0 != blockedLane }

                if let next = candidates.randomElement() {
                    preferredSafeLane = next
                }
            }
        }
    }

    private func spawnObstacle(lane: Int, y: CGFloat) {
        guard lanePositions.indices.contains(lane) else { return }

        let laneWidth = size.width * 0.26
        let obstacleSize = CGSize(
            width: laneWidth * Config.obstacleWidthRatio,
            height: Config.obstacleHeight
        )

        let node = SKSpriteNode(
            color: UIColor(red: 0.92, green: 0.25, blue: 0.18, alpha: 1),
            size: obstacleSize
        )
        node.position = CGPoint(x: lanePositions[lane], y: y)
        node.name = "obstacle"
        node.userData = NSMutableDictionary()
        node.userData?["lane"] = lane

        movingLayer.addChild(node)
    }

    // MARK: - Candy

    private func updateCandySpawning(deltaTime: TimeInterval) {
        candySpawnAccumulator += deltaTime

        guard candySpawnAccumulator >= Config.candySpawnInterval else { return }
        candySpawnAccumulator -= Config.candySpawnInterval

        guard Double.random(in: 0...1) < Config.candySpawnChance else { return }

        let spawnY = size.height + 52
        let availableLanes = candyAvailableLanes(aroundY: spawnY)
        guard let lane = availableLanes.randomElement() else { return }

        if Double.random(in: 0...1) < Config.candyTrailChance {
            for index in 0..<3 {
                spawnCandy(lane: lane, y: spawnY + CGFloat(index * 58))
            }
        } else {
            spawnCandy(lane: lane, y: spawnY)
        }
    }

    private func candyAvailableLanes(aroundY y: CGFloat) -> [Int] {
        var blockedLanes = Set<Int>()

        for node in movingLayer.children where node.name == "obstacle" {
            guard abs(node.position.y - y) < 120 else { continue }

            if let lane = node.userData?["lane"] as? Int {
                blockedLanes.insert(lane)
            }
        }

        return (0...2).filter { !blockedLanes.contains($0) }
    }

    private func spawnCandy(lane: Int, y: CGFloat) {
        guard lanePositions.indices.contains(lane) else { return }

        // アセット準備前は最軽量のSpriteNodeをキャンディ代替表示として使用。
        let node = SKSpriteNode(
            color: UIColor(red: 1.00, green: 0.39, blue: 0.66, alpha: 1),
            size: CGSize(width: 30, height: 30)
        )
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

        node.removeFromParent()
        candyCount += 1
        candyLabel.text = "CANDY  \(candyCount)"

        candyHaptic.impactOccurred(intensity: 0.64)
    }

    private func updateRoadMarks(deltaTime: TimeInterval, speed: CGFloat) {
        let deltaY = speed * CGFloat(deltaTime)
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
        guard !isGameOver, !hasShutDown, countdownRemaining <= 0 else {
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
            duration: Config.laneMoveDuration
        )
        move.timingMode = .easeOut
        playerNode.run(move, withKey: "laneMove")

        moveHaptic.impactOccurred(intensity: 0.72)
    }

    // MARK: - Finish / cleanup

    private func finishGame() {
        guard !isGameOver, !hasShutDown else { return }

        isGameOver = true
        previousUpdateTime = nil
        playerNode.removeAllActions()

        gameOverHaptic.notificationOccurred(.error)

        let result = HalloweenRunResult(
            distance: max(0, Int(distanceMeters.rounded(.down))),
            candyCount: max(0, candyCount)
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
        previousUpdateTime = nil

        playerNode.removeAllActions()
        removeAllActions()
        movingLayer.removeAllActions()
        roadMarkLayer.removeAllActions()
        hudLayer.removeAllActions()

        isPaused = true
    }
}
