import Foundation
import Testing
@testable import Mochi

/// Moving a book, or parts of it, between phones: what a file carries, and
/// what replacing or merging a part does to the book it lands in.
struct BookTransferTests {
    let day = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func item(_ id: String, _ name: String) -> Item {
        Item(id: id, name: name, boughtOn: day, buyPrice: 1000, cardName: "", estimatedPrice: 1200, plannedChannel: "")
    }

    func book() -> AppData {
        var b = AppData()
        b.items = [item("a", "Lens A"), item("b", "Body B")]
        b.wallets = [Wallet(name: "SMBC", balance: 100_000)]
        b.transactions = [Transaction(date: day, amount: 1000, kind: .asset, account: "SMBC", itemID: "b")]
        b.installments = [Installment(name: "Body plan", principal: 60_000, months: 12, firstAmount: 5000, firstDate: day, itemID: "b")]
        b.currency = "¥"
        return b
    }

    @Test func anExportCarriesOnlyThePartsPickedAndSaysWhich() throws {
        let out = BookTransfer.export(book(), groups: [.belongings])
        let back = try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(out))
        #expect(back.items.count == 2)
        #expect(back.wallets.isEmpty && back.transactions == nil)
        #expect(BookTransfer.groups(in: back) == [.belongings])
    }

    @Test func replacingBelongingsLeavesEveryOtherPartAlone() {
        var file = AppData()
        file.items = [item("c", "Lens C")]
        file.exportedGroups = ["belongings"]
        let out = BookTransfer.apply(file, to: book(), groups: [.belongings], mode: .replace)
        #expect(out.items.map(\.id) == ["c"])
        #expect(out.wallets.map(\.name) == ["SMBC"])
        #expect(out.transactions?.count == 1)
        #expect(out.exportedGroups == nil)
    }

    @Test func aLinkToAnItemThatWentIsDroppedNotTheThingThatLinked() {
        var file = AppData()
        file.items = [item("c", "Lens C")]
        let out = BookTransfer.apply(file, to: book(), groups: [.belongings], mode: .replace)
        #expect(out.installments?.first?.itemID == nil)
        #expect(out.installments?.count == 1)
        #expect(out.transactions?.first?.itemID == nil)
    }

    @Test func mergingKeepsTheBooksAddsTheFilesAndTakesTheFilesCopyOfBoth() {
        var file = AppData()
        var renamed = item("a", "Lens A (sold)")
        renamed.estimatedPrice = 900
        file.items = [renamed, item("c", "Lens C")]
        let out = BookTransfer.apply(file, to: book(), groups: [.belongings], mode: .merge)
        #expect(out.items.map(\.id) == ["a", "b", "c"])
        #expect(out.items[0].name == "Lens A (sold)")
        #expect(out.installments?.first?.itemID == "b")
    }

    @Test func settingsAreReplacedEvenWhenMerging() {
        var file = AppData()
        file.currency = "₫"
        let out = BookTransfer.apply(file, to: book(), groups: [.settings], mode: .merge)
        #expect(out.currency == "₫")
    }

    @Test func aPartTheFileLacksIsNotOfferedAndAnEqualOneIsNotPicked() {
        let b = book()
        let file = BookTransfer.export(b, groups: [.belongings, .money])
        #expect(BookTransfer.groups(in: file) == [.belongings, .money])
        #expect(!BookTransfer.differs(.belongings, book: b, file: file))
        var changed = file
        changed.items.removeLast()
        #expect(BookTransfer.differs(.belongings, book: b, file: changed))
    }

    @Test func thePreviewSaysWhatEachPartHoldsAfter() {
        var file = AppData()
        file.items = [item("c", "Lens C")]
        let replace = BookTransfer.preview(file, to: book(), groups: [.belongings], mode: .replace)
        #expect(replace == [.init(group: .belongings, before: 2, after: 1)])
        let merge = BookTransfer.preview(file, to: book(), groups: [.belongings], mode: .merge)
        #expect(merge == [.init(group: .belongings, before: 2, after: 3)])
    }

    @Test func aWholeBookReplacedTakesTheFilesLedgerStart() {
        var file = book()
        file.ledgerStart = day
        var mine = book()
        mine.ledgerStart = nil
        let partial = BookTransfer.apply(file, to: mine, groups: [.transactions], mode: .replace)
        #expect(partial.ledgerStart == nil)
        let whole = BookTransfer.apply(file, to: mine, groups: Set(BookGroup.allCases), mode: .replace)
        #expect(whole.ledgerStart == day)
    }
}
