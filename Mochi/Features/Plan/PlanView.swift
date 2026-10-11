import SwiftUI

/// Plan: the month as salary sees it (Budget), what is being put aside for
/// the known big bills (Goals), and every fixed item — salary, rent, bills,
/// subscriptions — in one list or calendar (Recurring).
struct PlanView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Organic.Space.l) {
                    // What the open part is, in a line under the title: it
                    // changes with the switch below it.
                    Text(verbatim: summary).font(Organic.value).foregroundStyle(Organic.n600)
                        .padding(.top, -8)
                    SegmentedTabs(options: [Router.PlanPart.budget, .goals, .recurring], selection: $router.planPart) {
                        switch $0 { case .budget: "Budget"; case .goals: "Goals"; case .recurring: "Recurring" }
                    }
                    switch router.planPart {
                    case .budget: BudgetSection()
                    case .goals: GoalsSection()
                    case .recurring: RecurringSection()
                    }
                }
                .padding(.horizontal, Organic.Space.gutter).padding(.bottom, Organic.Space.gutter)
                .readableWidth()
            }
            .background(Organic.bg)
            .navigationTitle("Plan")
        }
    }

    private var summary: String {
        switch router.planPart {
        case .budget:
            let b = store.budget
            let last = b.period.end.addingTimeInterval(-86_400)
            return String(localized: "Your month runs payday to payday: \(b.period.start.formatted(.dateTime.day().month(.abbreviated))) – \(last.formatted(.dateTime.day().month(.abbreviated))), day \(b.dayOfPeriod) of \(b.daysInPeriod)")
        case .goals: return String(localized: "Money set aside for things you already know are coming")
        case .recurring: return String(localized: "Everything that comes and goes on a fixed day")
        }
    }
}

// MARK: - Budget

struct BudgetSection: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var editing: String?
    @State private var limit = 0

    var body: some View {
        let b = store.budget
        let fixed = store.fixedInPayPeriod
        return VStack(alignment: .leading, spacing: Organic.Space.l) {
            Card {
              VStack(alignment: .leading, spacing: Organic.Space.m) {
                Text("Left to spend this period").font(Organic.captionStrong).foregroundStyle(Organic.n600)
                Text(verbatim: store.format(b.left)).font(Organic.hero).foregroundStyle(b.left < 0 ? Organic.a700 : Organic.text)
                Text("About \(store.format(b.perDay)) a day for the \(b.daysLeft) days left")
                    .font(Organic.value).foregroundStyle(Organic.n600)
                ProgressBar(fraction: b.limit > 0 ? Double(b.spent) / Double(b.limit) : 0, tint: Organic.n900).padding(.top, 4)
              }
            }
            ListHeading(title: "Flexible", trailing: String(localized: "\(store.format(b.spent)) of \(store.format(b.limit))"))
            Card(padding: .list) {
                if b.lines.isEmpty { EmptyNote("No limits yet. Tap a category below to give it one.") }
                ForEach(Array(b.lines.enumerated()), id: \.element.id) { i, l in
                    Button { editing = l.category; limit = l.limit } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(verbatim: l.category).font(Organic.row)
                                Spacer()
                                (Text(verbatim: store.format(l.spent)).font(Organic.rowValue)
                                 + Text(verbatim: " " + String(localized: "of \(store.format(l.limit))")).font(Organic.value).foregroundStyle(Organic.n600))
                            }
                            ProgressBar(fraction: l.fraction, tint: Organic.chartColor(l.colorIndex))
                            Text(verbatim: l.spent == 0 ? String(localized: "Nothing yet")
                                 : l.left >= 0 ? String(localized: "\(store.format(l.left)) left") : String(localized: "\(store.format(-l.left)) over"))
                                .font(Organic.caption).foregroundStyle(l.left >= 0 ? Organic.n600 : Organic.a700)
                        }
                        .padding(.vertical, Organic.Space.l)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) { if i > 0 { Hairline() } }
                }
            }
            let unset = store.spendingCategories.map(\.name).filter { n in !b.lines.contains { $0.category == n } }
            if !unset.isEmpty {
                FlowRow(spacing: 8) {
                    ForEach(unset, id: \.self) { n in
                        Button { editing = n; limit = 0 } label: { Chip(label: Text(verbatim: "+ \(n)"), selected: false) }
                            .buttonStyle(.plain)
                    }
                }
            }
            ListHeading(title: "Fixed", trailing: String(localized: "paid or scheduled"))
            // The bills of this pay period one by one, said as paid or still
            // to come; subscriptions together, a tap from their list.
            Card(padding: .list) {
                ForEach(Array(fixed.bills.enumerated()), id: \.element.id) { i, d in
                    ListRow(title: d.recurring.name,
                            sub: metaLine(d.recurring.paidBy.isEmpty ? "" : (store.isCard(d.recurring.paidBy) ? String(localized: "On \(d.recurring.paidBy)") : d.recurring.paidBy),
                                          d.date.formatted(.dateTime.day().month(.abbreviated))),
                            value: store.format(d.recurring.amount), valueSub: d.done ? String(localized: "Paid") : String(localized: "Scheduled"))
                        .overlay(alignment: .top) { if i > 0 { Hairline() } }
                }
                Button { router.planPart = .recurring } label: {
                    ListRow(title: String(localized: "Subscriptions"), sub: String(localized: "\(fixed.subscriptionCount) services · in Recurring"),
                            value: store.format(fixed.subscriptions),
                            valueSub: fixed.subscriptionsDone ? String(localized: "Paid") : String(localized: "Scheduled"))
                }
                .buttonStyle(.plain).overlay(alignment: .top) { if !fixed.bills.isEmpty { Hairline() } }
                ListRow(title: String(localized: "Goals"), sub: String(localized: "Set aside each month"),
                        value: store.format(store.goalsMonthly), valueSub: String(localized: "Kept back"), valueColor: Organic.info)
                    .overlay(alignment: .top) { Hairline() }
            }
            HelpText("The month starts on payday, the \(ordinalDay(b.period.start)), because that is when the money arrives. Belongings you buy are not in this budget: they stay yours, and what they lose in value shows on Belongings.")
        }
        .sheet(item: Binding(get: { editing.map { IDString(id: $0) } }, set: { editing = $0?.id })) { which in
            SheetScaffold(verbatimTitle: which.id) {
                MoneyField("Limit for a pay period", value: $limit)
                HelpText("Spending in \(which.id) from payday to the day before the next is counted against this.")
                PrimaryButton(title: "Save") { store.setBudget(which.id, limit: limit); editing = nil }
                if store.data.budgets?.contains(where: { $0.category == which.id }) == true {
                    DeleteButton(title: "Remove the limit") { store.setBudget(which.id, limit: 0); editing = nil }
                }
            }
        }
    }
}

/// "25th" — the payday the period starts on.
private func ordinalDay(_ d: Date) -> String {
    let f = NumberFormatter(); f.numberStyle = .ordinal
    return f.string(from: Calendar.current.component(.day, from: d) as NSNumber) ?? ""
}

/// A string that can drive `.sheet(item:)`.
struct IDString: Identifiable { let id: String }

// MARK: - Goals

struct GoalsSection: View {
    @Environment(Store.self) private var store
    @State private var editing: Goal?

    var body: some View {
        VStack(alignment: .leading, spacing: Organic.Space.l) {
            HStack {
                Spacer()
                AddButton { editing = Goal(name: "", target: 0) }
            }
            TileGrid {
                Tile(label: "Set aside a month", value: store.format(store.goalsMonthly),
                     sub: String(localized: "across \(store.goals.count) goals"), valueColor: Organic.info)
                Tile(label: "Saved so far", value: store.format(store.goalsSaved),
                     sub: String(localized: "of \(store.format(store.goalsTarget))"))
            }
            Card(padding: .list) {
                if store.goals.isEmpty { EmptyNote("No goals yet. 車検, a trip home, a tax bill — add what you know is coming.") }
                ForEach(Array(store.goals.enumerated()), id: \.element.id) { i, g in
                    Button { editing = g } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: g.name).font(Organic.title)
                                    Text(verbatim: metaLine(g.note, g.due.map { String(localized: "by \($0.formatted(.dateTime.month(.abbreviated).year()))") } ?? String(localized: "no date")))
                                        .font(Organic.caption).foregroundStyle(Organic.n600)
                                }
                                Spacer()
                                let m = Finance.monthlySetAside(g)
                                Text(verbatim: m > 0 ? String(localized: "\(store.format(m))/mo") : String(localized: "When you can"))
                                    .font(Organic.rowValue).foregroundStyle(Organic.info)
                            }
                            ProgressBar(fraction: g.target > 0 ? Double(g.saved) / Double(g.target) : 0)
                            HStack {
                                Text(verbatim: String(localized: "\(store.format(g.saved)) saved")); Spacer()
                                Text(verbatim: String(localized: "of \(store.format(g.target))"))
                            }
                            .font(Organic.caption).foregroundStyle(Organic.n600)
                        }
                        .padding(.vertical, Organic.Space.l)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) { if i > 0 { Hairline() } }
                }
            }
            Card {
              VStack(alignment: .leading, spacing: 12) {
                Text("How goals change the other numbers").font(Organic.title)
                Text("What you set aside counts as kept back in Safe to spend, so \(store.format(store.goalsMonthly)) a month never looks free to spend. Paying for the goal later is spending on that day, taken from the pot, not from the month.")
                    .font(Organic.value).foregroundStyle(Organic.n600).lineSpacing(3)
              }
            }
        }
        .sheet(item: $editing) { GoalEditor(goal: $0) }
    }
}

struct GoalEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let goal: Goal
    @State private var g = Goal(name: "", target: 0)
    @State private var hasDate = true
    @State private var add = 0

    var body: some View {
        SheetScaffold(title: goal.name.isEmpty ? "New goal" : "Goal") {
            FormField("What for (車検, Tết at home…)", text: $g.name)
            FormField("Note", text: $g.note)
            MoneyField("Target", value: $g.target)
            MoneyField("Saved so far", value: $g.saved)
            Toggle("It has a date", isOn: $hasDate).font(Organic.body).tint(Organic.accent)
            if hasDate {
                DatePicker("Needed by", selection: Binding(get: { g.due ?? .now.addingTimeInterval(86_400 * 180) }, set: { g.due = $0 }),
                           displayedComponents: .date).font(Organic.body)
            }
            if !goal.name.isEmpty {
                HStack { MoneyField("Put aside now", value: $add); AddPill(title: "Add") { g.saved += add; add = 0 } }
            }
            HelpText(verbatim: hasDate && g.target > 0
                     ? String(localized: "\(store.format(Finance.monthlySetAside(Goal(name: g.name, target: g.target, saved: g.saved, due: g.due ?? .now)))) a month kept back from Safe to spend until it is met.")
                     : String(localized: "An open goal asks for nothing in particular each month."))
            PrimaryButton(title: "Save") {
                guard !g.name.isEmpty, g.target > 0 else { return }
                if !hasDate { g.due = nil } else if g.due == nil { g.due = .now.addingTimeInterval(86_400 * 180) }
                store.saveGoal(g); dismiss()
            }
            if !goal.name.isEmpty { DeleteButton(title: "Delete goal") { store.deleteGoal(goal); dismiss() } }
        }
        .onAppear { g = goal; hasDate = goal.name.isEmpty || goal.due != nil }
    }
}
