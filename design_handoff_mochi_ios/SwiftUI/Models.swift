import Foundation

// MARK: - Domain

struct Owner: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
}

/// A place cash sits: bank account, marketplace wallet, physical cash.
/// There is no grouping — every wallet counts as real cash.
struct Wallet: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var balance: Int
    /// Free-text qualifier shown small next to the name ("bank", "not withdrawn").
    var note: String = ""
    var ownerID: String = "me"
}

/// Points / store credit. Deliberately NOT counted as cash.
struct PointWallet: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var points: Int
    var note: String = ""
}

struct CreditCard: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    /// Day of month the statement is paid (26, 27, 4…).
    var dueDay: Int
    var limit: Int
    var debt: Int
    var ownerID: String = "me"
}

/// How an item gets sold. Cash channels take a % fee; point channels pay a % bonus in points.
struct SalesChannel: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    /// Percent. Fee for cash channels, bonus rate for point channels.
    var rate: Double
    /// Wallet name the proceeds land in. Empty for point channels.
    var destination: String = ""
    var isPoints: Bool = false
}

enum AttributeKind: String, Codable, CaseIterable {
    case bool, options, text
}

struct AttributeSpec: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var kind: AttributeKind
    var options: [String] = []
}

/// A category shapes an item's attribute checklist. "Other" is not stored —
/// it is the built-in empty choice.
struct Category: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var attributes: [AttributeSpec]
}

struct SaleRecord: Codable, Hashable {
    var price: Int
    var channel: String
    /// What actually arrived after fees.
    var net: Int
    var date: Date
}

struct Item: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var categoryName: String = ""
    /// true = keeping it, excluded from resale projections and net-cash-after-selling.
    var keep: Bool = false
    var boughtOn: Date
    var buyPrice: Int
    var cardName: String
    var pointsEarned: Int = 0
    var estimatedPrice: Int
    var plannedChannel: String
    var accessories: String = ""
    var condition: String = ""
    /// Ordered key/value pairs, seeded from the category and editable per item.
    var attributes: [[String]] = []
    var sale: SaleRecord? = nil
    /// Per-item override of a point channel's bonus rate, in percent.
    var pointRateOverride: Double? = nil

    var isSold: Bool { sale != nil }
}

struct LedgerEntry: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var date: Date
    var label: String
    var detail: String
    var amount: Int
    /// "in" money arriving, "out" money leaving, "x" wallet-to-wallet transfer.
    var kind: String
}

struct Loan: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var person: String
    /// +1 you lent, -1 you owe.
    var direction: Int
    var amount: Int
    var currency: String   // "JPY" or "VND"
    var history: [LoanEvent] = []
}

struct LoanEvent: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var date: Date
    var title: String
    var amount: String
}

// MARK: - Persisted document

struct AppData: Codable {
    var items: [Item] = []
    var wallets: [Wallet] = []
    var pointWallets: [PointWallet] = []
    var cards: [CreditCard] = []
    var channels: [SalesChannel] = []
    var categories: [Category] = []
    var owners: [Owner] = [Owner(id: "me", name: "Me")]
    var loans: [Loan] = []
    var ledger: [LedgerEntry] = []
    var currency: String = "¥"
    var language: String = "vi"
    var autoBackup: Bool = true
    var lastBackup: Date? = nil
    /// Default transfer fee in yen — 210 for Mercari/Rakuma bank withdrawals.
    var defaultTransferFee: Int = 210
}
