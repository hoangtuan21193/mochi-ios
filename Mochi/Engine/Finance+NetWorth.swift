import Foundation

/// The Net worth screen: the monthly readings over a chosen stretch, what
/// net worth has done since the first of them, and the lines under "What
/// you have" and "What you owe". Readings are the snapshots and nothing
/// else — a month the app was not opened in has no point (CLAUDE.md).
extension Finance {
    enum NetWorthRange: String, CaseIterable { case year, twelveMonths, all }

    struct NetWorthSeries {
        let points: [(month: Date, value: Int)]
        /// Today's figure against the first reading in the range; nil with
        /// fewer than two readings, when there is no line to speak of.
        let change: Int?
        let since: Date?
        var readings: Int { points.count }
    }

    static func netWorthSeries(_ data: AppData, _ range: NetWorthRange, today: Date = .now) -> NetWorthSeries {
        let cal = Calendar.current
        let start: Date
        switch range {
        case .year: start = cal.dateInterval(of: .year, for: today)!.start
        case .twelveMonths: start = cal.date(byAdding: .month, value: -11, to: cal.dateInterval(of: .month, for: today)!.start)!
        case .all: start = .distantPast
        }
        let byMonth = Dictionary(grouping: (data.snapshots ?? []).filter { $0.date >= start && $0.date <= today }) {
            cal.dateInterval(of: .month, for: $0.date)!.start
        }
        // The last reading of a month, as `history` takes it.
        let points = byMonth.keys.sorted().map { m in (month: m, value: byMonth[m]!.max { $0.date < $1.date }!.netWorth) }
        let now = netWorth(data, today: today).total
        return NetWorthSeries(points: points, change: points.count >= 2 ? now - points[0].value : nil, since: points.first?.month)
    }

    /// The largest belonging still on a card's unbilled charges — "includes
    /// the ¥198,000 camera" says why that line is big.
    static func largestUnbilledPurchase(_ data: AppData, today: Date = .now) -> Item? {
        let since = Dictionary(uniqueKeysWithValues: data.cards.map { ($0.name, cycle(for: $0, data, today: today).lastClosing) })
        return data.items
            .filter { i in !i.cardName.isEmpty && (since[i.cardName].map { i.boughtOn > $0 } ?? false) }
            .max { $0.buyPrice < $1.buyPrice }
    }
}
