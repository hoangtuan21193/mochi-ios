import SwiftUI

/// What a book file would change, part by part, before anything is written.
/// Opened by Settings › Import and by a `.mochi` file opened from outside
/// (share sheet, AirDrop, Files). Only the parts that differ from the book
/// start switched on, so "take the file" never quietly rewrites the rest.
struct BookImportView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let url: URL
    /// Told what happened, for the line under Backups.
    var onDone: ((String) -> Void)? = nil

    @State private var file: AppData?
    @State private var unreadable = false
    @State private var groups: Set<BookGroup> = []
    @State private var mode: BookImportMode = .replace
    @State private var confirming = false

    var body: some View {
        SheetScaffold(title: "Import book") {
            if let file {
                content(file)
            } else if unreadable {
                Card {
                    CardHeader(title: "This is not a Mochi book",
                               subtitle: "Nothing was changed. Export from Mochi gives a file ending in .mochi; a book exported before that ends in .json.")
                }
            }
        }
        // Keyed by the file: a second file opened while this sheet is up must
        // not show the first one's parts.
        .task(id: url) {
            file = nil; unreadable = false
            if let read = store.readBookFile(url) {
                file = read
                groups = Set(BookTransfer.groups(in: read).filter { BookTransfer.differs($0, book: store.data, file: read) })
            } else {
                unreadable = true
            }
        }
    }

    @ViewBuilder private func content(_ file: AppData) -> some View {
        let inFile = Set(BookTransfer.groups(in: file))
        Card {
            Text(verbatim: url.lastPathComponent).font(Organic.title)
            HelpText("Pick the parts to take. Parts left off stay as they are in this book.")
        }
        ListHeading(title: "From the file")
        Card(padding: .list) {
            ForEach(Array(BookGroup.allCases.enumerated()), id: \.element) { i, g in
                if i > 0 { Hairline() }
                ToggleRow(title: Text(verbatim: g.title), detail: detail(g, file: file, inFile: inFile.contains(g)),
                          isOn: binding(g), enabled: inFile.contains(g))
            }
        }
        if groups.contains(where: \.canMerge) {
            SegmentedTabs(options: BookImportMode.allCases, selection: $mode) { m in
                m == .replace ? "Replace" : "Merge"
            }
            HelpText(mode == .replace
                     ? "Each part becomes exactly what the file has. What only this book has in it goes."
                     : "Adds what only the file has and takes the file's copy of anything in both. Nothing in this book goes. Settings are always replaced.")
        }
        Text(verbatim: preview(file)).font(Organic.meta).foregroundStyle(Organic.n600)
        PrimaryButton(title: buttonTitle, icon: "square.and.arrow.down") { confirming = true }
            .disabled(groups.isEmpty)
        .alert(alertTitle, isPresented: $confirming) {
            Button(mode == .replace ? "Replace" : "Merge", role: .destructive) {
                store.importBook(file, groups: groups, mode: mode)
                onDone?(String(AttributedString(localized: "Took ^[\(groups.count) part](inflect: true) from \(url.lastPathComponent).").characters))
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The book as it is now is kept as a timed copy under Earlier copies first, so this can be undone.")
        }
    }

    private func binding(_ g: BookGroup) -> Binding<Bool> {
        Binding(get: { groups.contains(g) }, set: { if $0 { groups.insert(g) } else { groups.remove(g) } })
    }

    private func detail(_ g: BookGroup, file: AppData, inFile: Bool) -> Text {
        guard inFile else { return Text("Not in this file") }
        guard BookTransfer.differs(g, book: store.data, file: file) else { return Text("Same as this book") }
        guard let mine = BookTransfer.count(g, in: store.data), let theirs = BookTransfer.count(g, in: file) else {
            return Text("Differs from this book")
        }
        return Text("Book \(mine) · file \(theirs)")
    }

    private var buttonTitle: LocalizedStringKey {
        mode == .replace || !groups.contains(where: \.canMerge) ? "Replace ^[\(groups.count) part](inflect: true)…" : "Merge ^[\(groups.count) part](inflect: true)…"
    }

    private var alertTitle: LocalizedStringKey {
        mode == .replace ? "Replace ^[\(groups.count) part](inflect: true) of the book?" : "Merge ^[\(groups.count) part](inflect: true) into the book?"
    }

    /// "Belongings 459 → 644", a line a part: what each holds after.
    private func preview(_ file: AppData) -> String {
        guard !groups.isEmpty else { return String(localized: "Pick at least one part.") }
        return BookTransfer.preview(file, to: store.data, groups: groups, mode: mode).map { c in
            if let before = c.before, let after = c.after { return "\(c.group.title) \(before) → \(after)" }
            return String(localized: "\(c.group.title) replaced")
        }.joined(separator: "\n")
    }
}
