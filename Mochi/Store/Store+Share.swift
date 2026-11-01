import Foundation

/// Share › Mochi (docs/design/share-from-shops.md). The extension saves what
/// was bought into the App Group; the app books it here, as Add a belonging
/// would, so the purchase is in Transactions on the account that paid.
extension Store {

    var lookUpListings: Bool { data.lookUpListings ?? true }

    func setLookUpListings(_ on: Bool) {
        data.lookUpListings = on
        save()
    }

    /// Rewritten with the widget's file on every save, so the sheet offers the
    /// accounts the book has now.
    func publishShareSnapshot() {
        ShareInbox.write(Self.shareSnapshot(of: data))
    }

    static func shareSnapshot(of data: AppData) -> ShareSnapshot {
        // Newest purchase last, so the dictionary ends up holding the latest per shop.
        let bought = data.items.filter { !$0.boughtFrom.isEmpty }.sorted { $0.boughtOn < $1.boughtOn }
        var lastAccount: [String: String] = [:]
        var lastResell: [String: Bool] = [:]
        for item in bought {
            if !item.cardName.isEmpty { lastAccount[item.boughtFrom] = item.cardName }
            lastResell[item.boughtFrom] = item.boughtToResell
        }
        var links: [String: ShareSnapshot.Known] = [:]
        for item in data.items { if let link = item.link { links[link] = .init(name: item.name, date: item.boughtOn) } }
        var shops = Set(bought.map(\.boughtFrom))
        shops.formUnion(data.channels.map(\.name))
        return ShareSnapshot(accounts: data.wallets.map(\.name) + data.cards.map(\.name),
                             lastAccount: lastAccount,
                             resellShops: lastResell.filter(\.value).map(\.key).sorted(),
                             shops: shops.sorted(),
                             links: links,
                             lookUpListings: data.lookUpListings ?? true,
                             currency: data.currency)
    }

    /// Books whatever the share sheet left, then clears it. Run on launch and
    /// whenever the app comes back, which is when someone who just shared a
    /// page opens Mochi to look.
    func takeSharedEntries() {
        let waiting = ShareInbox.pending()
        guard !waiting.isEmpty else { publishShareSnapshot(); return }
        for (url, entry) in waiting {
            receive(entry)
            ShareInbox.remove(url)
        }
        save()
        publishShareSnapshot()
    }

    /// One shared purchase into the book. Its id becomes the item's (or the
    /// spend's), so a file read twice — the app quit between booking and
    /// clearing — is booked once.
    @discardableResult
    func receive(_ e: SharedEntry) -> Bool {
        guard e.price > 0,
              !data.items.contains(where: { $0.id == e.id }),
              !transactions.contains(where: { $0.id == e.id }) else { return false }
        // An account renamed or removed since the share is left empty rather
        // than guessed: the item comes in without a purchase booked, as one
        // added by hand with no account does.
        let account = accountNames.contains(e.account) ? e.account : ""
        switch e.purpose {
        case .spend:
            // Like an Apple Pay spend: it waits in To review for its category.
            var t = Transaction(date: e.date, amount: -e.price, kind: .spend, account: account,
                                merchant: e.shop, note: e.name)
            t.id = e.id
            t.needsReview = true
            addTransaction(t)
        case .sell, .use:
            let channel = data.channels.first { $0.name.caseInsensitiveCompare(e.shop) == .orderedSame }?.name
                ?? data.channels.first?.name ?? ""
            var item = Item(name: e.name, boughtOn: e.date, buyPrice: e.price, boughtFrom: e.shop,
                            cardName: account, estimatedPrice: e.price, plannedChannel: channel)
            item.id = e.id
            item.link = e.link
            item.boughtToResell = e.purpose == .sell
            item.keep = e.purpose == .use
            item.valueHistory = [ValuePoint(date: e.date, value: e.price)]
            addItem(item)
        }
        return true
    }
}
