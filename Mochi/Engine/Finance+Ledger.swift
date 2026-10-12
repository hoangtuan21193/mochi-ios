import Foundation

/// The ledger: balances worked out from transactions, what the schedules post
/// on their day, and what Spending, Budget and Goals read. Pure like the rest
/// of `Finance` — the same book and the same day always give the same answer.
extension Finance {

    // MARK: - Transactions and balances

    static func transactions(_ data: AppData) -> [Transaction] { data.transactions ?? [] }

    /// A day before the book kept transactions. What happened then is inside
    /// the opening balances and the typed statements, so it is never counted
    /// again from a transaction or a schedule.
    static func isLegacy(_ date: Date, _ data: AppData) -> Bool {
        guard let start = data.ledgerStart else { return true }
        return date < Calendar.current.startOfDay(for: start)
    }

    /// What every transaction has done to one account, by name. A move takes
    /// from `account` and gives to `toAccount`; anything else changes
    /// `account` by its signed amount.
    static func effect(on name: String, _ data: AppData, through end: Date? = nil) -> Int {
        guard !name.isEmpty else { return 0 }
        return transactions(data).reduce(0) { sum, t in
            if let end, t.date > end { return sum }
            if t.kind == .move {
                return sum + (t.toAccount == name ? t.amount : 0) - (t.account == name ? t.amount : 0)
            }
            return sum + (t.account == name ? t.amount : 0)
        }
    }

    /// A wallet today: the balance it was given plus everything since.
    static func balance(of wallet: Wallet, _ data: AppData, through end: Date? = nil) -> Int {
        wallet.balance + effect(on: wallet.name, data, through: end)
    }

    /// What a card was charged in (from, to]: spending and belongings on it,
    /// less refunds, plus money moved out of it (a plan paid by card). A
    /// payment into the card is not a charge; `payments` counts those.
    static func charges(on card: CreditCard, after from: Date, through to: Date, _ data: AppData) -> Int {
        transactions(data).reduce(0) { sum, t in
            guard t.date > from, t.date <= to else { return sum }
            if t.kind == .move { return sum + (t.account == card.name ? t.amount : 0) }
            return sum + (t.account == card.name ? -t.amount : 0)
        }
    }

    static func payments(to card: CreditCard, after from: Date, through to: Date, _ data: AppData) -> Int {
        transactions(data).reduce(0) { sum, t in
            guard t.kind == .move, t.toAccount == card.name, t.date > from, t.date <= to else { return sum }
            return sum + t.amount
        }
    }

    /// Whether a recurring entry falls in the month of `date`. Monthly ones
    /// always do; a yearly one only in its month.
    static func recurs(_ r: Recurring, on date: Date) -> Bool {
        guard let m = r.month else { return true }
        return Calendar.current.component(.month, from: date) == m
    }

    /// How far a typed balance is from the book's figure. Booking this as an
    /// adjustment makes the two agree again.
    static func reconcile(_ wallet: Wallet, to typed: Int, _ data: AppData) -> Int {
        typed - balance(of: wallet, data)
    }

    // MARK: - Posting the schedules

    /// Everything the schedules should have posted in (postedThrough, today]:
    /// salary and bills from the Every month list, each card's payment on its
    /// due day, each instalment debit, each regular investment. Worked out day
    /// by day on a copy of the book, so a card paid on the 10th sees the rent
    /// posted to it on the 5th. Nothing before `ledgerStart` is ever posted.
    static func duePostings(_ data: AppData, through today: Date) -> [Transaction] {
        guard let start = data.ledgerStart else { return [] }
        let cal = Calendar.current
        let end = cal.startOfDay(for: today)
        var day = cal.startOfDay(for: data.postedThrough ?? cal.date(byAdding: .day, value: -1, to: start)!)
        var working = data
        var out: [Transaction] = []
        let existing = Set(transactions(data).compactMap { t in t.scheduleID.map { "\($0)@\(cal.startOfDay(for: t.date))" } })
        var guardDays = 0
        while day < end, guardDays < 800 {
            day = cal.date(byAdding: .day, value: 1, to: day)!
            guardDays += 1
            var todays: [Transaction] = []
            func post(_ t: Transaction) {
                let key = "\(t.scheduleID ?? "")@\(day)"
                guard !existing.contains(key), t.amount != 0 else { return }
                todays.append(t)
            }
            let yesterday = cal.date(byAdding: .day, value: -1, to: day)!
            for r in (working.recurring ?? []) where r.active && !r.paidBy.isEmpty
                && !scheduleDates(day: r.day, after: yesterday, through: day, shift: shift(for: r, working),
                                  where: { recurs(r, on: $0) }).isEmpty {
                post(Transaction(date: day, amount: r.isIncome ? r.amount : -r.amount,
                                 kind: r.isIncome ? .income : .spend, account: r.paidBy,
                                 merchant: r.name,
                                 category: r.isIncome ? "" : SpendingCategory.forRecurring(r.category),
                                 scheduleID: r.id, source: .recurring))
            }
            for card in working.cards {
                // The due day itself may have been a weekend: the statement
                // leaves on the business day the cycle says, so ask it.
                guard let from = card.payFrom, !from.isEmpty, BusinessCalendar.isBusinessDay(day) else { continue }
                let c = cycle(for: card, working, today: yesterday)
                guard cal.isDate(c.statementDue, inSameDayAs: day) else { continue }
                post(Transaction(date: day, amount: c.owedStatement, kind: .move, account: from,
                                 toAccount: card.name, merchant: card.name,
                                 scheduleID: card.id, source: .schedule))
            }
            for plan in installments(working) where !plan.closed {
                guard let from = plan.payFrom, !from.isEmpty else { continue }
                for k in 0..<plan.months where cal.isDate(plan.dueDate(at: k), inSameDayAs: day) {
                    post(Transaction(date: day, amount: plan.amount(at: k), kind: .move, account: from,
                                     toAccount: plan.name, merchant: plan.lender.isEmpty ? plan.name : plan.lender,
                                     scheduleID: plan.id, source: .schedule))
                }
            }
            for inv in (working.investments ?? []) where inv.monthly > 0 && !inv.paidBy.isEmpty
                && !scheduleDates(day: inv.monthlyDay, after: yesterday, through: day, shift: .later).isEmpty {
                post(Transaction(date: day, amount: inv.monthly, kind: .move, account: inv.paidBy,
                                 toAccount: inv.name, merchant: inv.provider.isEmpty ? inv.name : inv.provider,
                                 scheduleID: inv.id, source: .schedule))
            }
            if !todays.isEmpty {
                working.transactions = transactions(working) + todays
                out += todays
            }
        }
        return out
    }

    // MARK: - Spending

    struct Share: Identifiable {
        var id: String { name }
        let name: String
        let amount: Int
        let count: Int
        let colorIndex: Int
        /// The category's symbol; a shop or a place has none and is drawn by its initials.
        var symbol: String? = nil
        /// Of the period's total, filled by `spendingSummary`.
        var percent: Int = 0
    }

    /// Money spent on living inside the interval, as a positive figure.
    /// Belongings, moves between your own accounts, income and adjustments
    /// are not spending; a split counts only your share.
    static func spending(_ data: AppData, in interval: DateInterval) -> Int {
        -transactions(data).filter { interval.contains($0.date) }.reduce(0) { $0 + $1.spendingAmount }
    }

    static func spendingByCategory(_ data: AppData, in interval: DateInterval) -> [Share] {
        let cats = data.spendingCategories ?? SpendingCategory.defaults
        return grouped(data, in: interval) { $0.category.isEmpty ? "Other" : $0.category }
            .map { name, list in
                Share(name: name, amount: -list.reduce(0) { $0 + $1.spendingAmount }, count: list.count,
                      colorIndex: cats.first { $0.name == name }?.colorIndex ?? 6,
                      symbol: cats.first { $0.name == name }?.symbol)
            }
            .filter { $0.amount != 0 }
            .sorted { $0.amount > $1.amount }
    }

    static func spendingByMerchant(_ data: AppData, in interval: DateInterval) -> [Share] {
        grouped(data, in: interval) { $0.merchant.isEmpty ? "Unnamed" : $0.merchant }
            .enumerated()
            .map { i, pair in
                Share(name: pair.key, amount: -pair.value.reduce(0) { $0 + $1.spendingAmount },
                      count: pair.value.count, colorIndex: i % 7)
            }
            .filter { $0.amount != 0 }
            .sorted { $0.amount > $1.amount }
    }

    static func grouped(_ data: AppData, in interval: DateInterval,
                                by key: (Transaction) -> String) -> [String: [Transaction]] {
        Dictionary(grouping: transactions(data).filter { interval.contains($0.date) && $0.spendingAmount != 0 }, by: key)
    }

    /// What went into belongings inside the interval — shown beside Spending,
    /// never in it.
    static func belongingBuys(_ data: AppData, in interval: DateInterval) -> Int {
        -transactions(data).filter { $0.kind == .asset && interval.contains($0.date) }.reduce(0) { $0 + $1.amount }
    }

    struct MonthSpend: Identifiable {
        var id: Date { month }
        let month: Date
        let amount: Int
    }

    /// Spending month by month, oldest first, ending with this month.
    static func monthlySpending(_ data: AppData, months: Int = 6, today: Date = .now) -> [MonthSpend] {
        let cal = Calendar.current
        guard let this = cal.dateInterval(of: .month, for: today) else { return [] }
        return (0..<months).reversed().compactMap { back in
            guard let start = cal.date(byAdding: .month, value: -back, to: this.start),
                  let interval = cal.dateInterval(of: .month, for: start) else { return nil }
            return MonthSpend(month: start, amount: spending(data, in: interval))
        }
    }

    /// Transactions of one month or window, newest first — the one place a
    /// transaction list is filtered, so a list and its summary agree.
    static func transactions(_ data: AppData, in interval: DateInterval?, filter: TransactionFilter = .all,
                             search: String = "") -> [Transaction] {
        let q = searchKey(search)
        return transactions(data)
            .filter { interval?.contains($0.date) ?? true }
            .filter { t in
                switch filter {
                case .all: return true
                case .review: return t.needsReview
                case .uncategorised: return t.kind == .spend && t.category.isEmpty
                case .belongings: return t.kind == .asset
                case .split: return t.myShare != nil
                }
            }
            .filter { t in
                if q.isEmpty { return true }
                let name = searchKey(t.merchant + " " + t.note + " " + t.category)
                for n in q.numbers where !name.numbers.contains(where: { $0.contains(n) }) && !String(abs(t.amount)).contains(n) { return false }
                return q.letters.isEmpty || name.letters.contains(q.letters)
            }
            .sorted { $0.date > $1.date }
    }

    enum TransactionFilter: String, CaseIterable { case all, review, uncategorised, belongings, split }

    struct Flow {
        let income: Int
        let out: Int
        let count: Int
    }

    /// Money in and out of your accounts over the interval, moves left out:
    /// they are the same money changing pockets.
    static func flow(_ data: AppData, in interval: DateInterval) -> Flow {
        let list = transactions(data).filter { interval.contains($0.date) && $0.kind != .move && $0.kind != .adjustment }
        return Flow(income: list.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount },
                    out: -list.filter { $0.amount < 0 }.reduce(0) { $0 + $1.amount },
                    count: list.count)
    }

    /// One day of a transaction list: its rows, newest first as given, and
    /// what the day came to. Moves and corrections are left out of the total
    /// for the reason `flow` leaves them out.
    struct TransactionDay: Identifiable {
        var id: Date { day }
        let day: Date
        let rows: [Transaction]
        let total: Int
    }

    /// A filtered list cut into days, latest day first.
    static func days(_ list: [Transaction]) -> [TransactionDay] {
        let cal = Calendar.current
        return Dictionary(grouping: list) { cal.startOfDay(for: $0.date) }
            .map { day, rows in
                TransactionDay(day: day, rows: rows,
                               total: rows.filter { $0.kind != .move && $0.kind != .adjustment }.reduce(0) { $0 + $1.amount })
            }
            .sorted { $0.day > $1.day }
    }

    /// What is waiting for a category, and where it came from when it all
    /// came the same way — "3 came in from Apple Pay" says why they are
    /// there; a mix is only counted.
    struct ReviewQueue {
        let count: Int
        let source: TransactionSource?
        let uncategorised: Int
    }

    static func reviewQueue(_ data: AppData) -> ReviewQueue {
        let all = transactions(data)
        let waiting = all.filter(\.needsReview)
        let sources = Set(waiting.map(\.source))
        return ReviewQueue(count: waiting.count, source: sources.count == 1 ? sources.first : nil,
                           uncategorised: all.filter { $0.kind == .spend && $0.category.isEmpty }.count)
    }

    // MARK: - Budget by pay period

    /// The month as salary sees it: from the last payday to the day before
    /// the next. With no salary entered, the calendar month.
    static func payPeriod(_ data: AppData, today: Date = .now) -> DateInterval {
        let cal = Calendar.current
        guard let s = salary(data) else { return cal.dateInterval(of: .month, for: today)! }
        let start = latest(day: s.day, onOrBefore: cal.startOfDay(for: today))
        let end = next(day: s.day, after: start)
        return DateInterval(start: start, end: end)
    }

    struct BudgetStatus {
        struct Line: Identifiable {
            var id: String { category }
            let category: String
            let limit: Int
            let spent: Int
            let colorIndex: Int
            var left: Int { limit - spent }
            var fraction: Double { limit > 0 ? min(1, Double(spent) / Double(limit)) : 0 }
        }
        let period: DateInterval
        let lines: [Line]
        let dayOfPeriod: Int
        let daysInPeriod: Int
        /// Spending in categories that have no budget line (rent, subscriptions).
        let unbudgeted: Int
        var limit: Int { lines.reduce(0) { $0 + $1.limit } }
        var spent: Int { lines.reduce(0) { $0 + $1.spent } }
        var left: Int { limit - spent }
        var daysLeft: Int { max(1, daysInPeriod - dayOfPeriod + 1) }
        var perDay: Int { max(0, left) / daysLeft }
    }

    static func budget(_ data: AppData, today: Date = .now) -> BudgetStatus {
        let cal = Calendar.current
        let period = payPeriod(data, today: today)
        let byCat = Dictionary(uniqueKeysWithValues: spendingByCategory(data, in: period).map { ($0.name, $0) })
        let cats = data.spendingCategories ?? SpendingCategory.defaults
        let lines = (data.budgets ?? []).map { b in
            BudgetStatus.Line(category: b.category, limit: b.limit, spent: byCat[b.category]?.amount ?? 0,
                              colorIndex: cats.first { $0.name == b.category }?.colorIndex ?? 6)
        }
        let budgeted = Set(lines.map(\.category))
        let unbudgeted = byCat.values.filter { !budgeted.contains($0.name) }.reduce(0) { $0 + $1.amount }
        let days = cal.dateComponents([.day], from: period.start, to: period.end).day ?? 30
        let dayOf = (cal.dateComponents([.day], from: period.start, to: cal.startOfDay(for: today)).day ?? 0) + 1
        return BudgetStatus(period: period, lines: lines, dayOfPeriod: dayOf, daysInPeriod: days, unbudgeted: unbudgeted)
    }

    // MARK: - Goals

    /// What a goal needs put aside each month to be met on its date. An
    /// open-ended goal asks for nothing in particular.
    static func monthlySetAside(_ goal: Goal, today: Date = .now) -> Int {
        guard let due = goal.due else { return 0 }
        let left = max(0, goal.target - goal.saved)
        let months = max(1, Calendar.current.dateComponents([.month], from: today, to: due).month ?? 1)
        return (left + months - 1) / months
    }

    static func goalsMonthly(_ data: AppData, today: Date = .now) -> Int {
        (data.goals ?? []).reduce(0) { $0 + monthlySetAside($1, today: today) }
    }

    static func goalsSaved(_ data: AppData) -> Int { (data.goals ?? []).reduce(0) { $0 + $1.saved } }
    /// What every goal is aiming for, together: "saved so far … of ¥X".
    static func goalsTarget(_ data: AppData) -> Int { (data.goals ?? []).reduce(0) { $0 + $1.target } }

    // MARK: - Belongings

    /// Whole months between two days, at least one once a month has begun.
    static func monthsHeld(from start: Date, to end: Date) -> Int {
        max(0, Calendar.current.dateComponents([.month], from: start, to: end).month ?? 0)
    }

    /// What a belonging really costs: what was paid less what it would fetch
    /// (or fetched), spread over the months it was owned. nil in its first
    /// month, when there is nothing to spread yet.
    static func realCostPerMonth(_ item: Item, today: Date = .now) -> Int? {
        let end = item.sale?.date ?? today
        let months = monthsHeld(from: item.boughtOn, to: end)
        guard months >= 1 else { return nil }
        let back = item.sale?.net ?? item.estimatedPrice
        return (item.buyPrice - back) / months
    }

    /// Everything still owned, costing this much a month between them.
    static func belongingsMonthlyCost(_ data: AppData, today: Date = .now) -> Int {
        unsold(data).compactMap { realCostPerMonth($0, today: today) }.reduce(0, +)
    }

    /// Points earned buying what is still owned, kept or not. Reported, never added.
    static func pointsOnBelongings(_ data: AppData) -> Int { unsold(data).reduce(0) { $0 + $1.pointsEarned } }

    static func belongingsPaid(_ data: AppData) -> Int { unsold(data).reduce(0) { $0 + $1.buyPrice } }
    static func belongingsWorth(_ data: AppData) -> Int { unsold(data).reduce(0) { $0 + $1.estimatedPrice } }

    // MARK: - Subscriptions

    /// Subscriptions on the Every month list, soonest renewal first.
    // MARK: - Recurring, all of it

    /// What a fixed item is to the person paying it: money in, a bill that
    /// has to be paid, or a subscription that could be cancelled.
    enum RecurringKind: String, CaseIterable { case bill, subscription, income }

    static func kind(of r: Recurring) -> RecurringKind {
        if r.isIncome { return .income }
        return r.category == "subscription" ? .subscription : .bill
    }

    /// One fixed item on its day in a month.
    struct RecurringDue: Identifiable {
        let recurring: Recurring
        let date: Date
        let kind: RecurringKind
        /// Its day has come: posted, or due today.
        let done: Bool
        var id: String { recurring.id }
        /// Signed as it moves the money: income in, the rest out.
        var amount: Int { kind == .income ? recurring.amount : -recurring.amount }
    }

    /// Every active fixed item that falls in `month`, by date: monthly ones on
    /// their day (the 31st on a short month's last day), yearly ones only in
    /// their month. Paused ones are left out — they move no money.
    static func recurringDue(_ data: AppData, month: Date, today: Date = .now) -> [RecurringDue] {
        let start = Calendar.current.startOfDay(for: today)
        return (data.recurring ?? []).filter { $0.active && recurs($0, on: month) }
            .map { r in
                let d = date(day: r.day, in: month)
                return RecurringDue(recurring: r, date: d, kind: kind(of: r), done: d <= start)
            }
            .sorted { ($0.date, $0.recurring.name) < ($1.date, $1.recurring.name) }
    }

    /// The month's fixed items added up the way the Recurring page shows them.
    struct RecurringTotals: Equatable {
        var income = 0, bills = 0, subscriptions = 0
        /// Bills and subscriptions whose day has not come yet.
        var stillToPay = 0
        /// Income whose day has not come yet.
        var stillToCome = 0
        /// Items of any kind still to come, and what the ones gone by took.
        var leftCount = 0
        var paid = 0
    }

    static func recurringTotals(_ due: [RecurringDue]) -> RecurringTotals {
        var t = RecurringTotals()
        for d in due {
            switch d.kind {
            case .income: t.income += d.recurring.amount
            case .bill: t.bills += d.recurring.amount
            case .subscription: t.subscriptions += d.recurring.amount
            }
            if d.kind != .income && !d.done { t.stillToPay += d.recurring.amount }
            if d.kind != .income && d.done { t.paid += d.recurring.amount }
            if d.kind == .income && !d.done { t.stillToCome += d.recurring.amount }
            if !d.done { t.leftCount += 1 }
        }
        return t
    }

    /// Income landing on each day of the month, for the calendar's labels.
    static func recurringIncomeByDay(_ due: [RecurringDue]) -> [Int: Int] {
        due.filter { $0.kind == .income }
            .reduce(into: [:]) { $0[Calendar.current.component(.day, from: $1.date), default: 0] += $1.recurring.amount }
    }

    static func subscriptions(_ data: AppData) -> [Recurring] {
        (data.recurring ?? []).filter { $0.active && !$0.isIncome && $0.category == "subscription" }
    }

    /// What one costs a month: a yearly one spread over twelve.
    static func monthlyEquivalent(_ r: Recurring) -> Int { r.month == nil ? r.amount : r.amount / 12 }

    static func subscriptionsMonthly(_ data: AppData) -> Int {
        subscriptions(data).reduce(0) { $0 + monthlyEquivalent($1) }
    }

    /// The next day a recurring entry lands, yearly ones in their month.
    static func nextOccurrence(_ r: Recurring, after today: Date) -> Date {
        var d = next(day: r.day, after: Calendar.current.startOfDay(for: today))
        var tries = 0
        while !recurs(r, on: d), tries < 13 { d = next(day: r.day, after: d); tries += 1 }
        return d
    }

    // MARK: - Investments

    static func investmentsValue(_ data: AppData) -> Int { (data.investments ?? []).reduce(0) { $0 + $1.value } }
    static func investmentsContributed(_ data: AppData) -> Int { (data.investments ?? []).reduce(0) { $0 + $1.contributed } }
    /// NISA: ¥3,600,000 a year (1.2M つみたて + 2.4M 成長), ¥18,000,000 over a lifetime.
    static let nisaYearly = 3_600_000
    static let nisaLifetime = 18_000_000
    static func nisaUsedThisYear(_ data: AppData) -> Int {
        (data.investments ?? []).filter { $0.kind == "tsumitate" || $0.kind == "growth" }.reduce(0) { $0 + $1.contributedThisYear }
    }
    static func nisaUsedLifetime(_ data: AppData) -> Int {
        (data.investments ?? []).filter { $0.kind == "tsumitate" || $0.kind == "growth" }.reduce(0) { $0 + $1.contributed }
    }

    // MARK: - People

    /// Split bills and loans in yen, owed to you and by you.
    static func owedToYou(_ data: AppData) -> Int { loansOwedToYou(data) }
    static func youOwe(_ data: AppData) -> Int { loansYouOwe(data) }

    // MARK: - Rules and places

    /// The rule that fills in a transaction for this shop or this place: a
    /// place rule within its radius first, then the first shop rule whose
    /// words are in the merchant's name.
    static func rule(for merchant: String, latitude: Double? = nil, longitude: Double? = nil,
                     _ data: AppData) -> Rule? {
        let rules = data.rules ?? []
        if let lat = latitude, let lon = longitude {
            if let r = rules.first(where: { r in
                guard let rl = r.latitude, let ro = r.longitude else { return false }
                return distance(lat, lon, rl, ro) <= r.radius
            }) { return r }
        }
        let name = searchKey(merchant).letters
        guard !name.isEmpty else { return nil }
        return rules.first { r in
            let k = searchKey(r.contains).letters
            return !k.isEmpty && name.contains(k)
        }
    }

    /// A place the user has saved spending at before, near a point: the
    /// merchant, how many times, and what it usually costs. No map lookup —
    /// the book's own transactions are the only map.
    struct Place {
        let merchant: String
        let visits: Int
        let usualAmount: Int
        let category: String
        let account: String
    }

    /// A name for a spot from the book alone: a name already kept for a
    /// spend within `radius`, nearest first; otherwise the shop most often
    /// paid there. nil when nothing was ever saved near it.
    enum PlaceNameSource: Equatable { case saved, nearShop, maps }
    struct PlaceName: Equatable {
        let name: String
        let source: PlaceNameSource
    }

    static func placeName(near latitude: Double, _ longitude: Double, within radius: Double = 80,
                          _ data: AppData) -> PlaceName? {
        let named = transactions(data).compactMap { t -> (Double, String)? in
            guard let n = t.placeName, !n.isEmpty, let a = t.latitude, let o = t.longitude else { return nil }
            let d = distance(latitude, longitude, a, o)
            return d <= radius ? (d, n) : nil
        }
        if let nearest = named.min(by: { $0.0 < $1.0 }) { return PlaceName(name: nearest.1, source: .saved) }
        if let shop = place(near: latitude, longitude, within: radius, data) { return PlaceName(name: shop.merchant, source: .nearShop) }
        return nil
    }

    static func place(near latitude: Double, _ longitude: Double, within radius: Double = 80,
                      _ data: AppData) -> Place? {
        let near = transactions(data).filter { t in
            guard t.kind == .spend, let a = t.latitude, let o = t.longitude else { return false }
            return distance(latitude, longitude, a, o) <= radius
        }
        guard let top = Dictionary(grouping: near, by: \.merchant).max(by: { $0.value.count < $1.value.count }),
              !top.key.isEmpty else { return nil }
        let recent = top.value.sorted { $0.date > $1.date }
        let amounts = Dictionary(grouping: recent.prefix(12), by: \.amount).max { $0.value.count < $1.value.count }?.key ?? recent[0].amount
        return Place(merchant: top.key, visits: top.value.count, usualAmount: -amounts,
                     category: recent[0].category, account: recent[0].account)
    }

    /// Metres between two points, near enough for "the same shop".
    static func distance(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180, dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }

    // MARK: - Foreign currency

    /// A foreign amount in the book's currency at the rate the user typed.
    static func convert(_ foreign: Double, rate: Double) -> Int {
        guard rate > 0 else { return 0 }
        return Int((foreign / rate).rounded())
    }
}

// MARK: - Fixed money in the pay period

extension Finance {
    /// What Budget's Fixed card lists: the bills that fall in the pay period
    /// one by one, and the subscriptions together.
    struct FixedInPeriod {
        let bills: [RecurringDue]
        let subscriptions: Int
        let subscriptionCount: Int
        /// Every subscription's day in the period has come.
        let subscriptionsDone: Bool
    }

    static func fixedInPayPeriod(_ data: AppData, today: Date = .now) -> FixedInPeriod {
        let cal = Calendar.current
        let period = payPeriod(data, today: today)
        // A pay period spans two calendar months; each is asked for its items.
        var months: [Date] = []
        var m = cal.dateInterval(of: .month, for: period.start)!.start
        while m < period.end { months.append(m); m = cal.date(byAdding: .month, value: 1, to: m)! }
        let due = months.flatMap { recurringDue(data, month: $0, today: today) }.filter { period.contains($0.date) }
        let subs = due.filter { $0.kind == .subscription }
        return FixedInPeriod(bills: due.filter { $0.kind == .bill },
                             subscriptions: subs.reduce(0) { $0 + $1.recurring.amount },
                             subscriptionCount: subs.count, subscriptionsDone: subs.allSatisfy(\.done))
    }
}
