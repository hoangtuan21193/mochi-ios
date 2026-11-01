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
    /// The thing open beside the list on a wide screen.
    @State private var open: Item?
    /// What was typed into the search field over the list. Empty matches
    /// everything. The field is always there, so the query that shortened
    /// the list is always on screen beside it.
    @State private var query = ""

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
    /// A search looks through everything — to sell, to use and sold — because
    /// the thing being looked for is often on the list not picked; the mark on
    /// each row says which list it is on, and no chip is lit meanwhile.
    private var rows: [Item] {
        query.isEmpty ? store.items(status: status, period: period, sort: sort, search: "")
                      : store.items(status: .all, period: .all, sort: sort, search: query)
    }

    private var searchNote: LocalizedStringKey? {
        query.isEmpty ? nil : "Searching everything: to sell, to use and sold."
    }

    /// What each list is for: the question asked of this tab is "what can I
    /// sell", so that comes first. No counts: a chip whose width changed with
    /// its number pushed the row onto a second line when picked.
    private func statusName(_ s: Finance.ItemStatus) -> LocalizedStringKey {
        switch s {
        case .forSale: return "To sell"
        case .keeping: return "To use"
        case .sold: return "Sold"
        case .owned: return "Have"
        case .all: return "Everything"
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
                       selection: query.isEmpty ? status.rawValue : "",
                       display: { Text(statusName(Finance.ItemStatus(rawValue: $0) ?? .all)) }) { picked in
                // Picking a list ends the search across all of them.
                if !query.isEmpty { query = "" }
                if let s = Finance.ItemStatus(rawValue: picked) {
                    status = s
                    if s != .sold { period = .all }
                    // An order that means nothing on this list gives way to the first that does.
                    if !sorts.contains(sort) { sort = sorts[0] }
                }
            }
            // One line, always: wrapping let "Sold" drop to a second row when
            // the order's name beside it grew.
            .fixedSize(horizontal: true, vertical: false)
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
                profitThisMonthTile
            }
        default:
            // Two figures, not four: what was paid and what it would bring are
            // the halves of "if all sold now", and each row already says both.
            let o = store.resaleOutlook
            TileGrid {
                Tile(label: "If all sold now", value: store.signed(o.ifAllSold.total),
                     sub: String(localized: "cash \(store.signed(o.ifAllSold.cash)) · points +\(o.ifAllSold.points.formatted())"),
                     valueColor: o.ifAllSold.total < 0 ? Organic.a700 : Organic.s700)
                profitThisMonthTile
            }
        }
    }

    /// This month's result; the year, month by month, is a tap away.
    private var profitThisMonthTile: some View {
        let p = store.profitThisMonth
        return Button { router.openProfit() } label: {
            Tile(label: "Profit this month", value: store.signed(p.result.total),
                 sub: String(localized: "\(p.sold) sold · points included"),
                 valueColor: p.result.total < 0 ? Organic.a700 : Organic.s700)
        }
        .buttonStyle(.plain)
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
            Group {
                if sizeClass == .regular {
                    // Wide screens: the things on the left, the one opened on
                    // the right, as in Mail (decision #41). Before one is
                    // opened the right column has what the phone puts above
                    // the list: Buy advice and the totals.
                    ListDetail {
                        ScrollView { browse.padding(.horizontal, 16).padding(.bottom, 16) }
                    } detail: {
                        if let item = open, store.data.items.contains(where: { $0.id == item.id }) {
                            ItemDetailView(item: item).id(item.id)
                                .environment(\.closePane, { open = nil })
                        } else {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) { overview }
                                    .padding(.horizontal, 16).padding(.bottom, 16).readableWidth()
                            }
                        }
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            overview
                            Spacer().frame(height: Organic.Space.l)
                            browse
                        }
                        .padding(.horizontal, 16).padding(.bottom, 16)
                    }
                }
            }
            .background(Organic.bg)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Belongings")
            .toolbar {
                OwnChromeItem { IconButton(symbol: "arrow.down.to.line") { sheet = .importItems } }
                // Kept within reach, out of the way: looked at now and then,
                // not every time the tab opens. Export lives in Your data.
                OwnChromeItem {
                    IconMenu(label: "More") {
                        NavigationLink { WarrantyView() } label: { Label("Warranties", systemImage: "checkmark.shield") }
                        Button { sheet = .categories } label: { Label("Categories", systemImage: "tag") }
                    }
                }
                OwnChromeItem { IconButton(symbol: "plus", filled: true) { sheet = .newItem } }
            }
            .navigationDestination(isPresented: Binding(get: { router.buyAdvice }, set: { router.buyAdvice = $0 })) {
                BuyAdviceView()
            }
            .navigationDestination(isPresented: Binding(get: { router.profit }, set: { router.profit = $0 })) {
                ProfitView()
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
                case .importItems: ImportView().wideSheet()
                case .newItem: ItemEditorView(item: nil).wideSheet()
                }
            }
        }
    }

    /// Above the list on a phone, the right column before a thing is opened
    /// on a wide screen.
    @ViewBuilder private var overview: some View {
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
        tiles
        if pointsFromSelling > 0, status == .forSale {
            HelpText("Planned for a point channel: +\(pointsFromSelling) pt if sold, never counted as yen.")
                .padding(.top, 8)
        }
    }

    /// The switch and the search right over the list they change.
    private var browse: some View {
        VStack(alignment: .leading, spacing: 0) {
            browseControls
                .padding(.bottom, Organic.Space.m)
            VStack(alignment: .leading, spacing: Organic.Space.s) {
                SearchField("Search by name", text: $query)
                if let searchNote { HelpText(searchNote).padding(.horizontal, 2) }
            }
            .padding(.bottom, Organic.Space.m)
            if rows.isEmpty {
                Card {
                    Text(emptyMessage).font(Organic.value).foregroundStyle(Organic.n600)
                }
            } else {
                // One card, a thing to a row.
                Card(padding: .list) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, item in
                        Group {
                            if sizeClass == .regular {
                                Button { open = item } label: { row(item) }
                                    .openInDetail(open?.id == item.id)
                            } else {
                                NavigationLink { ItemDetailView(item: item) } label: { row(item) }
                            }
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .top) { if i > 0 { Hairline() } }
                    }
                }
            }
            HelpText(footnote)
                .padding(.horizontal, 2).padding(.vertical, 10)
        }
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

    /// A thing: when it was bought, then what it cost beside what it is worth
    /// (or sold for), a line each; on the right one figure with what it is
    /// under it — "−¥21,000" alone read as nothing in particular. The date is
    /// "9 months" no more (that read as how long a sale took) and follows the
    /// phone's own date format.
    private func row(_ item: Item) -> some View {
        let bought = String(localized: "Bought \(item.boughtOn.formatted(date: .numeric, time: .omitted))")
        let paid = item.isSold
            ? String(localized: "Paid \(store.format(item.buyPrice)) · sold \(store.format(item.sale?.net ?? 0))")
            : String(localized: "Paid \(store.format(item.buyPrice)) · worth \(store.format(item.estimatedPrice))")
        let held = bought + "\n" + paid
        let value: String, valueSub: String, colour: Color
        if item.keep && !item.isSold {
            let cost = store.realCostPerMonth(item)
            value = cost.map { store.perMonth($0) } ?? String(localized: "First month")
            valueSub = String(localized: "real cost")
            colour = (cost ?? 0) < 0 ? Organic.s700 : Organic.text
        } else {
            let t = store.trade(item)
            value = store.signed(t.total)
            valueSub = item.isSold ? String(localized: "profit") : String(localized: "if sold now")
            colour = t.total < 0 ? Organic.a700 : Organic.s700
        }
        return ListRow(title: item.name, sub: held, value: value, valueSub: valueSub, valueColor: colour,
                       mark: LeadMark(glyph: .symbol(symbol(for: item)), tint: Organic.n200, ink: Organic.n600, size: 44,
                                      corner: corner(for: item)),
                       strong: true)
            .copyOnLongPress(item.name)
    }

    /// Which list a thing is on, as a word on its square: a search shows all three.
    private func corner(for item: Item) -> LeadMark.Corner {
        if item.isSold { return .init(text: "SOLD", tint: Organic.s700) }
        if item.keep { return .init(text: "TO USE", tint: Organic.n700) }
        return .init(text: "TO SELL", tint: Organic.info)
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
