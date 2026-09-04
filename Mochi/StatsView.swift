import SwiftUI

/// Tab 3. Month / year profit and the sold-item history.
struct StatsView: View {
    @Environment(Store.self) private var store
    @State private var year = Calendar.current.component(.year, from: .now)

    private var sold: [Item] {
        store.data.items.filter {
            guard let s = $0.sale else { return false }
            return Calendar.current.component(.year, from: s.date) == year
        }
    }
    private var revenue: Int { sold.reduce(0) { $0 + ($1.sale?.net ?? 0) } }
    private var profit: Int { sold.reduce(0) { $0 + ($1.sale?.net ?? 0) - $1.buyPrice } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Metric(label: "Sold", value: "\(sold.count)", boxed: true)
                        Metric(label: "Revenue", value: store.format(revenue), boxed: true)
                        Metric(label: "Profit", value: store.format(profit), boxed: true)
                    }
                    Card {
                        Text("Sold items").font(Organic.title).padding(.bottom, 4)
                        if sold.isEmpty {
                            Text("Nothing sold in \(String(year)). Confirming a sale from an item's page files it here.")
                                .font(Organic.value).foregroundStyle(Organic.n600).padding(.vertical, 6)
                        }
                        ForEach(sold) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(Organic.row)
                                    Text("\(item.sale?.channel ?? "") · \(item.sale?.date.formatted(date: .numeric, time: .omitted) ?? "")")
                                        .font(Organic.meta).foregroundStyle(Organic.n600)
                                }
                                Spacer()
                                let p = (item.sale?.net ?? 0) - item.buyPrice
                                Text((p >= 0 ? "+" : "") + store.format(p))
                                    .font(Organic.rowValue)
                                    .foregroundStyle(p < 0 ? Organic.a800 : Organic.s700)
                            }
                            .padding(.vertical, 8)
                            .overlay(alignment: .top) { Hairline() }
                        }
                    }
                    activityCard
                }
                .padding(16)
            }
            .background(Organic.bg)
            .navigationTitle("Stats")
        }
    }

    /// Every movement of money, newest first. Buying, selling, paying a card,
    /// moving between wallets and hand-corrections all land here — it is the
    /// only place to see why a balance changed.
    private var activityCard: some View {
        Card {
            Text("Activity").font(Organic.title).padding(.bottom, 4)
            if store.data.ledger.isEmpty {
                Text("Nothing has moved yet.")
                    .font(Organic.value).foregroundStyle(Organic.n600).padding(.vertical, 6)
            }
            ForEach(store.recentLedger.prefix(40)) { entry in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.label).font(Organic.row)
                        Text("\(entry.date.formatted(date: .numeric, time: .shortened)) · \(entry.detail)")
                            .font(Organic.meta).foregroundStyle(Organic.n600)
                    }
                    Spacer()
                    if entry.amount != 0 {
                        Text((entry.amount > 0 ? "+" : "") + store.format(entry.amount))
                            .font(Organic.rowValue)
                            .foregroundStyle(entry.kind == "x" ? Organic.n700
                                             : (entry.amount < 0 ? Organic.a800 : Organic.s700))
                    }
                }
                .padding(.vertical, 8)
                .overlay(alignment: .top) { Hairline() }
            }
        }
    }
}
