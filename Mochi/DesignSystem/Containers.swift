import SwiftUI

// Organic design system — the shared components, one file per family:
// Containers, Buttons, Selection, Fields, DataDisplay, Layout. Every screen is
// built from these; a view file does not draw its own capsule, field, tag,
// divider or label-over-value pair. If a screen needs a variant, the variant is
// added here with a name, not inlined there. See design.md.

// MARK: - Containers

/// White card with a thin border (raised grey in dark). Every list block in the app sits in one of these.
struct Card<Content: View>: View {
    /// Standard for prose and forms; `.list` trims the vertical padding because
    /// rows carry their own.
    enum Padding { case standard, list, none }

    var fill: Color = Organic.n100
    var padding: Padding = .standard
    @ViewBuilder var content: Content

    private var insets: EdgeInsets {
        switch padding {
        case .standard: return EdgeInsets(top: Organic.Space.card, leading: Organic.Space.card, bottom: Organic.Space.card, trailing: Organic.Space.card)
        case .list: return EdgeInsets(top: 0, leading: Organic.Space.card, bottom: 0, trailing: Organic.Space.card)
        case .none: return EdgeInsets()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(insets)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: Organic.rCard, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Organic.rCard, style: .continuous)
                .stroke(fill == Organic.n100 ? Organic.n300 : .clear, lineWidth: Organic.stroke))
    }
}

/// A block inside a card: a form group, a nested list, a callout.
struct InnerBlock<Content: View>: View {
    var fill: Color = Organic.surface
    var padding: CGFloat = Organic.Space.l
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: Organic.Space.m) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: Organic.rInner, style: .continuous))
    }
}

/// Wraps a form in the app's sheet chrome: Close on the left, a Done
/// above the keyboard so number pads cannot trap it open. `leading` puts a
/// different way out in Close's place where closing is not what the user
/// wants next; `trailing` adds a second way on the right ("Retake" beside
/// Cancel on a scanned receipt).
struct SheetScaffold<Content: View>: View {
    private let title: Text
    private var leading: (title: LocalizedStringKey, action: () -> Void)?
    private var trailing: (title: LocalizedStringKey, action: () -> Void)?
    /// How wide the form may grow on an iPad. A form with a picture beside
    /// its fields (Check and save) asks for more than one column's width.
    private var maxWidth: CGFloat = 680
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss
    @Environment(\.closePane) private var closePane
    /// A focused `MoneyField` brings its own keyboard row, ending in `=`, which
    /// does what Done does. Two dismiss buttons on one row would be a puzzle.
    @State private var moneyFieldFocused = false

    /// A sheet the app named: "New wallet", "Card details".
    init(title: LocalizedStringKey, leading: (LocalizedStringKey, () -> Void)? = nil,
         trailing: (LocalizedStringKey, () -> Void)? = nil, maxWidth: CGFloat = 680, @ViewBuilder content: () -> Content) {
        self.title = Text(title)
        self.maxWidth = maxWidth
        self.leading = leading.map { (title: $0.0, action: $0.1) }
        self.trailing = trailing.map { (title: $0.0, action: $0.1) }
        self.content = content()
    }
    /// A sheet named after the thing it edits — a wallet, a person, a month.
    /// That name is the user's or the calendar's, so it is shown as written.
    init(verbatimTitle: String, @ViewBuilder content: () -> Content) {
        self.title = Text(verbatim: verbatimTitle); self.content = content()
    }

    var body: some View {
        if let closePane { pane(close: closePane) } else { sheet }
    }

    /// The same form in a wide screen's right column (`ListDetail`): no
    /// navigation bar of its own, so its title and Close sit on the first row.
    private func pane(close: @escaping () -> Void) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Organic.Space.row) {
                ZStack {
                    title.font(Organic.title).lineLimit(1)
                    HStack {
                        if let leading { Button(leading.title, action: leading.action) } else { Button("Close", action: close) }
                        Spacer()
                        if let trailing { Button(trailing.title, action: trailing.action) }
                    }
                    .font(Organic.body).foregroundStyle(Organic.accent)
                }
                .padding(.bottom, Organic.Space.s)
                content
            }
            .padding(Organic.Space.gutter)
            .readableWidth(maxWidth)
        }
        .background(Organic.bg)
        .scrollDismissesKeyboard(.interactively)
    }

    private var sheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Organic.Space.row) { content }
                    .padding(Organic.Space.gutter)
                .readableWidth(maxWidth)
            }
            .background(Organic.bg)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .onPreferenceChange(MoneyFieldFocusKey.self) { moneyFieldFocused = $0 }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let leading { Button(leading.title, action: leading.action) } else { Button("Close") { dismiss() } }
                }
                if let trailing {
                    ToolbarItem(placement: .topBarTrailing) { Button(trailing.title, action: trailing.action) }
                }
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
    #if SHARE_EXTENSION
    /// An extension has no `UIApplication.shared`; the share sheet's controller
    /// sets this to end editing on its own view.
    @MainActor static var endEditing: () -> Void = {}
    @MainActor static func now() { endEditing() }
    #else
    static func now() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
    #endif
}

// MARK: - Headers

/// Section header outside a card, with the round + that opens an inline form.
struct SectionHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    /// A subtitle already formatted (dates, figures), shown as written.
    var detail: String? = nil
    var isOpen: Bool = false
    var onAdd: (() -> Void)? = nil
    var body: some View {
        // The + stands beside both lines, so the subtitle sits right under
        // its title instead of under the button's height.
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Organic.title)
                if let subtitle {
                    Text(subtitle).font(Organic.caption).foregroundStyle(Organic.n600)
                } else if let detail {
                    Text(verbatim: detail).font(Organic.caption).foregroundStyle(Organic.n600)
                }
            }
            Spacer()
            if let onAdd { AddButton(isOpen: isOpen, action: onAdd) }
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
