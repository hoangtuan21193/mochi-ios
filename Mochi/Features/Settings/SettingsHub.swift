import SwiftUI

/// The top of Settings: every screen that is not a tab, grouped by what it
/// is for. Configuration follows underneath.
struct SettingsHub: View {
    @Environment(Store.self) private var store
    /// On a wide screen Settings is a menu beside the page it opened, as in
    /// the iPad's own Settings (decision #41): a row picks the page instead
    /// of pushing it, and the configuration below is listed too.
    var selection: Binding<SettingsPage>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Organic.Space.l) {
            // Accounts, cards, plans, people and investments are the Wallet
            // tab; warranties sit with Belongings. Settings is configuration.
            ListHeading(title: "Automatic")
            Card(padding: .list) {
                link(.rules, String(localized: "\(store.rules.count) rules"), "wand.and.stars", 4) { RulesView() }
                link(.categories, String(localized: "\(store.spendingCategories.count) spending categories"), "square.grid.2x2", 1) { SpendingCategoriesView() }
                link(.notifications, String(localized: "Payments, shortfalls, renewals"), "bell", 1) { NotificationsView() }
            }
            ListHeading(title: "You and your data")
            Card(padding: .list) {
                link(.household, store.household.partnerName.isEmpty ? String(localized: "Share the book with your partner") : metaLine(store.household.partnerName, store.household.partnerState.isEmpty ? String(localized: "not invited yet") : store.household.partnerState),
                     "house.and.flag", 3) { HouseholdView() }
                link(.yourData, String(localized: "Export everything, earlier copies"), "lock.shield", 2) { YourDataView() }
                link(.assistant, ReceiptReader.modelAvailable ? String(localized: "On this iPhone · Apple Intelligence") : String(localized: "Questions about your money"),
                     "bubble.left.and.text.bubble.right", 0) { AssistantView() }
            }
            if selection != nil {
                ListHeading(title: "This book")
                Card(padding: .list) {
                    link(.backups, String(localized: "A copy a day, the last 30 kept"), "clock.arrow.circlepath", 2) { EmptyView() }
                    link(.general, String(localized: "Language and currency"), "globe", 5) { EmptyView() }
                    link(.homeCounts, String(localized: "What “You have” adds up"), "house", 0) { EmptyView() }
                    link(.selling, String(localized: "Sales channels, fees and postage"), "tag", 3) { EmptyView() }
                    link(.owners, String(localized: "Who a card or wallet belongs to"), "person.2", 4) { EmptyView() }
                    link(.data, String(localized: "Import, restore or erase"), "externaldrive", 1) { EmptyView() }
                }
            }
        }
    }

    @ViewBuilder
    private func link<D: View>(_ page: SettingsPage, _ sub: String, _ symbol: String, _ color: Int,
                               @ViewBuilder destination: @escaping () -> D) -> some View {
        let label = HStack(spacing: Organic.Space.l) {
            LeadMark(glyph: .symbol(symbol), tint: Organic.chartColor(color).opacity(0.14), ink: Organic.chartColor(color), size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(page.title).font(Organic.row)
                Text(verbatim: sub).font(Organic.caption).foregroundStyle(Organic.n600).lineLimit(1)
            }
            Spacer()
            if selection == nil {
                Image(systemName: "chevron.right").font(Organic.glyph).foregroundStyle(Organic.n500)
            }
        }
        .padding(.vertical, Organic.Space.row)
        .contentShape(Rectangle())
        Group {
            if let selection {
                Button { selection.wrappedValue = page } label: { label }
                    .openInDetail(selection.wrappedValue == page)
            } else {
                NavigationLink(destination: destination) { label }
            }
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { Hairline() }
    }
}

/// A page of Settings on a wide screen: the screens the hub opens, then the
/// configuration a phone lists as cards under them.
enum SettingsPage: Hashable {
    case rules, categories, notifications, household, yourData, assistant
    case backups, general, homeCounts, selling, owners, data

    var title: LocalizedStringKey {
        switch self {
        case .rules: "Rules"
        case .categories: "Categories"
        case .notifications: "Notifications"
        case .household: "Household"
        case .yourData: "Your data"
        case .assistant: "Ask Mochi"
        case .backups: "Backups"
        case .general: "General"
        case .homeCounts: "What Home counts"
        case .selling: "Selling"
        case .owners: "Owners"
        case .data: "Data"
        }
    }
}

/// Spending categories: the names Spending groups by. A category in use can
/// be removed; its transactions then wait for a new one.
struct SpendingCategoriesView: View {
    @Environment(Store.self) private var store
    @State private var name = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Organic.Space.l) {
                Card {
                    HStack { FormField("New category", text: $name); AddPill { let n = name.trimmingCharacters(in: .whitespaces); if !n.isEmpty { store.addSpendingCategory(SpendingCategory(name: n, colorIndex: store.spendingCategories.count % 7)) }; name = "" } }
                }
                Card(padding: .list) {
                    ForEach(Array(store.spendingCategories.enumerated()), id: \.element.id) { i, c in
                        HStack {
                            ListRow(title: c.name, mark: LeadMark(glyph: .symbol(c.symbol), tint: Organic.chartColor(c.colorIndex).opacity(0.16), ink: Organic.chartColor(c.colorIndex)))
                            RemoveButton { store.deleteSpendingCategory(c) }
                        }
                        .overlay(alignment: .top) { if i > 0 { Hairline() } }
                    }
                }
            }
            .padding(Organic.Space.gutter)
            .readableWidth()
        }
        .background(Organic.bg)
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
    }
}
