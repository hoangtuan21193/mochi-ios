import Foundation
import Testing
@testable import Mochi

/// Share › Mochi: what the share sheet saved, booked by the app the way Add a
/// belonging books it — so a thing bought on Mercari is in Transactions on the
/// card that paid — and never twice.
struct ShareInboxTests {
    static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func store() -> Store {
        let s = Store(data: .empty)
        var a = AppData()
        a.wallets = [Wallet(name: "Bank", balance: 500_000)]
        a.cards = [CreditCard(name: "Rakuten card", dueDay: 27, debt: 0, closingDay: 31)]
        a.channels = [SalesChannel(name: "Mercari", rate: 10), SalesChannel(name: "Rakuma", rate: 6.6)]
        a.ledgerStart = Self.day(2026, 9, 1)
        a.postedThrough = Self.day(2026, 10, 31)
        a.transactions = []
        s.data = a
        return s
    }

    func entry(_ purpose: SharedEntry.Purpose, account: String = "Rakuten card", on date: Date = day(2026, 10, 12)) -> SharedEntry {
        SharedEntry(date: date, name: "SONY α7III ILCE-7M3 ボディ", price: 105_000, shop: "Mercari",
                    account: account, purpose: purpose, link: "https://jp.mercari.com/item/m42404194676")
    }

    @Test func aBelongingComesInWithItsPurchaseOnTheCard() {
        let s = store()
        let e = entry(.sell)
        #expect(s.receive(e))
        let item = s.data.items.first { $0.id == e.id }
        #expect(item?.buyPrice == 105_000 && item?.boughtFrom == "Mercari" && item?.cardName == "Rakuten card")
        #expect(item?.boughtToResell == true && item?.keep == false)
        #expect(item?.link == e.link)
        // Bought on Mercari to sell: planned for the same marketplace.
        #expect(item?.plannedChannel == "Mercari")
        let paid = s.data.transactions?.filter { $0.itemID == e.id } ?? []
        #expect(paid.count == 1)
        #expect(paid.first?.kind == .asset && paid.first?.amount == -105_000 && paid.first?.account == "Rakuten card")
    }

    @Test func toUseIsKept() {
        let s = store()
        let e = entry(.use)
        s.receive(e)
        #expect(s.data.items.first?.keep == true && s.data.items.first?.boughtToResell == false)
    }

    @Test func justASpendWaitsInToReviewAndIsNoBelonging() {
        let s = store()
        let e = entry(.spend)
        s.receive(e)
        #expect(s.data.items.isEmpty)
        let t = s.data.transactions?.first { $0.id == e.id }
        #expect(t?.kind == .spend && t?.needsReview == true && t?.amount == -105_000)
    }

    @Test func theSameEntryReadTwiceIsBookedOnce() {
        let s = store()
        let e = entry(.sell)
        #expect(s.receive(e))
        #expect(!s.receive(e))
        #expect(s.data.items.count == 1)
        #expect(s.data.transactions?.filter { $0.itemID == e.id }.count == 1)
    }

    @Test func anAccountGoneSinceTheShareIsLeftEmptyNotGuessed() {
        let s = store()
        let e = entry(.sell, account: "Old card")
        s.receive(e)
        #expect(s.data.items.first?.cardName == "")
        #expect(s.data.transactions?.isEmpty == true)
    }

    @Test func boughtBeforeTheLedgerItHasNoTransaction() {
        let s = store()
        let e = entry(.sell, on: Self.day(2026, 8, 1))
        s.receive(e)
        #expect(s.data.items.count == 1)
        #expect(s.data.transactions?.isEmpty == true)
    }

    @Test func theSnapshotRemembersEachShopsAccountAndPurpose() {
        let s = store()
        s.receive(entry(.sell))
        var other = entry(.use)
        other.id = UUID().uuidString
        other.shop = "MapCamera"
        other.account = "Bank"
        other.link = nil
        s.receive(other)
        let snap = Store.shareSnapshot(of: s.data)
        #expect(snap.accounts == ["Bank", "Rakuten card"])
        #expect(snap.lastAccount["Mercari"] == "Rakuten card" && snap.lastAccount["MapCamera"] == "Bank")
        #expect(snap.resellShops == ["Mercari"])
        #expect(snap.shops.contains("Rakuma") && snap.shops.contains("MapCamera"))
        #expect(snap.links["https://jp.mercari.com/item/m42404194676"]?.name == "SONY α7III ILCE-7M3 ボディ")
        #expect(snap.lookUpListings && snap.currency == "¥")
    }
}
