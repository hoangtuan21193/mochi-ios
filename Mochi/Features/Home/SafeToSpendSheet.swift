import SwiftUI

/// Behind "How it's worked out ›" on Home: the sum Safe to spend is, line by
/// line, how far it looks, and what is charged already but paid later. The
/// lines live here so the Home card can be one figure and one sentence.
struct SafeToSpendSheet: View {
    @Environment(Store.self) private var store

    private func dayMonth(_ d: Date) -> String { d.formatted(.dateTime.day().month(.abbreviated)) }

    var body: some View {
        let s = store.safeToSpend
        SheetScaffold(title: "Safe to spend") {
            Text(verbatim: store.format(s.total)).font(Organic.hero)
                .foregroundStyle(s.total < 0 ? Organic.a700 : Organic.text)
            Text(store.horizon == .cards ? "Looking to \(dayMonth(s.end)), when the last card is paid" : "Looking to \(dayMonth(s.end))")
                .font(Organic.value).foregroundStyle(Organic.n600)
            Card {
                LineRow(label: "Cash in accounts", value: store.format(s.cash))
                if s.incoming > 0 { LineRow(label: "Coming in before then: salary, withdrawals", value: store.signed(s.incoming), tone: .positive) }
                if s.cards > 0 { LineRow(label: "Card statements", value: store.signed(-s.cards), tone: .negative) }
                if s.installments > 0 { LineRow(label: "Instalment plans", value: store.signed(-s.installments), tone: .negative) }
                if s.bills > 0 { LineRow(label: "Bills from your accounts", value: store.signed(-s.bills), tone: .negative) }
                if s.buffer + s.goals > 0 {
                    LineRow(label: "Kept back on purpose", value: store.signed(-(s.buffer + s.goals)), tone: .quiet)
                }
                Hairline().padding(.vertical, 4)
                LineRow(label: "Safe to spend", value: store.format(s.total), total: true)
            }
            if store.chargedNotBilled > 0 {
                HelpText("Charged on cards since their statements closed: \(store.format(store.chargedNotBilled)), paid after \(dayMonth(s.end)). Not in this figure.")
            }
            HelpText("A marketplace balance counts only when a withdrawal can reach the bank before the debit it pays, and only after its fee.")
            ChipPicker(label: "Look as far as",
                       options: [String(localized: "The cards"), String(localized: "Payday"),
                                 String(localized: "30 days"), String(localized: "60 days")],
                       selection: selectionName,
                       onPick: pick)
                .padding(.top, Organic.Space.s)
        }
    }

    private var selectionName: String {
        switch store.horizon {
        case .cards: String(localized: "The cards")
        case .payday: String(localized: "Payday")
        case .days(60): String(localized: "60 days")
        default: String(localized: "30 days")
        }
    }

    private func pick(_ name: String) {
        switch name {
        case String(localized: "Payday"): store.setHorizon(.payday)
        case String(localized: "30 days"): store.setHorizon(.days(30))
        case String(localized: "60 days"): store.setHorizon(.days(60))
        default: store.setHorizon(.cards)
        }
    }
}
