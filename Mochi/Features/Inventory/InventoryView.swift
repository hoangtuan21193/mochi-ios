import SwiftUI

/// Tab 2. The list of things you own — some for resale, some kept.
/// Header carries three round icon buttons: categories, export, add.
struct InventoryView: View {
    @Environment(Store.self) private var store
    @State private var status: Finance.ItemStatus = .forSale
    @State private var sort: Finance.ItemSort = .newest
    @State private var period: Finance.Period = .all
    @State private var editing: Item? = nil
    /// What was typed into the search field. Empty matches everything.
    @State private var query = ""
    /// Whether the field is out. Closing it clears the query: a list filtered
    /// by words nothing on screen shows is a list nobody can explain.
    @State private var searching = false
    /// The sort and the period are folded away until asked for: most days the
    /// question is "what is for sale", and three controls on top of the list
    /// would answer a question nobody asked.
    @State private var browsing = false

    /// One sheet slot for the screen: separate `.sheet` modifiers stacked on the
    /// same view do not reliably coexist.
    @State private var sheet: InventorySheet?

    enum InventorySheet: String, Identifiable {
        case categories, importItems, export, newItem
        var id: String { rawValue }
    }

    /// Read once: the tile, its colour and the help line all ask the same
    /// question.
    private var pointsFromSelling: Int { store.pointsFromSelling }

    /// Filtered and ordered by `Finance`, so nothing here sorts a list itself.
    private var rows: [Item] { store.items(status: status, period: period, sort: sort, search: query) }

    /// How many names the query finds that the status or the date is hiding.
    /// Search stays inside the filters — chips that lie about what is on
    /// screen are worse than a search that finds nothing — so the screen says
    /// out loud when the thing being looked for is one chip away.
    /// Said under the field while it is open, and only then: the number is
    /// about what was typed, so it belongs beside the typing.
    private var searchNote: LocalizedStringKey? {
        hiddenMatches > 0 ? "Matches hidden by the status or date you picked: \(hiddenMatches)." : nil
    }

    private var hiddenMatches: Int {
        guard !query.isEmpty else { return 0 }
        return store.items(status: .all, period: .all, sort: sort, search: query).count - rows.count
    }

    private func statusName(_ s: Finance.ItemStatus) -> LocalizedStringKey {
        switch s {
        case .forSale: "For sale"
        case .keeping: "Keeping"
        case .sold: "Sold"
        case .all: "Everything"
        }
    }

    /// What each order means, said plainly. "Most profit" beats "profit
    /// descending" for someone deciding what to list next.
    private func sortName(_ s: Finance.ItemSort) -> LocalizedStringKey {
        switch s {
        case .newest: "Newest first"
        case .oldest: "Oldest first"
        case .priceHigh: "Highest price"
        case .priceLow: "Lowest price"
        case .profitHigh: "Most profit"
        case .profitLow: "Biggest loss"
        case .points: "Most points"
        case .fastest: "Sold fastest"
        case .slowest: "Sold slowest"
        }
    }

    private func periodName(_ p: Finance.Period) -> LocalizedStringKey {
        switch p {
        case .all: return "Any date"
        case .year(let y): return "All of \(String(y))"
        case .month:
            guard let start = p.start else { return "" }
            return "\(start.formatted(.dateTime.month(.wide).year()))"
        }
    }

    private func monthsIn(_ year: Int) -> [Finance.Period] {
        store.monthsWithActivity.filter {
            if case .month(let y, _) = $0 { return y == year }
            return false
        }
    }

    /// A tick beside the one in force.
    @ViewBuilder
    private func menuLabel(_ title: LocalizedStringKey, chosen: Bool) -> some View {
        if chosen { Label { Text(title) } icon: { Image(systemName: "checkmark") } } else { Text(title) }
    }

    /// Status stays chips — four short words, one row, and it is the switch
    /// that gets used every time. Sort and date are menus: nine orders and
    /// every month of every year are far past what chips can hold without
    /// wrapping into a broken block.
    private var browseControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            ChipPicker(options: Finance.ItemStatus.allCases.map(\.rawValue),
                       selection: status.rawValue,
                       display: { Text(statusName(Finance.ItemStatus(rawValue: $0) ?? .all)) }) { picked in
                if let s = Finance.ItemStatus(rawValue: picked) { status = s }
            }
            if browsing {
                DropdownRow(label: "Sort", value: Text(sortName(sort))) {
                    ForEach(Finance.ItemSort.allCases, id: \.self) { s in
                        Button { sort = s } label: { menuLabel(sortName(s), chosen: sort == s) }
                    }
                }
                DropdownRow(label: "Date", value: Text(periodName(period))) {
                    Button { period = .all } label: {
                        menuLabel("Any date", chosen: period == .all)
                    }
                    ForEach(store.yearsWithActivity, id: \.self) { y in
                        Menu(String(y)) {
                            Button { period = .year(y) } label: {
                                menuLabel("All of \(String(y))", chosen: period == .year(y))
                            }
                            ForEach(monthsIn(y), id: \.self) { m in
                                Button { period = m } label: {
                                    menuLabel(periodName(m), chosen: period == m)
                                }
                            }
                        }
                    }
                }
                HelpText("Sold items are dated by the day they sold; everything else by the day it was bought.")
                    .padding(.top, 2)
            }
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
                    // Its own row, in the point colour, because it is not the
                    // same kind of number as the three above: a MapCamera
                    // trade-in pays no yen at all, so its price is here and
                    // nowhere in "Sell-all proceeds".
                    if pointsFromSelling > 0 {
                        Metric(label: "Points if sold", value: String(localized: "+\(pointsFromSelling) pt"),
                               valueColor: Organic.a900, labelColor: Organic.a900,
                               large: true, boxed: true, fill: Organic.a100)
                            .padding(.top, 8)
                    }
                    HelpText(pointsFromSelling > 0
                             ? "Items marked Keeping are excluded from these numbers: \(store.keeping.count). Stock planned for a point channel pays points, not yen, so its price is only in the points line."
                             : "Items marked Keeping are excluded from these numbers: \(store.keeping.count).")
                        .padding(.horizontal, 2).padding(.vertical, 10)

                    // Header first, so the count and the way in to sorting sit
                    // above the controls they govern.
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(rows.count) items").font(Organic.title)
                        Spacer()
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { browsing.toggle() }
                        } label: {
                            LinkLabel(browsing ? "Hide sorting" : "Sort and filter")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 2).padding(.bottom, 8)

                    browseControls
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
            .safeAreaInset(edge: .bottom) {
                if searching {
                    SearchDock("Search by name", text: $query, note: searchNote) { cancelSearch() }
                }
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Filled while a query is in force, because the field
                    // itself is put away and the shortened list would
                    // otherwise have nothing to explain it.
                    IconButton(symbol: "magnifyingglass", filled: !query.isEmpty) {
                        if searching { cancelSearch() } else { searching = true }
                    }
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

    private func cancelSearch() {
        query = ""
        searching = false
    }

    private var emptyMessage: LocalizedStringKey {
        if !query.isEmpty { return "No name matches what you typed." }
        if store.data.items.isEmpty {
            return "No items yet. The + button adds one — its price goes onto the card you bought it with."
        }
        // A date filter is the likeliest reason a non-empty book shows nothing,
        // and saying "nothing sold yet" then would be a lie.
        if period != .all { return "Nothing here for the date you picked. Widen it to Any date to see the rest." }
        switch status {
        case .forSale: return "Nothing for sale right now."
        case .keeping: return "Nothing marked Keeping. Items you intend to keep are excluded from every resale number."
        case .sold: return "Nothing sold yet. Confirm a sale from an item's page and it moves here."
        case .all: return "Nothing matches."
        }
    }

    private func row(_ item: Item) -> some View {
        Card {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).font(Organic.title).lineLimit(2)
                        .copyOnLongPress(item.name)
                    HStack(spacing: 6) {
                        if !item.categoryName.isEmpty {
                            Badge(verbatim: item.categoryName, tone: .neutral)
                        }
                        // "Sold in 34 days" is what makes the fastest and
                        // slowest orders readable: without it the list is in
                        // an order nothing on the row explains.
                        let held = store.daysHeld(item).map { String(localized: "sold in \($0) days") } ?? ""
                        let meta = metaLine(item.cardName,
                                            item.keep && item.plannedChannel.isEmpty
                                                ? "keeping" : item.plannedChannel,
                                            held)
                        if !meta.isEmpty {
                            Text(meta).font(Organic.caption).foregroundStyle(Organic.n600)
                        }
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(store.format(item.sale?.price ?? item.estimatedPrice))
                        .font(Organic.title)
                    let profit = store.profit(item)
                    Text(store.signed(profit))
                        .font(Organic.captionStrong)
                        .foregroundStyle(profit < 0 ? Organic.a800 : Organic.s700)
                    // A trade-in pays no yen, so the cash line above it is the
                    // purchase going out and nothing coming back. On its own
                    // that reads as a disaster; the points are the other half.
                    let points = store.pointsOnSale(item)
                    if points > 0 {
                        Text("+\(points) pt")
                            .font(Organic.meta).foregroundStyle(Organic.a900)
                    }
                }
            }
        }
    }
}
