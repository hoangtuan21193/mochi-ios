import Foundation
import Testing
@testable import Mochi

/// The Shortcuts Wallet automation passes Amount as the phone formats it.
/// Every region's way of writing twelve hundred yen has to book ¥1,200.
struct TapAmountTests {
    @Test(arguments: ["¥1,200", "￥1,200", "1,200円", "JP¥1,200", "1.200 ¥", "1 200 ¥", "¥1,200.00", "1200", "-¥1,200", "１，２００円"])
    func everyRegionsFormatReadsAsTheSameYen(_ text: String) {
        #expect(CardEmailParser.tapAmount(text) == 1200)
    }

    @Test func aDecimalPartIsRounded() {
        #expect(CardEmailParser.tapAmount("$12.50") == 13)
        #expect(CardEmailParser.tapAmount("12,4 €") == 12)
    }

    @Test func noFigureBooksNothing() {
        #expect(CardEmailParser.tapAmount("") == nil)
        #expect(CardEmailParser.tapAmount("¥") == nil)
        #expect(CardEmailParser.tapAmount("¥0") == nil)
    }
}

/// What currency a tap was in, from the same Amount text.
struct TapCurrencyTests {
    @Test(arguments: [
        ("US$12.50", "USD"), ("$12.50", "USD"), ("USD 12.50", "USD"), ("12,50 €", "EUR"),
        ("₫150.000", "VND"), ("150.000 ₫", "VND"), ("150.000 đ", "VND"), ("NT$300", "TWD"),
        ("CN¥50", "CNY"), ("₩15,000", "KRW"), ("HK$88", "HKD"), ("£9.99", "GBP"),
        ("¥1,200", "JPY"), ("１，２００円", "JPY"),
    ])
    func theMarkNamesTheCurrency(_ text: String, _ code: String) {
        #expect(CardEmailParser.tapCurrency(text) == code)
    }

    @Test func aBareFigureSaysNothing() {
        #expect(CardEmailParser.tapCurrency("1200") == nil)
    }

    @Test(arguments: [("₫150.000", 150_000), ("12,50 €", 13), ("NT$300", 300), ("₩15,000", 15_000)])
    func theFigureIsReadWithItsCurrency(_ text: String, _ paid: Int) {
        #expect(CardEmailParser.tapAmount(text) == paid)
    }

    @Test func aForeignTapIsMatchedOnWhatWasPaidNotTheYen() {
        var a = AppData.empty
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 12))!
        var t = Transaction(date: day, amount: -1_800, kind: .spend, account: "Rakuten Card", merchant: "Starbucks", source: .applePay)
        t.currency = "USD"; t.foreignAmount = 12.5; t.rate = 0.0068
        a.transactions = [t]
        #expect(Finance.sameSpend(a, paid: 12.5, currency: "USD", account: "Rakuten Card", on: day) != nil)
        #expect(Finance.sameSpend(a, paid: 13, currency: "USD", account: "Rakuten Card", on: day) == nil)
        #expect(Finance.sameSpend(a, amount: 1_800, account: "Rakuten Card", on: day) == nil)
    }

    @Test(arguments: [("US$12.50", 12.5), ("12,50 €", 12.5), ("NT$300", 300.0), ("$0.99", 0.99)])
    func theCentsAreKept(_ text: String, _ paid: Double) {
        #expect(CardEmailParser.tapFigure(text) == paid)
    }

    @Test func aForeignFigureIsConvertedWithItsCents() {
        // $12.50 at 0.0068 dollars a yen is ¥1,838, not the ¥1,912 of $13.
        #expect(Finance.convert(12.5, rate: 0.0068) == 1_838)
    }

    @Test func aBookWrittenWithWholeForeignAmountsStillOpens() throws {
        let old = #"{"id":"t1","date":0,"amount":-1765,"kind":"spend","account":"Card","currency":"USD","foreignAmount":12,"rate":0.0068}"#
        let t = try JSONDecoder().decode(Transaction.self, from: Data(old.utf8))
        #expect(t.foreignAmount == 12)
        var cents = t
        cents.foreignAmount = 12.5
        let back = try JSONDecoder().decode(Transaction.self, from: JSONEncoder().encode(cents))
        #expect(back.foreignAmount == 12.5)
    }
}

/// What a `MoneyField` with cents reads from what is typed.
struct MoneyExpressionCentsTests {
    @Test func centsAreKeptUpToTheCurrencysDigits() {
        let mark = MoneyExpression.decimalMark
        #expect(MoneyExpression.evaluateExact(MoneyExpression.normalise("12\(mark)50", fractionDigits: 2)) == 12.5)
        #expect(MoneyExpression.normalise("12\(mark)505", fractionDigits: 2) == "12.50")
        #expect(MoneyExpression.normalise("\(mark)5", fractionDigits: 2) == "0.5")
        #expect(MoneyExpression.evaluateExact(MoneyExpression.normalise("2\(mark)5×3", fractionDigits: 2)) == 7.5)
    }

    @Test func yenStillTakesWholeNumbersOnly() {
        #expect(MoneyExpression.normalise("1,200.5") == "12005")
        #expect(MoneyExpression.evaluate("1200") == 1200)
    }

    @Test func aTypedDecimalKeepsItsMarkWhileTheCentsAreComing() {
        #expect(MoneyExpression.display("12.") == "12" + MoneyExpression.decimalMark)
        #expect(MoneyExpression.plain(12.5, fractionDigits: 2) == "12.5")
        #expect(MoneyExpression.plain(12, fractionDigits: 2) == "12")
    }
}
