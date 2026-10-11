import SwiftUI

/// Recurring: every fixed item — salary, rent, bills, subscriptions — in one
/// place, a month at a time, as a list split into what is still to come and
/// what has happened, or as a calendar. Monarch's way of showing them: one
/// list, the kind a filter rather than a separate screen, so rent and Netflix
/// sit side by side and the month's fixed money can be read at once.
/// Subscriptions keep their "still using it?" question.
struct RecurringSection: View {
    @Environment(Store.self) private var store
    @State private var month = Date.now
    @State private var filter: Filter = .all
    /// List or calendar is a habit, so it is remembered.
    @AppStorage("recurring.view") private var view: Shape = .list
    @State private var day: Int?
    @State private var editing: Recurring?
    @State private var adding = false

    enum Filter: Hashable { case all, bills, subscriptions, income }
    enum Shape: String { case list, calendar }

    var body: some View {
        let due = store.recurringDue(month: month)
        let totals = Finance.recurringTotals(due)
        let shown = due.filter(matches)
        return VStack(alignment: .leading, spacing: Organic.Space.l) {
            MonthStepper(month: $month, allowsFuture: true, spread: true)
            TileGrid {
                Tile(label: "Coming in", value: store.format(totals.income), sub: String(localized: "salary"), valueColor: Organic.s700)
                Tile(label: "Bills", value: store.format(totals.bills), sub: String(localized: "rent, power, insurance"))
                Tile(label: "Subscriptions", value: store.format(totals.subscriptions),
                     sub: String(localized: "\(due.filter { $0.kind == .subscription }.count) services"))
                Tile(label: "Still to pay", value: store.format(totals.stillToPay), sub: String(localized: "this month"))
            }
            if filter == .all || filter == .subscriptions, let ask = renewingSoon {
                renewalCard(ask)
            }
            HStack(spacing: Organic.Space.m) {
                FilterChips(options: [Filter.all, .bills, .subscriptions, .income], selection: $filter) { f in
                    switch f {
                    case .all: Text("All")
                    case .bills: Text("Bills")
                    case .subscriptions: Text("Subscriptions")
                    case .income: Text("Income")
                    }
                }
                SegmentedTabs(options: [Shape.list, .calendar], selection: $view, compact: true) {
                    switch $0 { case .list: "List"; case .calendar: "Calendar" }
                }
                .fixedSize()
            }
            switch view {
            case .list: list(shown, totals: totals)
            case .calendar: calendar(shown)
            }
            HelpText("Salary, rent, bills and subscriptions in one list. Subscriptions are the ones you could cancel.")
        }
        .sheet(item: $editing) { RecurringSheetView(entry: $0) }
    }

    private func matches(_ d: Finance.RecurringDue) -> Bool {
        switch filter {
        case .all: return true
        case .bills: return d.kind == .bill
        case .subscriptions: return d.kind == .subscription
        case .income: return d.kind == .income
        }
    }

    /// A subscription renewing within four days that has not been asked
    /// about this month.
    private var renewingSoon: Recurring? {
        store.subscriptions.first { s in
            Finance.nextOccurrence(s, after: .now).timeIntervalSinceNow < 86_400 * 4
                && (s.lastAsked.map { $0.timeIntervalSinceNow < -86_400 * 25 } ?? true)
        }
    }

    /// Asked before it renews, never cancelled for you: Mochi asks, the
    /// service is cancelled where it was bought.
    private func renewalCard(_ ask: Recurring) -> some View {
        let next = Finance.nextOccurrence(ask, after: .now)
        let days = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: next).day ?? 0)
        return Card(fill: Organic.warnSoft) {
            HStack(alignment: .top, spacing: Organic.Space.m) {
                Image(systemName: "bell").font(Organic.valueStrong).foregroundStyle(Organic.warn)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(ask.name) renews \(next.formatted(.dateTime.day().month(.abbreviated))). Still using it?")
                        .font(Organic.rowValue).foregroundStyle(Organic.text)
                    Text(verbatim: (ask.paidBy.isEmpty ? String(localized: "\(store.format(ask.amount)) a month")
                                                        : String(localized: "\(store.format(ask.amount)) a month on \(ask.paidBy)"))
                                   + ", " + (days == 1 ? String(localized: "tomorrow") : String(localized: "in \(days) days")))
                        .font(Organic.caption).foregroundStyle(Organic.n700)
                }
            }
            HStack(spacing: 8) {
                PrimaryButton(title: "Keep it") { store.answerStillUsing(ask, keep: true) }
                SecondaryButton(title: "I’ve cancelled it", style: .warm) { store.answerStillUsing(ask, keep: false) }
            }
            .padding(.top, 10)
        }
    }

    @ViewBuilder private func list(_ items: [Finance.RecurringDue], totals: Finance.RecurringTotals) -> some View {
        let upcoming = items.filter { !$0.done }, done = items.filter(\.done)
        SectionHeader(title: "Upcoming",
                      subtitle: "\(totals.leftCount) left · \(store.format(totals.stillToPay)) out · \(store.format(totals.stillToCome)) in",
                      isOpen: adding) { adding.toggle() }
        if adding { RecurringAddForm { adding = false } }
        if items.isEmpty {
            Card { EmptyNote("Nothing here this month. Add salary, rent, bills and subscriptions with the + above.") }
        }
        if !upcoming.isEmpty { rows(upcoming) }
        if !done.isEmpty {
            ListHeading(title: "Done this month", trailing: store.format(totals.paid))
            rows(done)
        }
    }

    private func rows(_ items: [Finance.RecurringDue], kind: Bool = false) -> some View {
        Card(padding: .list) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, d in
                Button { editing = d.recurring } label: {
                    ListRow(title: d.recurring.name, sub: detail(d, kind: kind),
                            value: store.signed(d.amount),
                            valueColor: d.kind == .income ? Organic.s700 : Organic.text,
                            mark: dateMark(d))
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { if i > 0 { Hairline() } }
            }
        }
    }

    /// The day on a calendar leaf in the colour of its kind; today says so,
    /// and a day gone by is grey.
    private func dateMark(_ d: Finance.RecurringDue) -> LeadMark {
        let cal = Calendar.current
        let today = cal.isDateInToday(d.date)
        let top = today ? String(localized: "Today") : d.date.formatted(.dateTime.weekday(.abbreviated))
        let ink = d.done ? Organic.n600 : tint(d.kind)
        return LeadMark(glyph: .dated(top, cal.component(.day, from: d.date)), tint: d.done ? Organic.n200 : ink.opacity(0.14), ink: ink, size: 40)
    }

    /// "Subscription · on Rakuten Card"; the calendar's day list also says
    /// what kind a bill is, because nothing else on it does.
    private func detail(_ d: Finance.RecurringDue, kind: Bool = false) -> String {
        let r = d.recurring
        var parts: [String] = []
        if d.kind == .subscription { parts.append(String(localized: "Subscription")) }
        if kind && d.kind == .bill { parts.append(String(localized: "Bill")) }
        if let m = r.month {
            parts.append(String(localized: "yearly"))
            parts.append(Calendar.current.monthSymbols[max(0, min(11, m - 1))])
        }
        if !r.paidBy.isEmpty {
            if d.kind == .income { parts.append(String(localized: "into \(r.paidBy)")) }
            else { parts.append(store.isCard(r.paidBy) ? String(localized: "on \(r.paidBy)") : r.paidBy) }
        }
        return parts.joined(separator: " · ")
    }

    private func tint(_ k: Finance.RecurringKind) -> Color {
        switch k {
        case .income: return Organic.s700
        case .bill: return Organic.a700
        case .subscription: return Organic.chartColor(5)
        }
    }

    @ViewBuilder private func calendar(_ items: [Finance.RecurringDue]) -> some View {
        let cal = Calendar.current
        let byDay = Dictionary(grouping: items) { cal.component(.day, from: $0.date) }
        Card {
            CalendarMonth(month: month,
                          marks: byDay.mapValues { $0.map { tint($0.kind) } },
                          labels: Finance.recurringIncomeByDay(items).mapValues { "+\($0 / 1000)k" },
                          selected: $day)
            Hairline().padding(.top, 8)
            ChartLegend(.init("Bill", .dot, Organic.a700), .init("Subscription", .dot, Organic.chartColor(5)), .init("Income", .dot, Organic.s700))
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
        if let day {
            let picked = byDay[day] ?? []
            let date = Finance.date(day: day, in: month)
            let away = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: date).day ?? 0
            SectionHeader(title: "\(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))",
                          subtitle: "\(picked.count == 1 ? String(localized: "1 item") : String(localized: "\(picked.count) items")) · \(away > 0 ? String(localized: "in \(away) days") : away == 0 ? String(localized: "today") : String(localized: "\(-away) days ago"))",
                          isOpen: adding) { adding.toggle() }
            if adding { RecurringAddForm { adding = false } }
            if picked.isEmpty { Card { EmptyNote("Nothing fixed on this day.") } } else { rows(picked, kind: true) }
        }
    }
}

/// A new fixed item: income, a bill or a subscription, its day and what pays
/// it. Ends in a line saying where the money will show up — a card-paid bill
/// surprises people, because nothing leaves on its own day.
struct RecurringAddForm: View {
    @Environment(Store.self) private var store
    let done: () -> Void
    @State private var name = ""
    @State private var amount = 0
    @State private var income = false
    @State private var dayText = ""
    @State private var paidBy = ""
    @State private var category = "other"

    private var day: Int { min(max(Int(dayText.filter(\.isNumber)) ?? 0, 0), 31) }

    var body: some View {
        Card {
            Text(income ? "New monthly income" : "New monthly bill").font(Organic.title).padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Button { income = false; if category == "salary" { category = "other" } } label: {
                        Chip(label: Text("Bill"), selected: !income, tint: Organic.a600)
                    }.buttonStyle(.plain)
                    Button { income = true; category = "salary" } label: {
                        Chip(label: Text("Income"), selected: income, tint: Organic.s600)
                    }.buttonStyle(.plain)
                }
                FormField(income ? "What it is (Salary)" : "What it is (Rent, Netflix…)", text: $name)
                HStack(spacing: 8) {
                    MoneyField("Amount a month", value: $amount)
                    FormField("Day (25)", text: $dayText, numeric: true).frame(width: 110)
                }
                if !income {
                    ChipPicker(label: "Kind", options: Recurring.expenseCategories, selection: category,
                               display: { Text(Recurring.categoryName($0)) }) { category = $0 }
                }
                if !store.payers.isEmpty {
                    ChipPicker(label: income ? "Lands in" : "Paid by", options: store.payers, selection: paidBy) { paidBy = $0 }
                }
                Text(preview).font(Organic.meta).foregroundStyle(Organic.n600)
                HStack {
                    Spacer()
                    AddPill {
                        guard !name.isEmpty, amount > 0, day > 0 else { return }
                        store.addRecurring(Recurring(name: name, amount: amount, kind: income ? "income" : "expense",
                                                     category: category, day: day, paidBy: paidBy))
                        done()
                    }
                }
            }
        }
    }

    private var preview: LocalizedStringKey {
        guard amount > 0, day > 0 else { return "Amount and day of the month, then what pays it." }
        if income { return "\(store.format(amount)) arrives on the \(day)th; Safe to spend counts it when the day falls before the horizon." }
        if store.isCard(paidBy) { return "Goes onto \(paidBy)'s next statement; cash leaves on the card's due day, not on the \(day)th." }
        return "\(store.format(amount)) leaves cash on the \(day)th every month."
    }
}
