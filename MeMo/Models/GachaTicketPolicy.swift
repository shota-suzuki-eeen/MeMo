import Foundation

enum GachaDrawPayment: Equatable {
    case normalTickets(Int)
    case steps(Int)

    var description: String {
        switch self {
        case .normalTickets(let count): return "チケット\(count)枚"
        case .steps(let amount): return "\(amount.formatted())歩"
        }
    }

    func canAfford(walletSteps: Int) -> Bool {
        switch self {
        case .normalTickets: return true
        case .steps(let amount): return amount > 0 && walletSteps >= amount
        }
    }
}

/// Regular-gacha pricing only. Event draws never call this policy.
enum GachaTicketPolicy {
    static let normalTicketID = "gachaTicket_nomal"
    static let specialTicketID = "gachaTicket_special"

    static func payment(drawCount: Int, normalTicketCount: Int, stepCost: Int) -> GachaDrawPayment {
        normalTicketCount >= drawCount && drawCount > 0 ? .normalTickets(drawCount) : .steps(stepCost)
    }
}
