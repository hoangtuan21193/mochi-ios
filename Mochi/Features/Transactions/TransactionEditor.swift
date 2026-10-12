import SwiftUI

/// Add or change one transaction. The same form reviews what a scan, Apple
/// Pay or an import brought in: every field arrives filled, and saving is
/// the confirmation. It ends, as every form does, by saying what will happen.
struct TransactionEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Editing a transaction already in the book.
    var existing: Transaction? = nil
    /// A new one that arrives filled in (from a scan or a place).
    var prefill: Transaction? = nil

    @State private var t = Transaction(date: .now, amount: 0, kind: .spend, account: "")
    @State private var amount = 0
    @State private var foreign = false
    @State private var foreignCode = "VND"
    @State private var foreignAmount = 0.0
    @State private var rateText = ""
    @State private var confirmingDelete = false
    @State private var splitting = false
    @State private var belonging = false
    @State private var suggested: Rule?

    private var isNew: Bool { existing == nil }

    var body: some View {
        SheetScaffold(title: isNew ? "Add a spend" : "Transaction") {
            Card {
                ChipPicker(options: ["spend", "income", "move", "refund"], selection: t.kind.rawValue,
                           display: { kindName($0) }) { t.kind = TransactionKind(rawValue: $0) ?? .spend }
                MoneyField("Amount", value: $amount, prominent: true)
                    .padding(.top, 8)
                if t.kind == .spend || t.kind == .refund {
                    Toggle("Paid in another currency", isOn: $foreign).font(Organic.body).tint(Organic.accent2)
                        .padding(.top, 6)
                    if foreign { foreignFields }
                }
            }
            Card {
                FormField(t.kind == .move ? "What for (optional)" : "Shop or payer", text: $t.merchant)
                if t.kind == .spend || t.kind == .refund {
                    ChipPicker(label: "Category", options: store.spendingCategories.map(\.name), selection: t.category) { t.category = $0 }
                        .padding(.top, 8)
                }
                ChipPicker(label: t.kind == .move ? "From" : (t.kind == .income ? "Into" : "Paid with"),
                           options: store.accountNames, selection: t.account) { t.account = $0 }
                    .padding(.top, 8)
                if t.kind == .move {
                    ChipPicker(label: "To", options: moveTargets, selection: t.toAccount ?? "") { t.toAccount = $0 }
                        .padding(.top, 8)
                }
                DatePicker("When", selection: $t.date, displayedComponents: [.date, .hourAndMinute])
                    .font(Organic.body).padding(.top, 8)
                FormField("Note", text: $t.note).padding(.top, 8)
                if let place = t.placeName {
                    Label { Text(verbatim: place) } icon: { Image(systemName: "mappin") }
                        .font(Organic.caption).foregroundStyle(Organic.n600).padding(.top, 8)
                }
            }
            if let file = t.receiptFile, let image = store.receiptImage(file) {
                Card {
                    Text("Receipt").font(Organic.title)
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: Organic.rSmall)).padding(.top, 6)
                    Text("Kept on this iPhone").font(Organic.caption).foregroundStyle(Organic.n600)
                }
            }
            HelpText(verbatim: preview)
            PrimaryButton(title: isNew ? "Save" : (t.needsReview ? "Confirm" : "Save")) { save() }
            if !isNew {
                HStack(spacing: Organic.Space.m) {
                    if t.kind == .spend {
                        SecondaryButton(title: "Split…") { splitting = true }
                        SecondaryButton(title: "It’s a belonging") { belonging = true }
                    }
                }
                DeleteButton(title: "Delete") { confirmingDelete = true }
            }
        }
        .onAppear(perform: load)
        .alert("Delete this transaction?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { if let existing { store.deleteTransaction(existing) }; dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The balance it changed goes back to what it was without it.")
        }
        .alert("Always put \(suggested?.contains ?? "") in \(suggested?.category ?? "")?",
               isPresented: Binding(get: { suggested != nil }, set: { if !$0 { suggested = nil; dismiss() } })) {
            Button("Make it a rule") { if let r = suggested { store.addRule(r) }; suggested = nil; dismiss() }
            Button("Not now", role: .cancel) { suggested = nil; dismiss() }
        } message: {
            Text("You chose it there three times. New ones will be filled in; you can still change any of them.")
        }
        .sheet(isPresented: $splitting) { SplitBillView(transaction: current) }
        .sheet(isPresented: $belonging) { MakeBelongingView(transaction: current) { dismiss() } }
    }

    private static let currencies = ["VND", "USD", "EUR", "KRW"]

    private var foreignFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            // A tap abroad can bring a currency outside the usual four; it gets its chip.
            ChipPicker(options: Self.currencies.contains(foreignCode) ? Self.currencies : Self.currencies + [foreignCode],
                       selection: foreignCode) {
                foreignCode = $0
                if let r = store.data.rates?[$0] { rateText = String(r) }
            }
            HStack(spacing: 8) {
                MoneyField("Paid", value: $foreignAmount, unit: .suffix(foreignCode), fractionDigits: Currency.fractionDigits(foreignCode))
                FormField("Per ¥1", text: $rateText, decimal: true).frame(width: 110)
            }
            if let rate = Double(rateText), rate > 0, foreignAmount > 0 {
                HelpText("≈ \(store.format(Finance.convert(foreignAmount, rate: rate))) at \(rateText) \(foreignCode) per yen · your rate, it never changes by itself")
            } else {
                HelpText("Type the rate from your exchange or remittance slip.")
            }
        }
        .padding(.top, 6)
        .onChange(of: foreignAmount) { _, _ in syncForeign() }
        .onChange(of: rateText) { _, _ in syncForeign() }
    }

    private func syncForeign() {
        if let rate = Double(rateText), rate > 0, foreignAmount > 0 { amount = Finance.convert(foreignAmount, rate: rate) }
    }

    private var moveTargets: [String] {
        store.accountNames.filter { $0 != t.account } + store.installments.map(\.name)
    }

    private var current: Transaction {
        var c = t
        c.amount = signedAmount
        return c
    }

    private var signedAmount: Int {
        switch t.kind {
        case .spend, .asset: return -abs(amount)
        case .adjustment: return t.amount
        default: return abs(amount)
        }
    }

    private var preview: String {
        guard amount > 0, !t.account.isEmpty else { return String(localized: "Type the amount and pick where it was paid from.") }
        let where_ = t.account
        switch t.kind {
        case .spend:
            if store.isCard(where_), let card = store.data.cards.first(where: { $0.name == where_ }) {
                let c = store.cycle(for: card)
                return String(localized: "\(store.format(amount)) goes on \(where_) · paid \(c.unbilledDue.formatted(.dateTime.day().month(.abbreviated)))")
            }
            return String(localized: "\(store.format(amount)) leaves \(where_) · counted in \(t.category.isEmpty ? String(localized: "no category") : t.category)")
        case .income: return String(localized: "\(store.format(amount)) lands in \(where_)")
        case .move: return String(localized: "\(store.format(amount)) moves from \(where_) to \(t.toAccount ?? "…") · not spending")
        case .refund: return String(localized: "\(store.format(amount)) comes back to \(where_)")
        default: return ""
        }
    }

    private func kindName(_ raw: String) -> Text {
        switch raw {
        case "income": return Text("Money in")
        case "move": return Text("Move")
        case "refund": return Text("Refund")
        default: return Text("Spend")
        }
    }

    private func load() {
        if let base = existing ?? prefill {
            t = base
            amount = abs(base.amount)
            if let c = base.currency, let f = base.foreignAmount {
                foreign = true; foreignCode = c; foreignAmount = f
                rateText = base.rate.map { String($0) } ?? ""
            }
        } else {
            t.account = store.data.wallets.first?.name ?? store.accountNames.first ?? ""
        }
        if t.account.isEmpty { t.account = store.accountNames.first ?? "" }
    }

    private func save() {
        guard amount > 0, !t.account.isEmpty else { return }
        var out = current
        out.needsReview = false
        if foreign, let rate = Double(rateText), rate > 0 {
            out.currency = foreignCode; out.foreignAmount = foreignAmount; out.rate = rate
            store.setRate(foreignCode, rate)
        } else if !foreign {
            out.currency = nil; out.foreignAmount = nil; out.rate = nil
        }
        if out.kind != .move { out.toAccount = nil }
        if isNew { store.addTransaction(out) } else { store.updateTransaction(out) }
        if out.kind == .spend, let r = store.suggestedRule(for: out.merchant) { suggested = r; return }
        dismiss()
    }
}

/// Turns a spend into a belonging: its name, what it is worth now and the
/// points it earned. The money has left either way; this says it became a
/// thing you still own.
struct MakeBelongingView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let transaction: Transaction
    var done: () -> Void = {}
    @State private var name = ""
    @State private var worth = 0
    @State private var points = 0
    @State private var toResell = false

    var body: some View {
        SheetScaffold(title: "Track as a belonging") {
            Card {
                Text(verbatim: metaLine(transaction.merchant, transaction.date.formatted(date: .abbreviated, time: .omitted), transaction.account))
                    .font(Organic.caption).foregroundStyle(Organic.n600)
                Text(verbatim: store.format(-transaction.amount)).font(Organic.display(30))
            }
            Card {
                FormField("Name", text: $name)
                MoneyField("Worth now", value: $worth).padding(.top, 8)
                MoneyField("Points earned", value: $points, unit: .suffix("pt")).padding(.top, 8)
                HelpText("Worth now is your figure. Check Mercari 持ち物査定 or a trade-in quote and type what it says.").padding(.top, 6)
                ChipPicker(label: "Why you bought it", options: ["use", "resell"], selection: toResell ? "resell" : "use",
                           display: { $0 == "resell" ? Text("Use, may sell later") : Text("To use") }) { toResell = $0 == "resell" }
                    .padding(.top, 8)
            }
            Card {
                Text("What this changes").font(Organic.title)
                LineRow(label: "Spending", value: store.signed(0))
                LineRow(label: "Belongings", value: store.signed(worth), tone: .positive)
                LineRow(label: "Net worth", value: store.signed(worth + transaction.amount),
                        tone: worth + transaction.amount < 0 ? .negative : .positive, total: true)
            }
            HelpText("Not counted as spending: the money became something you own. Its real cost shows as it loses value, and points sit beside it, never in cash.")
            PrimaryButton(title: "Save belonging") {
                guard !name.isEmpty else { return }
                _ = store.makeBelonging(from: transaction, name: name, worth: worth, points: points, toResell: toResell)
                dismiss(); done()
            }
        }
        .onAppear {
            name = transaction.note.isEmpty ? transaction.merchant : transaction.note
            worth = -transaction.amount
        }
    }
}
