import SwiftUI

/// Tab 5. Only true configuration lives here: backup, language, currency,
/// sales channels. Categories are in Inventory; wallets, cards and owners are
/// in Wallet — each managed where its effect is visible.
struct SettingsView: View {
    @Environment(Store.self) private var store
    @State private var chName = ""
    @State private var chRate = ""
    @State private var chIsPoints = false
    @State private var restoreFailed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    backupCard
                    Card {
                        Text("Currency").font(.system(size: 14, weight: .heavy)).padding(.bottom, 6)
                        HStack(spacing: 5) {
                            ForEach(["¥", "$", "€", "₫"], id: \.self) { sym in
                                Button { store.data.currency = sym; store.save() } label: {
                                    Chip(label: sym, selected: store.data.currency == sym)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    channelsCard
                }
                .padding(16)
            }
            .background(Organic.bg)
            .navigationTitle("Settings")
        }
    }

    private var backupCard: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud backup").font(.system(size: 14, weight: .heavy))
                    Text(backupLine).font(.system(size: 11)).foregroundStyle(Organic.n600)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { store.data.autoBackup },
                                         set: { store.data.autoBackup = $0; store.save() }))
                    .labelsHidden().tint(Organic.accent2)
            }
            HStack(spacing: 7) {
                PrimaryButton(title: "Back up now") { store.backupNow() }
                Button {
                    restoreFailed = !store.restoreFromCloud()
                } label: {
                    Text("Restore").font(.system(size: 12.5, weight: .heavy))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Organic.n200, in: Capsule()).foregroundStyle(Organic.n800)
                }
            }
            .padding(.top, 11)
            if restoreFailed {
                Text("No iCloud backup found. Check you are signed into iCloud Drive.")
                    .font(.system(size: 11)).foregroundStyle(Organic.a800).padding(.top, 6)
            }
        }
    }

    private var backupLine: String {
        let state = store.data.autoBackup ? "Auto backup on" : "Auto backup off"
        guard let last = store.data.lastBackup else { return state + " · never" }
        return state + " · last " + last.formatted(date: .numeric, time: .shortened)
    }

    /// A channel is one way to sell: cash (% fee) or points (% bonus).
    private var channelsCard: some View {
        Card {
            Text("Sales channels").font(.system(size: 14, weight: .heavy))
            Text("Cash channels take a fee; point channels pay a bonus in points.")
                .font(.system(size: 11)).foregroundStyle(Organic.n600).padding(.bottom, 4)
            ForEach(store.data.channels) { ch in
                HStack {
                    Text(ch.name).font(.system(size: 13, weight: .semibold))
                    Text(ch.isPoints ? "POINT" : "CASH")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(ch.isPoints ? Organic.a200 : Organic.s200, in: Capsule())
                        .foregroundStyle(ch.isPoints ? Organic.a900 : Organic.s900)
                    Spacer()
                    Text("\(ch.rate.formatted())%").font(.system(size: 12.5, weight: .heavy))
                }
                .padding(.vertical, 8)
                .overlay(alignment: .top) { Divider().overlay(Organic.n200) }
            }
            HStack(spacing: 8) {
                TextField("Channel", text: $chName)
                    .font(.system(size: 13))
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .background(Organic.bg, in: Capsule())
                TextField("%", text: $chRate).keyboardType(.decimalPad)
                    .font(.system(size: 13)).frame(width: 64)
                    .padding(.horizontal, 13).padding(.vertical, 9)
                    .background(Organic.bg, in: Capsule())
                Button { chIsPoints.toggle() } label: {
                    Chip(label: chIsPoints ? "Point" : "Cash", selected: true,
                         tint: chIsPoints ? Organic.a600 : Organic.s600)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
            PrimaryButton(title: "Add channel") {
                guard !chName.isEmpty else { return }
                store.data.channels.append(SalesChannel(name: chName,
                    rate: Double(chRate) ?? 0, isPoints: chIsPoints))
                store.save(); chName = ""; chRate = ""
            }
            .padding(.top, 8)
        }
    }
}

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
                        tile("Sold", "\(sold.count)")
                        tile("Revenue", store.format(revenue))
                        tile("Profit", store.format(profit))
                    }
                    Card {
                        Text("Sold items").font(.system(size: 14, weight: .heavy)).padding(.bottom, 4)
                        ForEach(sold) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.system(size: 13, weight: .semibold))
                                    Text("\(item.sale?.channel ?? "") · \(item.sale?.date.formatted(date: .numeric, time: .omitted) ?? "")")
                                        .font(.system(size: 10.5)).foregroundStyle(Organic.n600)
                                }
                                Spacer()
                                let p = (item.sale?.net ?? 0) - item.buyPrice
                                Text((p >= 0 ? "+" : "") + store.format(p))
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundStyle(p < 0 ? Organic.a800 : Organic.s700)
                            }
                            .padding(.vertical, 8)
                            .overlay(alignment: .top) { Divider().overlay(Organic.n200) }
                        }
                    }
                }
                .padding(16)
            }
            .background(Organic.bg)
            .navigationTitle("Stats")
        }
    }

    private func tile(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(l).font(.system(size: 11)).foregroundStyle(Organic.n700)
            Text(v).font(.system(size: 14, weight: .heavy))
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Organic.n100, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
