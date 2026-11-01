import Foundation
import Observation

/// What the share sheet holds while it is open: what was shared, what the page
/// said, and what the user changed. It reads the book only through the
/// snapshot the app leaves in the App Group, and writes only to the inbox.
@MainActor @Observable
final class ShareModel {
    enum Phase: Equatable {
        /// Opening the page.
        case reading
        /// The page gave its price, or the user is typing one after it did not.
        case ready
        /// No connection, no price on the page, or one in another currency.
        case unread(foreign: String?)
        /// Reading links is off in Your data: nothing was asked for.
        case off
        /// Mochi has never been opened, so there is no book to add to.
        case noBook
    }

    let snapshot: ShareSnapshot?
    var phase: Phase = .reading
    var name = ""
    var price = 0
    var shop = ""
    var account = ""
    var purpose: SharedEntry.Purpose = .use
    var image: URL?
    /// What the page asked; shown under Paid once the user may have paid less.
    private(set) var listed: Int?
    private(set) var link: URL?
    var saveFailed = false

    init(snapshot: ShareSnapshot?) {
        self.snapshot = snapshot
        account = snapshot?.accounts.first ?? ""
        if snapshot == nil { phase = .noBook }
    }

    var currency: Currency { snapshot.flatMap { Currency(rawValue: $0.currency) } ?? .jpy }
    var accounts: [String] { snapshot?.accounts ?? [] }
    /// The same page saved before, by link.
    var known: ShareSnapshot.Known? { link.flatMap { snapshot?.links[$0.absoluteString] } }
    var canSave: Bool { snapshot != nil && price > 0 && !name.trimmingCharacters(in: .whitespaces).isEmpty }
    var host: String? { link?.host }
    /// The account the shop was paid from last time, when that is the one picked.
    var accountIsRemembered: Bool { !shop.isEmpty && snapshot?.lastAccount[shop] == account && !account.isEmpty }

    // MARK: - Reading what was shared

    func load(_ items: [NSExtensionItem]) async {
        let (url, text) = await Self.extract(items)
        link = url
        // Whatever words came with the link name the thing until the page does.
        let words = text.map { t in url.map { t.replacingOccurrences(of: $0.absoluteString, with: "") } ?? t }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let words, !words.isEmpty { name = ListingReader.cleanTitle(words, site: nil) }
        shop = ListingReader.shopName(site: nil, host: url?.host, known: snapshot?.shops ?? [])
        rememberShop()
        guard let snapshot else { return }
        guard snapshot.lookUpListings else { phase = .off; return }
        guard let url else { phase = .unread(foreign: nil); return }
        phase = .reading
        guard let html = await Self.fetch(url) else { phase = .unread(foreign: nil); return }
        let listing = ListingReader.read(html: html, currency: currency.code)
        if let title = listing.title, !title.isEmpty { name = title }
        image = listing.image
        let named = ListingReader.shopName(site: listing.site, host: url.host, known: snapshot.shops)
        if !named.isEmpty, named != shop { shop = named; rememberShop() }
        if let p = listing.price {
            listed = p
            if price == 0 { price = p }
            phase = .ready
        } else {
            phase = .unread(foreign: listing.foreignCurrency)
        }
    }

    /// The account and the reason that shop was last bought from with.
    private func rememberShop() {
        guard let snapshot else { return }
        if let last = snapshot.lastAccount[shop], snapshot.accounts.contains(last) { account = last }
        purpose = snapshot.resellShops.contains(shop) ? .sell : .use
    }

    private static func extract(_ items: [NSExtensionItem]) async -> (URL?, String?) {
        var url: URL?
        var text: String?
        for item in items {
            if text == nil, let s = item.attributedContentText?.string, !s.isEmpty { text = s }
            for provider in item.attachments ?? [] {
                if url == nil, provider.hasItemConformingToTypeIdentifier("public.url"),
                   let u = try? await provider.loadItem(forTypeIdentifier: "public.url") as? URL, u.scheme?.hasPrefix("http") == true {
                    url = u
                } else if provider.hasItemConformingToTypeIdentifier("public.plain-text"),
                          let s = try? await provider.loadItem(forTypeIdentifier: "public.plain-text") as? String {
                    if text == nil { text = s }
                    if url == nil { url = ListingReader.firstURL(in: s) }
                }
            }
        }
        if url == nil, let text { url = ListingReader.firstURL(in: text) }
        return (url, text)
    }

    /// The one page, once, as Safari on an iPhone asks for it. No cookies, no
    /// cache, nothing from the book (decision #39).
    private static func fetch(_ url: URL) async -> String? {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 8
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                         forHTTPHeaderField: "User-Agent")
        request.setValue("ja-JP,ja;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        guard let (data, response) = try? await URLSession(configuration: config).data(for: request),
              (response as? HTTPURLResponse)?.statusCode ?? 0 < 400,
              data.count < 4_000_000 else { return nil }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .shiftJIS)
            ?? String(data: data, encoding: .japaneseEUC)
    }

    // MARK: - Saving

    var preview: String {
        let amount = currency.format(price)
        guard price > 0 else {
            if case .reading = phase { return String(localized: "Added as a belonging, not as spending, once the price is in.") }
            return purpose == .spend ? String(localized: "Saved as a spend once you type the price.")
                : String(localized: "Added as a belonging, not as spending, once you type the price.")
        }
        switch (purpose, account.isEmpty) {
        case (.spend, false):
            return String(localized: "A spend of \(amount) on \(account), waiting in To review for its category. It reaches your book the next time Mochi opens.")
        case (.spend, true):
            return String(localized: "A spend of \(amount), waiting in To review for its category and account. It reaches your book the next time Mochi opens.")
        case (_, false):
            return String(localized: "Added as a belonging, not as spending: \(amount) on \(account). It reaches your book the next time Mochi opens.")
        case (_, true):
            return String(localized: "Added as a belonging for \(amount), paid from no account yet. It reaches your book the next time Mochi opens.")
        }
    }

    func save() -> Bool {
        let entry = SharedEntry(date: .now, name: name.trimmingCharacters(in: .whitespacesAndNewlines), price: price,
                                shop: shop.trimmingCharacters(in: .whitespaces), account: account,
                                purpose: purpose, link: link?.absoluteString)
        do { try ShareInbox.add(entry); return true } catch { saveFailed = true; return false }
    }
}
