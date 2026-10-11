import SwiftUI
import UniformTypeIdentifiers

/// Paste a sheet or open a file, look at what it read, then import.
/// Nothing is written until the last button.
struct ImportView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var preview: Store.ImportPreview?
    @State private var pickingFile = false
    @State private var fileError: String?
    @State private var imported: Int?
    @State private var showingColumns = false
    @State private var showingHistory = false
    /// Where this text came from, kept for the history entry.
    @State private var source = "Pasted"
    /// The entry the last import wrote, so it can be taken back from this screen.
    @State private var lastBatch: ImportBatch?
    @State private var confirmingUndo = false
    /// Per channel name the sheet wrote: which of the book's channels to read
    /// it as. Absent = the preview's own match; "" = create one of that name.
    @State private var channelTarget: [String: String] = [:]
    /// Fee typed for each channel this sheet is about to create, keyed by name.
    @State private var newChannelRates: [String: String] = [:]
    /// Channels being created as point channels rather than cash.
    @State private var newChannelPoints: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let imported { doneCard(imported) } else {
                        sourceCard
                        exampleCard
                        if let preview {
                            previewCard(preview)
                            if !preview.channels.isEmpty { channelsCard(preview) }
                            importButton(preview)
                        }
                    }
                    // Last on the screen, and there whatever else is: past
                    // imports outlive the session that made them, so the way
                    // back to them cannot depend on importing again first.
                    historyCard
                }
                .padding(16)
                .readableWidth()
            }
            .background(Organic.bg)
            .navigationTitle("Import items")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { KeyboardDismiss.now() }
                }
            }
            // A sheet presented under the same identity is reused, so without
            // this the screen comes back showing the last import's result.
            .task {
                text = ""; preview = nil; imported = nil
                showingColumns = false; fileError = nil
                source = "Pasted"; lastBatch = nil; newChannelRates = [:]
                channelTarget = [:]; newChannelPoints = []
            }
            .sheet(isPresented: $showingHistory) { ImportHistoryView() }
            .fileImporter(isPresented: $pickingFile,
                          allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .text],
                          allowsMultipleSelection: false) { result in
                load(result)
            }
        }
    }

    // MARK: - History

    /// Every past import, with the items each one wrote and a way to take them
    /// back out. Shown empty too, so the screen says what it will remember.
    private var historyCard: some View {
        Card {
            if store.importHistory.isEmpty {
                Text("Import history").font(Organic.title)
                HelpText("No imports yet. Every one you make is kept here afterwards, with a button to take its items back out.")
                    .padding(.top, 4)
            } else {
                Button { showingHistory = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Import history").font(Organic.title)
                            HelpText(historySummary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(Organic.valueStrong).foregroundStyle(Organic.n500)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Says exactly what leaves with the items — debt handed back, channels
    /// taken away again — so the button is never a surprise.
    private func undoCardBody(_ batch: ImportBatch) -> String {
        // Two sentences, assembled: the second depends on what the batch made.
        // Each half is looked up on its own, so a translation can rebuild the
        // sentence its own way without the join being copy of its own.
        var first = String(localized: "This takes the \(batch.count) imported items back out.")
        if batch.updatedCount > 0 {
            first += " " + String(localized: "The \(batch.updatedCount) items it marked sold go back to how they were.")
        }
        if let made = batch.createdChannels, !made.isEmpty {
            return first + " " + String(localized: "The \(made.count) channels it created go too.")
        }
        return first + " " + String(localized: "Nothing else in the book changes.")
    }

    private func createdChannelSummary(_ names: [String]) -> String {
        names.map { name in
            let rate = store.data.channels.first { $0.name == name }?.rate ?? 0
            return "\(name) \(rate.formatted())%"
        }.joined(separator: " · ")
    }

    /// The undo takes back the channels the import invented as well, so the
    /// alert has to say so — a channel quietly vanishing is worse than one
    /// quietly staying.
    private var undoMessage: String {
        // Sentence by sentence: which ones appear depends on what the import
        // created, so each is looked up on its own and joined after.
        var text = String(localized: "Everything this import just wrote goes back out of Inventory.")
        if let made = lastBatch?.createdChannels, !made.isEmpty {
            text += " " + String(localized: "The \(made.count) channels it created go with it, unless something else is using them by then.")
            if let wallets = lastBatch?.createdWallets, !wallets.isEmpty {
                text += " " + String(localized: "Their \(wallets.count) wallets go too, as long as no money has landed in them.")
            }
        }
        return text + " " + String(localized: "This cannot be undone.")
    }

    private var historySummary: LocalizedStringKey {
        let history = store.importHistory
        let items = history.reduce(0) { $0 + $1.count }
        let last = history.first?.date.formatted(date: .abbreviated, time: .omitted) ?? ""
        return "\(history.count) imports · \(items) items · last \(last)"
    }

    // MARK: - Source

    private var sourceCard: some View {
        Card {
            Text("Paste a sheet").font(Organic.title)
            HelpText("One row per item. Only Name is needed — bring just the columns you have and leave the rest out. Tabs or commas both work.")
                .padding(.bottom, 8)

            TextEditor(text: $text)
                // A sheet is data, not prose: "Tamron" must not become a word.
                .autocorrectionDisabled()
                .font(Organic.mono)
                .scrollContentBackground(.hidden)
                .frame(height: 130)
                .padding(8)
                .background(Organic.n100, in: RoundedRectangle(cornerRadius: Organic.rInner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Organic.rInner).stroke(Organic.n300, lineWidth: Organic.stroke))
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Name\tCategory\tStatus\tDate\tBuy\tCard\tEst\tChannel…")
                            .font(Organic.mono)
                            .foregroundStyle(Organic.n500)
                            .padding(.horizontal, 13).padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: text) { _, new in
                    preview = new.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil : store.parseImport(new)
                }

            HStack(spacing: 8) {
                // A system PasteButton reads the clipboard without the
                // "Allow Paste?" alert that a manual UIPasteboard read triggers.
                PasteButton(payloadType: String.self) { strings in
                    guard let pasted = strings.first else { return }
                    Task { @MainActor in text = pasted; source = "Pasted" }
                }
                .buttonBorderShape(.capsule)
                .labelStyle(.titleAndIcon)
                .tint(Organic.n200)
                .frame(maxWidth: .infinity)

                SecondaryButton(title: "Open file", icon: "folder") { pickingFile = true }
            }
            .padding(.top, 8)

            if let fileError {
                HelpText(verbatim: fileError, tone: .warning).padding(.top, 6)
            }
        }
    }

    // MARK: - Example to work from

    /// A worked example in this book's own card and channel names, so it can be
    /// loaded and imported as-is, and a column-by-column key underneath it.
    private var exampleCard: some View {
        Card {
            Text("What a sheet looks like").font(Organic.title)
            HelpText("Two example rows, using your own card and channel names. One for sale, one already sold.")
                .padding(.bottom, 8)

            // One Text per line, each held to a single line, so the columns
            // stay in columns and the block scrolls sideways instead of
            // wrapping into unreadable paragraphs.
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(store.importExample.components(separatedBy: "\n").enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(Organic.mono)
                            .fontWeight(index == 0 ? .bold : .regular)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .textSelection(.enabled)
                    }
                }
                .padding(11)
                .readableWidth()
            }
            .background(Organic.n100, in: RoundedRectangle(cornerRadius: Organic.rInner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Organic.rInner).stroke(Organic.n300, lineWidth: Organic.stroke))

            HStack(spacing: 8) {
                SecondaryButton(title: "Try it in the box", icon: "arrow.up.doc") { text = store.importExample }
                SecondaryButton(title: "Copy", icon: "doc.on.doc") { UIPasteboard.general.string = store.importExample }
            }
            .padding(.top, 8)

            Button { withAnimation(.easeOut(duration: 0.18)) { showingColumns.toggle() } } label: {
                HStack(spacing: 5) {
                    Text(showingColumns ? "Hide the columns" : "What each column means")
                        .font(Organic.valueStrong)
                    Image(systemName: "chevron.down").font(Organic.metaStrong)
                        .rotationEffect(.degrees(showingColumns ? 180 : 0))
                }
                .foregroundStyle(Organic.a700)
                .padding(.top, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showingColumns {
                ForEach(Store.importColumnHelp, id: \.column) { entry in
                    HStack(alignment: .top, spacing: 8) {
                        Text(verbatim: entry.column)
                            .font(Organic.captionStrong)
                            .frame(width: 72, alignment: .leading)
                        HelpText(entry.help)
                    }
                    .padding(.vertical, 5)
                    .overlay(alignment: .top) { Hairline() }
                }
                HelpText("Columns you leave out are fine. Without a header row the order above is assumed.")
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Preview

    private func previewCard(_ preview: Store.ImportPreview) -> some View {
        Card {
            HStack {
                Text("Read \(preview.rows.count) row(s)").font(Organic.title)
                Spacer()
                Text(preview.recognisedHeader ? "Header row found" : "No header row")
                    .font(Organic.meta).foregroundStyle(Organic.n600)
            }
            columnSummary(preview)
            if preview.duplicateCount > 0 || preview.updateCount > 0 { duplicateBar(preview) }

            ForEach(Array(preview.rows.enumerated()), id: \.element.id) { index, row in
                rowLine(row, index: index)
            }

            if !preview.failures.isEmpty {
                Text("Skipped").font(Organic.valueStrong)
                    .foregroundStyle(Organic.a800).padding(.top, 10)
                ForEach(preview.failures, id: \.line) { failure in
                    HelpText("Line \(failure.line): \(failure.reason)", tone: .warning)
                        .padding(.top, 2)
                }
            }
        }
    }

    /// Which columns the sheet turned out to have. A partial sheet is normal —
    /// only Name is needed — so this says what was read rather than complaining
    /// about what was missing.
    private func columnSummary(_ preview: Store.ImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if !preview.usedColumns.isEmpty {
                Text((preview.recognisedHeader ? "Using: " : "Read as: ")
                     + preview.usedColumns.joined(separator: " · "))
                    .font(Organic.meta).foregroundStyle(Organic.n600)
            }
            if !preview.recognisedHeader {
                Text("No header row, so the columns were taken in the order above. Add a header line and they can be in any order — and you can leave out the ones you do not have.")
                    .font(Organic.meta).foregroundStyle(Organic.a800)
            }
            if !preview.ignoredHeaders.isEmpty {
                Text("Ignored: " + preview.ignoredHeaders.joined(separator: " · "))
                    .font(Organic.meta).foregroundStyle(Organic.n500)
            }
        }
        .padding(.top, 4)
    }

    /// Sits above the rows: says what matched and switches the lot on or off,
    /// so a hundred-row paste does not need a hundred taps.
    ///
    /// Two lines, because there are two kinds of match and one pair of chips
    /// could only ever tell the truth about one of them. Repeats are skipped;
    /// rows that say sold write over the item you already have. The second line
    /// exists because "Skip them" sitting alone read as "nothing here changes
    /// the book", while the sold rows changed it anyway.
    private func duplicateBar(_ preview: Store.ImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if preview.duplicateCount > 0 {
                HelpText("\(preview.duplicateCount) are the same purchase as something you already have, or a row this sheet repeats — same item, same purchase date, same market. They are off by default; a row that only shares a name or a date is a different purchase and comes in.")
                HStack(spacing: 5) {
                    Button { setDuplicates(included: false) } label: {
                        Chip(label: Text("Skip them"), selected: preview.includedDuplicateCount == 0)
                    }
                    .buttonStyle(.plain)
                    Button { setDuplicates(included: true) } label: {
                        // Both chips read the same thing — how many flagged rows
                        // are switched on — because that is what they set. Against
                        // the blocked count instead, a sheet whose only flags were
                        // "same name" left both chips looking chosen at once.
                        Chip(label: Text("Import anyway"),
                             selected: preview.includedDuplicateCount == preview.duplicateCount,
                             tint: Organic.a600)
                    }
                    .buttonStyle(.plain)
                }
            }
            if preview.updateCount > 0 {
                HelpText("\(preview.updateCount) say sold for a purchase already in your book. They add nothing — they mark the item you have as sold, and are on by default because the sheet knows the sale and the book does not.")
                    .padding(.top, preview.duplicateCount > 0 ? 6 : 0)
                HStack(spacing: 5) {
                    Button { setUpdates(included: true) } label: {
                        Chip(label: Text("Mark them sold"),
                             selected: preview.includedUpdateCount == preview.updateCount)
                    }
                    .buttonStyle(.plain)
                    Button { setUpdates(included: false) } label: {
                        Chip(label: Text("Leave mine as they are"),
                             selected: preview.includedUpdateCount == 0,
                             tint: Organic.a600)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 4).padding(.bottom, 2)
    }

    private func setDuplicates(included: Bool) {
        guard var current = preview else { return }
        for index in current.rows.indices where current.rows[index].isDuplicate {
            current.rows[index].include = included
        }
        preview = current
    }

    private func setUpdates(included: Bool) {
        guard var current = preview else { return }
        for index in current.rows.indices where current.rows[index].isUpdate {
            current.rows[index].include = included
        }
        preview = current
    }

    /// One row, tappable to include or leave out.
    private func rowLine(_ row: Store.ImportRow, index: Int) -> some View {
        Button { self.preview?.rows[index].include.toggle() } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: row.include ? "checkmark.circle.fill" : "circle")
                        .font(Organic.body)
                        .foregroundStyle(row.include ? Organic.s600 : Organic.n400)
                    Text(row.item.name).font(Organic.row)
                    // Every match is badged, not only the ones that block: a
                    // row that shares a name is worth a look even though it
                    // comes in, and a sold row landing on an item you already
                    // have says so rather than looking like a new purchase.
                    if row.isUpdate {
                        Badge("Marks yours sold", tone: .sage)
                    } else if row.duplicate != .none {
                        Badge(row.duplicate.tag, tone: row.isDuplicate ? .accent : .neutral)
                    }
                    Spacer()
                    Text(store.format(row.item.buyPrice) + " → " + store.format(row.item.estimatedPrice))
                        .font(Organic.captionStrong)
                }
                Text(verbatim: subtitle(row)).font(Organic.meta).foregroundStyle(Organic.n600)
                if !row.duplicateDetail.isEmpty {
                    Text(row.duplicateDetail).font(Organic.meta).foregroundStyle(Organic.a800)
                }
                ForEach(row.warnings, id: \.self) { warning in
                    Text(warning).font(Organic.meta).foregroundStyle(Organic.a800)
                }
            }
            .opacity(row.include ? 1 : 0.45)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .overlay(alignment: .top) { Hairline() }
        }
        .buttonStyle(.plain).foregroundStyle(Organic.text)
    }

    private func subtitle(_ row: Store.ImportRow) -> String {
        var bits: [String] = []
        if !row.item.categoryName.isEmpty { bits.append(row.item.categoryName) }
        if !row.item.cardName.isEmpty { bits.append(row.item.cardName) }
        if !row.item.plannedChannel.isEmpty { bits.append(row.item.plannedChannel) }
        bits.append(row.item.isSold ? String(localized: "sold")
                    : (row.item.keep ? String(localized: "keeping") : String(localized: "for sale")))
        bits.append(row.item.boughtOn.formatted(date: .numeric, time: .omitted))
        return bits.joined(separator: " · ")
    }

    // MARK: - Options and commit

    /// The one action on the screen, so it sits on the background rather than
    /// inside the card of the last option that happens to precede it.
    private func importButton(_ preview: Store.ImportPreview) -> some View {
        PrimaryButton(title: "Import \(preview.includedCount) item(s)") {
            guard let current = self.preview else { return }
            imported = store.commitImport(current, source: source, channelPlans: plans(current))
            lastBatch = store.importHistory.first
        }
        .padding(.top, 2)
        .disabled(preview.includedCount == 0)
        .opacity(preview.includedCount == 0 ? 0.5 : 1)
    }

    // MARK: - Channels the sheet brings

    /// Every channel the sheet names, and what happens to each. The rule of
    /// the card: a control appears only where there is a real choice. A book
    /// with no channels yet gets no "read as" menu — everything is created,
    /// and the one thing to type is the fee. A book with channels gets the
    /// menu, because a match is a guess and a new name might be a misspelling
    /// of an old one.
    private func channelsCard(_ preview: Store.ImportPreview) -> some View {
        let creating = preview.channels.filter { willCreate($0) }.count
        let total = preview.channels.count
        return Card {
            Text("Sales channels in this sheet").font(Organic.title)
            HelpText(channelsIntro(total: total, creating: creating))
                .padding(.bottom, 4)
            ForEach(preview.channels) { use in channelRow(use) }
            if creating > 0 {
                Text("A fee is what the marketplace keeps: Mercari 10%, PayPay Flea 5%, Y!Auction 8.8%. Leave it 0 if unsure — Settings can fix it later.")
                    .font(Organic.meta).foregroundStyle(Organic.n500).padding(.top, 8)
            }
        }
    }

    private func channelsIntro(total: Int, creating: Int) -> LocalizedStringKey {
        if store.data.channels.isEmpty {
            return total == 1
                ? "Your book has no channels yet, so this one is created on import. Type its fee; a wallet for its money is made alongside."
                : "Your book has no channels yet, so all \(total) are created on import. Type each fee; a wallet for each is made alongside."
        }
        if creating == 0 {
            return "All \(total) were matched to channels you already have. Tap a match to change it."
        }
        let matched = total - creating
        return "\(matched) matched channels you already have; \(creating) are new and will be created. A new name that is really one of yours misspelt can be pointed at it."
    }

    /// The book channel this written name maps to, or nil when it is to be created.
    private func target(_ use: Store.ChannelUse) -> String? {
        if let chosen = channelTarget[use.written] { return chosen.isEmpty ? nil : chosen }
        return use.matched
    }
    private func willCreate(_ use: Store.ChannelUse) -> Bool { target(use) == nil }

    /// Line 1: the name, and — for a new channel — the fee to type. Line 2: what
    /// the import will do with it, with a way to change that only when the book
    /// offers an alternative.
    private func channelRow(_ use: Store.ChannelUse) -> some View {
        let creating = willCreate(use)
        let isPoints = newChannelPoints.contains(use.written)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .center, spacing: 10) {
                Text(use.written).font(Organic.row).lineLimit(1)
                Text("\(use.rows) rows")
                    .font(Organic.meta).foregroundStyle(Organic.n500)
                Spacer(minLength: 8)
                if creating {
                    FormField {
                        HStack(spacing: 2) {
                            TextField("0", text: Binding(
                                get: { newChannelRates[use.written] ?? "" },
                                set: { newChannelRates[use.written] = $0 }))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 40)
                            Text("%").foregroundStyle(Organic.n600)
                        }
                    }
                    .fixedSize()
                    ToggleChip(label: isPoints ? "Point" : "Cash",
                               tint: isPoints ? Organic.a600 : Organic.s600) {
                        if isPoints { newChannelPoints.remove(use.written) } else { newChannelPoints.insert(use.written) }
                    }
                } else if let matched = target(use),
                          let channel = store.data.channels.first(where: { $0.name == matched }) {
                    Text("\(channel.rate.formatted())%")
                        .font(Organic.valueStrong).foregroundStyle(Organic.n700)
                }
            }
            outcomeLine(use, creating: creating, isPoints: isPoints)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .top) { Hairline() }
    }

    /// "New — created on import" or "Read as Mercari", followed by a change
    /// link when the book has channels to choose between.
    private func outcomeLine(_ use: Store.ChannelUse, creating: Bool, isPoints: Bool) -> some View {
        HStack(spacing: 6) {
            if creating {
                Badge("NEW", tone: .accent)
                Text(isPoints ? "Created as a point channel" : "Created on import")
                    .font(Organic.caption).foregroundStyle(Organic.n700)
            } else {
                HelpText(use.written == target(use) ? "Already in your book" : "Read as your \"\(target(use) ?? "")\"",
                         tone: .positive)
            }
            if !store.data.channels.isEmpty {
                targetMenu(use, creating: creating)
            }
            Spacer()
        }
    }

    /// Only rendered when the book has channels — the menu then always holds
    /// at least two real alternatives: the book's channels, and creating.
    private func targetMenu(_ use: Store.ChannelUse, creating: Bool) -> some View {
        Menu {
            Section(creating ? "Read it as one of yours instead" : "Read it as") {
                ForEach(store.data.channels) { ch in
                    Button {
                        channelTarget[use.written] = ch.name
                    } label: {
                        if target(use) == ch.name { Label(ch.name, systemImage: "checkmark") } else { Text(ch.name) }
                    }
                }
            }
            if !creating, !store.data.channels.contains(where: { $0.name == use.written }) {
                Section {
                    Button("Create \"\(use.written)\" as a new channel") { channelTarget[use.written] = "" }
                }
            }
        } label: {
            LinkLabel(creating ? "Map to existing" : "Change")
        }
    }

    /// One decision per written name, for the commit.
    private func plans(_ preview: Store.ImportPreview) -> [String: Store.ImportChannelPlan] {
        var out: [String: Store.ImportChannelPlan] = [:]
        for use in preview.channels {
            if let t = target(use) {
                out[use.written] = .use(t)
            } else {
                let typed = (newChannelRates[use.written] ?? "")
                    .replacingOccurrences(of: "%", with: "")
                    .replacingOccurrences(of: ",", with: ".")
                    .trimmingCharacters(in: .whitespaces)
                out[use.written] = .create(rate: Double(typed) ?? 0,
                                           isPoints: newChannelPoints.contains(use.written))
            }
        }
        return out
    }


    private func doneCard(_ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Card(fill: Organic.s100) {
                // Added and overwritten are counted apart: a row that marks an
                // item you already own as sold added nothing to Inventory, and
                // calling it "imported" would send you looking for a new item.
                let added = lastBatch?.count ?? count
                let updated = lastBatch?.updatedCount ?? 0
                Text("Imported \(added) item(s)").font(Organic.title)
                    .foregroundStyle(Organic.s900)
                if updated > 0 {
                    Text("\(updated) item(s) you already had are now marked sold, from the rows that said so.")
                        .font(Organic.caption).foregroundStyle(Organic.s900).padding(.top, 2)
                }
                Text("They are in Inventory now. Any item's category, date or channel can be changed from its own page.")
                    .font(Organic.caption).foregroundStyle(Organic.s900).padding(.top, 2)
                if let made = lastBatch?.createdChannels, !made.isEmpty {
                    Text("Created \(made.count) sales channels: \(createdChannelSummary(made)), each paying into its own wallet. Editable in Settings.")
                        .font(Organic.caption).foregroundStyle(Organic.s900).padding(.top, 6)
                }
                PrimaryButton(title: "Done") { dismiss() }.padding(.top, 10)
            }
            // The moment a wrong sheet is noticed is this one, so the way back
            // out sits here as well as in the history list.
            // An import that only marked things sold added nothing, and still
            // has to be undoable.
            if let batch = lastBatch,
               !store.remainingItems(of: batch).isEmpty || batch.updatedCount > 0 {
                Card {
                    Text("Wrong sheet?").font(Organic.title)
                    HelpText(verbatim: undoCardBody(batch)).padding(.top, 4)
                    DeleteButton(title: "Undo this import") { confirmingUndo = true }
                        .padding(.top, 10)
                }
            }
            if !store.looseCategoryNames.isEmpty { looseCategoriesCard }
        }
        .alert("Undo this import?", isPresented: $confirmingUndo) {
            Button("Remove", role: .destructive) {
                if let batch = lastBatch {
                    store.deleteImportBatch(batch)
                    lastBatch = nil
                    imported = nil
                    text = ""; preview = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(undoMessage)
        }
    }

    /// Category names the sheet brought that this book does not define. They
    /// work as labels either way, but only a real category carries an attribute
    /// checklist — so the offer to promote them belongs right here.
    private var looseCategoriesCard: some View {
        Group {
            SectionHeader(title: "Categories from the sheet",
                          subtitle: "Labels on the items, not categories yet. Making one real gives it an attribute checklist; leaving it alone changes nothing.")
            Card(padding: .list) {
                ForEach(Array(store.looseCategoryNames.enumerated()), id: \.element) { index, name in
                    HStack {
                        Text(name).font(Organic.row)
                        Spacer()
                        HelpText("\(store.data.items.filter { $0.categoryName == name }.count) item(s)")
                        MiniButton(title: "Add", style: .accent) {
                            store.addCategory(Category(name: name, attributes: []))
                        }
                    }
                    .padding(.vertical, Organic.Space.row)
                    .overlay(alignment: .top) { if index > 0 { Hairline() } }
                }
            }
        }
    }

    // MARK: - File

    private func load(_ result: Result<[URL], Error>) {
        fileError = nil
        do {
            guard let url = try result.get().first else { return }
            // Files handed over by the picker live outside the app's sandbox.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard let string = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .shiftJIS) else {
                fileError = String(localized: "That file is not text this app can read.")
                return
            }
            text = string
            source = url.lastPathComponent
        } catch {
            fileError = String(localized: "Could not open that file: \(error.localizedDescription)")
        }
    }
}
