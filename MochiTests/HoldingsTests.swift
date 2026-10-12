import Foundation
import Testing
@testable import Mochi

/// Home's "You have": the sources picked in Settings added up, nothing owed
/// taken off, and the cards due this round shown apart (decision #36).
struct HoldingsTests {
    static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func book() -> AppData {
        var a = AppData()
        a.wallets = [Wallet(name: "Bank", balance: 500_000), Wallet(name: "Cash", balance: 30_000),
                     Wallet(name: "Mercari", balance: 42_000, payoutTo: "Bank")]
        var gold = Investment(name: "Gold bar", kind: "gold", value: 400_000); gold.quantity = 20
        var btc = Investment(name: "Bitcoin", kind: "crypto", value: 460_000); btc.quantity = 0.035
        a.investments = [gold, btc, Investment(name: "NISA", kind: "tsumitate", value: 820_000)]
        a.pointWallets = [PointWallet(name: "PayPay", points: 5_000, spendAnywhere: true)]
        a.loans = [Loan(person: "Linh", direction: 1, amount: 20_000, currency: "JPY")]
        a.cards = [CreditCard(name: "Card", dueDay: 10, debt: 300_000, closingDay: 15)]
        return a
    }

    @Test func byDefaultAccountsMarketplaceGoldAndCoinsAreCounted() {
        let h = Finance.holdings(book())
        #expect(h.parts.map(\.source) == [.accounts, .marketplace, .gold, .crypto])
        #expect(h.parts.map(\.amount) == [530_000, 42_000, 400_000, 460_000])
        #expect(h.total == 1_432_000, "funds, points and money lent are left out until picked")
    }

    @Test func theSourcesPickedAreTheOnesCounted() {
        var a = book()
        a.holdingSources = ["accounts", "funds", "points", "lent"]
        let h = Finance.holdings(a)
        #expect(h.parts.map(\.source) == [.accounts, .funds, .points, .lent])
        #expect(h.total == 530_000 + 820_000 + 5_000 + 20_000)
        a.holdingSources = []
        #expect(Finance.holdings(a).total == 0)
    }

    @Test func aSourceHoldingNothingIsNotListed() {
        var a = book()
        a.investments = []
        #expect(Finance.holdings(a).parts.map(\.source) == [.accounts, .marketplace])
    }

    @Test func theCardsDueAreShownApartAndTakenOffWhatIsLeft() {
        // 6 Sep: the statement closed 15 Aug is debited 10 Sep.
        let today = Self.day(2026, 9, 6)
        let a = book()
        #expect(Finance.cardsDue(a, today: today) == 300_000)
        #expect(Finance.leftAfterCards(a, today: today) == 1_432_000 - 300_000)
        // Nothing owed is taken off what you have itself.
        #expect(Finance.holdings(a).total == 1_432_000)
    }
}
