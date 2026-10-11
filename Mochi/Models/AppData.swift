import Foundation

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
    /// Optional: books saved before commitments existed have no such key.
    var recurring: [Recurring]? = nil
    /// Optional for the same reason. One entry per month, taken on launch.
    var snapshots: [CashSnapshot]? = nil
    /// Cash that Safe to spend keeps back on purpose. 0 until set.
    var safetyBuffer: Int = 0
    /// "30d", "60d" or "payday" — how far Safe to spend looks.
    var horizon: String = "cards"
    /// Bumped when the shape of the book changes, so a later build can tell
    /// what it is reading. Books without the key are version 1.
    var schemaVersion: Int = 1

    // Version 2: the book keeps transactions. Every one of these is optional,
    // so a version-1 book decodes untouched and simply has none.
    var transactions: [Transaction]? = nil
    var spendingCategories: [SpendingCategory]? = nil
    /// When this book started keeping transactions. Balances typed before it
    /// are the openings; bills before it are counted the old way, from the
    /// Every month list, so nothing is counted twice across the switch.
    var ledgerStart: Date? = nil
    /// Recurring entries, card payments and plan debits are posted up to and
    /// including this day.
    var postedThrough: Date? = nil
    var budgets: [BudgetLine]? = nil
    var goals: [Goal]? = nil
    var rules: [Rule]? = nil
    var investments: [Investment]? = nil
    /// Units of a foreign currency per unit of the book's, as last typed.
    var rates: [String: Double]? = nil
    var household: Household? = nil
    var notifications: NotificationPrefs? = nil
    /// The last Sunday the weekly check-in was finished.
    var lastCheckin: Date? = nil
    /// Whether a spot with no saved name is looked up in Apple Maps. nil is
    /// on: the one thing in capture that uses the network, and it can be off.
    var lookUpPlaceNames: Bool? = nil
    /// What Buy advice aims to make on a trade, points included. nil = ¥10,000.
    var targetProfit: Int? = nil
}

extension AppData {
    private enum CodingKeys: String, CodingKey {
        case items, wallets, pointWallets, cards, channels, categories, owners, loans, ledger
        case importBatches, installments, currency, language, autoBackup, lastBackup
        case defaultTransferFee, defaultShippingFee, recurring, snapshots, safetyBuffer, horizon, schemaVersion
        case transactions, spendingCategories, ledgerStart, postedThrough, budgets, goals, rules, investments
        case rates, household, notifications, lastCheckin, lookUpPlaceNames, targetProfit
    }

    /// Reads any book ever written. Every key is optional here: a field added in
    /// a later build is simply absent from an older file, and the synthesised
    /// decoder would throw on it — which once turned a full book into an empty
    /// one. Defaults live here, not on the property declarations.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([Item].self, forKey: .items) ?? []
        wallets = try c.decodeIfPresent([Wallet].self, forKey: .wallets) ?? []
        pointWallets = try c.decodeIfPresent([PointWallet].self, forKey: .pointWallets) ?? []
        cards = try c.decodeIfPresent([CreditCard].self, forKey: .cards) ?? []
        channels = try c.decodeIfPresent([SalesChannel].self, forKey: .channels) ?? []
        categories = try c.decodeIfPresent([Category].self, forKey: .categories) ?? []
        owners = try c.decodeIfPresent([Owner].self, forKey: .owners) ?? [Owner(id: "me", name: "Me")]
        loans = try c.decodeIfPresent([Loan].self, forKey: .loans) ?? []
        ledger = try c.decodeIfPresent([LedgerEntry].self, forKey: .ledger) ?? []
        importBatches = try c.decodeIfPresent([ImportBatch].self, forKey: .importBatches)
        installments = try c.decodeIfPresent([Installment].self, forKey: .installments)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "¥"
        language = try c.decodeIfPresent(String.self, forKey: .language) ?? "system"
        autoBackup = try c.decodeIfPresent(Bool.self, forKey: .autoBackup) ?? true
        lastBackup = try c.decodeIfPresent(Date.self, forKey: .lastBackup)
        defaultTransferFee = try c.decodeIfPresent(Int.self, forKey: .defaultTransferFee) ?? 210
        defaultShippingFee = try c.decodeIfPresent(Int.self, forKey: .defaultShippingFee) ?? 1000
        recurring = try c.decodeIfPresent([Recurring].self, forKey: .recurring)
        snapshots = try c.decodeIfPresent([CashSnapshot].self, forKey: .snapshots)
        safetyBuffer = try c.decodeIfPresent(Int.self, forKey: .safetyBuffer) ?? 0
        horizon = try c.decodeIfPresent(String.self, forKey: .horizon) ?? "30d"
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        transactions = try c.decodeIfPresent([Transaction].self, forKey: .transactions)
        spendingCategories = try c.decodeIfPresent([SpendingCategory].self, forKey: .spendingCategories)
        ledgerStart = try c.decodeIfPresent(Date.self, forKey: .ledgerStart)
        postedThrough = try c.decodeIfPresent(Date.self, forKey: .postedThrough)
        budgets = try c.decodeIfPresent([BudgetLine].self, forKey: .budgets)
        goals = try c.decodeIfPresent([Goal].self, forKey: .goals)
        rules = try c.decodeIfPresent([Rule].self, forKey: .rules)
        investments = try c.decodeIfPresent([Investment].self, forKey: .investments)
        rates = try c.decodeIfPresent([String: Double].self, forKey: .rates)
        household = try c.decodeIfPresent(Household.self, forKey: .household)
        notifications = try c.decodeIfPresent(NotificationPrefs.self, forKey: .notifications)
        lastCheckin = try c.decodeIfPresent(Date.self, forKey: .lastCheckin)
        lookUpPlaceNames = try c.decodeIfPresent(Bool.self, forKey: .lookUpPlaceNames)
        targetProfit = try c.decodeIfPresent(Int.self, forKey: .targetProfit)
    }
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
