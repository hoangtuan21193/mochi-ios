import SwiftUI
import Charts

/// Net worth: what you have against what you owe, and how that has moved
/// month by month over the stretch chosen at the top. One reading a month,
/// from the snapshots — a month the app was not opened in stays empty rather
/// than being guessed. The line is net worth alone: drawing it by type would
/// put cash over time back on screen (decision #3).
struct NetWorthView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @AppStorage("networth.range") private var range: Finance.NetWorthRange = .year

    var body: some View {
        let w = store.netWorth
        let series = store.netWorthSeries(range)
        ScrollView {
            VStack(alignment: .leading, spacing: Organic.Space.l) {
                TileGrid {
                    Tile(label: "Net worth", value: store.format(w.total), sub: String(localized: "Today"))
                    Tile(label: "Since \(series.since?.formatted(.dateTime.month(.wide)) ?? "—")",
                         value: series.change.map(store.signed) ?? "—",
                         sub: String(localized: "\(series.readings) monthly readings"),
                         valueColor: (series.change ?? 0) >= 0 ? Organic.s700 : Organic.a700)
                    Tile(label: "Assets", value: store.format(w.assets))
                    Tile(label: "Owed", value: store.format(w.liabilities), valueColor: Organic.a700)
                }
                chart(series)
                ListHeading(title: "What you have", trailing: store.format(w.assets))
                Card(padding: .list) {
                    ListRow(title: String(localized: "Cash"), sub: String(localized: "\(store.data.wallets.count) accounts · typed from the bank"),
                            value: store.format(w.cash), mark: dot(2))
                    Button { router.open(.belongings) } label: {
                        ListRow(title: String(localized: "Belongings"), sub: String(localized: "\(store.unsold.count) things at what they’d sell for"),
                                value: store.format(w.inventory), mark: dot(0))
                    }
                    .overlay(alignment: .top) { Hairline() }
                    NavigationLink { InvestmentsView() } label: {
                        ListRow(title: String(localized: "Investments"), sub: String(localized: "Typed from the broker’s statement"),
                                value: store.format(w.investments), mark: dot(5))
                    }
                    .overlay(alignment: .top) { Hairline() }
                    NavigationLink { PeopleView() } label: {
                        ListRow(title: String(localized: "Owed to you"),
                                sub: store.peopleOwingYou == 1 ? String(localized: "1 person") : String(localized: "\(store.peopleOwingYou) people"),
                                value: store.format(w.receivables), mark: dot(1))
                    }
                    .overlay(alignment: .top) { Hairline() }
                }
                .buttonStyle(.plain)
                ListHeading(title: "What you owe", trailing: store.format(w.liabilities))
                Card(padding: .list) {
                    ListRow(title: String(localized: "Card statements"), sub: statementsLine,
                            value: store.format(w.cardDebt), valueColor: Organic.a700)
                    ListRow(title: String(localized: "On cards, not billed yet"),
                            sub: store.largestUnbilledPurchase.map { String(localized: "Includes the \(store.format($0.buyPrice)) \($0.name)") },
                            value: store.format(w.unbilledCharges), valueColor: Organic.a700)
                        .overlay(alignment: .top) { Hairline() }
                    ListRow(title: String(localized: "Instalment plans"),
                            sub: String(localized: "\(store.openInstallments.count) plans · fees not yet due left out"),
                            value: store.format(w.installmentPrincipal), valueColor: Organic.a700)
                        .overlay(alignment: .top) { Hairline() }
                    if w.loansYouOwe > 0 {
                        ListRow(title: String(localized: "People you owe"), value: store.format(w.loansYouOwe), valueColor: Organic.a700)
                            .overlay(alignment: .top) { Hairline() }
                    }
                }
                HelpText("\(store.pointsHeld.formatted()) pt in point wallets are listed apart and never added. Loans in đồng stay out of this figure.")
                    .padding(.horizontal, 4)
            }
            .padding(Organic.Space.gutter)
            .readableWidth()
        }
        .background(Organic.bg)
        .navigationTitle("Net worth")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                DropdownPill(value: Text(rangeName(range)), compact: true) {
                    ForEach(Finance.NetWorthRange.allCases, id: \.self) { r in
                        Button { range = r } label: {
                            if r == range { Label { Text(rangeName(r)) } icon: { Image(systemName: "checkmark") } } else { Text(rangeName(r)) }
                        }
                    }
                }
            }
        }
    }

    private func rangeName(_ r: Finance.NetWorthRange) -> LocalizedStringKey {
        switch r { case .year: "This year"; case .twelveMonths: "12 months"; case .all: "Every reading" }
    }

    /// "Rakuten ¥142,300 · SMBC ¥125,900": the statements still open.
    private var statementsLine: String? {
        let open = store.cardLines.filter { $0.statement > 0 }
        return open.isEmpty ? nil : open.map { "\($0.card.name) \(store.format($0.statement))" }.joined(separator: " · ")
    }

    private func dot(_ i: Int) -> LeadMark {
        LeadMark(glyph: .symbol("circle.fill"), tint: .clear, ink: Organic.chartColor(i), size: 14)
    }

    /// Readings as ringed points on a line, a price on the left so the climb
    /// can be read. The one wealth line the app draws: cash alone is not wealth.
    private func chart(_ s: Finance.NetWorthSeries) -> some View {
        Card {
            Text("Over time").font(Organic.title)
            if s.readings < 2 {
                Text("One reading a month, taken when you open Mochi. The line starts once there are two.")
                    .font(Organic.value).foregroundStyle(Organic.n600).padding(.top, 6)
            } else {
                // The fill starts at the lowest reading, not at zero: a
                // climb from ¥950,000 to ¥1.26M drawn from zero is a flat line.
                let low = s.points.map(\.value).min() ?? 0, high = s.points.map(\.value).max() ?? 1
                let pad = max(1, (high - low) / 5)
                Chart {
                    ForEach(s.points, id: \.month) { p in
                        AreaMark(x: .value("Month", p.month), yStart: .value("Floor", low - pad), yEnd: .value("Net worth", p.value))
                            .foregroundStyle(Organic.infoSoft)
                        LineMark(x: .value("Month", p.month), y: .value("Net worth", p.value))
                            .foregroundStyle(Organic.info).lineStyle(StrokeStyle(lineWidth: 2.5))
                        PointMark(x: .value("Month", p.month), y: .value("Net worth", p.value))
                            .symbol { Circle().strokeBorder(Organic.info, lineWidth: 2).background(Circle().fill(Organic.n100)).frame(width: 9, height: 9) }
                    }
                }
                .chartYScale(domain: (low - pad)...(high + pad))
                // Room at both ends so the first and last month names are not cut.
                .chartXScale(range: .plotDimension(padding: 14))
                .chartYAxis {
                    // Inside the plot, over their dashed lines, as the canvas draws them.
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { v in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 3])).foregroundStyle(Organic.n300)
                        AxisValueLabel(anchor: .bottomLeading, horizontalSpacing: 0, verticalSpacing: 2) {
                            if let n = v.as(Int.self) { Text(verbatim: "¥" + store.short(n).uppercased()).font(Organic.meta) }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated), anchor: .top).font(Organic.meta)
                    }
                }
                .frame(height: 180)
                .padding(.top, 8)
                Text("One reading a month, taken when you open Mochi. A month the app wasn’t opened stays empty.")
                    .font(Organic.caption).foregroundStyle(Organic.n600).padding(.top, 6)
            }
        }
    }
}
