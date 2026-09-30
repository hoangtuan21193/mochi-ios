import SwiftUI

// Organic design system — the shared components, one file per family:
// Containers, Buttons, Selection, Fields, DataDisplay, Layout. Every screen is
// built from these; a view file does not draw its own capsule, field, tag,
// divider or label-over-value pair. If a screen needs a variant, the variant is
// added here with a name, not inlined there. See design.md.

// MARK: - Containers

/// Cream card container. Every list block in the app sits in one of these.
struct Card<Content: View>: View {
    /// Standard for prose and forms; `.list` trims the vertical padding because
    /// rows carry their own.
    enum Padding { case standard, list, none }

    var fill: Color = Organic.n100
    var padding: Padding = .standard
    @ViewBuilder var content: Content

    private var insets: EdgeInsets {
        switch padding {
        case .standard: return EdgeInsets(top: Organic.Space.card, leading: 15, bottom: Organic.Space.card, trailing: 15)
        case .list: return EdgeInsets(top: Organic.Space.s, leading: 15, bottom: 9, trailing: 15)
        case .none: return EdgeInsets()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(insets)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: Organic.rCard, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
    }
}

/// A block inside a card: a form group, a nested list, a callout.
struct InnerBlock<Content: View>: View {
    var fill: Color = Organic.bg
    var padding: CGFloat = Organic.Space.row
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: Organic.Space.m) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: Organic.rInner, style: .continuous))
    }
}

/// Wraps a form in the app's cream sheet chrome: Close on the left, a Done
/// above the keyboard so number pads cannot trap it open.
struct SheetScaffold<Content: View>: View {
    private let title: Text
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss
    /// A focused `MoneyField` brings its own keyboard row, ending in `=`, which
    /// does what Done does. Two dismiss buttons on one row would be a puzzle.
    @State private var moneyFieldFocused = false

    /// A sheet the app named: "New wallet", "Card details".
    init(title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = Text(title); self.content = content()
    }
    /// A sheet named after the thing it edits — a wallet, a person, a month.
    /// That name is the user's or the calendar's, so it is shown as written.
    init(verbatimTitle: String, @ViewBuilder content: () -> Content) {
        self.title = Text(verbatim: verbatimTitle); self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Organic.Space.row) { content }
                    .padding(Organic.Space.gutter)
            }
            .background(Organic.bg)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .onPreferenceChange(MoneyFieldFocusKey.self) { moneyFieldFocused = $0 }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                if !moneyFieldFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { KeyboardDismiss.now() }
                    }
                }
            }
        }
    }
}

/// Bubbles "a MoneyField has the keyboard" up to whatever draws the Done
/// button, so the two keyboard rows never appear together.
struct MoneyFieldFocusKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

enum KeyboardDismiss {
    static func now() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}

// MARK: - Headers

/// Section header outside a card, with the round + that opens an inline form.
struct SectionHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var isOpen: Bool = false
    var onAdd: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(Organic.title)
                Spacer()
                if let onAdd { AddButton(isOpen: isOpen, action: onAdd) }
            }
            if let subtitle {
                Text(subtitle).font(Organic.meta).foregroundStyle(Organic.n600)
            }
        }
        .padding(.horizontal, 2)
    }
}

/// Title and help line at the top of a *form* card (Backup, General, Selling).
/// It never carries a +: anything you can add to is a list section, and a
/// list section's header is a `SectionHeader` outside the card, so every list
/// in the app has its title and its + in the same place.
struct CardHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Organic.title)
            if let subtitle {
                Text(subtitle).font(Organic.caption).foregroundStyle(Organic.n600)
            }
        }
    }
}
