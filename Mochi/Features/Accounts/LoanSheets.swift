import SwiftUI

// MARK: - Loans

struct LoanEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var person = ""
    @State private var lent = true
    @State private var amount = 0
    @State private var currency = "JPY"
    @State private var hasDate = false
    @State private var expectedOn = Date.now

    var body: some View {
        SheetScaffold(title: "New loan") {
            FormField("Who", text: $person)
            HStack(spacing: 5) {
                Button { lent = true } label: { Chip(label: Text("They owe me"), selected: lent, tint: Organic.s600) }
                    .buttonStyle(.plain)
                Button { lent = false } label: { Chip(label: Text("I owe them"), selected: !lent, tint: Organic.a600) }
                    .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                MoneyField("Amount", value: $amount, unit: .currency(Currency(code: currency) ?? .jpy))
                ForEach(["JPY", "VND"], id: \.self) { c in
                    Button { currency = c } label: { Chip(label: Text(verbatim: c), selected: currency == c) }
                        .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                ToggleChip(label: hasDate ? "Date agreed" : "No date yet",
                           tint: hasDate ? Organic.s600 : Organic.n500) { hasDate.toggle() }
                if hasDate {
                    DatePicker("", selection: $expectedOn, displayedComponents: .date).labelsHidden()
                }
            }
            HelpText(hasDate
                     ? "With a date it enters the cash forecast on that day. Without one it counts in net worth only."
                     : "A loan is a promise, not cash — it stays out of your wallet totals until it is repaid.")
            PrimaryButton(title: "Add loan") {
                guard !person.isEmpty else { return }
                store.addLoan(Loan(person: person, direction: lent ? 1 : -1,
                                   amount: amount,
                                   currency: currency,
                                   expectedOn: hasDate ? expectedOn : nil))
                dismiss()
            }
        }
    }
}

struct LoanRepayView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let loan: Loan

    @State private var amount = 0
    @State private var wallet = ""
    @State private var moveCash = true
    @State private var confirmingDelete = false

    private var live: Loan { store.data.loans.first { $0.id == loan.id } ?? loan }
    private var value: Int { min(amount, live.amount) }
    private var isYen: Bool { live.currency == "JPY" }

    var body: some View {
        SheetScaffold(verbatimTitle: live.person) {
            Card {
                Text(live.direction > 0 ? "They owe you" : "You owe them")
                    .font(Organic.caption).foregroundStyle(Organic.n600)
                Text(isYen ? store.format(live.amount) : "\(live.amount.formatted()) ₫")
                    .font(Organic.display(26))
                    .foregroundStyle(live.direction > 0 ? Organic.s700 : Organic.a800)
                    .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 8) {
                    MoneyField("Repayment amount", value: $amount, unit: .currency(Currency(code: live.currency) ?? .jpy))
                    Button { amount = live.amount } label: {
                        Chip(label: Text("All of it"), selected: value == live.amount && live.amount > 0)
                    }
                    .buttonStyle(.plain)

                    if isYen && !store.data.wallets.isEmpty {
                        ToggleChip(label: moveCash ? "Cash moves too" : "Record only",
                                   tint: moveCash ? Organic.s600 : Organic.n500) { moveCash.toggle() }
                        if moveCash {
                            ChipPicker(label: "Wallet", options: store.data.wallets.map(\.name), selection: wallet) {
                                wallet = $0
                            }
                            HelpText(live.direction > 0
                                     ? "\(store.format(value)) arrives in \(wallet)."
                                     : "\(store.format(value)) leaves \(wallet).")
                        }
                    } else if !isYen {
                        HelpText("Đồng loans are tracked on their own — no wallet moves.")
                    }

                    PrimaryButton(title: "Record repayment") {
                        store.repayLoan(live, amount: value,
                                        wallet: (isYen && moveCash && !wallet.isEmpty) ? wallet : nil)
                        dismiss()
                    }
                    .disabled(value <= 0)
                    .opacity(value <= 0 ? 0.5 : 1)
                }
            }

            if !live.history.isEmpty {
                Card {
                    Text("History").font(Organic.title).padding(.bottom, 4)
                    ForEach(live.history) { e in
                        HStack {
                            Text("\(e.date.formatted(date: .numeric, time: .omitted)) · \(e.title)")
                            Spacer()
                            Text(e.amount).fontWeight(.semibold)
                        }
                        .font(Organic.caption).foregroundStyle(Organic.n600)
                        .padding(.vertical, 4)
                    }
                }
            }

            DeleteButton(title: "Delete loan") { confirmingDelete = true }
        }
        .onAppear {
            wallet = store.data.wallets.first?.name ?? ""
            amount = live.amount
        }
        .alert("Delete this loan?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { store.deleteLoan(live); dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
