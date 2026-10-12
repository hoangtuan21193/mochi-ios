import SwiftUI

/// Transactions: every account in one list, a month at a time, grouped by
/// day with the day's total — and, one tab over, where the month went.
struct TransactionsView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var month = Date.now
    @State private var filter: Finance.TransactionFilter = .all
    @State private var showSpending = false
    @State private var search = ""
    @State private var searching = false
    @State private var editing: Transaction?
    @State private var importing = false

    private var interval: DateInterval { Calendar.current.dateInterval(of: .month, for: month)! }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Organic.Space.l) {
                    SegmentedTabs(options: [false, true], selection: $showSpending) { $0 ? "Spending" : "List" }
                    // Spending steps by its own period (a month, a pay period, a
                    // year), so it brings its own stepper.
                    if showSpending {
                        SpendingSection(date: $month)
                    } else {
                        HStack {
                            MonthStepper(month: $month)
                            Spacer()
                        }
                        list
                    }
                }
                .padding(.horizontal, Organic.Space.gutter).padding(.bottom, Organic.Space.gutter)
                .readableWidth()
            }
            .background(Organic.bg)
            .navigationTitle("Transactions")
            .toolbar {
                // Scanning first: it is how most rows get here. Typing one starts
                // from the scan sheet or Home's "Add a spend".
                // Spending reads what is booked; searching, importing and
                // scanning are the list's, and the canvas draws Spending bare.
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !showSpending {
                        Button { router.capture = .scan } label: { Image(systemName: "doc.text.viewfinder") }
                            .accessibilityLabel("Scan a receipt")
                        Button { searching.toggle(); if !searching { search = "" } } label: {
                            Image(systemName: search.isEmpty ? "magnifyingglass" : "magnifyingglass.circle.fill")
                        }
                        .accessibilityLabel("Search")
                        Button { importing = true } label: { Image(systemName: "doc") }
                            .accessibilityLabel("Import a statement")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if searching {
                    SearchDock("Shop, note or amount", text: $search) { searching = false; search = "" }
                }
            }
            .sheet(item: $editing) { t in TransactionEditor(existing: t) }
            .sheet(isPresented: $importing) { ImportStatementView() }
            .onAppear(perform: takeRoute)
            .onChange(of: router.transactionsFilter) { _, _ in takeRoute() }
            .onChange(of: router.showSpending) { _, _ in takeRoute() }
        }
    }

    private func takeRoute() {
        filter = router.transactionsFilter
        showSpending = router.showSpending
    }

    // MARK: - List

    private var list: some View {
        let rows = store.transactions(in: search.isEmpty ? interval : nil, filter: filter, search: search)
        let flow = store.flow(in: interval)
        let queue = store.reviewQueue
        return VStack(alignment: .leading, spacing: Organic.Space.l) {
            Text("\(flow.count) transactions · in \(store.format(flow.income)) · out \(store.format(flow.out))")
                .font(Organic.caption).foregroundStyle(Organic.n600)
                .padding(.top, -6)
            FilterChips(options: Finance.TransactionFilter.allCases, selection: $filter) { f in filterLabel(f) }
            if queue.count > 0 && filter != .review {
                Button { filter = .review } label: {
                    Banner(text: reviewLine(queue), action: "Review", symbol: "wave.3.right", tone: .warn)
                }
                .buttonStyle(.plain)
            }
            if rows.isEmpty {
                Card { EmptyNote(search.isEmpty ? "Nothing here this month. Scan a receipt, type a spend or import a statement." : "Nothing matches that.") }
            }
            ForEach(store.days(rows)) { day in
                VStack(alignment: .leading, spacing: 6) {
                    ListHeading(title: "\(day.day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))",
                                trailing: store.signed(day.total))
                    Card(padding: .list) {
                        ForEach(Array(day.rows.enumerated()), id: \.element.id) { i, t in
                            Button { editing = t } label: { TransactionRow(t: t) }
                                .buttonStyle(.plain)
                                .overlay(alignment: .top) { if i > 0 { Hairline() } }
                        }
                    }
                }
            }
        }
    }

    /// Why they are waiting, when it is one reason: an automation booked them
    /// and could not know the category.
    private func reviewLine(_ q: Finance.ReviewQueue) -> LocalizedStringKey {
        switch q.source {
        case .applePay: "\(q.count) came in from Apple Pay. Check the category and they’re done."
        case .email: "\(q.count) came in from card emails. Check the category and they’re done."
        case .statement: "\(q.count) came in from a statement. Check the category and they’re done."
        default: "\(q.count) to confirm. Check the category and they’re done."
        }
    }

    /// A chip that has work in it carries the count, in the accent, so it
    /// reads as a to-do and not as part of the name.
    private func counted(_ name: LocalizedStringKey, _ n: Int) -> Text {
        n > 0 ? Text(name) + Text(verbatim: " \(n)").bold().foregroundStyle(Organic.accent) : Text(name)
    }

    private func filterLabel(_ f: Finance.TransactionFilter) -> Text {
        switch f {
        case .all: return Text("All")
        case .review: return counted("To review", store.reviewQueue.count)
        case .uncategorised: return counted("No category", store.reviewQueue.uncategorised)
        case .belongings: return Text("Belongings")
        case .split: return Text("Split")
        }
    }
}

/// One transaction: who, what for, how much, from where.
struct TransactionRow: View {
    @Environment(Store.self) private var store
    let t: Transaction

    var body: some View {
        ListRow(title: title, sub: sub, value: store.signed(t.amount), valueSub: via,
                valueColor: valueColor, subColor: subColor, mark: mark)
    }

    private var title: String {
        if !t.merchant.isEmpty { return t.merchant }
        switch t.kind {
        case .move: return String(localized: "Move")
        case .adjustment: return String(localized: "Balance corrected")
        case .income: return String(localized: "Money in")
        default: return t.note.isEmpty ? String(localized: "Spend") : t.note
        }
    }

    private var sub: String {
        if t.needsReview { return metaLine(String(localized: "To review"), t.category.isEmpty ? "" : t.category + "?") }
        switch t.kind {
        // The shop is the title; which belonging it became is one tap in.
        case .asset: return String(localized: "Belonging · not spending")
        case .move: return String(localized: "Move · \(t.account) → \(t.toAccount ?? "")")
        case .refund: return metaLine(String(localized: "Refund"), t.category)
        case .adjustment: return String(localized: "Adjustment · not spending")
        case .income: return metaLine(String(localized: "Income"), t.note)
        case .spend:
            var parts = [t.category.isEmpty ? String(localized: "No category") : t.category]
            if let share = t.myShare { parts.append(String(localized: "your share \(store.format(share))")) }
            if let f = t.foreignAmount, let c = t.currency { parts.append(Currency.foreign(f, code: c)) }
            if t.receiptFile != nil { parts.append(String(localized: "receipt kept")) }
            // How it got here, when the right-hand line does not already say.
            else if t.source == .manual { parts.append(String(localized: "added here")) }
            else if t.source == .schedule || t.source == .recurring { parts.append(String(localized: "every month")) }
            return parts.joined(separator: " · ")
        }
    }

    private var via: String {
        switch t.source {
        case .applePay: return metaLine("Apple Pay", t.account)
        case .statement: return metaLine(String(localized: "Imported"), t.account)
        case .email: return metaLine(String(localized: "Card email"), t.account)
        default: return t.account
        }
    }

    private var valueColor: Color {
        switch t.kind {
        case .income, .refund: return Organic.s700
        case .asset, .move, .adjustment: return Organic.n600
        case .spend: return Organic.text
        }
    }

    private var subColor: Color {
        if t.needsReview { return Organic.warn }
        return t.kind == .asset ? Organic.info : Organic.n600
    }

    private var mark: LeadMark {
        if t.needsReview { return LeadMark(glyph: .initials(t.merchant.isEmpty ? "?" : t.merchant), tint: Organic.warnSoft, ink: Organic.warn) }
        switch t.kind {
        case .asset: return LeadMark(glyph: .initials(title), tint: Organic.infoSoft, ink: Organic.info)
        case .move: return LeadMark(glyph: .symbol("arrow.left.arrow.right"), tint: Organic.n200, ink: Organic.n700)
        case .adjustment: return LeadMark(glyph: .symbol("equal"), tint: Organic.n200, ink: Organic.n700)
        case .income, .refund: return LeadMark(glyph: .symbol("arrow.down.left"), tint: Organic.s100, ink: Organic.s700)
        // The shop's initials in its category's colour: the colour says what
        // for, the letters say where, and a column of cart icons said neither.
        case .spend:
            guard let c = store.spendingCategories.first(where: { $0.name == t.category }) else {
                return LeadMark(glyph: .initials(title), tint: Organic.n200, ink: Organic.n700)
            }
            let color = Organic.chartColor(c.colorIndex)
            return LeadMark(glyph: .initials(title), tint: color.opacity(0.16), ink: color)
        }
    }
}
