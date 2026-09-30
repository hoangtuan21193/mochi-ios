import SwiftUI

/// Item detail with the sell planner: price-forward (what do I net at this
/// price) or profit-backward (what price hits this profit).
struct ItemDetailView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: Item

    @State private var mode: Mode = .price
    @State private var channel = ""
    @State private var askingPrice = 0
    @State private var targetProfit = 0
    /// nil = not typed, so the app-wide default applies; 0 = genuinely free.
    @State private var shipping: Int? = nil
    @State private var editing = false
    @State private var confirmingDelete = false

    enum Mode: String, CaseIterable {
        case price = "From price", profit = "From target profit"
        /// The raw value is identity; the button's words come from here.
        var name: LocalizedStringKey { self == .price ? "From price" : "From target profit" }
    }

    private var live: Item { store.data.items.first { $0.id == item.id } ?? item }
    private var plan: Installment? { store.installment(for: live) }

    private var typedPrice: Int { askingPrice }

    /// What the typed postage costs, falling back to the app-wide default.
    private var plannedShipping: Int { shipping ?? store.data.defaultShippingFee }

    /// The item as the planner currently describes it: typed price, typed postage.
    private var probe: Item {
        var copy = live
        copy.estimatedPrice = typedPrice
        copy.shippingFee = plannedShipping
        return copy
    }

    /// What the currently typed asking price nets through the chosen channel.
    private var plannedNet: Int { store.netProceeds(probe, channelName: channel) }
    private var plannedProfit: Int { store.expectedProfit(probe, channelName: channel) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Card {
                    Text(live.name).font(Organic.title).copyOnLongPress(live.name)
                    HStack(spacing: 6) {
                        if !live.categoryName.isEmpty { Badge(verbatim: live.categoryName, tone: .neutral) }
                        if live.keep { Badge("Keeping", tone: .sage) }
                        if live.isSold { Badge("Sold", tone: .accent) }
                    }
                    .padding(.top, 4)
                    HStack(spacing: 8) {
                        Metric(label: "Bought for", value: store.format(live.buyPrice))
                        Metric(label: "Worth about", value: store.format(live.estimatedPrice))
                        Metric(label: plan == nil ? "Card" : "Paid by", value: plan == nil ? live.cardName : "Instalments")
                    }
                    .padding(.top, 10)
                    if live.pointsEarned > 0 {
                        Text("Earned \(live.pointsEarned.formatted()) pt on the purchase — points, not cash.")
                            .font(Organic.meta).foregroundStyle(Organic.s700).padding(.top, 8)
                    }
                }

                if let plan { planCard(plan) }
                if !live.isSold { keepToggle }
                if !live.isSold && !live.keep { sellPlanner }
                if live.isSold { soldCard }
                if !live.attributes.isEmpty { attributeCard }
                notesCard
                DeleteButton(title: "Delete item") { confirmingDelete = true }
            }
            .padding(16)
        }
        .background(Organic.bg)
        .navigationTitle("Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true } } }
        .sheet(isPresented: $editing) { ItemEditorView(item: live) }
        .alert("Delete \(live.name)?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { store.deleteItem(live); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(plan != nil
                 ? "Its instalment plan stays in Wallet — the lender is still owed either way."
                 : "Only the record goes. Wallets and card debt are not touched.")
        }
        .onAppear {
            channel = live.plannedChannel
            askingPrice = live.estimatedPrice
            shipping = live.shippingFee
        }
    }

    /// What a sale actually returned, and the way back out of it.
    private var soldCard: some View {
        Card(fill: Organic.a100) {
            Text("Sold").font(Organic.title)
            if let sale = live.sale {
                HelpText(verbatim: metaLine(sale.channel,
                                            sale.date.formatted(date: .abbreviated, time: .omitted)),
                         tone: .warning)
                HStack(spacing: 8) {
                    Metric(label: "Listed at", value: store.format(sale.price))
                    Metric(label: "Arrived", value: store.format(sale.net))
                    // Two figures, never added together: what the trade did to
                    // cash, and what it paid back in points.
                    Metric(label: "Cash profit", value: store.signed(store.profit(live)),
                           valueColor: store.profit(live) < 0 ? Organic.a800 : Organic.s700)
                    if live.pointsEarned > 0 {
                        Metric(label: "Points", value: "+\(live.pointsEarned.formatted()) pt", valueColor: Organic.s700)
                    }
                }
                .padding(.vertical, 10)
                if let plan, plan.remaining() > 0 {
                    // The sale is done; the plan is not. Money in hand minus
                    // what the lender is still owed is the number that matters.
                    HelpText("Still owed on the plan: \(store.format(plan.remaining())) · cash from this sale after paying it off: \(store.format(sale.net - plan.remaining()))",
                             tone: .warning)
                        .padding(.bottom, 10)
                }
                SecondaryButton(title: "Undo this sale", style: .warm) { store.unsell(live) }
                Text("The item goes back on sale. Your wallets are not touched either way.")
                    .font(Organic.meta).foregroundStyle(Organic.a900).padding(.top, 6)
            }
        }
    }

    /// The plan that paid for this item, read-only here. Editing and paying
    /// early live in Wallet, next to the other plans.
    private func planCard(_ plan: Installment) -> some View {
        Card {
            HStack(alignment: .firstTextBaseline) {
                Text("Instalment plan").font(Organic.rowValue)
                Spacer()
                Text(plan.isSettled() ? "Paid off" : "\(plan.monthsLeft()) months left")
                    .font(Organic.captionStrong)
                    .foregroundStyle(plan.isSettled() ? Organic.s700 : Organic.a800)
            }
            HStack(spacing: 8) {
                Metric(label: "Still owed", value: store.format(plan.remaining()))
                Metric(label: "Per month", value: store.format(plan.regular))
                Metric(label: "Ends", value: plan.projectedEnd().formatted(.dateTime.month(.abbreviated).year()))
            }
            .padding(.top, 8)
            Text(metaLine(plan.lender, "\(plan.months) months at 0%", "edit in Wallet"))
                .font(Organic.meta).foregroundStyle(Organic.n600).padding(.top, 6)
        }
    }

    /// Keep vs. sell. Keeping removes the item from every resale projection.
    private var keepToggle: some View {
        Card {
            Text("Is this for sale?").font(Organic.rowValue)
            HStack(spacing: 5) {
                ForEach([false, true], id: \.self) { keep in
                    Button {
                        var copy = live; copy.keep = keep; store.update(copy)
                    } label: {
                        Chip(label: keep ? Text("Keeping") : Text("For sale"), selected: live.keep == keep,
                             tint: keep ? Organic.s600 : Organic.n900)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Sell plan

    /// Channel, then price or target profit, then the arithmetic laid out line
    /// by line: commission, postage, what actually reaches you, and what that
    /// leaves once the item's own cost is counted.
    private var sellPlanner: some View {
        Card {
            Text("Sell plan · channel").font(Organic.rowValue)
                .padding(.bottom, 8)

            ChipPicker(options: store.data.channels.map(\.name), selection: channel,
                       accentOptions: Set(store.data.channels.filter(\.isPoints).map(\.name))) {
                channel = $0
            }

            HStack(spacing: 8) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Button { mode = m } label: {
                        Text(m.name).font(Organic.rowValue)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(mode == m ? Organic.accent : Organic.n200, in: Capsule())
                            .foregroundStyle(mode == m ? .white : Organic.n800)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)

            if mode == .price { fromPriceBlock } else { fromProfitBlock }
        }
    }

    private var fromPriceBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                labelled("Estimated price") { MoneyField("0", value: $askingPrice, prominent: true) }
                labelled("Estimated shipping") {
                    MoneyField("Default \(store.data.defaultShippingFee.formatted())", value: $shipping, prominent: true)
                }
            }

            let price = typedPrice
            let isPoints = store.channel(named: channel)?.isPoints == true
            let rate = store.channel(named: channel)?.rate ?? 0
            let fee = isPoints ? 0 : Int(Double(price) * rate / 100)

            breakdownRow(isPoints ? "Point bonus \(rate.formatted())%" : "Commission \(rate.formatted())%",
                         isPoints ? "+" + store.format(Int(Double(price) * rate / 100))
                                  : "−" + store.format(fee),
                         isPoints ? Organic.s700 : Organic.a800)
            breakdownRow("Estimated shipping", "−" + store.format(plannedShipping), Organic.a800)
            breakdownRow(isPoints ? "You receive (points)" : "You receive (cash)",
                         store.format(plannedNet), Organic.text, heavy: true)
            breakdownRow("Expected profit",
                         (plannedProfit >= 0 ? "" : "") + store.format(plannedProfit),
                         plannedProfit < 0 ? Organic.a800 : Organic.s700, heavy: true)

            PrimaryButton(title: "Confirm sale · \(store.format(plannedNet))") {
                var copy = live
                copy.shippingFee = plannedShipping
                store.update(copy)
                store.sell(copy, channelName: channel, price: price)
                dismiss()
            }
            .padding(.top, 12)
        }
    }

    /// Backward solve. Postage and the item's cost both have to be earned back
    /// before a target profit means anything.
    private var fromProfitBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                labelled("Profit you want") { MoneyField("0", value: $targetProfit, prominent: true) }
                labelled("Estimated shipping") {
                    MoneyField("Default \(store.data.defaultShippingFee.formatted())", value: $shipping, prominent: true)
                }
            }
            .padding(.bottom, 4)

            ForEach(store.data.channels) { ch in
                let target = Double(targetProfit)
                let rate = (ch.isPoints ? (live.pointRateOverride ?? ch.rate) : ch.rate) / 100
                let cost = target + Double(live.buyPrice) + Double(plannedShipping)
                let price = ch.isPoints ? cost / (1 + rate) : cost / (1 - rate)
                HStack {
                    Text(verbatim: ch.name).font(Organic.valueStrong)
                    Spacer()
                    Text("list at \(store.format(Int(price.rounded())))")
                        .font(Organic.valueStrong)
                }
                .padding(.vertical, 7)
                .overlay(alignment: .top) { Hairline() }
            }
        }
    }

    /// Caption over a planner field. The figures are the point of the card,
    /// so the fields themselves are the prominent `MoneyField`.
    private func labelled(_ label: LocalizedStringKey, @ViewBuilder field: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(Organic.caption).foregroundStyle(Organic.n600)
            field()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func breakdownRow(_ label: LocalizedStringKey, _ value: String, _ tint: Color,
                              heavy: Bool = false) -> some View {
        HStack {
            Text(label).font(heavy ? Organic.valueStrong : Organic.value)
                .foregroundStyle(heavy ? Organic.text : Organic.n700)
            Spacer()
            Text(value).font(Organic.rowValue).foregroundStyle(tint)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .top) { Hairline() }
    }

    /// A number attribute reads with the unit its category gives it —
    /// "12,400 shots" rather than a bare figure.
    private func displayValue(for pair: [String]) -> String {
        let value = pair.count > 1 ? pair[1] : ""
        guard let spec = store.data.categories.first(where: { $0.name == live.categoryName })?
            .attributes.first(where: { $0.name == pair.first }),
              spec.kind == .number else { return value }
        let pretty = Int(value).map { $0.formatted(.number.grouping(.automatic)) } ?? value
        return spec.unit.isEmpty ? pretty : "\(pretty) \(spec.unit)"
    }

    private var attributeCard: some View {
        Card {
            Text("Attributes").font(Organic.rowValue).padding(.bottom, 4)
            ForEach(Array(live.attributes.enumerated()), id: \.offset) { _, pair in
                HStack {
                    Text(pair.first ?? "").font(Organic.value).foregroundStyle(Organic.n700)
                    Spacer()
                    Text(displayValue(for: pair)).font(Organic.valueStrong)
                }
                .padding(.vertical, 6)
                .overlay(alignment: .top) { Hairline() }
            }
        }
    }

    private var notesCard: some View {
        Card {
            HStack {
                Text("Bought").font(Organic.caption).foregroundStyle(Organic.n600)
                Spacer()
                Text(metaLine(live.boughtOn.formatted(date: .abbreviated, time: .omitted),
                              live.boughtFrom))
                    .font(Organic.valueStrong)
            }
            .padding(.bottom, 8)
            if !live.accessories.isEmpty {
                Text("Accessories").font(Organic.caption).foregroundStyle(Organic.n600)
                Text(live.accessories).font(Organic.body).padding(.bottom, 8)
            }
            if !live.condition.isEmpty {
                Text("Condition").font(Organic.caption).foregroundStyle(Organic.n600)
                Text(live.condition).font(Organic.body)
            }
        }
    }
}
