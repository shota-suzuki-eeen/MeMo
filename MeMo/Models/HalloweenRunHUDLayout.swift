import Foundation

/// Scene coordinates, separated into a title/value row and a level/candy row.
struct HalloweenRunHUDLayout {
    let width: Double
    let height: Double
    let safeTop: Double

    var topInset: Double { max(20, safeTop) }
    var valueY: Double { height - topInset - 42 }
    var titleY: Double { valueY + 25 }
    var levelY: Double { valueY - 43 }
    var pumpkinY: Double { levelY - 23 }
    var candyY: Double { valueY - 58 }
    var headerClearance: Double { topInset + 126 }
    var candyCenterX: Double { width / 2 }
    var pumpkinCenters: [Double] { (0..<5).map { 26 + Double($0) * 21 } }
}
