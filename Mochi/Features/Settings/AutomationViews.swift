import SwiftUI
import UserNotifications

// MARK: - Rules

/// Rules: a shop or a place decides the category, so the same choice is not
/// made twice. What the user picks on a transaction always wins.
struct RulesView: View {
    @Environment(Store.self) private var store
    @State private var contains = ""
    @State private var category = ""
    @State private var ask = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Organic.Space.l) {
                Text("Mochi fills these in so you don’t pick them again").font(Organic.caption).foregroundStyle(Organic.n600)
                if let s = suggestion {
                    Button { store.addRule(s) } label: {
                        Banner(text: "You put \(s.contains) in \(s.category) three times. Always?", action: "Make a rule",
                               symbol: "wand.and.stars", tone: .info)
                    }
                    .buttonStyle(.plain)
                }
                ListHeading(title: "Your rules", trailing: String(localized: "used this month"))
                Card(padding: .list) {
                    if store.rules.isEmpty { EmptyNote("No rules yet. Add one below, or accept a suggestion when it appears.") }
                    ForEach(Array(store.rules.enumerated()), id: \.element.id) { i, r in
                        HStack {
                            ListRow(title: r.placeName.isEmpty ? String(localized: "Shop has “\(r.contains)”") : String(localized: "At \(r.placeName)"),
                                    sub: r.ask ? String(localized: "Ask every time") : metaLine(r.category, r.account ?? ""),
                                    value: "\(uses(r))×", valueColor: Organic.n600,
                                    mark: LeadMark(glyph: .symbol(r.latitude != nil ? "mappin" : "text.magnifyingglass"), tint: Organic.infoSoft, ink: Organic.info))
                            RemoveButton { store.deleteRule(r) }
                        }
                        .overlay(alignment: .top) { if i > 0 { Hairline() } }
                    }
                }
                Card {
                    Text("New rule").font(Organic.title)
                    FormField("When the shop contains", text: $contains).padding(.top, 6)
                    Toggle("Ask every time (it sells everything)", isOn: $ask).font(Organic.body).tint(Organic.accent).padding(.top, 6)
                    if !ask {
                        ChipPicker(label: "Set", options: store.spendingCategories.map(\.name), selection: category) { category = $0 }
                            .padding(.top, 6)
                    }
                    HelpText("Applies to new transactions and to the ones already here without a category. Your own edits always win over a rule.")
                        .padding(.top, 6)
                    PrimaryButton(title: "Add rule") {
                        guard !contains.isEmpty, ask || !category.isEmpty else { return }
                        store.addRule(Rule(contains: contains, category: category, ask: ask))
                        contains = ""; category = ""; ask = false
                    }
                    .padding(.top, 8)
                }
            }
            .padding(Organic.Space.gutter)
            .readableWidth()
        }
        .background(Organic.bg)
        .navigationTitle("Rules")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var suggestion: Rule? {
        let merchants = Set(store.transactions.map(\.merchant))
        return merchants.lazy.compactMap { store.suggestedRule(for: $0) }.first
    }

    private func uses(_ r: Rule) -> Int {
        store.transactions(in: store.thisMonth).filter { Finance.rule(for: $0.merchant, latitude: $0.latitude, longitude: $0.longitude, store.data)?.id == r.id }.count
    }
}

// MARK: - Notifications

/// Local notifications: worked out on the phone, scheduled on the phone.
/// Every one says the figure and what to do; none says "you overspent".
struct NotificationsView: View {
    @Environment(Store.self) private var store
    @State private var prefs = NotificationPrefs()
    @State private var allowed: Bool?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Organic.Space.l) {
                Text("Worked out on this iPhone · nothing sent to a server").font(Organic.caption).foregroundStyle(Organic.n600)
                if allowed == false {
                    Banner(text: "Notifications are off for Mochi in the iPhone’s Settings.", symbol: "bell.slash", tone: .warn)
                }
                Card(padding: .list) {
                    toggle("Card and plan payments", "3 days before · with cash left after", $prefs.payments)
                    toggle("Short of cash", "As soon as the forecast dips below zero", $prefs.shortfall)
                    toggle("Large spend", "Anything over \(store.format(prefs.largeSpendOver)) · a chance to call it a belonging", $prefs.largeSpend)
                    toggle("Subscription renews", "3 days before", $prefs.subscriptions)
                    toggle("Weekly check-in", "Sunday 20:00", $prefs.weeklyCheckin)
                    toggle("Warranty ends", "30 days before", $prefs.warranty)
                    toggle("Update a belonging’s worth", "Every 3 months, for May sell only", $prefs.worthReminder)
                }
                HelpText("Every notice says the figure and what to do. None of them says “you overspent”.")
            }
            .padding(Organic.Space.gutter)
            .readableWidth()
        }
        .background(Organic.bg)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { prefs = store.notificationPrefs }
        .onChange(of: prefs) { _, p in
            store.setNotificationPrefs(p)
            Task { allowed = await Notifier.schedule(for: store) }
        }
        .task { allowed = await Notifier.schedule(for: store) }
    }

    private func toggle(_ title: LocalizedStringKey, _ sub: LocalizedStringKey, _ on: Binding<Bool>) -> some View {
        Toggle(isOn: on) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Organic.row)
                Text(sub).font(Organic.caption).foregroundStyle(Organic.n600)
            }
        }
        .tint(Organic.accent)
        .padding(.vertical, Organic.Space.row)
        .overlay(alignment: .top) { Hairline() }
    }
}

// MARK: - Weekly check-in

/// A minute on Sunday: what the week cost, the entries waiting for a
/// category (one tap each), the belongings due a new worth, and what renews
/// soon. Missing a week piles nothing up.
struct WeeklyCheckinView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let cal = Calendar.current
        let end = cal.startOfDay(for: .now).addingTimeInterval(86_400)
        let week = DateInterval(start: end.addingTimeInterval(-86_400 * 7), end: end)
        let review = store.transactions.filter(\.needsReview).sorted { $0.date > $1.date }
        let stale = store.forSale.filter { ($0.valueHistory?.last?.date ?? $0.boughtOn) < .now.addingTimeInterval(-86_400 * 90) }
        let renewing = store.subscriptions.filter { Finance.nextOccurrence($0, after: .now) < .now.addingTimeInterval(86_400 * 7) }
        SheetScaffold(title: "Your week") {
            Card {
                Text("Spent \(week.start.formatted(.dateTime.day().month(.abbreviated))) – \(week.end.addingTimeInterval(-1).formatted(.dateTime.day().month(.abbreviated)))")
                    .font(Organic.captionStrong).foregroundStyle(Organic.n600)
                Text(verbatim: store.format(store.spending(in: week))).font(Organic.hero)
                let b = store.budget
                if !b.lines.isEmpty {
                    Verdict(text: b.left >= 0 ? "Within your pay-period budget" : "Over the budget for this pay period", positive: b.left >= 0)
                }
            }
            if !review.isEmpty {
                ListHeading(title: "\(review.count) to confirm", trailing: String(localized: "tap the right one"))
                Card(padding: .list) {
                    ForEach(Array(review.prefix(8).enumerated()), id: \.element.id) { i, t in
                        VStack(alignment: .leading, spacing: 6) {
                            TransactionRow(t: t)
                            FlowRow(spacing: 6) {
                                ForEach(suggestions(for: t), id: \.self) { c in
                                    Button { store.markReviewed(t, category: c) } label: {
                                        Chip(label: Text(verbatim: c), selected: c == t.category)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.leading, 48).padding(.bottom, 8)
                        }
                        .overlay(alignment: .top) { if i > 0 { Hairline() } }
                    }
                }
            }
            if !stale.isEmpty || !renewing.isEmpty {
                ListHeading(title: "Worth a look")
                Card(padding: .list) {
                    if !stale.isEmpty {
                        ListRow(title: String(localized: "\(stale.count) belongings not valued for 3 months"),
                                sub: stale.prefix(2).map(\.name).joined(separator: ", "),
                                mark: LeadMark(glyph: .symbol("shippingbox"), tint: Organic.infoSoft, ink: Organic.info))
                    }
                    ForEach(renewing) { s in
                        ListRow(title: String(localized: "\(s.name) renews \(Finance.nextOccurrence(s, after: .now).formatted(.dateTime.day().month(.abbreviated)))"),
                                sub: String(localized: "\(store.format(s.amount)) · still using it?"),
                                mark: LeadMark(glyph: .symbol("bell"), tint: Organic.a100, ink: Organic.accent))
                            .overlay(alignment: .top) { Hairline() }
                    }
                }
            }
            PrimaryButton(title: "Done for this week") { store.finishCheckin(); dismiss() }
            HelpText("Missed a week? Nothing piles up: next Sunday shows the same short list.")
        }
    }

    /// The category it is probably, then the two most used.
    private func suggestions(for t: Transaction) -> [String] {
        var out: [String] = []
        if !t.category.isEmpty { out.append(t.category) }
        let used = Dictionary(grouping: store.transactions.filter { !$0.category.isEmpty }, by: \.category)
            .sorted { $0.value.count > $1.value.count }.map(\.key)
        for c in used where !out.contains(c) && out.count < 3 { out.append(c) }
        if out.count < 3 { out += store.spendingCategories.map(\.name).filter { !out.contains($0) }.prefix(3 - out.count) }
        return out
    }
}

// MARK: - Local notifications

/// Schedules what the preferences ask for, from the same figures the screens
/// show. Replaces everything it scheduled before each time.
enum Notifier {
    @discardableResult
    static func schedule(for store: Store) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return false }
        center.removeAllPendingNotificationRequests()
        let p = store.notificationPrefs
        let cal = Calendar.current
        func add(_ id: String, _ title: String, _ body: String, at date: Date) {
            guard date > .now else { return }
            let c = UNMutableNotificationContent()
            c.title = title; c.body = body
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            center.add(UNNotificationRequest(identifier: id, content: c,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)),
                       withCompletionHandler: nil)
        }
        if p.payments {
            for day in store.paymentsDue.prefix(6) where day.amount < 0 {
                let at = cal.date(bySettingHour: 9, minute: 0, second: 0, of: day.date.addingTimeInterval(-86_400 * 3)) ?? day.date
                add("pay-\(day.id.timeIntervalSince1970)",
                    String(localized: "\(day.names.first ?? String(localized: "A payment")) in 3 days"),
                    String(localized: "\(store.format(-day.amount)) leaves on \(day.date.formatted(.dateTime.day().month(.abbreviated))). Cash after: \(store.format(day.balanceAfter))."),
                    at: at)
            }
        }
        if p.shortfall, let s = store.shortfall {
            add("short", String(localized: "Short by \(store.format(s.amount))"),
                String(localized: "Payments before \(s.from.formatted(.dateTime.day().month(.abbreviated))) need that much more in the bank."),
                at: .now.addingTimeInterval(60))
        }
        if p.shortfall {
            // A move between your own accounts, on the morning of its last day.
            for m in store.transfersNeeded {
                add("move-\(m.id)", String(localized: "Move \(store.format(m.amount)) to \(m.to) today"),
                    String(localized: "\(m.debitLabel) takes \(store.format(m.debitAmount)) from \(m.to) on \(m.debitDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))). Move it from \(m.from)."),
                    at: cal.date(bySettingHour: 9, minute: 0, second: 0, of: m.deadline) ?? m.deadline)
            }
        }
        if p.subscriptions {
            for s in store.subscriptions.prefix(10) {
                let next = Finance.nextOccurrence(s, after: .now)
                add("sub-\(s.id)", String(localized: "\(s.name) renews in 3 days"),
                    String(localized: "\(store.format(s.amount)) on \(s.paidBy). Still using it?"),
                    at: cal.date(bySettingHour: 9, minute: 0, second: 0, of: next.addingTimeInterval(-86_400 * 3)) ?? next)
            }
        }
        if p.weeklyCheckin {
            var comps = DateComponents(); comps.weekday = 1; comps.hour = 20
            let c = UNMutableNotificationContent()
            c.title = String(localized: "Your week in a minute")
            c.body = String(localized: "\(store.reviewCount) to confirm, and what the week cost.")
            center.add(UNNotificationRequest(identifier: "checkin", content: c,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)),
                       withCompletionHandler: nil)
        }
        if p.warranty {
            for item in store.unsold {
                guard let until = item.warrantyUntil else { continue }
                add("war-\(item.id)", String(localized: "\(item.name): cover ends in 30 days"),
                    String(localized: "Worth a check before \(until.formatted(date: .abbreviated, time: .omitted))."),
                    at: until.addingTimeInterval(-86_400 * 30))
            }
        }
        return true
    }
}
