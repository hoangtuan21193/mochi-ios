import Foundation

/// What a shop's item page says about itself, read from the tags it prints for
/// link previews: Mercari's `product:price:amount` and `og:title`, or the
/// schema.org `Offer` most shops carry. Pure — the share extension fetches the
/// page, this reads it — so every page shape has a test. Anything not found
/// stays nil: a guessed price is worse than an empty field (decision #39).
struct Listing: Equatable {
    var title: String?
    /// Whole units of `currency`; nil when the page has none, or has one in a
    /// currency other than the book's (then `foreignCurrency` says which).
    var price: Int?
    var foreignCurrency: String?
    /// The shop's own name for itself ("メルカリ"), before `shopName` maps it.
    var site: String?
    var image: URL?
}

enum ListingReader {

    /// - Parameter currency: the book's ISO code; a price in any other is not taken.
    static func read(html: String, currency: String = "JPY") -> Listing {
        let meta = metaTags(html)
        var out = Listing()
        out.site = meta["og:site_name"]
        if let t = meta["og:title"] ?? meta["twitter:title"] ?? titleTag(html) {
            out.title = cleanTitle(t, site: out.site)
        }
        out.image = (meta["og:image"] ?? meta["twitter:image"]).flatMap(URL.init(string:))

        let (amount, code) = meta["product:price:amount"].map { ($0, meta["product:price:currency"]) }
            ?? meta["og:price:amount"].map { ($0, meta["og:price:currency"]) }
            ?? offer(html)
        if let amount, let value = whole(amount) {
            if let code, code.uppercased() != currency.uppercased() {
                out.foreignCurrency = code.uppercased()
            } else {
                out.price = value
            }
        }
        return out
    }

    /// The first web address in what was shared: Mercari hands over a URL, some
    /// apps a sentence with the link at its end.
    static func firstURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range)
            .compactMap(\.url)
            .first { $0.scheme == "https" || $0.scheme == "http" }
    }

    /// A page title without the shop's name on its end: "SONY α7III ボディ by
    /// メルカリ" → "SONY α7III ボディ", "… - Yahoo!フリマ（旧PayPayフリマ）" likewise.
    static func cleanTitle(_ raw: String, site: String?) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let r = t.range(of: " by メルカリ", options: [.backwards, .anchored]) { t.removeSubrange(r) }
        if let site = site?.trimmingCharacters(in: .whitespaces), !site.isEmpty {
            for sep in [" - ", " | ", "｜", " / ", " – "] {
                if let r = t.range(of: sep, options: .backwards),
                   t[r.upperBound...].localizedCaseInsensitiveContains(site) {
                    t.removeSubrange(r.lowerBound...)
                    break
                }
            }
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The shop as the book names it. A name the book already uses wins, so
    /// a page saying "メルカリ" lands on the "Mercari" every other item has.
    static func shopName(site: String?, host: String?, known: [String]) -> String {
        let candidates = [site.flatMap { alias[$0] }, host.flatMap(hostAlias), site].compactMap { $0 }
        for c in candidates {
            if let k = known.first(where: { $0.caseInsensitiveCompare(c) == .orderedSame }) { return k }
        }
        return candidates.first ?? host ?? ""
    }

    // MARK: - Pieces

    private static let alias: [String: String] = [
        "メルカリ": "Mercari", "ラクマ": "Rakuma", "楽天ラクマ": "Rakuma",
        "ヤフオク!": "Yahoo! Auctions", "Yahoo!オークション": "Yahoo! Auctions",
        "Yahoo!フリマ": "PayPay Flea", "PayPayフリマ": "PayPay Flea", "楽天市場": "Rakuten",
    ]

    private static func hostAlias(_ host: String) -> String? {
        let h = host.lowercased()
        let table: [(String, String)] = [
            ("mercari.com", "Mercari"), ("merc.li", "Mercari"), ("fril.jp", "Rakuma"),
            ("auctions.yahoo.co.jp", "Yahoo! Auctions"), ("paypayfleamarket.yahoo.co.jp", "PayPay Flea"),
            ("rakuten.co.jp", "Rakuten"), ("amazon.co.jp", "Amazon"), ("mapcamera.com", "MapCamera"),
            ("kitamura.jp", "Kitamura"), ("2ndstreet.jp", "2nd Street"), ("hardoff.co.jp", "Hard Off"),
        ]
        return table.first { h == $0.0 || h.hasSuffix("." + $0.0) }?.1
    }

    /// Every `<meta>` with a property or name and a content, attributes in any order.
    private static func metaTags(_ html: String) -> [String: String] {
        var out: [String: String] = [:]
        for tag in matches(#"<meta\b[^>]*>"#, in: html) {
            guard let key = attribute("property", in: tag) ?? attribute("name", in: tag),
                  let content = attribute("content", in: tag) else { continue }
            let k = key.lowercased()
            if out[k] == nil { out[k] = decodeEntities(content) }
        }
        return out
    }

    private static func attribute(_ name: String, in tag: String) -> String? {
        for q in ["\"", "'"] {
            if let v = matches(#"\b\#(name)\s*=\s*\#(q)([^\#(q)]*)\#(q)"#, in: tag, group: 1).first { return v }
        }
        return nil
    }

    private static func titleTag(_ html: String) -> String? {
        matches(#"<title[^>]*>([^<]*)</title>"#, in: html, group: 1).first.map(decodeEntities)
            .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }

    /// schema.org `Offer` in a JSON-LD block: the shops that print no price tag.
    private static func offer(_ html: String) -> (String?, String?) {
        for block in matches(#"<script[^>]*application/ld\+json[^>]*>([\s\S]*?)</script>"#, in: html, group: 1)
        where block.contains("Offer") {
            let price = matches(#""price"\s*:\s*"?([0-9][0-9.,]*)"#, in: block, group: 1).first
            let code = matches(#""priceCurrency"\s*:\s*"([A-Za-z]{3})""#, in: block, group: 1).first
            if price != nil { return (price, code) }
        }
        return (nil, nil)
    }

    /// "105000", "105,000", "105000.0" → 105000. A figure with real cents is a
    /// foreign price and was turned away before this.
    private static func whole(_ s: String) -> Int? {
        let digits = s.replacingOccurrences(of: ",", with: "")
        guard let v = Double(digits), v > 0, v < 1_000_000_000 else { return nil }
        return Int(v.rounded())
    }

    private static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var t = s
        for (k, v) in [("&quot;", "\""), ("&#39;", "'"), ("&#x27;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " "), ("&amp;", "&")] {
            t = t.replacingOccurrences(of: k, with: v)
        }
        return t
    }

    private static func matches(_ pattern: String, in s: String, group: Int = 0) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap {
            Range($0.range(at: group), in: s).map { String(s[$0]) }
        }
    }
}
