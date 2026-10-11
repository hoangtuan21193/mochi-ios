import SwiftUI
import UniformTypeIdentifiers

/// Settings, the gear on Home. The screens that are not a tab are listed
/// first; below them only true configuration lives here, in the order it matters:
/// whether the book is safe (backup), what it is kept in (language, currency),
/// the rules every profit figure is computed by (channels, postage), then the
/// rarely-touched (owners) and the destructive (data). Categories are in
/// Inventory; wallets and cards are in Wallet — each managed where its effect
/// is visible.
struct SettingsView: View {
    @Environment(Store.self) private var store
    @State private var chName = ""
    @State private var chRate = ""
    @State private var chIsPoints = false
    /// Where a new channel's money lands. `nil` = make a wallet for it, the
    /// common case: a marketplace holds its own balance until withdrawn.
    @State private var shareURL: URL? = nil
    @State private var importing = false
    @State private var pendingRestore: Store.BackupFile? = nil
    @State private var backupNote: (text: String, ok: Bool)? = nil
    @State private var confirmingReset = false
    @State private var addOwner = false
    @State private var addChannel = false
    @State private var oName = ""
    /// One sheet slot. Two `.sheet` modifiers on the same view do not coexist —
    /// the later one wins and the other silently never presents.
    @State private var sheet: SettingsSheet?

    enum SettingsSheet: Identifiable {
        case channel(SalesChannel), owner(Owner), importHistory
        var id: String {
            switch self {
            case .channel(let c): return "c\(c.id)"
            case .owner(let o): return "o\(o.id)"
            case .importHistory: return "importHistory"
            }
        }
    }

    var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let problem = store.saveError { saveErrorCard(problem) }
                    SettingsHub()
                    backupCard
                    generalCard
                    spendingCard
                    channelsCard
                    sellingCard
                    ownersCard
                    dataCard
                }
                .padding(16)
                .readableWidth()
            }
            .background(Organic.bg)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $sheet) { which in
                switch which {
                case .channel(let c): ChannelEditorView(channel: c)
                case .owner(let o): OwnerEditorView(owner: o)
                case .importHistory: ImportHistoryView()
                }
            }
            .sheet(item: $shareURL) { url in ShareSheet(items: [url]) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                guard case .success(let url) = result else { return }
                let ok = store.replaceBook(with: url)
                backupNote = ok ? (String(localized: "Book replaced with \(url.lastPathComponent)."), true)
                                : (String(localized: "That file is not a Mochi book."), false)
            }
            .alert("Go back to \(pendingRestore?.label ?? "")?",
                   isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } })) {
                Button("Restore", role: .destructive) {
                    if let file = pendingRestore {
                        let ok = store.replaceBook(with: file.url)
                        backupNote = ok ? (String(localized: "Restored the copy from \(file.label)."), true)
                                        : (String(localized: "That copy could not be read."), false)
                    }
                    pendingRestore = nil
                }
                Button("Cancel", role: .cancel) { pendingRestore = nil }
            } message: {
                Text("The book as it is now is kept as a timed copy first, so this can be undone the same way.")
            }
            .alert("Erase everything?", isPresented: $confirmingReset) {
                Button("Erase", role: .destructive) { store.resetEverything() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Every wallet, card, item, loan and sales channel goes, and the settings on this screen go back to their defaults. Today's copy under Backups keeps the book as it was.")
            }
    }

    /// A failed write is the one thing in this app worth interrupting for: the
    /// numbers on screen would no longer be the numbers on disk.
    private func saveErrorCard(_ problem: String) -> some View {
        Card(fill: Organic.a100) {
            Text("Not saving").font(Organic.title).foregroundStyle(Organic.a900)
            Text(verbatim: problem).font(Organic.caption).foregroundStyle(Organic.a900).padding(.top, 2)
        }
    }

    /// Language and currency: set on the first day and rarely again, but they
    /// shape every screen, so they sit right under the backup.
    private var generalCard: some View {
        Card {
            Text("General").font(Organic.title).padding(.bottom, 6)
            DropdownRow(label: "Language", value: Text(String(localized: store.language.name))) {
                ForEach(AppLanguage.allCases) { l in
                    Button {
                        store.setLanguage(l)
                    } label: {
                        let name = String(localized: l.name)
                        if l == store.language { Label(name, systemImage: "checkmark") } else { Text(name) }
                    }
                }
            }
            if store.languageNeedsRestart {
                HelpText("Takes effect the next time the app is opened.", tone: .warning)
                    .padding(.bottom, 6)
            }
            DropdownRow(label: "Currency", value: Text(verbatim: "\(store.currency.code) · \(store.currency.symbol)")) {
                ForEach(Currency.allCases) { c in
                    // Title and subtitle, not one long line: a menu is narrow and
                    // "VND · ₫ · Vietnamese đồng" wrapped mid-word.
                    Button {
                        store.setCurrency(c)
                    } label: {
                        Text("\(c.code) · \(c.symbol)")
                        Text(String(localized: c.name))
                        if c == store.currency { Image(systemName: "checkmark") }
                    }
                }
            }
            HelpText("Every figure in the book is shown in \(String(localized: store.currency.name)). Personal loans keep their own currency.")
        }
    }

    /// Who a card or wallet belongs to. Set once, read never — which is why it
    /// stopped earning a section on the Wallet screen.
    private var ownersCard: some View {
        Group {
            SectionHeader(title: "Owners", subtitle: "Who a card or wallet belongs to",
                          isOpen: addOwner) { addOwner.toggle() }
            if addOwner {
                Card {
                    HStack(spacing: 8) {
                        FormField("Name", text: $oName)
                        AddPill {
                            guard !oName.isEmpty else { return }
                            store.data.owners.append(Owner(name: oName))
                            store.save(); oName = ""; addOwner = false
                        }
                    }
                }
            }
            Card(padding: .list) {
            ForEach(store.data.owners) { o in
                RowButton(first: o.id == store.data.owners.first?.id, action: { sheet = .owner(o) }) {
                    HStack {
                        Text(o.name).font(Organic.row)
                        Spacer()
                        Text(ownerMeta(o)).font(Organic.meta).foregroundStyle(Organic.n600)
                    }
                }
            }
            }
        }
    }

    private func ownerMeta(_ o: Owner) -> LocalizedStringKey {
        let cards = store.data.cards.filter { $0.ownerID == o.id }.count
        let wallets = store.data.wallets.filter { $0.ownerID == o.id }.count
        // One key, both counts. English needs the two plurals; the catalogue
        // carries them, and a language without plurals writes one form.
        return "\(cards) cards · \(wallets) wallets"
    }

    /// Demo data and the way back out of it.
    private var dataCard: some View {
        Card {
            CardHeader(title: "Data",
                       subtitle: store.isEmptyBook
                           ? "Nothing entered yet. Load a sample book to see how the screens read with real numbers in them."
                           : "\(store.data.items.count) items · \(store.data.wallets.count) wallets · \(store.data.cards.count) cards")
                .padding(.bottom, 8)
            if store.isEmptyBook {
                PrimaryButton(title: "Load sample data") { store.loadDemoData() }
            } else {
                DeleteButton(title: "Erase everything") { confirmingReset = true }
            }
            // Between "one item" and "the whole book" sits the import: dozens of
            // rows written at once, and the only thing worth undoing in bulk.
            if !store.importHistory.isEmpty {
                Button { sheet = .importHistory } label: {
                    HStack {
                        Text("Import history").font(Organic.rowValue)
                        Spacer()
                        Text("\(store.importHistory.count)")
                            .font(Organic.caption).foregroundStyle(Organic.n600)
                        Image(systemName: "chevron.right")
                            .font(Organic.captionStrong).foregroundStyle(Organic.n500)
                    }
                    .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Two kinds of safety, neither of them a cloud the app cannot see: a copy
    /// the app keeps by itself each day the book changes, and a file the user
    /// keeps wherever they like. The old iCloud toggle had no container behind
    /// it and never wrote a byte.
    private var backupCard: some View {
        Card {
            CardHeader(title: "Backups",
                       subtitle: "A copy of the book is kept on this phone each day it changes, for 30 days. Export a file now and then to keep one somewhere of your own.")
                .padding(.bottom, 8)
            HStack(spacing: 7) {
                PrimaryButton(title: "Export book file", icon: "square.and.arrow.up") { shareURL = store.exportBookFile() }
                SecondaryButton(title: "Import", icon: "square.and.arrow.down", style: .quiet) { importing = true }
            }
            let copies = store.backups
            if copies.isEmpty {
                HelpText("No daily copy yet — the first one is taken the next time the book changes.")
                    .padding(.top, 8)
            } else {
                DropdownRow(label: "Earlier copies · \(copies.count)", value: Text("Restore…")) {
                    ForEach(copies) { file in
                        Button {
                            pendingRestore = file
                        } label: {
                            Text(file.label)
                            Text(ByteCountFormatter.string(fromByteCount: Int64(file.bytes), countStyle: .file))
                        }
                    }
                }
                .padding(.top, 6)
            }
            if let note = backupNote {
                HelpText(verbatim: note.text, tone: note.ok ? .positive : .warning).padding(.top, 6)
            }
        }
    }

    /// What postage usually costs. Items can say otherwise one by one.
    private var sellingCard: some View {
        Card {
            CardHeader(title: "Selling",
                       subtitle: "Postage comes out of what a cash sale pays you. An item can override this on its own page.")
                .padding(.bottom, 8)
            HStack {
                Text("Default shipping").font(Organic.value)
                Spacer()
                MoneyField("0", value: Binding(
                    get: { store.data.defaultShippingFee },
                    set: { store.data.defaultShippingFee = $0; store.save() }),
                    alignment: .trailing)
                .frame(width: 120)
            }
            HStack(spacing: 5) {
                ForEach([0, 210, 850, 1000], id: \.self) { amount in
                    Button {
                        store.data.defaultShippingFee = amount
                        store.save()
                    } label: {
                        Chip(label: amount == 0 ? Text("Free") : Text(verbatim: store.format(amount)),
                             selected: store.data.defaultShippingFee == amount)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
        }
    }

    /// The one knob on Safe to spend: cash kept back on purpose, so the number
    /// on the Overview is what can go without touching the floor.
    private var spendingCard: some View {
        Card {
            CardHeader(title: "Safe to spend",
                       subtitle: "Cash the Overview keeps back before it says what you can spend. A month of rent is a common choice; 0 means every yen counts.")
                .padding(.bottom, 8)
            HStack {
                Text("Safety reserve").font(Organic.value)
                Spacer()
                MoneyField("0", value: Binding(
                    get: { store.data.safetyBuffer },
                    set: { store.setSafetyBuffer($0) }),
                    alignment: .trailing)
                .frame(width: 140)
            }
            HelpText("The forecast warns when cash is about to fall under this line.")
                .padding(.top, 6)
        }
    }

    /// A channel is one way to sell: cash (% fee) or points (% bonus).
    private var channelsCard: some View {
        Group {
            SectionHeader(title: "Sales channels",
                          subtitle: "Cash channels take a fee; point channels pay a bonus in points.",
                          isOpen: addChannel) { addChannel.toggle() }
            if addChannel { Card { addChannelForm } }
            Card(padding: .list) {
            if store.data.channels.isEmpty && !addChannel {
                // A fresh book has none. Say what one is and what it does
                // before asking for it — the + alone reads as "add a thing".
                Text("""
                     A channel is a place you sell: Mercari, Rakuma, PayPay Flea, a second-hand shop's trade-in counter.

                     Each one knows its fee — Mercari keeps 10%, so a ¥10,000 sale pays you ¥9,000 — which is what the sell planner and the sell-all figure work from. Point channels (MapCamera trade-in points) pay a bonus in points instead of cash. Selling never moves a wallet balance: you type those in from the bank.

                     Add one with the + above. Items pick their planned channel from this list.
                     """)
                    .font(Organic.value).foregroundStyle(Organic.n700)
                    .padding(.vertical, 6)
            }
            ForEach(store.data.channels) { ch in
                RowButton(first: ch.id == store.data.channels.first?.id, action: { sheet = .channel(ch) }) {
                    HStack {
                        Text(ch.name).font(Organic.row)
                        if ch.isPoints { Badge("POINT", tone: .accent) } else { Badge("CASH", tone: .sage) }
                        Spacer()
                        Text("\(ch.rate.formatted())%").font(Organic.valueStrong)
                    }
                }
            }
            }
        }
    }

    /// Name, fee, cash/point. Nothing about where money goes: a sale is a
    /// record, and the bank balance is typed in by hand.
    private var addChannelForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                FormField("Channel (Mercari, Rakuma…)", text: $chName)
                FormField("%", text: $chRate, decimal: true).frame(width: 64)
                ToggleChip(label: chIsPoints ? "Point" : "Cash",
                           tint: chIsPoints ? Organic.a600 : Organic.s600) { chIsPoints.toggle() }
            }
            HStack {
                HelpText(chIsPoints
                         ? "Pays \(chRate.isEmpty ? "0" : chRate)% on top of the price, in points."
                         : "Keeps \(chRate.isEmpty ? "0" : chRate)% of the sale price as its fee.")
                Spacer()
                AddPill {
                    guard !chName.isEmpty else { return }
                    store.addChannel(SalesChannel(name: chName,
                                                  rate: Double(chRate.replacingOccurrences(of: ",", with: ".")) ?? 0,
                                                  isPoints: chIsPoints))
                    chName = ""; chRate = ""; chIsPoints = false; addChannel = false
                }
            }
        }
        .padding(.bottom, 6)
    }
}
