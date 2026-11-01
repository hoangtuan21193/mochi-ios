import Foundation

/// A purchase saved from Share › Mochi, waiting in the App Group until the app
/// opens and books it (`Store.takeSharedEntries`). The share extension never
/// writes the book itself: two processes writing one file is how a book gets
/// lost, and the app may be open behind the sheet. Compiled into both targets.
struct SharedEntry: Codable, Identifiable, Equatable {
    /// Why it was bought — the same choice Add a belonging offers, plus a
    /// spend for something that is not kept as a belonging at all.
    enum Purpose: String, Codable, CaseIterable { case sell, use, spend }

    var id: String = UUID().uuidString
    var date: Date
    var name: String
    var price: Int
    var shop: String
    var account: String
    var purpose: Purpose
    var link: String?
}

/// The little the share sheet needs to know about the book, written by the
/// app next to `widget.json` on every save. The extension reads this instead
/// of the book, which is too big to open inside a share sheet.
struct ShareSnapshot: Codable, Equatable {
    /// Wallets first, then cards — the order every account picker uses.
    var accounts: [String]
    /// A shop as `Item.boughtFrom` writes it → the account it was last paid from.
    var lastAccount: [String: String]
    /// Shops whose last belonging was bought to sell, so the sheet starts on "To sell" there.
    var resellShops: [String]
    /// Every shop name in the book, so a page's "メルカリ" lands on the book's "Mercari".
    var shops: [String]
    /// A link already in the book → what came from it, so sharing it twice says so.
    var links: [String: Known]
    var lookUpListings: Bool
    /// `Currency` raw value (its symbol), as `AppData.currency` stores it.
    var currency: String

    struct Known: Codable, Equatable {
        var name: String
        var date: Date
    }
}

/// Where the app and the share extension meet: one snapshot file one way,
/// one file per saved purchase the other.
enum ShareInbox {
    static let appGroup = "group.com.hoangtuan.mochi"
    static let snapshotFile = "share.json"
    static let folder = "share-inbox"

    static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    static func readSnapshot() -> ShareSnapshot? {
        guard let url = container?.appendingPathComponent(snapshotFile),
              let blob = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ShareSnapshot.self, from: blob)
    }

    static func write(_ snapshot: ShareSnapshot) {
        guard let url = container?.appendingPathComponent(snapshotFile),
              let blob = try? JSONEncoder().encode(snapshot) else { return }
        // Skipped when unchanged: this runs on every save of the book.
        if (try? Data(contentsOf: url)) == blob { return }
        try? blob.write(to: url, options: .atomic)
    }

    static func add(_ entry: SharedEntry) throws {
        guard let base = container else { throw CocoaError(.fileNoSuchFile) }
        let dir = base.appendingPathComponent(folder, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try JSONEncoder().encode(entry).write(to: dir.appendingPathComponent("\(entry.id).json"), options: .atomic)
    }

    /// Oldest first, so two things shared in a row land in the order they were bought.
    static func pending() -> [(url: URL, entry: SharedEntry)] {
        guard let dir = container?.appendingPathComponent(folder, isDirectory: true),
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let blob = try? Data(contentsOf: url),
                      let entry = try? JSONDecoder().decode(SharedEntry.self, from: blob) else { return nil }
                return (url, entry)
            }
            .sorted { $0.entry.date < $1.entry.date }
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
