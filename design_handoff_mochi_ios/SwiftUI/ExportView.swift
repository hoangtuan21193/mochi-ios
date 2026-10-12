import SwiftUI
import UniformTypeIdentifiers

/// Export inventory as TSV or CSV: copy, share sheet, or save to Files.
struct ExportView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var format: Store.ExportFormat = .tsv
    @State private var scope: Store.ExportScope = .all
    @State private var shareURL: URL? = nil

    private var text: String { store.exportText(format: format, scope: scope) }
    private var fileName: String {
        "inventory-\(Date.now.formatted(.iso8601.year().month().day())).\(format.rawValue)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Copy this and paste straight into Google Sheets — one row per item.")
                        .font(.system(size: 11.5)).foregroundStyle(Organic.n600)
                    HStack(spacing: 5) {
                        ForEach(Store.ExportFormat.allCases, id: \.self) { f in
                            Button { format = f } label: {
                                Chip(label: f.rawValue.uppercased(), selected: format == f)
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(Store.ExportScope.allCases, id: \.self) { s in
                            Button { scope = s } label: {
                                Chip(label: scopeLabel(s), selected: scope == s, tint: Organic.s300)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text(text)
                        .font(.system(size: 10.5, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(13)
                        .background(Organic.n100, in: RoundedRectangle(cornerRadius: Organic.rInner, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Organic.rInner).stroke(Organic.n300, lineWidth: 1.5))

                    PrimaryButton(title: "Copy everything", icon: "doc.on.doc") {
                        UIPasteboard.general.string = text
                    }
                    HStack(spacing: 8) {
                        secondary("Share file", "square.and.arrow.up") { shareURL = writeTempFile() }
                        secondary("Save file", "square.and.arrow.down") { shareURL = writeTempFile() }
                    }
                }
                .padding(16)
            }
            .background(Organic.bg)
            .navigationTitle("Export inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } } }
            .sheet(item: $shareURL) { url in ShareSheet(items: [url]) }
        }
    }

    private func scopeLabel(_ s: Store.ExportScope) -> String {
        switch s { case .all: "All"; case .forSale: "For sale"; case .sold: "Sold" }
    }

    private func secondary(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(title).font(.system(size: 13.5, weight: .heavy))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(Organic.n200, in: Capsule()).foregroundStyle(Organic.n800)
        }
    }

    private func writeTempFile() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? text.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }
}

extension URL: @retroactive Identifiable { public var id: String { absoluteString } }

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
