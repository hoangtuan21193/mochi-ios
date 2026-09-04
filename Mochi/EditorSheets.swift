import SwiftUI

/// The edit / pay / delete half of Wallet. Adding was already inline on the
/// screen; everything that changes or removes an existing row lives here so the
/// list rows stay one line tall.

/// Owner chip row, shared by the wallet and card editors.
struct OwnerPicker: View {
    @Environment(Store.self) private var store
    @Binding var selection: String
    var body: some View {
        let owners = store.data.owners
        ChipPicker(label: "Owner",
                   options: owners.map(\.name),
                   selection: owners.first { $0.id == selection }?.name ?? "",
                   onPick: { name in
                       if let o = owners.first(where: { $0.name == name }) { selection = o.id }
                   })
    }
}

// MARK: - Wallet

struct WalletEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let wallet: Wallet

    @State private var name = ""
    @State private var note = ""
    @State private var balance = ""
    @State private var ownerID = "me"
    @State private var confirmingDelete = false

    private var balanceValue: Int { Int(balance.filter { $0.isNumber || $0 == "-" }) ?? 0 }

    var body: some View {
        SheetScaffold(title: "Edit wallet") {
            FormField("Wallet or account name", text: $name)
            FormField("Note (bank, not withdrawn…)", text: $note)
            FormField { TextField("Balance now", text: $balance).keyboardType(.numbersAndPunctuation) }
            OwnerPicker(selection: $ownerID)

            if balanceValue != wallet.balance {
                HelpText("Correcting the balance by \(store.format(balanceValue - wallet.balance)) — it lands in the activity log, not in profit.")
            }

            PrimaryButton(title: "Save") {
                guard !name.isEmpty else { return }
                var copy = wallet
                copy.name = name; copy.note = note
                copy.balance = balanceValue; copy.ownerID = ownerID
                store.updateWallet(copy, oldName: wallet.name)
                dismiss()
            }
            DeleteButton(title: "Delete wallet") { confirmingDelete = true }
                .padding(.top, 4)
        }
        .onAppear {
            name = wallet.name; note = wallet.note
            balance = String(wallet.balance); ownerID = wallet.ownerID
        }
        .alert("Delete \(wallet.name)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { store.deleteWallet(wallet); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(wallet.balance != 0
                 ? "Its \(store.format(wallet.balance)) leaves your cash total."
                 : "This cannot be undone.")
        }
    }
}

// MARK: - Point wallet

struct PointWalletEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// nil = creating a new one.
    let pointWallet: PointWallet?

    @State private var name = ""
    @State private var note = ""
    @State private var points = ""

    var body: some View {
        SheetScaffold(title: pointWallet == nil ? "New point wallet" : "Edit point wallet") {
            FormField("Name (MapCamera points…)", text: $name)
            FormField("Note", text: $note)
            FormField("Points", text: $points, numeric: true)
            HelpText("Points are never counted as cash.")

            PrimaryButton(title: pointWallet == nil ? "Add point wallet" : "Save") {
                guard !name.isEmpty else { return }
                let value = Int(points.filter(\.isNumber)) ?? 0
                if let pointWallet {
                    var copy = pointWallet
                    copy.name = name; copy.note = note; copy.points = value
                    store.updatePointWallet(copy, oldName: pointWallet.name)
                } else {
                    store.addPointWallet(PointWallet(name: name, points: value, note: note))
                }
                dismiss()
            }
            if let pointWallet {
                DeleteButton(title: "Delete point wallet") {
                    store.deletePointWallet(pointWallet); dismiss()
                }
                .padding(.top, 4)
            }
        }
        .onAppear {
            guard let pointWallet else { return }
            name = pointWallet.name; note = pointWallet.note; points = String(pointWallet.points)
        }
    }
}

// MARK: - Card: pay, edit, delete

struct CardSheetView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let card: CreditCard

    @State private var payAmount = ""
    @State private var payWallet = ""
    @State private var name = ""
    @State private var dueDay = ""
    @State private var limit = ""
    @State private var debt = ""
    @State private var ownerID = "me"
    @State private var confirmingDelete = false
    @State private var editing = false

    /// The card as it stands now, so the sheet keeps up with its own payments.
    private var live: CreditCard { store.data.cards.first { $0.id == card.id } ?? card }
    private var payValue: Int { min(Int(payAmount.filter(\.isNumber)) ?? 0, live.debt) }
    private var walletBalance: Int {
        store.data.wallets.first { $0.name == payWallet }?.balance ?? 0
    }

    var body: some View {
        SheetScaffold(title: live.name) {
            payBlock
            if editing { editBlock } else {
                SecondaryButton(title: "Edit card details", style: .outlined) { editing = true }
            }
        }
        .onAppear {
            payWallet = store.data.wallets.max { $0.balance < $1.balance }?.name ?? ""
            payAmount = live.debt > 0 ? String(live.debt) : ""
            name = live.name; dueDay = String(live.dueDay)
            limit = String(live.limit); debt = String(live.debt); ownerID = live.ownerID
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

    // MARK: pay

    private var payBlock: some View {
        Card {
            Text("Pay this bill").font(Organic.title)
            HelpText("Owing \(store.format(live.debt)) · due on the \(live.dueDay)")
                .padding(.bottom, 8)

            if live.debt == 0 {
                Text("Nothing owed on this card.")
                    .font(Organic.value).foregroundStyle(Organic.s700)
                    .padding(.vertical, 6)
            } else if store.data.wallets.isEmpty {
                Text("Add a wallet first — a bill has to be paid out of somewhere.")
                    .font(Organic.value).foregroundStyle(Organic.a800)
                    .padding(.vertical, 6)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    FormField("Amount", text: $payAmount, numeric: true)
                    HStack(spacing: 5) {
                        Button { payAmount = String(live.debt) } label: {
                            Chip(label: "Full \(store.format(live.debt))", selected: payValue == live.debt)
                        }
                        .buttonStyle(.plain)
                        Button { payAmount = String(live.debt / 2) } label: {
                            Chip(label: "Half", selected: payValue == live.debt / 2 && live.debt > 0)
                        }
                        .buttonStyle(.plain)
                    }
                    ChipPicker(label: "From", options: store.data.wallets.map(\.name), selection: payWallet) {
                        payWallet = $0
                    }
                    HelpText(payValue > walletBalance
                             ? "\(payWallet) only holds \(store.format(walletBalance)) — this would overdraw it by \(store.format(payValue - walletBalance))."
                             : "\(payWallet) keeps \(store.format(walletBalance - payValue)) after paying.",
                             tone: payValue > walletBalance ? .warning : .quiet)

                    PrimaryButton(title: "Pay \(store.format(payValue))") {
                        store.payCard(live, amount: payValue, from: payWallet)
                        payAmount = String(store.data.cards.first { $0.id == live.id }?.debt ?? 0)
                    }
                    .disabled(payValue <= 0 || payWallet.isEmpty)
                    .opacity(payValue <= 0 || payWallet.isEmpty ? 0.5 : 1)
                }
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
                    FormField("Due day", text: $dueDay, numeric: true)
                    FormField("Limit", text: $limit, numeric: true)
                }
                FormField("Debt owed", text: $debt, numeric: true)
                HelpText("Correct the debt here only to match a statement; buying and paying move it on their own.")
                OwnerPicker(selection: $ownerID)
                PrimaryButton(title: "Save") {
                    guard !name.isEmpty else { return }
                    var copy = live
                    copy.name = name
                    copy.dueDay = min(max(Int(dueDay.filter(\.isNumber)) ?? 1, 1), 31)
                    copy.limit = Int(limit.filter(\.isNumber)) ?? 0
                    copy.debt = Int(debt.filter(\.isNumber)) ?? 0
                    copy.ownerID = ownerID
                    store.updateCard(copy, oldName: live.name)
                    dismiss()
                }
                DeleteButton(title: "Delete card") { confirmingDelete = true }
            }
        }
    }
}

// MARK: - Owner

struct OwnerEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let owner: Owner

    @State private var name = ""
    @State private var refusal: String?

    var body: some View {
        SheetScaffold(title: "Edit owner") {
            FormField("Name", text: $name)
            PrimaryButton(title: "Save") {
                guard !name.isEmpty else { return }
                var copy = owner; copy.name = name
                store.updateOwner(copy)
                dismiss()
            }
            if owner.id != "me" {
                DeleteButton(title: "Delete owner") {
                    if let why = store.deleteOwner(owner) { refusal = why } else { dismiss() }
                }
                .padding(.top, 4)
            } else {
                HelpText("\"Me\" is built in — the card drawdown splits your bills from the ones you pay on behalf of others by it.")
            }
            if let refusal {
                Text(refusal).font(Organic.value).foregroundStyle(Organic.a800)
            }
        }
        .onAppear { name = owner.name }
    }
}

// MARK: - Loans

struct LoanEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var person = ""
    @State private var lent = true
    @State private var amount = ""
    @State private var currency = "JPY"

    var body: some View {
        SheetScaffold(title: "New loan") {
            FormField("Who", text: $person)
            HStack(spacing: 5) {
                Button { lent = true } label: { Chip(label: "They owe me", selected: lent, tint: Organic.s600) }
                    .buttonStyle(.plain)
                Button { lent = false } label: { Chip(label: "I owe them", selected: !lent, tint: Organic.a600) }
                    .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                FormField("Amount", text: $amount, numeric: true)
                ForEach(["JPY", "VND"], id: \.self) { c in
                    Button { currency = c } label: { Chip(label: c, selected: currency == c) }
                        .buttonStyle(.plain)
                }
            }
            HelpText("A loan is a promise, not cash — it stays out of your wallet totals until it is repaid.")
            PrimaryButton(title: "Add loan") {
                guard !person.isEmpty else { return }
                store.addLoan(Loan(person: person, direction: lent ? 1 : -1,
                                   amount: Int(amount.filter(\.isNumber)) ?? 0,
                                   currency: currency))
                dismiss()
            }
        }
    }
}

struct LoanRepayView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let loan: Loan

    @State private var amount = ""
    @State private var wallet = ""
    @State private var moveCash = true
    @State private var confirmingDelete = false

    private var live: Loan { store.data.loans.first { $0.id == loan.id } ?? loan }
    private var value: Int { min(Int(amount.filter(\.isNumber)) ?? 0, live.amount) }
    private var isYen: Bool { live.currency == "JPY" }

    var body: some View {
        SheetScaffold(title: live.person) {
            Card {
                Text(live.direction > 0 ? "They owe you" : "You owe them")
                    .font(Organic.caption).foregroundStyle(Organic.n600)
                Text(isYen ? store.format(live.amount) : "\(live.amount.formatted()) ₫")
                    .font(Organic.display(26))
                    .foregroundStyle(live.direction > 0 ? Organic.s700 : Organic.a800)
                    .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 8) {
                    FormField("Repayment amount", text: $amount, numeric: true)
                    Button { amount = String(live.amount) } label: {
                        Chip(label: "All of it", selected: value == live.amount && live.amount > 0)
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
            amount = String(live.amount)
        }
        .alert("Delete this loan?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { store.deleteLoan(live); dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Sales channel

struct ChannelEditorView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let channel: SalesChannel

    @State private var name = ""
    @State private var rate = ""
    @State private var isPoints = false
    @State private var destination = ""
    @State private var createWallet = false
    @State private var confirmingDelete = false

    private var newWalletName: String {
        SalesChannel.defaultDestinationName(for: name.isEmpty ? channel.name : name, isPoints: isPoints)
    }
    private var existingDestinations: [String] {
        isPoints ? store.data.pointWallets.map(\.name) : store.data.wallets.map(\.name)
    }
    private var newOption: String { "New: \(newWalletName)" }
    private var destinationOptions: [String] {
        (existingDestinations.contains(newWalletName) ? [] : [newOption]) + ["Not set"] + existingDestinations
    }

    private var itemsUsing: Int {
        store.data.items.filter { $0.plannedChannel == channel.name && !$0.isSold }.count
    }

    var body: some View {
        SheetScaffold(title: "Edit channel") {
            FormField("Channel name", text: $name)
            HStack(spacing: 8) {
                FormField(isPoints ? "Bonus %" : "Fee %", text: $rate, decimal: true)
                ToggleChip(label: isPoints ? "Point" : "Cash",
                           tint: isPoints ? Organic.a600 : Organic.s600) {
                    isPoints.toggle(); destination = ""; createWallet = false
                }
            }
            HelpText(isPoints
                     ? "A point channel pays \(rate.isEmpty ? "0" : rate)% on top, into points — never into cash."
                     : "A cash channel takes \(rate.isEmpty ? "0" : rate)% off the sale price.")

            // Same one-tap create as the add form. A channel that was added
            // before destinations existed should not need a trip to Wallet.
            ChipPicker(label: isPoints ? "Points land in" : "Money lands in",
                       options: destinationOptions,
                       selection: createWallet ? newOption : (destination.isEmpty ? "Not set" : destination),
                       accentOptions: [newOption]) { pick in
                if pick == newOption { destination = ""; createWallet = true }
                else if pick == "Not set" { destination = ""; createWallet = false }
                else { destination = pick; createWallet = false }
            }
            .padding(.top, 4)
            if createWallet {
                HelpText(isPoints ? "A point wallet is created for it, starting at 0."
                                  : "A wallet is created for it at ¥0, marked \"not withdrawn\".")
            } else if destination.isEmpty {
                HelpText(isPoints
                         ? "Without a point wallet, a sale here records but the points land nowhere."
                         : "Without a destination, proceeds fall into your first wallet — usually the bank, while the money is really still on the marketplace.",
                         tone: .warning)
            }

            PrimaryButton(title: "Save") {
                guard !name.isEmpty else { return }
                var copy = channel
                copy.name = name
                copy.rate = Double(rate.replacingOccurrences(of: ",", with: ".")) ?? 0
                copy.isPoints = isPoints
                copy.destination = createWallet ? store.makeDestination(for: copy) : destination
                store.updateChannel(copy, oldName: channel.name)
                dismiss()
            }
            DeleteButton(title: "Delete channel") { confirmingDelete = true }
                .padding(.top, 4)
        }
        .onAppear {
            name = channel.name; rate = channel.rate.formatted()
            isPoints = channel.isPoints; destination = channel.destination
        }
        .alert("Delete \(channel.name)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { store.deleteChannel(channel); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(itemsUsing > 0
                 ? "\(itemsUsing) unsold item(s) plan to sell here; their estimate falls back to the full price."
                 : "This cannot be undone.")
        }
    }
}

// MARK: - Instalment plan: progress, pay early, edit, delete

struct InstallmentSheetView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let plan: Installment

    @State private var prepay = ""
    @State private var wallet = ""
    @State private var moveCash = true
    @State private var editing = false
    @State private var confirmingDelete = false

    @State private var name = ""
    @State private var lender = ""
    @State private var principal = ""
    @State private var months = ""
    @State private var firstAmount = ""
    @State private var firstDate = Date.now
    @State private var itemID: String? = nil
    @State private var closed = false

    /// The plan as it stands now, so the sheet keeps up with its own payments.
    private var live: Installment { store.installments.first { $0.id == plan.id } ?? plan }
    private var prepayValue: Int { min(Int(prepay.filter(\.isNumber)) ?? 0, live.remaining()) }
    private var linkedItem: Item? { live.itemID.flatMap { id in store.data.items.first { $0.id == id } } }

    var body: some View {
        SheetScaffold(title: live.name) {
            summaryCard
            if !live.isSettled() { prepayCard }
            if editing { editBlock } else {
                SecondaryButton(title: "Edit plan details", style: .outlined) { editing = true }
            }
        }
        .onAppear {
            wallet = store.data.wallets.max { $0.balance < $1.balance }?.name ?? ""
            name = live.name; lender = live.lender
            principal = String(live.principal); months = String(live.months)
            firstAmount = String(live.firstAmount); firstDate = live.firstDate
            itemID = live.itemID; closed = live.closed
        }
        .alert("Delete \(live.name)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { store.deleteInstallment(live); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(live.remaining() > 0
                 ? "It still owes \(store.format(live.remaining())), which will disappear from your totals."
                 : "This cannot be undone.")
        }
    }

    // MARK: summary

    private var summaryCard: some View {
        let paid = live.principal - live.remaining()
        let ratio = live.principal > 0 ? Double(paid) / Double(live.principal) : 1
        return Card {
            Text(live.isSettled() ? "Paid off" : "Still owed")
                .font(Organic.caption).foregroundStyle(Organic.n600)
            Text(store.format(live.remaining()))
                .font(Organic.display(26))
                .foregroundStyle(live.isSettled() ? Organic.s700 : Organic.a800)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Organic.n200)
                    Capsule().fill(live.isSettled() ? Organic.s500 : Organic.a500)
                        .frame(width: geo.size.width * min(1, ratio))
                }
            }
            .frame(height: 6).padding(.vertical, 10)

            HStack(spacing: 8) {
                Metric(label: "Borrowed", value: store.format(live.principal))
                Metric(label: "Paid so far", value: store.format(paid))
                Metric(label: "Per month", value: store.format(live.regular))
            }
            HStack(spacing: 8) {
                Metric(label: "Months left", value: live.isSettled() ? "—" : "\(live.monthsLeft()) of \(live.months)")
                Metric(label: "Next debit", value: live.nextDue().map {
                    "\(store.format($0.amount)) · \($0.date.formatted(.dateTime.day().month(.abbreviated)))"
                } ?? "—")
                Metric(label: "Last payment", value: live.projectedEnd().formatted(.dateTime.month(.abbreviated).year()))
            }
            .padding(.top, 10)

            Text(metaLine(live.lender,
                          "first \(store.format(live.firstAmount)) on \(live.firstDate.formatted(date: .abbreviated, time: .omitted))",
                          linkedItem.map { $0.isSold ? "\($0.name) — sold" : $0.name } ?? "",
                          live.extraPaid > 0 ? "paid early \(store.format(live.extraPaid))" : ""))
                .font(Organic.meta).foregroundStyle(Organic.n600).padding(.top, 10)
            Text("Payments are counted from the calendar as their dates pass. Your bank balance is yours to correct in Wallets.")
                .font(Organic.meta).foregroundStyle(Organic.n500).padding(.top, 4)
        }
    }

    // MARK: pay early

    private var prepayCard: some View {
        Card {
            Text("Pay early").font(Organic.title)
            HelpText("A lump sum takes months off the end of the plan. Paying the rest closes it.")
                .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 8) {
                FormField("Amount", text: $prepay, numeric: true)
                Button { prepay = String(live.remaining()) } label: {
                    Chip(label: "Rest of it · \(store.format(live.remaining()))",
                         selected: prepayValue == live.remaining() && live.remaining() > 0)
                }
                .buttonStyle(.plain)
                if !store.data.wallets.isEmpty {
                    ToggleChip(label: moveCash ? "Cash moves too" : "Record only",
                               tint: moveCash ? Organic.s600 : Organic.n500) { moveCash.toggle() }
                    if moveCash {
                        ChipPicker(label: "From", options: store.data.wallets.map(\.name), selection: wallet) {
                            wallet = $0
                        }
                    }
                }
                PrimaryButton(title: "Record \(store.format(prepayValue)) paid early") {
                    store.prepayInstallment(live, amount: prepayValue,
                                            from: (moveCash && !wallet.isEmpty) ? wallet : nil)
                    prepay = ""
                }
                .disabled(prepayValue <= 0)
                .opacity(prepayValue <= 0 ? 0.5 : 1)
            }
        }
    }

    // MARK: edit

    private var monthsValue: Int { max(1, Int(months.filter(\.isNumber)) ?? 1) }

    private var editBlock: some View {
        Card {
            Text("Plan details").font(Organic.title).padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 8) {
                FormField("What it bought", text: $name)
                FormField("Lender", text: $lender)
                HStack(spacing: 8) {
                    FormField("Total borrowed", text: $principal, numeric: true)
                    FormField("Months", text: $months, numeric: true)
                }
                HStack(spacing: 5) {
                    ForEach([12, 24, 36, 48, 60], id: \.self) { m in
                        Button { months = String(m) } label: { Chip(label: "\(m)", selected: monthsValue == m) }
                            .buttonStyle(.plain)
                    }
                }
                HStack {
                    FormField("First payment", text: $firstAmount, numeric: true)
                    DatePicker("", selection: $firstDate, displayedComponents: .date).labelsHidden()
                }
                InlineMenu(label: "Item",
                           value: store.data.items.first { $0.id == itemID }?.name ?? "Not linked") {
                    Button("Not linked") { itemID = nil }
                    ForEach(store.data.items.sorted { !$0.isSold && $1.isSold }) { item in
                        Button(item.isSold ? "\(item.name) (sold)" : item.name) { itemID = item.id }
                    }
                }
                ToggleChip(label: closed ? "Marked paid off" : "Still running",
                           tint: closed ? Organic.s600 : Organic.n900) { closed.toggle() }
                HelpText("Correct the figures here to match the lender's statement; the months paid are counted from the dates on their own.")
                PrimaryButton(title: "Save") {
                    guard !name.isEmpty else { return }
                    var copy = live
                    copy.name = name; copy.lender = lender
                    copy.principal = Int(principal.filter(\.isNumber)) ?? copy.principal
                    copy.months = monthsValue
                    copy.firstAmount = Int(firstAmount.filter(\.isNumber)) ?? copy.firstAmount
                    copy.firstDate = firstDate
                    copy.itemID = itemID; copy.closed = closed
                    store.updateInstallment(copy)
                    editing = false
                }
                DeleteButton(title: "Delete plan") { confirmingDelete = true }
            }
        }
    }
}
