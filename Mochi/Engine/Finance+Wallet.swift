import Foundation

/// What the Wallet tab says beside each place money is kept or owed: what an
/// account is for (salary lands here, it pays that card), whether it runs
/// short and by when to move money in, when a marketplace balance has to be
/// withdrawn, what each card and plan takes next. The figures are the
/// forecast's (`events`, `accountForecast`, `transfersNeeded`), read one
/// account at a time.
extension Finance {
    /// How far ahead the Wallet looks for a gap: past the next salary and
    /// every card's next debit.
    static let walletHorizonDays = 45

    struct AccountNote: Identifiable {
        var id: String { wallet.id }
        let wallet: Wallet
        let balance: Int
        /// Regular income paid into it ("Salary").
        let incomes: [String]
        /// Cards and plans debited from it.
        let pays: [String]
        /// The first debit it cannot cover, and by how much.
        let shortBy: Int?
        let shortOn: Date?
        /// The last business day a move from another account lands in time.
        let moveBy: Date?
        /// A marketplace balance: the last day to ask for the withdrawal so it
        /// lands before `forDebit`, the last debit of the account it goes to.
        let withdrawBy: Date?
        let forDebit: Date?
    }

    /// Every wallet, largest balance first.
    static func accountNotes(_ data: AppData, today: Date = .now) -> [AccountNote] {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: walletHorizonDays, to: today)!
        let walks = accountForecast(data, to: end, today: today)
        let moves = transfersNeeded(data, to: end, today: today)
        let list = events(data, from: today, to: end)
        return data.wallets.map { w in
            let incomes = (data.recurring ?? []).filter { $0.kind == "income" && $0.paidBy == w.name }.map(\.name)
            let pays = data.cards.filter { $0.payFrom == w.name }.map(\.name)
                + (data.installments ?? []).filter { $0.payFrom == w.name && !$0.isSettled(on: today) }.map(\.name)
            let short = walks[w.name]?.first { $0.balanceAfter < 0 }
            var withdrawBy: Date?, forDebit: Date?
            if w.isMarketplace, let to = w.payoutTo,
               let target = list.filter({ $0.account == to && $0.amount < 0 }).map(\.date).max() {
                let by = BusinessCalendar.latestStart(businessDays: w.payoutDays ?? 3, arrivingBy: target)
                if by >= cal.startOfDay(for: today) { withdrawBy = by; forDebit = target }
            }
            return AccountNote(wallet: w, balance: balance(of: w, data), incomes: incomes, pays: pays,
                               shortBy: short.map { -$0.balanceAfter }, shortOn: short?.date,
                               moveBy: moves.first { $0.to == w.name }?.deadline,
                               withdrawBy: withdrawBy, forDebit: forDebit)
        }
        .sorted { $0.balance > $1.balance }
    }

    /// One card as Wallet lists it: the statement still to pay and when,
    /// and what is charged but not billed yet.
    struct CardLine: Identifiable {
        var id: String { card.id }
        let card: CreditCard
        let statement: Int
        let due: Date
        let unbilled: Int
    }

    /// Soonest debit first; a card with nothing to pay sinks to the bottom.
    static func cardLines(_ data: AppData, today: Date = .now) -> [CardLine] {
        data.cards.map { c in
            let cy = cycle(for: c, data, today: today)
            let open = cy.owedStatement > 0
            return CardLine(card: c, statement: cy.owedStatement, due: open ? cy.statementDue : cy.unbilledDue, unbilled: cy.unbilled)
        }
        .sorted { ($0.statement > 0 ? 0 : 1, $0.due) < ($1.statement > 0 ? 0 : 1, $1.due) }
    }

    /// What every instalment plan debits inside the interval.
    static func installmentDebits(_ data: AppData, in interval: DateInterval) -> Int {
        (data.installments ?? []).reduce(0) { sum, p in
            sum + (0..<p.months).filter { interval.contains(p.dueDate(at: $0)) }.reduce(0) { $0 + p.amount(at: $1) }
        }
    }
}

extension Finance {
    /// The year's first monthly reading, which `netWorthChangeThisYear`
    /// measures from: "since January".
    static func firstReadingThisYear(_ data: AppData, today: Date = .now) -> Date? {
        let cal = Calendar.current
        let year = cal.component(.year, from: today)
        return (data.snapshots ?? []).filter { cal.component(.year, from: $0.date) == year }.map(\.date).min()
    }
}

extension Finance {
    /// How many people owe you in yen: the People row's count.
    static func peopleOwingYou(_ data: AppData) -> Int {
        Set(data.loans.filter { $0.direction > 0 && $0.currency == "JPY" }.map(\.person)).count
    }

    /// When the holdings were last typed from the broker.
    static func investmentsUpdated(_ data: AppData) -> Date? {
        (data.investments ?? []).map(\.updatedOn).max()
    }
}
