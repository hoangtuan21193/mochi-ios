import SwiftUI

/// What selling made over a year: the total with points, a column a month,
/// the months that sold, and the trades that made and lost the most. Opened
/// from the "Profit this month" tile on Belongings and on Home. Points are
/// in every figure, the cash part beside it (decision #27).
struct ProfitView: View {
    @Environment(Store.self) private var store
    @State private var year = Calendar.current.component(.year, from: .now)

    var body: some View {
        let months = store.profitByMonth(year: year)
        let total = store.profitWithPoints(for: .year(year))
        let sold = store.summary(for: .year(year)).soldCount
        let extremes = store.extremeTrades(year: year)
        ScrollView {
            // Wide screens: the year and its columns on the left, the months
            // and the trades on the right (decision #41).
            AdaptiveColumns {
                stepper
                Card {
                    Text("Made in \(String(year))").font(Organic.caption).foregroundStyle(Organic.n600)
                    Text(verbatim: store.signed(total.total)).font(Organic.hero)
                        .foregroundStyle(total.total < 0 ? Organic.a700 : Organic.s700)
                    Text(verbatim: String(localized: "\(sold) sold · cash \(store.signed(total.cash)) · points +\(total.points.formatted())"))
                        .font(Organic.caption).foregroundStyle(Organic.n600)
                    if sold > 0 {
                        ProfitColumns(months: months.map {
                            .init(month: $0.month, total: $0.result.total, points: $0.result.points, label: monthInitial($0.month))
                        })
                        .padding(.top, Organic.Space.m)
                        ChartLegend(.init("Cash", .bar, Organic.chartGain), .init("Points", .bar, Organic.chartGainPoints),
                                    .init("Loss", .bar, Organic.a700))
                            .padding(.top, Organic.Space.s)
                    }
                }
                if sold == 0 {
                    HelpText("Nothing sold in \(String(year)). A sale counts in the month it is dated.")
                        .padding(.horizontal, 4)
                }
            } trailing: {
                if sold > 0 {
                    ListHeading(title: "Month by month")
                    Card(padding: .list) {
                        ForEach(Array(months.filter { $0.sold > 0 }.enumerated()), id: \.element.month) { i, m in
                            ListRow(title: monthName(m.month),
                                    sub: String(localized: "\(m.sold) sold · cash \(store.signed(m.result.cash)) · points +\(m.result.points.formatted())"),
                                    value: store.signed(m.result.total),
                                    valueColor: m.result.total < 0 ? Organic.a700 : Organic.s700)
                                .overlay(alignment: .top) { if i > 0 { Hairline() } }
                        }
                    }
                    trades("Made the most", extremes.best)
                    trades("Lost the most", extremes.worst)
                    HelpText("Each sale is what came in after the fee and postage, less what was paid, with the points from buying at ¥1 each.")
                        .padding(.horizontal, 4)
                }
            }
            .padding(Organic.Space.gutter)
        }
        .background(Organic.bg)
        .navigationTitle("Profit")
        .navigationBarTitleDisplayMode(.large)
    }

    /// Only the years something sold in, and this one; no arrow past either end.
    private var stepper: some View {
        let years = store.saleYears
        let i = years.firstIndex(of: year) ?? years.count - 1
        return PeriodStepper(title: String(year),
                             back: { if i > 0 { year = years[i - 1] } },
                             forward: i < years.count - 1 ? { year = years[i + 1] } : nil)
    }

    @ViewBuilder private func trades(_ title: LocalizedStringKey, _ list: [Finance.ItemTrade]) -> some View {
        if !list.isEmpty {
            ListHeading(title: title)
            Card(padding: .list) {
                ForEach(Array(list.enumerated()), id: \.element.item.id) { i, t in
                    NavigationLink { ItemDetailView(item: t.item) } label: {
                        ListRow(title: t.item.name,
                                sub: String(localized: "Sold \(t.item.sale!.date.formatted(.dateTime.day().month())) · cash \(store.signed(t.result.cash))"),
                                value: store.signed(t.result.total),
                                valueColor: t.result.total < 0 ? Organic.a700 : Organic.s700, chevron: true)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) { if i > 0 { Hairline() } }
                }
            }
        }
    }

    private func monthName(_ m: Int) -> String {
        Calendar.current.date(from: DateComponents(year: year, month: m)).map { $0.formatted(.dateTime.month(.wide)) } ?? ""
    }

    private func monthInitial(_ m: Int) -> String {
        Calendar.current.date(from: DateComponents(year: year, month: m)).map { $0.formatted(.dateTime.month(.narrow)) } ?? ""
    }
}
