import Foundation

@main
enum GachaTicketPolicyTests {
    static func main() {
        var assertions = 0
        func check(_ value: Bool, _ message: String) {
            assertions += 1
            guard value else { fatalError(message) }
        }
        check(GachaTicketPolicy.normalTicketID == "gachaTicket_nomal" && GachaTicketPolicy.specialTicketID == "gachaTicket_special", "released ticket IDs stay unchanged")
        for (count, cost) in [(1, 500), (10, 5000)] {
            for tickets in [-1, 0, 1, 2, 9, 10, 11, Int.max] {
                let payment = GachaTicketPolicy.payment(drawCount: count, normalTicketCount: tickets, stepCost: cost)
                check(payment == (tickets >= count ? .normalTickets(count) : .steps(cost)), "ticket priority and all-or-nothing count threshold")
                for wallet in [0, cost-1, cost, cost+1, 10_000] {
                    check(payment.canAfford(walletSteps: wallet) == (tickets >= count || wallet >= cost), "wallet and ticket affordability independent")
                }
            }
        }
        check(GachaTicketPolicy.payment(drawCount: 10, normalTicketCount: 9, stepCost: 5000) == .steps(5000), "nine tickets never combine with steps")
        check(GachaTicketPolicy.payment(drawCount: 1, normalTicketCount: 9, stepCost: 500) == .normalTickets(1), "same inventory permits ticket single")
        check(GachaTicketPolicy.payment(drawCount: 10, normalTicketCount: 10, stepCost: 5000) == .normalTickets(10), "ten threshold permits tickets without steps")
        check(!GachaDrawPayment.steps(0).canAfford(walletSteps: 1000) && !GachaDrawPayment.steps(-1).canAfford(walletSteps: 1000), "invalid step charges cannot be admitted")
        print("PASS: \(assertions) normal-gacha ticket/payment assertions")
    }
}
