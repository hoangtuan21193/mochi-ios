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

    /// "Mercari wallet" / "MapCamera points": what a freshly made destination
    /// is called, so the same channel never spawns two differently named wallets.
    static func defaultDestinationName(for channel: String, isPoints: Bool) -> String {
        let base = channel.trimmingCharacters(in: .whitespaces)
        return isPoints ? "\(base) points" : "\(base) wallet"
    }
}

enum AttributeKind: String, Codable, CaseIterable {
    /// Yes/No, a fixed list, a plain number, or free text. `number` exists
    /// because things like a shutter count are a figure you read off the body,
    /// not one of four buckets someone guessed at in advance.
    case bool, options, number, text
}

struct AttributeSpec: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var kind: AttributeKind
    var options: [String] = []
    /// Shown after a number field: "shots", "%", "cycles".
    var unit: String = ""
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
    /// What actually arrived after fees and postage.
    var net: Int
    var date: Date
    /// What postage cost on this sale.
    var shipping: Int = 0
}

struct Item: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var categoryName: String = ""
    /// true = keeping it, excluded from resale projections and net-cash-after-selling.
    var keep: Bool = false
    var boughtOn: Date
    var buyPrice: Int
    /// The shop it came from — MapCamera, Hardoff, a Mercari seller. Distinct
    /// from `cardName`, which is only how it was paid for.
    var boughtFrom: String = ""
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
    /// What postage is expected to cost. nil falls back to the app-wide default
    /// — a lens in a small box is not a tripod.
    var shippingFee: Int? = nil

    var isSold: Bool { sale != nil }
}

/// One import, kept so it can be undone later. The ids are what was actually
/// written — rows the commit skipped as duplicates are not in here.
struct ImportBatch: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var date: Date
    var itemIDs: [String]
    /// Names as they were imported, so the entry still reads after the items
    /// have been renamed or deleted one by one.
    var itemNames: [String]
    /// Whether this import raised card debt. Undoing it has to give back
    /// exactly what it took, and nothing more.
    var addedToDebt: Bool
    /// "Pasted" or the file it was opened from.
    var source: String
    /// Sales channels this import had to invent because the sheet named ones
    /// the book did not have. Optional: batches written before imports created
    /// channels have no such key.
    var createdChannels: [String]? = nil
    /// Wallets made for those channels to pay into. Undo takes them back too,
    /// as long as no money has landed in them.
    var createdWallets: [String]? = nil

    var count: Int { itemIDs.count }
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

/// A shopping-credit plan (ショッピングクレジット): a fixed sum paid back in
/// equal monthly instalments at 0% interest. Distinct from a card — there is no
/// limit and no revolving balance — and from a `Loan`, which has no schedule.
/// The item it bought may be long gone; the debt is not.
struct Installment: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    /// Who is collecting: Orico, Jaccs, MapCamera credit…
    var lender: String = ""
    /// The whole amount borrowed.
    var principal: Int
    /// 12 / 24 / 36 / 60.
    var months: Int
    /// The first payment usually differs from the rest — the lender rounds the
    /// monthly figure and puts the remainder in month one.
    var firstAmount: Int
    /// When the first payment left the bank. Every later payment falls on the
    /// same day of the following months.
    var firstDate: Date
    /// The inventory item this bought, if it is in the book. nil when the item
    /// was never entered or has since been deleted.
    var itemID: String? = nil
    /// Paid ahead of schedule (一括返済 or a partial lump sum).
    var extraPaid: Int = 0
    /// Settled in full before the schedule ran out.
    var closed: Bool = false
}

extension Installment {
    /// What each month after the first costs. Integer division: any remainder
    /// is absorbed by the last payment, so the schedule always sums to the principal.
    var regular: Int {
        guard months > 1 else { return 0 }
        return (principal - firstAmount) / (months - 1)
    }

    /// Payment number `k` (0-based) as the lender will actually debit it.
    func amount(at k: Int) -> Int {
        guard k >= 0, k < months else { return 0 }
        if months == 1 { return principal }
        if k == 0 { return firstAmount }
        if k == months - 1 { return principal - firstAmount - regular * (months - 2) }
        return regular
    }

    func dueDate(at k: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: k, to: firstDate) ?? firstDate
    }

    /// The last scheduled payment.
    var endDate: Date { dueDate(at: max(0, months - 1)) }

    /// Payments whose date has come. Counted from the calendar, not ticked by
    /// hand: the bank debits these on its own, and five plans over sixty
    /// months would be three hundred taps.
    func paidCount(on today: Date = .now) -> Int {
        let cal = Calendar.current
        let day = cal.startOfDay(for: today)
        var n = 0
        for k in 0..<months where cal.startOfDay(for: dueDate(at: k)) <= day { n += 1 }
        return n
    }

    func paidBySchedule(on today: Date = .now) -> Int {
        (0..<paidCount(on: today)).reduce(0) { $0 + amount(at: $1) }
    }

    func remaining(on today: Date = .now) -> Int {
        if closed { return 0 }
        return max(0, principal - paidBySchedule(on: today) - extraPaid)
    }

    func isSettled(on today: Date = .now) -> Bool { remaining(on: today) == 0 }

    /// Months still to be debited. A lump sum paid early takes months off the
    /// end of the plan rather than shrinking each payment.
    func monthsLeft(on today: Date = .now) -> Int {
        let left = remaining(on: today)
        guard left > 0 else { return 0 }
        let bySchedule = months - paidCount(on: today)
        guard extraPaid > 0, regular > 0 else { return bySchedule }
        return min(bySchedule, Int((Double(left) / Double(regular)).rounded(.up)))
    }

    /// The next debit, or nil once the plan is done.
    func nextDue(on today: Date = .now) -> (date: Date, amount: Int)? {
        let k = paidCount(on: today)
        guard !isSettled(on: today), k < months else { return nil }
        return (dueDate(at: k), min(amount(at: k), remaining(on: today)))
    }

    /// When the last payment actually leaves, allowing for money paid early.
    func projectedEnd(on today: Date = .now) -> Date {
        let left = monthsLeft(on: today)
        guard left > 0 else { return dueDate(at: max(0, paidCount(on: today) - 1)) }
        return dueDate(at: paidCount(on: today) + left - 1)
    }
}

// MARK: - Preferences

/// The money the book is kept in. Raw value is the symbol, because that is
/// what `AppData.currency` has always stored on disk.
enum Currency: String, CaseIterable, Identifiable {
    case jpy = "¥", vnd = "₫", usd = "$", eur = "€"

    var id: String { rawValue }
    var symbol: String { rawValue }
    var code: String {
        switch self {
        case .jpy: return "JPY"
        case .vnd: return "VND"
        case .usd: return "USD"
        case .eur: return "EUR"
        }
    }
    var name: String {
        switch self {
        case .jpy: return "Japanese yen"
        case .vnd: return "Vietnamese đồng"
        case .usd: return "US dollar"
        case .eur: return "Euro"
        }
    }
    /// Đồng is written after the number ("5,000,000 ₫"); the others before.
    var symbolTrails: Bool { self == .vnd }
}

/// UI language. Applied through `AppleLanguages`, the way iOS itself picks a
/// per-app language, so it takes effect on the next launch and reaches every
/// system-formatted date and number as well as the app's own strings.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, en, vi, ja

    var id: String { rawValue }
    var name: String {
        switch self {
        case .system: return "Follow device"
        case .en: return "English"
        case .vi: return "Tiếng Việt"
        case .ja: return "日本語"
        }
    }
    /// The identifier handed to `AppleLanguages`; nil clears the override.
    var localeIdentifier: String? { self == .system ? nil : rawValue }
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
    /// Optional on purpose: a book saved before imports were tracked has no
    /// such key, and a non-optional field would make the whole file unreadable.
    var importBatches: [ImportBatch]? = nil
    /// Optional for the same reason: books saved before instalment plans
    /// existed have no such key.
    var installments: [Installment]? = nil
    /// Stored as the symbol ("¥") for compatibility with books saved before
    /// `Currency` existed; read through `Currency(rawValue:)`.
    var currency: String = "¥"
    /// An `AppLanguage` raw value. "system" follows the device.
    var language: String = "system"
    var autoBackup: Bool = true
    var lastBackup: Date? = nil
    /// Default transfer fee in yen — 210 for Mercari/Rakuma bank withdrawals.
    var defaultTransferFee: Int = 210
    /// What postage usually costs, used when an item does not say otherwise.
    var defaultShippingFee: Int = 1000
}

// MARK: - Starting state

extension AppData {
    /// A fresh install: nothing at all. Wallets, cards, items and sales
    /// channels are all the user's own — a Mercari seller and a MapCamera
    /// trade-in regular need different channels at different fees, and a
    /// pre-filled list is four things to delete before the first real one.
    /// Settings explains what a channel is and offers the +.
    static var empty: AppData { AppData() }
}
