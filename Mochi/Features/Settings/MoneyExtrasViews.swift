import SwiftUI

// MARK: - Investments

/// Holdings typed from a broker's statement, with the NISA allowance they
/// use. Mochi records; it gives no investment advice.
struct InvestmentsView: View {
    @Environment(Store.self) private var store
    @State private var editing: Investment?
    @State private var gold: Investment?
    @State private var coin: Investment?

    /// Accounts typed from a broker; gold and coins have sections of their own.
    private var typed: [Investment] { store.investments.filter { $0.kind != "gold" && $0.kind != "crypto" } }

    var body: some View {
        let value = store.investmentsValue
        let put = Finance.investmentsContributed(store.data)
        ScrollView {
            VStack(alignment: .leading, spacing: Organic.Space.l) {
                Card {
                    Text("Worth now").font(Organic.captionStrong).foregroundStyle(Organic.n600)
                    Text(verbatim: store.format(value)).font(Organic.hero)
                    Text("You put in \(store.format(put)) · \(store.signed(value - put)) on paper").font(Organic.value).foregroundStyle(Organic.n600)
                }
                ListHeading(title: "Accounts")
                Card(padding: .list) {
                    if typed.isEmpty { EmptyNote("None yet. Add a NISA or iDeCo account and type what the statement says.") }
                    ForEach(Array(typed.enumerated()), id: \.element.id) { i, inv in
                        Button { editing = inv } label: {
                            ListRow(title: inv.name, sub: String(localized: "Put in \(store.format(inv.contributed))"),
                                    value: store.format(inv.value), valueSub: inv.provider,
                                    mark: LeadMark(glyph: .symbol("chart.line.uptrend.xyaxis"), tint: Organic.chartColor(5).opacity(0.16), ink: Organic.chartColor(5)))
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .top) { if i > 0 { Hairline() } }
                    }
                }
                SectionHeader(title: "Gold", subtitle: pricedLine(store.goldHoldings, "World price for its weight")) {
                    gold = Investment(name: "", kind: "gold", value: 0)
                }
                Card(padding: .list) {
                    if store.goldHoldings.isEmpty { EmptyNote("No gold yet. Add a bar, a ring or jewellery; it is priced every day.") }
                    ForEach(Array(store.goldHoldings.enumerated()), id: \.element.id) { i, g in
                        Button { gold = g } label: {
                            ListRow(title: g.name,
                                    sub: "\((g.quantity ?? 0).formatted()) \(GoldSheet.unitShort(g.unit ?? "gram")) · \(g.goldKind ?? "24K")",
                                    value: store.format(g.value),
                                    valueSub: g.unitPrice.map { "\(store.format(Int($0.rounded())))/\(GoldSheet.unitShort(g.unit ?? "gram"))" },
                                    mark: LeadMark(glyph: .symbol("circle.hexagongrid"), tint: Organic.chartColor(3).opacity(0.16), ink: Organic.chartColor(3)))
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .top) { if i > 0 { Hairline() } }
                    }
                }
                SectionHeader(title: "Crypto", subtitle: pricedLine(store.coinHoldings, "Priced every hour")) {
                    coin = Investment(name: "", kind: "crypto", value: 0)
                }
                Card(padding: .list) {
                    if store.coinHoldings.isEmpty { EmptyNote("No coins yet. Pick one and type how much you hold.") }
                    ForEach(Array(store.coinHoldings.enumerated()), id: \.element.id) { i, c in
                        Button { coin = c } label: {
                            ListRow(title: c.name,
                                    sub: ["\((c.quantity ?? 0).formatted(.number.precision(.fractionLength(0...8)))) \(c.coinSymbol ?? "")", c.provider]
                                        .filter { !$0.isEmpty }.joined(separator: " · "),
                                    value: store.format(c.value),
                                    valueSub: Finance.gainOnPaid(c).map { store.signed($0) },
                                    mark: LeadMark(glyph: .initials(c.coinSymbol ?? c.name), tint: Organic.n200, ink: Organic.text))
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .top) { if i > 0 { Hairline() } }
                    }
                }
                Card {
                    Text("NISA allowance").font(Organic.title)
                    allowance("This year", Finance.nisaUsedThisYear(store.data), Finance.nisaYearly)
                    allowance("Lifetime", Finance.nisaUsedLifetime(store.data), Finance.nisaLifetime)
                }
                HelpText("Mochi records what you hold and when money goes in; it gives no investment advice. A regular purchase shows in the payment forecast like any bill.")
            }
            .padding(Organic.Space.gutter)
            .readableWidth()
        }
        .background(Organic.bg)
        .navigationTitle("Investments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AddButton { editing = Investment(name: "", value: 0) } } }
        .sheet(item: $editing) { InvestmentEditor(investment: $0) }
        .sheet(item: $gold) { GoldSheet(gold: $0) }
        .sheet(item: $coin) { CoinSheet(coin: $0) }
        .task { await store.refreshPrices() }
    }

    /// "priced today, 09:30" from the oldest price in a section — the one the
    /// whole figure is only as fresh as.
    private func pricedLine(_ holdings: [Investment], _ none: LocalizedStringKey) -> LocalizedStringKey {
        guard let oldest = holdings.compactMap(\.pricedAt).min() else { return none }
        let when = Calendar.current.isDateInToday(oldest)
            ? oldest.formatted(date: .omitted, time: .shortened)
            : oldest.formatted(.dateTime.day().month(.abbreviated).hour().minute())
        return "Priced \(when)"
    }

    private func allowance(_ label: LocalizedStringKey, _ used: Int, _ limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(Organic.value)
                Spacer()
                Text(verbatim: store.format(used)).font(Organic.rowValue)
                Text(verbatim: String(localized: "of \(store.format(limit))")).font(Organic.value).foregroundStyle(Organic.n600)
            }
            ProgressBar(fraction: Double(used) / Double(limit), tint: Organic.chartColor(5))
        }
        .padding(.top, 8)
    }
}

struct InvestmentEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let investment: Investment
    @State private var i = Investment(name: "", value: 0)

    var body: some View {
        SheetScaffold(title: investment.name.isEmpty ? "New investment" : "Investment") {
            FormField("Name (NISA つみたて投資枠)", text: $i.name)
            FormField("Broker", text: $i.provider)
            ChipPicker(label: "Kind", options: ["tsumitate", "growth", "ideco", "other"], selection: i.kind,
                       display: { k in
                           switch k { case "tsumitate": Text("つみたて"); case "growth": Text("成長"); case "ideco": Text("iDeCo"); default: Text("Other") }
                       }) { i.kind = $0 }
            MoneyField("Worth now (from the statement)", value: $i.value)
            MoneyField("Put in so far", value: $i.contributed)
            MoneyField("Put in this year", value: $i.contributedThisYear)
            MoneyField("Every month", value: $i.monthly)
            if i.monthly > 0 {
                ChipPicker(label: "Paid from", options: store.accountNames, selection: i.paidBy) { i.paidBy = $0 }
                FormField("Day of the month", text: Binding(get: { String(i.monthlyDay) }, set: { i.monthlyDay = Int($0) ?? 27 }), numeric: true)
            }
            HelpText("A regular purchase is posted as a move on its day: cash goes down, the holding goes up by the same.")
            PrimaryButton(title: "Save") { guard !i.name.isEmpty else { return }; i.updatedOn = .now; store.saveInvestment(i); dismiss() }
            if !investment.name.isEmpty { DeleteButton(title: "Delete") { store.deleteInvestment(investment); dismiss() } }
        }
        .onAppear { i = investment }
    }
}

// MARK: - Warranties

/// Receipts and cover for the things you own, ending soonest first.
struct WarrantyView: View {
    @Environment(Store.self) private var store

    var body: some View {
        let covered = store.unsold.filter { $0.warrantyUntil != nil }.sorted { $0.warrantyUntil! < $1.warrantyUntil! }
        let soon = covered.first { $0.warrantyUntil! > .now && $0.warrantyUntil! < .now.addingTimeInterval(86_400 * 60) }
        ScrollView {
            VStack(alignment: .leading, spacing: Organic.Space.l) {
                if let soon {
                    Banner(text: "\(soon.name) cover ends in \(days(soon.warrantyUntil!)) days — worth a check before then",
                           symbol: "checkmark.shield", tone: .warn)
                }
                ListHeading(title: "Ending soonest")
                Card(padding: .list) {
                    if covered.isEmpty { EmptyNote("No cover recorded. Add a warranty date on a belonging’s page.") }
                    ForEach(Array(covered.enumerated()), id: \.element.id) { i, item in
                        let d = days(item.warrantyUntil!)
                        NavigationLink { ItemDetailView(item: item) } label: {
                            ListRow(title: item.name,
                                    sub: metaLine(item.warrantyNote, String(localized: "ends \(item.warrantyUntil!.formatted(date: .abbreviated, time: .omitted))")),
                                    value: d < 0 ? String(localized: "Ended") : (d < 365 ? String(localized: "\(d) days") : String(localized: "\(d / 365) years")),
                                    valueColor: d < 60 ? Organic.warn : Organic.n600,
                                    mark: LeadMark(glyph: .symbol("checkmark.shield"), tint: d < 60 ? Organic.warnSoft : Organic.s100,
                                                   ink: d < 60 ? Organic.warn : Organic.s700))
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .top) { if i > 0 { Hairline() } }
                    }
                }
            }
            .padding(Organic.Space.gutter)
            .readableWidth()
        }
        .background(Organic.bg)
        .navigationTitle("Warranties")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func days(_ d: Date) -> Int { Calendar.current.dateComponents([.day], from: .now, to: d).day ?? 0 }
}

// MARK: - Your data

/// Export everything, bring it back, earlier copies. No account, no server:
/// if Mochi ever stops, the export still opens in any spreadsheet.
struct YourDataView: View {
    @Environment(Store.self) private var store
    @State private var shareURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Organic.Space.l) {
                Card {
                    HStack(spacing: Organic.Space.l) {
                        LeadMark(glyph: .symbol("lock.shield"), tint: Organic.s100, ink: Organic.s700, size: 44)
                        Text("No account, no server, no trackers. If Mochi ever stops, the export below still opens in any spreadsheet.")
                            .font(Organic.value)
                    }
                }
                ListHeading(title: "What leaves this iPhone")
                Card {
                    Toggle(isOn: Binding(get: { store.lookUpPlaceNames }, set: { store.setLookUpPlaceNames($0) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Name new places and shops with Apple Maps").font(Organic.row)
                            Text("Where a receipt is scanned somewhere new, the spot is sent to Apple Maps for its name, as the Maps app does; for a shop the book has not seen, so are the phone number and address printed on the receipt. Off: only places and shops you have saved before are named.")
                                .font(Organic.caption).foregroundStyle(Organic.n600)
                        }
                    }
                    .tint(Organic.accent)
                }
                Card {
                    Toggle(isOn: Binding(get: { store.lookUpRates }, set: { store.setLookUpRates($0) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Look up exchange rates").font(Organic.row)
                            Text("Once a day the book’s currency code is sent to \(ExchangeRates.source) for the day’s rates, so a receipt or Apple Pay spend in another currency is counted in yours. No amount or shop is sent. Off: a spend in another currency waits in To review for a rate you type.")
                                .font(Organic.caption).foregroundStyle(Organic.n600)
                        }
                    }
                    .tint(Organic.accent)
                }
                Card {
                    Toggle(isOn: Binding(get: { store.lookUpPrices }, set: { store.setLookUpPrices($0) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Look up gold and coin prices").font(Organic.row)
                            Text("For gold and coins in Investments: “gold” is sent to \(Prices.goldSource) once a day, and the names of the coins you hold to \(Prices.coinSource) once an hour. Never how much you hold. Off: they keep the last price they had.")
                                .font(Organic.caption).foregroundStyle(Organic.n600)
                        }
                    }
                    .tint(Organic.accent)
                }
                ListHeading(title: "Export", trailing: String(localized: "no row limit"))
                Card(padding: .list) {
                    exportRow("Whole book", String(localized: "JSON · reopens in Mochi"), "doc") { store.exportBookFile() }
                    exportRow("Transactions", String(localized: "CSV · \(store.transactions.count) rows"), "list.bullet") { store.exportTransactionsCSV() }
                    exportRow("Belongings", String(localized: "CSV · price, worth, sales"), "shippingbox") { store.exportBelongingsCSV() }
                    exportRow("Receipt photos", String(localized: "\(store.receiptFiles.count) photos"), "doc.viewfinder") { store.exportReceiptsFolder() }
                }
                HelpText("Earlier copies, restore and import sit under Backups in Settings.")
            }
            .padding(Organic.Space.gutter)
            .readableWidth()
        }
        .background(Organic.bg)
        .navigationTitle("Your data")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareURL) { ShareSheet(items: [$0]) }
    }

    private func exportRow(_ title: LocalizedStringKey, _ sub: String, _ symbol: String, make: @escaping () -> URL?) -> some View {
        Button { shareURL = make() } label: {
            HStack(spacing: Organic.Space.l) {
                LeadMark(glyph: .symbol(symbol), tint: Organic.infoSoft, ink: Organic.info)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Organic.row)
                    Text(verbatim: sub).font(Organic.caption).foregroundStyle(Organic.n600)
                }
                Spacer()
                Image(systemName: "square.and.arrow.up").foregroundStyle(Organic.accent)
            }
            .padding(.vertical, Organic.Space.row)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { Hairline() }
    }
}

extension Store {
    /// Every transaction, one row each, in columns a spreadsheet reads.
    func exportTransactionsCSV() -> URL? {
        let df = ISO8601DateFormatter()
        func cell(_ s: String) -> String { s.contains(where: { ",\"\n".contains($0) }) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s }
        var rows = ["date,amount,kind,account,to,merchant,category,note,currency,foreign_amount,rate,source,receipt,place"]
        for t in transactions.sorted(by: { $0.date < $1.date }) {
            rows.append([df.string(from: t.date), String(t.amount), t.kind.rawValue, t.account, t.toAccount ?? "", t.merchant, t.category, t.note,
                         t.currency ?? "", t.foreignAmount.map { $0.rounded() == $0 ? String(Int($0)) : String($0) } ?? "", t.rate.map { String($0) } ?? "", t.source.rawValue, t.receiptFile ?? "", t.placeName ?? ""]
                .map(cell).joined(separator: ","))
        }
        return writeTemp("mochi-transactions.csv", rows.joined(separator: "\n"))
    }

    func exportBelongingsCSV() -> URL? {
        writeTemp("mochi-belongings.csv", exportText(format: .csv, scope: .all))
    }

    /// The receipts folder, copied out so the share sheet can hand it over.
    func exportReceiptsFolder() -> URL? {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mochi-receipts", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for f in receiptFiles { try? FileManager.default.copyItem(at: f, to: dir.appendingPathComponent(f.lastPathComponent)) }
        return dir
    }

    private func writeTemp(_ name: String, _ text: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do { try text.write(to: url, atomically: true, encoding: .utf8) } catch { return nil }
        return url
    }
}
