import Foundation
import Testing
@testable import Mochi

/// The Profit screen: a year's selling month by month, with points, and the
/// trades that made and lost the most.
struct ProfitByMonthTests {
    let day = PointsProfitTests.day

    func sold(_ name: String, paid: Int, net: Int, points: Int = 0, on date: Date) -> Item {
        var i = Item(name: name, boughtOn: day(2026, 1, 1), buyPrice: paid, cardName: "",
                     pointsEarned: points, estimatedPrice: 0, plannedChannel: "")
        i.sale = SaleRecord(price: net, channel: "", net: net, date: date)
        return i
    }

    func book() -> AppData {
        var a = AppData()
        a.items = [
            sold("Lens", paid: 100_000, net: 120_000, points: 2_000, on: day(2026, 3, 10)),
            sold("Body", paid: 200_000, net: 190_000, points: 4_000, on: day(2026, 3, 20)),
            sold("Flash", paid: 10_000, net: 15_000, on: day(2026, 7, 2)),
            sold("Old", paid: 5_000, net: 9_000, on: day(2025, 12, 31)),
        ]
        var held = Item(name: "Held", boughtOn: day(2026, 2, 1), buyPrice: 50_000, cardName: "",
                        estimatedPrice: 60_000, plannedChannel: "")
        held.keep = false
        a.items.append(held)
        return a
    }

    @Test func aYearIsTwelveMonthsWithEmptyOnesAtZero() {
        let months = Finance.profitByMonth(book(), year: 2026)
        #expect(months.count == 12)
        #expect(months[2] == .init(month: 3, result: .init(cash: 10_000, points: 6_000), sold: 2))
        #expect(months[6].result.total == 5_000)
        #expect(months[0].result.total == 0 && months[0].sold == 0)
        // The months add up to the year.
        #expect(months.reduce(0) { $0 + $1.result.total } == Finance.profitWithPoints(book(), for: .year(2026)).total)
    }

    @Test func theBestAndWorstOfAYearLeaveOtherYearsAndUnsoldThingsOut() {
        let e = Finance.extremeTrades(book(), year: 2026)
        #expect(e.best.map(\.item.name) == ["Lens", "Flash"])
        #expect(e.worst.map(\.item.name) == ["Body"])
        #expect(e.worst[0].result == .init(cash: -10_000, points: 4_000))
    }

    @Test func theYearsOfferedAreTheOnesSomethingSoldInAndThisOne() {
        #expect(Finance.saleYears(book(), today: day(2027, 2, 1)) == [2025, 2026, 2027])
        #expect(Finance.saleYears(AppData(), today: day(2026, 10, 1)) == [2026])
    }
}
