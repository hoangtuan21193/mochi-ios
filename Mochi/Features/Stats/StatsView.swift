import SwiftUI
import Charts

/// Tab 2. How this has gone — the backward-looking half of the app.
///
/// Overview answers what is true now and what happens before the next bill.
/// Everything here is history: a year of selling above, and the month-by-month
/// shape of the book below. Nothing on this screen is a forecast, and no figure
/// on it is repeated on Overview.
struct StatsView: View {
    @Environment(Store.self) private var store
    /// Which window the figures above the charts report on — a whole year, or
    /// one month. Starts on this year, the widest useful answer.
    @State private var period: Finance.Period = .year(Calendar.current.component(.year, from: .now))
    /// How far the charts look back. Two years is as much as the snapshots
    /// keep (36 months), and more than that on a phone-width chart is a smear.
    @State private var months = 12

    private static let spans = [6, 12, 24]

    private var summary: Finance.PeriodSummary { store.summary(for: period) }
    private var history: [Finance.MonthPoint] { store.history(months: months) }
    /// The months that actually have a snapshot. A balance chart drawn through
    /// the gaps would invent a history the book does not have.
    private var balancePoints: [Finance.MonthPoint] { history.filter { $0.cash != nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    yearCard
                    balanceCard
                    profitCard
                    soldCard
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
            }
            .background(Organic.bg)
            .navigationTitle("Stats")
        }
    }

    // MARK: - The year

    private var yearCard: some View {
        Card {
            Text("Selling").font(Organic.title)
            // A menu, not chips. Every month of every year is far more than
            // four options, and chips for that wrapped into a broken block —
            // the years hold their own months, so one control covers both.
            periodPicker.padding(.vertical, 6)
            HStack(spacing: 8) {
                Metric(label: "Sold", value: "\(summary.soldCount)", boxed: true)
                Metric(label: "Revenue", value: store.format(summary.revenue), boxed: true)
                Metric(label: "Cash profit", value: store.signed(summary.profit),
                       valueColor: summary.profit < 0 ? Organic.a800 : Organic.s900, boxed: true)
            }
            .padding(.top, 10)
            VStack(spacing: 0) {
                if let days = summary.averageDaysHeld {
                    LineRow(label: "Days from buy to sale", value: "\(days)", tone: .quiet)
                }
                if summary.points > 0 {
                    LineRow(label: "Points on purchases", value: "+\(summary.points.formatted()) pt",
                            tone: .positive)
                }
            }
            .padding(.top, 6)
            if summary.points > 0 {
                HelpText("Points are counted on the day you bought, so they fill up whether or not anything has sold. Not cash, and not inside the profit above: add them to a point wallet yourself.")
                    .padding(.top, 4)
            }
        }
    }

    /// Every year the book has anything in, each holding its own months, plus
    /// the whole book. A submenu per year keeps the list short however many
    /// years pile up.
    private var periodPicker: some View {
        DropdownRow(label: "Period", value: Text(periodName(period))) {
            Button { period = .all } label: {
                label("Everything", chosen: period == .all)
            }
            ForEach(store.yearsWithActivity, id: \.self) { y in
                Menu(String(y)) {
                    Button { period = .year(y) } label: {
                        label("All of \(String(y))", chosen: period == .year(y))
                    }
                    ForEach(monthsIn(y), id: \.self) { m in
                        Button { period = m } label: {
                            label(periodName(m), chosen: period == m)
                        }
                    }
                }
            }
        }
    }

    /// A tick beside the one in force. A `Label` with a checkmark is how every
    /// other menu in the app marks its choice.
    @ViewBuilder
    private func label(_ title: LocalizedStringKey, chosen: Bool) -> some View {
        if chosen { Label { Text(title) } icon: { Image(systemName: "checkmark") } } else { Text(title) }
    }

    private func monthsIn(_ year: Int) -> [Finance.Period] {
        store.monthsWithActivity.filter {
            if case .month(let y, _) = $0 { return y == year }
            return false
        }
    }

    private func periodName(_ p: Finance.Period) -> LocalizedStringKey {
        switch p {
        case .all: return "Everything"
        case .year(let y): return "All of \(String(y))"
        case .month:
            guard let start = p.start else { return "" }
            return "\(start.formatted(.dateTime.month(.wide).year()))"
        }
    }

    // MARK: - Cash and net worth, month by month

    private var balanceCard: some View {
        Card {
            Text("Cash and net worth").font(Organic.title)
            spanPicker.padding(.top, 6)
            if balancePoints.count < 2 {
                HelpText("The app writes down your cash and net worth once a month, the first time it opens. Two months of those and this draws the line between them — there is nothing to reconstruct from before it was installed.")
                    .padding(.top, 2)
            } else {
                HelpText("Taken once a month from the balances you typed. A month the app never opened in has no reading, so the line skips it.")
                    .padding(.top, 2)
                balanceChart
                    .padding(.top, 10)
                ChartLegend(.init("Cash", .line, Organic.s700),
                            .init("Net worth", .dashed, Organic.n700))
                    .padding(.top, 6)
                if let first = balancePoints.first, let last = balancePoints.last,
                   let from = first.cash, let to = last.cash {
                    CalloutRow(label: "Cash since \(first.month.formatted(.dateTime.month(.abbreviated).year()))",
                               value: store.signed(to - from), positive: to >= from)
                        .padding(.top, 8)
                }
            }
        }
    }

    private var balanceChart: some View {
        Chart {
            ForEach(balancePoints) { p in
                if let cash = p.cash {
                    LineMark(x: .value("Month", p.month), y: .value("Cash", cash),
                             series: .value("Series", "cash"))
                        .foregroundStyle(Organic.s700)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("Month", p.month), y: .value("Cash", cash))
                        .foregroundStyle(Organic.s700).symbolSize(18)
                }
                if let worth = p.netWorth {
                    LineMark(x: .value("Month", p.month), y: .value("Cash", worth),
                             series: .value("Series", "worth"))
                        .foregroundStyle(Organic.n700)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }
            }
            RuleMark(y: .value("Zero", 0)).foregroundStyle(Organic.n300)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 120)
    }

    // MARK: - Profit, month by month

    private var profitCard: some View {
        let months = history
        let anything = months.contains { $0.profit != 0 || $0.points != 0 }
        return Card {
            HStack(alignment: .firstTextBaseline) {
                Text("Profit by month").font(Organic.title)
                Spacer()
                Text("\(months.reduce(0) { $0 + $1.soldCount }) sold")
                    .font(Organic.meta).foregroundStyle(Organic.n600)
            }
            if !anything {
                HelpText("Nothing has sold in this window. Confirming a sale from an item's page puts its month on this chart.")
                    .padding(.top, 2)
            } else {
                HelpText("What each month's confirmed sales made after fees and postage. A month with nothing sold is a gap, not a zero month of trading.")
                    .padding(.top, 2)
                profitChart(months)
                    .padding(.top, 10)
                ChartLegend(.init("Made money", .bar, Organic.s600),
                            .init("Lost money", .bar, Organic.a600))
                    .padding(.top, 6)
                VStack(spacing: 0) {
                    // Named by what it actually is. "Best month · ¥0" on a run
                    // of losing months points at a month that sold nothing,
                    // which is not a best month — it is an empty one.
                    if let best = months.max(by: { $0.profit < $1.profit }), best.profit > 0 {
                        LineRow(label: "Best month", value: monthLine(best), tone: .positive)
                    } else if let worst = months.min(by: { $0.profit < $1.profit }), worst.profit < 0 {
                        LineRow(label: "Worst month", value: monthLine(worst), tone: .negative)
                    }
                    LineRow(label: "Over \(months.count) months",
                            value: store.signed(months.reduce(0) { $0 + $1.profit }),
                            tone: months.reduce(0) { $0 + $1.profit } < 0 ? .negative : .positive,
                            total: true)
                }
                .padding(.top, 4)
            }
        }
    }

    private func profitChart(_ points: [Finance.MonthPoint]) -> some View {
        Chart {
            ForEach(points) { p in
                BarMark(x: .value("Month", p.month, unit: .month),
                        y: .value("Profit", p.profit))
                    .foregroundStyle(p.profit < 0 ? Organic.a600 : Organic.s600)
                    .cornerRadius(3)
            }
            RuleMark(y: .value("Zero", 0)).foregroundStyle(Organic.n300)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 110)
    }

    /// A month and what it made, named. The figure on its own would leave the
    /// reader hunting the chart for which bar it was.
    private func monthLine(_ point: Finance.MonthPoint) -> String {
        metaLine(point.month.formatted(.dateTime.month(.abbreviated).year()),
                 store.signed(point.profit))
    }

    private var spanPicker: some View {
        DropdownRow(label: "Look back", value: Text("\(months) months")) {
            ForEach(Self.spans, id: \.self) { m in
                Button { months = m } label: {
                    label("\(m) months", chosen: months == m)
                }
            }
        }
    }

    // MARK: - What sold

    private var soldCard: some View {
        Card {
            Text("What sold").font(Organic.title).padding(.bottom, 4)
            if summary.soldCount == 0 {
                EmptyNote("Nothing sold in this window. Confirming a sale from an item's page files it here.")
            }
            ForEach(soldItems) { item in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: item.name).font(Organic.row)
                        Text(verbatim: metaLine(item.sale?.channel ?? "",
                                                item.sale?.date.formatted(date: .numeric, time: .omitted) ?? ""))
                            .font(Organic.meta).foregroundStyle(Organic.n600)
                    }
                    Spacer(minLength: 8)
                    let p = store.profit(item)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(store.signed(p))
                            .font(Organic.rowValue)
                            .foregroundStyle(p < 0 ? Organic.a800 : Organic.s700)
                        if item.pointsEarned > 0 {
                            Text("+\(item.pointsEarned.formatted()) pt")
                                .font(Organic.meta).foregroundStyle(Organic.s700)
                        }
                    }
                }
                .padding(.vertical, 8)
                .overlay(alignment: .top) { Hairline() }
            }
        }
    }

    /// Newest sale first, through the one filter in `Finance` — so this list
    /// holds exactly the sales the figures above it counted.
    private var soldItems: [Item] {
        store.items(status: .sold, period: period, sort: .newest)
    }
}
