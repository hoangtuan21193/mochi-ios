import Foundation

/// What Home's first card reads: the cards' nearest debits, which account
/// each leaves, and the move that keeps a short account from failing.
extension Store {
    /// The end of the cards' nearest round of statements — Safe to spend's
    /// horizon when it is left on the default.
    var cardsHorizon: Date { Finance.Horizon.cards.end(data, today: .now) }

    /// Each card debit up to `cardsHorizon`, soonest first.
    var cardDebits: [Finance.ScheduledEvent] {
        Finance.events(data, from: .now, to: cardsHorizon).filter { $0.kind == .card }
    }
    var cardDebitsTotal: Int { cardDebits.reduce(0) { $0 - $1.amount } }
    /// The same debits a day to a line, for the Cards to pay widget.
    var cardDays: [Finance.CardDay] { Finance.cardDays(data, to: cardsHorizon) }

    /// Moves between your own accounts that keep every debit up to the
    /// horizon from failing.
    var transfersNeeded: [Finance.TransferSuggestion] {
        Finance.transfersNeeded(data, to: horizon.end(data, today: .now))
    }

    /// The same moves over the cards' round, which is what Home's first card
    /// is about — Safe to spend's horizon may stop before a card is debited.
    var cardMoves: [Finance.TransferSuggestion] { Finance.transfersNeeded(data, to: cardsHorizon) }
    /// Accounts that fail before the cards' round ends, movable or not.
    var cardShortfalls: [Finance.AccountShortfall] { Finance.accountShortfalls(data, to: cardsHorizon) }
    /// Can this round of cards be paid.
    var cardRound: Finance.CardRoundVerdict { Finance.cardRound(data, to: cardsHorizon) }

    /// Charged on cards, paid after the horizon: shown, never subtracted.
    var chargedNotBilled: Int {
        Finance.chargedNotBilled(data, after: horizon.end(data, today: .now))
    }

    /// What an account holds today, by name.
    func balance(ofAccount name: String) -> Int? {
        data.wallets.first { $0.name == name }.map { Finance.balance(of: $0, data) }
    }
}

extension Store {
    /// Net worth against the year's first monthly reading; nil until two exist.
    var netWorthThisYear: (change: Int, readings: Int)? { Finance.netWorthChangeThisYear(data) }
    /// What sold this calendar year: the count, and profit with its points.
    var profitThisYear: (sold: Int, result: Finance.TradeResult) {
        let year = Finance.Period.year(Calendar.current.component(.year, from: .now))
        return (Finance.summary(data, for: year).soldCount, Finance.profitWithPoints(data, for: year))
    }
    /// Points that buy anything, at their value — the part in net worth.
    var spendablePoints: Int { Finance.spendablePointsValue(data) }
    /// Points tied to one shop, counted as points.
    var shopPoints: Int {
        data.pointWallets.filter { $0.spendAnywhere != true }.reduce(0) { $0 + $1.points }
    }
    func trade(_ item: Item) -> Finance.TradeResult { Finance.trade(item, data) }
    /// What the things for sale come to: paid, would bring, if all sold now.
    var resaleOutlook: Finance.ResaleOutlook { Finance.resaleOutlook(data) }
    /// What sold in a period made, cash and points apart.
    func profitWithPoints(for period: Finance.Period) -> Finance.TradeResult { Finance.profitWithPoints(data, for: period) }
}

/// Buy advice reads the book's memory: what like things sold for, what a
/// shop pays back in points, what a marketplace keeps.
extension Store {
    var targetProfit: Int { data.targetProfit ?? 10_000 }
    func setTargetProfit(_ value: Int) { data.targetProfit = value; save() }
    /// Shops the book has bought from, most used first.
    var shops: [String] { Finance.shops(data) }
    /// Channels a thing can be sold on for cash: Buy advice solves for yen.
    var cashChannels: [SalesChannel] { data.channels.filter { !$0.isPoints } }
    func pointRate(atShop shop: String) -> Double { Finance.pointRate(atShop: shop, data) }
    func buyAdvice(sellFor: Int, channel: String, postage: Int, shop: String) -> Finance.BuyAdvice {
        Finance.buyAdvice(sellFor: sellFor, channel: channel, postage: postage, shop: shop, target: targetProfit, data)
    }
}

/// A card's usage email, passed over by a Shortcuts Mail automation.
extension Store {
    /// Books the email as a spend on its card, filled from the book's memory,
    /// waiting in To review. nil when the email is not a card spend; the card
    /// is left empty for the review when the book has none, or two, that fit.
    @discardableResult
    func addCardEmail(subject: String, body: String) -> Transaction? {
        guard let mail = CardEmailParser.parse(subject: subject, body: body) else { return nil }
        let card = CardEmailParser.card(for: mail, in: data.cards)?.name ?? ""
        // Apple Pay may have booked the same tap already: one spend, not two.
        if let same = Finance.sameSpend(data, amount: mail.amount, account: card, on: mail.date ?? .now) { return same }
        var t = Transaction(date: mail.date ?? .now, amount: -mail.amount, kind: .spend, account: card,
                            merchant: mail.merchant, source: .email)
        fill(&t)
        t.needsReview = true
        addTransaction(t, applyRules: false)
        return t
    }
}

/// The Wallet tab's lines beside each account, card and plan.
extension Store {
    var accountNotes: [Finance.AccountNote] { Finance.accountNotes(data) }
    var cardLines: [Finance.CardLine] { Finance.cardLines(data) }
    var firstReadingThisYear: Date? { Finance.firstReadingThisYear(data) }
    /// Net worth month by month from the snapshots, months without one left out.
    var netWorthPoints: [(month: Date, value: Int)] {
        Finance.history(data, months: 12).compactMap { p in p.netWorth.map { (p.month, $0) } }
    }
    var installmentDebitsThisMonth: Int {
        Finance.installmentDebits(data, in: Calendar.current.dateInterval(of: .month, for: .now)!)
    }
    /// Everything the Cards and plans tab counts: statements, charges not
    /// billed yet, and plan principal — the Owed side bar loans.
    var cardsAndPlansOwed: Int { let w = netWorth; return w.cardDebt + w.unbilledCharges + w.installmentPrincipal }
    /// Invested and lent, the third tab's figure.
    var investedAndLent: Int { investmentsValue + loansOwedToYou }
}

extension Store {
    var peopleOwingYou: Int { Finance.peopleOwingYou(data) }
    var investmentsUpdated: Date? { Finance.investmentsUpdated(data) }
}

extension Store {
    func pointBalance(_ wallet: PointWallet) -> Int { Finance.pointBalance(wallet, data) }
}

extension Store {
    func netWorthSeries(_ range: Finance.NetWorthRange) -> Finance.NetWorthSeries { Finance.netWorthSeries(data, range) }
    var largestUnbilledPurchase: Item? { Finance.largestUnbilledPurchase(data) }
}

extension Store {
    var fixedInPayPeriod: Finance.FixedInPeriod { Finance.fixedInPayPeriod(data) }
}
