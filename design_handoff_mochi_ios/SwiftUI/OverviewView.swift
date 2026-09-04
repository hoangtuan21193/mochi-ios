import SwiftUI

/// Tab 1. Answers "how much money do I actually have, and what is due next".
struct OverviewView: View {
    @Environment(Store.self) private var store
    @State private var cyclesExpanded = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    heroCard
                    dueCard
                    if !store.sellSuggestions.isEmpty { suggestionCard }
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 16)
            }
            .background(Organic.bg)
            .navigationTitle("Mochi")
        }
    }

    // Dark card: real cash, then the four stats in one label-over-value rhythm.
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("REAL CASH")
                .font(.system(size: 10.5, weight: .bold)).kerning(1)
                .foregroundStyle(.white.opacity(0.65))
            Text(store.format(store.realCash))
                .font(Organic.display(34))
                .foregroundStyle(store.realCash < 0 ? Organic.a300 : Organic.s300)
                .padding(.vertical, 4)
            HStack(spacing: 16) {
                stat("CASH & WALLETS", store.format(store.cash), .white)
                stat("CARD DEBT", store.format(store.debt), .white)
            }
            Divider().overlay(Color.white.opacity(0.22)).padding(.vertical, 12)
            HStack(spacing: 16) {
                stat("IF YOU SOLD IT ALL", "≈ +" + store.format(store.liquidation), Organic.s300)
                stat("CASH AFTER THAT", store.format(store.cashAfterSellingAll),
                     store.cashAfterSellingAll < 0 ? Organic.a300 : Organic.s300)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Organic.n900, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 10, weight: .bold)).kerning(0.8)
                .foregroundStyle(.white.opacity(0.6))
            Text(value).font(.system(size: 16, weight: .heavy)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Card bills, collapsed by default. Expanded it walks the drawdown date by date.
    private var dueCard: some View {
        Card {
            Button { withAnimation(.easeOut(duration: 0.2)) { cyclesExpanded.toggle() } } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Card bills next cycle").font(.system(size: 14, weight: .heavy))
                        Text(cyclesExpanded ? "Tap to collapse" : subline)
                            .font(.system(size: 11)).foregroundStyle(Organic.n600)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(store.format(store.debt))
                            .font(Organic.display(19)).foregroundStyle(Organic.a800)
                        if let next = store.dueCycles.first {
                            Text("Next: \(next.day) · \(store.format(next.total))")
                                .font(.system(size: 10.5, weight: .bold)).foregroundStyle(Organic.n600)
                        }
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .heavy)).foregroundStyle(Organic.n500)
                        .rotationEffect(.degrees(cyclesExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Organic.text)

            if cyclesExpanded {
                Text("Drawn down from cash & wallets \(store.format(store.cash))")
                    .font(.system(size: 11.5)).foregroundStyle(Organic.n600)
                    .padding(.top, 11)
                ForEach(store.dueCycles) { cycle in cycleBlock(cycle) }
            }
        }
    }

    private var subline: String {
        store.cash >= store.debt ? "Cash covers every bill" : "Short \(store.format(store.debt - store.cash))"
    }

    private func cycleBlock(_ c: Store.DueCycle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(Organic.n200).padding(.vertical, 11)
            HStack(spacing: 11) {
                Text(String(format: "%02d", c.day))
                    .font(.system(size: 14, weight: .heavy))
                    .frame(width: 40, height: 40)
                    .background(c.day == store.dueCycles.first?.day ? Organic.accent : Organic.n200, in: Circle())
                    .foregroundStyle(c.day == store.dueCycles.first?.day ? .white : Organic.n800)
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.format(c.total)).font(.system(size: 14.5, weight: .heavy))
                    Text(detailLine(c)).font(.system(size: 11)).foregroundStyle(Organic.n600)
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(c.cards) { card in
                    HStack {
                        Text(card.name).font(.system(size: 12)).foregroundStyle(Organic.n700)
                        Spacer()
                        Text(store.format(card.debt)).font(.system(size: 12, weight: .semibold))
                    }
                }
            }
            .padding(.leading, 51).padding(.top, 8)

            HStack {
                Text(c.isShort ? "Not enough — short by" : "Cash left after this date")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text(store.format(abs(c.cashAfter))).font(.system(size: 12.5, weight: .heavy))
            }
            .foregroundStyle(c.isShort ? Organic.a900 : Organic.s900)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(c.isShort ? Organic.a100 : Organic.s100,
                        in: RoundedRectangle(cornerRadius: Organic.rSmall, style: .continuous))
            .padding(.leading, 51).padding(.top, 9)
        }
    }

    private func detailLine(_ c: Store.DueCycle) -> String {
        let base = "\(c.cards.count) cards"
        guard c.onBehalf > 0 else { return base }
        return base + " · mine \(store.format(c.mine)) · on behalf \(store.format(c.onBehalf))"
    }

    // Only rendered when cash does NOT cover the bills.
    private var suggestionCard: some View {
        Card(fill: Organic.s100) {
            Text("Sell these to cover the cards").font(.system(size: 14, weight: .heavy))
            Text("Highest net first").font(.system(size: 11.5)).foregroundStyle(Organic.s900)
                .padding(.bottom, 8)
            ForEach(store.sellSuggestions) { item in
                HStack {
                    Text(item.name).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("+" + store.format(store.netProceeds(item, channelName: item.plannedChannel)))
                        .font(.system(size: 13, weight: .heavy)).foregroundStyle(Organic.s900)
                }
                .padding(.vertical, 7)
                .overlay(alignment: .top) { Divider().overlay(Organic.s200) }
            }
        }
    }
}
