import Foundation

@main
enum HalloweenRunHUDLayoutTests {
    static func main() {
        var assertions = 0
        func check(_ value: Bool, _ message: String) {
            assertions += 1
            guard value else { fatalError(message) }
        }
        for (width, height) in [(320.0, 568.0), (375, 667), (393, 852), (402, 874), (430, 932)] {
            for top in [0.0, 20, 59, 62] {
                let hud = HalloweenRunHUDLayout(width: width, height: height, safeTop: top)
                check(hud.titleY + 7 < height - top, "title clears safe top")
                check(hud.titleY - hud.valueY > 20 && hud.valueY - hud.levelY > 35, "primary rows do not overlap")
                check(hud.pumpkinCenters.count == 5 && hud.pumpkinCenters.first! > 18, "five pumpkin silhouettes have matching centers")
                check(hud.pumpkinCenters.last! + 9 < width - 150, "pumpkins clear right candy counter at small widths")
                check(hud.pumpkinY - 9 > height - hud.headerClearance, "pumpkins stay in header")
                check(hud.candyCenterX == width / 2 && hud.candyY < hud.valueY - 35, "bonus collection target is upper center below time")
                let playerY = height * 0.18
                for level in 1...5 {
                    let speed = Halloween2026Configuration.scrollSpeed(forLevel: level, sceneHeight: height,
                        playerY: playerY, collisionHalfHeight: 55, headerClearance: hud.headerClearance)
                    let travel = height - hud.headerClearance - playerY - 55
                    check(travel / speed >= Halloween2026Configuration.minimumObstacleReactionTime - 0.0001, "safe-area-aware HUD retains minimum reaction time")
                }
            }
        }
        print("PASS: \(assertions) Halloween HUD/safe-area/reaction assertions")
    }
}
