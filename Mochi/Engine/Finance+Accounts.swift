import Foundation

// MARK: - The forecast account by account

/// The household total can cover every bill while the one account a card
/// debits from cannot: a JCB card paid from MUFG fails on the 13th even with
/// plenty in SMBC. So besides the one figure for the household, the forecast
/// is walked per account, and a gap becomes a move between your own accounts
/// with an amount and a day to make it by.
extension Finance {
    /// One account's balance after each day it moves.
    struct AccountDay: Identifiable {
        var id: Date { date }
        let date: Date
        let amount: Int
        let balanceAfter: Int
    }

    /// A move between two of your own accounts that keeps a debit from
    /// failing.
    struct TransferSuggestion: Identifiable, Hashable {
        var id: String { "\(from)>\(to)@\(deadline.timeIntervalSince1970)" }
        let from: String
        let to: String
        let amount: Int
        /// The last business day before the debit, so a bank transfer made on
        /// it lands in time.
        let deadline: Date
        /// The debit it is for.
        let debitDate: Date
        let debitLabel: String
        let debitAmount: Int
        /// What the short account holds now.
        let balanceNow: Int
        /// How short it would be on the debit day without the move.
        let shortBy: Int
        /// The last business day before the debit, even when it has passed:
        /// then `deadline` is today, and the move is late rather than early.
        var lastBusinessDay: Date? = nil
        /// What is left in the short account after the debit, with the move.
        var leftAfter: Int { amount - shortBy }
        /// The business day to make it by has gone: what is left is a
        /// transfer today, on whatever day today is.
        var isLate: Bool { lastBusinessDay.map { $0 < deadline } ?? false }
    }

    /// Each spendable account's walk through the forecast. Events with no
    /// account (a card with nowhere to pay from) are left out here; they
    /// still count in the household walk.
    static func accountForecast(_ data: AppData, to end: Date, today: Date = .now) -> [String: [AccountDay]] {
        let cal = Calendar.current
        var out: [String: [AccountDay]] = [:]
        let accounts = data.wallets.filter { !$0.isMarketplace }
        let list = events(data, from: today, to: end)
        for w in accounts {
            var balance = Finance.balance(of: w, data)
            let mine = Dictionary(grouping: list.filter { $0.account == w.name }) { cal.startOfDay(for: $0.date) }
            out[w.name] = mine.keys.sorted().map { d in
                let amount = mine[d]!.reduce(0) { $0 + $1.amount }
                balance += amount
                return AccountDay(date: d, amount: amount, balanceAfter: balance)
            }
        }
        return out
    }

    /// The moves that keep every account above zero through `end`, soonest
    /// first. For each account that would go below zero, the gap is its worst
    /// point before money next comes into it, rounded up to the next
    /// thousand; it is taken from the account with the most to spare at its
    /// lowest point. One suggestion per short account: once it is made, the
    /// forecast is walked again with the move in it.
    static func transfersNeeded(_ data: AppData, to end: Date, today: Date = .now) -> [TransferSuggestion] {
        let cal = Calendar.current
        let walks = accountForecast(data, to: end, today: today)
        let list = events(data, from: today, to: end)
        let now = Dictionary(uniqueKeysWithValues: data.wallets.filter { !$0.isMarketplace }.map { ($0.name, balance(of: $0, data)) })
        // Lowest point of each account over the whole window: what it could spare.
        var spare: [String: Int] = [:]
        for (name, days) in walks {
            spare[name] = min(now[name] ?? 0, days.map(\.balanceAfter).min() ?? (now[name] ?? 0))
        }
        var out: [TransferSuggestion] = []
        for (name, days) in walks {
            guard let first = days.firstIndex(where: { $0.balanceAfter < 0 }) else { continue }
            var worst = days[first].balanceAfter
            for d in days[(first + 1)...] {
                if d.amount > 0 { break }
                worst = min(worst, d.balanceAfter)
            }
            let need = Int((Double(-worst) / 1000).rounded(.up)) * 1000
            guard let source = spare.filter({ $0.key != name && $0.value >= need }).max(by: { $0.value < $1.value })?.key else { continue }
            spare[source]! -= need
            let debitDay = days[first].date
            let debit = list.filter { $0.account == name && $0.amount < 0 && cal.isDate($0.date, inSameDayAs: debitDay) }
            var deadline = cal.date(byAdding: .day, value: -1, to: debitDay)!
            while !BusinessCalendar.isBusinessDay(deadline) { deadline = cal.date(byAdding: .day, value: -1, to: deadline)! }
            out.append(TransferSuggestion(from: source, to: name, amount: need, deadline: max(deadline, cal.startOfDay(for: today)),
                                          debitDate: debitDay, debitLabel: debit.first?.label ?? "",
                                          debitAmount: -debit.reduce(0) { $0 + $1.amount },
                                          balanceNow: now[name] ?? 0, shortBy: -days[first].balanceAfter,
                                          lastBusinessDay: deadline))
        }
        return out.sorted { $0.deadline < $1.deadline }
    }

    /// An account that goes below zero on a day it is debited: the first
    /// such day, and by how much.
    struct AccountShortfall: Identifiable, Hashable {
        var id: String { "\(account)@\(date.timeIntervalSince1970)" }
        let account: String
        let date: Date
        let shortBy: Int
    }

    /// Every account that fails somewhere before `end`, soonest first —
    /// whether or not another account has room to cover it. A move is only
    /// the fix; the shortfall stands on its own, and is most worth saying
    /// when no move can fix it.
    static func accountShortfalls(_ data: AppData, to end: Date, today: Date = .now) -> [AccountShortfall] {
        accountForecast(data, to: end, today: today).compactMap { name, days in
            days.first { $0.balanceAfter < 0 }.map { AccountShortfall(account: name, date: $0.date, shortBy: -$0.balanceAfter) }
        }
        .sorted { ($0.date, $0.account) < ($1.date, $1.account) }
    }

    /// Whether this round of card debits can be paid: Home's first answer.
    enum CardRoundVerdict: Equatable {
        /// Every account clears every debit, and so does the household.
        case covered
        /// One account fails on `on`; `move` is the transfer that saves it,
        /// nil when no account of yours has that much to spare.
        case accountShort(AccountShortfall, move: TransferSuggestion?)
        /// Each account clears, yet the household as a whole does not —
        /// a card with nowhere set to pay from still has to be paid.
        case householdShort(amount: Int, from: Date)
    }

    /// The verdict over `end` (the cards' horizon). An account that fails
    /// is a failure whether or not a move exists: saying "every account can
    /// pay" because nothing could be moved to it was the wrong way round.
    static func cardRound(_ data: AppData, to end: Date, today: Date = .now) -> CardRoundVerdict {
        if let first = accountShortfalls(data, to: end, today: today).first {
            let move = transfersNeeded(data, to: end, today: today).first { $0.to == first.account }
            return .accountShort(first, move: move)
        }
        if let short = shortfall(paymentsDue(data, to: end, today: today)) {
            return .householdShort(amount: short.amount, from: short.from)
        }
        return .covered
    }
}

// MARK: - Cards to pay, a day to a line

extension Finance {
    /// The card debits due on one day, added up: four cards on two days read
    /// as two lines and one total.
    struct CardDay: Identifiable, Equatable {
        var id: Date { date }
        let date: Date
        /// What leaves on the day, as a positive figure.
        let amount: Int
        let cards: [String]
    }

    /// Every card debit up to `end`, one entry a day, soonest first.
    static func cardDays(_ data: AppData, to end: Date, today: Date = .now) -> [CardDay] {
        let cal = Calendar.current
        let debits = events(data, from: today, to: end).filter { $0.kind == .card && $0.amount < 0 }
        let byDay = Dictionary(grouping: debits) { cal.startOfDay(for: $0.date) }
        return byDay.keys.sorted().map { d in
            let list = byDay[d]!
            var names: [String] = []
            for e in list where !names.contains(e.label) { names.append(e.label) }
            return CardDay(date: d, amount: -list.reduce(0) { $0 + $1.amount }, cards: names)
        }
    }
}

// MARK: - Net worth this year

extension Finance {
    /// How far net worth has moved since the first monthly reading of the
    /// year, and how many readings there are. nil until there are two: one
    /// reading is a point, not a change.
    static func netWorthChangeThisYear(_ data: AppData, today: Date = .now) -> (change: Int, readings: Int)? {
        let cal = Calendar.current
        let year = cal.component(.year, from: today)
        let readings = (data.snapshots ?? []).filter { cal.component(.year, from: $0.date) == year }.sorted { $0.date < $1.date }
        guard readings.count >= 2, let first = readings.first else { return nil }
        return (netWorth(data, today: today).total - first.netWorth, readings.count)
    }
}

// MARK: - Points and profit

/// A purchase's points are part of what the trade made: a ¥785,266 lens that
/// paid back ¥94,328 of points and sold for ¥740,000 lost cash and still made
/// money. So profit is shown with them, and its cash part always beside it.
/// Points are never cash, never Safe to spend; only points that buy anything
/// count in net worth.
extension Finance {
    /// What `points` in a wallet are worth in the book's currency.
    static func value(ofPoints points: Int, in wallet: PointWallet?) -> Int {
        Int((Double(points) * (wallet?.yenPerPoint ?? 1)).rounded())
    }

    /// Points that buy anything, at their value: the part of points that is in net worth.
    static func spendablePointsValue(_ data: AppData) -> Int {
        data.pointWallets.filter { $0.spendAnywhere == true }
            .reduce(0) { $0 + value(ofPoints: $1.points + effect(on: $1.name, data), in: $1) }
    }

    /// A trade's result, with its cash part and its points part.
    struct TradeResult: Equatable {
        let cash: Int
        let points: Int
        var total: Int { cash + points }
    }

    /// What an item made once sold, or would make sold now through its
    /// planned channel at its worth: the cash result plus the points the
    /// purchase earned (and, for a point channel, the points the sale pays).
    static func trade(_ item: Item, _ data: AppData) -> TradeResult {
        let cash = profit(item, data)
        var points = item.pointsEarned
        if !item.isSold { points += expectedPoints(item, channelName: item.plannedChannel, data) }
        return TradeResult(cash: cash, points: points)
    }

    /// Profit with points on what sold in `period`.
    static func profitWithPoints(_ data: AppData, for period: Period) -> TradeResult {
        let sold = data.items.filter { $0.sale.map { period.contains($0.date) } ?? false }
        return sold.reduce(TradeResult(cash: 0, points: 0)) { sum, item in
            let t = trade(item, data)
            return TradeResult(cash: sum.cash + t.cash, points: sum.points + t.points)
        }
    }
}

// MARK: - What the things for sale come to

extension Finance {
    /// The things marked for sale, as the Belongings tiles read them: what
    /// was paid and the points it paid back, what selling them would bring
    /// after fees, postage and withdrawing, and the result if all sold now —
    /// cash and points apart, then together.
    struct ResaleOutlook: Equatable {
        let paid: Int
        let pointsBack: Int
        let wouldBring: Int
        let ifAllSold: TradeResult
    }

    static func resaleOutlook(_ data: AppData) -> ResaleOutlook {
        let items = forSale(data)
        let result = items.reduce(TradeResult(cash: 0, points: 0)) { sum, item in
            let t = trade(item, data)
            return TradeResult(cash: sum.cash + t.cash, points: sum.points + t.points)
        }
        return ResaleOutlook(paid: items.reduce(0) { $0 + $1.buyPrice },
                             pointsBack: items.reduce(0) { $0 + $1.pointsEarned },
                             wouldBring: liquidation(data),
                             ifAllSold: result)
    }
}
