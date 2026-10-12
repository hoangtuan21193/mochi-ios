import SwiftUI

/// Item detail with the sell planner: price-forward (what do I net at this
/// price) or profit-backward (what price hits this profit).
struct ItemDetailView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: Item

    @State private var mode: Mode = .price
    @State private var channel = ""
    @State private var askingPrice = ""
    @State private var targetProfit = ""
    @State private var editing = false

    enum Mode: String, CaseIterable { case price = "Set a price", profit = "Target a profit" }

    private var live: Item { store.data.items.first { $0.id == item.id } ?? item }

    /// What the currently typed asking price nets through the chosen channel.
    private var plannedNet: Int {
        var probe = live
        probe.estimatedPrice = Int(askingPrice.filter(\.isNumber)) ?? 0
        return store.netProceeds(probe, channelName: channel)
    }

    private var typedPrice: Int { Int(askingPrice.filter(\.isNumber)) ?? 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Card {
                    Text(live.name).font(.system(size: 17, weight: .heavy))
                    HStack(spacing: 6) {
                        if !live.categoryName.isEmpty { tag(live.categoryName, Organic.n200, Organic.n700) }
                        if live.keep { tag("Keeping", Organic.s200, Organic.s900) }
                        if live.isSold { tag("Sold", Organic.a200, Organic.a900) }
                    }
                    .padding(.top, 4)
                    HStack(spacing: 8) {
                        metric("Bought for", store.format(live.buyPrice))
                        metric("Worth about", store.format(live.estimatedPrice))
                        metric("Card", live.cardName)
                    }
                    .padding(.top, 10)
                }

                if !live.isSold { keepToggle }
                if !live.isSold && !live.keep { sellPlanner }
                if !live.attributes.isEmpty { attributeCard }
                if !live.accessories.isEmpty || !live.condition.isEmpty { notesCard }
            }
            .padding(16)
        }
        .background(Organic.bg)
        .navigationTitle("Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { editing = true } } }
        .sheet(isPresented: $editing) { ItemEditorView(item: live) }
        .onAppear { channel = live.plannedChannel; askingPrice = String(live.estimatedPrice) }
    }

    private func tag(_ text: String, _ bg: Color, _ fg: Color) -> some View {
        Text(text).font(.system(size: 9.5, weight: .bold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(bg, in: Capsule()).foregroundStyle(fg)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10.5)).foregroundStyle(Organic.n600)
            Text(value).font(.system(size: 13, weight: .heavy)).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Keep vs. sell. Keeping removes the item from every resale projection.
    private var keepToggle: some View {
        Card {
            Text("Is this for sale?").font(.system(size: 13, weight: .heavy))
            HStack(spacing: 5) {
                ForEach([false, true], id: \.self) { keep in
                    Button {
                        var copy = live; copy.keep = keep; store.update(copy)
                    } label: {
                        Chip(label: keep ? "Keeping" : "For sale", selected: live.keep == keep,
                             tint: keep ? Organic.s600 : Organic.n900)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)
        }
    }

    private var sellPlanner: some View {
        Card {
            Text("Sell plan").font(.system(size: 13, weight: .heavy))
            HStack(spacing: 5) {
                ForEach(Mode.allCases, id: \.self) { m in
                    Button { mode = m } label: { Chip(label: m.rawValue, selected: mode == m) }
                        .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)

            FlowRow(spacing: 5) {
                ForEach(store.data.channels) { ch in
                    Button { channel = ch.name } label: {
                        Chip(label: ch.name, selected: channel == ch.name,
                             tint: ch.isPoints ? Organic.a600 : Organic.n900)
                    }
                    .buttonStyle(.plain)
                }
            }

            if mode == .price {
                TextField("Asking price", text: $askingPrice)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(Organic.bg, in: Capsule())
                    .overlay(Capsule().stroke(Organic.n300, lineWidth: 1.5))
                    .padding(.top, 8)
                let net = plannedNet
                HStack {
                    Text(store.channel(named: channel)?.isPoints == true ? "You get in points" : "You net")
                        .font(.system(size: 11.5)).foregroundStyle(Organic.n600)
                    Spacer()
                    Text("\(store.format(net)) · profit \(store.format(net - live.buyPrice))")
                        .font(.system(size: 12.5, weight: .heavy))
                        .foregroundStyle(net - live.buyPrice < 0 ? Organic.a800 : Organic.s700)
                }
                .padding(.top, 8)

                PrimaryButton(title: "Confirm sale · \(store.format(net))") {
                    store.sell(live, channelName: channel, price: typedPrice)
                    dismiss()
                }
                .padding(.top, 10)
            } else {
                TextField("Profit you want", text: $targetProfit)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(Organic.bg, in: Capsule())
                    .overlay(Capsule().stroke(Organic.n300, lineWidth: 1.5))
                    .padding(.vertical, 8)
                // Backward solve: price = (target + cost) / (1 ± rate)
                ForEach(store.data.channels) { ch in
                    let target = Double(Int(targetProfit.filter(\.isNumber)) ?? 0)
                    let rate = (ch.isPoints ? (live.pointRateOverride ?? ch.rate) : ch.rate) / 100
                    let price = ch.isPoints ? (target + Double(live.buyPrice)) / (1 + rate)
                                            : (target + Double(live.buyPrice)) / (1 - rate)
                    HStack {
                        Text(ch.name).font(.system(size: 12.5, weight: .semibold))
                        Spacer()
                        Text("list at " + store.format(Int(price.rounded())))
                            .font(.system(size: 12.5, weight: .heavy))
                    }
                    .padding(.vertical, 6)
                    .overlay(alignment: .top) { Divider().overlay(Organic.n200) }
                }
            }
        }
    }

    private var attributeCard: some View {
        Card {
            Text("Attributes").font(.system(size: 13, weight: .heavy)).padding(.bottom, 4)
            ForEach(Array(live.attributes.enumerated()), id: \.offset) { _, pair in
                HStack {
                    Text(pair.first ?? "").font(.system(size: 12.5)).foregroundStyle(Organic.n700)
                    Spacer()
                    Text(pair.count > 1 ? pair[1] : "").font(.system(size: 12.5, weight: .semibold))
                }
                .padding(.vertical, 6)
                .overlay(alignment: .top) { Divider().overlay(Organic.n200) }
            }
        }
    }

    private var notesCard: some View {
        Card {
            if !live.accessories.isEmpty {
                Text("Accessories").font(.system(size: 11)).foregroundStyle(Organic.n600)
                Text(live.accessories).font(.system(size: 13)).padding(.bottom, 8)
            }
            if !live.condition.isEmpty {
                Text("Condition").font(.system(size: 11)).foregroundStyle(Organic.n600)
                Text(live.condition).font(.system(size: 13))
            }
        }
    }
}
