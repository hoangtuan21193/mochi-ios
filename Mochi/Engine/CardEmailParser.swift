import Foundation

/// A card's "you just used your card" email (カード利用のお知らせ), read on the
/// phone from the Subject and Body a Shortcuts Mail automation passes over.
/// Pure, so a test can hold an email and the spend it must give. It would
/// rather read nothing than guess: an email without a figure and a shop is
/// not a spend.
struct CardEmail: Equatable {
    var date: Date?
    var merchant: String
    var amount: Int
    /// The issuer the email names (楽天カード, JCB), matched to a card in the
    /// book by `CardEmailParser.card(for:in:)`.
    var issuer: String
}

enum CardEmailParser {
    /// Issuers whose emails are known, each with the words that name it in a
    /// subject or a sender and the words a card in the book is called by.
    static let issuers: [(name: String, says: [String], card: [String])] = [
        ("Rakuten Card", ["楽天カード", "rakuten"], ["rakuten", "楽天"]),
        ("JCB", ["jcb"], ["jcb"]),
        ("SMBC Card", ["三井住友カード", "smbc", "vpass"], ["smbc", "三井住友"]),
        ("Saison", ["セゾン", "saison"], ["saison", "セゾン"]),
        ("AEON Card", ["イオンカード", "aeon"], ["aeon", "イオン"]),
        ("PayPay Card", ["paypayカード", "paypay card"], ["paypay card", "paypayカード"]),
    ]

    static func parse(subject: String, body: String, calendar: Calendar = .current) -> CardEmail? {
        let text = fold(subject + "\n" + body)
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let amount = value(after: ["ご利用金額", "利用金額", "ご請求金額", "金額"], in: lines).flatMap(yen),
              let merchant = value(after: ["ご利用先", "利用先", "ご利用店名", "利用店名", "ご利用加盟店", "加盟店名"], in: lines),
              !merchant.isEmpty else { return nil }
        let date = value(after: ["ご利用日時", "ご利用日", "利用日"], in: lines).flatMap { day($0, calendar) }
        let lower = text.lowercased()
        let issuer = issuers.first { $0.says.contains { lower.contains($0.lowercased()) } }?.name ?? ""
        return CardEmail(date: date, merchant: merchant, amount: amount, issuer: issuer)
    }

    /// The card in the book this email is about: the one whose name carries
    /// the issuer's words. nil when none, or more than one, does — a guess
    /// between two JCB cards would book the spend on the wrong one.
    static func card(for email: CardEmail, in cards: [CreditCard]) -> CreditCard? {
        guard let words = issuers.first(where: { $0.name == email.issuer })?.card else { return nil }
        let hits = cards.filter { c in words.contains { c.name.lowercased().contains($0) } }
        return hits.count == 1 ? hits[0] : nil
    }

    /// Full-width digits, letters, colons and spaces folded to ASCII, so
    /// "３，２８０円" and "3,280円" read alike. Only that block: the system's
    /// full-to-half transform would turn カード into half-width ｶｰﾄﾞ too.
    static func fold(_ s: String) -> String {
        String(String.UnicodeScalarView(s.unicodeScalars.map { u in
            switch u.value {
            case 0xFF01...0xFF5E: return Unicode.Scalar(u.value - 0xFEE0)!
            case 0x3000: return " "
            default: return u
            }
        }))
    }

    /// What follows a label on its line — "ご利用先:AMAZON" or "■ご利用先 AMAZON" —
    /// or, when the label stands alone, the next line that is not empty.
    private static func value(after labels: [String], in lines: [String]) -> String? {
        for label in labels {
            for (i, line) in lines.enumerated() {
                guard let r = line.range(of: label) else { continue }
                var rest = String(line[r.upperBound...])
                rest = rest.trimmingCharacters(in: CharacterSet(charactersIn: " :：　\t■・】」"))
                if !rest.isEmpty { return rest }
                if let next = lines[(i + 1)...].first(where: { !$0.isEmpty }) { return next }
            }
        }
        return nil
    }

    private static func yen(_ s: String) -> Int? {
        let digits = s.prefix { $0.isNumber || $0 == "," || $0 == " " }.filter(\.isNumber)
        return Int(digits).flatMap { $0 > 0 ? $0 : nil }
    }

    private static func day(_ s: String, _ calendar: Calendar) -> Date? {
        let parts = s.split { !$0.isNumber }.compactMap { Int($0) }
        guard parts.count >= 3, parts[0] > 2000 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

extension Finance {
    /// A spend already booked for the same tap: same day, same card, same
    /// amount. A card that sends an email and an Apple Pay tap for one
    /// payment hands both over, and the book keeps it once.
    static func sameSpend(_ data: AppData, amount: Int, account: String, on day: Date) -> Transaction? {
        let cal = Calendar.current
        return (data.transactions ?? []).first {
            $0.kind == .spend && -$0.amount == amount && $0.account == account && cal.isDate($0.date, inSameDayAs: day)
        }
    }
}
