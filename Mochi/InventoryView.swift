import SwiftUI

/// Tab 2. The list of things you own — some for resale, some kept.
/// Header carries three round icon buttons: categories, export, add.
struct InventoryView: View {
    @Environment(Store.self) private var store
    @State private var filter: Filter = .inStock
    @State private var editing: Item? = nil

    /// One sheet slot for the screen: separate `.sheet` modifiers stacked on the
    /// same view do not reliably coexist.
    @State private var sheet: InventorySheet?

    enum InventorySheet: String, Identifiable {
        case categories, importItems, export, newItem
        var id: String { rawValue }
    }

    enum Filter: String, CaseIterable {
        case inStock = "For sale", keep = "Keeping", sold = "Sold"
    }

    private var rows: [Item] {
        switch filter {
        case .inStock: return store.forSale
        case .keep: return store.keeping
        case .sold: return store.data.items.filter(\.isSold)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Metric(label: "Spent (for sale)", value: store.format(store.inventoryCost),
                               labelColor: Organic.n700, large: true, boxed: true)
                        Metric(label: "Sell-all proceeds", value: store.format(store.liquidation),
                               valueColor: Organic.s900, labelColor: Organic.n700, large: true, boxed: true, fill: Organic.s100)
                        Metric(label: "Expected profit", value: store.format(store.expectedProfit),
                               valueColor: store.expectedProfit < 0 ? Organic.a800 : Organic.s900,
                               labelColor: Organic.n700, large: true, boxed: true, fill: Organic.s100)
                    }
                    HelpText("Items marked Keeping are excluded from these numbers: \(store.keeping.count).")
                        .padding(.horizontal, 2).padding(.vertical, 10)

                    ChipPicker(options: Filter.allCases.map(\.rawValue), selection: filter.rawValue) { picked in
                        if let f = Filter(rawValue: picked) { filter = f }
                    }
                    .padding(.bottom, 12)

                    if rows.isEmpty {
                        Card {
                            Text(emptyMessage).font(Organic.value).foregroundStyle(Organic.n600)
                        }
                    }
                    VStack(spacing: 10) {
                        ForEach(rows) { item in
                            NavigationLink { ItemDetailView(item: item) } label: { row(item) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
            }
            .background(Organic.bg)
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    IconButton(symbol: "tag") { sheet = .categories }
                    IconButton(symbol: "square.and.arrow.down") { sheet = .importItems }
                    IconButton(symbol: "square.and.arrow.up") { sheet = .export }
                    IconButton(symbol: "plus", filled: true) { sheet = .newItem }
                }
            }
            .sheet(item: $sheet) { which in
                switch which {
                case .categories: CategoryManagerView()
                case .importItems: ImportView()
                case .export: ExportView()
                case .newItem: ItemEditorView(item: nil)
                }
            }
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .inStock: return store.data.items.isEmpty
            ? "No items yet. The + button adds one — its price goes onto the card you bought it with."
            : "Nothing for sale right now."
        case .keep: return "Nothing marked Keeping. Items you intend to keep are excluded from every resale number."
        case .sold: return "Nothing sold yet. Confirm a sale from an item's page and it moves here."
        }
    }

    private func row(_ item: Item) -> some View {
        Card {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(Organic.title).lineLimit(2)
                    HStack(spacing: 6) {
                        if !item.categoryName.isEmpty {
                            Badge(item.categoryName, tone: .neutral, uppercase: false)
                        }
                        let meta = metaLine(item.cardName,
                                            item.keep && item.plannedChannel.isEmpty
                                                ? "keeping" : item.plannedChannel)
                        if !meta.isEmpty {
                            Text(meta).font(Organic.caption).foregroundStyle(Organic.n600)
                        }
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(store.format(item.sale?.price ?? item.estimatedPrice))
                        .font(Organic.title)
                    let net = item.sale?.net ?? store.netProceeds(item, channelName: item.plannedChannel)
                    let profit = net - item.buyPrice
                    Text((profit >= 0 ? "+" : "") + store.format(profit))
                        .font(Organic.captionStrong)
                        .foregroundStyle(profit < 0 ? Organic.a800 : Organic.s700)
                }
            }
        }
    }
}
