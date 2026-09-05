import SwiftUI

/// Tab 5. Only true configuration lives here, in the order it matters:
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
    @State private var chDestination: String? = nil
    @State private var restoreFailed = false
    @State private var confirmingReset = false
    @State private var shippingDraft = ""
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let problem = store.saveError { saveErrorCard(problem) }
                    backupCard
                    generalCard
                    channelsCard
                    sellingCard
                    ownersCard
                    dataCard
                }
                .padding(16)
            }
            .background(Organic.bg)
            .navigationTitle("Settings")
            .sheet(item: $sheet) { which in
                switch which {
                case .channel(let c): ChannelEditorView(channel: c)
                case .owner(let o): OwnerEditorView(owner: o)
                case .importHistory: ImportHistoryView()
                }
            }
            .alert("Erase everything?", isPresented: $confirmingReset) {
                Button("Erase", role: .destructive) { store.resetEverything() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Every wallet, card, item, loan and sales channel goes, and the settings on this screen go back to their defaults. An iCloud backup, if you have one, is left alone.")
            }
        }
    }

    /// A failed write is the one thing in this app worth interrupting for: the
    /// numbers on screen would no longer be the numbers on disk.
    private func saveErrorCard(_ problem: String) -> some View {
        Card(fill: Organic.a100) {
            Text("Not saving").font(Organic.title).foregroundStyle(Organic.a900)
            Text(problem).font(Organic.caption).foregroundStyle(Organic.a900).padding(.top, 2)
        }
    }

    /// Language and currency: set on the first day and rarely again, but they
    /// shape every screen, so they sit right under the backup.
    private var generalCard: some View {
        Card {
            Text("General").font(Organic.title).padding(.bottom, 6)
            DropdownRow(label: "Language", value: store.language.name) {
                ForEach(AppLanguage.allCases) { l in
                    Button {
                        store.setLanguage(l)
                    } label: {
                        if l == store.language { Label(l.name, systemImage: "checkmark") } else { Text(l.name) }
                    }
                }
            }
            if store.languageNeedsRestart {
                HelpText("Takes effect the next time the app is opened.", tone: .warning)
                    .padding(.bottom, 6)
            }
            DropdownRow(label: "Currency", value: "\(store.currency.code) · \(store.currency.symbol)") {
                ForEach(Currency.allCases) { c in
                    // Title and subtitle, not one long line: a menu is narrow and
                    // "VND · ₫ · Vietnamese đồng" wrapped mid-word.
                    Button {
                        store.setCurrency(c)
                    } label: {
                        Text("\(c.code) · \(c.symbol)")
                        Text(c.name)
                        if c == store.currency { Image(systemName: "checkmark") }
                    }
                }
            }
            HelpText("Every figure in the book is shown in \(store.currency.name). Personal loans keep their own currency.")
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

    private func ownerMeta(_ o: Owner) -> String {
        let cards = store.data.cards.filter { $0.ownerID == o.id }.count
        let wallets = store.data.wallets.filter { $0.ownerID == o.id }.count
        return "\(cards) \(cards == 1 ? "card" : "cards") · \(wallets) \(wallets == 1 ? "wallet" : "wallets")"
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

    private var backupCard: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud backup").font(Organic.title)
                    HelpText(backupLine)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { store.data.autoBackup },
                                         set: { store.data.autoBackup = $0; store.save() }))
                    .labelsHidden().tint(Organic.accent2)
            }
            HStack(spacing: 7) {
                PrimaryButton(title: "Back up now") { store.backupNow() }
                SecondaryButton(title: "Restore", style: .quiet) {
                    restoreFailed = !store.restoreFromCloud()
                }
            }
            .padding(.top, 11)
            if restoreFailed {
                HelpText("No iCloud backup found. Check you are signed into iCloud Drive.", tone: .warning)
                    .padding(.top, 6)
            }
        }
    }

    private var backupLine: String {
        let state = store.data.autoBackup ? "Auto backup on" : "Auto backup off"
        guard let last = store.data.lastBackup else { return state + " · never" }
        return state + " · last " + last.formatted(date: .numeric, time: .shortened)
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
                FormField {
                    TextField("0", text: Binding(
                        get: { shippingDraft.isEmpty ? String(store.data.defaultShippingFee) : shippingDraft },
                        set: { new in
                            shippingDraft = new.filter(\.isNumber)
                            store.data.defaultShippingFee = Int(shippingDraft) ?? 0
                            store.save()
                        }))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                .frame(width: 90)
            }
            HStack(spacing: 5) {
                ForEach([0, 210, 850, 1000], id: \.self) { amount in
                    Button {
                        shippingDraft = String(amount)
                        store.data.defaultShippingFee = amount
                        store.save()
                    } label: {
                        Chip(label: amount == 0 ? "Free" : store.format(amount),
                             selected: store.data.defaultShippingFee == amount)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 8)
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
                     A channel is a place you sell: Mercari, Rakuma, PayPay Flea, a camera shop's trade-in counter.

                     Each one knows its fee — Mercari keeps 10%, so a ¥10,000 sale pays you ¥9,000 — and the wallet the money lands in, so a sale moves the right balance on its own. Point channels (MapCamera trade-in points) pay a bonus into a point wallet instead of cash.

                     Add one with the + above. Items pick their planned channel from this list.
                     """)
                    .font(Organic.value).foregroundStyle(Organic.n700)
                    .padding(.vertical, 6)
            }
            ForEach(store.data.channels) { ch in
                RowButton(first: ch.id == store.data.channels.first?.id, action: { sheet = .channel(ch) }) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(ch.name).font(Organic.row)
                            if ch.isPoints { Badge("POINT", tone: .accent) } else { Badge("CASH", tone: .sage) }
                            Spacer()
                            Text("\(ch.rate.formatted())%").font(Organic.valueStrong)
                        }
                        // Where the money goes is the one thing about a channel that
                        // silently corrupts a balance when wrong, so it is on the row.
                        Text(ch.destination.isEmpty
                             ? (ch.isPoints ? "No point wallet — points land nowhere" : "No wallet — pays into the first one")
                             : "pays into \(ch.destination)")
                            .font(Organic.meta)
                            .foregroundStyle(ch.destination.isEmpty ? Organic.a800 : Organic.n600)
                    }
                }
            }
            }
        }
    }

    /// The wallet the new channel would create if asked to.
    private var chNewWalletName: String {
        SalesChannel.defaultDestinationName(for: chName.isEmpty ? "Channel" : chName, isPoints: chIsPoints)
    }
    private var chExistingDestinations: [String] {
        chIsPoints ? store.data.pointWallets.map(\.name) : store.data.wallets.map(\.name)
    }

    /// Name, fee, cash/point — and where the money goes, decided here rather
    /// than found missing later. Without a destination a sale falls into the
    /// first wallet, usually the bank, while the money is in fact still sitting
    /// on the marketplace.
    private var addChannelForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                FormField("Channel (Mercari, Rakuma…)", text: $chName)
                FormField("%", text: $chRate, decimal: true).frame(width: 64)
                ToggleChip(label: chIsPoints ? "Point" : "Cash",
                           tint: chIsPoints ? Organic.a600 : Organic.s600) {
                    chIsPoints.toggle(); chDestination = nil
                }
            }
            ChipPicker(label: chIsPoints ? "Points land in" : "Money lands in",
                       options: ["New: \(chNewWalletName)"] + chExistingDestinations,
                       selection: chDestination ?? "New: \(chNewWalletName)",
                       accentOptions: ["New: \(chNewWalletName)"]) { pick in
                chDestination = pick == "New: \(chNewWalletName)" ? nil : pick
            }
            HStack {
                HelpText(chDestination == nil
                         ? (chIsPoints ? "A point wallet is created for it, starting at 0."
                                       : "A wallet is created for it at ¥0, marked \"not withdrawn\".")
                         : "Sales pay straight into \(chDestination ?? "").")
                Spacer()
                AddPill {
                    guard !chName.isEmpty else { return }
                    var ch = SalesChannel(name: chName, rate: Double(chRate.replacingOccurrences(of: ",", with: ".")) ?? 0,
                                          isPoints: chIsPoints)
                    ch.destination = chDestination ?? store.makeDestination(for: ch)
                    store.addChannel(ch)
                    chName = ""; chRate = ""; chIsPoints = false; chDestination = nil; addChannel = false
                }
            }
        }
        .padding(.bottom, 6)
    }
}
