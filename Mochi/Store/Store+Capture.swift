import Foundation
import UIKit

/// Turning what a receipt said into a transaction ready to review, filled
/// from the book's memory: the shop by its registration number, the card by
/// its last four digits, the category by a rule or by what was chosen there
/// last time. Every guess says where it came from, so the review sheet can
/// mark the ones worth a look.
extension Store {

    struct CaptureGuess {
        /// New for every reading, so the review can tell a fresher one arrived.
        var id = UUID()
        var transaction: Transaction
        var draft: ReceiptDraft
        /// Why each field is what it is, for the line under it.
        var shopReason: String
        var accountReason: String
        var categoryReason: String
        /// A line worth tracking as a belonging, if one is — its price in the
        /// book's money, converted where the receipt is in another.
        var belongingLine: ReceiptDraft.Line?
        /// Why the receipt is taken to be in another currency, when it is.
        var currencyReason: String?
    }

    func guess(from draft: ReceiptDraft, receiptFile: String?, latitude: Double?, longitude: Double?) -> CaptureGuess {
        var t = Transaction(date: draft.date ?? .now, amount: -(draft.total ?? 0), kind: .spend,
                            account: "", merchant: draft.merchant, source: .scan)
        t.receiptFile = receiptFile
        t.latitude = latitude
        t.longitude = longitude
        t.registration = draft.registration
        var shopReason = draft.merchant.isEmpty ? String(localized: "Not in the photo · type it, or scan the top")
                                                : String(localized: "Read from the receipt")
        // Said only when there is a reason; the picker speaks for itself.
        var accountReason = ""
        var categoryReason = String(localized: "Pick one")

        // The same shop before: by registration number first, then by name.
        let before = transactions.sorted { $0.date > $1.date }.first { old in
            if let r = draft.registration, old.registration == r { return true }
            return !draft.merchant.isEmpty && Finance.searchKey(old.merchant).letters == Finance.searchKey(draft.merchant).letters
        }
        if let before {
            t.merchant = before.merchant
            let seen = transactions.filter { $0.merchant == before.merchant }.count
            shopReason = draft.registration != nil && before.registration == draft.registration
                ? String(localized: "Known by its registration number · seen \(seen)×")
                : String(localized: "Seen here \(seen)× before")
        }

        // The card by its last four; otherwise how it was paid.
        if let last4 = draft.cardLast4, let card = data.cards.first(where: { $0.last4 == last4 }) {
            t.account = card.name
            accountReason = String(localized: "Card ending \(last4) on the receipt")
        } else if draft.payment == .payPay, let w = data.wallets.first(where: { $0.name.localizedCaseInsensitiveContains("paypay") }) {
            t.account = w.name
            accountReason = String(localized: "PayPay on the receipt")
        } else if draft.payment == .cash, let w = data.wallets.first(where: { $0.name.localizedCaseInsensitiveContains("cash") || $0.name.contains("現金") }) {
            t.account = w.name
            accountReason = String(localized: "Paid in cash")
        } else if let before, !before.account.isEmpty {
            t.account = before.account
            accountReason = String(localized: "What you paid with there last time")
        } else if let last4 = draft.cardLast4 {
            accountReason = String(localized: "Card ending \(last4) · which card is it?")
            t.account = data.cards.first?.name ?? data.wallets.first?.name ?? ""
        } else {
            t.account = data.wallets.first?.name ?? ""
        }

        // The category: a rule, then what was picked there before.
        if let rule = Finance.rule(for: t.merchant, latitude: latitude, longitude: longitude, data), !rule.ask {
            t.category = rule.category
            categoryReason = String(localized: "Your rule for this shop")
        } else if let before, !before.category.isEmpty {
            t.category = before.category
            let n = transactions.filter { $0.merchant == before.merchant && $0.category == before.category }.count
            categoryReason = String(localized: "Picked here last \(n) times")
        }

        // Another currency: the receipt's figures are kept as printed and
        // turned into the book's at the last rate typed for it. With no rate
        // yet there is no amount, and the review asks for one.
        var currencyReason: String?
        var rate: Double?
        if let code = draft.currency, code != currency.code {
            rate = data.rates?[code]
            t.currency = code
            t.foreignAmount = draft.exactTotal
            t.rate = rate
            t.amount = -(rate.flatMap { r in draft.exactTotal.map { Finance.convert($0, rate: r) } } ?? 0)
            currencyReason = rate == nil ? String(localized: "\(code) on the receipt · type the rate")
                                         : String(localized: "\(code) on the receipt · at the rate you used last")
        }
        func inBook(_ price: Int) -> Int? {
            guard t.currency != nil else { return price }
            return rate.map { Finance.convert(Double(price), rate: $0) }
        }

        let threshold = Finance.rule(for: t.merchant, data)?.belongingOver ?? notificationPrefs.largeSpendOver
        let costly = draft.lines.compactMap { l in inBook(l.price).map { ReceiptDraft.Line(name: l.name, price: $0) } }
        let total = t.currency == nil ? draft.total : (t.amount == 0 ? nil : -t.amount)
        let big = costly.filter { $0.price >= threshold }.max { $0.price < $1.price }
            ?? ((total ?? 0) >= threshold && draft.lines.count <= 1 ? costly.first ?? .init(name: draft.merchant, price: total ?? 0) : nil)

        return CaptureGuess(transaction: t, draft: draft, shopReason: shopReason, accountReason: accountReason,
                            categoryReason: categoryReason, belongingLine: big, currencyReason: currencyReason)
    }

    /// What the live camera has read so far, said the way the book knows it:
    /// the shop with how often it has been seen, the card by its name.
    struct FoundField: Identifiable {
        enum Kind { case total, when, shop, card }
        let kind: Kind
        let value: String
        var id: Kind { kind }
    }

    func foundFields(_ draft: ReceiptDraft) -> [FoundField] {
        var out: [FoundField] = []
        let money = draft.currency.flatMap(Currency.init(code:)) ?? currency
        if let t = draft.exactTotal { out.append(.init(kind: .total, value: money.format(exact: t))) }
        if let d = draft.date { out.append(.init(kind: .when, value: d.formatted(.dateTime.day().month(.abbreviated).hour().minute()))) }
        if !draft.merchant.isEmpty {
            let known = transactions.first { old in
                if let r = draft.registration, old.registration == r { return true }
                return Finance.searchKey(old.merchant).letters == Finance.searchKey(draft.merchant).letters
            }
            if let known {
                let seen = transactions.filter { $0.merchant == known.merchant }.count
                out.append(.init(kind: .shop, value: String(localized: "\(known.merchant) (seen \(seen)×)")))
            } else {
                out.append(.init(kind: .shop, value: draft.merchant))
            }
        }
        if let c = draft.cardLast4 {
            let name = data.cards.first { $0.last4 == c }?.name
            out.append(.init(kind: .card, value: name.map { "••\(c) · \($0)" } ?? "••\(c)"))
        } else if draft.payment == .payPay {
            out.append(.init(kind: .card, value: "PayPay"))
        } else if draft.payment == .cash {
            out.append(.init(kind: .card, value: String(localized: "Cash")))
        }
        return out
    }

    /// A spend added from where the user is, filled from the place's history.
    func quickAddAt(_ place: Finance.Place, latitude: Double?, longitude: Double?) -> Transaction {
        var t = Transaction(date: .now, amount: -place.usualAmount, kind: .spend, account: place.account,
                            merchant: place.merchant, category: place.category, latitude: latitude, longitude: longitude)
        if let latitude, let longitude { t.placeName = Finance.placeName(near: latitude, longitude, data)?.name }
        return t
    }

    /// The receipt languages in the order most likely for this book: a book
    /// in đồng or a phone in Vietnamese reads Vietnamese first, one in yen
    /// Japanese first, anything else English.
    var receiptLanguages: [String] {
        if currency == .vnd || language == .vi { return ["vi-VT", "en-US", "ja-JP"] }
        if currency == .jpy || language == .ja { return ["ja-JP", "en-US", "vi-VT"] }
        return ["en-US", "ja-JP", "vi-VT"]
    }

    var lookUpPlaceNames: Bool { data.lookUpPlaceNames ?? true }

    func setLookUpPlaceNames(_ on: Bool) {
        data.lookUpPlaceNames = on
        save()
    }

    /// What to call the spot a receipt was scanned at. The book first — a
    /// name kept for a spend here, or the shop usually paid here — and only
    /// then Apple Maps, if the user allows it and there is a connection.
    /// The shop's name from Apple Maps, when the receipt's own name line did
    /// not say it surely: the book has not seen this shop (by registration
    /// number or name) and the receipt printed a phone number or an address.
    /// Off with the same switch as naming places.
    func shopFromMaps(_ guess: CaptureGuess) async -> (name: String, byPhone: Bool)? {
        guard asksMapsForShop(guess) else { return nil }
        let d = guess.draft
        return await NearbyPlace.shopName(phone: d.phone, address: d.address, partialName: d.merchant,
                                          near: guess.transaction.latitude, guess.transaction.longitude)
    }

    /// Whether `shopFromMaps` would ask at all, so the review only says it is
    /// asking when it is.
    func asksMapsForShop(_ guess: CaptureGuess) -> Bool {
        let d = guess.draft
        guard lookUpPlaceNames, d.phone != nil || d.address != nil,
              guess.transaction.merchant == d.merchant else { return false }
        return !transactions.contains { old in
            (d.registration != nil && old.registration == d.registration)
                || (!d.merchant.isEmpty && Finance.searchKey(old.merchant).letters == Finance.searchKey(d.merchant).letters)
        }
    }

    func placeName(latitude: Double, longitude: Double) async -> Finance.PlaceName? {
        if let known = Finance.placeName(near: latitude, longitude, data) { return known }
        guard lookUpPlaceNames, let area = await NearbyPlace.areaName(latitude: latitude, longitude: longitude) else { return nil }
        return Finance.PlaceName(name: area, source: .maps)
    }
}
