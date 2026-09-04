import SwiftUI

/// Tab 2. The list of things you own — some for resale, some kept.
/// Header carries three round icon buttons: categories, export, add.
struct InventoryView: View {
    @Environment(Store.self) private var store
    @State private var filter: Filter = .inStock
    @State private var showCategories = false
    @State private var showExport = false
    @State private var editing: Item? = nil
    @State private var addingNew = false

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
                        summaryTile("Spent (for sale)", store.format(store.inventoryCost), Organic.n100, Organic.text)
                        summaryTile("Sell-all proceeds", store.format(store.liquidation), Organic.s100, Organic.s900)
                        summaryTile("Expected profit", store.format(store.expectedProfit), Organic.s100,
                                    store.expectedProfit < 0 ? Organic.a800 : Organic.s900)
                    }
                    Text("Items marked Keeping are excluded from these numbers: \(store.keeping.count).")
                        .font(.system(size: 11)).foregroundStyle(Organic.n600)
                        .padding(.horizontal, 2).padding(.vertical, 10)

                    HStack(spacing: 6) {
                        ForEach(Filter.allCases, id: \.self) { f in
                            Button { filter = f } label: { Chip(label: f.rawValue, selected: filter == f) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 12)

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
                    iconButton("tag") { showCategories = true }
                    iconButton("square.and.arrow.up") { showExport = true }
                    iconButton("plus", filled: true) { addingNew = true }
                }
            }
            .sheet(isPresented: $showCategories) { CategoryManagerView() }
            .sheet(isPresented: $showExport) { ExportView() }
            .sheet(isPresented: $addingNew) { ItemEditorView(item: nil) }
        }
    }

    private func iconButton(_ symbol: String, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .heavy))
                .frame(width: 29, height: 29)
                .background(filled ? Organic.accent : Organic.n200, in: Circle())
                .foregroundStyle(filled ? .white : Organic.n800)
        }
    }

    private func summaryTile(_ label: String, _ value: String, _ fill: Color, _ fg: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11)).foregroundStyle(Organic.n700)
            Text(value).font(.system(size: 14, weight: .heavy)).foregroundStyle(fg)
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(_ item: Item) -> some View {
        Card(padding: EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(.system(size: 14, weight: .heavy)).lineLimit(2)
                    HStack(spacing: 6) {
                        if !item.categoryName.isEmpty {
                            Text(item.categoryName).font(.system(size: 9.5, weight: .bold))
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Organic.n200, in: Capsule())
                                .foregroundStyle(Organic.n700)
                        }
                        Text("\(item.cardName) · \(item.plannedChannel)")
                            .font(.system(size: 11)).foregroundStyle(Organic.n600)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(store.format(item.sale?.price ?? item.estimatedPrice))
                        .font(.system(size: 14.5, weight: .heavy))
                    let net = item.sale?.net ?? store.netProceeds(item, channelName: item.plannedChannel)
                    let profit = net - item.buyPrice
                    Text((profit >= 0 ? "+" : "") + store.format(profit))
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(profit < 0 ? Organic.a800 : Organic.s700)
                }
            }
        }
    }
}
