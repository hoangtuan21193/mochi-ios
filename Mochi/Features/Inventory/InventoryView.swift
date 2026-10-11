import SwiftUI

/// Belongings. What you own, what it is worth, and what it really costs you
/// a month — the price less what it would fetch, spread over the months it
/// has been yours. Some are kept, some may be sold; sold ones stay with the
/// cost they came to.
struct InventoryView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var status: Finance.ItemStatus = .forSale
    /// What would make most if sold now, first: the list is where the next
    /// listing is chosen.
    @State private var sort: Finance.ItemSort = .profitHigh
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var period: Finance.Period = .all
    @State private var editing: Item? = nil
    /// What was typed into the search field. Empty matches everything.
    @State private var query = ""
    /// Whether the field is out. Closing it clears the query: a list filtered
    /// by words nothing on screen shows is a list nobody can explain.
    @State private var searching = false

    /// One sheet slot for the screen: separate `.sheet` modifiers stacked on the
    /// same view do not reliably coexist.
    @State private var sheet: InventorySheet?

    enum InventorySheet: String, Identifiable {
        case categories, importItems, newItem
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

    /// What each list is for, with how many it holds: the question asked of
    /// this tab is "what can I sell", so that comes first.
    private func statusName(_ s: Finance.ItemStatus) -> String {
        let n = store.items(status: s, period: .all, sort: .newest, search: "").count
        switch s {
        case .forSale: return String(localized: "To sell · \(n)")
        case .keeping: return String(localized: "To use · \(n)")
        case .sold: return String(localized: "Sold")
        case .owned: return String(localized: "Have · \(n)")
        case .all: return String(localized: "Everything")
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
        // On what has sold the profit is made, not "now".
        case .profitHigh: status == .sold ? "Most profit" : "Profit now"
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

    /// Three lists as chips, and one menu for the order (and, for what has
    /// sold, the dates). The order is named on the menu itself — "Profit
    /// now" — so the list says how it is sorted without opening anything.
    private var browseControls: some View {
        HStack(alignment: .center, spacing: Organic.Space.m) {
            ChipPicker(options: [Finance.ItemStatus.forSale, .keeping, .sold].map(\.rawValue),
                       selection: status.rawValue,
                       display: { Text(verbatim: statusName(Finance.ItemStatus(rawValue: $0) ?? .all)) }) { picked in
                if let s = Finance.ItemStatus(rawValue: picked) {
                    status = s
                    if s != .sold { period = .all }
                    // An order that means nothing on this list gives way to the first that does.
                    if !sorts.contains(sort) { sort = sorts[0] }
                }
            }
            Spacer(minLength: 0)
            DropdownPill(value: Text(sortName(sort)), compact: true) {
                ForEach(sorts, id: \.self) { s in
                    Button { sort = s } label: { menuLabel(sortName(s), chosen: sort == s) }
                }
                if status == .sold {
                    Divider()
                    Menu {
                        Button { period = .all } label: { menuLabel("Any date", chosen: period == .all) }
                        ForEach(store.yearsWithActivity, id: \.self) { y in
                            Menu(String(y)) {
                                Button { period = .year(y) } label: {
                                    menuLabel("All of \(String(y))", chosen: period == .year(y))
                                }
                                ForEach(monthsIn(y), id: \.self) { m in
                                    Button { period = m } label: { menuLabel(periodName(m), chosen: period == m) }
                                }
                            }
                        }
                    } label: { Text("Sold when · \(Text(periodName(period)))") }
                }
            }
        }
    }

    /// The orders that mean something on the list shown: nothing is profit
    /// "now" once it has sold, and only what has sold sold fast or slow.
    private var sorts: [Finance.ItemSort] {
        switch status {
        case .forSale: return [.profitHigh, .profitLow, .newest, .oldest, .priceHigh, .priceLow, .points]
        case .keeping: return [.newest, .oldest, .priceHigh, .priceLow, .points]
        default: return [.newest, .oldest, .profitHigh, .profitLow, .fastest, .slowest, .priceHigh, .priceLow]
        }
    }

    /// The four figures over the list, for the list it is.
    @ViewBuilder private var tiles: some View {
        switch status {
        case .sold:
            let sum = store.summary(for: period)
            // With points, as the rows are: a cash-only figure here would not add up to them.
            let made = store.profitWithPoints(for: period)
            TileGrid {
                Tile(label: "Sold", value: "\(sum.soldCount)", sub: sum.averageDaysHeld.map { String(localized: "about \($0) days each") })
                Tile(label: "Brought in", value: store.format(sum.revenue), sub: String(localized: "after fees and postage"))
                Tile(label: "Profit", value: store.signed(made.total),
                     sub: String(localized: "cash \(store.signed(made.cash)) · points +\(made.points.formatted())"),
                     valueColor: made.total < 0 ? Organic.a700 : Organic.s700)
                Tile(label: "Points on buys", value: "\(sum.points.formatted()) pt", sub: String(localized: "never counted as cash"))
            }
        case .keeping:
            TileGrid {
                // Everything owned, to sell and to use: what it is worth and costs a month.
                Tile(label: "Worth now", value: store.format(store.belongingsWorth),
                     sub: String(localized: "all \(store.unsold.count) things you own"))
                Tile(label: "You paid", value: store.format(store.belongingsPaid),
                     sub: String(localized: "+ \(Finance.pointsOnBelongings(store.data).formatted()) pt back"))
                // Worth more than was paid is a gain, said as one.
                if store.belongingsMonthlyCost < 0 {
                    Tile(label: "Gained a month", value: store.format(-store.belongingsMonthlyCost),
                         sub: String(localized: "Worth more now than you paid"), valueColor: Organic.s700)
                } else {
                    Tile(label: "Real cost a month", value: store.format(store.belongingsMonthlyCost),
                         sub: String(localized: "Value lost, spread out"))
                }
                profitThisYearTile
            }
        default:
            let o = store.resaleOutlook
            TileGrid {
                Tile(label: "You paid for these", value: store.format(o.paid),
                     sub: String(localized: "+ \(o.pointsBack.formatted()) pt back"))
                Tile(label: "Would bring now", value: store.format(o.wouldBring),
                     sub: String(localized: "after fees, postage, withdrawing"))
                Tile(label: "If all sold now", value: store.signed(o.ifAllSold.total),
                     sub: String(localized: "cash \(store.signed(o.ifAllSold.cash)) · points +\(o.ifAllSold.points.formatted())"),
                     valueColor: o.ifAllSold.total < 0 ? Organic.a700 : Organic.s700)
                profitThisYearTile
            }
        }
    }

    private var profitThisYearTile: some View {
        let p = store.profitThisYear
        return Tile(label: "Profit this year", value: store.signed(p.result.total),
                    sub: String(localized: "\(p.sold) sold · points included"),
                    valueColor: p.result.total < 0 ? Organic.a700 : Organic.s700)
    }

    private var footnote: LocalizedStringKey {
        switch status {
        case .forSale: "Profit if sold now: after the fee, postage and withdrawing, with the points from buying at ¥1 each. Worth is your own figure; sold prices you look up never change it."
        case .sold: "Profit on what sold: what came in after the fee and postage, less what you paid, with the points from buying at ¥1 each."
        default: "Worth is your own figure. Update it from Mercari 持ち物査定 or a shop’s trade-in price; each one is kept so a thing’s page can draw what it lost."
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                // Wide screens: Buy advice and the totals on the left, the
                // things themselves on the right.
                AdaptiveColumns(spacing: 0) {
                    // The way in before buying the next one, above what is owned now.
                    NavigationLink { BuyAdviceView() } label: {
                        Card(padding: .list) {
                            ListRow(title: String(localized: "Buy advice"),
                                    sub: String(localized: "What to pay for the next one, before you buy"),
                                    value: String(localized: "Open ›"), valueColor: Organic.accent,
                                    mark: LeadMark(glyph: .symbol("lightbulb"), tint: Organic.a100, ink: Organic.accent, round: true),
                                    strong: true)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, Organic.Space.l)
                    // On a phone the switch sits over the figures it changes;
                    // on a wide screen it heads the list in the other column.
                    if sizeClass != .regular {
                        browseControls
                            .padding(.bottom, Organic.Space.l)
                    }
                    tiles
                    if pointsFromSelling > 0, status == .forSale {
                        HelpText("Planned for a point channel: +\(pointsFromSelling) pt if sold, never counted as yen.")
                            .padding(.top, 8)
                    }
                } trailing: {
                    if sizeClass == .regular {
                        browseControls
                            .padding(.bottom, Organic.Space.l)
                    } else {
                        Spacer().frame(height: Organic.Space.l)
                    }
                    if rows.isEmpty {
                        Card {
                            Text(emptyMessage).font(Organic.value).foregroundStyle(Organic.n600)
                        }
                    } else {
                        // One card, a thing to a row.
                        Card(padding: .list) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { i, item in
                                NavigationLink { ItemDetailView(item: item) } label: { row(item) }
                                    .buttonStyle(.plain)
                                    .overlay(alignment: .top) { if i > 0 { Hairline() } }
                            }
                        }
                    }
                    HelpText(footnote)
                        .padding(.horizontal, 2).padding(.vertical, 10)
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
            }
            .background(Organic.bg)
            .safeAreaInset(edge: .bottom) {
                if searching {
                    SearchDock("Search by name", text: $query, note: searchNote) { cancelSearch() }
                }
            }
            .navigationTitle("Belongings")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Filled while a query is in force, because the field
                    // itself is put away and the shortened list would
                    // otherwise have nothing to explain it.
                    IconButton(symbol: "magnifyingglass", filled: !query.isEmpty) {
                        if searching { cancelSearch() } else { searching = true }
                    }
                    IconButton(symbol: "arrow.down.to.line") { sheet = .importItems }
                    // Kept within reach, out of the way: looked at now and then,
                    // not every time the tab opens. Export lives in Your data.
                    IconMenu(label: "More") {
                        NavigationLink { WarrantyView() } label: { Label("Warranties", systemImage: "checkmark.shield") }
                        Button { sheet = .categories } label: { Label("Categories", systemImage: "tag") }
                    }
                    IconButton(symbol: "plus", filled: true) { sheet = .newItem }
                }
            }
            .navigationDestination(isPresented: Binding(get: { router.buyAdvice }, set: { router.buyAdvice = $0 })) {
                BuyAdviceView()
            }
            #if DEBUG
            // Debug-only: `-status sold` / `-status keeping` opens on that chip,
            // so design-check can capture each list without taps.
            .onAppear {
                if let s = UserDefaults.standard.string(forKey: "status").flatMap(Finance.ItemStatus.init(rawValue:)) {
                    status = s
                    if !sorts.contains(sort) { sort = sorts[0] }
                }
            }
            #endif
            .sheet(item: $sheet) { which in
                switch which {
                case .categories: CategoryManagerView()
                case .importItems: ImportView()
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
        case .owned: return "Nothing yet. The + button adds a belonging, or scan a receipt and track a line as one."
        case .forSale: return "Nothing for sale right now."
        case .keeping: return "Nothing marked Keeping. Items you intend to keep are excluded from every resale number."
        case .sold: return "Nothing sold yet. Confirm a sale from an item's page and it moves here."
        case .all: return "Nothing matches."
        }
    }

    /// A thing: how long it has been yours and what it cost, and on the right
    /// what it would make sold now (or made, or costs a month while used).
    private func row(_ item: Item) -> some View {
        let months = Finance.monthsHeld(from: item.boughtOn, to: item.sale?.date ?? .now)
        // The Sold chip already says it sold; the line says how long it took.
        let held = item.isSold
            ? String(localized: "\(months) months · paid \(store.format(item.buyPrice))")
            : (months > 0 ? String(localized: "\(months) months · paid \(store.format(item.buyPrice))")
                          : String(localized: "This month · paid \(store.format(item.buyPrice))"))
        let value: String, valueSub: String, colour: Color
        if item.keep && !item.isSold {
            let cost = store.realCostPerMonth(item)
            value = cost.map { store.perMonth($0) } ?? String(localized: "First month")
            valueSub = String(localized: "worth \(store.format(item.estimatedPrice))")
            colour = (cost ?? 0) < 0 ? Organic.s700 : Organic.text
        } else {
            let t = store.trade(item)
            value = store.signed(t.total)
            valueSub = item.isSold ? String(localized: "sold \(store.format(item.sale?.net ?? 0))")
                                   : String(localized: "worth \(store.format(item.estimatedPrice))")
            colour = t.total < 0 ? Organic.a700 : Organic.s700
        }
        return ListRow(title: item.name, sub: held, value: value, valueSub: valueSub, valueColor: colour,
                       mark: LeadMark(glyph: .symbol(symbol(for: item)), tint: Organic.n200, ink: Organic.n600, size: 44), strong: true)
            .copyOnLongPress(item.name)
    }

    /// A symbol for the kind of thing, read from its category's name.
    private func symbol(for item: Item) -> String {
        let n = (item.categoryName + " " + item.name).lowercased()
        if n.contains("lens") || n.contains("camera") || n.contains("body") || n.contains("カメラ") { return "camera" }
        if n.contains("mac") || n.contains("laptop") || n.contains("pc") { return "laptopcomputer" }
        if n.contains("iphone") || n.contains("phone") || n.contains("pixel") { return "iphone" }
        if n.contains("jacket") || n.contains("coat") || n.contains("shirt") || n.contains("bag") { return "tshirt" }
        if n.contains("chair") || n.contains("sofa") || n.contains("desk") { return "chair" }
        if n.contains("watch") { return "applewatch" }
        return "shippingbox"
    }
}
