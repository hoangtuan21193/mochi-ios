import Foundation
import SwiftUI

/// What a transaction does to the money. The sign of `amount` follows the
/// account: negative takes money out of it (or, on a card, adds to what the
/// card is owed), positive puts money in.
enum TransactionKind: String, Codable, CaseIterable {
    /// Money spent on living: groceries, rent, a train. The only kind Spending counts.
    case spend
    /// Salary, a sale's payout, a gift in.
    case income
    /// Money moving between two of your own places: a bank-to-PayPay top-up,
    /// paying a card, an instalment debit. Never spending, never income.
    case move
    /// Money coming back for something that was spend.
    case refund
    /// Money that became a belonging. It leaves the account like spend does,
    /// but it is not spending: the book still holds its value as an item.
    case asset
    /// The difference between what the book worked out and what the bank
    /// says, booked so the balance matches again (YNAB's reconcile).
    case adjustment
}

/// Where an entry came from, so a screen can say "from Apple Pay" and an
/// import can tell its own rows from ones typed in.
enum TransactionSource: String, Codable {
    case manual, scan, applePay, statement, recurring, schedule, split, email
}

/// One movement of money. Balances are worked out from these on top of the
/// opening balance each account was given, so a transaction is the record
/// of *why* a balance is what it is.
struct Transaction: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var date: Date
    /// In the book's currency. Negative leaves `account`. For a move this is
    /// the positive sum that goes from `account` to `toAccount`.
    var amount: Int
    var kind: TransactionKind
    /// A wallet, card or point wallet name; for a move, where it came from.
    var account: String
    /// A move's destination: a wallet, a card (paying it off) or an
    /// instalment plan's name (a debit against it).
    var toAccount: String? = nil
    var merchant: String = ""
    /// A `SpendingCategory` name. Empty for moves and adjustments.
    var category: String = ""
    var note: String = ""
    /// Set when the money was paid in another currency ("VND"). `amount` is
    /// then the yen figure at `rate`, and `foreignAmount` what was paid.
    var currency: String? = nil
    var foreignAmount: Int? = nil
    /// Units of `currency` per unit of the book's currency, as the user typed it.
    var rate: Double? = nil
    /// The belonging this bought or sold.
    var itemID: String? = nil
    /// The recurring entry, card or plan that posted it on its day.
    var scheduleID: String? = nil
    var source: TransactionSource = .manual
    /// Came in from Apple Pay, an import or a scan the user has not looked at.
    var needsReview: Bool = false
    /// A file name under Application Support/receipts. The photo itself is
    /// never inside the book, which would make every save megabytes.
    var receiptFile: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    /// What the spot is called — a place saved here before, or the area
    /// Apple Maps gave for it — kept with the spend so it is named later
    /// without asking again.
    var placeName: String? = nil
    /// When a bill is split, the share that was yours. nil means all of it.
    /// The rest is owed to you and sits in People, not in Spending.
    var myShare: Int? = nil
    /// Links the IOUs a split created, so undoing a split takes them too.
    var splitID: String? = nil
    /// Who added it, when the book is shared between two iPhones.
    var addedBy: String? = nil
    /// The shop's 登録番号 (T + 13 digits) when a receipt showed it: the same
    /// shop next time, however OCR spells its name.
    var registration: String? = nil

    /// What this means for Spending: money out on living, less refunds.
    /// A split counts only the part that was yours.
    var spendingAmount: Int {
        switch kind {
        case .spend: return myShare.map { -$0 } ?? amount
        case .refund: return amount
        default: return 0
        }
    }
}

extension Transaction {
    private enum CodingKeys: String, CodingKey {
        case id, date, amount, kind, account, toAccount, merchant, category, note, currency, foreignAmount, rate
        case itemID, scheduleID, source, needsReview, receiptFile, latitude, longitude, placeName, myShare, splitID, addedBy, registration
    }
    /// Every key but the essentials is optional on read: a book written by an
    /// earlier build of this very model must still open.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        date = try c.decode(Date.self, forKey: .date)
        amount = try c.decode(Int.self, forKey: .amount)
        kind = try c.decodeIfPresent(TransactionKind.self, forKey: .kind) ?? .spend
        account = try c.decodeIfPresent(String.self, forKey: .account) ?? ""
        toAccount = try c.decodeIfPresent(String.self, forKey: .toAccount)
        merchant = try c.decodeIfPresent(String.self, forKey: .merchant) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
        foreignAmount = try c.decodeIfPresent(Int.self, forKey: .foreignAmount)
        rate = try c.decodeIfPresent(Double.self, forKey: .rate)
        itemID = try c.decodeIfPresent(String.self, forKey: .itemID)
        scheduleID = try c.decodeIfPresent(String.self, forKey: .scheduleID)
        source = try c.decodeIfPresent(TransactionSource.self, forKey: .source) ?? .manual
        needsReview = try c.decodeIfPresent(Bool.self, forKey: .needsReview) ?? false
        receiptFile = try c.decodeIfPresent(String.self, forKey: .receiptFile)
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        placeName = try c.decodeIfPresent(String.self, forKey: .placeName)
        myShare = try c.decodeIfPresent(Int.self, forKey: .myShare)
        splitID = try c.decodeIfPresent(String.self, forKey: .splitID)
        addedBy = try c.decodeIfPresent(String.self, forKey: .addedBy)
        registration = try c.decodeIfPresent(String.self, forKey: .registration)
    }
}

/// A heading for spending. Separate from an item's `Category`, which says
/// what a belonging *is* and carries its attributes.
struct SpendingCategory: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    /// An SF Symbol, so the category reads at a glance in a list.
    var symbol: String = "circle"
    /// Index into `Organic.chart`, so a category keeps its colour on every chart.
    var colorIndex: Int = 0

    /// What a fresh book starts with. Names stay English in the book (they are
    /// identity, like a currency's symbol); screens translate the built-ins.
    static let defaults: [SpendingCategory] = [
        .init(name: "Housing", symbol: "house", colorIndex: 0),
        .init(name: "Groceries", symbol: "cart", colorIndex: 1),
        .init(name: "Eating out", symbol: "fork.knife", colorIndex: 2),
        .init(name: "Transport", symbol: "tram", colorIndex: 3),
        .init(name: "Household", symbol: "sofa", colorIndex: 4),
        .init(name: "Subscriptions", symbol: "repeat", colorIndex: 5),
        .init(name: "Fun", symbol: "sparkles", colorIndex: 8),
        .init(name: "Health", symbol: "cross.case", colorIndex: 4),
        .init(name: "Utilities", symbol: "bolt", colorIndex: 7),
        .init(name: "Other", symbol: "ellipsis.circle", colorIndex: 6),
    ]

    /// Where a `Recurring` bill lands when the app posts it on its day.
    static func forRecurring(_ raw: String) -> String {
        switch raw {
        case "rent": return "Housing"
        case "utility": return "Utilities"
        case "subscription": return "Subscriptions"
        case "insurance": return "Other"
        default: return "Other"
        }
    }
}

extension SpendingCategory {
    private enum CodingKeys: String, CodingKey { case id, name, symbol, colorIndex }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "circle"
        colorIndex = try c.decodeIfPresent(Int.self, forKey: .colorIndex) ?? 0
    }
}

/// A belonging's worth on one day, as the user typed it (from 持ち物査定 or a
/// trade-in quote). Kept so its page can draw what it lost, and when.
struct ValuePoint: Codable, Hashable {
    var date: Date
    var value: Int
}
