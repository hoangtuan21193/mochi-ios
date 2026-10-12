import Foundation
import Testing
@testable import Mochi

/// Gold at the world price for its weight and purity, coins at the source's
/// price, both in the book's money; looked up at most daily (gold) and hourly
/// (coins), never when switched off.
struct PricesTests {
    let gold = #"{"currency":"USD","currencySymbol":"$","exchangeRate":1.0,"name":"Gold","price":4195.6,"symbol":"XAU","updatedAt":"2026-10-11T21:13:08Z"}"#
    let coins = #"{"bitcoin":{"jpy":13217681},"ethereum":{"jpy":400754.5}}"#

    @Test func goldIsTheWorldPriceForItsWeightAndPurity() throws {
        let usdPerOunce = try #require(Prices.parseGold(Data(gold.utf8)))
        #expect(usdPerOunce == 4195.6)
        // ¥1 = $0.0068: a gram of 24K is 4195.6 / 31.1035 × 0.9999 / 0.0068.
        let gram = try #require(Finance.goldUnitPrice(usdPerOunce: usdPerOunce, unit: "gram", kind: "24K", usdRate: 0.0068))
        #expect(Int(gram.rounded()) == 19_835)
        // A chỉ is 3.75 g; 18K is three quarters gold.
        let chi18 = try #require(Finance.goldUnitPrice(usdPerOunce: usdPerOunce, unit: "chi", kind: "18K", usdRate: 0.0068))
        #expect(abs(chi18 - gram / 0.9999 * 0.75 * 3.75) < 0.001)
        // A book kept in dollars: an ounce of 24K is the world price.
        let oz = try #require(Finance.goldUnitPrice(usdPerOunce: usdPerOunce, unit: "oz", kind: "24K", usdRate: 1))
        #expect(abs(oz - 4195.6 * 0.9999) < 0.001)
        #expect(Finance.goldUnitPrice(usdPerOunce: usdPerOunce, unit: "tael", kind: "24K", usdRate: 1) == nil)
    }

    @Test func aReplyThatIsNotGoldIsNotRead() {
        #expect(Prices.parseGold(Data(#"{"symbol":"XAG","currency":"USD","price":50}"#.utf8)) == nil)
        #expect(Prices.parseGold(Data("Too many requests".utf8)) == nil)
    }

    @Test func coinsArePricedInTheBooksMoney() {
        let p = Prices.parseCoins(Data(coins.utf8), currency: "JPY")
        #expect(p["bitcoin"] == 13_217_681)
        #expect(p["ethereum"] == 400_754.5)
        #expect(Prices.parseCoins(Data(coins.utf8), currency: "VND").isEmpty, "a reply in yen is not đồng")
    }

    @Test func aSearchFindsCoinsByName() {
        let reply = #"{"coins":[{"id":"pepe","name":"Pepe","symbol":"pepe","market_cap_rank":30}],"exchanges":[]}"#
        #expect(Prices.parseSearch(Data(reply.utf8)) == [Prices.Coin(id: "pepe", symbol: "PEPE", name: "Pepe")])
    }

    @Test func aHoldingIsWorthItsQuantityAtThePrice() {
        var btc = Investment(name: "Bitcoin", kind: "crypto", contributed: 480_000, value: 0)
        btc.quantity = 0.035; btc.unit = "BTC"; btc.coinID = "bitcoin"
        let day = Date(timeIntervalSince1970: 1_791_700_000)
        let p = Finance.priced(btc, unitPrice: 15_820_000, at: day)
        #expect(p.value == 553_700)
        #expect(p.pricedAt == day && p.unitPrice == 15_820_000)
        // A NISA account typed from the broker is not touched.
        let nisa = Investment(name: "NISA", kind: "tsumitate", value: 820_000)
        #expect(Finance.priced(nisa, unitPrice: 1, at: day).value == 820_000)
    }

    @Test func pricesAreLookedUpDailyForGoldHourlyForCoinsAndNeverWhenOff() {
        let now = Date(timeIntervalSince1970: 1_791_700_000)
        var a = AppData.empty
        #expect(Finance.pricesDue(a, now: now) == (false, false), "nothing held")
        var g = Investment(name: "SJC", kind: "gold", value: 0); g.quantity = 5; g.unit = "chi"; g.goldKind = "24K"
        var c = Investment(name: "BTC", kind: "crypto", value: 0); c.quantity = 0.1; c.coinID = "bitcoin"
        g.pricedAt = now.addingTimeInterval(-2 * 3600); c.pricedAt = now.addingTimeInterval(-2 * 3600)
        a.investments = [g, c]
        #expect(Finance.pricesDue(a, now: now) == (false, true))
        a.investments?[0].pricedAt = nil
        #expect(Finance.pricesDue(a, now: now) == (true, true))
        a.lookUpPrices = false
        #expect(Finance.pricesDue(a, now: now) == (false, false))
    }

    @Test func anInvestmentWrittenBeforeGoldAndCoinsStillOpens() throws {
        let old = #"{"id":"i1","name":"NISA","kind":"tsumitate","contributed":700000,"value":820000}"#
        let i = try JSONDecoder().decode(Investment.self, from: Data(old.utf8))
        #expect(i.value == 820_000 && i.quantity == nil && i.coinID == nil && i.pricedAt == nil)
    }
}
