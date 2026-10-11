import Foundation
import CloudKit

/// Sharing the book between two iPhones through the app's own iCloud
/// container (CloudKit). The book travels as one record in a zone of its own,
/// holding the JSON file as an asset; the newer copy wins and the one it
/// replaces is kept as a timed backup first, so nothing is lost to a race.
/// The zone is what gets shared with the partner (a zone-wide CKShare).
///
/// The container belongs to the developer team, and the capability has to be
/// on for the build, so all of this stays switched off until Info.plist says
/// `MochiCloudSyncEnabled` and the user is signed in to iCloud — see
/// docs/setup-xcode.md. A personal (free) team cannot sign the iCloud
/// entitlement at all, so it lives in `Mochi-iCloud.entitlements`, and the
/// flag must only be set on a build signed with that file: `CKContainer`
/// traps without it.
enum CloudSync {
    static let containerID = "iCloud.com.hoangtuan.mochi"
    static let zone = CKRecordZone.ID(zoneName: "Book", ownerName: CKCurrentUserDefaultName)
    static let recordID = CKRecord.ID(recordName: "book", zoneID: zone)

    static var isEnabled: Bool {
        Bundle.main.object(forInfoDictionaryKey: "MochiCloudSyncEnabled") as? Bool == true
            && FileManager.default.ubiquityIdentityToken != nil
    }

    private static var database: CKDatabase { CKContainer(identifier: containerID).privateCloudDatabase }

    /// Sends the book up. Creates the zone the first time.
    static func push(_ data: AppData) async throws {
        guard isEnabled else { return }
        _ = try? await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zone)], deleting: [])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cloud-book.json")
        try JSONEncoder().encode(data).write(to: url, options: .atomic)
        let record = (try? await database.record(for: recordID)) ?? CKRecord(recordType: "Book", recordID: recordID)
        record["file"] = CKAsset(fileURL: url)
        record["savedAt"] = Date.now as NSDate
        _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .changedKeys)
    }

    /// The book in iCloud and when it was saved, if there is one.
    static func pull() async throws -> (AppData, Date)? {
        guard isEnabled, let record = try? await database.record(for: recordID),
              let asset = record["file"] as? CKAsset, let url = asset.fileURL,
              let saved = record["savedAt"] as? Date else { return nil }
        let data = try JSONDecoder().decode(AppData.self, from: Data(contentsOf: url))
        return (data, saved)
    }

    /// A share of the whole zone, for the invite sheet.
    static func share(title: String) async throws -> CKShare? {
        guard isEnabled else { return nil }
        let share = CKShare(recordZoneID: zone)
        share[CKShare.SystemFieldKey.title] = title as NSString
        share.publicPermission = .none
        _ = try await database.modifyRecords(saving: [share], deleting: [])
        return share
    }
}
