import Foundation
import Testing
@testable import Mochi

/// Receipts as Vision hands them over, and what each must come out as.
struct ReceiptParserTests {
    let convenience = [
        "Sunmart 渋谷道玄坂店",
        "東京都渋谷区道玄坂 0-0-0",
        "TEL 03-0000-0000",
        "登録番号 T1234567890123",
        "2026年9月30日(火) 12:41",
        "おにぎり 鮭 ¥180",
        "サラダ ¥398",
        "緑茶 500ml ¥162",
        "からあげ ¥540",
        "小計 ¥1,280",
        "(内消費税等 8% ¥94)",
        "合計 ¥1,280",
        "クレジット VISA ****1234",
    ]

    @Test func aConvenienceStoreReceiptGivesEveryField() {
        let d = ReceiptParser.parse(convenience)
        #expect(d.merchant == "Sunmart 渋谷道玄坂店")
        #expect(d.total == 1_280)
        #expect(d.registration == "T1234567890123")
        #expect(d.phone == "03-0000-0000")
        #expect(d.cardLast4 == "1234")
        #expect(d.payment == .card)
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: d.date!)
        #expect(c.year == 2026 && c.month == 9 && c.day == 30 && c.hour == 12 && c.minute == 41)
        #expect(d.lines.map(\.price) == [180, 398, 162, 540])
        #expect(d.totalMatchesLines)
    }

    @Test func theLinesThatGaveAFieldAreTheOnesOutlined() {
        let d = ReceiptParser.parse(convenience)
        // Shop, 登録番号, date, 合計, card — not 小計, not the lines bought.
        #expect(ReceiptParser.linesUsed(convenience, for: d) == [0, 3, 4, 11, 12])
    }

    @Test func thePhotoKeepsWhatItReadAndTakesOnlyWhatItMissed() {
        var photo = ReceiptDraft(); photo.total = 1_280; photo.merchant = "Sunmart"
        var live = ReceiptDraft(); live.total = 1_200; live.cardLast4 = "1234"
        let merged = photo.filled(from: live)
        #expect(merged.total == 1_280)
        #expect(merged.cardLast4 == "1234")
        #expect(merged.merchant == "Sunmart")
        // The camera goes the other way: the newest frame wins where it read something.
        #expect(photo.filled(from: live, preferringOther: true).total == 1_200)
        #expect(photo.filled(from: live, preferringOther: true).merchant == "Sunmart")
    }

    @Test func fullWidthFiguresAndYenSignsAreRead() {
        let d = ReceiptParser.parse(["ヒカリカメラ", "２０２６／０９／２９", "ミラーレス一眼 ￥１９８，０００", "お会計　￥１９８，０００", "現金"])
        #expect(d.total == 198_000)
        #expect(d.payment == .cash)
        #expect(Calendar.current.component(.day, from: d.date!) == 29)
    }

    @Test func theTotalIsNotWhatWasHandedOver() {
        let d = ReceiptParser.parse(["Kobe Coffee", "ブレンド 650", "合計 650", "お預り 1,000", "お釣 350"])
        #expect(d.total == 650)
        #expect(d.lines.map(\.name) == ["ブレンド"], "\(d.lines)")
    }

    @Test func aTotalOnTheNextLineIsFound() {
        #expect(ReceiptParser.total(in: ["お買上合計", "¥2,380"]) == 2_380)
    }

    @Test func withNoWordTheLargestFigureIsTheTotal() {
        #expect(ReceiptParser.total(in: ["Udon", "かけ 390", "天ぷら 500", "890"]) == 890)
    }

    @Test func aDiscountIsANegativeLine() {
        let d = ReceiptParser.parse(["Shop", "シャンプー 780", "値引 -100", "合計 680"])
        #expect(d.lines.map(\.price) == [780, -100])
        #expect(d.totalMatchesLines)
    }

    @Test func transitAndPayPayAreTold() {
        #expect(ReceiptParser.payment(in: ["交通系IC 残高 1,200"]) == .transitIC)
        #expect(ReceiptParser.payment(in: ["PayPay 支払"]) == .payPay)
    }

    @Test func aShortYearDateIsRead() {
        // Year first on a Japanese receipt; the kana is what says it is one.
        let d = ReceiptParser.date(in: ["ファミリーマート", "26/09/28 18:05"], calendar: .current)
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour], from: d!)
        #expect(c.year == 2026 && c.month == 9 && c.day == 28 && c.hour == 18)
    }
}

/// The camera's starting zoom, from the lens's closest focus.
struct ScanZoomTests {
    // A wide lens: 73° across the long side, 4:3, focusing no nearer than 200 mm.
    @Test func aLensThatCannotFocusCloseIsZoomedSoTheReceiptIsHeldFartherAway() {
        let z = ScanCamera.zoomToFill(fieldOfView: 73, zoom: 1, shortOverLong: 0.75, minimumFocus: 200)
        // Filling 75% of the width needs the receipt ~96 mm away; 200 / 96 ≈ 2.1×.
        #expect(z > 2.0 && z < 2.2)
    }

    @Test func aLensThatFocusesCloseEnoughIsLeftAlone() {
        #expect(ScanCamera.zoomToFill(fieldOfView: 73, zoom: 1, shortOverLong: 0.75, minimumFocus: 80) == 1)
        #expect(ScanCamera.zoomToFill(fieldOfView: 73, zoom: 1, shortOverLong: 0.75, minimumFocus: -1) == 1)
    }
}
