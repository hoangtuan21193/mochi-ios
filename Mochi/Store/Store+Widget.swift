import Foundation
import WidgetKit

/// The few figures the widgets draw, written to the App Group the widget
/// extension can read. The widget never opens the book itself: it reads this
/// file, which is rewritten on every save.
struct WidgetSnapshot: Codable {
    var safeToSpend: Int
    var until: Date
    var covered: Bool
    var nextName: String
    var nextAmount: Int
    var nextDate: Date?
    var cashAfter: Int
    var reviewCount: Int
    var currencySymbol: String
    var updated: Date
    // Added with the Next card widget; optional so an older file still reads.
    /// Safe to spend looks as far as the cards' debits (the default horizon).
    var horizonIsCards: Bool? = nil
    var cardName: String? = nil
    var cardDate: Date? = nil
    var cardAmount: Int? = nil
    /// The account the card leaves, and how short it is without a move.
    var cardAccount: String? = nil
    var cardShortBy: Int? = nil
    var cardMoveBy: Date? = nil
    /// Every card due before the cards' horizon, a day to a line.
    var cardDays: [CardDayLine]? = nil
    /// The first move the cards need: how much, by when.
    var moveAmount: Int? = nil
    var moveBy: Date? = nil
    var shortAccount: String? = nil
    var shortBy: Int? = nil
    var shortOn: Date? = nil
    /// Home's "You have" and what is left once this round of cards is paid
    /// (decision #36). The widget that drew Safe to spend draws these.
    var have: Int? = nil
    var leftAfterCards: Int? = nil

    struct CardDayLine: Codable {
        var date: Date
        var amount: Int
        var cards: [String]
    }

    static let appGroup = "group.com.hoangtuan.mochi"
    static let fileName = "widget.json"
}

extension Store {
    func publishWidgetSnapshot() {
        guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.appGroup) else { return }
        let s = safeToSpend
        let next = paymentsDue.first { $0.amount < 0 }
        var snap = WidgetSnapshot(safeToSpend: s.total, until: s.end, covered: shortfall == nil,
                                  nextName: next?.names.first ?? "", nextAmount: -(next?.amount ?? 0), nextDate: next?.date,
                                  cashAfter: next?.balanceAfter ?? cash, reviewCount: reviewCount,
                                  currencySymbol: currency.symbol, updated: .now)
        snap.horizonIsCards = horizon == .cards
        snap.have = holdings.total
        snap.leftAfterCards = leftAfterCards
        // Of the cards due on the soonest day, the one whose account is short:
        // that is the one the widget has something to say about.
        // A short account is short whether or not a move can save it, so the
        // shortfalls decide what is flagged and the moves only add a deadline.
        let moves = cardMoves
        let shorts = cardShortfalls
        let soonest = cardDebits.filter { Calendar.current.isDate($0.date, inSameDayAs: cardDebits.first?.date ?? .distantPast) }
        let short = soonest.first { c in shorts.contains { $0.account == c.account } }
        if let card = short ?? cardDebits.first {
            let gap = shorts.first { $0.account == card.account && $0.date <= card.date }
            snap.cardName = card.label
            snap.cardDate = card.date
            snap.cardAmount = -card.amount
            snap.cardAccount = card.account
            snap.cardShortBy = gap?.shortBy
            snap.cardMoveBy = gap.flatMap { g in moves.first { $0.to == g.account }?.deadline }
        }
        snap.cardDays = cardDays.map { WidgetSnapshot.CardDayLine(date: $0.date, amount: $0.amount, cards: $0.cards) }
        if let first = shorts.first {
            let move = moves.first { $0.to == first.account }
            snap.moveAmount = move?.amount
            snap.moveBy = move?.deadline
            snap.shortAccount = first.account
            snap.shortBy = first.shortBy
            snap.shortOn = first.date
        }
        guard let blob = try? JSONEncoder().encode(snap) else { return }
        try? blob.write(to: dir.appendingPathComponent(WidgetSnapshot.fileName), options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
