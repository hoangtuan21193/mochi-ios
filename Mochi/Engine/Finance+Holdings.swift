import Foundation

/// What you have, the figure at the head of Home (decision #36): money and
/// things that can be turned into money, added up from the sources the user
/// picked in Settings. It is not net worth — nothing owed is taken off — and
/// the cards due this round are shown right under it, with what is left
/// once they are paid.
extension Finance {
    enum HoldingSource: String, CaseIterable, Identifiable {
        /// Bank accounts and cash: every wallet that is not a marketplace balance.
        case accounts
        /// Money waiting on Mercari, ヤフオク! and the like until withdrawn.
        case marketplace
        case gold
        case crypto
        /// NISA, iDeCo and other funds typed from a broker.
        case funds
        /// Points that buy anything (PayPay), at their yen value.
        case points
        /// Money lent in yen and owed back.
        case lent

        var id: String { rawValue }
    }

    /// Counted until the user says otherwise: what can be spent or sold
    /// quickly — accounts, marketplace balances, gold and coins.
    static let defaultHoldingSources: [HoldingSource] = [.accounts, .marketplace, .gold, .crypto]

    static func holdingSources(_ data: AppData) -> [HoldingSource] {
        guard let stored = data.holdingSources else { return defaultHoldingSources }
        return HoldingSource.allCases.filter { stored.contains($0.rawValue) }
    }

    struct Holdings: Equatable {
        /// Each counted source with what it holds, in `HoldingSource` order;
        /// a source holding nothing is left out.
        let parts: [(source: HoldingSource, amount: Int)]
        var total: Int { parts.reduce(0) { $0 + $1.amount } }

        static func == (a: Holdings, b: Holdings) -> Bool {
            a.parts.map(\.source) == b.parts.map(\.source) && a.parts.map(\.amount) == b.parts.map(\.amount)
        }
    }

    static func holdingAmount(_ source: HoldingSource, _ data: AppData) -> Int {
        let invs = data.investments ?? []
        switch source {
        case .accounts: return spendableCash(data)
        case .marketplace: return data.wallets.filter(\.isMarketplace).reduce(0) { $0 + balance(of: $1, data) }
        case .gold: return invs.filter { $0.kind == "gold" }.reduce(0) { $0 + $1.value }
        case .crypto: return invs.filter { $0.kind == "crypto" }.reduce(0) { $0 + $1.value }
        case .funds: return invs.filter { $0.kind != "gold" && $0.kind != "crypto" }.reduce(0) { $0 + $1.value }
        case .points: return spendablePointsValue(data)
        case .lent: return loansOwedToYou(data)
        }
    }

    static func holdings(_ data: AppData) -> Holdings {
        Holdings(parts: holdingSources(data).compactMap { s in
            let a = holdingAmount(s, data)
            return a == 0 ? nil : (s, a)
        })
    }

    /// What the cards take this round: every card debit up to the end of the
    /// cards' nearest statements, the figure Home shows under what you have.
    static func cardsDue(_ data: AppData, today: Date) -> Int {
        events(data, from: today, to: Horizon.cards.end(data, today: today))
            .filter { $0.kind == .card }.reduce(0) { $0 - $1.amount }
    }

    /// What you have once this round of cards is paid. Negative: the cards
    /// take more than everything counted.
    static func leftAfterCards(_ data: AppData, today: Date) -> Int {
        holdings(data).total - cardsDue(data, today: today)
    }
}
