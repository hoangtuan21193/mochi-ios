import Foundation

/// One import, kept so it can be undone later. The ids are what was actually
/// written — rows the commit skipped as duplicates are not in here.
struct ImportBatch: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var date: Date
    var itemIDs: [String]
    /// Names as they were imported, so the entry still reads after the items
    /// have been renamed or deleted one by one.
    var itemNames: [String]
    /// Always false now: imports stopped raising card debt. Kept so older
    /// batches decode.
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
    /// Items this import overwrote rather than added — a sheet row that says
    /// sold lands on the item the book already has. These are the items *as
    /// they stood before*, so undo can put them back exactly. Optional: no
    /// batch written before this existed has the key.
    var updatedItems: [Item]? = nil

    /// Items this import added. Overwrites are counted on their own, because
    /// "3 of 5 still in the book" is about items that were added.
    var count: Int { itemIDs.count }
    /// Items it wrote a sale over instead of adding.
    var updatedCount: Int { updatedItems?.count ?? 0 }
    var changedCount: Int { count + updatedCount }
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
