import SwiftUI

/// The Wallet tab: what you have and what you owe. Net worth heads it with
/// its line drawn small, and the rest is three tabs — Accounts (cash and
/// points), Cards and plans, Invested (investments and money lent) — each
/// with its figure on the tab. Every "add" follows one pattern: section
/// header + round + button that reveals an inline form. It used to be two
/// screens off Home (Accounts and cards, Net worth) and nobody could say
/// which held what.
struct WalletView: View {
    var body: some View {
        NavigationStack { AccountsView() }
    }
}

struct AccountsView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var addWallet = false
    @State private var addCard = false
    @State private var addPoint = false
    @State private var addPlan = false
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
    @State private var cPayFrom = ""; @State private var cLast4 = ""
    // add-point-wallet form
    @State private var ptName = ""; @State private var ptPoints = 0; @State private var ptNote = ""
    // add-plan form
    @State private var pName = ""; @State private var pLender = ""
    @State private var pMonths = ""; @State private var pFirst = 0; @State private var pMonthly = 0
    @State private var pStartYear = Calendar.current.component(.year, from: .now)
    @State private var pStartMonth = Calendar.current.component(.month, from: .now)
    @State private var pDay = ""
    @State private var pItemID: String? = nil

    /// Which third of the tab is open; remembered, because the cards are
    /// what most visits are for in the week a statement lands.
    @AppStorage("wallet.part") private var part: Part = .accounts
    @State private var openInvestments = false
    @State private var openPeople = false
    @State private var openNetWorth = false

    enum Part: String, CaseIterable { case accounts, cards, invested }

    var body: some View {
        ScrollView {
            // Wide screens: net worth on the left, the open third on the right.
            AdaptiveColumns(spacing: 12) {
                Text("What you have and what you owe").font(Organic.value).foregroundStyle(Organic.n600)
                    .padding(.top, -8)
                netWorthCard
            } trailing: {
                SegmentedTabs(options: Part.allCases, selection: $part, detail: partFigure) { p in
                    switch p { case .accounts: "Accounts"; case .cards: "Cards and plans"; case .invested: "Invested" }
                }
                switch part {
                case .accounts: accountsPart
                case .cards: cardsPart
                case .invested: investedPart
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
        .background(Organic.bg)
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(isPresented: $openInvestments) { InvestmentsView() }
        .navigationDestination(isPresented: $openPeople) { PeopleView() }
        .navigationDestination(isPresented: $openNetWorth) { NetWorthView() }
        #if DEBUG
        // Debug-only: `-open networth` lands on Net worth for design-check.
        .onAppear { if UserDefaults.standard.string(forKey: "open") == "networth" { openNetWorth = true } }
        #endif
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
    }

    /// The figure under each tab's name: what that third adds up to.
    private func partFigure(_ p: Part) -> String {
        switch p {
        case .accounts: store.format(store.cash)
        case .cards: store.format(-store.cardsAndPlansOwed)
        case .invested: store.format(store.investedAndLent)
        }
    }

    // MARK: - Net worth

    /// Net worth first: this tab is "what do I have and owe", and that is the
    /// one figure that answers it. The line under it is drawn from the
    /// monthly readings only; the full chart is a tap away.
    private var netWorthCard: some View {
        let w = store.netWorth
        return Card {
            VStack(alignment: .leading, spacing: Organic.Space.m) {
                HStack {
                    Text("Net worth").font(Organic.valueStrong).foregroundStyle(Organic.n600)
                    Spacer()
                    NavigationLink { NetWorthView() } label: {
                        Text("Over time ›").font(Organic.valueStrong).foregroundStyle(Organic.accent)
                    }
                }
                Text(verbatim: store.format(w.total))
                    .font(Organic.hero).foregroundStyle(Organic.text)
                    .minimumScaleFactor(0.6).lineLimit(1)
                if let c = store.netWorthThisYear, let since = store.firstReadingThisYear {
                    Text("\(store.signed(c.change)) since \(since.formatted(.dateTime.month(.wide))) · \(c.readings) monthly readings")
                        .font(Organic.value).foregroundStyle(c.change >= 0 ? Organic.s700 : Organic.a700)
                }
                if store.netWorthPoints.count >= 2 {
                    NetWorthLine(points: store.netWorthPoints)
                }
                HStack(spacing: Organic.Space.m) {
                    Metric(label: "Assets", value: store.format(w.assets), large: true, boxed: true, fill: Organic.n200)
                    Metric(label: "Owed", value: store.format(w.liabilities), valueColor: Organic.a700, large: true, boxed: true, fill: Organic.n200)
                }
            }
        }
    }

    // MARK: - Accounts

    private var accountsPart: some View {
        let notes = store.accountNotes
        let others = notes.filter { !$0.wallet.isMarketplace }
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Cash and wallets",
                          subtitle: "\(store.format(store.cash)) · real money, before marketplace fees",
                          isOpen: addWallet) { addWallet.toggle() }
            if addWallet { addWalletForm }
            Card(padding: .list) {
                if notes.isEmpty {
                    EmptyNote("No wallets yet. Add the bank accounts, marketplace balances and cash you actually hold.")
                }
                ForEach(notes) { n in
                    RowButton(first: n.id == notes.first?.id, padded: false, action: { sheet = .wallet(n.wallet) }) {
                        ListRow(title: ownerTitle(n.wallet.name, owner: n.wallet.ownerID), sub: accountLine(n),
                                value: store.format(n.balance), valueSub: accountDeadline(n),
                                mark: LeadMark(glyph: .initials(n.wallet.name), tint: markColor(n, in: others).opacity(0.14), ink: markColor(n, in: others)))
                            .opacity(n.balance == 0 ? 0.45 : 1)
                    }
                }
            }
            if notes.count > 1 {
                SecondaryButton(title: "Move money", icon: "arrow.left.arrow.right", style: .outlined) { sheet = .transfer }
            }

            SectionHeader(title: "Points", subtitle: "\(store.format(store.spendablePoints)) in net worth · never cash",
                          isOpen: addPoint) { addPoint.toggle() }
            if addPoint { addPointForm }
            Card(padding: .list) {
                if store.data.pointWallets.isEmpty {
                    EmptyNote("Store credit and shop points live here, deliberately outside your cash.")
                }
                ForEach(store.data.pointWallets) { p in
                    RowButton(first: p.id == store.data.pointWallets.first?.id, padded: false, action: { sheet = .pointWallet(p) }) {
                        // Points that are not in net worth are greyed: listed, not counted.
                        ListRow(title: p.name, sub: pointLine(p), value: String(localized: "\(store.pointBalance(p).formatted()) pt"),
                                valueColor: p.spendAnywhere == true ? Organic.text : Organic.n600,
                                mark: LeadMark(glyph: .initials(p.name), tint: Organic.n200, ink: Organic.n700))
                    }
                }
            }
            HelpText("Balances are typed from the bank. Points usable anywhere count in net worth at their value; points tied to one shop are listed apart. No point is ever cash.")
        }
    }

    /// "SMBC bank · Tuấn" once the book has more than one owner; one owner
    /// is everyone, and naming them on every row says nothing.
    private func ownerTitle(_ name: String, owner id: String) -> String {
        guard store.data.owners.count > 1, let o = store.data.owners.first(where: { $0.id == id }) else { return name }
        return "\(name) · \(o.name)"
    }

    /// What the account is for: salary lands here, it pays these, it runs
    /// short on this day; a marketplace says where and how it withdraws.
    private func accountLine(_ n: Finance.AccountNote) -> String {
        if n.wallet.isMarketplace, let to = n.wallet.payoutTo {
            return String(localized: "Withdraws to \(to) · \(store.format(n.wallet.payoutFee ?? 0)) · \(n.wallet.payoutDays ?? 3) business days")
        }
        var parts: [String] = []
        if !n.incomes.isEmpty { parts.append(String(localized: "\(ListFormatter.localizedString(byJoining: n.incomes)) comes in here")) }
        // Two by name; a long list would push the shortfall off the row.
        if !n.pays.isEmpty {
            let named = ListFormatter.localizedString(byJoining: Array(n.pays.prefix(2)))
            parts.append(n.pays.count > 2 ? String(localized: "pays \(named) and \(n.pays.count - 2) more") : String(localized: "pays \(named)"))
        }
        if let short = n.shortBy, let on = n.shortOn {
            parts.append(String(localized: "\(store.format(short)) short on \(on.formatted(.dateTime.day().month(.abbreviated)))"))
        }
        guard let first = parts.first else { return capitalised(n.wallet.note) }
        parts[0] = first.prefix(1).uppercased() + first.dropFirst()
        return parts.joined(separator: " · ")
    }

    /// The day something has to happen by, under the balance.
    private func accountDeadline(_ n: Finance.AccountNote) -> String? {
        if let by = n.moveBy { return String(localized: "move by \(by.formatted(.dateTime.day().month(.abbreviated)))") }
        if let by = n.withdrawBy, let debit = n.forDebit {
            return String(localized: "by \(by.formatted(.dateTime.day().month(.abbreviated))) for the \(ordinal(Calendar.current.component(.day, from: debit)))")
        }
        return nil
    }

    /// A marketplace is the accent; the others take the chart colours in turn.
    private func markColor(_ n: Finance.AccountNote, in others: [Finance.AccountNote]) -> Color {
        if n.wallet.isMarketplace { return Organic.accent }
        let palette = [Organic.s700, Organic.info, Organic.chartColor(5), Organic.chartColor(2), Organic.chartColor(7)]
        return palette[(others.firstIndex { $0.id == n.id } ?? 0) % palette.count]
    }

    private func pointLine(_ p: PointWallet) -> String {
        if p.spendAnywhere == true {
            return String(localized: "Usable anywhere · in net worth at \(store.format(Finance.value(ofPoints: 1, in: p)))")
        }
        return p.note.isEmpty ? String(localized: "Tied to one shop · not in net worth")
                              : String(localized: "\(capitalised(p.note)) · not in net worth")
    }

    /// A note as a sub-line starts with a capital, whatever was typed.
    private func capitalised(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    private func ordinal(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .ordinal
        return f.string(from: n as NSNumber) ?? "\(n)"
    }

    // MARK: - Cards and plans

    private var cardsPart: some View {
        let lines = store.cardLines
        let toPay = lines.reduce(0) { $0 + $1.statement }
        let later = lines.reduce(0) { $0 + $1.unbilled }
        let plans = store.installmentsByUrgency
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Credit cards", subtitle: "To pay \(store.format(toPay)) · not billed yet \(store.format(later))",
                          isOpen: addCard) { addCard.toggle() }
            if addCard { addCardForm }
            Card(padding: .list) {
                if lines.isEmpty {
                    EmptyNote("No cards yet. Add one and type in what its statement says; items you buy on it are listed under it.")
                }
                ForEach(lines) { l in
                    RowButton(first: l.id == lines.first?.id, padded: false, action: { sheet = .card(l.card) }) {
                        ListRow(title: ownerTitle(l.card.name, owner: l.card.ownerID), sub: cardLine(l),
                                value: store.format(l.statement), valueSub: l.unbilled > 0 ? String(localized: "+\(store.format(l.unbilled)) later") : nil,
                                valueColor: l.statement > 0 ? Organic.a700 : Organic.n600,
                                mark: LeadMark(glyph: .symbol("creditcard"), tint: Organic.alertSoft, ink: Organic.a700))
                    }
                }
            }

            // Shopping credit: fixed sum, fixed months, 0%. The thing it
            // bought may already be sold — the debit keeps coming.
            SectionHeader(title: "Instalment plans",
                          subtitle: "\(store.format(store.installmentDebt)) still to pay · \(store.format(store.installmentDebitsThisMonth)) in \(Date.now.formatted(.dateTime.month(.wide)))",
                          isOpen: addPlan) { addPlan.toggle() }
            if addPlan { addPlanForm }
            Card(padding: .list) {
                if plans.isEmpty {
                    EmptyNote("No plans yet. Add anything bought on shopping credit — the months left and the total still owed are worked out from the dates.")
                }
                ForEach(plans) { plan in
                    RowButton(first: plan.id == plans.first?.id, padded: false, action: { sheet = .plan(plan) }) {
                        ListRow(title: plan.name, sub: planLine(plan), value: store.format(plan.remaining()),
                                valueSub: plan.isSettled() ? nil : String(localized: "left"),
                                valueColor: plan.isSettled() ? Organic.n600 : Organic.a700,
                                mark: LeadMark(glyph: .symbol("shippingbox"), tint: Organic.infoSoft, ink: Organic.info))
                            .opacity(plan.isSettled() ? 0.45 : 1)
                    }
                }
            }

            // Salary, rent, bills and subscriptions are commitments, not
            // money held or owed: they live in Plan › Recurring. This row is
            // the way there.
            Button { router.planPart = .recurring; router.open(.plan) } label: {
                Card(padding: .list) {
                    ListRow(title: String(localized: "Every month"),
                            sub: String(localized: "Salary, rent, bills and subscriptions · in Plan"),
                            mark: LeadMark(glyph: .symbol("calendar"), tint: Organic.n200, ink: Organic.n700), chevron: true)
                }
            }
            .buttonStyle(.plain)
            HelpText("Statements are typed as the card prints them; what you buy on a card shows as not billed yet until it closes.")
        }
    }

    /// "Paid Tue 13 Oct from MUFG"; a card with nothing open says so.
    private func cardLine(_ l: Finance.CardLine) -> String {
        guard l.statement > 0 else { return String(localized: "Nothing to pay on this statement") }
        let day = l.due.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        if let from = l.card.payFrom { return String(localized: "Paid \(day) from \(from)") }
        return String(localized: "Paid \(day)")
    }

    /// "5 of 18 · ¥26,000 on the 27th from SMBC".
    private func planLine(_ plan: Installment) -> String {
        guard let next = plan.nextDue() else { return String(localized: "Paid off · \(store.format(plan.principal)) over \(plan.months) months") }
        var line = String(localized: "\(plan.paidCount()) of \(plan.months) · \(store.format(next.amount)) on the \(ordinal(Calendar.current.component(.day, from: next.date)))")
        if let from = plan.payFrom { line += String(localized: " from \(from)") }
        return line
    }

    // MARK: - Invested

    private var investedPart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Investments", subtitle: "NISA, stocks, gold, crypto · in net worth") { openInvestments = true }
            Card(padding: .list) {
                NavigationLink { InvestmentsView() } label: {
                    ListRow(title: String(localized: "Investments"), sub: String(localized: "NISA typed from the broker · gold and crypto priced for you"),
                            value: store.format(store.investmentsValue),
                            valueSub: store.investmentsUpdated.map { String(localized: "updated \($0.formatted(.dateTime.day().month(.abbreviated)))") },
                            mark: LeadMark(glyph: .symbol("arrow.up.right"), tint: Organic.chartColor(5).opacity(0.14), ink: Organic.chartColor(5)))
                }
                .buttonStyle(.plain)
            }
            SectionHeader(title: "Lent", subtitle: "Owed to you · in net worth when it is in yen") { openPeople = true }
            Card(padding: .list) {
                NavigationLink { PeopleView() } label: {
                    ListRow(title: String(localized: "People"),
                            sub: String(localized: "Owed to you · \(store.peopleOwingYou) people · loans in đồng kept apart"),
                            value: store.signed(store.loansOwedToYou), valueSub: String(localized: "owed to you"),
                            valueColor: store.loansOwedToYou > 0 ? Organic.s700 : Organic.text,
                            mark: LeadMark(glyph: .symbol("person.2"), tint: Organic.warnSoft, ink: Organic.warn))
                }
                .buttonStyle(.plain)
            }
            HelpText("Funds are typed from the broker; gold and crypto are priced online. Money lent counts in net worth when it is in yen; loans in đồng are kept apart.")
        }
    }

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
                HStack(spacing: 8) {
                    FormField("Closes on day (締め日)", text: $cClosing, numeric: true)
                    FormField("Last 4 digits", text: $cLast4, numeric: true)
                }
                ChipPicker(label: "Paid from", options: store.data.wallets.map(\.name), selection: cPayFrom) { cPayFrom = $0 }
                ChipPicker(label: "Owner", options: store.data.owners.map(\.name),
                           selection: ownerName(cOwner)) { cOwner = ownerID(named: $0) ?? cOwner }
                Text(verbatim: cardPreview).font(Organic.meta).foregroundStyle(Organic.n600)
                HStack {
                    Spacer()
                    AddPill {
                        guard !cName.isEmpty else { return }
                        let digits = cLast4.filter(\.isNumber)
                        store.addCard(CreditCard(name: cName, dueDay: max(cDueValue, 1),
                                                 debt: cDebt, ownerID: cOwner,
                                                 closingDay: cClosingValue,
                                                 payFrom: cPayFrom.isEmpty ? nil : cPayFrom,
                                                 last4: digits.count == 4 ? digits : nil))
                        cName = ""; cDue = ""; cClosing = ""; cDebt = 0; cOwner = "me"; cPayFrom = ""; cLast4 = ""; addCard = false
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
        if !cPayFrom.isEmpty { parts.append(String(localized: "paid from \(cPayFrom) on the due day")) }
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
