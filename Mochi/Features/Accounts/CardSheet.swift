import SwiftUI

// MARK: - Card: pay, edit, delete

struct CardSheetView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let card: CreditCard

    @State private var name = ""
    @State private var dueDay = ""
    @State private var closingDay = ""
    @State private var debt = 0
    @State private var ownerID = "me"
    @State private var payFrom = ""
    @State private var last4 = ""
    @State private var confirmingDelete = false
    /// 0 = this month, -1 = last month. The statement covers one of the two.
    @State private var monthOffset = 0

    /// The card as it stands now, so the sheet keeps up with edits.
    private var live: CreditCard { store.data.cards.first { $0.id == card.id } ?? card }
    private var month: Date { Calendar.current.date(byAdding: .month, value: monthOffset, to: .now) ?? .now }
    private var purchases: (items: [Item], total: Int) { store.purchases(on: live, in: month) }

    var body: some View {
        // With "Paid from" set the payment is posted on the due day by itself;
        // the sheet edits the card and shows what was charged on it.
        SheetScaffold(verbatimTitle: live.name) {
            cycleBlock
            editBlock
            purchasesBlock
        }
        .onAppear {
            name = live.name; dueDay = String(live.dueDay)
            closingDay = live.closingDay.map(String.init) ?? ""
            debt = store.cycle(for: live).statementAmount; ownerID = live.ownerID
            payFrom = live.payFrom ?? ""; last4 = live.last4 ?? ""
        }
        .alert("Delete \(live.name)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { store.deleteCard(live); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(live.debt > 0
                 ? "It still carries \(store.format(live.debt)) of debt, which will disappear from your totals."
                 : "Items bought on it keep their history but lose the card link.")
        }
    }

    // MARK: where the card is in its month

    /// The statement, when it is paid, and what has piled up since it closed.
    /// The second figure is the one the old screen could not show: money owed
    /// that is on no statement yet.
    private var cycleBlock: some View {
        let c = store.cycle(for: live)
        return Card {
            HStack(alignment: .firstTextBaseline) {
                Text(c.statementOpen ? "Next payment" : "Statement paid").font(Organic.title)
                Spacer()
                Text(store.format(c.owedStatement)).font(Organic.display(19))
                    .foregroundStyle(c.statementOpen ? Organic.a800 : Organic.n500)
            }
            Text(c.statementOpen
                 ? "Due \(c.statementDue.formatted(.dateTime.day().month(.abbreviated))) · \(store.dueLabel(live.dueDay))"
                 : "Paid on \(c.statementDue.formatted(.dateTime.day().month(.abbreviated))). Type the new statement in when it closes.")
                .font(Organic.meta).foregroundStyle(Organic.n600)
            VStack(spacing: 0) {
                // Only with a closing day is there a "since" to speak of.
                // Without one this row is always zero by construction, and
                // "charged since today" is a line that explains nothing.
                if live.closingDay != nil {
                    LineRow(label: "Charged since \(c.lastClosing.formatted(.dateTime.day().month(.abbreviated))), not yet billed",
                            value: store.format(c.unbilled), tone: .quiet)
                }
                LineRow(label: "Next statement, projected · due \(c.unbilledDue.formatted(.dateTime.day().month(.abbreviated)))",
                        value: store.format(c.projectedNext), tone: .negative)
            }
            .padding(.top, 8)
            if live.closingDay == nil {
                HelpText("No closing day set. Until there is one the figure you type is taken as everything this card is owed today, and nothing is counted as charged since — otherwise a bill on this card would be counted twice. Set it below and the two figures above split properly.", tone: .warning)
                    .padding(.top, 6)
            }
        }
    }

    // MARK: bought on this card

    /// What the card was charged this month or last, to hold against its
    /// statement. Debt is typed in by hand, so this is how you check it.
    private var purchasesBlock: some View {
        let bought = purchases
        return Card {
            Text("Bought on this card").font(Organic.title)
            HelpText(verbatim: metaLine(month.formatted(.dateTime.month(.wide).year()),
                                        bought.items.isEmpty ? "" : String(localized: "\(bought.items.count) items")))
                .padding(.bottom, 8)
            HStack(spacing: 5) {
                Button { monthOffset = 0 } label: { Chip(label: Text("This month"), selected: monthOffset == 0) }
                    .buttonStyle(.plain)
                Button { monthOffset = -1 } label: { Chip(label: Text("Last month"), selected: monthOffset == -1) }
                    .buttonStyle(.plain)
            }
            .padding(.bottom, 4)
            if bought.items.isEmpty {
                EmptyNote("Nothing bought on this card in \(month.formatted(.dateTime.month(.wide))).")
            }
            ForEach(bought.items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.name).font(Organic.row).lineLimit(1)
                    if item.isSold { Badge("SOLD", tone: .accent) }
                    Text(item.boughtOn.formatted(.dateTime.day().month(.abbreviated)))
                        .font(Organic.meta).foregroundStyle(Organic.n500)
                    Spacer()
                    Text(store.format(item.buyPrice)).font(Organic.rowValue)
                }
                .padding(.vertical, Organic.Space.row)
                .overlay(alignment: .top) { if item.id != bought.items.first?.id { Hairline() } }
            }
            if !bought.items.isEmpty {
                CalloutRow(label: "Charged in \(month.formatted(.dateTime.month(.abbreviated)))",
                           value: store.format(bought.total), positive: false)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: edit

    private var editBlock: some View {
        Card {
            Text("Card details").font(Organic.title).padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 8) {
                FormField("Card name", text: $name)
                HStack(spacing: 8) {
                    FormField("Paid on day (26)", text: $dueDay, numeric: true)
                    FormField("Closes on day (15)", text: $closingDay, numeric: true)
                }
                MoneyField("Next payment, as the statement says", value: $debt)
                HelpText("Type what the statement says when it differs from what the book added up; the book adds up the next one itself from the charges on this card.")
                FormField("Last 4 digits (for receipts)", text: $last4, numeric: true)
                ChipPicker(label: "Paid from", options: store.data.wallets.map(\.name), selection: payFrom) { payFrom = $0 }
                HelpText(payFrom.isEmpty ? "Pick the account the statement is paid from and the payment is posted on the due day by itself."
                                         : "On each due day the statement moves from \(payFrom) to this card: cash goes down, the debt goes to zero, nothing counts as spending.")
                OwnerPicker(selection: $ownerID)
                PrimaryButton(title: "Save") {
                    guard !name.isEmpty else { return }
                    var copy = live
                    copy.name = name
                    copy.dueDay = min(max(Int(dueDay.filter(\.isNumber)) ?? 1, 1), 31)
                    copy.debt = debt
                    copy.ownerID = ownerID
                    copy.payFrom = payFrom.isEmpty ? nil : payFrom
                    let digits = last4.filter(\.isNumber)
                    copy.last4 = digits.count == 4 ? digits : nil
                    copy.closingDay = Int(closingDay.filter(\.isNumber)).flatMap { (1...31).contains($0) ? $0 : nil }
                    store.updateCard(copy, oldName: live.name)
                    dismiss()
                }
                DeleteButton(title: "Delete card") { confirmingDelete = true }
            }
        }
    }
}
