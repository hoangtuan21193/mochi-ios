import Foundation
import Testing
@testable import Mochi

/// The most to pay in the shop and still make the target once sold on, and
/// a card's usage email read into a spend.
struct BuyAdviceTests {
    static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    /// The Buy advice artboard: a lens to sell on Mercari for ¥240,000, bought
    /// at a shop that has paid back 4% in points.
    func book() -> AppData {
        var a = AppData()
        a.channels = [SalesChannel(name: "Mercari", rate: 10)]
        a.wallets = [Wallet(name: "SMBC bank", balance: 300_000),
                     Wallet(name: "Mercari", balance: 0, payoutTo: "SMBC bank", payoutFee: 200, payoutDays: 3)]
        var old = Item(name: "Nikon Z 70-200mm f/2.8 VR S", boughtOn: Self.day(2025, 11, 1), buyPrice: 200_000,
                       boughtFrom: "MapCamera", cardName: "", pointsEarned: 8_000, estimatedPrice: 0, plannedChannel: "Mercari")
        old.sale = SaleRecord(price: 238_000, channel: "Mercari", net: 212_700, date: Self.day(2026, 3, 1))
        var older = Item(name: "Z 70-200 f2.8", boughtOn: Self.day(2025, 8, 1), buyPrice: 220_000,
                         boughtFrom: "MapCamera", cardName: "", pointsEarned: 8_800, estimatedPrice: 0, plannedChannel: "Mercari")
        older.sale = SaleRecord(price: 245_000, channel: "Mercari", net: 219_000, date: Self.day(2025, 11, 1))
        let other = Item(name: "Sony 24-70mm f/2.8 GM II", boughtOn: Self.day(2026, 1, 1), buyPrice: 250_000,
                         boughtFrom: "Bic Camera", cardName: "", estimatedPrice: 0, plannedChannel: "Mercari")
        a.items = [other, old, older]
        return a
    }

    @Test func theMostToPayStillMakesTheTargetWithPoints() {
        let a = book()
        let advice = Finance.buyAdvice(sellFor: 240_000, channel: "Mercari", postage: 1_500,
                                       shop: "MapCamera", target: 10_000, a)
        #expect(advice.fee == 24_000)
        #expect(advice.payoutFee == 200)
        #expect(advice.payoutTo == "SMBC bank")
        #expect(advice.pointRate == 4)
        #expect(advice.maxPrice == 212_800)
        let atMax = advice.result(at: advice.maxPrice)
        #expect(atMax.cash == 1_500)
        #expect(atMax.points == 8_512)
        #expect(atMax.total == 10_012)
    }

    @Test func aDearerAskLosesTheGapLessItsPoints() {
        let advice = Finance.buyAdvice(sellFor: 240_000, channel: "Mercari", postage: 1_500,
                                       shop: "MapCamera", target: 10_000, book())
        let asked = advice.result(at: 225_000)
        #expect(asked.cash == -10_700)
        #expect(asked.points == 9_000)
        #expect(asked.total == -1_700)
    }

    @Test func aShopNeverBoughtFromPaysNoPoints() {
        let advice = Finance.buyAdvice(sellFor: 240_000, channel: "Mercari", postage: 1_500,
                                       shop: "Somewhere new", target: 10_000, book())
        #expect(advice.pointRate == 0)
        #expect(advice.maxPrice == 204_300)
    }

    @Test func theShopUsedMostComesFirst() {
        #expect(Finance.shops(book()) == ["MapCamera", "Bic Camera"])
    }

    @Test func typingSuggestsNamesSoldBeforeLastSoldFirst() {
        let index = Finance.SoldIndex(book())
        let names = index.suggestions("70-200")
        #expect(names.map(\.name) == ["Nikon Z 70-200mm f/2.8 VR S", "Z 70-200 f2.8"])
        #expect(names.first?.lastPrice == 238_000)
        // Once the field holds a name as sold, the list goes away.
        #expect(index.suggestions("Z 70-200 f2.8").isEmpty)
        #expect(index.suggestions("").isEmpty)
        // A thing owned and never sold comes after the sales, with what was paid.
        let owned = index.suggestions("24-70")
        #expect(owned.map(\.name) == ["Sony 24-70mm f/2.8 GM II"])
        #expect(owned.first?.sold == false)
        #expect(owned.first?.lastPrice == 250_000)
    }

    @Test func similarSalesMatchTheWayTheSearchDoes() {
        let sold = Finance.similarSales("z 70-200 f2.8", book())
        #expect(sold.map(\.sale?.price) == [238_000, 245_000])
        #expect(Finance.similarSales("", book()).isEmpty)
    }

    // MARK: card emails

    @Test func aRakutenCardEmailBecomesASpend() {
        let body = """
        楽天カードをご利用いただきありがとうございます。
        ■利用日: 2026/10/01
        ■利用先: AMAZON.CO.JP
        ■利用者: 本人
        ■支払方法: 1回
        ■利用金額: 3,280 円
        """
        let mail = CardEmailParser.parse(subject: "【楽天カード】カード利用のお知らせ", body: body)
        #expect(mail?.merchant == "AMAZON.CO.JP")
        #expect(mail?.amount == 3_280)
        #expect(mail?.issuer == "Rakuten Card")
        #expect(mail?.date == Self.day(2026, 10, 1))
    }

    @Test func aJCBEmailWithFullWidthFiguresAndTheValueOnTheNextLine() {
        let body = """
        カードご利用のお知らせ
        【ご利用日時】
        ２０２６/１０/０１ １２:３４
        【ご利用先】
        セブン－イレブン
        【ご利用金額】
        ６４８円
        """
        let mail = CardEmailParser.parse(subject: "JCBカード／ショッピングご利用のお知らせ", body: body)
        #expect(mail?.amount == 648)
        #expect(mail?.issuer == "JCB")
        #expect(mail?.date == Self.day(2026, 10, 1))
        #expect(mail?.merchant.isEmpty == false)
    }

    @Test func anEmailWithoutAFigureIsNotASpend() {
        #expect(CardEmailParser.parse(subject: "【楽天カード】ご請求額確定のお知らせ", body: "明細をご確認ください。") == nil)
    }

    @Test func theCardIsTheOneWhoseNameCarriesTheIssuer() {
        let cards = [CreditCard(name: "Rakuten Card", dueDay: 27, debt: 0), CreditCard(name: "JCB Card W", dueDay: 10, debt: 0),
                     CreditCard(name: "JCB Gold", dueDay: 10, debt: 0)]
        let rakuten = CardEmail(date: nil, merchant: "X", amount: 1, issuer: "Rakuten Card")
        let jcb = CardEmail(date: nil, merchant: "X", amount: 1, issuer: "JCB")
        #expect(CardEmailParser.card(for: rakuten, in: cards)?.name == "Rakuten Card")
        // Two JCB cards: no guess.
        #expect(CardEmailParser.card(for: jcb, in: cards) == nil)
    }

    @Test func aTapBookedTwiceIsKeptOnce() {
        var a = AppData()
        a.transactions = [Transaction(date: Self.day(2026, 10, 1), amount: -648, kind: .spend, account: "Rakuten Card",
                                      merchant: "LAWSON", source: .applePay)]
        #expect(Finance.sameSpend(a, amount: 648, account: "Rakuten Card", on: Self.day(2026, 10, 1)) != nil)
        #expect(Finance.sameSpend(a, amount: 648, account: "Rakuten Card", on: Self.day(2026, 10, 2)) == nil)
        #expect(Finance.sameSpend(a, amount: 650, account: "Rakuten Card", on: Self.day(2026, 10, 1)) == nil)
    }

    @Test func typingAFindsTheSonyAlpha() {
        var a = AppData()
        a.items = [Item(name: "Sony α7C II body", boughtOn: Self.day(2026, 1, 1), buyPrice: 198_000, cardName: "",
                        estimatedPrice: 0, plannedChannel: "")]
        #expect(Finance.SoldIndex(a).suggestions("sony a7c").map(\.name) == ["Sony α7C II body"])
    }
}
