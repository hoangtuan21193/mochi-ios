import SwiftUI
import UniformTypeIdentifiers

/// Import a statement: PayPay's history, a card's 明細, a bank's CSV. The
/// user picks which account it is; rows already in the book are left off, a
/// top-up is a move, a bank debit for a card is matched to the card so it is
/// counted once. Nothing is written until the button at the bottom.
struct ImportStatementView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false
    @State private var fileName = ""
    @State private var result: StatementParser.Result?
    @State private var account = ""
    @State private var topUpFrom = ""
    @State private var includeRepeats = true
    @State private var added: Int?

    var body: some View {
        SheetScaffold(title: "Import a statement") {
            if let added {
                Card {
                    Verdict(text: "\(added) transactions added")
                    Text("Those without a category are waiting in To review.").font(Organic.value).foregroundStyle(Organic.n600)
                        .padding(.top, 4)
                }
                PrimaryButton(title: "Done") { dismiss() }
            } else {
                Card {
                    HStack(spacing: Organic.Space.l) {
                        LeadMark(glyph: .symbol("doc.text"), tint: Organic.infoSoft, ink: Organic.info, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: fileName.isEmpty ? String(localized: "No file yet") : fileName).font(Organic.row)
                            Text("A CSV from PayPay, your card’s site or your bank · read on this iPhone")
                                .font(Organic.caption).foregroundStyle(Organic.n600)
                        }
                    }
                    SecondaryButton(title: fileName.isEmpty ? "Choose a file" : "Choose another file", icon: "folder") { picking = true }
                        .padding(.top, 8)
                    if !store.accountNames.isEmpty {
                        ChipPicker(label: "This is the statement of", options: store.accountNames, selection: account) { account = $0 }
                            .padding(.top, 8)
                    }
                }
                if let result { preview(result) }
            }
        }
        .fileImporter(isPresented: $picking, allowedContentTypes: [.commaSeparatedText, .plainText, .tabSeparatedText, .text]) { r in
            guard case .success(let url) = r else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { return }
            // Japanese statements still come in Shift-JIS more often than not.
            let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .shiftJIS) ?? ""
            fileName = url.lastPathComponent
            result = StatementParser.parse(text)
            if account.isEmpty {
                account = store.accountNames.first { url.lastPathComponent.localizedCaseInsensitiveContains($0) }
                    ?? (url.lastPathComponent.lowercased().contains("paypay")
                        ? store.accountNames.first { $0.localizedCaseInsensitiveContains("paypay") } ?? "" : "")
            }
        }
        .onAppear { if account.isEmpty { account = store.accountNames.first ?? "" } }
    }

    private func preview(_ r: StatementParser.Result) -> some View {
        let matches = StatementParser.match(r.rows, account: account, store.data)
        let new = r.rows.filter { matches[$0.id] == .new || matches[$0.id] == .twiceInFile }
        let here = r.rows.filter { matches[$0.id] == .alreadyHere }
        let moves = r.rows.filter { if case .cardPayment = matches[$0.id] { return true }; return $0.kind == .move }
        let refunds = r.rows.filter { $0.kind == .refund && matches[$0.id] != .alreadyHere }
        let toAdd = r.rows.filter { matches[$0.id] != .alreadyHere }
        return VStack(alignment: .leading, spacing: Organic.Space.l) {
            TileGrid {
                Tile(label: "New", value: "\(new.filter { $0.kind == .spend || $0.kind == .income }.count)", sub: String(localized: "will be added"))
                Tile(label: "Already here", value: "\(here.count)", sub: String(localized: "scanned, typed or imported before"), valueColor: Organic.n600)
                Tile(label: "Moves", value: "\(moves.count)", sub: String(localized: "top-ups and card payments · not spending"), valueColor: Organic.info)
                Tile(label: "Refunds", value: "\(refunds.count)", sub: String(localized: "money back"), valueColor: Organic.s700)
            }
            if moves.contains(where: { matches[$0.id] == .new && $0.amount > 0 }) {
                ChipPicker(label: "Top-ups came from", options: store.accountNames.filter { $0 != account }, selection: topUpFrom) { topUpFrom = $0 }
            }
            ListHeading(title: "What comes in", trailing: "\(toAdd.count) of \(r.rows.count)")
            Card(padding: .list) {
                ForEach(Array(r.rows.prefix(40).enumerated()), id: \.element.id) { i, row in
                    ListRow(title: row.merchant.isEmpty ? String(localized: "Unnamed") : row.merchant,
                            sub: rowNote(row, matches[row.id] ?? .new),
                            value: store.signed(row.amount),
                            valueSub: row.date.formatted(.dateTime.day().month(.abbreviated)),
                            valueColor: matches[row.id] == .alreadyHere ? Organic.n500 : (row.amount > 0 ? Organic.s700 : Organic.text))
                        .opacity(matches[row.id] == .alreadyHere ? 0.55 : 1)
                        .overlay(alignment: .top) { if i > 0 { Hairline() } }
                }
            }
            if !r.failures.isEmpty {
                HelpText("Lines \(r.failures.prefix(5).map(String.init).joined(separator: ", ")) had no date that could be read and are left out.", tone: .warning)
            }
            HelpText("Rows that match something already in the book are left off, so importing the same file twice changes nothing. A top-up or a card payment is money moving between your own accounts: it is never counted as spending.")
            PrimaryButton(title: "Add \(toAdd.count) · skip \(here.count) already here") {
                added = store.importStatement(toAdd, matches: matches, account: account, topUpFrom: topUpFrom, source: fileName)
            }
        }
    }

    private func rowNote(_ row: StatementParser.Row, _ m: StatementParser.Match) -> String {
        switch m {
        case .alreadyHere: return String(localized: "Already here · left off")
        case .twiceInFile: return String(localized: "Twice in this file · both come in")
        case .cardPayment(let card): return String(localized: "Pays \(card) · counted once, as a move")
        case .new:
            if !row.note.isEmpty { return row.note }
            let rule = Finance.rule(for: row.merchant, store.data)
            return rule.map { String(localized: "\($0.category) · by your rule") } ?? String(localized: "No category yet · to review")
        }
    }
}

extension Store {
    /// Writes an import: spending and income as they are, top-ups and card
    /// payments as moves, rules filling what they can. Anything without a
    /// category waits in To review. Returns how many were added.
    @discardableResult
    func importStatement(_ rows: [StatementParser.Row], matches: [UUID: StatementParser.Match],
                         account: String, topUpFrom: String, source: String) -> Int {
        var list = data.transactions ?? []
        var count = 0
        for r in rows {
            let m = matches[r.id] ?? .new
            guard m != .alreadyHere else { continue }
            var t: Transaction
            if case .cardPayment(let card) = m {
                t = Transaction(date: r.date, amount: abs(r.amount), kind: .move, account: account, toAccount: card,
                                merchant: r.merchant, source: .statement)
            } else if r.kind == .move {
                t = r.amount > 0
                    ? Transaction(date: r.date, amount: r.amount, kind: .move, account: topUpFrom.isEmpty ? r.merchant : topUpFrom,
                                  toAccount: account, merchant: r.merchant, source: .statement)
                    : Transaction(date: r.date, amount: abs(r.amount), kind: .move, account: account, toAccount: r.merchant,
                                  merchant: r.merchant, source: .statement)
            } else {
                t = Transaction(date: r.date, amount: r.amount, kind: r.kind, account: account, merchant: r.merchant,
                                note: source, source: .statement)
                fill(&t)
                t.needsReview = t.kind == .spend && t.category.isEmpty
            }
            list.append(t)
            count += 1
        }
        data.transactions = list
        log(label: String(localized: "Statement import"), detail: metaLine(source, account), amount: count, kind: "x")
        save()
        return count
    }
}
