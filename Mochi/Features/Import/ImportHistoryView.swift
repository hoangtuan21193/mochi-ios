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
                Text(verbatim: batch.date.formatted(date: .abbreviated, time: .shortened))
                    .font(Organic.rowValue)
                Spacer()
                Badge("Records only")
            }
            HelpText("\(batch.count) items · \(batch.source)").padding(.top, 2)
            if batch.updatedCount > 0 {
                HelpText("\(batch.updatedCount) items it marked sold, from rows for purchases already in the book.")
                    .padding(.top, 2)
            }
            if let made = batch.createdChannels, !made.isEmpty {
                HelpText("Created channels: \(made.joined(separator: " · "))", tone: .warning)
                    .padding(.top, 2)
            }
            Text(verbatim: nameList(batch))
                .font(Organic.caption).foregroundStyle(Organic.n700)
                .padding(.top, 6)

            // What is left is what matters: items deleted since, or an import
            // already undone, must not promise a removal that cannot happen.
            Text(status(batch, left: left.count, sold: sold))
                .font(Organic.captionStrong)
                .foregroundStyle(left.isEmpty ? Organic.n600 : Organic.a800)
                .padding(.top, 6)

            if left.isEmpty && batch.updatedCount > 0 {
                DeleteButton(title: "Put \(batch.updatedCount) item(s) back") { confirming = batch }
                    .padding(.top, 10)
                SecondaryButton(title: "Leave them, drop this entry") { store.forgetImportBatch(batch) }
                    .padding(.top, 6)
            } else if left.isEmpty {
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
        return rest > 0 ? String(localized: "\(shown) · and \(rest) more") : shown
    }

    private func status(_ batch: ImportBatch, left: Int, sold: Int) -> LocalizedStringKey {
        if left == 0 && batch.updatedCount > 0 && batch.count == 0 {
            return "This import added nothing — it marked \(batch.updatedCount) items sold."
        }
        if left == 0 { return "None of these are in the book any more." }
        if sold > 0 { return "\(left) of \(batch.count) still in the book · \(sold) sold since" }
        return "\(left) of \(batch.count) still in the book"
    }

    private var confirmMessage: String {
        guard let batch = confirming else { return "" }
        let left = store.remainingItems(of: batch)
        let sold = left.filter(\.isSold).count
        // Sentence by sentence, each looked up on its own, so a translation can
        // rearrange one without the others having to agree with it.
        var text = String(localized: "\(left.count) items from this import go out of Inventory.")
        if batch.updatedCount > 0 {
            text += " " + String(localized: "The \(batch.updatedCount) items it marked sold go back to how they were.")
        }
        if let made = batch.createdChannels, !made.isEmpty {
            text += " " + String(localized: "The \(made.count) channels this import created go too, unless something else is using them.")
        }
        if sold > 0 {
            text += " " + String(localized: "\(sold) of them sold — the sale records go with them; your wallets are untouched.")
        }
        return text + " " + String(localized: "This cannot be undone.")
    }
}
