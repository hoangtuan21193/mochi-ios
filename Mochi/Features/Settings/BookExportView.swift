import SwiftUI

/// The book, or some parts of it, as a `.mochi` file to share. Every part is
/// on to begin with: the usual reason to export is a copy of everything.
struct BookExportView: View {
    @Environment(Store.self) private var store
    @State private var groups = Set(BookGroup.allCases)
    @State private var shareURL: URL?

    var body: some View {
        SheetScaffold(title: "Export book") {
            Card(padding: .list) {
                ForEach(Array(BookGroup.allCases.enumerated()), id: \.element) { i, g in
                    if i > 0 { Hairline() }
                    ToggleRow(title: Text(verbatim: g.title), detail: detail(g), isOn: binding(g))
                }
            }
            Text(verbatim: preview).font(Organic.meta).foregroundStyle(Organic.n600)
            PrimaryButton(title: "Share file", icon: "square.and.arrow.up") {
                shareURL = store.exportBookFile(groups: groups)
            }
            .disabled(groups.isEmpty)
            HelpText("Open the file on another iPhone and Mochi asks which parts to take, and whether to replace or merge them.")
        }
        .sheet(item: $shareURL) { ShareSheet(items: [$0]) }
    }

    private func binding(_ g: BookGroup) -> Binding<Bool> {
        Binding(get: { groups.contains(g) }, set: { if $0 { groups.insert(g) } else { groups.remove(g) } })
    }

    private func detail(_ g: BookGroup) -> Text? {
        guard let n = BookTransfer.count(g, in: store.data) else { return Text("Currency, language, fees, what Home counts") }
        return Text("\(n) in the book")
    }

    private var preview: String {
        guard !groups.isEmpty else { return String(localized: "Pick at least one part.") }
        let name = "mochi-book-\(Date.now.formatted(.iso8601.year().month().day())).\(Store.bookExtension)"
        return String(localized: "\(name) · \(groups.count) of \(BookGroup.allCases.count) parts")
    }
}
