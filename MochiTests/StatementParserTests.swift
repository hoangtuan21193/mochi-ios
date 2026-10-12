import Foundation
import Testing
@testable import Mochi

/// Statement files read by their header names, and matched against the book
/// so an import never counts a spend twice.
struct StatementParserTests {
    static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    let paypay = """
    取引日,出金金額（円）,入金金額（円）,海外出金金額,通貨,変換レート（円）,利用国,取引内容,取引先,取引方法,支払い区分,利用者,取引番号
    2026/09/30 12:41:00,650,-,-,-,-,-,支払い,Kobe Coffee 新宿三丁目,PayPay残高,-,-,1
    2026/09/29 10:00:00,-,10000,-,-,-,-,チャージ,SMBC銀行,銀行口座,-,-,2
    2026/09/29 18:10:00,-,380,-,-,-,-,返金,Nishi Pharmacy,PayPay残高,-,-,3
    2026/09/28 19:05:00,890,-,-,-,-,-,支払い,Hanamaru Udon,PayPay残高,-,-,4
    """

    @Test func payPaysHistoryIsReadByItsHeaders() {
        let r = StatementParser.parse(paypay)
        #expect(r.rows.count == 4)
        #expect(r.rows[0].merchant == "Kobe Coffee 新宿三丁目")
        #expect(r.rows[0].amount == -650)
        #expect(r.rows[0].kind == .spend)
        #expect(r.rows[1].kind == .move)
        #expect(r.rows[1].amount == 10_000)
        #expect(r.rows[2].kind == .refund)
        #expect(r.rows[2].amount == 380)
    }

    @Test func aCardStatementWithChargesOnlyReadsThemAsSpending() {
        let rakuten = """
        利用日,利用店名・商品名,利用者,支払方法,利用金額,支払手数料,支払総額
        2026/09/30,SUNMART SHIBUYA,本人,1回払い,1280,0,1280
        2026/09/27,YAKINIKU KINTA,本人,1回払い,16000,0,16000
        """
        let r = StatementParser.parse(rakuten)
        #expect(r.rows.map(\.amount) == [-1_280, -16_000])
        #expect(r.rows.allSatisfy { $0.kind == .spend })
    }

    @Test func aHeaderlessStatementIsReadByWhatItsColumnsHold() {
        let smbc = "2026/09/28,NETFLIX.COM,1590,１,１,1590"
        let r = StatementParser.parse(smbc)
        #expect(r.rows.first?.merchant == "NETFLIX.COM")
        #expect(r.rows.first?.amount == -1_590)
    }

    @Test func whatIsAlreadyInTheBookIsLeftOff() {
        var a = AppData()
        a.wallets = [Wallet(name: "PayPay", balance: 0)]
        a.transactions = [Transaction(date: Self.day(2026, 9, 30), amount: -650, kind: .spend, account: "PayPay", merchant: "Kobe Coffee")]
        let rows = StatementParser.parse(paypay).rows
        let m = StatementParser.match(rows, account: "PayPay", a)
        #expect(m[rows[0].id] == .alreadyHere)
        #expect(m[rows[3].id] == .new)
    }

    @Test func aBankDebitForACardIsMatchedToTheCard() {
        var a = AppData()
        a.cards = [CreditCard(name: "Rakuten Card", dueDay: 10, debt: 142_300, closingDay: 15)]
        let bank = """
        日付,摘要,お引出し,お預入れ,残高
        2026/10/10,ラクテンカード サービス,142300,,370100
        2026/10/12,ATM,10000,,360100
        """
        let rows = StatementParser.parse(bank).rows
        #expect(rows[0].kind == .move)
        let m = StatementParser.match(rows, account: "SMBC", a)
        #expect(m[rows[0].id] == .cardPayment("Rakuten Card"))
    }
}
