import Foundation

/// Where a period's money went, for Transactions › Spending: the period
/// itself (a calendar month, a pay period or a year), its four figures, the
/// shares by category, shop or place, and the period's income followed to
/// where it went. docs/design/spending.md.
extension Finance {
    enum SpendingPeriod: String, CaseIterable { case month, payPeriod, year }
    enum SpendingSplit: String, CaseIterable { case categories, shops, places }

    /// The period of kind `p` that holds `date`. A pay period runs payday to
    /// the day before the next, as Budget's does; without a salary it is the
    /// calendar month.
    static func spendingInterval(_ data: AppData, _ p: SpendingPeriod, containing date: Date) -> DateInterval {
        let cal = Calendar.current
        switch p {
        case .month: return cal.dateInterval(of: .month, for: date)!
        case .year: return cal.dateInterval(of: .year, for: date)!
        case .payPeriod: return payPeriod(data, today: date)
        }
    }

    /// The one before, and the one after — nil when it has not begun yet:
    /// what was spent cannot be looked at ahead.
    static func previousSpendingInterval(_ data: AppData, _ p: SpendingPeriod, before i: DateInterval) -> DateInterval {
        spendingInterval(data, p, containing: i.start.addingTimeInterval(-1))
    }

    static func nextSpendingInterval(_ data: AppData, _ p: SpendingPeriod, after i: DateInterval, today: Date = .now) -> DateInterval? {
        i.end > today ? nil : spendingInterval(data, p, containing: i.end)
    }

    struct SpendingSummary {
        let interval: DateInterval
        let previousInterval: DateInterval
        let spent: Int
        /// Nil when nothing was spent in the period before: a change against
        /// an empty period is the whole figure, and says nothing.
        let change: Int?
        let shares: [Share]
        var largest: Share? { shares.first }
        let perDay: Int
        /// Days of the period gone by, today included.
        let days: Int
        let belongingBuys: Int
    }

    static func spendingSummary(_ data: AppData, _ p: SpendingPeriod, containing date: Date,
                                by split: SpendingSplit, today: Date = .now) -> SpendingSummary {
        let cal = Calendar.current
        let interval = spendingInterval(data, p, containing: date)
        let before = previousSpendingInterval(data, p, before: interval)
        let spent = spending(data, in: interval)
        let previous = spending(data, in: before)
        var shares: [Share]
        switch split {
        case .categories: shares = spendingByCategory(data, in: interval)
        case .shops: shares = spendingByMerchant(data, in: interval)
        case .places: shares = spendingByPlace(data, in: interval)
        }
        // Rounded, not cut: 16.9% is 17%, as anyone would say it.
        for i in shares.indices { shares[i].percent = spent > 0 ? Int((Double(shares[i].amount) * 100 / Double(spent)).rounded()) : 0 }
        let lastDay = interval.contains(today) ? cal.startOfDay(for: today) : cal.date(byAdding: .day, value: -1, to: interval.end)!
        let days = max(1, (cal.dateComponents([.day], from: cal.startOfDay(for: interval.start), to: lastDay).day ?? 0) + 1)
        return SpendingSummary(interval: interval, previousInterval: before, spent: spent,
                               change: previous > 0 ? spent - previous : nil, shares: shares,
                               perDay: spent / days, days: days, belongingBuys: belongingBuys(data, in: interval))
    }

    /// Spending by the place kept on each transaction (a saved spot's name);
    /// what was spent with no place kept is one share of its own.
    static func spendingByPlace(_ data: AppData, in interval: DateInterval) -> [Share] {
        grouped(data, in: interval) { ($0.placeName ?? "").isEmpty ? "No place kept" : $0.placeName! }
            .sorted { $0.key < $1.key }
            .enumerated()
            .map { i, pair in
                Share(name: pair.key, amount: -pair.value.reduce(0) { $0 + $1.spendingAmount },
                      count: pair.value.count, colorIndex: i % 7)
            }
            .filter { $0.amount != 0 }
            .sorted { $0.amount > $1.amount }
    }

    /// A period's income followed to where it went: the largest shares one
    /// by one, the rest together, and what was left. Spending more than came
    /// in shows the gap as coming from what you had, never as a negative
    /// "left over". Belongings bought are in neither side, as in the total.
    struct IncomeFlow {
        let income: Int
        /// What spending took beyond the income.
        let fromSavings: Int
        let top: [Share]
        /// The shares after `top`, together; nil when there are none.
        let rest: Share?
        let restCount: Int
        let leftOver: Int
        var spent: Int { top.reduce(0) { $0 + $1.amount } + (rest?.amount ?? 0) }
    }

    static func incomeFlow(_ data: AppData, in interval: DateInterval, shares: [Share], showing n: Int = 3) -> IncomeFlow {
        let income = transactions(data).filter { $0.kind == .income && interval.contains($0.date) }.reduce(0) { $0 + $1.amount }
        let top = Array(shares.prefix(n))
        let others = shares.dropFirst(n)
        let rest = others.isEmpty ? nil
            : Share(name: "", amount: others.reduce(0) { $0 + $1.amount }, count: others.reduce(0) { $0 + $1.count },
                    colorIndex: others.first!.colorIndex)
        let spent = shares.reduce(0) { $0 + $1.amount }
        return IncomeFlow(income: income, fromSavings: max(0, spent - income), top: top, rest: rest,
                          restCount: others.count, leftOver: max(0, income - spent))
    }
}
