import SwiftUI

/// Tab 4. Cash, points, card debt, loans. No physical goods. Owners are
/// configuration, not money, so they sit in Settings.
/// Every "add" here follows one pattern: section header + round + button
/// that reveals an inline form.
struct WalletView: View {
    @Environment(Store.self) private var store
    @State private var addWallet = false
    @State private var addCard = false
    @State private var addPlan = false
    @State private var showLoans = false
    @State private var showAllWallets = false
    /// One sheet slot for the whole screen. Six separate `.sheet` modifiers on
    /// the same view do not reliably coexist — the later ones win and the rest
    /// silently never present.
    @State private var sheet: WalletSheet?

    enum WalletSheet: Identifiable {
        case wallet(Wallet), card(CreditCard), plan(Installment)
        case pointWallet(PointWallet?), transfer

        var id: String {
            switch self {
            case .wallet(let w): return "w\(w.id)"
            case .card(let c): return "c\(c.id)"
            case .plan(let p): return "i\(p.id)"
            case .pointWallet(let p): return "p\(p?.id ?? "new")"
            case .transfer: return "transfer"
            }
        }
    }

    // add-wallet form
    @State private var wName = ""; @State private var wBal = ""; @State private var wOwner = "me"
    // add-card form
    @State private var cName = ""; @State private var cDue = ""; @State private var cLimit = ""; @State private var cOwner = "me"
    @State private var cDebt = ""
    // add-plan form
    @State private var pName = ""; @State private var pLender = ""; @State private var pPrincipal = ""
    @State private var pMonths = "24"; @State private var pFirst = ""; @State private var pFirstDate = Date.now
    @State private var pItemID: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    netWorthCard

                    SectionHeader(title: "Cash & wallets", isOpen: addWallet) { addWallet.toggle() }
                    if addWallet { addWalletForm }
                    Card(padding: .list) {
                        if store.data.wallets.isEmpty {
                            EmptyNote("No wallets yet. Add the bank accounts, marketplace balances and cash you actually hold.")
                        }
                        // No Total row here: the same figure is the first line of
                        // the hero card two inches above. Saying it twice taught
                        // the eye that every number on this screen is skippable.
                        ForEach(visibleWallets) { w in
                            RowButton(first: w.id == visibleWallets.first?.id, action: { sheet = .wallet(w) }) {
                                row(w.name, note: w.note, value: store.format(w.balance))
                                    .opacity(w.balance == 0 ? 0.45 : 1)
                            }
                        }
                        if hiddenWalletCount > 0 {
                            RowButton(action: { withAnimation(.easeOut(duration: 0.2)) { showAllWallets.toggle() } }) {
                                HStack(spacing: 4) {
                                    Text(showAllWallets ? "Show less"
                                         : "\(hiddenWalletCount) smaller \(hiddenWalletCount == 1 ? "wallet" : "wallets")")
                                    Image(systemName: showAllWallets ? "chevron.up" : "chevron.down")
                                        .font(Organic.glyph)
                                }
                                .font(Organic.meta).foregroundStyle(Organic.n600)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    SecondaryButton(title: "Move money", icon: "arrow.left.arrow.right", style: .outlined) { sheet = .transfer }

                    pointsCard

                    // Subtitle dropped: it repeated the hero's debt figure.
                    SectionHeader(title: "Credit card debt", isOpen: addCard) { addCard.toggle() }
                    if addCard { addCardForm }
                    Card(padding: .list) {
                        if store.data.cards.isEmpty {
                            EmptyNote("No cards yet. Add one and every item you buy on it raises its debt.")
                        }
                        ForEach(store.cardsByUrgency) { card in
                            RowButton(first: card.id == store.cardsByUrgency.first?.id, action: { sheet = .card(card) }) {
                                cardRow(card)
                            }
                        }
                    }

                    // Shopping credit: fixed sum, fixed months, 0%. The camera it
                    // bought may already be sold — the debit keeps coming.
                    SectionHeader(title: "Instalment plans", isOpen: addPlan) { addPlan.toggle() }
                    if addPlan { addPlanForm }
                    Card(padding: .list) {
                        if store.installments.isEmpty {
                            EmptyNote("No plans yet. Add anything bought on shopping credit — the months left and the total still owed are worked out from the dates.")
                        }
                        ForEach(store.installmentsByUrgency) { plan in
                            RowButton(first: plan.id == store.installmentsByUrgency.first?.id, action: { sheet = .plan(plan) }) {
                                planRow(plan)
                            }
                        }
                        if !store.openInstallments.isEmpty {
                            HStack {
                                Text("Next month \(store.format(store.installmentMonthly))")
                                Spacer()
                                Text("Still owed \(store.format(store.installmentDebt))")
                            }
                            .font(Organic.metaStrong).foregroundStyle(Organic.a800)
                            .padding(.vertical, 10)
                            .overlay(alignment: .top) { Hairline() }
                        }
                    }

                    // Owners live in Settings now. Who owns a card is set once and
                    // read never; it was taking a whole section on the screen you
                    // open to decide what to pay.

                    Button { showLoans = true } label: {
                        Card {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Personal loan book").font(Organic.title)
                                    Text("\(store.data.loans.count) people")
                                        .font(Organic.meta).foregroundStyle(Organic.n600)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(Organic.valueStrong)
                                    .foregroundStyle(Organic.n500)
                            }
                        }
                    }
                    .buttonStyle(.plain).foregroundStyle(Organic.text)
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
            }
            .background(Organic.bg)
            .navigationTitle("Wallet")
            .sheet(item: $sheet) { which in
                switch which {
                case .wallet(let w): WalletEditorView(wallet: w)
                case .card(let c): CardSheetView(card: c)
                case .plan(let p): InstallmentSheetView(plan: p)
                case .pointWallet(let p): PointWalletEditorView(pointWallet: p)
                case .transfer: TransferSheet()
                }
            }
            .navigationDestination(isPresented: $showLoans) { LoanBookView() }
        }
    }

    /// Biggest balances first, so the ones folded away are genuinely the ones
    /// that do not change a decision.
    private var walletsBySize: [Wallet] {
        store.data.wallets.sorted { $0.balance > $1.balance }
    }
    private var walletFoldThreshold: Int { 4 }
    private var hiddenWalletCount: Int {
        max(0, walletsBySize.count - walletFoldThreshold)
    }
    private var visibleWallets: [Wallet] {
        showAllWallets || hiddenWalletCount == 0
            ? walletsBySize : Array(walletsBySize.prefix(walletFoldThreshold))
    }

    /// One hero number, three supporting figures on a single line. The old
    /// version stacked four rows of near-identical weight, so the total —
    /// the only number here anyone acts on — had no primacy at all.
    private var netWorthCard: some View {
        Card {
            Text("Net worth").font(Organic.meta).foregroundStyle(Organic.n600)
                .textCase(.uppercase).tracking(0.6)
            Text(store.format(store.cashAfterSellingAll))
                .font(Organic.hero).foregroundStyle(Organic.text)
                .minimumScaleFactor(0.6).lineLimit(1)
                .padding(.top, 1)
            HStack(alignment: .top, spacing: 10) {
                Metric(label: "cash", value: store.format(store.cash), valueColor: Organic.n700)
                // Cards and plans together: net worth above already nets both off.
                Metric(label: "debt", value: store.format(-(store.debt + store.installmentDebt)), valueColor: Organic.a700)
                Metric(label: "stock", value: store.format(store.liquidation), valueColor: Organic.s700)
            }
            .padding(.top, 10)
        }
    }

    private var pointsCard: some View {
        Card(fill: Organic.a100) {
            HStack(alignment: .firstTextBaseline) {
                // Four things fought for this row and the tag was the one that
                // got clipped. It reads as a subtitle instead.
                VStack(alignment: .leading, spacing: 1) {
                    Text("Point wallets").font(Organic.title)
                    Text("NOT CASH").font(Organic.metaStrong).foregroundStyle(Organic.a700)
                        .tracking(0.5)
                }
                Spacer()
                Text("\(store.data.pointWallets.reduce(0) { $0 + $1.points }) pt")
                    .font(Organic.rowValue).foregroundStyle(Organic.a900)
                // Same + as everywhere else, wearing this card's own colours.
                AddButton(fill: Organic.a200, stroke: Organic.a300, symbol: Organic.a800) {
                    sheet = .pointWallet(nil)
                }
            }
            if store.data.pointWallets.isEmpty {
                Text("Store credit and shop points live here, deliberately outside your cash.")
                    .font(Organic.meta).foregroundStyle(Organic.a900).padding(.top, 8)
            }
            ForEach(store.data.pointWallets) { p in
                Button { sheet = .pointWallet(p) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.name).font(Organic.row)
                            Text(p.note).font(Organic.meta).foregroundStyle(Organic.a900)
                        }
                        Spacer()
                        Text("\(p.points) pt").font(Organic.rowValue)
                    }
                    .padding(.vertical, 9)
                    .overlay(alignment: .top) { Hairline(color: Organic.a200) }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(Organic.text)
            }
        }
    }

    private func row(_ name: String, note: String, value: String) -> some View {
        HStack {
            Text(name).font(Organic.row)
            if !note.isEmpty {
                Text(note).font(Organic.meta).foregroundStyle(Organic.n500)
            }
            Spacer()
            Text(value).font(Organic.rowValue)
        }
    }

    /// One card: name, debt, then the urgency line. The limit bar only appears
    /// when the limit is nearly gone — six always-on bars were six pieces of
    /// texture carrying a number nobody acts on daily.
    private func cardRow(_ card: CreditCard) -> some View {
        let ratio = card.limit > 0 ? Double(card.debt) / Double(card.limit) : 0
        let tight = ratio > 0.8
        let days = store.daysUntilDue(card.dueDay)
        let urgent = card.debt > 0 && days <= 7
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.name).font(Organic.row)
                if card.ownerID != "me", let o = store.data.owners.first(where: { $0.id == card.ownerID }) {
                    Badge(o.name, tone: .sage)
                }
                Spacer()
                Text(store.format(card.debt)).font(Organic.rowValue)
            }
            if tight {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Organic.n200)
                        Capsule().fill(Organic.a600)
                            .frame(width: geo.size.width * min(1, ratio))
                    }
                }
                .frame(height: 5)
            }
            HStack(spacing: 6) {
                // Relative, not "Due on the 27". The question is always how long
                // you have, and a date makes you do that subtraction yourself.
                Text(store.dueLabel(card.dueDay))
                    .font(urgent ? Organic.metaStrong : Organic.meta)
                    .foregroundStyle(urgent ? Organic.a700 : Organic.n600)
                if tight {
                    Text("· limit nearly gone").font(Organic.meta).foregroundStyle(Organic.a700)
                }
                Spacer()
                Text("day \(card.dueDay)").font(Organic.meta).foregroundStyle(Organic.n500)
            }
        }
        .opacity(card.debt == 0 ? 0.45 : 1)
    }

    /// One plan: name, what is still owed, then the line that answers "how
    /// long is this going to keep coming out" — months left, next debit, end.
    private func planRow(_ plan: Installment) -> some View {
        let settled = plan.isSettled()
        let soldItem = plan.itemID.flatMap { id in store.data.items.first { $0.id == id } }?.isSold == true
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(plan.name).font(Organic.row).lineLimit(1)
                if soldItem {
                    Badge("SOLD", tone: .accent)
                }
                if !plan.lender.isEmpty {
                    Text(plan.lender).font(Organic.meta).foregroundStyle(Organic.n500).lineLimit(1)
                }
                Spacer()
                Text(store.format(plan.remaining())).font(Organic.rowValue)
            }
            if settled {
                Text("Paid off · \(store.format(plan.principal)) over \(plan.months) months")
                    .font(Organic.meta).foregroundStyle(Organic.s700)
            } else {
                HStack(spacing: 6) {
                    Text("\(plan.monthsLeft()) of \(plan.months) months left")
                        .font(Organic.metaStrong).foregroundStyle(Organic.a700)
                    if let next = plan.nextDue() {
                        Text("· \(store.format(next.amount)) on \(next.date.formatted(.dateTime.day().month(.abbreviated)))")
                            .font(Organic.meta).foregroundStyle(Organic.n600)
                    }
                    Spacer()
                    Text("ends \(plan.projectedEnd().formatted(.dateTime.month(.abbreviated).year()))")
                        .font(Organic.meta).foregroundStyle(Organic.n500)
                }
            }
        }
        .opacity(settled ? 0.45 : 1)
    }

    // MARK: - Inline forms

    private var addWalletForm: some View {
        Card {
            Text("New wallet").font(Organic.title).padding(.bottom, 8)
            VStack(spacing: 8) {
                FormField("Wallet or account name", text: $wName)
                FormField("Balance now", text: $wBal, numeric: true)
                ChipPicker(label: "Owner", options: store.data.owners.map(\.name),
                           selection: ownerName(wOwner)) { wOwner = ownerID(named: $0) ?? wOwner }
                HStack {
                    Spacer()
                    AddPill {
                        guard !wName.isEmpty else { return }
                        store.data.wallets.append(Wallet(name: wName,
                            balance: Int(wBal.filter(\.isNumber)) ?? 0, ownerID: wOwner))
                        store.save(); wName = ""; wBal = ""; addWallet = false
                    }
                }
            }
        }
    }

    private var cDueValue: Int { min(max(Int(cDue.filter(\.isNumber)) ?? 0, 0), 31) }
    private var cDebtValue: Int { Int(cDebt.filter(\.isNumber)) ?? 0 }
    private var cLimitValue: Int { Int(cLimit.filter(\.isNumber)) ?? 0 }

    /// A card is almost never added on the day it is opened: it arrives with a
    /// balance already on it. Asking for that balance here, instead of making
    /// the user add the card and then reopen it to "correct" the debt, is the
    /// difference between one step and three.
    private var addCardForm: some View {
        Card {
            Text("New credit card").font(Organic.title).padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 8) {
                FormField("Card name (Saison, Rakuten…)", text: $cName)
                FormField("Owed right now", text: $cDebt, numeric: true)
                HStack(spacing: 8) {
                    FormField("Paid on day (1–31)", text: $cDue, numeric: true)
                    FormField("Limit", text: $cLimit, numeric: true)
                }
                ChipPicker(label: "Owner", options: store.data.owners.map(\.name),
                           selection: ownerName(cOwner)) { cOwner = ownerID(named: $0) ?? cOwner }
                Text(cardPreview).font(Organic.meta).foregroundStyle(Organic.n600)
                HStack {
                    Spacer()
                    AddPill {
                        guard !cName.isEmpty else { return }
                        store.addCard(CreditCard(name: cName, dueDay: max(cDueValue, 1),
                                                 limit: cLimitValue, debt: cDebtValue, ownerID: cOwner))
                        cName = ""; cDue = ""; cLimit = ""; cDebt = ""; cOwner = "me"; addCard = false
                    }
                }
            }
        }
    }

    /// Reads the form back as the row it is about to become, so a wrong due
    /// day or a forgotten balance is caught before Add, not after.
    private var cardPreview: String {
        var parts: [String] = []
        parts.append(cDebtValue > 0 ? "\(store.format(cDebtValue)) goes onto card debt now"
                                    : "Nothing owed yet — buying on it adds to its debt")
        if cDueValue > 0 { parts.append(store.dueLabel(cDueValue)) }
        if cLimitValue > 0, cDebtValue > 0 {
            parts.append("\(Int(Double(cDebtValue) / Double(cLimitValue) * 100))% of limit")
        }
        return parts.joined(separator: " · ")
    }

    private var pPrincipalValue: Int { Int(pPrincipal.filter(\.isNumber)) ?? 0 }
    private var pMonthsValue: Int { max(1, Int(pMonths.filter(\.isNumber)) ?? 1) }
    /// What the lender will most likely ask for in month one when the field is
    /// left blank: the even split, remainder and all.
    private var pFirstSuggested: Int {
        guard pPrincipalValue > 0 else { return 0 }
        let even = pPrincipalValue / pMonthsValue
        return pPrincipalValue - even * (pMonthsValue - 1)
    }
    private var pFirstValue: Int {
        let typed = Int(pFirst.filter(\.isNumber)) ?? 0
        return typed > 0 ? typed : pFirstSuggested
    }

    private var addPlanForm: some View {
        Card {
            Text("New instalment plan").font(Organic.title).padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 8) {
                FormField("What it bought", text: $pName)
                HStack(spacing: 8) {
                    FormField("Lender (Orico, Jaccs…)", text: $pLender)
                    FormField("Total borrowed", text: $pPrincipal, numeric: true)
                }
                HStack(spacing: 5) {
                    ForEach([12, 24, 36, 48, 60], id: \.self) { m in
                        Button { pMonths = String(m) } label: { Chip(label: "\(m)", selected: pMonthsValue == m) }
                            .buttonStyle(.plain)
                    }
                    FormField("mo", text: $pMonths, numeric: true).frame(width: 64)
                }
                HStack {
                    FormField(pFirstSuggested > 0 ? "First payment (≈ \(pFirstSuggested.formatted()))" : "First payment",
                              text: $pFirst, numeric: true)
                    DatePicker("", selection: $pFirstDate, displayedComponents: .date).labelsHidden()
                }
                if !store.data.items.isEmpty { itemLinkPicker }
                if pPrincipalValue > 0 {
                    let preview = Installment(name: pName, principal: pPrincipalValue, months: pMonthsValue,
                                              firstAmount: pFirstValue, firstDate: pFirstDate)
                    Text("Then \(store.format(preview.regular)) a month · last payment \(preview.endDate.formatted(.dateTime.month(.abbreviated).year())) · \(preview.paidCount()) already paid by today")
                        .font(Organic.meta).foregroundStyle(Organic.n600)
                }
                HStack {
                    Spacer()
                    AddPill {
                        guard !pName.isEmpty, pPrincipalValue > 0 else { return }
                        store.addInstallment(Installment(name: pName, lender: pLender, principal: pPrincipalValue,
                                                         months: pMonthsValue, firstAmount: pFirstValue,
                                                         firstDate: pFirstDate, itemID: pItemID))
                        pName = ""; pLender = ""; pPrincipal = ""; pFirst = ""; pItemID = nil
                        pMonths = "24"; pFirstDate = .now; addPlan = false
                    }
                }
            }
        }
    }

    /// Optional link to the item this plan paid for. A menu, not chips: a book
    /// with forty items would otherwise be forty chips.
    private var itemLinkPicker: some View {
        let linked = store.data.items.first { $0.id == pItemID }
        return InlineMenu(label: "Item", value: linked?.name ?? "Not linked") {
            Button("Not linked") { pItemID = nil }
            ForEach(store.data.items.sorted { !$0.isSold && $1.isSold }) { item in
                Button {
                    pItemID = item.id
                    if pName.isEmpty { pName = item.name }
                    if pPrincipal.isEmpty { pPrincipal = String(item.buyPrice) }
                } label: {
                    Text(item.isSold ? "\(item.name) (sold)" : item.name)
                }
            }
        }
    }

    /// `ChipPicker` selects by name; wallets and cards store the owner's id.
    /// These two translate at the edge so the stored value stays the id.
    private func ownerName(_ id: String) -> String {
        store.data.owners.first { $0.id == id }?.name ?? ""
    }

    private func ownerID(named name: String) -> String? {
        store.data.owners.first { $0.name == name }?.id
    }
}

/// Wallet-to-wallet move with the 手数料 field. Mercari / Rakuma bank
/// withdrawals cost ¥210 a time, so the fee defaults to that.
struct TransferSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var from = ""
    @State private var to = ""
    @State private var amount = ""
    @State private var fee = "210"

    private var amountValue: Int { Int(amount.filter(\.isNumber)) ?? 0 }
    private var feeValue: Int { Int(fee.filter(\.isNumber)) ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ChipPicker(label: "From", options: store.data.wallets.map(\.name), selection: from) { from = $0 }
                    ChipPicker(label: "To", options: store.data.wallets.map(\.name), selection: to) { to = $0 }
                    HStack(spacing: 8) {
                        FormField("Amount", text: $amount, numeric: true)
                        FormField("手数料", text: $fee, numeric: true)
                            .frame(width: 100)
                    }
                    HStack(spacing: 5) {
                        ForEach([0, 210, 250], id: \.self) { f in
                            Button { fee = String(f) } label: {
                                Chip(label: f == 0 ? "No fee" : store.format(f), selected: feeValue == f)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HelpText(amountValue > 0
                             ? "Arrives: \(store.format(max(0, amountValue - feeValue)))" +
                               (feeValue > 0 ? " · 手数料 \(store.format(feeValue))" : "")
                             : "Bank withdrawals from Mercari / Rakuma usually cost ¥210 per transfer.")
                    PrimaryButton(title: "Move it") {
                        store.transfer(from: from, to: to, amount: amountValue, fee: feeValue)
                        dismiss()
                    }
                }
                .padding(16)
            }
            .background(Organic.bg)
            .navigationTitle("Move money")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
        .onAppear {
            from = store.data.wallets.first?.name ?? ""
            to = store.data.wallets.dropFirst().first?.name ?? ""
        }
    }
}
