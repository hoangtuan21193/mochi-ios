import SwiftUI

/// People: 立替 from split bills and loans, in yen and đồng, in one list.
/// What is owed to you in yen counts in net worth; đồng stays outside the
/// four numbers, as before.
struct PeopleView: View {
    @Environment(Store.self) private var store
    @State private var adding = false
    @State private var settling: Loan?

    var body: some View {
        let owedYen = store.data.loans.filter { $0.direction > 0 && $0.currency == "JPY" }.reduce(0) { $0 + $1.amount }
        let oweYen = store.data.loans.filter { $0.direction < 0 && $0.currency == "JPY" }.reduce(0) { $0 + $1.amount }
        ScrollView {
            VStack(alignment: .leading, spacing: Organic.Space.l) {
                TileGrid {
                    Tile(label: "Owed to you", value: store.format(owedYen),
                         sub: String(localized: "\(store.data.loans.filter { $0.direction > 0 }.count) people"), valueColor: Organic.s700)
                    Tile(label: "You owe", value: store.format(oweYen), sub: vndLine, valueColor: Organic.a700)
                }
                Card(padding: .list) {
                    if store.data.loans.isEmpty {
                        EmptyNote("Nobody yet. Split a bill from Transactions, or add money you lent or borrowed.")
                    }
                    ForEach(Array(store.data.loans.enumerated()), id: \.element.id) { i, loan in
                        Button { settling = loan } label: {
                            ListRow(title: loan.person,
                                    sub: loan.history.prefix(2).map { "\($0.title) \($0.amount)" }.joined(separator: " · "),
                                    value: amount(loan), valueSub: loan.direction > 0 ? String(localized: "owes you") : String(localized: "you owe"),
                                    valueColor: loan.direction > 0 ? Organic.s700 : Organic.a700,
                                    mark: LeadMark(glyph: .initials(loan.person), tint: Organic.n200))
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .top) { if i > 0 { Hairline() } }
                    }
                }
                HelpText("Money you lent or fronted is yours and counts in net worth when it is in yen. Loans in đồng stay out of the four numbers.")
                    .padding(.horizontal, 4)
                if !store.data.loans.isEmpty {
                    NavigationLink { LoanBookView() } label: {
                        LinkLabel("Each loan's history, edit or delete")
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(Organic.Space.gutter)
            .readableWidth()
        }
        .background(Organic.bg)
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AddButton { adding = true } } }
        .sheet(isPresented: $adding) { LoanEditorView() }
        .sheet(item: $settling) { LoanRepayView(loan: $0) }
    }

    private var vndLine: String {
        let vnd = store.data.loans.filter { $0.currency == "VND" }.reduce(0) { $0 + $1.direction * $1.amount }
        return vnd == 0 ? "" : String(localized: "\(abs(vnd).formatted()) ₫ in đồng, outside net worth")
    }

    private func amount(_ l: Loan) -> String {
        l.currency == "JPY" ? store.format(l.amount) : "\(l.amount.formatted()) ₫"
    }
}

/// Split a bill: your share stays spending, everyone else's becomes money
/// owed to you in People. Equal shares by default; any share can be typed.
struct SplitBillView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let transaction: Transaction
    @State private var names: [String] = []
    @State private var newName = ""
    @State private var equal = true
    @State private var shares: [String: Int] = [:]

    private var total: Int { -transaction.amount }
    private var people: [String] { [String(localized: "You")] + names }

    var body: some View {
        SheetScaffold(title: "Split this bill") {
            Card {
                Text(verbatim: metaLine(transaction.merchant, transaction.date.formatted(date: .abbreviated, time: .omitted), transaction.account))
                    .font(Organic.caption).foregroundStyle(Organic.n600)
                Text(verbatim: store.format(total)).font(Organic.display(30))
                ChipPicker(options: ["equal", "amount"], selection: equal ? "equal" : "amount",
                           display: { $0 == "equal" ? Text("Equally") : Text("By amount") }) { equal = $0 == "equal" }
                    .padding(.top, 6)
            }
            ListHeading(title: "Who was there", trailing: String(localized: "\(people.count) people"))
            Card(padding: .list) {
                ForEach(Array(people.enumerated()), id: \.offset) { i, name in
                    HStack(spacing: Organic.Space.l) {
                        LeadMark(glyph: .initials(name), tint: Organic.n200, size: 32)
                        Text(verbatim: name).font(Organic.row)
                        Spacer()
                        if equal {
                            Text(verbatim: store.format(share(of: name))).font(Organic.rowValue)
                        } else {
                            MoneyField("Share", value: Binding(get: { shares[name] ?? 0 }, set: { shares[name] = $0 }))
                                .frame(width: 130)
                        }
                        if i > 0 { RemoveButton { names.removeAll { $0 == name } } }
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .top) { if i > 0 { Hairline() } }
                }
                HStack {
                    FormField("Add a name", text: $newName)
                    AddPill { let n = newName.trimmingCharacters(in: .whitespaces); if !n.isEmpty, !names.contains(n) { names.append(n) }; newName = "" }
                }
                .padding(.vertical, 8)
                .overlay(alignment: .top) { Hairline() }
            }
            Card {
                Text("What this changes").font(Organic.title)
                LineRow(label: "Your spending · \(transaction.category)", value: store.format(share(of: people[0])))
                LineRow(label: "Owed to you by \(names.count) people", value: store.format(total - share(of: people[0])), tone: .positive)
                LineRow(label: "On \(transaction.account)", value: store.format(total), tone: .negative)
            }
            HelpText("Only your share is spending. What the others owe is money coming back, not income, and it sits in People until they pay.")
            PrimaryButton(title: "Split \(store.format(total))") {
                guard !names.isEmpty else { return }
                store.split(transaction, myShare: share(of: people[0]),
                            others: names.map { ($0, share(of: $0)) })
                dismiss()
            }
        }
    }

    private func share(of name: String) -> Int {
        if equal {
            let n = max(1, people.count)
            // The first person carries the rounding, so the shares add up.
            let each = total / n
            return name == people[0] ? total - each * (n - 1) : each
        }
        return shares[name] ?? 0
    }
}
