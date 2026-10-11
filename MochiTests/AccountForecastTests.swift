import Foundation
import Testing
@testable import Mochi

/// The forecast walked account by account: a card debited from an account
/// that runs short is a move to make, even when the household total covers
/// it; and a marketplace balance pays nothing until it is withdrawn.
/// The book is the one the design draws: 1 October 2026.
struct AccountForecastTests {
    static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }
    let today = day(2026, 10, 1)

    func book() -> AppData {
        var a = AppData()
        a.wallets = [Wallet(name: "SMBC", balance: 182_000),
                     Wallet(name: "MUFG", balance: 31_000),
                     Wallet(name: "Mercari", balance: 86_400, payoutTo: "SMBC", payoutFee: 200, payoutDays: 3),
                     Wallet(name: "Cash", balance: 12_000)]
        a.cards = [CreditCard(name: "JCB Card W", dueDay: 10, debt: 96_200, closingDay: 15, payFrom: "MUFG"),
                   CreditCard(name: "Rakuten Card", dueDay: 27, debt: 168_500, closingDay: 31, payFrom: "SMBC")]
        a.recurring = [Recurring(name: "Salary", amount: 380_000, kind: "income", category: "salary", day: 25, paidBy: "SMBC"),
                       Recurring(name: "Rent", amount: 98_000, kind: "expense", category: "rent", day: 27, paidBy: "SMBC")]
        return a
    }
    var end: Date { Self.day(2026, 10, 31) }

    @Test func aShortAccountGetsAMoveFromOneWithRoomToSpare() {
        let moves = Finance.transfersNeeded(book(), to: end, today: today)
        #expect(moves.count == 1)
        let m = moves[0]
        #expect(m.from == "SMBC" && m.to == "MUFG")
        // ¥96,200 against ¥31,000 is ¥65,200 short, rounded up to the thousand.
        #expect(m.shortBy == 65_200)
        #expect(m.amount == 66_000)
        #expect(m.leftAfter == 800)
        // JCB's 10th is a Saturday and the 12th Sports Day: it leaves Tue 13 Oct,
        // so the move has to be made by Friday the 9th.
        #expect(m.debitDate == Self.day(2026, 10, 13))
        #expect(m.deadline == Self.day(2026, 10, 9))
        #expect(m.debitLabel == "JCB Card W")
    }

    @Test func theHouseholdTotalAloneWouldHaveSaidAllWasFine() {
        let days = Finance.paymentsDue(book(), to: end, today: today)
        #expect(Finance.shortfall(days) == nil)
    }

    @Test func noMoveOnceTheAccountsAreBalanced() {
        var a = book()
        a.wallets[0].balance -= 66_000
        a.wallets[1].balance += 66_000
        #expect(Finance.transfersNeeded(a, to: end, today: today).isEmpty)
    }

    /// Sunday the 11th: Friday the 9th was the business day to move by, so
    /// the move is today and says it is late, not "before the weekend".
    @Test func aMovePastItsBusinessDayIsToday() {
        let m = Finance.transfersNeeded(book(), to: end, today: Self.day(2026, 10, 11)).first { $0.to == "MUFG" }
        #expect(m?.deadline == Self.day(2026, 10, 11))
        #expect(m?.lastBusinessDay == Self.day(2026, 10, 9))
        #expect(m?.isLate == true)
        #expect(Finance.transfersNeeded(book(), to: end, today: today).first?.isLate == false)
    }

    @Test func theCardRoundNamesTheShortAccountAndItsMove() {
        guard case .accountShort(let s, let move) = Finance.cardRound(book(), to: end, today: today) else {
            Issue.record("MUFG cannot pay JCB on the 13th"); return
        }
        #expect(s.account == "MUFG" && s.shortBy == 65_200 && s.date == Self.day(2026, 10, 13))
        #expect(move?.from == "SMBC")
    }

    /// The bug this guards: with no account able to spare the gap there was
    /// no move to suggest, and Home said every account could pay.
    @Test func anAccountWithNothingToMoveFromIsStillShort() {
        var a = book()
        a.wallets[0].balance = 20_000
        a.wallets[2].balance = 0
        #expect(Finance.transfersNeeded(a, to: end, today: today).filter { $0.to == "MUFG" }.isEmpty)
        guard case .accountShort(let s, let move) = Finance.cardRound(a, to: end, today: today) else {
            Issue.record("MUFG is short with nothing to cover it"); return
        }
        #expect(s.account == "MUFG" && s.shortBy == 65_200)
        #expect(move == nil)
    }

    /// A card with nowhere set to pay from is in no account's walk, so only
    /// the household total can say it cannot be paid.
    @Test func aCardWithNoAccountIsCheckedAgainstTheHousehold() {
        var a = book()
        a.cards[0].payFrom = nil
        a.wallets = [Wallet(name: "SMBC", balance: 40_000)]
        a.recurring = []
        a.cards.removeLast()
        guard case .householdShort(let amount, let from) = Finance.cardRound(a, to: end, today: today) else {
            Issue.record("¥40,000 cannot pay ¥96,200"); return
        }
        #expect(amount == 56_200)
        #expect(from == Self.day(2026, 10, 13))
    }

    @Test func theCardRoundIsCoveredOnceTheAccountsAreBalanced() {
        var a = book()
        a.wallets[0].balance -= 66_000
        a.wallets[1].balance += 66_000
        #expect(Finance.cardRound(a, to: end, today: today) == .covered)
    }

    @Test func aMarketplaceBalanceArrivesAsAWithdrawalInTime() {
        let a = book()
        let payout = Finance.events(a, from: today, to: end).first { $0.kind == .payout }
        // Three business days before Tue 27 Oct, landing the day before: Wed 21.
        #expect(payout?.date == Self.day(2026, 10, 21))
        #expect(payout?.amount == 86_200)
        #expect(payout?.account == "SMBC")
    }

    @Test func aMarketplaceBalanceIsNotCashForBills() {
        #expect(Finance.spendableCash(book()) == 225_000)
        #expect(Finance.cashNow(book()) == 311_400)
    }

    @Test func cardsDueTheSameDayAreOneLine() {
        var a = book()
        a.cards.append(CreditCard(name: "SMBC Card", dueDay: 10, debt: 20_000, closingDay: 15, payFrom: "SMBC"))
        let days = Finance.cardDays(a, to: end, today: today)
        // JCB and SMBC Card both on Tue 13 Oct (the 10th is a Saturday, the 12th Sports Day).
        #expect(days.first?.date == Self.day(2026, 10, 13))
        #expect(Set(days.first?.cards ?? []) == ["JCB Card W", "SMBC Card"])
        #expect(days.count == Set(days.map(\.date)).count)
        let debits = Finance.events(a, from: today, to: end).filter { $0.kind == .card && $0.amount < 0 }
        #expect(days.reduce(0) { $0 + $1.amount } == -debits.reduce(0) { $0 + $1.amount })
    }
}

/// Safe to spend looks as far as the cards' nearest statements: here JCB on
/// the 13th and Rakuten on the 27th, with the salary of the 23rd before it.
struct SafeToSpendCardsTests {
    let base = AccountForecastTests()

    @Test func theHorizonIsTheLastOfTheNearestCardDebits() {
        let a = base.book()
        #expect(Finance.Horizon.cards.end(a, today: base.today) == AccountForecastTests.day(2026, 10, 27))
    }

    @Test func itCountsTheSalaryAndTheMarketplaceThatLandBeforeIt() {
        var a = base.book()
        a.safetyBuffer = 30_000
        let s = Finance.safeToSpend(a, horizon: .cards, today: base.today)
        #expect(s.cash == 225_000)
        #expect(s.incoming == 380_000 + 86_200)
        #expect(s.cards == 96_200 + 168_500)
        #expect(s.bills == 98_000)
        // 225,000 + 466,200 − 264,700 − 98,000 − 30,000
        #expect(s.total == 298_500)
    }

    @Test func aNewBookUsesTheCardsAndAnOldOneKeepsItsThirtyDays() {
        // A new book starts on the cards. A book written before the field
        // existed keeps the 30 days it was read with (CompatibilityTests).
        #expect(AppData().horizon == "cards")
        #expect(Finance.Horizon.stored("cards") == .cards)
        #expect(Finance.Horizon.stored("30d") == .days(30))
    }
}

struct NetWorthThisYearTests {
    @Test func oneReadingIsNotAChange() {
        var a = AccountForecastTests().book()
        a.snapshots = [CashSnapshot(date: AccountForecastTests.day(2026, 1, 3), cash: 0, cardDebt: 0, installmentDebt: 0, netWorth: 100_000)]
        #expect(Finance.netWorthChangeThisYear(a, today: AccountForecastTests.day(2026, 10, 1)) == nil)
    }

    @Test func theChangeIsFromTheYearsFirstReading() {
        var a = AccountForecastTests().book()
        let today = AccountForecastTests.day(2026, 10, 1)
        let now = Finance.netWorth(a, today: today).total
        a.snapshots = [CashSnapshot(date: AccountForecastTests.day(2025, 12, 2), cash: 0, cardDebt: 0, installmentDebt: 0, netWorth: 0),
                       CashSnapshot(date: AccountForecastTests.day(2026, 1, 3), cash: 0, cardDebt: 0, installmentDebt: 0, netWorth: now - 312_000),
                       CashSnapshot(date: AccountForecastTests.day(2026, 9, 1), cash: 0, cardDebt: 0, installmentDebt: 0, netWorth: now - 10_000)]
        let c = Finance.netWorthChangeThisYear(a, today: today)
        #expect(c?.change == 312_000)
        #expect(c?.readings == 2)
    }
}
