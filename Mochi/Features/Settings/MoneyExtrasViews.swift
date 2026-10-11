import SwiftUI

// MARK: - Investments

/// Holdings typed from a broker's statement, with the NISA allowance they
/// use. Mochi records; it gives no investment advice.
struct InvestmentsView: View {
    @Environment(Store.self) private var store
    @State private var editing: Investment?

    var body: some View {
        let value = store.investmentsValue
        let put = Finance.investmentsContributed(store.data)
        ScrollView {
            VStack(alignment: .leading, spacing: Organic.Space.l) {
                Card {
                    Text("Worth, as last typed").font(Organic.captionStrong).foregroundStyle(Organic.n600)
                    Text(verbatim: store.format(value)).font(Organic.hero)
                    Text("You put in \(store.format(put)) · \(store.signed(value - put)) on paper").font(Organic.value).foregroundStyle(Organic.n600)
                }
                ListHeading(title: "Accounts")
                Card(padding: .list) {
                    if store.investments.isEmpty { EmptyNote("None yet. Add a NISA or iDeCo account and type what the statement says.") }
                    ForEach(Array(store.investments.enumerated()), id: \.element.id) { i, inv in
                        Button { editing = inv } label: {
                            ListRow(title: inv.name, sub: String(localized: "Put in \(store.format(inv.contributed))"),
                                    value: store.format(inv.value), valueSub: inv.provider,
                                    mark: LeadMark(glyph: .symbol("chart.line.uptrend.xyaxis"), tint: Organic.chartColor(5).opacity(0.16), ink: Organic.chartColor(5)))
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
                         t.currency ?? "", t.foreignAmount.map(String.init) ?? "", t.rate.map { String($0) } ?? "", t.source.rawValue, t.receiptFile ?? "", t.placeName ?? ""]
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
