import SwiftUI
import UniformTypeIdentifiers

/// Paste a sheet or open a file, look at what it read, then import.
/// Nothing is written until the last button.
struct ImportView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var preview: Store.ImportPreview?
    @State private var addToCardDebt = false
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
    /// Wallet a created channel pays into. Absent = make one for it.
    @State private var newChannelDestination: [String: String] = [:]

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
                            optionsCard(preview)
                            importButton(preview)
                        }
                    }
                    // Last on the screen, and there whatever else is: past
                    // imports outlive the session that made them, so the way
                    // back to them cannot depend on importing again first.
                    historyCard
                }
                .padding(16)
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
                addToCardDebt = false; showingColumns = false; fileError = nil
                source = "Pasted"; lastBatch = nil; newChannelRates = [:]
                channelTarget = [:]; newChannelPoints = []; newChannelDestination = [:]
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
    private func undoCardBody(_ batch: ImportBatch, count: Int) -> String {
        var text = batch.addedToDebt
            ? "This takes the \(count) item(s) back out and gives the card debt back."
            : "This takes the \(count) item(s) back out."
        if let made = batch.createdChannels, !made.isEmpty {
            let wallets = batch.createdWallets?.count ?? 0
            text += wallets > 0
                ? " The \(made.count) channel(s) and \(wallets) wallet(s) it created go too, if still empty."
                : " The \(made.count) channel(s) it created go too."
        } else if !batch.addedToDebt {
            text += " Nothing else in the book changes."
        }
        return text
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
        var text = "Everything this import just wrote goes back out of Inventory."
        if let made = lastBatch?.createdChannels, !made.isEmpty {
            text += " The \(made.count) channel(s) it created go with it, unless something else is using them by then."
            if let wallets = lastBatch?.createdWallets, !wallets.isEmpty {
                text += " Their \(wallets.count) wallet(s) go too, as long as no money has landed in them."
            }
        }
        return text + " This cannot be undone."
    }

    private var historySummary: String {
        let history = store.importHistory
        let items = history.reduce(0) { $0 + $1.count }
        let last = history.first?.date.formatted(date: .abbreviated, time: .omitted) ?? ""
        return "\(history.count) import(s) · \(items) item(s) · last \(last)"
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
                HelpText(fileError, tone: .warning).padding(.top, 6)
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
                        Text(entry.column)
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
            if preview.duplicateCount > 0 { duplicateBar(preview) }

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
    private func duplicateBar(_ preview: Store.ImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HelpText("\(preview.duplicateCount) look like things you already have. They are off by default — two of the same lens is possible, so the choice stays yours.")
            HStack(spacing: 5) {
                Button { setDuplicates(included: false) } label: {
                    Chip(label: "Skip them", selected: preview.forcedDuplicateCount == 0)
                }
                .buttonStyle(.plain)
                Button { setDuplicates(included: true) } label: {
                    Chip(label: "Import anyway",
                         selected: preview.forcedDuplicateCount == preview.duplicateCount,
                         tint: Organic.a600)
                }
                .buttonStyle(.plain)
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

    /// One row, tappable to include or leave out.
    private func rowLine(_ row: Store.ImportRow, index: Int) -> some View {
        Button { self.preview?.rows[index].include.toggle() } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: row.include ? "checkmark.circle.fill" : "circle")
                        .font(Organic.body)
                        .foregroundStyle(row.include ? Organic.s600 : Organic.n400)
                    Text(row.item.name).font(Organic.row)
                    if row.isDuplicate {
                        Badge(row.duplicate.tag, tone: row.duplicate == .sameNameOnly ? .neutral : .accent)
                    }
                    Spacer()
                    Text(store.format(row.item.buyPrice) + " → " + store.format(row.item.estimatedPrice))
                        .font(Organic.captionStrong)
                }
                Text(subtitle(row)).font(Organic.meta).foregroundStyle(Organic.n600)
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
        bits.append(row.item.isSold ? "sold" : (row.item.keep ? "keeping" : "for sale"))
        bits.append(row.item.boughtOn.formatted(date: .numeric, time: .omitted))
        return bits.joined(separator: " · ")
    }

    // MARK: - Options and commit

    private func optionsCard(_ preview: Store.ImportPreview) -> some View {
        Card {
            Text("Card debt").font(Organic.title)
            HelpText(addToCardDebt
                 ? "Each imported purchase raises its card's debt, as if you had bought it today."
                 : "Records only. Use this when the debt for these items is already on your cards.")
                .padding(.vertical, 6)
            HStack(spacing: 5) {
                Button { addToCardDebt = false } label: {
                    Chip(label: "Records only", selected: !addToCardDebt)
                }
                .buttonStyle(.plain)
                Button { addToCardDebt = true } label: {
                    Chip(label: "Add to card debt", selected: addToCardDebt, tint: Organic.a600)
                }
                .buttonStyle(.plain)
            }
            if addToCardDebt {
                HelpText("That would add \(store.format(debtDelta(preview))) across your cards.", tone: .warning)
                    .padding(.top, 6)
            }
        }
    }

    /// The one action on the screen, so it sits on the background rather than
    /// inside the card of the last option that happens to precede it.
    private func importButton(_ preview: Store.ImportPreview) -> some View {
        PrimaryButton(title: "Import \(preview.includedCount) item(s)") {
            guard let current = self.preview else { return }
            imported = store.commitImport(current, addToCardDebt: addToCardDebt, source: source,
                                          channelPlans: plans(current))
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

    private func channelsIntro(total: Int, creating: Int) -> String {
        if store.data.channels.isEmpty {
            return total == 1
                ? "Your book has no channels yet, so this one is created on import. Type its fee; a wallet for its money is made alongside."
                : "Your book has no channels yet, so all \(total) are created on import. Type each fee; a wallet for each is made alongside."
        }
        if creating == 0 {
            return "All \(total) were matched to channels you already have. Tap a match to change it."
        }
        let matched = total - creating
        return "\(matched) matched \(matched == 1 ? "a channel" : "channels") you already have; \(creating) \(creating == 1 ? "is" : "are") new and will be created. A new name that is really one of yours misspelt can be pointed at it."
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
                Text("\(use.rows) row\(use.rows == 1 ? "" : "s")")
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
                        newChannelDestination[use.written] = nil
                    }
                } else if let matched = target(use),
                          let channel = store.data.channels.first(where: { $0.name == matched }) {
                    Text("\(channel.rate.formatted())%")
                        .font(Organic.valueStrong).foregroundStyle(Organic.n700)
                }
            }
            outcomeLine(use, creating: creating, isPoints: isPoints)
            if creating { destinationLine(use, isPoints: isPoints) }
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

    /// Where a new channel pays. Plain text when there is nothing to choose
    /// from; a change link once the book has wallets of the right kind.
    private func destinationLine(_ use: Store.ChannelUse, isPoints: Bool) -> some View {
        let newWallet = SalesChannel.defaultDestinationName(for: use.written, isPoints: isPoints)
        let existing = isPoints ? store.data.pointWallets.map(\.name) : store.data.wallets.map(\.name)
        let chosen = newChannelDestination[use.written]
        return HStack(spacing: 6) {
            Image(systemName: "arrow.turn.down.right")
                .font(Organic.glyph).foregroundStyle(Organic.n400)
            HelpText(chosen.map { "\(isPoints ? "Points land" : "Money lands") in \($0)" }
                     ?? "\(isPoints ? "Points land" : "Money lands") in a new wallet, \"\(newWallet)\"")
                .lineLimit(1)
            if !existing.isEmpty {
                Menu {
                    Button {
                        newChannelDestination[use.written] = nil
                    } label: {
                        if chosen == nil { Label("New wallet: \(newWallet)", systemImage: "checkmark") }
                        else { Text("New wallet: \(newWallet)") }
                    }
                    Section("Or an existing one") {
                        ForEach(existing, id: \.self) { n in
                            Button {
                                newChannelDestination[use.written] = n
                            } label: {
                                if chosen == n { Label(n, systemImage: "checkmark") } else { Text(n) }
                            }
                        }
                    }
                } label: {
                    LinkLabel("Change")
                }
            }
            Spacer()
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
                                           isPoints: newChannelPoints.contains(use.written),
                                           destination: newChannelDestination[use.written])
            }
        }
        return out
    }

    /// Only unsold rows with a card this book knows can move a debt.
    private func debtDelta(_ preview: Store.ImportPreview) -> Int {
        preview.rows.filter { $0.include && !$0.item.isSold && !$0.item.cardName.isEmpty }
            .reduce(0) { $0 + $1.item.buyPrice }
    }

    private func doneCard(_ count: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Card(fill: Organic.s100) {
                Text("Imported \(count) item(s)").font(Organic.title)
                    .foregroundStyle(Organic.s900)
                Text("They are in Inventory now, and in the activity log. Any item's category can be changed from its own page.")
                    .font(Organic.caption).foregroundStyle(Organic.s900).padding(.top, 2)
                if let made = lastBatch?.createdChannels, !made.isEmpty {
                    Text("Created \(made.count) sales channel(s): \(createdChannelSummary(made)), each paying into its own wallet. Editable in Settings.")
                        .font(Organic.caption).foregroundStyle(Organic.s900).padding(.top, 6)
                }
                PrimaryButton(title: "Done") { dismiss() }.padding(.top, 10)
            }
            // The moment a wrong sheet is noticed is this one, so the way back
            // out sits here as well as in the history list.
            if let batch = lastBatch, !store.remainingItems(of: batch).isEmpty {
                Card {
                    Text("Wrong sheet?").font(Organic.title)
                    HelpText(undoCardBody(batch, count: count)).padding(.top, 4)
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
        Card {
            CardHeader(title: "Categories from the sheet",
                       subtitle: "These are labels on the items, not categories yet. Making them real gives them an attribute checklist; leaving them alone changes nothing.") {
                for name in store.looseCategoryNames {
                    store.addCategory(Category(name: name, attributes: []))
                }
            }
            .padding(.bottom, 8)
            ForEach(store.looseCategoryNames, id: \.self) { name in
                HStack {
                    Text(name).font(Organic.row)
                    Spacer()
                    HelpText("\(store.data.items.filter { $0.categoryName == name }.count) item(s)")
                    MiniButton(title: "Add", style: .accent) {
                        store.addCategory(Category(name: name, attributes: []))
                    }
                }
                .padding(.vertical, 7)
                .overlay(alignment: .top) { Hairline() }
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
                fileError = "That file is not text this app can read."
                return
            }
            text = string
            source = url.lastPathComponent
        } catch {
            fileError = "Could not open that file: \(error.localizedDescription)"
        }
    }
}
