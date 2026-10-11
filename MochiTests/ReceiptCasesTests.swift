import Foundation
import Testing
@testable import Mochi

/// Receipts as they come: Japanese, English and Vietnamese, whole, cut off at
/// the top or the bottom, and long ones taken in two photos. Lines are what
/// Vision hands over, one per printed row.
struct ReceiptCasesTests {
    let cal = Calendar(identifier: .gregorian)

    func ymdhm(_ d: Date?) -> [Int] {
        guard let d else { return [] }
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        return [c.year!, c.month!, c.day!, c.hour ?? 0, c.minute ?? 0]
    }

    // MARK: Amounts

    @Test func figuresArePrintedEveryWay() {
        let cases: [(String, Int?)] = [
            ("合計 ¥1,280", 1_280), ("合計 1,280円", 1_280), ("¥5,500-", 5_500), ("値引 ▲100", -100), ("値引 -100", -100),
            ("TOTAL $25.35", 25), ("TOTAL 25.50", 26), ("Tổng cộng: 74.700đ", 74_700), ("Tổng tiền 125,000 VND", 125_000),
            ("Tổng 1.250.000 ₫", 1_250_000), ("Total 1.234,56 €", 1_235), ("おにぎり 鮭 ¥180", 180), ("軽 サラダ 398軽", 398),
            ("緑茶 500ml", nil), ("ありがとうございました", nil),
        ]
        for (line, want) in cases {
            #expect(ReceiptParser.trailingAmount(ReceiptParser.normalise(line)) == want, "\(line)")
        }
    }

    // MARK: Japanese

    @Test func aSupermarketWithTaxIncludedTotalAndADiscount() {
        let d = ReceiptParser.parse([
            "ライフ 新宿店", "令和8年9月30日(水) 18:05", "牛乳 1L 238", "食パン 6枚 168", "値引 ▲50", "小計 356",
            "(8%対象 356)", "税込合計 ¥384", "お預り ¥1,000", "お釣り ¥616",
        ], calendar: cal)
        #expect(d.merchant == "ライフ 新宿店")
        #expect(d.total == 384)
        #expect(ymdhm(d.date) == [2026, 9, 30, 18, 5])
        #expect(d.lines.map(\.price) == [238, 168, -50])
        #expect(d.payment == .cash)
        #expect(!d.missingTop && !d.missingBottom)
    }

    @Test func aRestaurantPrintsTheTotalOnTheLineBelow() {
        let d = ReceiptParser.parse(["居酒屋 はなこ", "2026/09/29 21:40", "生ビール 2 1,100", "枝豆 480", "お会計", "¥1,580"], calendar: cal)
        #expect(d.total == 1_580)
        #expect(d.lines.map(\.name) == ["生ビール", "枝豆"])
    }

    @Test func aHandwrittenRyoshushoHasOneFigure() {
        let d = ReceiptParser.parse(["領収書", "山田 様", "¥5,500-", "但し 飲食代として", "2026年9月28日", "喫茶 ミモザ"], calendar: cal)
        #expect(d.total == 5_500)
        #expect(ymdhm(d.date).prefix(3) == [2026, 9, 28])
    }

    @Test func aRyoshushoTakesItsShopFromTheStampAtTheFoot() {
        // The heading and the customer are at the top; the shop is stamped below the date.
        let d = ReceiptParser.parse(["領収書", "山田 様", "¥5,500-", "但し 飲食代として", "2026年9月28日", "喫茶 ミモザ"], calendar: cal)
        #expect(d.merchant == "喫茶 ミモザ")
    }

    @Test func theHeadingIsNeverTheShopHoweverItIsRead() {
        for heading in ["領収書", "領 収 書", "【領収書】", "領収害", "领收书", "御領収書", "R E C E I P T", "レシート", "お客様控え"] {
            let d = ReceiptParser.parse([heading, "Sunmart 渋谷道玄坂店", "2026年9月30日 12:41", "おにぎり ¥180", "合計 ¥180"], calendar: cal)
            #expect(d.merchant == "Sunmart 渋谷道玄坂店", "\(heading) was taken for the shop")
        }
    }

    @Test func aPhoneNumberIsTheSameHoweverItIsWritten() {
        #expect(ReceiptParser.samePhone("03-1234-5678", "+81 3-1234-5678"))
        #expect(ReceiptParser.samePhone("(03) 1234 5678", "0312345678"))
        #expect(!ReceiptParser.samePhone("03-1234-5678", "03-1234-5679"))
        #expect(!ReceiptParser.samePhone("1234", "1234"), "too short to be a shop's number")
    }

    @Test func theAddressIsReadFromThePostcodeOrThePrefecture() {
        let a = ReceiptParser.parse(["Sunmart 渋谷道玄坂店", "東京都渋谷区道玄坂 0-0-0", "合計 ¥180"], calendar: cal)
        #expect(a.address == "東京都渋谷区道玄坂 0-0-0")
        let b = ReceiptParser.parse(["喫茶 ミモザ", "〒150-0043", "渋谷区道玄坂1-2-3", "合計 ¥980"], calendar: cal)
        #expect(b.address == "渋谷区道玄坂1-2-3")
        let c = ReceiptParser.parse(["カフェ", "〒530-0001 大阪府大阪市北区梅田1-1", "合計 ¥500"], calendar: cal)
        #expect(c.address == "大阪府大阪市北区梅田1-1")
        #expect(ReceiptParser.parse(["カフェ", "合計 ¥500"], calendar: cal).address == nil)
    }

    @Test func onlyTheBottomOfAConvenienceReceipt() {
        // Held too close: the shop, the address and the date are above the picture.
        let d = ReceiptParser.parse(["からあげ ¥540", "小計 ¥1,280", "(内消費税等 8% ¥94)", "合計 ¥1,280", "クレジット VISA ****1234"], calendar: cal)
        #expect(d.total == 1_280)
        #expect(d.merchant == "", "a product line is not the shop")
        #expect(d.cardLast4 == "1234")
        #expect(d.missingTop)
        #expect(!d.totalMatchesLines)
    }

    @Test func onlyTheTopOfALongReceipt() {
        let d = ReceiptParser.parse(["Sunmart 渋谷道玄坂店", "登録番号 T1234567890123", "2026年9月30日(水) 12:41",
                                     "おにぎり 鮭 ¥180", "サラダ ¥398", "緑茶 500ml ¥162"], calendar: cal)
        #expect(d.merchant == "Sunmart 渋谷道玄坂店")
        #expect(d.total == nil, "the dearest line is not the total")
        #expect(d.missingBottom)
    }

    @Test func aLongReceiptInTwoPhotosIsJoined() {
        let top = ReceiptParser.parse(["Sunmart 渋谷道玄坂店", "2026年9月30日 12:41", "おにぎり 鮭 ¥180", "サラダ ¥398", "緑茶 500ml ¥162"], calendar: cal)
        // The second photo overlaps the first by one line.
        let bottom = ReceiptParser.parse(["緑茶 500ml ¥162", "からあげ ¥540", "小計 ¥1,280", "合計 ¥1,280", "クレジット VISA ****1234"], calendar: cal)
        for whole in [top.joined(with: bottom), bottom.joined(with: top)] {
            #expect(whole.merchant == "Sunmart 渋谷道玄坂店")
            #expect(whole.lines.map(\.price) == [180, 398, 162, 540])
            #expect(whole.total == 1_280)
            #expect(whole.totalMatchesLines)
            #expect(whole.cardLast4 == "1234")
        }
        #expect(top.goesAbove(bottom) && !bottom.goesAbove(top))
    }

    @Test func aVeryLongReceiptKeepsEveryLine() {
        let items = (1...60).map { "商品\($0) ¥100" }
        let d = ReceiptParser.parse(["業務スーパー"] + items + ["合計 ¥6,000"], calendar: cal)
        #expect(d.lines.count == 60)
        #expect(d.totalMatchesLines)
    }

    // MARK: English

    @Test func anAmericanReceiptInDollars() {
        let d = ReceiptParser.parse([
            "TRADER JOE'S", "401 Bay St", "Tel 415-555-0100", "BANANAS 0.99", "OAT MILK 3.49", "SUBTOTAL 4.48", "TAX 0.37",
            "TOTAL 4.85", "VISA ************1234", "09/30/2026 07:15 PM",
        ], calendar: cal)
        #expect(d.merchant == "TRADER JOE'S")
        #expect(d.total == 5, "whole units, the cents rounded")
        #expect(ymdhm(d.date) == [2026, 9, 30, 19, 15])
        #expect(d.cardLast4 == "1234")
        #expect(d.payment == .card)
    }

    @Test func subtotalAndSavingsAreNotTheTotal() {
        #expect(ReceiptParser.total(in: ["Sub Total 3,000", "Total Savings 300", "Grand Total 2,700", "Cash 3,000", "Change 300"]) == 2_700)
        #expect(ReceiptParser.total(in: ["SUBTOTAL 1,000", "TOTAL 1,100"]) == 1_100)
    }

    @Test func anEnglishReceiptInYenWithADayFirstDate() {
        let d = ReceiptParser.parse(["Hotel Okura Lounge", "30 Sep 2026 15:20", "Afternoon tea x2 ¥9,600", "Service charge ¥960",
                                     "Total ¥10,560", "Card ****5678"], calendar: cal)
        #expect(d.merchant == "Hotel Okura Lounge", "\"tel\" in Hotel is not a phone line")
        #expect(d.total == 10_560)
        #expect(ymdhm(d.date) == [2026, 9, 30, 15, 20])
        #expect(d.lines.map(\.name) == ["Afternoon tea", "Service charge"])
    }

    @Test func aProductNumberIsNotTakenForAQuantity() {
        let d = ReceiptParser.parse(["Bic Camera", "Pixel 9 ¥128,800", "Total ¥128,800"], calendar: cal)
        #expect(d.lines.map(\.name) == ["Pixel 9"])
    }

    // MARK: Vietnamese

    @Test func aVietnameseCafeWithQuantityAndUnitPrice() {
        let d = ReceiptParser.parse([
            "HIGHLANDS COFFEE", "HÓA ĐƠN BÁN LẺ", "Địa chỉ: 12 Lê Lợi, Q.1", "Ngày: 30/09/2026 12:41",
            "Cà phê sữa đá 2 29.000 58.000", "Bánh mì 1 25.000 25.000", "Tạm tính 83.000", "Giảm giá -8.300",
            "Tổng cộng: 74.700đ", "Tiền khách đưa 100.000", "Tiền thừa 25.300",
        ], calendar: cal)
        #expect(d.merchant == "HIGHLANDS COFFEE")
        #expect(d.total == 74_700)
        #expect(ymdhm(d.date) == [2026, 9, 30, 12, 41])
        #expect(d.lines == [.init(name: "Cà phê sữa đá", price: 58_000), .init(name: "Bánh mì", price: 25_000), .init(name: "Giảm giá", price: -8_300)])
        #expect(d.totalMatchesLines)
        #expect(d.payment == .cash)
    }

    @Test func aVietnameseReceiptReadWithoutItsAccents() {
        let d = ReceiptParser.parse(["COM TAM CALI", "Com suon 65.000", "Tra da 5.000", "TONG CONG 70.000"], calendar: cal)
        #expect(d.total == 70_000)
        #expect(d.merchant == "COM TAM CALI")
    }

    @Test func aVietnameseSupermarketPaysTheStrongerLine() {
        let d = ReceiptParser.parse(["WinMart", "Ngày 29 tháng 09 năm 2026", "Thành tiền 150.000", "Chiết khấu -15.000",
                                     "Tổng tiền thanh toán 135.000", "Thẻ VISA **** **** **** 4321"], calendar: cal)
        #expect(d.total == 135_000)
        #expect(ymdhm(d.date).prefix(3) == [2026, 9, 29])
        #expect(d.cardLast4 == "4321")
        #expect(d.payment == .card)
    }

    @Test func onlyTheBottomOfAVietnameseReceipt() {
        let d = ReceiptParser.parse(["Trà sữa 45.000", "Tổng cộng 90.000", "Tiền mặt 100.000", "Tiền thừa 10.000"], calendar: cal)
        #expect(d.total == 90_000)
        #expect(d.merchant == "")
        #expect(d.missingTop)
    }

    // MARK: Dates that are not dates

    @Test func aTwoDigitYearIsLastOutsideJapan() {
        #expect(ymdhm(ReceiptParser.date(in: ["Phở 24", "30/09/26 12:00"], calendar: cal)).prefix(3) == [2026, 9, 30])
    }

    @Test func thirtyFirstOfSeptemberIsNotADay() {
        #expect(ReceiptParser.date(in: ["31/09/2026"], calendar: cal) == nil)
        #expect(ymdhm(ReceiptParser.date(in: ["13/09/2026"], calendar: cal)).prefix(3) == [2026, 9, 13])
    }

    // MARK: What Vision really hands over
    //
    // Read from rendered receipts on the simulator (iOS 26.5), in both
    // language orders. Kept as they came, misreadings and all.

    let vietnameseReadJapaneseFirst = ["PHUC LONG COFFEE", "HOA DON BAN LE", "Ngay: 30/09/2026 15:10", "Tra stra 2 45.000 90.000",
                                       "Banh croissant 1 35.000 35.000", "Tam tinn 125.000", "Tong cong 125.000d", "Tien mat 200.000",
                                       "Tien thura 75.000"]
    let vietnameseReadVietnameseFirst = ["PHÚC LONG COFFEE", "HÓA ĐƠN BÁN LẺ", "Ngày: 30/09/2026 15:10", "Trà sữa 2 45.000 90.000",
                                         "Bánh croissant 1 35.000 35.000", "Tạm tính 125.000", "Tổng cộng 125.000đ", "Tiền mặt 200.000",
                                         "Tiền thừa 75.000"]
    let japaneseReadJapaneseFirst = ["ローソン 新宿三丁目店", "登録番号 9876543210987", "2026年10月1日（木） 08:15", "おにぎり梅 ¥160",
                                     "ホットコーヒー ¥120", "サンドイッチ ¥398"]
    let japaneseReadVietnameseFirst = ["**# T9876543210987", "2026{10018( 815", "·160", "*\" .]- - ·120", "·398"]

    @Test func aVietnameseReceiptReadWithJapaneseFirstStillAddsUp() {
        let d = ReceiptParser.parse(vietnameseReadJapaneseFirst, calendar: cal)
        #expect(d.merchant == "PHUC LONG COFFEE")
        #expect(d.total == 125_000, "\"125.000d\" is an OCR'd 125.000đ")
        #expect(d.lines.map(\.price) == [90_000, 35_000], "Tam tinn and Tien thura are one letter off Tạm tính and Tiền thừa")
        #expect(d.totalMatchesLines)
        #expect(ymdhm(d.date) == [2026, 9, 30, 15, 10])
    }

    @Test func theSameReceiptReadVietnameseFirstGivesTheSame() {
        let d = ReceiptParser.parse(vietnameseReadVietnameseFirst, calendar: cal)
        #expect(d.merchant == "PHÚC LONG COFFEE")
        #expect(d.total == 125_000)
        #expect(d.lines.map(\.name) == ["Trà sữa", "Bánh croissant"])
        #expect(d.payment == .cash)
    }

    @Test func aRegistrationNumberWhoseTWasLost() {
        let d = ReceiptParser.parse(japaneseReadJapaneseFirst, calendar: cal)
        #expect(d.registration == "T9876543210987")
        #expect(d.merchant == "ローソン 新宿三丁目店")
        #expect(ymdhm(d.date) == [2026, 10, 1, 8, 15])
        #expect(d.missingBottom)
    }

    @Test func aReadingInTheWrongScriptIsReadAgainTheOtherWay() {
        let ja = ["ja-JP", "en-US", "vi-VT"], vi = ["vi-VT", "en-US", "ja-JP"]
        #expect(ReceiptReader.otherOrder(for: vietnameseReadJapaneseFirst, after: ja) == vi)
        #expect(ReceiptReader.otherOrder(for: japaneseReadVietnameseFirst, after: vi) == ja)
        // Read right the first time: no second pass.
        #expect(ReceiptReader.otherOrder(for: japaneseReadJapaneseFirst, after: ja) == nil)
        #expect(ReceiptReader.otherOrder(for: vietnameseReadVietnameseFirst, after: vi) == nil)
        // And the better reading wins.
        #expect(ReceiptReader.score(vietnameseReadVietnameseFirst) >= ReceiptReader.score(vietnameseReadJapaneseFirst))
        #expect(ReceiptReader.score(japaneseReadJapaneseFirst) > ReceiptReader.score(japaneseReadVietnameseFirst))
    }

    @Test func oneLetterOffIsStillTheWord() {
        #expect(ReceiptWords(["tam tinh"]).found(in: ReceiptParser.fold("Tam tinn 125.000")))
        #expect(ReceiptWords(["tam tinh"]).found(in: ReceiptParser.fold("Tạm tính 125.000")))
        // Short words must match exactly: "card" is not "cart".
        #expect(!ReceiptWords(["card"]).found(in: "shopping cart 300"))
        #expect(!ReceiptWords(["tel"]).found(in: "hotel okura"))
    }

    // MARK: Which money

    @Test func theReceiptSaysWhichMoneyItIsIn() {
        #expect(ReceiptParser.parse(["Sunmart", "合計 ¥1,280"]).currency == "JPY")
        #expect(ReceiptParser.parse(vietnameseReadVietnameseFirst).currency == "VND")
        // Read without accents and with đ as d: still đồng.
        #expect(ReceiptParser.parse(vietnameseReadJapaneseFirst).currency == "VND")
        #expect(ReceiptParser.parse(["COM TAM CALI", "Com suon 65.000", "TONG CONG 70.000"]).currency == "VND", "a Vietnamese word, no symbol")
        #expect(ReceiptParser.parse(["TRADER JOE'S", "TOTAL $4.85"]).currency == "USD")
        #expect(ReceiptParser.parse(["Café de Flore", "Total 12,50 €"]).currency == "EUR")
        #expect(ReceiptParser.parse(["ラーメン 900", "合計 900"]).currency == "JPY", "no symbol, but Japanese")
        // Nothing on the paper says: the book's own money, not a guess.
        #expect(ReceiptParser.parse(["SHOP", "Item 300", "Total 300"]).currency == nil)
    }

    @Test func aForeignTotalIsTurnedIntoTheBooksAtTheRate() {
        // 125.000 ₫ at 170 ₫ to ¥1.
        #expect(Finance.convert(125_000, rate: 170) == 735)
        // Two parts of one receipt keep the money the first one found.
        var top = ReceiptParser.parse(["PHÚC LONG COFFEE", "Trà sữa 90.000"])
        top.currency = "VND"
        #expect(top.joined(with: ReceiptParser.parse(["Tổng cộng 90.000"])).currency == "VND")
    }

    // MARK: A receipt photographed at a slant

    /// A piece of text centred at (x, y), `w` wide and `h` tall in the
    /// normalised picture, its line rising `slope` (in y per x) to the right.
    func piece(_ text: String, _ x: CGFloat, _ y: CGFloat, w: CGFloat = 0.2, h: CGFloat = 0.03, slope: CGFloat) -> ReceiptReader.Piece {
        let lx = x - w / 2, rx = x + w / 2, ly = y - slope * w / 2, ry = y + slope * w / 2
        return .init(text: text, quad: [CGPoint(x: lx, y: ly - h / 2), CGPoint(x: rx, y: ry - h / 2),
                                        CGPoint(x: rx, y: ry + h / 2), CGPoint(x: lx, y: ly + h / 2)])
    }

    @Test func aSlantedReceiptKeepsEachPriceOnItsOwnLine() {
        // Lines rise to the right: each price sits higher than its name by
        // two line heights, level with the name of the line above.
        let s: CGFloat = -0.06 / 0.7
        let pieces = [
            piece("合計", 0.1, 0.50, slope: s), piece("¥80", 0.8, 0.44, w: 0.1, slope: s),
            piece("お預り金額", 0.15, 0.56, w: 0.3, slope: s), piece("¥100", 0.8, 0.50, w: 0.1, slope: s),
            piece("おつり", 0.1, 0.62, slope: s), piece("¥20", 0.8, 0.56, w: 0.1, slope: s),
        ]
        let rows = ReceiptReader.group(pieces, aspect: 0.75)
        #expect(rows.map(\.text) == ["合計 ¥80", "お預り金額 ¥100", "おつり ¥20"])
        // The outline runs along the slant: its right end higher than its left.
        #expect(rows[0].quad.count == 4 && rows[0].quad[1].y < rows[0].quad[0].y)
        #expect(ReceiptParser.parse(rows.map(\.text)).total == 80)
    }

    @Test func aStraightReceiptGroupsAsBefore() {
        let pieces = [piece("サラダ", 0.2, 0.30, slope: 0), piece("¥398", 0.8, 0.301, w: 0.1, slope: 0),
                      piece("緑茶", 0.2, 0.34, slope: 0), piece("¥162", 0.8, 0.341, w: 0.1, slope: 0)]
        #expect(ReceiptReader.group(pieces, aspect: 0.75).map(\.text) == ["サラダ ¥398", "緑茶 ¥162"])
    }
}
