import Foundation
import Testing
@testable import Mochi

/// The Net worth screen's line: monthly readings in the chosen stretch, and
/// today's figure against the first of them.
struct NetWorthTests {
    static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }
    let today = day(2026, 10, 4)

    func book() -> AppData {
        var a = AppData()
        a.wallets = [Wallet(name: "Bank", balance: 1_000_000)]
        a.snapshots = [
            CashSnapshot(date: Self.day(2025, 11, 2), cash: 0, cardDebt: 0, installmentDebt: 0, netWorth: 700_000),
            CashSnapshot(date: Self.day(2026, 1, 3), cash: 0, cardDebt: 0, installmentDebt: 0, netWorth: 800_000),
            CashSnapshot(date: Self.day(2026, 3, 1), cash: 0, cardDebt: 0, installmentDebt: 0, netWorth: 850_000),
            // Two in one month: the later is the truer reading.
            CashSnapshot(date: Self.day(2026, 9, 1), cash: 0, cardDebt: 0, installmentDebt: 0, netWorth: 900_000),
            CashSnapshot(date: Self.day(2026, 9, 20), cash: 0, cardDebt: 0, installmentDebt: 0, netWorth: 950_000),
        ]
        return a
    }

    @Test func thisYearCountsFromJanuary() {
        let s = Finance.netWorthSeries(book(), .year, today: today)
        #expect(s.readings == 3)
        #expect(s.points.last?.value == 950_000)
        #expect(s.change == 1_000_000 - 800_000)
        #expect(Calendar.current.component(.month, from: s.since!) == 1)
    }

    @Test func twelveMonthsReachesBackIntoLastYear() {
        let s = Finance.netWorthSeries(book(), .twelveMonths, today: today)
        #expect(s.readings == 4)
        #expect(s.change == 300_000)
    }

    @Test func oneReadingIsAPointNotAChange() {
        var a = book()
        a.snapshots = [a.snapshots![0]]
        #expect(Finance.netWorthSeries(a, .all, today: today).change == nil)
    }
}
