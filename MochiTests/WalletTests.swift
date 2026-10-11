import Foundation
import Testing
@testable import Mochi

/// What the Wallet tab says beside each account, card and plan — the book
/// the Wallet artboard draws, on 1 October 2026.
struct WalletTests {
    let today = AccountForecastTests.day(2026, 10, 1)
    func book() -> AppData { AccountForecastTests().book() }

    @Test func eachAccountSaysWhatItIsFor() {
        let notes = Finance.accountNotes(book(), today: today)
        #expect(notes.map(\.wallet.name) == ["SMBC", "Mercari", "MUFG", "Cash"])
        let smbc = notes[0]
        #expect(smbc.incomes == ["Salary"])
        #expect(smbc.pays == ["Rakuten Card"])
        #expect(smbc.shortBy == nil)
    }

    @Test func theShortAccountSaysByHowMuchAndWhenToMove() {
        let mufg = Finance.accountNotes(book(), today: today).first { $0.wallet.name == "MUFG" }!
        #expect(mufg.pays == ["JCB Card W"])
        #expect(mufg.shortBy == 65_200)
        #expect(mufg.shortOn == AccountForecastTests.day(2026, 10, 13))
        #expect(mufg.moveBy == AccountForecastTests.day(2026, 10, 9))
    }

    @Test func aMarketplaceSaysTheLastDayToWithdraw() {
        let mercari = Finance.accountNotes(book(), today: today).first { $0.wallet.name == "Mercari" }!
        #expect(mercari.withdrawBy == AccountForecastTests.day(2026, 10, 21))
        #expect(mercari.forDebit == AccountForecastTests.day(2026, 10, 27))
    }

    @Test func cardsWithAStatementToPayComeFirstSoonestFirst() {
        let lines = Finance.cardLines(book(), today: today)
        #expect(lines.map(\.card.name) == ["JCB Card W", "Rakuten Card"])
        #expect(lines[0].statement == 96_200)
    }

    @Test func aPlanDebitsInsideTheMonth() {
        var a = book()
        let plan = InstallmentSchedule(months: 18, firstAmount: 26_000, monthly: 26_000, startYear: 2026, startMonth: 6, payDay: 27)
            .plan(name: "Z8")!
        a.installments = [plan]
        let october = Calendar.current.dateInterval(of: .month, for: today)!
        #expect(Finance.installmentDebits(a, in: october) == 26_000)
    }
}
