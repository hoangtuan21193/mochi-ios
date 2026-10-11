import Foundation
import Testing
@testable import Mochi

/// Profit is shown with the points a trade earned, its cash part beside it;
/// only points that buy anything count in net worth; a channel can charge a
/// flat fee per sale on top of its rate.
struct PointsProfitTests {
    static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func aLensThatLostCashStillMadeMoneyWithItsPoints() {
        // CLAUDE.md's example: ¥785,266 paid, ¥94,328 of points back, ¥740,000 in hand.
        var a = AppData()
        a.channels = [SalesChannel(name: "Mercari", rate: 10)]
        var lens = Item(name: "Lens", boughtOn: Self.day(2026, 3, 1), buyPrice: 785_266, cardName: "",
                        pointsEarned: 94_328, estimatedPrice: 0, plannedChannel: "Mercari")
        lens.sale = SaleRecord(price: 822_222, channel: "Mercari", net: 740_000, date: Self.day(2026, 6, 1))
        a.items = [lens]
        let t = Finance.trade(lens, a)
        #expect(t.cash == -45_266)
        #expect(t.points == 94_328)
        #expect(t.total == 49_062)
        let year = Finance.profitWithPoints(a, for: .year(2026))
        #expect(year.total == 49_062)
        // The cash figures are untouched.
        #expect(Finance.summary(a, for: .year(2026)).profit == -45_266)
    }

    @Test func pointsThatBuyAnythingAreInNetWorthAndShopPointsAreNot() {
        var a = AppData()
        a.wallets = [Wallet(name: "Bank", balance: 100_000)]
        a.pointWallets = [PointWallet(name: "PayPay points", points: 41_300, spendAnywhere: true),
                          PointWallet(name: "MapCamera points", points: 52_800)]
        let n = Finance.netWorth(a, today: Self.day(2026, 10, 1))
        #expect(n.points == 41_300)
        #expect(n.total == 141_300)
        // Never cash, never Safe to spend.
        #expect(Finance.cashNow(a) == 100_000)
        #expect(Finance.spendableCash(a) == 100_000)
    }

    @Test func aPointCanBeWorthLessThanAYen() {
        let w = PointWallet(name: "Store", points: 1_000, spendAnywhere: true, yenPerPoint: 0.5)
        #expect(Finance.value(ofPoints: 1_000, in: w) == 500)
    }

    @Test func aFlatFeePerSaleComesOffThePayout() {
        var a = AppData()
        a.channels = [SalesChannel(name: "eBay", rate: 10, fixedFee: 100)]
        a.defaultShippingFee = 0
        let item = Item(name: "Thing", boughtOn: Self.day(2026, 1, 1), buyPrice: 5_000, cardName: "",
                        estimatedPrice: 10_000, plannedChannel: "eBay", shippingFee: 0)
        #expect(Finance.netProceeds(item, channelName: "eBay", a) == 8_900)
        #expect(Finance.commission(item, channelName: "eBay", a) == 1_100)
    }

    @Test func theThingsForSaleComeToTheirTradesAddedUp() {
        var a = AppData()
        a.channels = [SalesChannel(name: "Mercari", rate: 10)]
        a.defaultShippingFee = 1_000
        let lens = Item(name: "Lens", boughtOn: Self.day(2026, 3, 1), buyPrice: 200_000, cardName: "",
                        pointsEarned: 8_000, estimatedPrice: 230_000, plannedChannel: "Mercari")
        let kept = Item(name: "Chair", keep: true, boughtOn: Self.day(2026, 3, 1), buyPrice: 50_000, cardName: "",
                        estimatedPrice: 30_000, plannedChannel: "Mercari")
        a.items = [lens, kept]
        let o = Finance.resaleOutlook(a)
        // Only the lens is for sale: 230,000 less 10% and postage is 206,000.
        #expect(o.paid == 200_000)
        #expect(o.pointsBack == 8_000)
        #expect(o.wouldBring == 206_000)
        #expect(o.ifAllSold.cash == 6_000)
        #expect(o.ifAllSold.points == 8_000)
        #expect(o.ifAllSold.total == 14_000)
    }
}
