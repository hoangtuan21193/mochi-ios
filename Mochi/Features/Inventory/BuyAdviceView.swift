import SwiftUI

/// Before buying something to sell on: the most to pay and still make the
/// target. Pushed from Belongings and Home's "Bought to sell", and opened by
/// the Buy advice widget and shortcut. The sale price is the user's guess —
/// the sold searches open in Safari and nothing is read from them.
struct BuyAdviceView: View {
    @Environment(Store.self) private var store

    @State private var name = ""
    @State private var sellFor = 0
    @State private var shop = ""
    @State private var channel = ""
    @State private var postage = 0
    @State private var asked = 0
    @State private var editingTarget = false
    @State private var target = 0
    @State private var adding: Item?
    /// Worked out once when the screen opens: what has sold, with its search
    /// keys, and each shop's points rate. Searching the book afresh on every
    /// keystroke is what made typing here lag.
    @State private var index: Finance.SoldIndex?
    @State private var shopRates: [(shop: String, rate: Double)] = []

    private var advice: Finance.BuyAdvice {
        store.buyAdvice(sellFor: sellFor, channel: channel, postage: postage, shop: shop)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Organic.Space.l) {
                Text("Before you buy: the most to pay and still make what you want")
                    .font(Organic.value).foregroundStyle(Organic.n600)
                // Wide screens: the three questions on the left, the answer on the right.
                AdaptiveColumns {
                    inputs
                } trailing: {
                    if sellFor > 0 {
                        // Worked out once per drawing, not once per card that shows it.
                        let a = advice
                        result(a)
                        seller(a)
                    }
                    PrimaryButton(title: "Bought it, add to Belongings") { adding = draft }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    HelpText("Every field comes along. The sites open in Safari; what you see there changes nothing until you type it.")
                }
            }
            .padding(.horizontal, Organic.Space.gutter).padding(.bottom, Organic.Space.gutter)
        }
        .background(Organic.bg)
        .navigationTitle("Buy advice")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $adding) { ItemEditorView(item: nil, draft: $0) }
        .onAppear(perform: seed)
    }

    // MARK: - What is it, and where it goes

    /// Three questions, a card each, in the order they are answered in the
    /// shop: what it is, what it will sell for, where it is bought and sold.
    /// The shop's own price is a separate question at the bottom, so the
    /// sale price is never typed into the wrong box.
    @ViewBuilder private var inputs: some View {
        Card {
            CardHeader(title: "1. What are you buying?", subtitle: "The name as you would list it")
            NameField(name: $name, sellFor: $sellFor, index: index)
                .padding(.top, Organic.Space.s)
        }
        Card {
            CardHeader(title: "2. What will it sell for?",
                       subtitle: "Second-hand, once it is yours. Not the shop’s price: that goes at the bottom")
            // What like things sold for and when: a list, one sale a line,
            // because the figure is what gets compared.
            let sold = index?.similar(name) ?? []
            if sold.isEmpty, name.trimmingCharacters(in: .whitespaces).count >= 3 {
                HelpText("Nothing like it sold yet. Names suggested on this iPhone are names only: check what it sells for below.")
                    .padding(.top, Organic.Space.s)
            }
            if !sold.isEmpty {
                InnerBlock(fill: Organic.surface, padding: Organic.Space.row) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("You sold \(sold.count) like it").font(Organic.caption).foregroundStyle(Organic.n600)
                            .padding(.bottom, 2)
                        ForEach(Array(sold.prefix(5).enumerated()), id: \.element.id) { i, item in
                            HStack {
                                Text(verbatim: item.sale?.date.formatted(.dateTime.day().month(.abbreviated).year()) ?? "")
                                    .font(Organic.row)
                                Spacer()
                                Text(verbatim: store.format(item.sale?.price ?? 0)).font(Organic.rowValue)
                            }
                            .frame(minHeight: 40)
                            .overlay(alignment: .top) { if i > 0 { Hairline() } }
                        }
                    }
                }
                .padding(.top, Organic.Space.m)
            }
            VStack(alignment: .leading, spacing: Organic.Space.s) {
                FieldLabel("Your guess")
                MoneyField("What it sells for", value: $sellFor)
            }
            .padding(.top, Organic.Space.m)
            let sites = store.data.channels.compactMap { ch in searchURL(ch).map { (ch.name, $0) } }
            if !sites.isEmpty {
                VStack(alignment: .leading, spacing: Organic.Space.s) {
                    FieldLabel("Check what it sold for")
                    FlowRow(spacing: Organic.Space.m) {
                        ForEach(sites, id: \.0) { ExternalLinkButton(title: $0.0, url: $0.1) }
                    }
                }
                .padding(.top, Organic.Space.m)
            }
        }
        Card {
            CardHeader(title: "3. Where you buy it and sell it",
                       subtitle: "The shop’s points and the market’s fee come from here")
            HStack(alignment: .top, spacing: Organic.Space.m) {
                VStack(alignment: .leading, spacing: Organic.Space.s) {
                    FieldLabel("Buy at")
                    FormField {
                        Menu {
                            ForEach(shopRates, id: \.shop) { s in
                                Button { shop = s.shop } label: { Text(verbatim: shopName(s.shop)) }
                            }
                            Button("Somewhere else") { shop = "" }
                        } label: {
                            Text(verbatim: shop.isEmpty ? String(localized: "Somewhere else") : shopName(shop))
                                .lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(Organic.text)
                    }
                }
                VStack(alignment: .leading, spacing: Organic.Space.s) {
                    FieldLabel("Sell on")
                    FormField {
                        Menu {
                            ForEach(store.cashChannels) { ch in
                                Button { channel = ch.name } label: { Text(verbatim: channelName(ch)) }
                            }
                        } label: {
                            Text(verbatim: store.cashChannels.first { $0.name == channel }.map(channelName) ?? channel)
                                .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(Organic.text)
                    }
                }
            }
            .padding(.top, Organic.Space.s)
            VStack(alignment: .leading, spacing: Organic.Space.s) {
                FieldLabel("Postage")
                MoneyField("Postage", value: $postage)
            }
            .padding(.top, Organic.Space.s)
        }
    }

    // MARK: - The answer

    private func result(_ a: Finance.BuyAdvice) -> some View {
        let atMax = a.result(at: a.maxPrice)
        return Card {
            FieldLabel("Pay at most")
            Text(verbatim: store.format(a.maxPrice)).font(Organic.hero)
            if editingTarget {
                HStack(spacing: Organic.Space.m) {
                    MoneyField("Profit you want", value: $target)
                    MiniButton(title: "Save", style: .accent) {
                        store.setTargetProfit(target)
                        editingTarget = false
                    }
                }
            } else {
                HStack(spacing: 4) {
                    Text("to make \(store.format(a.target)) with points ·").font(Organic.caption).foregroundStyle(Organic.n600)
                    Button { target = store.targetProfit; editingTarget = true } label: {
                        Text("change the target").font(Organic.caption).foregroundStyle(Organic.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            VStack(spacing: 0) {
                line("Sells for", store.format(a.sellsFor), Organic.text)
                if a.fee > 0 {
                    line(String(localized: "\(a.channel) fee, \(percent(a.feeRate))"), store.signed(-a.fee), Organic.a700)
                }
                if a.postage + a.payoutFee > 0 {
                    line(a.payoutFee > 0 ? String(localized: "Postage and withdrawing") : String(localized: "Postage"),
                         store.signed(-(a.postage + a.payoutFee)), Organic.a700,
                         sub: a.payoutFee > 0
                            ? String(localized: "\(store.format(a.postage)) + \(store.format(a.payoutFee)) to \(a.payoutTo ?? "")")
                            : nil)
                }
                if atMax.points > 0 {
                    line(String(localized: "Points from \(a.shop)"), store.signed(atMax.points), Organic.s700,
                         sub: String(localized: "\(percent(a.pointRate)) of \(store.format(a.maxPrice))"))
                }
                line(String(localized: "You keep"), store.signed(atMax.total), atMax.total < 0 ? Organic.a700 : Organic.s700, strong: true, last: true)
            }
            .padding(.top, Organic.Space.m)
        }
    }

    private func seller(_ a: Finance.BuyAdvice) -> some View {
        return Card {
            VStack(alignment: .leading, spacing: Organic.Space.s) {
                CardHeader(title: "Is the shop’s price worth it?", subtitle: "Type what the shop or seller asks")
                MoneyField("Their price", value: $asked)
                    .padding(.top, Organic.Space.s)
            }
            if asked > 0 {
                let r = a.result(at: asked)
                let over = a.over(asked)
                Spacer().frame(height: Organic.Space.s)
                if over > 0 {
                    Verdict(text: r.total < 0
                            ? "\(store.format(over)) over · you would lose \(store.format(-r.total))"
                            : "\(store.format(over)) over · you would make \(store.format(r.total))",
                            positive: false)
                } else {
                    Verdict(text: "\(store.format(-over)) under · you would make \(store.format(r.total))")
                }
                Text("Cash \(store.signed(r.cash)) · points +\(r.points.formatted()) pt")
                    .font(Organic.caption).foregroundStyle(Organic.n600)
            }
        }
    }

    // MARK: - Helpers

    /// One line of the sum, as a list row with the hairline under it.
    private func line(_ title: String, _ value: String, _ colour: Color, sub: String? = nil,
                      strong: Bool = false, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            ListRow(title: title, sub: sub, value: value, valueColor: colour, strong: strong)
            if !last { Hairline() }
        }
    }

    private func percent(_ v: Double) -> String { "\(v.formatted(.number.precision(.fractionLength(0...1))))%" }
    private func shopName(_ s: String) -> String {
        let r = shopRates.first { $0.shop == s }?.rate ?? 0
        return r > 0 ? String(localized: "\(s) · \(percent(r)) points") : s
    }
    private func channelName(_ ch: SalesChannel) -> String { "\(ch.name) · \(percent(ch.rate))" }

    private func searchURL(_ ch: SalesChannel) -> URL? {
        guard let template = ch.searchURL, !template.isEmpty else { return nil }
        let q = name.trimmingCharacters(in: .whitespaces).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: template.replacingOccurrences(of: "{item}", with: q))
    }

    private var draft: Item {
        let price = asked > 0 ? asked : advice.maxPrice
        return Item(name: name, boughtOn: .now, buyPrice: price, boughtFrom: shop, cardName: "",
                    pointsEarned: advice.result(at: price).points, estimatedPrice: sellFor, plannedChannel: channel,
                    shippingFee: postage, boughtToResell: true)
    }

    private func seed() {
        if index == nil { index = Finance.SoldIndex(store.data) }
        if shopRates.isEmpty { shopRates = store.shops.map { ($0, store.pointRate(atShop: $0)) } }
        if channel.isEmpty { channel = store.cashChannels.first?.name ?? "" }
        if shop.isEmpty { shop = store.shops.first ?? "" }
        if postage == 0 { postage = store.data.defaultShippingFee }
    }
}

/// The name, and the names sold before under it while it is typed in. Its
/// own view so that the field gaining focus redraws only this, not the whole
/// screen: tapping into it used to wait on every card being drawn again
/// before the keyboard came up.
private struct NameField: View {
    @Environment(Store.self) private var store
    @Binding var name: String
    @Binding var sellFor: Int
    let index: Finance.SoldIndex?
    @FocusState private var focused: Bool
    /// Names the on-device model offers when the book has sold nothing like
    /// what is typed; for the text they were asked for.
    @State private var modelNames: (typed: String, names: [String]) = ("", [])

    var body: some View {
        let picks = index?.suggestions(name) ?? []
        VStack(alignment: .leading, spacing: Organic.Space.s) {
            FormField {
                TextField("e.g. Nikon Z 70-200mm f/2.8", text: $name)
                    .autocorrectionDisabled()
                    .focused($focused)
            }
            if focused, !picks.isEmpty {
                suggestions(picks)
            } else if focused, modelNames.typed == name, !modelNames.names.isEmpty {
                modelSuggestions(modelNames.names)
            }
        }
        // Asked only once typing pauses, and only when the book has nothing:
        // what you sold before is always the better answer.
        .task(id: focused ? name : "") {
            guard focused, picks.isEmpty, ProductNamer.available, name.count >= 3,
                  !modelNames.names.contains(name) else { return }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            let typed = name
            let names = await ProductNamer.names(for: typed)
            if !Task.isCancelled { modelNames = (typed, names) }
        }
    }

    /// Names the model suggests: a name only, never a price.
    private func modelSuggestions(_ names: [String]) -> some View {
        SuggestionBox {
            ForEach(Array(names.enumerated()), id: \.element) { i, n in
                Button {
                    name = n
                    modelNames = (n, names)
                    focused = false
                } label: {
                    ListRow(title: n, sub: String(localized: "Suggested on this iPhone · not sold before"))
                        .padding(.horizontal, Organic.Space.l)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { if i > 0 { Hairline() } }
            }
        }
    }

    /// Names sold before, under the field while it is being typed in. Picking
    /// one fills the name, and the last price it sold for if none is typed.
    private func suggestions(_ picks: [Finance.SoldIndex.Name]) -> some View {
        SuggestionBox {
            ForEach(Array(picks.enumerated()), id: \.element.id) { i, n in
                Button {
                    name = n.name
                    // A sale is a price to start from; what was paid is not.
                    if sellFor == 0, n.sold { sellFor = n.lastPrice }
                    focused = false
                } label: {
                    ListRow(title: n.name,
                            sub: !n.sold ? String(localized: "You have one · not sold yet")
                                : n.times == 1 ? String(localized: "Sold once") : String(localized: "Sold \(n.times) times"),
                            value: n.sold ? store.format(n.lastPrice) : String(localized: "paid \(store.format(n.lastPrice))"),
                            valueSub: n.lastDate.formatted(.dateTime.day().month(.abbreviated).year()))
                        .padding(.horizontal, Organic.Space.l)
                }
                .buttonStyle(.plain)
                .overlay(alignment: .top) { if i > 0 { Hairline() } }
            }
        }
    }
}
