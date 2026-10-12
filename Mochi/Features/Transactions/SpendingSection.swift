import SwiftUI

/// Where a period's money went: four figures, the shares by category, shop or
/// place drawn three ways, what went into belongings instead, and six months
/// side by side. Belongings bought are kept out of the total and said so
/// underneath. Every figure comes from `Finance.spendingSummary`;
/// docs/design/spending.md.
struct SpendingSection: View {
    @Environment(Store.self) private var store
    /// Any day inside the period on screen.
    @Binding var date: Date
    /// How long a period is, and how the shares are drawn, are the reader's
    /// habit rather than the book's, so they live in the app's defaults.
    @AppStorage("spending.period") private var period: Finance.SpendingPeriod = .month
    @AppStorage("spending.chart") private var chart: ChartStyle = .ring
    @State private var split: Finance.SpendingSplit = .categories

    enum ChartStyle: String, CaseIterable { case ring, columns, flow }

    /// A pay period chosen before the salary was deleted falls back to the month.
    private var current: Finance.SpendingPeriod { store.spendingPeriods.contains(period) ? period : .month }

    var body: some View {
        let sum = store.spendingSummary(current, containing: date, by: split)
        return VStack(alignment: .leading, spacing: Organic.Space.l) {
            HStack {
                PeriodStepper(title: title(sum.interval), back: { date = sum.previousInterval.start },
                              forward: store.nextSpendingInterval(current, after: sum.interval).map { next in { date = next.start } })
                Spacer()
                if store.spendingPeriods.count > 1 {
                    DropdownPill(value: Text(periodName(current)), compact: true) {
                        ForEach(store.spendingPeriods, id: \.self) { p in
                            Button { period = p } label: {
                                if p == current { Label { Text(periodName(p)) } icon: { Image(systemName: "checkmark") } } else { Text(periodName(p)) }
                            }
                        }
                    }
                }
            }
            TileGrid {
                Tile(label: "Spent", value: store.format(sum.spent))
                Tile(label: "Against \(previousName(sum.previousInterval))", value: sum.change.map(store.signed) ?? "—",
                     valueColor: (sum.change ?? 0) <= 0 ? Organic.s700 : Organic.a700)
                Tile(label: "Largest", value: sum.largest?.name ?? "—",
                     sub: sum.largest.map { String(localized: "\($0.percent)% of spending") })
                Tile(label: "Per day", value: store.format(sum.perDay), sub: String(localized: "\(sum.days) days"))
            }
            whereItWent(sum)
            if sum.belongingBuys > 0 || store.belongingsMonthlyCost > 0 {
                AsideStrip(lines: [.init(label: "Bought as belongings · not in the total", value: store.format(sum.belongingBuys))]
                    // Only a loss belongs beside spending; a gain is not money spent.
                    + (store.belongingsMonthlyCost > 0
                       ? [.init(label: "Value your belongings lost this month", value: store.format(store.belongingsMonthlyCost))] : []))
            }
            trend
        }
    }

    // MARK: - Where it went

    private func whereItWent(_ sum: Finance.SpendingSummary) -> some View {
        let shares = sum.shares.map { ChartShare(name: $0.name, amount: $0.amount, color: Organic.chartColor($0.colorIndex), symbol: $0.symbol) }
        return Card {
          VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Where it went").font(Organic.title)
                Spacer()
                SegmentedTabs(options: Finance.SpendingSplit.allCases, selection: $split, compact: true) { s in
                    switch s { case .categories: "Categories"; case .shops: "Shops"; case .places: "Places" }
                }
            }
            if shares.isEmpty {
                EmptyNote("Nothing spent in this period yet.")
            } else {
                switch chart {
                case .ring:
                    ShareRing(shares: Array(shares.prefix(8)), total: store.format(sum.spent))
                case .columns:
                    ShareColumns(shares: Array(shares.prefix(7)), short: store.short)
                    caption(columnsLine(sum.interval))
                case .flow:
                    flow(sum, shares: shares)
                }
                IconSegments(options: ChartStyle.allCases, selection: $chart) { c in
                    switch c { case .ring: "chart.pie"; case .columns: "chart.bar.xaxis"; case .flow: "arrow.triangle.branch" }
                } label: { c in
                    switch c { case .ring: "Show as ring"; case .columns: "Show as columns"; case .flow: "Show as flow" }
                }
                .frame(maxWidth: .infinity)
              VStack(spacing: 0) {
                ForEach(Array(sum.shares.prefix(8))) { s in
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Circle().fill(Organic.chartColor(s.colorIndex)).frame(width: 10, height: 10)
                            Text(verbatim: s.name).font(Organic.row).lineLimit(1)
                            Spacer()
                            Text(verbatim: store.format(s.amount)).font(Organic.rowValue)
                            // A share that rounds to nothing is still there.
                            Text(verbatim: s.percent == 0 ? "<1%" : "\(s.percent)%").font(Organic.caption)
                                .foregroundStyle(Organic.n600).frame(width: 36, alignment: .trailing)
                        }
                        ProgressBar(fraction: Double(s.amount) / Double(max(sum.largest?.amount ?? 1, 1)),
                                    tint: Organic.chartColor(s.colorIndex))
                    }
                    .padding(.vertical, 8)
                    .overlay(alignment: .top) { Hairline() }
                }
              }
            }
          }
        }
    }

    @ViewBuilder
    private func flow(_ sum: Finance.SpendingSummary, shares: [ChartShare]) -> some View {
        let f = store.incomeFlow(in: sum.interval, shares: sum.shares)
        if f.income == 0 {
            EmptyNote("No income booked in \(shortName(sum.interval)), so there is nothing to follow. The ring and the columns still show where it went.")
        } else {
            let sources = [FlowChart.Node(name: String(localized: "Income"), value: store.format(f.income), amount: f.income, color: Organic.text)]
                + (f.fromSavings > 0 ? [FlowChart.Node(name: String(localized: "From what you had"), value: store.format(f.fromSavings), amount: f.fromSavings, color: Organic.n500)] : [])
            let targets = f.top.map { FlowChart.Node(name: $0.name, value: store.format($0.amount), amount: $0.amount, color: Organic.chartColor($0.colorIndex)) }
                + (f.rest.map { [FlowChart.Node(name: String(localized: "\(f.restCount) more"), value: store.format($0.amount), amount: $0.amount, color: Organic.chartColor($0.colorIndex))] } ?? [])
                + (f.leftOver > 0 ? [FlowChart.Node(name: String(localized: "Left over"), value: store.format(f.leftOver), amount: f.leftOver, color: Organic.n500)] : [])
            FlowChart(sources: sources, targets: targets)
            caption(flowLine(sum.interval))
        }
    }

    private func caption(_ text: String) -> some View {
        Text(verbatim: text).font(Organic.caption).foregroundStyle(Organic.n600)
            .multilineTextAlignment(.center).frame(maxWidth: .infinity)
    }

    // MARK: - Six months

    private var trend: some View {
        Card {
            HStack(alignment: .firstTextBaseline) {
                Text("Last six months").font(Organic.title)
                Spacer()
                Text("Tap a month to see it").font(Organic.caption).foregroundStyle(Organic.n600)
            }
            MonthBars(bars: store.monthlySpending(months: 6).map { .init(month: $0.month, amount: $0.amount) },
                      selected: date, short: store.short) { m in
                period = .month
                date = m
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Words for a period

    private func periodName(_ p: Finance.SpendingPeriod) -> LocalizedStringKey {
        switch p { case .month: "Month"; case .payPeriod: "Pay period"; case .year: "Year" }
    }

    /// "September 2026", "25 Sep – 24 Oct", "2026".
    private func title(_ i: DateInterval) -> String {
        switch current {
        case .month: return i.start.formatted(.dateTime.month(.wide).year())
        case .year: return i.start.formatted(.dateTime.year())
        case .payPeriod: return lastDayRange(i)
        }
    }

    /// The period on its own, inside a sentence: "September", "2026".
    private func shortName(_ i: DateInterval) -> String {
        switch current {
        case .month: return i.start.formatted(.dateTime.month(.wide))
        case .year: return i.start.formatted(.dateTime.year())
        case .payPeriod: return lastDayRange(i)
        }
    }

    private func lastDayRange(_ i: DateInterval) -> String {
        let last = Calendar.current.date(byAdding: .day, value: -1, to: i.end)!
        return "\(i.start.formatted(.dateTime.day().month(.abbreviated))) – \(last.formatted(.dateTime.day().month(.abbreviated)))"
    }

    /// "Against August", "Against the last pay period", "Against 2025".
    private func previousName(_ i: DateInterval) -> String {
        switch current {
        case .payPeriod: return String(localized: "the last pay period")
        default: return shortName(i)
        }
    }

    private func columnsLine(_ i: DateInterval) -> String {
        let name = shortName(i)
        switch split {
        case .categories: return String(localized: "\(name), one column a category. Names and shares are in the list below.")
        case .shops: return String(localized: "\(name), one column a shop. Names and shares are in the list below.")
        case .places: return String(localized: "\(name), one column a place. Names and shares are in the list below.")
        }
    }

    private func flowLine(_ i: DateInterval) -> String {
        String(localized: "\(shortName(i))’s income, followed to where it went. Belongings bought are not in it.")
    }
}
