import Foundation

/// The calculation engine: pure functions over `AppData` and a date, so every
/// figure on screen can be checked in a test with a made-up book. `Store`
/// wraps these for the views; nothing here reads the clock or the disk.
///
/// Four questions, four separate answers. Folding them into one number is what
/// made the old headline mislead — a sixty-month plan is owed, but it is not
/// owed on Friday.
///
///   cashNow          what is in the wallets today
///   safeToSpend      cash after what must be paid before a horizon
///   monthlyCashFlow  is the book richer or poorer than last month
///   netWorth         assets − liabilities, if everything were sold and settled
///
/// Rules that keep one yen from being counted twice:
///   • A card-paid bill (rent on Saison) is never a cash event on its own day.
///     It is part of that card's next statement; cash leaves on the due day.
///   • Something bought on a card to sell again is inventory (asset) and an unbilled charge
///     (liability) at once. Net worth moves only by its expected margin.
///   • An instalment debit is debt going down plus its slice of 分割手数料.
///     Only the fee is a cost; the rest was already owed.
///   • Nothing here changes a balance. Wallets and statements are typed.
enum Finance {

    // MARK: - Cash

    /// Every wallet is cash. Points are not.
    static func cashNow(_ data: AppData) -> Int {
        data.wallets.reduce(0) { $0 + $1.balance }
    }

    // MARK: - Items

    static func channel(named name: String, _ data: AppData) -> SalesChannel? {
        data.channels.first { $0.name == name }
    }

    /// What postage this item is expected to cost.
    static func shipping(_ item: Item, _ data: AppData) -> Int {
        item.shippingFee ?? data.defaultShippingFee
    }

    /// The marketplace's cut alone, before postage.
    static func commission(_ item: Item, channelName: String, price: Int? = nil, _ data: AppData) -> Int {
        guard let ch = channel(named: channelName, data), !ch.isPoints else { return 0 }
        return Int(Double(price ?? item.estimatedPrice) * (ch.rate / 100))
    }

    /// What a sale of `item` through `channelName` actually puts in a wallet
    /// (or in points, for a point channel).
    ///
    /// On a cash channel postage comes out of the payout, the way Mercari and
    /// Rakuma actually settle. A point channel credits its points in full and
    /// the postage is booked separately as cash leaving a wallet, because
    /// points and yen are not the same pocket.
    static func netProceeds(_ item: Item, channelName: String, price: Int? = nil, _ data: AppData) -> Int {
        let listed = price ?? item.estimatedPrice
        guard let ch = channel(named: channelName, data) else { return listed }
        if ch.isPoints {
            let rate = item.pointRateOverride ?? ch.rate
            return Int(Double(listed) * (1 + rate / 100))
        }
        return Int(Double(listed) * (1 - ch.rate / 100)) - shipping(item, data)
    }

    /// What the sale leaves in cash once the item's own cost is counted.
    ///
    /// A point sale earns no yen: the credit is points, so the cash side is the
    /// purchase and the postage going out and nothing coming back. That reads
    /// as a loss, and it is one — the trade is only worth it once the points
    /// beside it are counted, which is exactly why they are reported on their
    /// own rather than folded in here.
    static func expectedProfit(_ item: Item, channelName: String, price: Int? = nil, _ data: AppData) -> Int {
        let postage = shipping(item, data)
        guard channel(named: channelName, data)?.isPoints != true else {
            return -item.buyPrice - postage
        }
        return netProceeds(item, channelName: channelName, price: price, data) - item.buyPrice
    }

    /// The points that same sale would credit — nothing on a cash channel.
    static func expectedPoints(_ item: Item, channelName: String, price: Int? = nil, _ data: AppData) -> Int {
        guard channel(named: channelName, data)?.isPoints == true else { return 0 }
        return netProceeds(item, channelName: channelName, price: price, data)
    }

    /// Revenue − cost − fee − postage, as recorded when the sale was confirmed.
    /// nil while the item is unsold.
    static func realizedProfit(_ item: Item) -> Int? {
        guard let sale = item.sale else { return nil }
        return sale.net - item.buyPrice
    }

    static func unsold(_ data: AppData) -> [Item] { data.items.filter { !$0.isSold } }
    static func forSale(_ data: AppData) -> [Item] { unsold(data).filter { !$0.keep } }

    /// True when an item's planned channel pays in points rather than yen — a
    /// MapCamera trade-in counter, not Mercari.
    static func sellsForPoints(_ item: Item, _ data: AppData) -> Bool {
        channel(named: item.plannedChannel, data)?.isPoints == true
    }

    /// Cash if every item marked for sale sold at its estimate through its
    /// planned channel. Items marked "keep" are excluded, and so is anything
    /// planned for a point channel: that sale pays no yen at all. Its points
    /// are `pointsFromSelling`, reported beside this figure and never inside
    /// it — added in, they would show up in net worth as money.
    static func liquidation(_ data: AppData) -> Int {
        forSale(data)
            .filter { !sellsForPoints($0, data) }
            .reduce(0) { $0 + netProceeds($1, channelName: $1.plannedChannel, data) }
    }

    /// Points the stock would pay back if it all sold through its planned
    /// channel. Only a point channel pays in points; everything planned for a
    /// cash channel contributes nothing here.
    static func pointsFromSelling(_ data: AppData) -> Int {
        forSale(data)
            .filter { sellsForPoints($0, data) }
            .reduce(0) { $0 + netProceeds($1, channelName: $1.plannedChannel, data) }
    }

    static func inventoryCost(_ data: AppData) -> Int {
        forSale(data).reduce(0) { $0 + $1.buyPrice }
    }

    /// Margin still to be made on what is unsold.
    static func unrealizedProfit(_ data: AppData) -> Int {
        forSale(data).reduce(0) { $0 + expectedProfit($1, channelName: $1.plannedChannel, data) }
    }

    /// Points a purchase earned back (PayPay, Rakuten, MapCamera). Never cash:
    /// they sit in a point wallet the user types by hand, so they are reported
    /// beside the cash figures, never added to them. Counted on the day the
    /// item was bought, which is when the points landed.
    static func pointsEarned(_ data: AppData, in interval: DateInterval) -> Int {
        data.items.filter { interval.contains($0.boughtOn) }.reduce(0) { $0 + $1.pointsEarned }
    }

    /// Points earned on stock that has not sold yet.
    static func pointsOnStock(_ data: AppData) -> Int {
        forSale(data).reduce(0) { $0 + $1.pointsEarned }
    }

    /// Points sitting in point wallets. Never cash, and never added to it.
    static func pointsHeld(_ data: AppData) -> Int {
        data.pointWallets.reduce(0) { $0 + $1.points }
    }

    /// What the cards say they owe, added up exactly as the Wallet rows show
    /// it: the statement figure typed in against each card. `cardDebt` differs
    /// — it drops a statement whose due day has already passed on a card with a
    /// known closing day, which is right for net worth and wrong for a total
    /// that has to equal the rows above it.
    static func typedCardDebt(_ data: AppData) -> Int {
        data.cards.reduce(0) { $0 + $1.debt }
    }

    /// What the monthly commitments come to, in and out, however they are paid.
    /// Paused entries are left out: nothing leaves for them.
    static func monthlyCommitments(_ data: AppData) -> (income: Int, bills: Int) {
        let active = (data.recurring ?? []).filter(\.active)
        return (active.filter(\.isIncome).reduce(0) { $0 + $1.amount },
                active.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount })
    }

    /// Profit on sales confirmed inside the interval.
    static func realizedSalesProfit(_ data: AppData, in interval: DateInterval) -> Int {
        data.items.compactMap { item -> Int? in
            guard let sale = item.sale, interval.contains(sale.date) else { return nil }
            return realizedProfit(item)
        }.reduce(0, +)
    }

    /// The resale side as it stands today, as Overview asks for it: sell the
    /// stock, and what selling has made this month. Cost, margin, points and
    /// what is still on a card are read one screen down — Inventory has them
    /// above its list, Stats has them per month — so they are not bundled here
    /// only to be laid out in a row.
    struct ResaleBusiness {
        var liquidation: Int
        var realizedThisMonth: Int
        var unsoldCount: Int
    }

    static func resaleBusiness(_ data: AppData, today: Date = .now) -> ResaleBusiness {
        let month = Calendar.current.dateInterval(of: .month, for: today)!
        return ResaleBusiness(
            liquidation: liquidation(data),
            realizedThisMonth: realizedSalesProfit(data, in: month),
            unsoldCount: forSale(data).count)
    }

    // MARK: - History

    /// One month of the past, as far as the book can say.
    ///
    /// `cash` and `netWorth` come from that month's `CashSnapshot` and are nil
    /// for a month the app was not installed for — the balances are typed, so
    /// there is no way to reconstruct them after the fact. Profit, points and
    /// the sale count are worked out from the items and are always known.
    struct MonthPoint: Identifiable {
        var id: Date { month }
        /// The first day of the month.
        let month: Date
        let cash: Int?
        let netWorth: Int?
        /// Profit on sales confirmed inside the month.
        let profit: Int
        /// Points the month's purchases paid back.
        let points: Int
        let soldCount: Int
    }

    /// The last `months` months, oldest first, ending with the one `today`
    /// falls in. A month with no snapshot still reports its profit and points:
    /// a gap in the balance history is not a gap in the sales history.
    static func history(_ data: AppData, months: Int = 12, today: Date = .now) -> [MonthPoint] {
        let cal = Calendar.current
        guard months > 0, let thisMonth = cal.dateInterval(of: .month, for: today) else { return [] }
        let snaps = data.snapshots ?? []
        return (0..<months).reversed().compactMap { back in
            guard let start = cal.date(byAdding: .month, value: -back, to: thisMonth.start),
                  let interval = cal.dateInterval(of: .month, for: start) else { return nil }
            // The last snapshot of the month, not the first: a book restored
            // mid-month can hold two, and the later one is the truer reading.
            let snap = snaps.filter { cal.isDate($0.date, equalTo: start, toGranularity: .month) }
                .max { $0.date < $1.date }
            return MonthPoint(month: start,
                              cash: snap?.cash,
                              netWorth: snap?.netWorth,
                              profit: realizedSalesProfit(data, in: interval),
                              points: pointsEarned(data, in: interval),
                              soldCount: data.items.filter { $0.sale.map { interval.contains($0.date) } ?? false }.count)
        }
    }

    /// A window the backward-looking screens report on: one month, one whole
    /// year, or everything the book holds.
    ///
    /// The raw value is what a picker compares and what could be stored, so it
    /// stays these ASCII shapes whatever language the app is showing.
    enum Period: Hashable {
        case all
        case year(Int)
        case month(year: Int, month: Int)

        var id: String {
            switch self {
            case .all: return "all"
            case .year(let y): return "y\(y)"
            case .month(let y, let m): return "m\(y)-\(m)"
            }
        }

        static func from(id: String) -> Period? {
            if id == "all" { return .all }
            if id.hasPrefix("y"), let y = Int(id.dropFirst()) { return .year(y) }
            if id.hasPrefix("m") {
                let parts = id.dropFirst().split(separator: "-")
                if parts.count == 2, let y = Int(parts[0]), let m = Int(parts[1]) {
                    return .month(year: y, month: m)
                }
            }
            return nil
        }

        /// nil for `.all`, which has no bounds — a caller that needs an
        /// interval treats nil as "no filtering".
        var interval: DateInterval? {
            let cal = Calendar.current
            switch self {
            case .all:
                return nil
            case .year(let y):
                guard let start = cal.date(from: DateComponents(year: y, month: 1, day: 1)),
                      let end = cal.date(from: DateComponents(year: y + 1, month: 1, day: 1)) else { return nil }
                return DateInterval(start: start, end: end)
            case .month(let y, let m):
                guard let start = cal.date(from: DateComponents(year: y, month: m, day: 1)),
                      let end = cal.date(byAdding: .month, value: 1, to: start) else { return nil }
                return DateInterval(start: start, end: end)
            }
        }

        /// The first day of the window, for naming it on screen.
        var start: Date? { interval?.start }

        func contains(_ date: Date) -> Bool { interval?.contains(date) ?? true }
    }

    /// Selling over a period. `.all` reports the whole book.
    struct PeriodSummary {
        let period: Period
        let soldCount: Int
        /// What the sales actually paid, after fees and postage.
        let revenue: Int
        let profit: Int
        /// Points the period's *purchases* paid back — counted on the buy
        /// date, so this fills up whether or not anything sold.
        let points: Int
        /// Days from purchase to sale, averaged over the period's sales.
        let averageDaysHeld: Int?
    }

    static func summary(_ data: AppData, for period: Period) -> PeriodSummary {
        let sold = data.items.filter { $0.sale.map { period.contains($0.date) } ?? false }
        let held = sold.compactMap { daysHeld($0) }
        let bought = data.items.filter { period.contains($0.boughtOn) }
        return PeriodSummary(period: period,
                             soldCount: sold.count,
                             revenue: sold.reduce(0) { $0 + ($1.sale?.net ?? 0) },
                             profit: sold.reduce(0) { $0 + (realizedProfit($1) ?? 0) },
                             points: bought.reduce(0) { $0 + $1.pointsEarned },
                             averageDaysHeld: held.isEmpty ? nil : held.reduce(0, +) / held.count)
    }

    /// How long an item sat before it sold. nil while it is unsold — there is
    /// no answer yet, which is different from zero days.
    static func daysHeld(_ item: Item) -> Int? {
        guard let sale = item.sale else { return nil }
        return Calendar.current.dateComponents([.day], from: item.boughtOn, to: sale.date).day
    }

    // MARK: - Browsing the inventory

    /// Which items a list is about.
    enum ItemStatus: String, CaseIterable { case forSale, keeping, sold, all }

    /// How the list is ordered. `fastest` and `slowest` only mean anything for
    /// something that has sold, so unsold items sink to the bottom under them
    /// rather than being dropped — the filter decides what is in the list, the
    /// sort only decides the order.
    enum ItemSort: String, CaseIterable {
        case newest, oldest, priceHigh, priceLow, profitHigh, profitLow, points, fastest, slowest
    }

    /// The date a list is ordered and filtered by: when it sold if it has, and
    /// when it was bought if it has not. "What did I sell in September" and
    /// "what did I buy in September" are the same question asked of the two
    /// halves of the book.
    static func listDate(_ item: Item) -> Date { item.sale?.date ?? item.boughtOn }

    /// The figure a list shows against an item: what it fetched if it sold,
    /// what it should fetch if it has not.
    static func listPrice(_ item: Item) -> Int { item.sale?.price ?? item.estimatedPrice }

    /// The inventory as a screen reads it: filtered by status, period and
    /// typed name, then ordered. One function, so the list and anything
    /// summarising it can never disagree about which items are in view.
    /// An empty `search` matches everything; the order is the chosen one
    /// either way, so searching narrows the list without reshuffling it.
    static func items(_ data: AppData, status: ItemStatus, period: Period, sort: ItemSort,
                      search: String = "") -> [Item] {
        let byStatus = data.items.filter { item in
            switch status {
            case .forSale: return !item.isSold && !item.keep
            case .keeping: return !item.isSold && item.keep
            case .sold: return item.isSold
            case .all: return true
            }
        }
        let inPeriod = byStatus.filter { period.contains(listDate($0)) }
        let found = inPeriod.filter { matches($0, search: search) }
        return found.sorted { a, b in
            switch sort {
            case .newest: return listDate(a) > listDate(b)
            case .oldest: return listDate(a) < listDate(b)
            case .priceHigh: return listPrice(a) > listPrice(b)
            case .priceLow: return listPrice(a) < listPrice(b)
            case .profitHigh: return profit(a, data) > profit(b, data)
            case .profitLow: return profit(a, data) < profit(b, data)
            case .points: return a.pointsEarned > b.pointsEarned
            case .fastest, .slowest:
                // Unsold last under either, and a stable order among them.
                switch (daysHeld(a), daysHeld(b)) {
                case let (x?, y?): return sort == .fastest ? x < y : x > y
                case (nil, _?): return false
                case (_?, nil): return true
                case (nil, nil): return listDate(a) > listDate(b)
                }
            }
        }
    }

    /// What an item made, or is expected to make, in cash — the figure the
    /// profit sorts use, so the order matches the number on the row.
    static func profit(_ item: Item, _ data: AppData) -> Int {
        realizedProfit(item) ?? expectedProfit(item, channelName: item.plannedChannel, data)
    }

    // MARK: - Searching by name

    /// What a name and a query are both reduced to before they are compared:
    /// lowercase, diacritics and full-width forms folded, everything that is
    /// not a letter or a digit dropped, then split where letters meet digits.
    /// "200mm F/2.8", "200mm f2.8" and "200mmf2.8" all come out as the letters
    /// "mmf" and the numbers ["200", "28"] — which is why any of them finds
    /// the others.
    struct SearchKey {
        /// Every letter in order, with the gaps closed up.
        var letters = ""
        /// Each run of digits in order. On camera gear this is the part that
        /// identifies the thing: 200, 28, 5d, a7.
        var numbers: [String] = []
        var isEmpty: Bool { letters.isEmpty && numbers.isEmpty }
    }

    static func searchKey(_ text: String) -> SearchKey {
        // Punctuation goes before the split, not at it, so "f/2.8" and "f28"
        // both read as one number: nobody types the dot the same way twice.
        let flat = text
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                     locale: Locale(identifier: "en_US_POSIX"))
            .filter { $0.isLetter || $0.isNumber }
        var key = SearchKey()
        var digits = ""
        for ch in flat {
            if ch.isNumber {
                digits.append(ch)
            } else {
                if !digits.isEmpty { key.numbers.append(digits); digits = "" }
                key.letters.append(ch)
            }
        }
        if !digits.isEmpty { key.numbers.append(digits) }
        return key
    }

    /// How many of `typed`'s letters appear in `name`, in order — the
    /// forgiving half of the match, and the reason "mm" typed into a name
    /// that never had one is not fatal.
    private static func overlap(_ typed: String, _ name: String) -> Int {
        var rest = Substring(name)
        var hits = 0
        for ch in typed where !rest.isEmpty {
            if let i = rest.firstIndex(of: ch) {
                hits += 1
                rest = rest[rest.index(after: i)...]
            }
        }
        return hits
    }

    /// Does this item's name answer the query? Numbers anchor the match:
    /// every number typed has to appear inside a number in the name, so a
    /// "200" never turns up a 24-70. Letters are the hint on top of it.
    ///
    /// A typed number is a commitment, typed letters are not. With no number
    /// to anchor on, every letter has to be in the name in order — the
    /// ordinary "type the start of it" search. With a number, half the letters
    /// will do, which is what makes "200mmf2.8" find "200 f2.8": the "mm" is
    /// missing from the name and the brand is missing from the query, and
    /// nobody writes a lens down the same way twice.
    static func matches(_ item: Item, search: String) -> Bool {
        let q = searchKey(search)
        if q.isEmpty { return true }
        let name = searchKey(item.name)
        for n in q.numbers where !name.numbers.contains(where: { $0.contains(n) }) { return false }
        if q.letters.isEmpty { return true }
        let hits = overlap(q.letters, name.letters)
        return q.numbers.isEmpty ? hits == q.letters.count : hits * 2 >= q.letters.count
    }

    /// The months the book has anything in, newest first, so a month picker
    /// offers only months with something to show.
    static func monthsWithActivity(_ data: AppData, today: Date = .now) -> [Period] {
        let cal = Calendar.current
        var starts = Set<Date>()
        if let thisMonth = cal.dateInterval(of: .month, for: today)?.start { starts.insert(thisMonth) }
        for item in data.items {
            for date in [item.boughtOn, item.sale?.date].compactMap({ $0 }) {
                if let start = cal.dateInterval(of: .month, for: date)?.start { starts.insert(start) }
            }
        }
        return starts.sorted(by: >).compactMap { start in
            let c = cal.dateComponents([.year, .month], from: start)
            guard let y = c.year, let m = c.month else { return nil }
            return .month(year: y, month: m)
        }
    }

    /// The years the book has anything in, newest first. The picker offers only
    /// these: a year with no purchase and no sale has nothing to show, and this
    /// year is always offered so a fresh book still has something to land on.
    static func yearsWithActivity(_ data: AppData, today: Date = .now) -> [Int] {
        let cal = Calendar.current
        var years = Set([cal.component(.year, from: today)])
        for item in data.items {
            years.insert(cal.component(.year, from: item.boughtOn))
            if let sale = item.sale { years.insert(cal.component(.year, from: sale.date)) }
        }
        return years.sorted(by: >)
    }

    // MARK: - Cards

    /// Where a card is in its month. The typed `debt` is the statement that
    /// closed at `lastClosing` and is paid on `statementDue`; everything since
    /// is unbilled and lands on the statement after.
    struct CardCycle {
        let card: CreditCard
        let previousClosing: Date
        let lastClosing: Date
        let nextClosing: Date
        /// When the typed statement is paid. In the past when it already was.
        let statementDue: Date
        /// When the charges since `lastClosing` are paid.
        let unbilledDue: Date
        /// Stock cost charged in (previousClosing, lastClosing] — inside `debt`.
        let statementStockCost: Int
        /// Stock cost charged after `lastClosing` — on no statement yet.
        let unbilledStockCost: Int
        /// Card-paid bills that fell in (previousClosing, lastClosing].
        let statementBills: Int
        /// Card-paid bills that fell in (lastClosing, today].
        let unbilledBills: Int
        /// Card-paid bills still to fall in (today, nextClosing].
        let comingBills: Int
        /// Card-paid bills over a whole month, for cycles further out.
        let monthlyBills: Int
        /// Whether the typed statement is still owed or already paid.
        let statementOpen: Bool

        /// What the statement holds that is neither stock nor a bill you
        /// listed: groceries, trains, the rest of life. The book cannot see
        /// those, so it reads them off the statement and assumes next month
        /// looks the same.
        var livingEstimate: Int { max(0, card.debt - statementStockCost - statementBills) }
        /// Charged, not yet on a statement. A liability today.
        var unbilled: Int { unbilledStockCost + unbilledBills }
        /// The statement after the current one, as far as the book can tell.
        var projectedNext: Int { unbilled + comingBills + livingEstimate }
        /// Statements further out: bills and living only — no stock is assumed.
        var projectedSteady: Int { monthlyBills + livingEstimate }
        /// Typed debt while it is still owed; zero once its due day has passed.
        var owedStatement: Int { statementOpen ? card.debt : 0 }
    }

    static func cycle(for card: CreditCard, _ data: AppData, today: Date = .now) -> CardCycle {
        let cal = Calendar.current
        let day = cal.startOfDay(for: today)
        let last: Date, prev: Date, next: Date
        if let c = card.closingDay {
            last = latest(day: c, onOrBefore: day)
            prev = cal.date(byAdding: .month, value: -1, to: last)!
            next = cal.date(byAdding: .month, value: 1, to: last)!
        } else {
            // No closing day: the book cannot tell billed from unbilled, so it
            // treats the typed figure as everything charged up to today. The
            // "statement" therefore closes today, which makes both unbilled
            // windows below empty on their own — anything already charged is
            // inside `debt`, and counting it again was double-counting every
            // card-paid bill (a rent on the 5th appeared in the typed figure
            // *and* as an unbilled charge).
            last = day
            prev = cal.date(byAdding: .month, value: -1, to: day)!
            next = cal.date(byAdding: .month, value: 1, to: day)!
        }
        // With a known closing day the due date is fixed by the calendar and
        // can be in the past, meaning the typed figure was paid. Without one
        // the statement closed today, so its due day is always still ahead.
        let statementDue = self.next(day: card.dueDay, after: last)
        // The unbilled charges are paid one due day after the statement, and
        // never on the same day as it: if the statement slipped a month above,
        // they slip with it.
        let unbilledDue = self.next(day: card.dueDay, after: max(next, statementDue))

        let charged = data.items.filter { $0.cardName == card.name }
        let inStatement = charged.filter { $0.boughtOn > prev && $0.boughtOn <= last }.reduce(0) { $0 + $1.buyPrice }
        let unbilledCost = charged.filter { $0.boughtOn > last && $0.boughtOn <= today }.reduce(0) { $0 + $1.buyPrice }

        let bills = (data.recurring ?? []).filter { $0.active && !$0.isIncome && $0.paidBy == card.name }
        func billsFalling(after from: Date, through to: Date) -> Int {
            bills.reduce(0) { $0 + $1.amount * occurrences(day: $1.day, after: from, through: to) }
        }
        return CardCycle(card: card, previousClosing: prev, lastClosing: last, nextClosing: next,
                         statementDue: statementDue, unbilledDue: unbilledDue,
                         statementStockCost: inStatement, unbilledStockCost: unbilledCost,
                         statementBills: billsFalling(after: prev, through: last),
                         unbilledBills: billsFalling(after: last, through: day),
                         comingBills: billsFalling(after: day, through: next),
                         monthlyBills: bills.reduce(0) { $0 + $1.amount },
                         statementOpen: statementDue > day)
    }

    /// Typed statements still owed, across cards.
    static func cardDebt(_ data: AppData, today: Date = .now) -> Int {
        data.cards.reduce(0) { $0 + cycle(for: $1, data, today: today).owedStatement }
    }

    /// Charged on a card, on no statement yet.
    static func unbilledCharges(_ data: AppData, today: Date = .now) -> Int {
        data.cards.reduce(0) { $0 + cycle(for: $1, data, today: today).unbilled }
    }

    // MARK: - Instalments

    static func installments(_ data: AppData) -> [Installment] { data.installments ?? [] }

    /// Everything still to be paid across every plan, fee included — what will
    /// actually leave the bank.
    static func installmentRemaining(_ data: AppData, today: Date = .now) -> Int {
        installments(data).reduce(0) { $0 + $1.remaining(on: today) }
    }

    /// The debt part of what remains: the fee not yet accrued is a cost still to
    /// come, not money owed today.
    static func installmentPrincipal(_ data: AppData, today: Date = .now) -> Int {
        installments(data).reduce(0) { $0 + $1.remaining(on: today) - remainingFee($1, today: today) }
    }

    /// 分割手数料 spread evenly over the payments; this is the part still ahead.
    static func remainingFee(_ plan: Installment, today: Date = .now) -> Int {
        guard plan.months > 0, plan.feeTotal > 0 else { return 0 }
        return plan.feeTotal * plan.monthsLeft(on: today) / plan.months
    }

    /// The fee inside one debit.
    static func feePerPayment(_ plan: Installment) -> Int {
        plan.months > 0 ? plan.feeTotal / plan.months : 0
    }

    // MARK: - Loans

    static func loansOwedToYou(_ data: AppData) -> Int {
        data.loans.filter { $0.direction > 0 && $0.currency == "JPY" }.reduce(0) { $0 + $1.amount }
    }

    static func loansYouOwe(_ data: AppData) -> Int {
        data.loans.filter { $0.direction < 0 && $0.currency == "JPY" }.reduce(0) { $0 + $1.amount }
    }

    // MARK: - Schedule

    enum EventKind { case income, receivable, card, installment, bill, loan }

    /// One thing that will move cash on a day. `amount` is signed: money in
    /// is positive.
    struct ScheduledEvent: Identifiable {
        var id: String { "\(kind)-\(label)-\(date.timeIntervalSince1970)" }
        let date: Date
        /// The name of the card, plan, bill or person. The user's own words,
        /// shown as written.
        let label: String
        /// What kind of movement it is. Copy, so it is resolved here rather
        /// than handed to the view as a key: half the values are a lender's
        /// name, and only this side knows which is which.
        let detail: String
        let amount: Int
        let kind: EventKind
    }

    /// Everything that will move cash in (today, end], soonest first. Card-paid
    /// bills are not listed on their own day: they are inside the card events.
    static func events(_ data: AppData, from today: Date, to end: Date) -> [ScheduledEvent] {
        let cal = Calendar.current
        let day = cal.startOfDay(for: today)
        var out: [ScheduledEvent] = []
        func add(_ date: Date, _ label: String, _ detail: String, _ amount: Int, _ kind: EventKind) {
            guard date > day, date <= end, amount != 0 else { return }
            out.append(ScheduledEvent(date: date, label: label, detail: detail, amount: amount, kind: kind))
        }

        for card in data.cards {
            let c = cycle(for: card, data, today: today)
            add(c.statementDue, card.name, String(localized: "Statement"), -c.owedStatement, .card)
            add(c.unbilledDue, card.name, String(localized: "Next statement, projected"), -c.projectedNext, .card)
            var due = c.unbilledDue
            while let later = cal.date(byAdding: .month, value: 1, to: due), later <= end {
                add(later, card.name, String(localized: "Projected from bills and living"), -c.projectedSteady, .card)
                due = later
            }
        }

        for plan in installments(data) where !plan.closed {
            for k in plan.paidCount(on: today)..<plan.months {
                let date = plan.dueDate(at: k)
                if date > end { break }
                add(date, plan.name, plan.lender.isEmpty ? String(localized: "Instalment") : plan.lender, -plan.amount(at: k), .installment)
            }
        }

        let cardNames = Set(data.cards.map(\.name))
        for r in (data.recurring ?? []) where r.active && !cardNames.contains(r.paidBy) {
            for date in dates(day: r.day, after: day, through: end) {
                add(date, r.name, r.isIncome ? String(localized: "Income") : String(localized: "Bill"), r.isIncome ? r.amount : -r.amount, r.isIncome ? .income : .bill)
            }
        }

        for loan in data.loans where loan.currency == "JPY" {
            guard let when = loan.expectedOn else { continue }
            add(cal.startOfDay(for: when), loan.person,
                loan.direction > 0 ? String(localized: "Pays you back") : String(localized: "You pay back"),
                loan.direction > 0 ? loan.amount : -loan.amount,
                loan.direction > 0 ? .receivable : .loan)
        }

        return out.sorted { $0.date < $1.date }
    }

    /// One line of the upcoming list: a single dated movement, or several of
    /// one kind collapsed into one.
    struct EventGroup: Identifiable {
        var id: String { "\(kind)-\(first.timeIntervalSince1970)-\(count)" }
        let kind: EventKind
        /// The soonest of them, which is where the line sorts.
        let first: Date
        /// The last of them; the same day as `first` when there is only one.
        let last: Date
        let amount: Int
        let count: Int
        /// The movement itself when this line is one of them. A collapsed line
        /// has no single name, so this is nil and the view names the kind.
        let single: ScheduledEvent?
    }

    /// The upcoming movements with cards and instalment plans collapsed to one
    /// line each.
    ///
    /// Six statements and two plan debits are eight rows saying the same thing
    /// twice over, and this list is read at a glance — the chart above it
    /// already draws every individual step. A kind collapses only when it has
    /// more than one movement in the window, so a lone card still appears
    /// under its own name.
    ///
    /// Every event lands in exactly one line, so the lines add up to exactly
    /// what the events did. Nothing is counted twice and nothing is dropped.
    static func upcomingLines(_ data: AppData, from today: Date, to end: Date) -> [EventGroup] {
        let all = events(data, from: today, to: end)
        var lines: [EventGroup] = []
        for kind in [EventKind.card, .installment] {
            let of = all.filter { $0.kind == kind }
            guard of.count > 1 else { continue }
            lines.append(EventGroup(kind: kind,
                                    first: of.map(\.date).min()!,
                                    last: of.map(\.date).max()!,
                                    amount: of.reduce(0) { $0 + $1.amount },
                                    count: of.count,
                                    single: nil))
        }
        let collapsed = Set(lines.map(\.kind))
        for e in all where !collapsed.contains(e.kind) {
            lines.append(EventGroup(kind: e.kind, first: e.date, last: e.date,
                                    amount: e.amount, count: 1, single: e))
        }
        return lines.sorted { $0.first < $1.first }
    }

    // MARK: - Horizon

    /// How far Safe to spend looks. `payday` is the next salary; with no salary
    /// entered it falls back to thirty days.
    enum Horizon: Equatable {
        case days(Int)
        case payday
        case date(Date)

        static func stored(_ raw: String) -> Horizon {
            switch raw {
            case "60d": return .days(60)
            case "payday": return .payday
            default: return .days(30)
            }
        }
        var storedValue: String {
            switch self {
            case .days(60): return "60d"
            case .payday: return "payday"
            default: return "30d"
            }
        }

        func end(_ data: AppData, today: Date) -> Date {
            let cal = Calendar.current
            let day = cal.startOfDay(for: today)
            switch self {
            case .days(let n): return cal.date(byAdding: .day, value: n, to: day)!
            case .date(let d): return max(cal.startOfDay(for: d), day)
            case .payday:
                guard let salary = Finance.salary(data) else { return cal.date(byAdding: .day, value: 30, to: day)! }
                return Finance.next(day: salary.day, after: day)
            }
        }
    }

    /// The salary line, if one is entered: the income marked "salary", else the
    /// largest income.
    static func salary(_ data: AppData) -> Recurring? {
        let incomes = (data.recurring ?? []).filter { $0.active && $0.isIncome }
        return incomes.first { $0.category == "salary" } ?? incomes.max { $0.amount < $1.amount }
    }

    // MARK: - Safe to spend

    struct SafeToSpend {
        let end: Date
        let cash: Int
        let incoming: Int
        let cards: Int
        let installments: Int
        let bills: Int
        let buffer: Int
        var committed: Int { cards + installments + bills }
        var total: Int { cash + incoming - committed - buffer }
    }

    /// Cash, plus what is confirmed to arrive before `horizon`, minus what must
    /// be paid before it, minus the buffer kept back on purpose.
    static func safeToSpend(_ data: AppData, horizon: Horizon, today: Date = .now) -> SafeToSpend {
        let end = horizon.end(data, today: today)
        let list = events(data, from: today, to: end)
        func sum(_ kinds: Set<EventKind>) -> Int { list.filter { kinds.contains($0.kind) }.reduce(0) { $0 + abs($1.amount) } }
        return SafeToSpend(end: end, cash: cashNow(data),
                           incoming: sum([.income, .receivable]),
                           cards: sum([.card]),
                           installments: sum([.installment]),
                           bills: sum([.bill, .loan]),
                           buffer: data.safetyBuffer)
    }

    // MARK: - Payment schedule

    /// One day of the schedule: everything that moves cash that day, and what
    /// is left once it has.
    struct DueDay: Identifiable {
        var id: Date { date }
        let date: Date
        /// Signed, money in positive — a salary day is a row too, because
        /// hiding it would make the balance jump for no visible reason.
        let amount: Int
        /// What is due, in the order it comes: card and plan names.
        let names: [String]
        /// Cash left at the end of the day, if everything before it happens as
        /// planned.
        let balanceAfter: Int
        /// How much more has to be in the bank by then for the day to clear.
        /// The reserve is not in this: the question is whether the payment can
        /// physically be made, not whether it is comfortable.
        var shortfall: Int { max(0, -balanceAfter) }
    }

    /// The forecast as a payment schedule, one row a day with the running
    /// balance — so a screen can say "by the 4th you are ¥120,000 short"
    /// instead of leaving the reader to add up a list.
    static func paymentsDue(_ data: AppData, to end: Date, today: Date = .now) -> [DueDay] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: events(data, from: today, to: end)) {
            cal.startOfDay(for: $0.date)
        }
        var balance = cashNow(data)
        var out: [DueDay] = []
        for day in grouped.keys.sorted() {
            let of = grouped[day] ?? []
            let amount = of.reduce(0) { $0 + $1.amount }
            balance += amount
            // Deduped, order kept: two events for one card on one day would
            // otherwise print its name twice.
            var names: [String] = []
            for e in of where e.amount < 0 && !names.contains(e.label) { names.append(e.label) }
            out.append(DueDay(date: day, amount: amount, names: names, balanceAfter: balance))
        }
        return out
    }

    /// How much extra has to be found, and the first day the schedule fails.
    /// nil when every day clears on the cash already in the wallets.
    ///
    /// The amount is the *worst* day, not the first: that is the sum that has
    /// to be lined up. The date is the *first*, because that is the deadline.
    static func shortfall(_ days: [DueDay]) -> (amount: Int, from: Date)? {
        let short = days.filter { $0.shortfall > 0 }
        guard let first = short.first,
              let worst = short.max(by: { $0.shortfall < $1.shortfall }) else { return nil }
        return (worst.shortfall, first.date)
    }

    // MARK: - Forecast

    struct ForecastPoint: Identifiable {
        var id: Date { date }
        let date: Date
        let balance: Int
    }

    struct Forecast {
        let points: [ForecastPoint]
        let lowest: ForecastPoint
        let buffer: Int
        /// How far the lowest point sits under the buffer; 0 when it never does.
        var shortfall: Int { max(0, buffer - lowest.balance) }
    }

    /// Cash day by day from today to `end`, every scheduled event applied on
    /// its day.
    static func projectedCashBalance(_ data: AppData, to end: Date, today: Date = .now) -> Forecast {
        let cal = Calendar.current
        var day = cal.startOfDay(for: today)
        var balance = cashNow(data)
        let list = events(data, from: today, to: end)
        var points = [ForecastPoint(date: day, balance: balance)]
        var lowest = points[0]
        while day < end {
            day = cal.date(byAdding: .day, value: 1, to: day)!
            balance += list.filter { cal.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.amount }
            let p = ForecastPoint(date: day, balance: balance)
            points.append(p)
            if p.balance < lowest.balance { lowest = p }
        }
        return Forecast(points: points, lowest: lowest, buffer: data.safetyBuffer)
    }

    // MARK: - Net worth

    struct NetWorth {
        let cash: Int
        let inventory: Int
        let receivables: Int
        let cardDebt: Int
        let unbilledCharges: Int
        let installmentPrincipal: Int
        let loansYouOwe: Int
        var assets: Int { cash + inventory + receivables }
        var liabilities: Int { cardDebt + unbilledCharges + installmentPrincipal + loansYouOwe }
        var total: Int { assets - liabilities }
    }

    /// Everything sold at its estimate, everyone paid back, every card, plan
    /// and person paid off. Rent next year is not in here: it is not owed yet.
    static func netWorth(_ data: AppData, today: Date = .now) -> NetWorth {
        NetWorth(cash: cashNow(data),
                 inventory: liquidation(data),
                 receivables: loansOwedToYou(data),
                 cardDebt: cardDebt(data, today: today),
                 unbilledCharges: unbilledCharges(data, today: today),
                 installmentPrincipal: installmentPrincipal(data, today: today),
                 loansYouOwe: loansYouOwe(data))
    }

    // MARK: - Monthly cash flow

    struct MonthlyCashFlow {
        let month: DateInterval
        let income: Int
        let resaleProfit: Int
        /// Every recurring bill, however it is paid.
        let fixedBills: Int
        /// What the statements say life costs beyond the bills listed.
        let livingEstimate: Int
        /// 分割手数料 falling in the month. Principal is not a cost.
        let interest: Int
        var planned: Int { income + resaleProfit - fixedBills - livingEstimate - interest }
        /// From the snapshots, when the month has one to compare against.
        let actualCashDelta: Int?
        let actualNetWorthDelta: Int?

        /// How the month has really gone against its plan. Positive is better
        /// than planned. nil until there is a snapshot to compare against.
        ///
        /// The gap is the point of showing both: `planned` leans on the cards'
        /// `livingEstimate`, so a month that keeps landing behind plan is the
        /// app telling you that estimate is too low.
        var againstPlan: Int? { actualNetWorthDelta.map { $0 - planned } }
    }

    /// Is the book getting richer or poorer from ordinary life? Income and
    /// resale profit in, bills and living out. Paying down a card or a plan is
    /// not a cost — that money was already counted when it was owed.
    static func monthlyCashFlow(_ data: AppData, month reference: Date, today: Date = .now) -> MonthlyCashFlow {
        let cal = Calendar.current
        let month = cal.dateInterval(of: .month, for: reference)!
        let recurring = (data.recurring ?? []).filter(\.active)
        let interest = installments(data).filter { !$0.closed }.reduce(0) { sum, plan in
            let hits = (0..<plan.months).filter { month.contains(plan.dueDate(at: $0)) }.count
            return sum + hits * feePerPayment(plan)
        }
        let living = data.cards.reduce(0) { $0 + cycle(for: $1, data, today: today).livingEstimate }

        let snaps = (data.snapshots ?? []).sorted { $0.date < $1.date }
        let start = snaps.first { month.contains($0.date) }
        let isCurrent = month.contains(today)
        var cashDelta: Int? = nil, worthDelta: Int? = nil
        if let start {
            if isCurrent {
                cashDelta = cashNow(data) - start.cash
                worthDelta = netWorth(data, today: today).total - start.netWorth
            } else if let end = snaps.first(where: { $0.date >= month.end }) {
                cashDelta = end.cash - start.cash
                worthDelta = end.netWorth - start.netWorth
            }
        }
        return MonthlyCashFlow(month: month,
                               income: recurring.filter(\.isIncome).reduce(0) { $0 + $1.amount },
                               resaleProfit: realizedSalesProfit(data, in: month),
                               fixedBills: recurring.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount },
                               livingEstimate: living,
                               interest: interest,
                               actualCashDelta: cashDelta,
                               actualNetWorthDelta: worthDelta)
    }

    /// The snapshot the month should hold, taken from the book as it stands.
    static func snapshot(_ data: AppData, today: Date = .now) -> CashSnapshot {
        CashSnapshot(date: today, cash: cashNow(data),
                     cardDebt: cardDebt(data, today: today),
                     installmentDebt: installmentRemaining(data, today: today),
                     netWorth: netWorth(data, today: today).total)
    }

    // MARK: - Calendar helpers

    /// `day` of the month `reference` falls in, pulled back to the month's last
    /// day when the month is shorter (a bill on the 31st lands on Feb 28).
    static func date(day: Int, in reference: Date) -> Date {
        let cal = Calendar.current
        let interval = cal.dateInterval(of: .month, for: reference)!
        let length = cal.range(of: .day, in: .month, for: reference)!.count
        return cal.date(byAdding: .day, value: min(max(day, 1), length) - 1, to: interval.start)!
    }

    /// Most recent occurrence of `day` on or before `today` (start of day).
    static func latest(day: Int, onOrBefore today: Date) -> Date {
        let cal = Calendar.current
        let candidate = date(day: day, in: today)
        if candidate <= today { return candidate }
        return date(day: day, in: cal.date(byAdding: .month, value: -1, to: today)!)
    }

    /// First occurrence of `day` strictly after `today` (start of day).
    static func next(day: Int, after today: Date) -> Date {
        let cal = Calendar.current
        let candidate = date(day: day, in: today)
        if candidate > today { return candidate }
        return date(day: day, in: cal.date(byAdding: .month, value: 1, to: today)!)
    }

    /// Every occurrence of `day` in (from, through].
    static func dates(day: Int, after from: Date, through to: Date) -> [Date] {
        var out: [Date] = []
        var d = next(day: day, after: from)
        while d <= to {
            out.append(d)
            d = next(day: day, after: d)
        }
        return out
    }

    static func occurrences(day: Int, after from: Date, through to: Date) -> Int {
        dates(day: day, after: from, through: to).count
    }
}
