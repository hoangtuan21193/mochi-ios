import SwiftUI

// The cash-flow sheet lived here, behind a "Richer this month" card. Both are
// gone: until two monthly snapshots exist the figure on the front was the
// *plan* — income less bills less a living estimate read off the cards — and a
// projection labelled as this month's result reads as fact. The real
// month-on-month move is on Stats, drawn from the snapshots. `Finance.monthlyCashFlow`
// stays, with its tests, for whatever shows it next.

// MARK: - Net worth sheet

/// Assets against liabilities, line by line. Long-term health, read now and
/// then, so it lives behind a tap rather than on the front.
struct NetWorthSheet: View {
    @Environment(Store.self) private var store

    var body: some View {
        let w = store.netWorth
        SheetScaffold(title: "Net worth") {
            Card {
                Text("If everything were sold and settled").font(Organic.caption).foregroundStyle(Organic.n600)
                Text(store.format(w.total))
                    .font(Organic.hero).foregroundStyle(Organic.text)
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text("Every item at its estimate, every loan collected, every card, plan and person paid. Next month's rent is not in here — it is not owed yet.")
                    .font(Organic.meta).foregroundStyle(Organic.n600).padding(.top, 4)
            }
            Card {
                Text("Assets").font(Organic.title).padding(.bottom, 4)
                LineRow(label: "Cash & wallets", value: store.format(w.cash))
                LineRow(label: "Stock at resale", value: store.format(w.inventory))
                if w.receivables > 0 { LineRow(label: "Owed to you", value: store.format(w.receivables)) }
                Hairline().padding(.vertical, 4)
                LineRow(label: "Assets", value: store.format(w.assets), tone: .positive, total: true)
            }
            Card {
                Text("Liabilities").font(Organic.title).padding(.bottom, 4)
                LineRow(label: "Card statements", value: store.format(w.cardDebt))
                LineRow(label: "On cards, not yet billed", value: store.format(w.unbilledCharges))
                LineRow(label: "Instalment plans, principal", value: store.format(w.installmentPrincipal))
                if w.loansYouOwe > 0 { LineRow(label: "People you owe", value: store.format(w.loansYouOwe)) }
                Hairline().padding(.vertical, 4)
                LineRow(label: "Liabilities", value: store.format(w.liabilities), tone: .negative, total: true)
            }
        }
    }
}
