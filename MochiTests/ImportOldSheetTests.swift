import Foundation
import Testing
@testable import Mochi

/// The sheet this book grew out of: a Google Sheet with its own column names,
/// two columns the app has no business reading (someone else's card, the
/// length of a loan), a point *rate* beside the points themselves, and the
/// same purchase written twice. It has to import as it stands — the rows are
/// years of buying and selling, and retyping a header is not the answer.
struct ImportOldSheetTests {

    /// Header and rows exactly as they are pasted out of the sheet:
    /// Sold? · Item · 購入日 · Thẻ vợ · Loan time · Buy · Buy on Market ·
    /// % Point · Earn Point · New price · Sell Price · Sell on ·
    /// Shipping Fee · Income · Profit
    static let sheet =
        "Sold?\tItem\t購入日\tThẻ vợ\tLoan time\tBuy\tBuy on Market\t% Point\tEarn Point\tNew price\tSell Price\tSell on\tShipping Fee\tIncome\tProfit\n" +
        "FALSE\tOsprey Tenpo 33\t\t\t\t¥27,000\tLocal\t11.0%\t¥2,970\t\t\t\t¥850\t#N/A\t#N/A\n" +
        "FALSE\tOM BLX-1 Battery\t\t\t\t¥5,000\tPayPay\t1.0%\t¥50\t\t¥5,000\tRakuma\t¥1,000\t¥3,775\t-¥1,225\n" +
        "FALSE\tOlympus MC-14\t\tPayPay\t\t¥15,000\tPayPay\t1.0%\t¥150\t\t¥15,000\tRakuma\t¥1,000\t¥13,325\t-¥1,675\n" +
        "FALSE\tLP-E6N\t\tSaison\t\t¥0\tMercari\t1.0%\t¥0\t\t¥2,500\tPayPay\t¥200\t¥2,175\t¥2,175\n" +
        "FALSE\tSigma 56 F1.4 M43\t2024/02/08\t\t\t¥36,500\tKitamura\t0.0%\t¥0\t\t¥42,500\tPayPay\t¥1,000\t¥39,375\t¥2,875\n" +
        "TRUE\tEOS R5 Mark II\t2025/02/09\t\t60\t¥610,000\tKitamura\t0.5%\t¥3,050\t\t¥505,000\tPayPay\t¥1,000\t¥478,750\t-¥131,250\n" +
        "FALSE\tHomePod 2\t2025/10/18\t\t\t¥25,000\tMercari\t1.0%\t¥250\t\t¥27,000\tPayPay\t¥1,000\t¥24,650\t-¥350\n" +
        "FALSE\tHomePod 2\t2025/10/18\t\t\t¥25,000\tMercari\t1.0%\t¥250\t\t¥27,000\tPayPay\t¥1,000\t¥24,650\t-¥350\n" +
        "TRUE\tOM1 MK2\t2025/12/31\t\t\t¥185,000\tMercari\t1.0%\t¥1,850\t\t¥213,000\tMercari\t¥1,000\t¥190,700\t¥5,700"

    /// A book with the cards and channels the sheet's words have to land on:
    /// "PayPay" is this book's "PayPay Flea", and "Rakuma" is nobody's yet.
    func store() -> Store {
        let s = Store(data: .empty)
        var book = AppData.empty
        book.cards = [CreditCard(name: "Saison", dueDay: 4, debt: 0)]
        book.channels = [SalesChannel(name: "Mercari", rate: 10),
                         SalesChannel(name: "PayPay Flea", rate: 5)]
        book.defaultShippingFee = 1_000
        s.data = book
        return s
    }

    private func row(_ preview: Store.ImportPreview, _ name: String) -> Store.ImportRow? {
        preview.rows.first { $0.item.name == name }
    }

    @Test func columnsTheAppDoesNotDefineAreSkippedRatherThanRead() {
        let s = store()
        let preview = s.parseImport(Self.sheet)

        #expect(preview.recognisedHeader)
        #expect(preview.failures.isEmpty)
        #expect(preview.rows.count == 9)

        // Named as the sheet writes them, not folded, or the line on screen
        // names a column nobody can find in their own sheet.
        #expect(preview.ignoredHeaders == ["Thẻ vợ", "Loan time", "% Point", "New price"])
        // Nothing was read as a card: the only card-ish column was the wife's.
        #expect(!preview.usedColumns.contains("Card"))
        #expect(preview.rows.allSatisfy { $0.item.cardName.isEmpty })
        // "Thẻ vợ" holding a real card name changes nothing and warns about
        // nothing — the column is not this book's business.
        #expect(row(preview, "LP-E6N")?.warnings.contains { $0.contains("card") } == false)

        // Points come from Earn Point. The 11.0% in "% Point" is a rate.
        #expect(row(preview, "Osprey Tenpo 33")?.item.pointsEarned == 2_970)
        #expect(row(preview, "EOS R5 Mark II")?.item.pointsEarned == 3_050)
    }

    @Test func theSheetsOwnWordsLandOnTheRightFields() {
        let s = store()
        let preview = s.parseImport(Self.sheet)

        // Buy on Market is where it was bought, Sell on is where it goes.
        let battery = row(preview, "OM BLX-1 Battery")
        #expect(battery?.item.boughtFrom == "PayPay")
        #expect(battery?.item.buyPrice == 5_000)
        #expect(battery?.item.plannedChannel == "Rakuma")
        #expect(battery?.item.shippingFee == 1_000)
        // FALSE with a Sell Price is an asking price, not a sale.
        #expect(battery?.item.isSold == false)
        #expect(battery?.item.estimatedPrice == 5_000)

        // "PayPay" is read as this book's channel; "Rakuma" is new.
        #expect(row(preview, "LP-E6N")?.item.plannedChannel == "PayPay Flea")
        #expect(preview.channels.first { $0.written == "Rakuma" }?.isNew == true)
        #expect(preview.channels.first { $0.written == "PayPay" }?.matched == "PayPay Flea")

        // TRUE means sold: Sell Price is the price, Income is what arrived.
        let r5 = row(preview, "EOS R5 Mark II")
        #expect(r5?.item.sale?.price == 505_000)
        #expect(r5?.item.sale?.net == 478_750)
        #expect(r5?.item.sale?.channel == "PayPay Flea")
        #expect(r5?.item.buyPrice == 610_000)
        #expect(Finance.realizedProfit(r5!.item) == -131_250)

        // 購入日 reads, and a row without one comes in dated today and says so.
        #expect(row(preview, "Sigma 56 F1.4 M43")?.item.boughtOn
                == Calendar.current.date(from: DateComponents(year: 2024, month: 2, day: 8)))
        #expect(row(preview, "LP-E6N")?.warnings.contains { $0.contains("dated today") } == true)
        #expect(row(preview, "Sigma 56 F1.4 M43")?.warnings.contains { $0.contains("dated today") } == false)

        // No Sell on at all, but Sold? says FALSE — the sheet is stating this
        // is stock it still holds, so it comes in for sale with nowhere named
        // yet. Only a blank status lets the missing channel mean "keeping".
        #expect(row(preview, "Osprey Tenpo 33")?.item.keep == false)
        #expect(row(preview, "Osprey Tenpo 33")?.warnings.contains { $0.contains("for sale") } == true)
    }

    @Test func theSamePurchaseTwiceIsFlaggedAndStillImportsWhenAskedFor() {
        let s = store()
        var preview = s.parseImport(Self.sheet)

        let repeated = preview.rows.filter { $0.duplicate == .repeatedInFile }
        #expect(repeated.count == 1)
        #expect(repeated[0].item.name == "HomePod 2")
        // Off by default, so a sheet pasted twice does not double the book.
        #expect(repeated[0].include == false)
        #expect(preview.includedCount == 8)

        // "Import anyway" — two of the same speaker, bought the same day, is
        // exactly what this sheet says.
        for i in preview.rows.indices where preview.rows[i].isDuplicate {
            preview.rows[i].include = true
        }
        #expect(preview.includedDuplicateCount == preview.duplicateCount)

        let written = s.commitImport(preview, source: "Test")
        #expect(written == 9)
        #expect(s.data.items.filter { $0.name == "HomePod 2" }.count == 2)
        // The channel the sheet named and the book lacked was created.
        #expect(s.data.channels.contains { $0.name == "Rakuma" })
        // Records only: an import never touches a card or a wallet.
        #expect(s.data.cards[0].debt == 0)
        #expect(s.data.wallets.isEmpty)
    }

    @Test func pastingTheSameSheetTwiceDoesNotDoubleTheBook() {
        let s = store()
        #expect(s.commitImport(s.parseImport(Self.sheet), source: "Test") == 8)
        // Every row now matches something in the book, so the second paste
        // adds nothing. The two sold rows land on the items they describe —
        // writing the same sale they already carry — and the book stays eight.
        let again = s.parseImport(Self.sheet)
        #expect(again.includedCount == 2)
        #expect(again.rows.filter { $0.isUpdate }.map { $0.item.name } == ["EOS R5 Mark II", "OM1 MK2"])
        #expect(again.rows.filter { $0.include && !$0.isUpdate }.isEmpty)
        #expect(s.commitImport(again, source: "Test") == 2)
        #expect(s.data.items.count == 8)
    }
    /// Item, 購入日 and Buy on Market decide it, and nothing else does. The
    /// same purchase re-exported with the Sell on column changed is the same
    /// purchase: flagged, and left off unless the user says otherwise.
    @Test func onlySellOnDiffersAndItIsStillTheSamePurchase() {
        let s = store()
        #expect(s.commitImport(s.parseImport(Self.sheet), source: "Test") == 8)

        let header = "Item\t購入日\tBuy\tBuy on Market\tSell on\n"
        // Sigma 56: same name, same day, same market — Rakuma instead of PayPay,
        // and a different buy price, because neither is what tells two things apart.
        let changed = header + "Sigma 56 F1.4 M43\t2024/02/08\t¥40,000\tKitamura\tRakuma"
        let preview = s.parseImport(changed)
        #expect(preview.rows.count == 1)
        #expect(preview.rows[0].duplicate == .exact)
        #expect(preview.rows[0].include == false)
        #expect(s.commitImport(preview, source: "Test") == 0)

        // A different Buy on Market is a different purchase: badged so it can
        // be looked at, counted as no duplicate, and switched on.
        let elsewhere = header + "Sigma 56 F1.4 M43\t2024/02/08\t¥36,500\tMap Camera\tPayPay"
        let other = s.parseImport(elsewhere)
        #expect(other.rows[0].duplicate == .sameNameAndDate)
        #expect(other.rows[0].isDuplicate == false)
        #expect(other.rows[0].include == true)
        #expect(other.duplicateCount == 0)

        // A different day is two lenses, and comes in by default.
        let laterDay = header + "Sigma 56 F1.4 M43\t2025/02/08\t¥36,500\tKitamura\tPayPay"
        let second = s.parseImport(laterDay)
        #expect(second.rows[0].duplicate == .sameNameOnly)
        #expect(second.rows[0].include == true)
        #expect(second.duplicateCount == 0)
    }

    /// A sheet row that says sold, on a purchase the book already holds, is
    /// not a repeat to skip: it writes the sale over the item, keeps its id,
    /// and keeps what the sheet had no column for. Undo puts it back.
    @Test func aSoldRowOverwritesThePurchaseTheBookAlreadyHas() {
        let s = store()
        #expect(s.commitImport(s.parseImport(Self.sheet), source: "Test") == 8)
        let before = s.data.items.first { $0.name == "Sigma 56 F1.4 M43" }!
        #expect(before.isSold == false)

        let sold = "Item\t購入日\tBuy\tBuy on Market\tSold?\tSell Price\tSell on\tSold date\tIncome\n" +
            "Sigma 56 F1.4 M43\t2024/02/08\t¥36,500\tKitamura\tTRUE\t¥44,000\tMercari\t2026/06/01\t¥38,600"
        let preview = s.parseImport(sold)
        #expect(preview.rows[0].duplicate == .exact)
        // An update is not a duplicate to skip: it is on, and the chips above
        // the list have nothing to switch.
        #expect(preview.rows[0].isUpdate == true)
        #expect(preview.rows[0].include == true)
        #expect(preview.duplicateCount == 0)
        // It has its own control above the list, so "Skip them" is never
        // claiming to have stopped something that still changes the book.
        #expect(preview.updateCount == 1)
        #expect(preview.includedUpdateCount == 1)

        // Switched off, it writes nothing at all.
        var left = preview
        left.rows[0].include = false
        #expect(left.includedUpdateCount == 0)
        #expect(s.commitImport(left, source: "Test") == 0)
        #expect(s.data.items.first { $0.name == "Sigma 56 F1.4 M43" }?.isSold == false)

        #expect(s.commitImport(preview, source: "Test") == 1)
        // No second copy, and the item is the same item.
        #expect(s.data.items.filter { $0.name == "Sigma 56 F1.4 M43" }.count == 1)
        let after = s.data.items.first { $0.name == "Sigma 56 F1.4 M43" }!
        #expect(after.id == before.id)
        #expect(after.sale?.price == 44_000)
        #expect(after.sale?.net == 38_600)
        #expect(after.keep == false)

        // Undo gives back exactly what it took: the item as it stood, not a hole.
        let batch = s.importHistory.first!
        #expect(batch.count == 0)          // nothing added
        #expect(batch.updatedCount == 1)   // one item marked sold
        #expect(s.deleteImportBatch(batch) == 1)
        #expect(s.data.items.filter { $0.name == "Sigma 56 F1.4 M43" }.count == 1)
        #expect(s.data.items.first { $0.name == "Sigma 56 F1.4 M43" }?.isSold == false)
    }

    /// The rows land in the book in the order the sheet wrote them, and the
    /// duplicate chips open on "Skip them" — nothing flagged is switched on
    /// until the reader switches it on.
    @Test func rowsKeepTheSheetsOrderAndDuplicatesStartOff() {
        let s = store()
        #expect(s.commitImport(s.parseImport(Self.sheet), source: "Test") == 8)
        #expect(s.data.items.prefix(3).map(\.name)
                == ["Osprey Tenpo 33", "OM BLX-1 Battery", "Olympus MC-14"])

        // Seven repeats to skip; the two sold rows are updates, not repeats.
        let again = s.parseImport(Self.sheet)
        #expect(again.duplicateCount == 7)
        #expect(again.includedDuplicateCount == 0)
        #expect(again.rows.filter { $0.include }.allSatisfy { $0.isUpdate })
    }
    /// The same book kept a second way: no 購入日 column at all, so every row
    /// comes in dated today. Two lines that agree on name and market are then
    /// indistinguishable from one line typed twice, and the book says they are
    /// two things — a battery sold and a battery still held, two Z8s at
    /// different prices, two identical chairs. All of them come in.
    static let datelessSheet =
        "Sold?\tItem\tThẻ vợ\tBuy\tBuy on Market\t% Point\tEarn Point\tNew price\tSell Price\tSell on\tShipping Fee\tIncome\tProfit\n" +
        "FALSE\tOsprey Tenpo 33\t\t¥27,000\tLocal\t11.0%\t¥2,970\t\t\t\t¥850\t#N/A\t#N/A\n" +
        "TRUE\tOM BLX-1 Battery\t\t¥5,000\tPayPay\t1.0%\t¥50\t\t¥5,000\tRakuma\t¥0\t¥4,775\t-¥225\n" +
        "FALSE\tOM BLX-1 Battery\t\t¥5,000\tPayPay\t1.0%\t¥50\t\t¥5,000\tRakuma\t¥1,000\t¥3,775\t-¥1,225\n" +
        "TRUE\tZ8\t\t¥450,000\tMercari\t2.0%\t¥9,000\t\t¥480,000\tRakuma\t¥1,000\t¥457,400\t¥7,400\n" +
        "FALSE\tZ8\tRakuten\t¥460,000\tMercari\t2.0%\t¥9,200\t\t¥498,000\tRakuma\t¥0\t¥475,590\t¥15,590\n" +
        "FALSE\t\t\t\t\t\t¥0\t\t\tRakuma\t¥1,000\t-¥1,000\t-¥1,000"

    @Test func aSheetWithNoPurchaseDateBringsEveryRowIn() {
        let s = store()
        let preview = s.parseImport(Self.datelessSheet)

        #expect(preview.recognisedHeader)
        #expect(preview.rows.count == 5)
        // The last line has figures but no name: it is not an item.
        #expect(preview.failures.map(\.line) == [7])
        #expect(!preview.usedColumns.contains("Date"))

        // Nothing is blocked: without a purchase date there is no way to tell
        // two of a thing from one written twice, so the sheet is taken at its
        // word. The repeat is still said, on the row.
        #expect(preview.duplicateCount == 0)
        #expect(preview.includedCount == 5)
        let repeated = preview.rows.filter { $0.duplicate == .sameNameOnly }
        #expect(repeated.map { $0.item.name } == ["OM BLX-1 Battery", "Z8"])
        #expect(repeated.allSatisfy { $0.include })

        // Sold? FALSE with no Sell on is stock, not something being kept.
        #expect(preview.rows[0].item.keep == false)
        #expect(preview.rows[0].item.isSold == false)

        // Sold? TRUE takes Sell Price as the sale and Income as what arrived.
        let sold = preview.rows[1].item
        #expect(sold.sale?.price == 5_000)
        #expect(sold.sale?.net == 4_775)
        #expect(sold.pointsEarned == 50)

        #expect(s.commitImport(preview, source: "Test") == 5)
        #expect(s.data.items.map(\.name)
                == ["Osprey Tenpo 33", "OM BLX-1 Battery", "OM BLX-1 Battery", "Z8", "Z8"])
        // Both Z8s, at the prices the sheet gave them.
        #expect(s.data.items.filter { $0.name == "Z8" }.map(\.buyPrice) == [450_000, 460_000])
    }
}
