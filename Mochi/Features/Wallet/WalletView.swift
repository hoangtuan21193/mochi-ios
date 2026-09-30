import SwiftUI

/// Tab 4. Cash, points, card debt, loans. No physical goods. Owners are
/// configuration, not money, so they sit in Settings.
/// Every "add" here follows one pattern: section header + round + button
/// that reveals an inline form.
struct WalletView: View {
    @Environment(Store.self) private var store
    @State private var addWallet = false
    @State private var addCard = false
    @State private var addPoint = false
    @State private var addPlan = false
    @State private var addRecurring = false
    @State private var showLoans = false
    @State private var showAllWallets = false
    /// One sheet slot for the whole screen. Six separate `.sheet` modifiers on
    /// the same view do not reliably coexist — the later ones win and the rest
    /// silently never present.
    @State private var sheet: WalletSheet?

    enum WalletSheet: Identifiable {
        case wallet(Wallet), card(CreditCard), plan(Installment), recurring(Recurring)
        case pointWallet(PointWallet?), transfer

        var id: String {
            switch self {
            case .wallet(let w): return "w\(w.id)"
            case .card(let c): return "c\(c.id)"
            case .plan(let p): return "i\(p.id)"
            case .recurring(let r): return "r\(r.id)"
            case .pointWallet(let p): return "p\(p?.id ?? "new")"
            case .transfer: return "transfer"
            }
        }
    }

    // add-wallet form
    @State private var wName = ""; @State private var wBal = 0; @State private var wOwner = "me"
    // add-card form
    @State private var cName = ""; @State private var cDue = ""; @State private var cOwner = "me"
    @State private var cDebt = 0; @State private var cClosing = ""
    // add-point-wallet form
    @State private var ptName = ""; @State private var ptPoints = 0; @State private var ptNote = ""
    // add-plan form
    @State private var pName = ""; @State private var pLender = ""
    @State private var pMonths = ""; @State private var pFirst = 0; @State private var pMonthly = 0
    @State private var pStartYear = Calendar.current.component(.year, from: .now)
    @State private var pStartMonth = Calendar.current.component(.month, from: .now)
    @State private var pDay = ""
    @State private var pItemID: String? = nil
    // add-recurring form
    @State private var rName = ""; @State private var rAmount = 0; @State private var rIncome = false
    @State private var rDay = ""; @State private var rPaidBy = ""; @State private var rCategory = "other"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    cashCard

                    SectionHeader(title: "Cash & wallets", isOpen: addWallet) { addWallet.toggle() }
                    if addWallet { addWalletForm }
                    Card(padding: .list) {
                        if store.data.wallets.isEmpty {
                            EmptyNote("No wallets yet. Add the bank accounts, marketplace balances and cash you actually hold.")
                        }
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
                                         : "\(hiddenWalletCount) smaller wallets")
                                    Image(systemName: showAllWallets ? "chevron.up" : "chevron.down")
                                        .font(Organic.glyph)
                                }
                                .font(Organic.meta).foregroundStyle(Organic.n600)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        // The rows collapse the small wallets out of sight, so
                        // this is the only line on the card that counts them.
                        if !store.data.wallets.isEmpty {
                            SectionTotal(label: "Total", value: store.format(store.cash))
                        }
                    }

                    SecondaryButton(title: "Move money", icon: "arrow.left.arrow.right", style: .outlined) { sheet = .transfer }

                    // Same shape as every other section: header and + outside,
                    // rows inside. The terracotta tint is the only thing that
                    // marks these as not-cash, and that is enough.
                    SectionHeader(title: "Point wallets", subtitle: pointsSubtitle, isOpen: addPoint) { addPoint.toggle() }
                    if addPoint { addPointForm }
                    Card(fill: Organic.a100, padding: .list) {
                        if store.data.pointWallets.isEmpty {
                            EmptyNote("Store credit and shop points live here, deliberately outside your cash.")
                        }
                        ForEach(store.data.pointWallets) { p in
                            RowButton(first: p.id == store.data.pointWallets.first?.id, hairline: Organic.a200,
                                      action: { sheet = .pointWallet(p) }) {
                                HStack {
                                    Text(p.name).font(Organic.row)
                                    if !p.note.isEmpty {
                                        Text(p.note).font(Organic.meta).foregroundStyle(Organic.a900)
                                    }
                                    Spacer()
                                    Text("\(p.points) pt").font(Organic.rowValue)
                                }
                            }
                        }
                        if !store.data.pointWallets.isEmpty {
                            SectionTotal(label: "Total", value: String(localized: "\(store.pointsHeld) pt"),
                                         tint: Organic.a900, hairline: Organic.a200)
                        }
                    }

                    // Subtitle dropped: it repeated the hero's debt figure.
                    SectionHeader(title: "Credit card debt", isOpen: addCard) { addCard.toggle() }
                    if addCard { addCardForm }
                    Card(padding: .list) {
                        if store.data.cards.isEmpty {
                            EmptyNote("No cards yet. Add one and type in what its statement says; items you buy on it are listed under it.")
                        }
                        ForEach(store.cardsByUrgency) { card in
                            RowButton(first: card.id == store.cardsByUrgency.first?.id, action: { sheet = .card(card) }) {
                                cardRow(card)
                            }
                        }
                        if !store.data.cards.isEmpty {
                            SectionTotal(label: "Total", value: store.format(store.typedCardDebt),
                                         tint: Organic.a800)
                        }
                    }

                    // Shopping credit: fixed sum, fixed months, 0%. The thing it
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
                            SectionTotal(label: "Still owed", value: store.format(store.installmentDebt),
                                         note: "Next month \(store.format(store.installmentMonthly))",
                                         tint: Organic.a800)
                        }
                    }

                    // What lands or leaves every month without being a purchase:
                    // salary, rent, subscriptions. A commitment, not a debt — it
                    // shapes Safe to spend and the forecast, never net worth.
                    SectionHeader(title: "Every month", isOpen: addRecurring) { addRecurring.toggle() }
                    if addRecurring { addRecurringForm }
                    Card(padding: .list) {
                        if store.recurring.isEmpty {
                            EmptyNote("Nothing yet. Add your salary and the bills that come every month — rent, phone, subscriptions — and say what pays each one. Bills on a card ride on that card's statement.")
                        }
                        ForEach(store.recurringByDay) { r in
                            RowButton(first: r.id == store.recurringByDay.first?.id, action: { sheet = .recurring(r) }) {
                                recurringRow(r)
                            }
                        }
                        if !store.recurring.isEmpty {
                            // Two totals, because they are two different
                            // promises: what lands, and what leaves.
                            SectionTotal(label: "Bills", value: store.format(store.monthlyCommitments.bills),
                                         note: "Income \(store.format(store.monthlyCommitments.income))",
                                         tint: Organic.a800)
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
                case .recurring(let r): RecurringSheetView(entry: r)
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

    /// Cash first: this screen is where the balances are typed, so its headline
    /// is the one they add up to. Safe to spend and net worth are Overview's.
    private var cashCard: some View {
        let w = store.netWorth
        return Card {
            Text("Cash now").font(Organic.meta).foregroundStyle(Organic.n600)
                .textCase(.uppercase).tracking(0.6)
            Text(store.format(w.cash))
                .font(Organic.hero).foregroundStyle(Organic.text)
                .minimumScaleFactor(0.6).lineLimit(1)
                .padding(.top, 1)
            HStack(alignment: .top, spacing: 10) {
                Metric(label: "cards", value: store.format(-(w.cardDebt + w.unbilledCharges)), valueColor: Organic.a700)
                Metric(label: "plans", value: store.format(-w.installmentPrincipal), valueColor: Organic.a700)
                Metric(label: "stock", value: store.format(w.inventory), valueColor: Organic.s700)
                Metric(label: "net worth", value: store.format(w.total), valueColor: Organic.n700)
            }
            .padding(.top, 10)
        }
    }

    private func recurringRow(_ r: Recurring) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(r.name).font(Organic.row).lineLimit(1)
            Text(verbatim: recurringDetail(r)).font(Organic.meta).foregroundStyle(Organic.n600).lineLimit(1)
            Spacer()
            Text(store.signed(r.isIncome ? r.amount : -r.amount))
                .font(Organic.rowValue)
                .foregroundStyle(r.isIncome ? Organic.s700 : Organic.text)
        }
        .opacity(r.active ? 1 : 0.45)
    }

    private func recurringDetail(_ r: Recurring) -> String {
        // A join of pieces, one of them a wallet's own name: each half is
        // looked up on its own and the line assembled after.
        var parts = [String(localized: "day \(r.day)")]
        if !r.paidBy.isEmpty { parts.append(store.isCard(r.paidBy) ? String(localized: "on \(r.paidBy)") : r.paidBy) }
        if !r.active { parts.append(String(localized: "paused")) }
        return parts.joined(separator: " · ")
    }

    /// Just the warning. The total that used to sit here is the last line of
    /// the card now, where every other section keeps its total.
    private let pointsSubtitle: LocalizedStringKey = "Not cash"

    private var addPointForm: some View {
        Card {
            Text("New point wallet").font(Organic.title).padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 8) {
                FormField("Name (MapCamera points, Rakuten points…)", text: $ptName)
                HStack(spacing: 8) {
                    MoneyField("Points now", value: $ptPoints, unit: .suffix("pt"))
                    FormField("Note (expires monthly…)", text: $ptNote)
                }
                Text("Counted apart from cash. Type the balance in from the shop's app.")
                    .font(Organic.meta).foregroundStyle(Organic.n600)
                HStack {
                    Spacer()
                    AddPill {
                        guard !ptName.isEmpty else { return }
                        store.addPointWallet(PointWallet(name: ptName, points: ptPoints, note: ptNote))
                        ptName = ""; ptPoints = 0; ptNote = ""; addPoint = false
                    }
                }
            }
        }
    }

    private func row(_ name: String, note: String, value: String) -> some View {
        HStack {
            // A wallet's name and the user's own note: both shown as written.
            Text(verbatim: name).font(Organic.row)
            if !note.isEmpty {
                Text(verbatim: note).font(Organic.meta).foregroundStyle(Organic.n500)
            }
            Spacer()
            Text(value).font(Organic.rowValue)
        }
    }

    /// One card: name, debt, then the urgency line.
    private func cardRow(_ card: CreditCard) -> some View {
        let days = store.daysUntilDue(card.dueDay)
        let urgent = card.debt > 0 && days <= 7
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.name).font(Organic.row)
                if card.ownerID != "me", let o = store.data.owners.first(where: { $0.id == card.ownerID }) {
                    Badge(verbatim: o.name, tone: .sage, shout: true)
                }
                Spacer()
                Text(store.format(card.debt)).font(Organic.rowValue)
            }
            HStack(spacing: 6) {
                // Relative, not "Due on the 27". The question is always how long
                // you have, and a date makes you do that subtraction yourself.
                Text(store.dueLabel(card.dueDay))
                    .font(urgent ? Organic.metaStrong : Organic.meta)
                    .foregroundStyle(urgent ? Organic.a700 : Organic.n600)
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
                MoneyField("Balance now", value: $wBal)
                ChipPicker(label: "Owner", options: store.data.owners.map(\.name),
                           selection: ownerName(wOwner)) { wOwner = ownerID(named: $0) ?? wOwner }
                HStack {
                    Spacer()
                    AddPill {
                        guard !wName.isEmpty else { return }
                        store.data.wallets.append(Wallet(name: wName, balance: wBal, ownerID: wOwner))
                        store.save(); wName = ""; wBal = 0; addWallet = false
                    }
                }
            }
        }
    }

    private var cDueValue: Int { min(max(Int(cDue.filter(\.isNumber)) ?? 0, 0), 31) }

    /// A card is almost never added on the day it is opened: it arrives with a
    /// balance already on it. Asking for that balance here, instead of making
    /// the user add the card and then reopen it to "correct" the debt, is the
    /// difference between one step and three.
    private var addCardForm: some View {
        Card {
            Text("New credit card").font(Organic.title).padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 8) {
                FormField("Card name (Saison, Rakuten…)", text: $cName)
                HStack(spacing: 8) {
                    MoneyField("Owed right now", value: $cDebt)
                    FormField("Paid on day (1–31)", text: $cDue, numeric: true)
                }
                // Asked for, not optional. Without it the book cannot tell
                // what is already on a statement from what was charged since,
                // and has to treat the typed figure as everything owed — which
                // makes the two figures on the card screen guesses.
                FormField("Closes on day (1–31)", text: $cClosing, numeric: true)
                ChipPicker(label: "Owner", options: store.data.owners.map(\.name),
                           selection: ownerName(cOwner)) { cOwner = ownerID(named: $0) ?? cOwner }
                Text(verbatim: cardPreview).font(Organic.meta).foregroundStyle(Organic.n600)
                HStack {
                    Spacer()
                    AddPill {
                        guard !cName.isEmpty else { return }
                        store.addCard(CreditCard(name: cName, dueDay: max(cDueValue, 1),
                                                 debt: cDebt, ownerID: cOwner,
                                                 closingDay: cClosingValue))
                        cName = ""; cDue = ""; cClosing = ""; cDebt = 0; cOwner = "me"; addCard = false
                    }
                }
            }
        }
    }

    /// Reads the form back as the row it is about to become, so a wrong due
    /// day or a forgotten balance is caught before Add, not after.
    /// nil when the field is blank or nonsense, which is the honest answer:
    /// a card whose cycle is unknown says so rather than guessing a day.
    private var cClosingValue: Int? {
        let n = Int(cClosing.filter(\.isNumber)) ?? 0
        return (1...31).contains(n) ? n : nil
    }

    private var cardPreview: String {
        var parts: [String] = []
        parts.append(cDebt > 0
                     ? String(localized: "\(store.format(cDebt)) goes onto card debt now")
                     : String(localized: "Nothing owed yet — type the statement in when it comes"))
        if cDueValue > 0 { parts.append(store.dueLabel(cDueValue)) }
        // Say what is lost by leaving it blank, before Add, not after.
        if cClosingValue == nil {
            parts.append(String(localized: "no closing day — billed and unbilled cannot be split"))
        }
        return parts.joined(separator: " · ")
    }

    /// The form read back as the lender printed it, so the preview line and Add
    /// work from the same figures.
    private var pSchedule: InstallmentSchedule {
        InstallmentSchedule(months: Int(pMonths.filter(\.isNumber)) ?? 0, firstAmount: pFirst,
                            monthly: pMonthly, startYear: pStartYear, startMonth: pStartMonth,
                            payDay: Int(pDay.filter(\.isNumber)) ?? 0)
    }

    /// The five lines a Japanese shopping-credit confirmation prints, in its
    /// order: 分割支払回数, 初回お支払金額, 2回目以降お支払金額, お支払期間 and
    /// 毎月のお支払日. The total borrowed is their sum, so it is shown, not asked.
    private var addPlanForm: some View {
        Card {
            Text("New instalment plan").font(Organic.title)
            HelpText("Copy the lender's confirmation line by line: payments, first payment, the amount every month after it, the month it starts and the day it is debited.")
                .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 8) {
                FormField("What it bought", text: $pName)
                HStack(spacing: 8) {
                    FormField("Lender (Orico, Jaccs…)", text: $pLender)
                    FormField("Payments (60)", text: $pMonths, numeric: true).frame(width: 120)
                }
                HStack(spacing: 8) {
                    MoneyField("First payment", value: $pFirst)
                    MoneyField("Then each month", value: $pMonthly)
                }
                HStack(spacing: 8) {
                    FormField { MonthPicker(label: "Starts", year: $pStartYear, month: $pStartMonth) }
                    FormField("Paid on day (26)", text: $pDay, numeric: true).frame(width: 120)
                }
                if !store.data.items.isEmpty { itemLinkPicker }
                Text(planPreview).font(Organic.meta).foregroundStyle(Organic.n600)
                HStack {
                    Spacer()
                    AddPill {
                        guard !pName.isEmpty,
                              let plan = pSchedule.plan(name: pName, lender: pLender, itemID: pItemID)
                        else { return }
                        store.addInstallment(plan)
                        pName = ""; pLender = ""; pMonths = ""; pFirst = 0; pMonthly = 0
                        pStartYear = Calendar.current.component(.year, from: .now)
                        pStartMonth = Calendar.current.component(.month, from: .now)
                        pDay = ""; pItemID = nil; addPlan = false
                    }
                }
            }
        }
    }

    /// Says what the typed schedule adds up to before Add, so a mistyped month
    /// or a missing day is caught here and not in the totals.
    private var planPreview: LocalizedStringKey {
        guard let plan = pSchedule.plan(name: pName) else {
            return "Fill in the payments, the two amounts and the day it is debited."
        }
        return "Borrows \(store.format(plan.principal)) · first payment \(plan.firstDate.formatted(.dateTime.day().month(.abbreviated).year())) · last \(plan.endDate.formatted(.dateTime.month(.abbreviated).year())) · \(plan.paidCount()) already paid by today"
    }

    private var rDayValue: Int { min(max(Int(rDay.filter(\.isNumber)) ?? 0, 0), 31) }

    private var addRecurringForm: some View {
        Card {
            Text(rIncome ? "New monthly income" : "New monthly bill").font(Organic.title).padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Button { rIncome = false; if rCategory == "salary" { rCategory = "other" } } label: {
                        Chip(label: Text("Bill"), selected: !rIncome, tint: Organic.a600)
                    }.buttonStyle(.plain)
                    Button { rIncome = true; rCategory = "salary" } label: {
                        Chip(label: Text("Income"), selected: rIncome, tint: Organic.s600)
                    }.buttonStyle(.plain)
                }
                FormField(rIncome ? "What it is (Salary)" : "What it is (Rent, Netflix…)", text: $rName)
                HStack(spacing: 8) {
                    MoneyField("Amount a month", value: $rAmount)
                    FormField("Day (25)", text: $rDay, numeric: true).frame(width: 110)
                }
                if !rIncome {
                    ChipPicker(label: "Kind", options: Recurring.expenseCategories,
                               selection: rCategory,
                               display: { Text(Recurring.categoryName($0)) }) { rCategory = $0 }
                }
                if !store.payers.isEmpty {
                    ChipPicker(label: rIncome ? "Lands in" : "Paid by", options: store.payers, selection: rPaidBy) { rPaidBy = $0 }
                }
                Text(recurringPreview).font(Organic.meta).foregroundStyle(Organic.n600)
                HStack {
                    Spacer()
                    AddPill {
                        guard !rName.isEmpty, rAmount > 0, rDayValue > 0 else { return }
                        store.addRecurring(Recurring(name: rName, amount: rAmount, kind: rIncome ? "income" : "expense",
                                                     category: rCategory, day: rDayValue, paidBy: rPaidBy))
                        rName = ""; rAmount = 0; rDay = ""; rPaidBy = ""; rCategory = "other"; rIncome = false
                        addRecurring = false
                    }
                }
            }
        }
    }

    /// Says where the money will show up before Add: a card-paid bill is the
    /// one that surprises people, because nothing leaves on its own day.
    private var recurringPreview: LocalizedStringKey {
        guard rAmount > 0, rDayValue > 0 else { return "Amount and day of the month, then what pays it." }
        if rIncome { return "\(store.format(rAmount)) arrives on the \(rDayValue)th; Safe to spend counts it when the day falls before the horizon." }
        if store.isCard(rPaidBy) { return "Goes onto \(rPaidBy)'s next statement; cash leaves on the card's due day, not on the \(rDayValue)th." }
        return "\(store.format(rAmount)) leaves cash on the \(rDayValue)th every month."
    }

    /// Optional link to the item this plan paid for. A menu, not chips: a book
    /// with forty items would otherwise be forty chips.
    private var itemLinkPicker: some View {
        let linked = store.data.items.first { $0.id == pItemID }
        return InlineMenu(label: "Item", value: linked.map { Text(verbatim: $0.name) } ?? Text("Not linked")) {
            Button("Not linked") { pItemID = nil }
            ForEach(store.data.items.sorted { !$0.isSold && $1.isSold }) { item in
                Button {
                    pItemID = item.id
                    if pName.isEmpty { pName = item.name }
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
