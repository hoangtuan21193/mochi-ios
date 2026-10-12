import SwiftUI

/// The top of Settings: every screen that is not a tab, grouped by what it
/// is for. Configuration follows underneath.
struct SettingsHub: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: Organic.Space.l) {
            // Accounts, cards, plans, people and investments are the Wallet
            // tab; warranties sit with Belongings. Settings is configuration.
            ListHeading(title: "Automatic")
            Card(padding: .list) {
                link("Rules", String(localized: "\(store.rules.count) rules"), "wand.and.stars", 4) { RulesView() }
                link("Categories", String(localized: "\(store.spendingCategories.count) spending categories"), "square.grid.2x2", 1) { SpendingCategoriesView() }
                link("Notifications", String(localized: "Payments, shortfalls, renewals"), "bell", 1) { NotificationsView() }
            }
            ListHeading(title: "You and your data")
            Card(padding: .list) {
                link("Household", store.household.partnerName.isEmpty ? String(localized: "Share the book with your partner") : metaLine(store.household.partnerName, store.household.partnerState.isEmpty ? String(localized: "not invited yet") : store.household.partnerState),
                     "house.and.flag", 3) { HouseholdView() }
                link("Your data", String(localized: "Export everything, earlier copies"), "lock.shield", 2) { YourDataView() }
                link("Ask Mochi", ReceiptReader.modelAvailable ? String(localized: "On this iPhone · Apple Intelligence") : String(localized: "Questions about your money"),
                     "bubble.left.and.text.bubble.right", 0) { AssistantView() }
            }
        }
    }

    private func link<D: View>(_ title: LocalizedStringKey, _ sub: String, _ symbol: String, _ color: Int,
                               @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: Organic.Space.l) {
                LeadMark(glyph: .symbol(symbol), tint: Organic.chartColor(color).opacity(0.14), ink: Organic.chartColor(color), size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Organic.row)
                    Text(verbatim: sub).font(Organic.caption).foregroundStyle(Organic.n600).lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").font(Organic.glyph).foregroundStyle(Organic.n500)
            }
            .padding(.vertical, Organic.Space.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) { Hairline() }
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
