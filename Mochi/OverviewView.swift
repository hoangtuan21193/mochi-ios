import SwiftUI

/// Tab 1. Answers "how much money do I actually have, and what is due next".
struct OverviewView: View {
    @Environment(Store.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    heroCard
                    if store.isEmptyBook { startHereCard } else {
                        dueCard
                        if !store.sellSuggestions.isEmpty { suggestionCard }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 16)
            }
            .background(Organic.bg)
            .navigationTitle("Mochi")
        }
    }

    /// Shown until there is a book to draw on. The hero card above still reads
    /// zero honestly, so this only says where the numbers come from.
    private var startHereCard: some View {
        Card {
            Text("Start here").font(Organic.title)
            Text("""
                 Nothing is entered yet, so every number above is zero.

                 1. Wallet — add the bank accounts and cash you hold, the credit cards you buy on, and any instalment plans still running.
                 2. Settings — add the places you sell (Mercari, Rakuma…) with their fee. Each gets a wallet its sales pay into.
                 3. Inventory — add what you own; buying on a card raises that card's debt.
                 4. Back here — this screen tells you what you really have and whether cash covers the next bills.
                 """)
                .font(Organic.value).foregroundStyle(Organic.n700)
                .padding(.top, 6)
            Text("Settings can load a sample book if you would rather look around first.")
                .font(Organic.caption).foregroundStyle(Organic.n600)
                .padding(.top, 8)
        }
    }

    // Dark card: real cash, then the four stats in one label-over-value rhythm.
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("REAL CASH")
                .font(Organic.metaStrong).kerning(1)
                .foregroundStyle(.white.opacity(0.65))
            Text(store.format(store.realCash))
                .font(Organic.display(34))
                .foregroundStyle(store.realCash < 0 ? Organic.a300 : Organic.s300)
                .padding(.vertical, 4)
            HStack(spacing: 16) {
                Metric(label: "CASH & WALLETS", value: store.format(store.cash),
                       valueColor: .white, labelColor: .white.opacity(0.6), large: true)
                Metric(label: "CARD DEBT", value: store.format(store.debt),
                       valueColor: .white, labelColor: .white.opacity(0.6), large: true)
            }
            Hairline(color: .white.opacity(0.22)).padding(.vertical, 12)
            // Two figures, deliberately apart: what the plans take next month
            // is a cash question; what they still owe in total is the weight of
            // several cameras bought on sixty months each. Folding the second
            // into "card debt" would make every bill look unpayable.
            if !store.installments.isEmpty {
                HStack(spacing: 16) {
                    Metric(label: "INSTALMENTS NEXT MONTH", value: store.format(store.installmentMonthly),
                           valueColor: .white, labelColor: .white.opacity(0.6), large: true)
                    Metric(label: "STILL OWED ON PLANS", value: store.format(store.installmentDebt),
                           valueColor: Organic.a300, labelColor: .white.opacity(0.6), large: true)
                }
                Hairline(color: .white.opacity(0.22)).padding(.vertical, 12)
            }
            HStack(spacing: 16) {
                Metric(label: "IF YOU SOLD IT ALL", value: "≈ +" + store.format(store.liquidation),
                       valueColor: Organic.s300, labelColor: .white.opacity(0.6), large: true)
                Metric(label: "CASH AFTER THAT", value: store.format(store.cashAfterSellingAll),
                       valueColor: store.cashAfterSellingAll < 0 ? Organic.a300 : Organic.s300,
                       labelColor: .white.opacity(0.6), large: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Organic.n900, in: RoundedRectangle(cornerRadius: Organic.rCard, style: .continuous))
    }

    // Card bills, always open. Collapsed it showed a total and a "next" teaser —
    // both of which the drawdown below repeats, so the fold was hiding the only
    // part that answers the question and duplicating the part that does not.
    private var dueCard: some View {
        Card {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Card bills next cycle").font(Organic.title)
                    Text(subline).font(Organic.meta)
                        .foregroundStyle(store.cash >= store.debt ? Organic.s700 : Organic.a700)
                }
                Spacer()
                Text(store.format(store.debt))
                    .font(Organic.display(19)).foregroundStyle(Organic.a800)
            }
            Text("Drawn down from cash & wallets \(store.format(store.cash))")
                .font(Organic.meta).foregroundStyle(Organic.n600)
                .padding(.top, 9)
            ForEach(store.dueCycles) { cycle in cycleBlock(cycle) }
        }
    }

    private var subline: String {
        store.cash >= store.debt ? "Cash covers every bill" : "Short \(store.format(store.debt - store.cash))"
    }

    private func cycleBlock(_ c: Store.DueCycle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Hairline().padding(.vertical, 11)
            HStack(spacing: 11) {
                Text(String(format: "%02d", c.day))
                    .font(Organic.title)
                    .frame(width: 40, height: 40)
                    .background(c.day == store.dueCycles.first?.day ? Organic.accent : Organic.n200, in: Circle())
                    .foregroundStyle(c.day == store.dueCycles.first?.day ? .white : Organic.n800)
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.format(c.total)).font(Organic.title)
                    Text(detailLine(c)).font(Organic.caption).foregroundStyle(Organic.n600)
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(c.cards) { card in
                    HStack {
                        Text(card.name).font(Organic.value).foregroundStyle(Organic.n700)
                        Spacer()
                        Text(store.format(card.debt)).font(Organic.valueStrong)
                    }
                }
            }
            .padding(.leading, 51).padding(.top, 8)

            CalloutRow(label: c.isShort ? "Not enough — short by" : "Cash left after this date",
                       value: store.format(abs(c.cashAfter)),
                       positive: !c.isShort)
                .padding(.leading, 51).padding(.top, 9)
        }
    }

    private func detailLine(_ c: Store.DueCycle) -> String {
        let base = "\(c.cards.count) \(c.cards.count == 1 ? "card" : "cards")"
        guard c.onBehalf > 0 else { return base }
        return base + " · mine \(store.format(c.mine)) · on behalf \(store.format(c.onBehalf))"
    }

    // Only rendered when cash does NOT cover the bills.
    private var suggestionCard: some View {
        Card(fill: Organic.s100) {
            Text("Sell these to cover the cards").font(Organic.title)
            Text("Highest net first").font(Organic.caption).foregroundStyle(Organic.s900)
                .padding(.bottom, 8)
            ForEach(store.sellSuggestions) { item in
                HStack {
                    Text(item.name).font(Organic.row)
                    Spacer()
                    Text("+" + store.format(store.netProceeds(item, channelName: item.plannedChannel)))
                        .font(Organic.rowValue).foregroundStyle(Organic.s900)
                }
                .padding(.vertical, 7)
                .overlay(alignment: .top) { Hairline(color: Organic.s200) }
            }
        }
    }
}
