import Foundation
import Testing
@testable import Mochi

/// Transactions › Spending: the period, its four figures, the split by
/// place, and the income followed to where it went.
struct SpendingTests {
    static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }
    let today = day(2026, 10, 10)

    func spend(_ amount: Int, _ d: Date, category: String = "Groceries", place: String? = nil) -> Transaction {
        var t = Transaction(date: d, amount: -amount, kind: .spend, account: "Bank", merchant: "Shop", category: category)
        t.placeName = place
        return t
    }

    func book() -> AppData {
        var a = AppData()
        a.wallets = [Wallet(name: "Bank", balance: 500_000)]
        a.recurring = [Recurring(name: "Salary", amount: 300_000, kind: "income", category: "salary", day: 25, paidBy: "Bank")]
        a.transactions = [
            Transaction(date: Self.day(2026, 9, 25), amount: 300_000, kind: .income, account: "Bank", merchant: "Salary"),
            spend(85_000, Self.day(2026, 9, 27), category: "Housing", place: "Home"),
            spend(28_000, Self.day(2026, 10, 2), place: "Sunmart"),
            spend(12_000, Self.day(2026, 10, 3), category: "Eating out", place: "Sunmart"),
            spend(9_000, Self.day(2026, 10, 4), category: "Transport"),
            spend(6_000, Self.day(2026, 10, 5), category: "Fun"),
            spend(20_000, Self.day(2026, 9, 10)),
        ]
        return a
    }

    @Test func aPayPeriodRunsPaydayToPaydayAndStepsBackOne() {
        let a = book()
        let i = Finance.spendingInterval(a, .payPeriod, containing: today)
        #expect(Calendar.current.component(.day, from: i.start) == 25)
        #expect(Calendar.current.component(.month, from: i.start) == 9)
        let before = Finance.previousSpendingInterval(a, .payPeriod, before: i)
        #expect(Calendar.current.component(.month, from: before.start) == 8)
        #expect(Finance.nextSpendingInterval(a, .payPeriod, after: i, today: today) == nil)
    }

    @Test func theFourFiguresOfAMonthSoFar() {
        let s = Finance.spendingSummary(book(), .month, containing: today, by: .categories, today: today)
        #expect(s.spent == 55_000)
        // September had ¥105,000: this October is ¥50,000 lighter.
        #expect(s.change == -50_000)
        #expect(s.days == 10)
        #expect(s.perDay == 5_500)
        #expect(s.largest?.name == "Groceries")
        // 28,000 of 55,000 is 50.9%: rounded, not cut.
        #expect(s.largest?.percent == 51)
    }

    @Test func nothingBeforeMeansNoChange() {
        let s = Finance.spendingSummary(book(), .month, containing: Self.day(2026, 9, 1), by: .categories, today: today)
        #expect(s.change == nil)
        #expect(s.days == 30)
    }

    @Test func placesGatherByTheNameKept() {
        let s = Finance.spendingSummary(book(), .month, containing: today, by: .places, today: today)
        #expect(s.shares.map(\.name) == ["Sunmart", "No place kept"])
        #expect(s.shares.first?.amount == 40_000)
    }

    @Test func theIncomeIsFollowedToWhatWasLeft() {
        let a = book()
        let s = Finance.spendingSummary(a, .payPeriod, containing: today, by: .categories, today: today)
        let f = Finance.incomeFlow(a, in: s.interval, shares: s.shares)
        #expect(f.income == 300_000)
        #expect(f.top.map(\.name) == ["Housing", "Groceries", "Eating out"])
        #expect(f.rest?.amount == 15_000)
        #expect(f.restCount == 2)
        #expect(f.leftOver == 300_000 - 140_000)
        #expect(f.fromSavings == 0)
    }

    @Test func spendingMoreThanCameInComesFromWhatYouHad() {
        let a = book()
        let s = Finance.spendingSummary(a, .month, containing: today, by: .categories, today: today)
        let f = Finance.incomeFlow(a, in: s.interval, shares: s.shares)
        #expect(f.income == 0)
        #expect(f.leftOver == 0)
        #expect(f.fromSavings == 55_000)
    }

    @Test func aColumnFigureIsShort() {
        #expect(Currency.jpy.short(85_000) == "85k")
        #expect(Currency.jpy.short(168_420) == "168k")
        #expect(Currency.jpy.short(1_250_000) == "1.3m" || Currency.jpy.short(1_250_000) == "1.2m")
        #expect(Currency.jpy.short(800) == "800")
    }
}
