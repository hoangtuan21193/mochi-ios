import Foundation

/// A statement file — PayPay's 取引履歴, a card's 明細, a bank's 入出金明細 —
/// read by its header names into rows the book can match. Pure, so every
/// format and every matching rule has a test.
enum StatementParser {

    struct Row: Identifiable, Equatable {
        let id = UUID()
        var line: Int
        var date: Date
        var merchant: String
        /// As the imported account sees it: negative is money out of it (or
        /// charged to it, for a card).
        var amount: Int
        var kind: TransactionKind
        /// Why the row is what it is, for the preview.
        var note: String = ""
        static func == (a: Row, b: Row) -> Bool { a.id == b.id }
    }

    struct Result {
        var rows: [Row] = []
        var failures: [Int] = []
        var readColumns: [String] = []
    }

    private static let dateNames = ["取引日", "利用日", "ご利用日", "日付", "取引日時", "利用日時", "年月日", "お取引日", "date", "日時"]
    private static let merchantNames = ["取引先", "利用店名・商品名", "利用店名", "ご利用店名", "ご利用先", "利用先", "摘要", "お取引内容", "店名", "内容", "description", "merchant", "ご利用店名・商品名"]
    private static let outNames = ["出金金額(円)", "出金金額", "お支払金額", "支払金額", "利用金額", "ご利用金額", "お引出し", "お引出金額", "引出金額", "出金", "支払総額", "amount", "金額"]
    private static let inNames = ["入金金額(円)", "入金金額", "お預入れ", "お預入金額", "預入金額", "入金"]
    private static let kindNames = ["取引内容", "取引種別", "区分", "取引区分"]

    static func parse(_ text: String, calendar: Calendar = .current) -> Result {
        var out = Result()
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let headerIndex = lines.firstIndex(where: { l in
            let cells = split(l).map(fold)
            return cells.contains { c in dateNames.contains { fold($0) == c } }
        }) else {
            return headerless(lines, calendar: calendar)
        }
        let header = split(lines[headerIndex]).map(fold)
        func col(_ names: [String]) -> Int? {
            for n in names { if let i = header.firstIndex(of: fold(n)) { return i } }
            return nil
        }
        let dCol = col(dateNames), mCol = col(merchantNames), oCol = col(outNames), iCol = col(inNames), kCol = col(kindNames)
        out.readColumns = [dCol, mCol, oCol, iCol, kCol].compactMap { $0 }.map { split(lines[headerIndex])[$0] }
        for (n, raw) in lines.enumerated() where n > headerIndex && !raw.isEmpty {
            let cells = split(raw)
            func cell(_ i: Int?) -> String { i.flatMap { $0 < cells.count ? cells[$0] : nil } ?? "" }
            guard let date = parseDate(cell(dCol), calendar: calendar) else { out.failures.append(n + 1); continue }
            let outAmt = amount(cell(oCol)), inAmt = amount(cell(iCol))
            guard outAmt != 0 || inAmt != 0 else { continue }
            var merchant = cell(mCol)
            let kindText = cell(kCol)
            if merchant.isEmpty { merchant = kindText }
            // A statement that lists charges only prints them positive.
            var signed = inAmt != 0 && outAmt == 0 ? inAmt : -abs(outAmt)
            if iCol == nil, outAmt < 0 { signed = abs(outAmt) }
            var row = Row(line: n + 1, date: date, merchant: merchant, amount: signed, kind: signed < 0 ? .spend : .income)
            classify(&row, hint: kindText)
            out.rows.append(row)
        }
        return out
    }

    /// Some card statements carry no header at all: find the date, the
    /// amount and the widest text column by what they hold.
    private static func headerless(_ lines: [String], calendar: Calendar) -> Result {
        var out = Result()
        for (n, raw) in lines.enumerated() where !raw.isEmpty {
            let cells = split(raw)
            guard let di = cells.firstIndex(where: { parseDate($0, calendar: calendar) != nil }),
                  let date = parseDate(cells[di], calendar: calendar) else { continue }
            let amounts = cells.enumerated().filter { $0.offset != di && amount($0.element) != 0 && $0.element.filter(\.isLetter).isEmpty }
            guard let ai = amounts.first?.offset else { out.failures.append(n + 1); continue }
            let text = cells.enumerated().filter { $0.offset != di && $0.offset != ai }.max { $0.element.count < $1.element.count }?.element ?? ""
            var row = Row(line: n + 1, date: date, merchant: text, amount: -abs(amount(cells[ai])), kind: .spend)
            classify(&row, hint: "")
            out.rows.append(row)
        }
        return out
    }

    /// Top-ups, refunds, card payments and transfers are not spending.
    static func classify(_ row: inout Row, hint: String) {
        let text = row.merchant + " " + hint
        if ["チャージ", "charge", "Charge"].contains(where: text.contains) {
            row.kind = .move; row.note = String(localized: "Top-up · moves money between your own accounts")
        } else if ["返金", "取消", "キャンセル", "refund", "Refund"].contains(where: text.contains) {
            row.kind = .refund; row.amount = abs(row.amount); row.note = String(localized: "Refund · money back")
        } else if ["カード", "クレジット", "ｶｰﾄﾞ", "引落", "ﾋｷｵﾄｼ", "口座振替"].contains(where: text.contains) && row.amount < 0 {
            row.kind = .move; row.note = String(localized: "Looks like a card payment · counted once")
        } else if ["振替", "振込", "送る", "受け取る", "送金"].contains(where: text.contains) {
            row.kind = row.amount < 0 ? .move : .income
            row.note = row.amount < 0 ? String(localized: "A transfer out") : ""
        }
    }

    // MARK: - Cells

    static func split(_ line: String) -> [String] {
        let sep: Character = line.filter { $0 == "\t" }.count > line.filter { $0 == "," }.count ? "\t" : ","
        var cells: [String] = []
        var cur = "", quoted = false
        for ch in line {
            if ch == "\"" { quoted.toggle(); continue }
            if ch == sep && !quoted { cells.append(cur.trimmingCharacters(in: .whitespaces)); cur = ""; continue }
            cur.append(ch)
        }
        cells.append(cur.trimmingCharacters(in: .whitespaces))
        return cells
    }

    static func fold(_ s: String) -> String {
        (s.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? s)
            .lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "（", with: "(").replacingOccurrences(of: "）", with: ")")
    }

    static func amount(_ s: String) -> Int {
        let t = ReceiptParser.normalise(s).replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "円", with: "").trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, let v = Double(t) else { return 0 }
        return Int(v.rounded())
    }

    static func parseDate(_ s: String, calendar: Calendar) -> Date? {
        let t = ReceiptParser.normalise(s)
        let patterns = [#"(20\d{2})[/\-.年](\d{1,2})[/\-.月](\d{1,2})"#, #"(20\d{2})(\d{2})(\d{2})"#]
        for p in patterns {
            guard let re = try? NSRegularExpression(pattern: p),
                  let m = re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)), m.numberOfRanges == 4,
                  let y = Range(m.range(at: 1), in: t).flatMap({ Int(t[$0]) }),
                  let mo = Range(m.range(at: 2), in: t).flatMap({ Int(t[$0]) }),
                  let d = Range(m.range(at: 3), in: t).flatMap({ Int(t[$0]) }),
                  (1...12).contains(mo), (1...31).contains(d) else { continue }
            var c = DateComponents(year: y, month: mo, day: d, hour: 12)
            if let tm = try? NSRegularExpression(pattern: #"(\d{1,2}):(\d{2})"#),
               let mm = tm.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
               let h = Range(mm.range(at: 1), in: t).flatMap({ Int(t[$0]) }),
               let mi = Range(mm.range(at: 2), in: t).flatMap({ Int(t[$0]) }) { c.hour = h; c.minute = mi }
            return calendar.date(from: c)
        }
        return nil
    }

    // MARK: - Matching against the book

    enum Match: Equatable { case new, alreadyHere, twiceInFile, cardPayment(String) }

    /// A row is already in the book when the same account has a transaction
    /// on the same day for the same amount — a scan, an Apple Pay entry or an
    /// earlier import of the same file. A bank row that pays a card is matched
    /// to that card so it is counted once, as a move.
    static func match(_ rows: [Row], account: String, _ data: AppData) -> [UUID: Match] {
        let cal = Calendar.current
        var used = Set<String>()
        var seen: [String: Int] = [:]
        var out: [UUID: Match] = [:]
        let existing = Finance.transactions(data).filter { $0.account == account || ($0.kind == .move && $0.toAccount == account) }
        for r in rows {
            let key = "\(cal.startOfDay(for: r.date).timeIntervalSince1970)|\(r.amount)|\(r.merchant)"
            seen[key, default: 0] += 1
            if let hit = existing.first(where: { t in
                !used.contains(t.id) && cal.isDate(t.date, inSameDayAs: r.date)
                    && (t.amount == r.amount || (t.kind == .move && t.amount == abs(r.amount)))
            }) {
                used.insert(hit.id)
                out[r.id] = .alreadyHere
                continue
            }
            if r.kind == .move, r.amount < 0,
               let card = data.cards.first(where: { c in
                   r.merchant.localizedCaseInsensitiveContains(c.name) || abs(Finance.cycle(for: c, data, today: r.date).statementAmount) == abs(r.amount)
               }) {
                out[r.id] = .cardPayment(card.name)
                continue
            }
            out[r.id] = seen[key, default: 0] > 1 ? .twiceInFile : .new
        }
        return out
    }
}
