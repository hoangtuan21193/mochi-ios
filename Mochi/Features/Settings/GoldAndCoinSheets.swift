import SwiftUI

// MARK: - Gold

/// Gold held, priced every day at the world price for its weight and purity
/// (decision #31, planboard gold-crypto D1). No gold shop's price can be read
/// by an app, so the sheet says the figure is the world price and a shop may
/// pay more or less.
struct GoldSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let gold: Investment
    @State private var g = Investment(name: "", kind: "gold", value: 0)
    @State private var quantity = 0.0
    @State private var unitPrice: Double?
    @State private var pricing = false
    @State private var confirmDelete = false

    private var isNew: Bool { !store.investments.contains { $0.id == gold.id } }

    var body: some View {
        SheetScaffold(title: isNew ? "Add gold" : "Gold") {
            HelpText("Priced every day at the world gold price for its weight and purity. No gold shop’s own price can be read by an app, so a shop may pay more or less.")
            FormField("Name (SJC bar, nhẫn tròn, 金地金)", text: $g.name)
            ChipPicker(label: "Gold", options: Prices.goldKinds, selection: g.goldKind ?? "24K") { g.goldKind = $0 }
            MoneyField("How much", value: $quantity, unit: .suffix(Self.unitShort(g.unit ?? "gram")), fractionDigits: 3)
            ChipPicker(label: "Unit", options: Prices.units, selection: g.unit ?? "gram",
                       display: { Text(verbatim: Self.unitName($0)) }) { g.unit = $0 }
            HelpText("1 lượng = 10 chỉ = 37.5 g · a troy ounce is 31.1 g")
            MoneyField("What you paid (optional)", value: $g.contributed)
            worthCard
            HelpText("An investment: it counts in net worth and in “You have” when Gold or Crypto is counted there, never in cash. Only the word “gold” is sent to \(Prices.goldSource), never how much you hold.")
            PrimaryButton(title: isNew ? "Add gold" : "Save") { save() }
                .disabled(quantity <= 0)
                .opacity(quantity > 0 ? 1 : 0.5)
            if !isNew { DeleteButton(title: "Delete") { confirmDelete = true } }
        }
        .onAppear {
            g = gold
            if g.unit == nil { g.unit = Prices.defaultUnit(for: store.currency.code) }
            if g.goldKind == nil { g.goldKind = "24K" }
            quantity = gold.quantity ?? 0
            unitPrice = gold.unitPrice
        }
        .task(id: "\(g.unit ?? "")\(g.goldKind ?? "")") {
            guard let unit = g.unit, let kind = g.goldKind else { return }
            pricing = true
            unitPrice = await store.goldUnitPrice(unit: unit, kind: kind) ?? (unit == gold.unit && kind == gold.goldKind ? gold.unitPrice : nil)
            pricing = false
        }
        .alert("Delete this gold?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { store.deleteInvestment(gold); dismiss() }
        } message: { Text("It leaves net worth. Nothing else changes.") }
    }

    private var draft: Investment {
        var d = g
        d.kind = "gold"
        d.quantity = quantity
        if d.name.trimmingCharacters(in: .whitespaces).isEmpty { d.name = String(localized: "Gold \(d.goldKind ?? "24K")") }
        return unitPrice.map { Finance.priced(d, unitPrice: $0, at: .now) } ?? d
    }

    private var worthCard: some View {
        let d = draft
        return Card {
            Text("Would sell for about").font(Organic.captionStrong).foregroundStyle(Organic.n600)
            Text(verbatim: unitPrice == nil || quantity <= 0 ? "—" : store.format(d.value)).font(Organic.hero)
            if let gain = Finance.gainOnPaid(d), unitPrice != nil {
                Text(verbatim: gain >= 0 ? String(localized: "Up \(store.format(gain)) on what you paid")
                                         : String(localized: "Down \(store.format(-gain)) on what you paid"))
                    .font(Organic.value).foregroundStyle(gain >= 0 ? Organic.s700 : Organic.a700)
            }
            Text(verbatim: priceLine).font(Organic.caption).foregroundStyle(Organic.n600).padding(.top, 4)
        }
    }

    private var priceLine: String {
        if pricing { return String(localized: "Getting today’s gold price…") }
        guard let unitPrice else {
            return store.lookUpPrices ? String(localized: "No gold price yet · it is priced once there is a connection")
                                      : String(localized: "Looking up gold prices is off in Your data")
        }
        let each = store.format(Int(unitPrice.rounded()))
        return String(localized: "\(each) a \(Self.unitName(g.unit ?? "gram")) of \(g.goldKind ?? "24K") at the world price · \(Prices.goldSource)")
    }

    private func save() {
        guard quantity > 0 else { return }
        store.saveInvestment(draft)
        dismiss()
    }

    /// Beside a figure: "5 chỉ", "20 g", "1 oz".
    static func unitShort(_ unit: String) -> String {
        switch unit {
        case "gram": return "g"
        case "oz": return "oz"
        default: return unitName(unit)
        }
    }

    static func unitName(_ unit: String) -> String {
        switch unit {
        case "chi": return String(localized: "chỉ")
        case "luong": return String(localized: "lượng")
        case "oz": return String(localized: "troy ounce")
        default: return String(localized: "gram")
        }
    }
}

// MARK: - Crypto

/// A coin held: picked from ten well-known ones or searched by name, priced
/// every hour in the book's money (planboard gold-crypto D2).
struct CoinSheet: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let coin: Investment
    @State private var c = Investment(name: "", kind: "crypto", value: 0)
    @State private var quantity = 0.0
    @State private var query = ""
    @State private var found: [Prices.Coin] = []
    @State private var listed: [String: Double] = [:]
    @State private var confirmDelete = false

    private var isNew: Bool { !store.investments.contains { $0.id == coin.id } }
    private var shown: [Prices.Coin] { query.count >= 2 ? found : Prices.popular }
    private var chosen: Prices.Coin? {
        c.coinID.map { id in shown.first { $0.id == id } ?? .init(id: id, symbol: c.coinSymbol ?? "", name: c.name) }
    }

    var body: some View {
        SheetScaffold(title: isNew ? "Add crypto" : "Crypto") {
            HelpText("Pick a coin and type how much you hold. Its price is checked for you every hour.")
            if isNew {
                SearchField("Search coins", text: $query)
                Card(padding: .list) {
                    if shown.isEmpty {
                        EmptyNote(query.count >= 2 ? "No coin by that name" : "Type two letters or more")
                    }
                    ForEach(Array(shown.enumerated()), id: \.element.id) { i, k in
                        Button { pick(k) } label: {
                            ListRow(title: k.name, sub: k.symbol,
                                    value: listed[k.id].map { store.format(Int($0.rounded())) },
                                    mark: LeadMark(glyph: .initials(k.symbol), tint: Organic.n200, ink: Organic.text),
                                    strong: c.coinID == k.id)
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .trailing) {
                            if c.coinID == k.id { Image(systemName: "checkmark").font(Organic.valueStrong).foregroundStyle(Organic.accent).accessibilityLabel(Text("Chosen")) }
                        }
                        .overlay(alignment: .top) { if i > 0 { Hairline() } }
                    }
                }
            }
            if let k = chosen {
                MoneyField("How much", value: $quantity, unit: .suffix(k.symbol), fractionDigits: 8)
                FormField("Held at (bitFlyer, Binance)", text: $c.provider)
                MoneyField("What you paid (optional)", value: $c.contributed)
                worthCard(k)
                HelpText("An investment: it counts in net worth and in “You have” when Gold or Crypto is counted there, never in cash. Only the coin’s name is sent to \(Prices.coinSource), never how much you hold.")
                PrimaryButton(title: isNew ? "Add \(k.name)" : "Save") { save() }
                    .disabled(quantity <= 0)
                    .opacity(quantity > 0 ? 1 : 0.5)
            }
            if !isNew { DeleteButton(title: "Delete") { confirmDelete = true } }
        }
        .onAppear {
            c = coin
            quantity = coin.quantity ?? 0
            if let id = coin.coinID, let p = coin.unitPrice { listed[id] = p }
        }
        // The typed name, a moment after typing stops, so each letter is not a request.
        .task(id: query) {
            guard query.count >= 2 else { found = []; return }
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            found = await store.searchCoins(query)
        }
        .task(id: shown.map(\.id) + [c.coinID ?? ""]) {
            let ids = Array(Set(shown.map(\.id) + [c.coinID].compactMap { $0 })).sorted()
            let prices = await store.coinPrices(ids)
            listed.merge(prices) { _, new in new }
        }
        .alert("Delete this coin?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { store.deleteInvestment(coin); dismiss() }
        } message: { Text("It leaves net worth. Nothing else changes.") }
    }

    private func pick(_ k: Prices.Coin) {
        c.coinID = k.id
        c.coinSymbol = k.symbol
        c.name = k.name
        c.unit = k.symbol
    }

    private var draft: Investment {
        var d = c
        d.kind = "crypto"
        d.quantity = quantity
        guard let id = d.coinID, let p = listed[id] else { return d }
        return Finance.priced(d, unitPrice: p, at: .now)
    }

    private func worthCard(_ k: Prices.Coin) -> some View {
        let d = draft
        let price = listed[k.id]
        return Card {
            Text("Worth now").font(Organic.captionStrong).foregroundStyle(Organic.n600)
            Text(verbatim: price == nil || quantity <= 0 ? "—" : store.format(d.value)).font(Organic.hero)
            if let gain = Finance.gainOnPaid(d), price != nil {
                Text(verbatim: gain >= 0 ? String(localized: "Up \(store.format(gain)) on what you paid")
                                         : String(localized: "Down \(store.format(-gain)) on what you paid"))
                    .font(Organic.value).foregroundStyle(gain >= 0 ? Organic.s700 : Organic.a700)
            }
            Text(verbatim: price.map { String(localized: "\(k.symbol) at \(store.format(Int($0.rounded()))) · price from \(Prices.coinSource)") }
                 ?? (store.lookUpPrices ? String(localized: "No price yet · it is priced once there is a connection")
                                        : String(localized: "Looking up coin prices is off in Your data")))
                .font(Organic.caption).foregroundStyle(Organic.n600).padding(.top, 4)
        }
    }

    private func save() {
        guard quantity > 0, c.coinID != nil else { return }
        store.saveInvestment(draft)
        dismiss()
    }
}
