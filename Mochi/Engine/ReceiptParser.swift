import Foundation

/// What a receipt says, read from its text lines — Japanese first, English
/// and Vietnamese too. Pure: the camera and Vision hand over lines, this
/// finds the total, the date, the shop, the registration number, the card
/// and the lines bought. Every rule is here so a test can hold a receipt and
/// the answer it must give.
///
/// It would rather leave a field empty than fill it wrongly: a shop name
/// taken from a product line, or a total guessed from the dearest item, is
/// believed at a glance, and an empty field is not.
struct ReceiptDraft: Equatable {
    struct Line: Equatable, Hashable {
        var name: String
        var price: Int
    }
    var merchant: String = ""
    /// The total as printed, cents and all: "$25.35" is 25.35. A receipt in
    /// another currency keeps this as what was paid (`foreignAmount`).
    var exactTotal: Double? = nil
    /// The total in whole units — what the yen side, the line check and the
    /// reading's score work in. Setting it drops any cents.
    var total: Int? {
        get { exactTotal.map { Int($0.rounded()) } }
        set { exactTotal = newValue.map(Double.init) }
    }
    var date: Date? = nil
    /// 適格請求書発行事業者登録番号: T and thirteen digits. The same shop has the
    /// same number on every receipt, so it identifies the shop better than
    /// its name, which OCR spells a different way each time.
    var registration: String? = nil
    var phone: String? = nil
    /// The shop's address as printed (〒 and the prefecture onwards), so the
    /// review can say where the receipt was issued, not only where the phone
    /// was.
    var address: String? = nil
    var cardLast4: String? = nil
    var payment: Payment = .unknown
    var lines: [Line] = []
    /// Printed in Japanese, so the review can name the total 合計.
    var japanese = false
    /// The money the receipt is in, as an ISO code ("VND"), when it says:
    /// a symbol or code by the figures, or the language around them. Every
    /// figure above is in it, not in the book's.
    var currency: String? = nil

    enum Payment: String { case unknown, cash, card, payPay, transitIC, iD, quicPay }

    /// How sure the parser is of each field, for the review sheet to mark the
    /// ones worth a glance.
    var totalMatchesLines: Bool {
        guard let total, !lines.isEmpty else { return false }
        return lines.reduce(0) { $0 + $1.price } == total
    }

    /// The head of the receipt was not in the picture: lines or a total, and
    /// nothing that names the shop.
    var missingTop: Bool {
        merchant.isEmpty && registration == nil && (total != nil || !lines.isEmpty)
    }

    /// The foot was not: lines bought, and no total under them.
    var missingBottom: Bool { total == nil && !lines.isEmpty }
}

extension ReceiptDraft {
    /// This draft with the gaps filled from `other`. With `preferringOther`
    /// every field `other` has wins (the live camera: the newest frame is the
    /// best look); without it only what this one lacks is taken (the photo:
    /// it is sharper, so what it read stands, and the live frames only fill
    /// what it missed).
    func filled(from other: ReceiptDraft, preferringOther: Bool = false) -> ReceiptDraft {
        func pick<T>(_ mine: T?, _ theirs: T?) -> T? { preferringOther ? (theirs ?? mine) : (mine ?? theirs) }
        var d = self
        d.merchant = pick(merchant.isEmpty ? nil : merchant, other.merchant.isEmpty ? nil : other.merchant) ?? ""
        d.exactTotal = pick(exactTotal, other.exactTotal)
        d.date = pick(date, other.date)
        d.registration = pick(registration, other.registration)
        d.phone = pick(phone, other.phone)
        d.address = pick(address, other.address)
        d.cardLast4 = pick(cardLast4, other.cardLast4)
        d.payment = pick(payment == .unknown ? nil : payment, other.payment == .unknown ? nil : other.payment) ?? .unknown
        d.lines = pick(lines.isEmpty ? nil : lines, other.lines.isEmpty ? nil : other.lines) ?? []
        d.japanese = japanese || other.japanese
        d.currency = pick(currency, other.currency)
        return d
    }

    /// Two photos of one long receipt, joined. Whichever has the head goes
    /// first; the lines are laid end to end, and the lines both photos caught
    /// where they overlap are kept once. Every other field is filled from
    /// whichever part has it.
    func joined(with other: ReceiptDraft) -> ReceiptDraft {
        if !goesAbove(other) { return other.joined(with: self) }
        var d = filled(from: other)
        let overlap = (0...min(lines.count, other.lines.count)).reversed()
            .first { k in Array(lines.suffix(k)) == Array(other.lines.prefix(k)) } ?? 0
        d.lines = lines + other.lines.dropFirst(overlap)
        // The total is the foot's, which is the lower part's when both read one.
        if let t = other.exactTotal { d.exactTotal = t }
        return d
    }

    /// Whether this part sits above `other` on the paper: the one with the
    /// head goes first, and between two heads (or two feet) the first taken.
    func goesAbove(_ other: ReceiptDraft) -> Bool { !(missingTop && !other.missingTop) }
}

/// Words to look for on a folded line. Latin ones are whole words only, so
/// "tel" is not found in "Hotel" nor "card" in "Cardamom latte"; kana and
/// kanji have no spaces to go by and are found anywhere. A long Latin word
/// is also found one letter off, because that is how OCR misses a
/// Vietnamese accent: "Tạm tính" comes back as "Tam tinn".
struct ReceiptWords {
    private let latin: [NSRegularExpression]
    private let fuzzy: [[String]]
    private let other: [String]

    init(_ words: [String]) {
        let ascii = words.filter { $0.unicodeScalars.allSatisfy(\.isASCII) }
        latin = ascii.compactMap {
            try? NSRegularExpression(pattern: "(?<![a-z0-9])" + NSRegularExpression.escapedPattern(for: $0) + "(?![a-z])")
        }
        fuzzy = ascii.filter { $0.count >= 7 }.map { $0.split(separator: " ").map(String.init) }
        other = words.filter { !$0.unicodeScalars.allSatisfy(\.isASCII) }
    }

    /// `folded` is the line through `ReceiptParser.fold`.
    func found(in folded: String) -> Bool {
        if other.contains(where: folded.contains) { return true }
        let range = NSRange(folded.startIndex..., in: folded)
        if latin.contains(where: { $0.firstMatch(in: folded, range: range) != nil }) { return true }
        let tokens = folded.split(whereSeparator: { !$0.isLetter }).map(String.init)
        return fuzzy.contains { word in
            guard tokens.count >= word.count else { return false }
            return (0...(tokens.count - word.count)).contains { i in
                Self.distance(tokens[i..<(i + word.count)].joined(separator: " "), word.joined(separator: " ")) <= 1
            }
        }
    }

    /// Edits between two short strings (Levenshtein).
    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty, !b.isEmpty else { return max(a.count, b.count) }
        var row = Array(0...b.count)
        for i in 1...a.count {
            var prev = row[0]; row[0] = i
            for j in 1...b.count {
                let cur = row[j]
                row[j] = min(row[j] + 1, row[j - 1] + 1, prev + (a[i - 1] == b[j - 1] ? 0 : 1))
                prev = cur
            }
        }
        return row[b.count]
    }
}

enum ReceiptParser {

    static func parse(_ raw: [String], calendar: Calendar = .current) -> ReceiptDraft {
        let lines = raw.map(normalise).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var d = ReceiptDraft()
        // OCR drops the T now and then; beside 登録番号 the thirteen digits are enough.
        d.registration = (firstMatch(#"T\s?(\d{13})(?!\d)"#, in: lines) ?? firstMatch(#"登録番号\D{0,3}(\d{13})(?!\d)"#, in: lines)).map { "T" + $0 }
        d.phone = firstMatch(#"(?:TEL|Tel|tel|電話|ĐT|Đt|Phone|phone|Hotline)[:：.\s]*(\+?[0-9]{2,4}[- ][0-9]{2,4}[- ][0-9]{3,4})"#, in: lines)
        d.cardLast4 = firstMatch(cardPattern, in: lines)
        d.date = date(in: lines, calendar: calendar)
        d.exactTotal = total(in: lines)
        d.payment = payment(in: lines)
        d.merchant = merchant(in: lines)
        d.address = address(in: lines)
        d.lines = items(in: lines)
        d.japanese = lines.contains { $0.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) } }
        d.currency = currency(in: lines)
        return d
    }

    /// Which of the raw lines gave a field of `draft`: the shop, the
    /// registration number, the date, the total and the card. The camera
    /// outlines these, so what it says it read can be checked against the
    /// paper. Indexes are into `raw` as given.
    static func linesUsed(_ raw: [String], for draft: ReceiptDraft, calendar: Calendar = .current) -> Set<Int> {
        var used = Set<Int>()
        let lines = raw.map(normalise)
        func mark(_ test: (String) -> Bool) {
            if let i = lines.firstIndex(where: test) { used.insert(i) }
        }
        if !draft.merchant.isEmpty { mark { $0.contains(draft.merchant) } }
        if let r = draft.registration { mark { $0.replacingOccurrences(of: " ", with: "").contains(r.dropFirst()) } }
        if draft.date != nil { mark { date(in: [$0], calendar: calendar) != nil } }
        // The line that says 合計 with that figure, not 小計 carrying the same one.
        if let t = draft.total {
            if let i = lines.lastIndex(where: { trailingAmount($0) == t && totalScore($0) > 0 })
                ?? lines.lastIndex(where: { trailingAmount($0) == t }) {
                used.insert(i)
            }
        }
        if let c = draft.cardLast4 { mark { $0.contains(c) && firstMatch(cardPattern, in: [$0]) != nil } }
        return used
    }

    // MARK: - Normalising

    /// Full-width digits and letters to half-width, ￥ to ¥, and the dashes
    /// OCR invents. Everything after works on this.
    static func normalise(_ s: String) -> String {
        // Only the full-width ASCII block (Ａ–ｚ, ０–９, ＄…) and the ideographic
        // space are narrowed. The system transform would also turn katakana
        // into half-width ﾌﾞﾚﾝﾄﾞ, which is not how anyone writes a product.
        var scalars = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            if (0xFF01...0xFF5E).contains(u.value), let a = Unicode.Scalar(u.value - 0xFEE0) { scalars.append(a) }
            else if u.value == 0x3000 { scalars.append(" ") }
            else { scalars.append(u) }
        }
        var out = String(scalars)
        out = out.replacingOccurrences(of: "￥", with: "¥").replacingOccurrences(of: "\\", with: "¥")
        for dash in ["ー", "−", "–", "—", "―"] where out.range(of: #"\d"# + dash, options: .regularExpression) != nil {
            out = out.replacingOccurrences(of: dash, with: "-")
        }
        return out
    }

    /// Lower case, no accents, đ as d: what the words are matched on, so
    /// "TỔNG CỘNG", "Tổng cộng" and an OCR's "TONG CONG" are one word. Kana
    /// and kanji are left alone: folding would take the dakuten off ご.
    static func fold(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        for u in s.unicodeScalars {
            if u.value >= 0x3000 { out.append(u); continue }
            let folded = String(u).replacingOccurrences(of: "đ", with: "d").replacingOccurrences(of: "Đ", with: "d")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            out.append(contentsOf: folded.unicodeScalars)
        }
        return String(out)
    }

    // MARK: - Amounts

    /// The figure at the end of a line, in whichever way the receipt prints
    /// it. The separators are what tell thousands from cents: three digits
    /// after one is thousands ("1,280", "74.700"), one or two are cents
    /// ("25.35"), so "74.700đ" is seventy-four thousand and "$25.35" is
    /// twenty-five and change.
    private static let amountPattern = #"(?:(?:^|\s)[-▲△])?\s*(?:[¥$€₫]|VND|USD|JPY)?\s*(?<![\d.,])(\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)\s*(?:円|đ|₫|d(?![a-z])|VND|vnd|USD|€|-)?\s*(?:[*※軽外内]{1,2}|[A-Z](?![a-z]))?\s*$"#

    /// A money figure at the end of a line, in whole units: "¥1,280",
    /// "1,280円", "▲100", "74.700đ", "125,000 VND", "$25.35" (25). nil when
    /// the line does not end in one.
    static func trailingAmount(_ line: String) -> Int? {
        trailingFigure(line).flatMap { v in
            let whole = Int(v.magnitude.rounded())
            return whole > 0 ? (v < 0 ? -whole : whole) : nil
        }
    }

    /// The same figure with its cents: "$25.35" → 25.35, "▲0.50" → −0.5.
    static func trailingFigure(_ line: String) -> Double? {
        guard let r = line.range(of: amountPattern, options: .regularExpression) else { return nil }
        let token = String(line[r]).trimmingCharacters(in: .whitespaces)
        guard let numberRange = token.range(of: #"\d[\d.,]*\d|\d"#, options: .regularExpression) else { return nil }
        let negative = token[..<numberRange.lowerBound].contains { "-▲△".contains($0) }
        guard let v = exactUnits(String(token[numberRange])), v > 0, v < 1_000_000_000 else { return nil }
        return negative ? -v : v
    }

    /// "1,280" → 1280, "74.700" → 74700, "1.234,56" → 1235, "25.35" → 25.
    static func wholeUnits(_ number: String) -> Int? {
        exactUnits(number).map { Int($0.rounded()) }
    }

    /// "1.234,56" → 1234.56, "25.35" → 25.35, "74.700" → 74700: one or two
    /// digits after the last mark are cents, three are a thousands group.
    static func exactUnits(_ number: String) -> Double? {
        var s = Substring(number)
        var cents = ""
        if let last = s.lastIndex(where: { $0 == "." || $0 == "," }) {
            let after = s[s.index(after: last)...]
            if after.count <= 2 {
                cents = String(after.filter(\.isNumber))
                s = s[..<last]
            }
        }
        guard let whole = Int(s.filter(\.isNumber)) else { return nil }
        // Read back from text, so 4.85 is the double nearest 4.85 and not 4 + 0.85.
        return Double(cents.isEmpty ? "\(whole)" : "\(whole).\(cents)")
    }

    // MARK: - Currency

    /// What the receipt's money is, from what it prints. A symbol or code
    /// beside a figure counts most; then the language: kana or kanji is yen,
    /// a Vietnamese word or letter is đồng. A trailing "d" after a figure
    /// counts for đồng too — it is how OCR reads đ without its stroke. nil
    /// when nothing on the paper says.
    static func currency(in lines: [String]) -> String? {
        var votes: [String: Int] = [:]
        for line in lines {
            if line.contains("¥") || line.contains("円") || line.contains("JPY") { votes["JPY", default: 0] += 2 }
            if line.contains("₫") || line.contains("VND") || line.contains("VNĐ") || line.contains("vnd")
                || line.range(of: #"\d\s*[đd]\s*$"#, options: .regularExpression) != nil { votes["VND", default: 0] += 2 }
            if line.contains("$") || line.contains("USD") { votes["USD", default: 0] += 2 }
            if line.contains("€") || line.contains("EUR") { votes["EUR", default: 0] += 2 }
        }
        if let top = votes.max(by: { $0.value < $1.value }) { return top.key }
        let text = lines.joined(separator: " ")
        if text.unicodeScalars.contains(where: { (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) }) { return "JPY" }
        let vietnameseLetters = CharacterSet(charactersIn: "ăâđêôơưĂÂĐÊÔƠƯạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹ")
        if text.unicodeScalars.contains(where: vietnameseLetters.contains) || vietnameseWords.found(in: fold(text)) { return "VND" }
        return nil
    }

    private static let vietnameseWords = ReceiptWords(["tong cong", "tong tien", "thanh tien", "tam tinh", "tien mat", "tien thua", "hoa don", "khach dua"])

    // MARK: - Total

    /// Words that say "this is what was paid", strongest first: a grand
    /// total beats a total, which beats the column head "thành tiền". A
    /// strong one wins even with a tax word beside it (税込合計).
    private static let strongTotal = ReceiptWords(["総合計", "税込合計", "お支払金額", "お支払い金額", "お支払合計", "ご請求額", "ご請求金額", "お買上合計",
                                      "grand total", "amount due", "balance due", "total due", "total amount", "amount payable",
                                      "tong thanh toan", "tong tien thanh toan", "khach can tra", "khach phai tra", "can thanh toan",
                                      "phai thanh toan"])
    private static let plainTotal = ReceiptWords(["合計", "お会計", "お買上計", "ご利用金額", "領収金額", "total", "tong cong", "tong tien", "tong so tien"])
    private static let weakTotal = ReceiptWords(["thanh tien"])
    /// A line with one of these is not the total unless a strong word says it is.
    private static let notTotal = ReceiptWords(["小計", "点数", "合計点", "税", "対象", "お預", "お釣", "釣銭", "内訳",
                                   "subtotal", "sub total", "sub-total", "tax", "vat", "change", "tender", "cash", "tip",
                                   "savings", "saved", "discount", "items", "item count", "qty",
                                   "tam tinh", "thue", "giam gia", "chiet khau", "tien thua", "tra lai", "khach dua",
                                   "tien mat", "so luong", "tien hang"])

    /// How strongly a line claims to be the total: 3 grand, 2 total, 1 a
    /// column head, 0 not at all.
    static func totalScore(_ line: String) -> Int {
        let f = fold(line)
        if strongTotal.found(in: f) { return 3 }
        guard !notTotal.found(in: f) else { return 0 }
        if plainTotal.found(in: f) { return 2 }
        if weakTotal.found(in: f) { return 1 }
        return 0
    }

    static func total(in lines: [String]) -> Double? {
        var best: (score: Int, value: Double)?
        for (i, line) in lines.enumerated() {
            let score = totalScore(line)
            guard score > 0 else { continue }
            let next = i + 1 < lines.count ? lines[i + 1] : nil
            let value = trailingFigure(line)
                ?? next.flatMap { totalScore($0) == 0 && isBareAmount($0) ? trailingFigure($0) : nil }
            // The last line of the strongest kind: a receipt prints the
            // total below the lines, and a stronger word only once.
            if let value, value > 0, score >= (best?.score ?? 0) { best = (score, value) }
        }
        if let best { return best.value }
        // No word to go by. A figure on a line of its own is a total (a
        // 領収書, a till that prints only the sum); so is the one figure on
        // a slip with one. Otherwise there is none — the dearest line is not
        // the total of a receipt whose foot is out of the picture.
        let candidates = lines.filter { !handedOver.found(in: fold($0)) }
        if let bare = candidates.filter(isBareAmount).compactMap(trailingFigure).filter({ $0 > 0 }).max() { return bare }
        let priced = candidates.compactMap(trailingFigure).filter { $0 > 0 }
        return priced.count == 1 ? priced[0] : nil
    }

    private static let handedOver = ReceiptWords(["お預", "お釣", "釣銭", "現金", "cash", "change", "tien mat", "tien thua", "khach dua"])

    /// A line that is a figure and nothing else ("890", "¥5,500-").
    private static func isBareAmount(_ line: String) -> Bool {
        trailingAmount(line) != nil
            && line.range(of: #"^\s*[-▲△]?\s*(?:[¥$€₫]|VND|USD|JPY)?\s*[\d.,]+\s*(?:円|đ|₫|d|VND|vnd|USD|€|-)?\s*$"#, options: .regularExpression) != nil
    }

    // MARK: - Date

    private static let monthNames = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    /// The first date on the receipt, with its time where one is printed.
    /// Year first is Japanese (2026/09/30, 26/09/30, 令和8年9月30日); day
    /// first is Vietnamese and most English (30/09/2026, 30 Sep 2026); month
    /// first only where the receipt is in dollars or a day over 12 says so.
    static func date(in lines: [String], calendar: Calendar) -> Date? {
        let text = lines.joined(separator: " ")
        let japanese = text.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) || (0x4E00...0x9FFF).contains($0.value) }
        let monthFirst = text.contains("$") || text.contains("USD")
        for line in lines {
            let f = fold(line)
            var ymd: (Int, Int, Int)?
            if let g = groups(#"(20\d{2})\s*[年/.\-]\s*(\d{1,2})\s*[月/.\-]\s*(\d{1,2})"#, in: line) {
                ymd = (Int(g[0]) ?? 0, Int(g[1]) ?? 0, Int(g[2]) ?? 0)
            } else if let g = groups(#"(?:令和|R)\s*(\d{1,2})\s*[年/.\-]\s*(\d{1,2})\s*[月/.\-]\s*(\d{1,2})"#, in: line) {
                ymd = (2018 + (Int(g[0]) ?? 0), Int(g[1]) ?? 0, Int(g[2]) ?? 0)
            } else if let g = groups(#"ngay\s*(\d{1,2})\s*thang\s*(\d{1,2})\s*nam\s*(20\d{2})"#, in: f) {
                ymd = (Int(g[2]) ?? 0, Int(g[1]) ?? 0, Int(g[0]) ?? 0)
            } else if let g = groups(#"(?<![\d.,])(\d{1,2})[/.\-](\d{1,2})[/.\-](20\d{2}|\d{2})(?![\d.,])"#, in: line) {
                let a = Int(g[0]) ?? 0, b = Int(g[1]) ?? 0, c = Int(g[2]) ?? 0
                if c < 100 && japanese {
                    // Two-digit year: Japanese receipts put it first (26/09/30).
                    ymd = (2000 + a, b, c)
                } else {
                    let y = c < 100 ? 2000 + c : c
                    let dayFirst = a > 12 || (b <= 12 && !monthFirst)
                    ymd = dayFirst ? (y, b, a) : (y, a, b)
                }
            } else if let g = groups(#"(?<!\d)(\d{1,2})\s+([a-z]{3})[a-z]*\.?,?\s+(20\d{2})"#, in: f),
                      let m = monthNames.firstIndex(of: g[1]) {
                ymd = (Int(g[2]) ?? 0, m + 1, Int(g[0]) ?? 0)
            } else if let g = groups(#"([a-z]{3})[a-z]*\.?\s+(\d{1,2}),?\s+(20\d{2})"#, in: f),
                      let m = monthNames.firstIndex(of: g[0]) {
                ymd = (Int(g[2]) ?? 0, m + 1, Int(g[1]) ?? 0)
            }
            guard let (y, m, d) = ymd, (1...12).contains(m), (1...31).contains(d) else { continue }
            var c = DateComponents(year: y, month: m, day: d)
            if let (h, min) = time(in: line) ?? lines.lazy.compactMap({ time(in: $0, alone: true) }).first {
                c.hour = h; c.minute = min
            }
            // 31 September is not a day; a misread would roll into October.
            guard let date = calendar.date(from: c), calendar.component(.day, from: date) == d else { continue }
            return date
        }
        return nil
    }

    /// "12:41", "7:15 PM", "12時41分". `alone`: only a line that starts with
    /// the time, so a line elsewhere on the receipt can lend its time to the
    /// date without a price being taken for one.
    private static func time(in line: String, alone: Bool = false) -> (Int, Int)? {
        let pattern = alone ? #"^\s*(\d{1,2})[:時](\d{2})"# : #"(?<!\d)(\d{1,2})[:時](\d{2})"#
        guard let g = groups(pattern, in: line), var h = Int(g[0]), let m = Int(g[1]), h < 24, m < 60 else { return nil }
        let f = fold(line)
        if f.range(of: #"\d\s*pm"#, options: .regularExpression) != nil, h < 12 { h += 12 }
        if f.range(of: #"\d\s*am"#, options: .regularExpression) != nil, h == 12 { h = 0 }
        return (h, m)
    }

    // MARK: - Payment and card

    /// A masked card number's last four: "****1234", "XXXX XXXX XXXX 1234",
    /// "**** **** **** 5678", "•••• 1234".
    private static let cardPattern = #"(?:[*Xx•]{2,}[\s\-]?)+(\d{4})(?!\d)"#

    static func payment(in lines: [String]) -> ReceiptDraft.Payment {
        let text = lines.joined(separator: " ")
        let f = fold(text)
        if text.contains("PayPay") { return .payPay }
        if ["Suica", "PASMO", "ICOCA", "交通系", "SUICA"].contains(where: text.contains) { return .transitIC }
        if text.contains("QUICPay") { return .quicPay }
        if ["クレジット", "VISA", "Visa", "MASTER", "Master", "JCB", "AMEX", "カード"].contains(where: text.contains)
            || ["credit", "debit", "the tin dung", "quet the", "thanh toan the"].contains(where: f.contains) { return .card }
        if text.range(of: #"(?<![A-Za-z])iD(?![A-Za-z])"#, options: .regularExpression) != nil { return .iD }
        if ["現金", "お預", "お釣"].contains(where: text.contains) || ["cash", "tien mat", "khach dua"].contains(where: f.contains) { return .cash }
        return .unknown
    }

    // MARK: - Shop

    /// Lines at the head of a receipt that are not its name. Japanese ones
    /// are matched as written; the rest on the folded line.
    private static let notShopJapanese = ReceiptWords(["領収書", "領収証", "レシート", "いらっしゃいませ", "ありがとう", "電話", "登録番号", "〒", "都", "県", "区", "市"])
    private static let notShop = ReceiptWords(["receipt", "invoice", "welcome", "thank", "tel", "phone", "www", "http", "order", "table", "cashier", "server",
                                  "hoa don", "phieu", "cam on", "xin chao", "dia chi", "d/c", "dt:", "dien thoai", "mst", "ma so thue",
                                  "hotline", "website", "so hd", "ngay", "thu ngan", "ban so", "quay"])

    /// The shop: among the lines above the first thing bought, the first
    /// that reads like a name — not a date, a phone number, an address or the
    /// word receipt. When the first line is already an item or a total, the
    /// head is out of the picture and there is no name to give.
    static func merchant(in lines: [String]) -> String {
        let firstPriced = lines.firstIndex { l in
            trailingAmount(l) != nil && l.filter(\.isNumber).count < 9 && firstMatch(#"T\s?(\d{13})"#, in: [l]) == nil
        } ?? lines.count
        for line in lines.prefix(min(firstPriced, 6)) where looksLikeShop(line) {
            return line.trimmingCharacters(in: .whitespaces)
        }
        // A 領収書 written out by hand or printed as a form: its top is the
        // heading, the customer (〜様) and the amount, and the shop's name is
        // stamped at the foot, below the date.
        if lines.prefix(3).contains(where: isHeading) {
            for line in lines.reversed() where looksLikeShop(line) && !line.contains("但") && !line.contains("上記") {
                return line.trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    private static func looksLikeShop(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let f = fold(trimmed)
        let digits = trimmed.filter(\.isNumber).count
        return trimmed.count >= 2 && digits * 2 < trimmed.count && totalScore(trimmed) == 0
            && !isHeading(trimmed) && !isAddressee(trimmed)
            && !notShopJapanese.found(in: trimmed) && !notShop.found(in: f) && !notItem.found(in: f)
            && date(in: [trimmed], calendar: .current) == nil && trailingAmount(trimmed) == nil
    }

    /// The word at the top of the paper that says what it is — 領収書,
    /// レシート, お客様控え — however OCR spells it: with spaces between the
    /// characters ("領 収 書"), in brackets, or one character misread
    /// ("領収害", "领收书"). Taken for the shop's name, it named every spend
    /// "領収書".
    static func isHeading(_ line: String) -> Bool {
        let bare = line.unicodeScalars.filter { CharacterSet.letters.contains($0) }.map(String.init).joined()
        guard !bare.isEmpty else { return false }
        let words = ["領収書", "領収証", "御領収書", "領収", "レシート", "お買上明細", "お買い上げ明細", "ご利用明細",
                     "明細書", "お客様控え", "お客様控", "控え", "売上票", "納品書", "請求書"]
        if words.contains(bare) { return true }
        // One character off in a short line: two of 領, 収 and 書/証 is the heading.
        if bare.count <= 5 {
            let marks: [Character] = ["領", "领", "収", "收", "書", "书", "証"]
            if Set(bare.filter { marks.contains($0) }).count >= 2 { return true }
        }
        let latin = fold(bare)
        return latin.count <= 9 && ["receipt", "reciept", "invoice"].contains { ReceiptWords.distance(latin, $0) <= 1 }
    }

    /// Whether two phone numbers are the same line, however each is written:
    /// "03-1234-5678", "+81 3-1234-5678" and "0312345678" are one number.
    /// How a shop found on Apple Maps is matched to the receipt it printed.
    static func samePhone(_ a: String, _ b: String) -> Bool {
        func digits(_ s: String) -> String {
            var d = s.filter(\.isNumber)
            if d.hasPrefix("81"), d.count >= 11 { d = "0" + d.dropFirst(2) }
            return d
        }
        let x = digits(a), y = digits(b)
        return x.count >= 9 && x == y
    }

    /// The customer a 領収書 is made out to: 山田 様, 株式会社〇〇 御中.
    private static func isAddressee(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t.hasSuffix("様") || t.hasSuffix("御中") || t.hasSuffix("様へ") || t.hasSuffix("殿")
    }

    /// The shop's address: the line with the postcode (〒123-4567) or that
    /// starts with a prefecture, joined to the line after the postcode when
    /// the postcode stands alone.
    static func address(in lines: [String]) -> String? {
        let prefecture = #"^(?:〒\s?\d{3}-?\d{4}\s*)?(?:東京都|北海道|(?:京都|大阪)府|.{2,3}県)\S*?(?:市|区|町|村|郡)"#
        for (i, line) in lines.enumerated() {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.range(of: prefecture, options: .regularExpression) != nil {
                return t.replacingOccurrences(of: #"^〒\s?\d{3}-?\d{4}\s*"#, with: "", options: .regularExpression)
            }
            if t.range(of: #"^〒\s?\d{3}-?\d{4}\s*$"#, options: .regularExpression) != nil, i + 1 < lines.count {
                let next = lines[i + 1].trimmingCharacters(in: .whitespaces)
                if next.range(of: #"(?:市|区|町|村|郡)"#, options: .regularExpression) != nil { return next }
            }
        }
        return nil
    }

    // MARK: - Lines bought

    private static let notItem = ReceiptWords(["合計", "小計", "税", "お預", "お釣", "釣銭", "現金", "点数", "対象", "クレジット", "visa", "カード", "paypay",
                                  "お会計", "total", "支払", "tel", "電話", "登録番号", "no.", "レジ", "担当",
                                  "subtotal", "tax", "change", "cash", "tender", "tip", "card", "balance", "amount due",
                                  "tong", "tam tinh", "thue", "vat", "tien thua", "tra lai", "khach dua", "tien mat", "thanh toan", "can tra"])

    /// Lines bought: a name and a price at its end. Discounts come in as
    /// negative lines so the list still adds up to the total. Quantity and
    /// unit price printed between name and price ("Bánh mì 2 25.000 50.000")
    /// are taken off the name.
    static func items(in lines: [String]) -> [ReceiptDraft.Line] {
        var out: [ReceiptDraft.Line] = []
        for line in lines {
            let f = fold(line)
            guard !notItem.found(in: f), let price = trailingAmount(line),
                  groups(#"(\d{1,2}):(\d{2})"#, in: line) == nil,
                  date(in: [line], calendar: .current) == nil else { continue }
            var name = line.replacingOccurrences(of: amountPattern, with: "", options: .regularExpression)
            // A unit price left at the end of the name (a figure with
            // separators, or three digits or more), then the quantity before
            // it. A bare small number stays unless a unit price went: it is
            // "Pixel 9", not a count.
            var unitPrice = false
            if let r = name.range(of: #"\s+[@x×]?\s*[¥$]?(?:\d{1,3}(?:[.,]\d{3})+|\d{3,})(?:[.,]\d{1,2})?\s*(?:円|đ)?\s*$"#, options: .regularExpression) {
                name.removeSubrange(r); unitPrice = true
            }
            // Japanese and Vietnamese print the count after the name; an
            // English name ending in a number is usually the product's own.
            let countAfterName = unitPrice || line.unicodeScalars.contains { $0.value >= 0x00C0 }
            let quantity = countAfterName ? #"\s+(?:[x×]\s*)?\d{1,3}\s*(?:個|点|x|×)?\s*$"#
                                          : #"\s+(?:[x×]\s*\d{1,3}|\d{1,3}\s*(?:個|点|x|×))\s*$"#
            if let r = name.range(of: quantity, options: .regularExpression) { name.removeSubrange(r) }
            name = name.trimmingCharacters(in: .whitespaces)
            // A name is mostly letters: a line of codes or figures is not one.
            let letters = name.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            let cjk = name.unicodeScalars.contains { $0.value >= 0x3040 }
            guard letters >= 2 || cjk, name.filter(\.isNumber).count <= letters else { continue }
            out.append(.init(name: name, price: price))
        }
        return Array(out.prefix(120))
    }

    // MARK: - Regex helpers

    private static func groups(_ pattern: String, in s: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (1..<m.numberOfRanges).compactMap { Range(m.range(at: $0), in: s).map { String(s[$0]) } }
    }

    private static func firstMatch(_ pattern: String, in lines: [String]) -> String? {
        for line in lines { if let g = groups(pattern, in: line), let first = g.first { return first } }
        return nil
    }
}
