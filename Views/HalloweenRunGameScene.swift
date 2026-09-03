//
//  HalloweenRunGameScene.swift
//  MeMo
//
//  3レーン縦スクロールランゲーム本体。
//  キャラクターは下部固定、障害物/キャンディを下方向へ流す。
//

import SpriteKit
import UIKit

final class HalloweenRunGameScene: SKScene, SKPhysicsContactDelegate {
    private enum PhysicsCategory {
        static let player: UInt32 = 1 << 0
        static let obstacle: UInt32 = 1 << 1
        static let candy: UInt32 = 1 << 2
    }

    private enum Config {
        static let laneMoveDuration: TimeInterval = 0.14

        static let baseScrollSpeed: CGFloat = 260
        static let maxScrollSpeed: CGFloat = 520
        static let maxDifficultyReachTime: TimeInterval = 180

        static let baseObstacleSpawnInterval: TimeInterval = 1.45
        // 左右タップで十分反応できるよう、最大難度でも0.9秒未満にはしない。
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

        // 0秒時点で約8m/s、3分時点で約16m/s。3分生存時は約2,160mが目安。
        static let baseMetersPerSecond: Double = 8
        static let maxMetersPerSecond: Double = 16
    }

    var onDistanceChanged: ((Int) -> Void)?
    var onCandyChanged: ((Int) -> Void)?
    var onCountdownChanged: ((Int?) -> Void)?
    var onGameOver: ((HalloweenRunResult) -> Void)?

    private let playerNode = SKShapeNode(rectOf: CGSize(width: 52, height: 62), cornerRadius: 22)

    private var lanePositions: [CGFloat] = []
    private var playerLane: Int = 1
    private var preferredSafeLane: Int = 1

    private var previousUpdateTime: TimeInterval?
    private var countdownRemaining: TimeInterval = 3
    private var lastReportedCountdown: Int?

    private var elapsedTime: TimeInterval = 0
    private var obstacleSpawnAccumulator: TimeInterval = 0
    private var candySpawnAccumulator: TimeInterval = 0
    private var distanceMeters: Double = 0
    private var candyCount: Int = 0
    private var lastReportedDistance: Int = -1
    private var isGameOver = false

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.08, green: 0.04, blue: 0.15, alpha: 1)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        removeAllChildren()
        setupRoad()
        setupPlayer()
        reportCountdownIfNeeded(force: true)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard !lanePositions.isEmpty else { return }

        lanePositions = Config.laneXRatio.map { size.width * $0 }
        playerNode.position = CGPoint(
            x: lanePositions[min(max(0, playerLane), lanePositions.count - 1)],
            y: size.height * Config.playerYRatio
        )
    }

    private func setupRoad() {
        lanePositions = Config.laneXRatio.map { size.width * $0 }

        let road = SKShapeNode(rectOf: CGSize(width: size.width * 0.86, height: size.height * 1.1), cornerRadius: 34)
        road.fillColor = UIColor(red: 0.13, green: 0.09, blue: 0.21, alpha: 1)
        road.strokeColor = UIColor.white.withAlphaComponent(0.10)
        road.lineWidth = 2
        road.position = CGPoint(x: size.width / 2, y: size.height / 2)
        road.zPosition = -10
        addChild(road)

        let dividerXs = [
            (lanePositions[0] + lanePositions[1]) * 0.5,
            (lanePositions[1] + lanePositions[2]) * 0.5,
        ]

        for dividerX in dividerXs {
            for index in 0..<12 {
                let mark = SKShapeNode(rectOf: CGSize(width: 4, height: 38), cornerRadius: 2)
                mark.fillColor = UIColor.white.withAlphaComponent(0.16)
                mark.strokeColor = .clear
                mark.position = CGPoint(
                    x: dividerX,
                    y: CGFloat(index) * (size.height / 10) - 30
                )
                mark.name = "roadMark"
                mark.zPosition = -5
                addChild(mark)
            }
        }
    }

    private func setupPlayer() {
        playerNode.removeFromParent()
        playerLane = 1
        preferredSafeLane = 1

        playerNode.fillColor = UIColor(white: 0.96, alpha: 1)
        playerNode.strokeColor = UIColor.black.withAlphaComponent(0.40)
        playerNode.lineWidth = 3
        playerNode.position = CGPoint(x: lanePositions[playerLane], y: size.height * Config.playerYRatio)
        playerNode.zPosition = 20
        playerNode.name = "player"

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 40, height: 50))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.player
        body.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.candy
        body.collisionBitMask = 0
        playerNode.physicsBody = body

        let leftEye = SKShapeNode(circleOfRadius: 5)
        leftEye.fillColor = .black
        leftEye.strokeColor = .clear
        leftEye.position = CGPoint(x: -10, y: 10)
        leftEye.zPosition = 1
        playerNode.addChild(leftEye)

        let rightEye = SKShapeNode(circleOfRadius: 5)
        rightEye.fillColor = .black
        rightEye.strokeColor = .clear
        rightEye.position = CGPoint(x: 10, y: 10)
        rightEye.zPosition = 1
        playerNode.addChild(rightEye)

        addChild(playerNode)
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver else { return }

        if EventManager.hasEnded(.halloween2026) {
            finishGame()
            return
        }

        guard let previousUpdateTime else {
            self.previousUpdateTime = currentTime
            return
        }

        var deltaTime = currentTime - previousUpdateTime
        self.previousUpdateTime = currentTime

        // 復帰直後などの巨大deltaで障害物が飛ばないように抑制。
        deltaTime = min(max(0, deltaTime), 0.05)

        if countdownRemaining > 0 {
            countdownRemaining = max(0, countdownRemaining - deltaTime)
            reportCountdownIfNeeded()
            return
        }

        if lastReportedCountdown != 0 {
            lastReportedCountdown = 0
            onCountdownChanged?(nil)
        }

        elapsedTime += deltaTime
        let difficulty = difficultyProgress
        let scrollSpeed = currentScrollSpeed(difficulty: difficulty)

        updateRoadMarks(deltaTime: deltaTime, speed: scrollSpeed)
        updateMovingNodes(deltaTime: deltaTime, speed: scrollSpeed)
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

        if integerDistance != lastReportedDistance {
            lastReportedDistance = integerDistance
            onDistanceChanged?(integerDistance)
        }
    }

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
            let afterStart = min(
                1,
                max(0, (elapsedTime - Config.doubleObstacleStartTime) /
                    (Config.maxDifficultyReachTime - Config.doubleObstacleStartTime))
            )
            doubleChance = 0.12 + ((Config.maximumDoubleObstacleChance - 0.12) * afterStart)
        }

        let shouldUseDoubleObstacle = Double.random(in: 0...1) < doubleChance

        if shouldUseDoubleObstacle {
            // 安全レーンは前回から最大1レーンだけ移動させる。
            // これにより左右タップ1回で必ず次の安全レーンへ到達できる。
            let candidates = [preferredSafeLane - 1, preferredSafeLane, preferredSafeLane + 1]
                .filter { (0...2).contains($0) }
            let nextSafeLane = candidates.randomElement() ?? preferredSafeLane
            preferredSafeLane = nextSafeLane

            for lane in 0...2 where lane != nextSafeLane {
                spawnObstacle(lane: lane, y: spawnY)
            }
        } else {
            // 単体障害物では、保証している安全レーンを塞がない。
            let blockedCandidates = (0...2).filter { $0 != preferredSafeLane }
            let blockedLane = blockedCandidates.randomElement() ?? 0
            spawnObstacle(lane: blockedLane, y: spawnY)

            // 難易度が上がるにつれて安全ルート自体も左右へ動かす。
            if difficulty > 0.20, Double.random(in: 0...1) < 0.30 {
                let candidates = [preferredSafeLane - 1, preferredSafeLane + 1]
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

        let node = SKShapeNode(rectOf: obstacleSize, cornerRadius: 14)
        node.fillColor = UIColor(red: 0.92, green: 0.25, blue: 0.18, alpha: 1)
        node.strokeColor = UIColor.orange.withAlphaComponent(0.85)
        node.lineWidth = 3
        node.position = CGPoint(x: lanePositions[lane], y: y)
        node.name = "obstacle"
        node.zPosition = 10
        node.userData = NSMutableDictionary()
        node.userData?["lane"] = lane

        let body = SKPhysicsBody(rectangleOf: CGSize(width: obstacleSize.width * 0.84, height: obstacleSize.height * 0.84))
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = PhysicsCategory.obstacle
        body.contactTestBitMask = PhysicsCategory.player
        body.collisionBitMask = 0
        node.physicsBody = body

        addChild(node)
    }

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

        enumerateChildNodes(withName: "obstacle") { node, _ in
            guard abs(node.position.y - y) < 120 else { return }
            if let lane = node.userData?["lane"] as? Int {
                blockedLanes.insert(lane)
            }
        }

        return (0...2).filter { !blockedLanes.contains($0) }
    }

    private func spawnCandy(lane: Int, y: CGFloat) {
        guard lanePositions.indices.contains(lane) else { return }

        let container = SKNode()
        container.position = CGPoint(x: lanePositions[lane], y: y)
        container.name = "candy"
        container.zPosition = 12
        container.userData = NSMutableDictionary()
        container.userData?["lane"] = lane

        let glow = SKShapeNode(circleOfRadius: 24)
        glow.fillColor = UIColor.systemPink.withAlphaComponent(0.22)
        glow.strokeColor = UIColor.white.withAlphaComponent(0.16)
        glow.lineWidth = 2
        container.addChild(glow)

        let label = SKLabelNode(text: "🍬")
        label.fontSize = 30
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -1)
        container.addChild(label)

        let body = SKPhysicsBody(circleOfRadius: 20)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = PhysicsCategory.candy
        body.contactTestBitMask = PhysicsCategory.player
        body.collisionBitMask = 0
        container.physicsBody = body

        addChild(container)
    }

    private func updateMovingNodes(deltaTime: TimeInterval, speed: CGFloat) {
        let deltaY = speed * CGFloat(deltaTime)

        for node in children where node.name == "obstacle" || node.name == "candy" {
            node.position.y -= deltaY
            if node.position.y < -100 {
                node.removeFromParent()
            }
        }
    }

    private func updateRoadMarks(deltaTime: TimeInterval, speed: CGFloat) {
        let deltaY = speed * CGFloat(deltaTime)
        let resetY = size.height + 80

        enumerateChildNodes(withName: "roadMark") { node, _ in
            node.position.y -= deltaY
            if node.position.y < -60 {
                node.position.y = resetY
            }
        }
    }

    private func reportCountdownIfNeeded(force: Bool = false) {
        guard countdownRemaining > 0 else {
            if force || lastReportedCountdown != 0 {
                lastReportedCountdown = 0
                onCountdownChanged?(nil)
            }
            return
        }

        let value = max(1, Int(ceil(countdownRemaining)))
        if force || value != lastReportedCountdown {
            lastReportedCountdown = value
            onCountdownChanged?(value)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameOver, countdownRemaining <= 0 else { return }
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
        let move = SKAction.moveTo(x: lanePositions[targetLane], duration: Config.laneMoveDuration)
        move.timingMode = .easeOut
        playerNode.run(move, withKey: "laneMove")

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func didBegin(_ contact: SKPhysicsContact) {
        guard !isGameOver else { return }

        let categories = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if categories == (PhysicsCategory.player | PhysicsCategory.obstacle) {
            finishGame()
            return
        }

        if categories == (PhysicsCategory.player | PhysicsCategory.candy) {
            let candyNode: SKNode?
            if contact.bodyA.categoryBitMask == PhysicsCategory.candy {
                candyNode = contact.bodyA.node
            } else {
                candyNode = contact.bodyB.node
            }

            candyNode?.removeFromParent()
            candyCount += 1
            onCandyChanged?(candyCount)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    private func finishGame() {
        guard !isGameOver else { return }
        isGameOver = true

        playerNode.removeAllActions()
        UINotificationFeedbackGenerator().notificationOccurred(.error)

        let result = HalloweenRunResult(
            distance: max(0, Int(distanceMeters.rounded(.down))),
            candyCount: max(0, candyCount)
        )

        onGameOver?(result)
    }
}
