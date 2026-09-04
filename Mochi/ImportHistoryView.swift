import SwiftUI

/// Every import this book has taken, newest first, with the way back out.
/// An import is the one action that writes dozens of rows on a single tap, so
/// it is the one that most needs a single tap to take them back.
struct ImportHistoryView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// The batch waiting on a confirmation, if any.
    @State private var confirming: ImportBatch?
    @State private var removed: Int?

    var body: some View {
        SheetScaffold(title: "Import history") {
            // Outside the list, not inside it: undoing the only entry empties
            // the list, and the receipt has to survive that.
            if let removed {
                Card(fill: Organic.s100) {
                    Text("Removed \(removed) item(s)").font(Organic.title)
                        .foregroundStyle(Organic.s900)
                    Text("They are out of Inventory. Card debt they added, if any, went back with them.")
                        .font(Organic.caption).foregroundStyle(Organic.s900).padding(.top, 2)
                }
            }
            if store.importHistory.isEmpty {
                Card {
                    Text(removed == nil ? "No imports yet" : "Nothing left to undo")
                        .font(Organic.title)
                    HelpText("Every import is listed here afterwards, so a sheet pasted by mistake can be taken back out in one go.")
                        .padding(.top, 4)
                }
            } else {
                ForEach(store.importHistory) { batch in
                    batchCard(batch)
                }
            }
        }
        .alert("Remove these items?", isPresented: Binding(get: { confirming != nil },
                                                          set: { if !$0 { confirming = nil } })) {
            Button("Remove", role: .destructive) {
                if let batch = confirming { removed = store.deleteImportBatch(batch) }
                confirming = nil
            }
            Button("Cancel", role: .cancel) { confirming = nil }
        } message: {
            Text(confirmMessage)
        }
    }

    // MARK: - One import

    private func batchCard(_ batch: ImportBatch) -> some View {
        let left = store.remainingItems(of: batch)
        let sold = left.filter(\.isSold).count
        return Card {
            HStack(alignment: .firstTextBaseline) {
                Text(batch.date.formatted(date: .abbreviated, time: .shortened))
                    .font(Organic.rowValue)
                Spacer()
                Badge(batch.addedToDebt ? "On card debt" : "Records only",
                      tone: batch.addedToDebt ? .accent : .neutral)
            }
            HelpText("\(batch.count) item(s) · \(batch.source)").padding(.top, 2)
            if let made = batch.createdChannels, !made.isEmpty {
                HelpText("Created channel(s): " + made.joined(separator: " · "), tone: .warning)
                    .padding(.top, 2)
            }
            Text(nameList(batch))
                .font(Organic.caption).foregroundStyle(Organic.n700)
                .padding(.top, 6)

            // What is left is what matters: items deleted since, or an import
            // already undone, must not promise a removal that cannot happen.
            Text(status(batch, left: left.count, sold: sold))
                .font(Organic.captionStrong)
                .foregroundStyle(left.isEmpty ? Organic.n600 : Organic.a800)
                .padding(.top, 6)

            if left.isEmpty {
                SecondaryButton(title: "Remove from history") { store.forgetImportBatch(batch) }
                    .padding(.top, 10)
            } else {
                DeleteButton(title: "Remove \(left.count) item(s)") { confirming = batch }
                    .padding(.top, 10)
                SecondaryButton(title: "Keep them, drop this entry") { store.forgetImportBatch(batch) }
                    .padding(.top, 6)
            }
        }
    }

    private func nameList(_ batch: ImportBatch) -> String {
        let shown = batch.itemNames.prefix(3).joined(separator: " · ")
        let rest = batch.itemNames.count - 3
        return rest > 0 ? "\(shown) · and \(rest) more" : shown
    }

    private func status(_ batch: ImportBatch, left: Int, sold: Int) -> String {
        if left == 0 { return "None of these are in the book any more." }
        var text = "\(left) of \(batch.count) still in the book"
        if sold > 0 { text += " · \(sold) sold since" }
        return text
    }

    private var confirmMessage: String {
        guard let batch = confirming else { return "" }
        let left = store.remainingItems(of: batch)
        let sold = left.filter(\.isSold).count
        var text = "\(left.count) item(s) from this import go out of Inventory."
        if batch.addedToDebt {
            text += " The debt they put on your cards comes back off."
        }
        if let made = batch.createdChannels, !made.isEmpty {
            text += " The \(made.count) channel(s) this import created go too, unless something else is using them."
        }
        if sold > 0 {
            text += " \(sold) of them sold — that money already landed and is left where it is."
        }
        return text + " This cannot be undone."
    }
}
