import Foundation

extension Store {
    /// When the app comes to the front: take the iCloud copy if it is newer
    /// than this phone's last save (keeping this one as a timed backup
    /// first), then send this phone's book up. A no-op until sharing is on.
    @MainActor
    func syncWithCloud() async {
        guard CloudSync.isEnabled else { return }
        // The copy this phone just sent comes back newer by a second; only a
        // book that actually differs replaces this one.
        if let (remote, saved) = try? await CloudSync.pull(), saved > (lastLocalSave ?? .distantPast),
           (try? JSONEncoder().encode(remote)) != (try? JSONEncoder().encode(data)) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("cloud-incoming.json")
            if (try? JSONEncoder().encode(remote).write(to: url, options: .atomic)) != nil { replaceBook(with: url) }
        }
        try? await CloudSync.push(data)
    }

    /// When this phone last wrote the book, read off the file itself.
    var lastLocalSave: Date? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let attrs = try? FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent("mochi.json").path)
        return attrs?[.modificationDate] as? Date
    }
}
