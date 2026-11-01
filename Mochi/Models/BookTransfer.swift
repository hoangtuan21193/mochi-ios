import Foundation
import UniformTypeIdentifiers

extension UTType {
    /// A book file: JSON underneath, its own extension so the share sheet
    /// offers Mochi for it and for nobody else's JSON. Declared in Info.plist.
    static let mochiBook = UTType(exportedAs: "com.hoangtuan.mochi.book", conformingTo: .json)
}

/// The parts a book is moved in and out by. Six, one per place the user
/// looks, so nothing that has to travel together can be split: a card and the
/// plan it pays go in the same group, or the debt they add up to goes wrong.
enum BookGroup: String, CaseIterable, Codable, Identifiable {
    case belongings, money, transactions, plan, history, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .belongings: String(localized: "Belongings")
        case .money: String(localized: "Wallets, cards and debts")
        case .transactions: String(localized: "Transactions")
        case .plan: String(localized: "Plan")
        case .history: String(localized: "Net worth history")
        case .settings: String(localized: "Settings")
        }
    }

    /// Settings are single values, so there is nothing to add them to.
    var canMerge: Bool { self != .settings }
}

/// Replace makes a group equal to the file's; merge keeps what only the book
/// has, adds what only the file has, and takes the file's copy of anything in
/// both (matched by id).
enum BookImportMode: String, CaseIterable, Identifiable {
    case replace, merge
    var id: String { rawValue }
}

/// Pure: a book in, a book out. `Store` does the files, the backup and the save.
enum BookTransfer {
    /// The book with only `groups` in it, and a note of which they are, so an
    /// import can tell a group left out from a group that was empty.
    static func export(_ book: AppData, groups: Set<BookGroup>) -> AppData {
        var out = AppData()
        out.schemaVersion = book.schemaVersion
        out.ledgerStart = book.ledgerStart
        out.postedThrough = book.postedThrough
        for g in groups { copy(g, from: book, into: &out) }
        out.exportedGroups = BookGroup.allCases.filter(groups.contains).map(\.rawValue)
        return out
    }

    /// The groups a file carries. A file from before groups existed is a
    /// whole book.
    static func groups(in file: AppData) -> [BookGroup] {
        guard let names = file.exportedGroups else { return BookGroup.allCases }
        return BookGroup.allCases.filter { names.contains($0.rawValue) }
    }

    /// How many things a group holds, for "book 459 → file 644". nil for
    /// Settings, which is values, not things.
    static func count(_ group: BookGroup, in d: AppData) -> Int? {
        switch group {
        case .belongings: d.items.count
        case .money: d.wallets.count + d.pointWallets.count + d.cards.count + (d.installments?.count ?? 0)
            + d.loans.count + (d.investments?.count ?? 0)
        case .transactions: d.transactions?.count ?? 0
        case .plan: (d.recurring?.count ?? 0) + (d.budgets?.count ?? 0) + (d.goals?.count ?? 0)
        case .history: d.snapshots?.count ?? 0
        case .settings: nil
        }
    }

    /// Whether importing the group would change anything. Compared as encoded
    /// JSON, so a group equal in count but different in content still counts.
    static func differs(_ group: BookGroup, book: AppData, file: AppData) -> Bool {
        slice(group, of: book) != slice(group, of: file)
    }

    /// What each group would hold after the import, beside what it holds
    /// now — the line said before the button.
    struct Change: Equatable { let group: BookGroup; let before: Int?; let after: Int? }
    static func preview(_ file: AppData, to book: AppData, groups: Set<BookGroup>, mode: BookImportMode) -> [Change] {
        let result = apply(file, to: book, groups: groups, mode: mode)
        return BookGroup.allCases.filter(groups.contains).map {
            Change(group: $0, before: count($0, in: book), after: count($0, in: result))
        }
    }

    /// `book` with `groups` taken from `file`. A link into a group that no
    /// longer has its target is dropped, as deleting an item does: the plan
    /// or the spend stays, the link goes.
    static func apply(_ file: AppData, to book: AppData, groups: Set<BookGroup>, mode: BookImportMode) -> AppData {
        var out = book
        for g in groups {
            if mode == .merge && g.canMerge { merge(g, from: file, into: &out) } else { copy(g, from: file, into: &out) }
        }
        // A whole book replaced is the file's book, down to when it started
        // keeping transactions; anything less keeps this book's clock.
        if mode == .replace && groups == Set(BookGroup.allCases) {
            out.schemaVersion = max(file.schemaVersion, book.schemaVersion)
            out.ledgerStart = file.ledgerStart
            out.postedThrough = file.postedThrough
        }
        out.exportedGroups = nil
        let itemIDs = Set(out.items.map(\.id))
        out.installments = out.installments?.map { var p = $0; if let id = p.itemID, !itemIDs.contains(id) { p.itemID = nil }; return p }
        out.transactions = out.transactions?.map { var t = $0; if let id = t.itemID, !itemIDs.contains(id) { t.itemID = nil }; return t }
        out.importBatches = out.importBatches?.compactMap { b in
            var b = b
            b.itemIDs = b.itemIDs.filter(itemIDs.contains)
            return b.itemIDs.isEmpty && (b.updatedItems ?? []).isEmpty ? nil : b
        }
        return out
    }

    // MARK: - Per group

    private static func copy(_ g: BookGroup, from s: AppData, into d: inout AppData) {
        switch g {
        case .belongings:
            d.items = s.items; d.categories = s.categories; d.channels = s.channels; d.importBatches = s.importBatches
        case .money:
            d.wallets = s.wallets; d.pointWallets = s.pointWallets; d.cards = s.cards
            d.installments = s.installments; d.loans = s.loans; d.investments = s.investments; d.owners = s.owners
        case .transactions:
            d.transactions = s.transactions; d.spendingCategories = s.spendingCategories; d.rules = s.rules; d.ledger = s.ledger
        case .plan:
            d.recurring = s.recurring; d.budgets = s.budgets; d.goals = s.goals
        case .history:
            d.snapshots = s.snapshots
        case .settings:
            d.currency = s.currency; d.language = s.language
            d.defaultTransferFee = s.defaultTransferFee; d.defaultShippingFee = s.defaultShippingFee
            d.safetyBuffer = s.safetyBuffer; d.horizon = s.horizon; d.holdingSources = s.holdingSources
            d.household = s.household; d.notifications = s.notifications; d.targetProfit = s.targetProfit
            d.lookUpRates = s.lookUpRates; d.lookUpPrices = s.lookUpPrices; d.lookUpPlaceNames = s.lookUpPlaceNames
            d.lookUpListings = s.lookUpListings
            d.rates = s.rates; d.ratesFetched = s.ratesFetched; d.lastCheckin = s.lastCheckin
        }
    }

    private static func merge(_ g: BookGroup, from s: AppData, into d: inout AppData) {
        switch g {
        case .belongings:
            d.items = byID(d.items, s.items); d.categories = byID(d.categories, s.categories)
            d.channels = byID(d.channels, s.channels); d.importBatches = byID(d.importBatches, s.importBatches)
        case .money:
            d.wallets = byID(d.wallets, s.wallets); d.pointWallets = byID(d.pointWallets, s.pointWallets)
            d.cards = byID(d.cards, s.cards); d.installments = byID(d.installments, s.installments)
            d.loans = byID(d.loans, s.loans); d.investments = byID(d.investments, s.investments)
            d.owners = byID(d.owners, s.owners)
        case .transactions:
            d.transactions = byID(d.transactions, s.transactions)
            d.spendingCategories = byID(d.spendingCategories, s.spendingCategories)
            d.rules = byID(d.rules, s.rules); d.ledger = byID(d.ledger, s.ledger)
        case .plan:
            d.recurring = byID(d.recurring, s.recurring); d.budgets = byID(d.budgets, s.budgets); d.goals = byID(d.goals, s.goals)
        case .history:
            // One snapshot a month: the file's reading of a month wins.
            let cal = Calendar.current
            let key = { (x: CashSnapshot) in cal.dateComponents([.year, .month], from: x.date) }
            var all = (d.snapshots ?? []).filter { mine in !(s.snapshots ?? []).contains { key($0) == key(mine) } }
            all += s.snapshots ?? []
            d.snapshots = all.sorted { $0.date < $1.date }
        case .settings:
            copy(g, from: s, into: &d)
        }
    }

    /// The book's list with the file's copy of each shared id laid over it in
    /// place, and what only the file has added after.
    private static func byID<T: Identifiable>(_ book: [T], _ file: [T]) -> [T] where T.ID: Hashable {
        let incoming = Dictionary(file.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        let mine = Set(book.map(\.id))
        return book.map { incoming[$0.id] ?? $0 } + file.filter { !mine.contains($0.id) }
    }

    private static func byID<T: Identifiable>(_ book: [T]?, _ file: [T]?) -> [T]? where T.ID: Hashable {
        guard book != nil || file != nil else { return nil }
        return byID(book ?? [], file ?? [])
    }

    private static func slice(_ g: BookGroup, of book: AppData) -> Data? {
        var only = AppData()
        copy(g, from: book, into: &only)
        let enc = JSONEncoder()
        enc.outputFormatting = .sortedKeys
        return try? enc.encode(only)
    }
}
