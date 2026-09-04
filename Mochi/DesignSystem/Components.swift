import SwiftUI

// Organic design system — the shared components. Every screen is built from
// these; a view file does not draw its own capsule, field, tag, divider or
// label-over-value pair. If a screen needs a variant, the variant is added
// here with a name, not inlined there. See design.md.

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
    let title: String
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { KeyboardDismiss.now() }
                }
            }
        }
    }
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
    let title: String
    var subtitle: String? = nil
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

/// A card's own header: title, optional help line, optional + on the right.
struct CardHeader: View {
    let title: String
    var subtitle: String? = nil
    var isOpen: Bool = false
    var onAdd: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(Organic.title)
                Spacer()
                if let onAdd { AddButton(isOpen: isOpen, fill: Organic.n200, action: onAdd) }
            }
            if let subtitle {
                Text(subtitle).font(Organic.caption).foregroundStyle(Organic.n600)
            }
        }
    }
}

// MARK: - Buttons

/// Full-width primary action. One per screen or sheet: Save, Import, Move it.
struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon { Image(systemName: icon).font(Organic.rowValue) }
                Text(title).font(Organic.rowValue)
            }
            .frame(maxWidth: .infinity).padding(.vertical, Organic.Space.card)
            .background(Organic.accent, in: Capsule())
            .foregroundStyle(.white)
        }
    }
}

/// Full-width secondary action: Restore, Edit details, Move money, Undo.
/// Quiet by default; `.warm` for an undo that reverses money; `.outlined`
/// when it sits on the page rather than in a card.
struct SecondaryButton: View {
    enum Style { case quiet, warm, outlined }
    let title: String
    var icon: String? = nil
    var style: Style = .quiet
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: Organic.Space.m) {
                if let icon { Image(systemName: icon) }
                Text(title).font(Organic.rowValue)
            }
            .frame(maxWidth: .infinity).padding(.vertical, Organic.Space.l)
            .background(fill, in: Capsule())
            .overlay(Capsule().stroke(style == .outlined ? Organic.n300 : .clear, lineWidth: Organic.stroke))
            .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
    }
    private var fill: Color {
        switch style {
        case .quiet: return Organic.n200
        case .warm: return Organic.a200
        case .outlined: return Organic.n100
        }
    }
    private var foreground: Color {
        switch style {
        case .quiet: return Organic.n800
        case .warm: return Organic.a900
        case .outlined: return Organic.text
        }
    }
}

/// Destructive full-width action, terracotta rather than accent.
struct DeleteButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(role: .destructive, action: action) {
            Text(title).font(Organic.rowValue)
                .frame(maxWidth: .infinity).padding(.vertical, Organic.Space.card)
                .background(Organic.a100, in: Capsule())
                .foregroundStyle(Organic.a800)
        }
    }
}

/// The one way to say "add" in this app: a round +, never a full-width button.
/// It turns into an × while its form is open.
struct AddButton: View {
    var isOpen: Bool = false
    var fill: Color = Organic.n100
    var stroke: Color = Organic.n300
    var symbol: Color = Organic.n700
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(Organic.rowValue)
                .frame(width: 28, height: 28)
                .background(fill, in: Circle())
                .overlay(Circle().stroke(stroke, lineWidth: Organic.stroke))
                .foregroundStyle(symbol)
                .rotationEffect(.degrees(isOpen ? 45 : 0))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: isOpen)
    }
}

/// The confirm inside an open inline form. Small and to the right.
struct AddPill: View {
    var title = "Add"
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(Organic.rowValue)
                .padding(.horizontal, Organic.Space.gutter).padding(.vertical, Organic.Space.row)
                .background(Organic.accent, in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

/// Small round × for removing a row inside a form.
struct RemoveButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(Organic.captionStrong)
                .frame(width: 28, height: 28)
                .background(Organic.n200, in: Circle()).foregroundStyle(Organic.n700)
        }
        .buttonStyle(.plain)
    }
}

/// Round toolbar button: tag, import, export; `filled` for the one primary (+).
struct IconButton: View {
    let symbol: String
    var filled: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(Organic.rowValue)
                .frame(width: 29, height: 29)
                .background(filled ? Organic.accent : Organic.n200, in: Circle())
                .foregroundStyle(filled ? .white : Organic.n800)
        }
    }
}

/// A small pill action inside a row: "Add", "+ Add row". `.accent` when it
/// creates something, `.quiet` when it only opens more form.
struct MiniButton: View {
    enum Style { case accent, quiet }
    let title: String
    var style: Style = .quiet
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(Organic.captionStrong)
                .padding(.horizontal, 11).padding(.vertical, 5)
                .background(style == .accent ? Organic.accent : Organic.n200, in: Capsule())
                .foregroundStyle(style == .accent ? .white : Organic.n800)
        }
        .buttonStyle(.plain)
    }
}

/// A small accent text link with a chevron — the label of a Menu that offers
/// a secondary correction ("Change", "Map to existing"). Not a pill: a pill
/// per row makes every row look like it demands a decision.
struct LinkLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(spacing: 2) {
            Text(text)
            Image(systemName: "chevron.down").font(Organic.glyph)
        }
        .font(Organic.captionStrong).foregroundStyle(Organic.accent)
    }
}

// MARK: - Selection

/// The pill chip used everywhere for single-select rows.
struct Chip: View {
    let label: String
    let selected: Bool
    var tint: Color = Organic.n900
    var body: some View {
        Text(label)
            .font(Organic.valueStrong)
            // A chip is one word or two; it wraps to the next row, never inside itself.
            .lineLimit(1).fixedSize()
            .padding(.horizontal, Organic.Space.l).padding(.vertical, Organic.Space.s)
            .background(selected ? tint : Organic.n200)
            .foregroundStyle(selected ? Organic.bg : Organic.n700)
            .clipShape(Capsule())
    }
}

/// A labelled single-select. Chips while the list is short enough to scan at
/// a glance; past `chipLimit` it becomes a dropdown, because eight wallets as
/// chips is three wrapped rows the eye has to search. Callers never decide
/// which — the count does, so every picker in the app switches at the same point.
struct ChipPicker: View {
    var label: String = ""
    let options: [String]
    let selection: String
    var tint: Color = Organic.n900
    /// Options drawn in accent as chips ("New: Mercari wallet", a point channel).
    var accentOptions: Set<String> = []
    var placeholder: String = "Choose"
    let onPick: (String) -> Void

    static let chipLimit = 4

    var body: some View {
        if options.count > Self.chipLimit { dropdown } else { chips }
    }

    private var chips: some View {
        VStack(alignment: .leading, spacing: 5) {
            if !label.isEmpty { FieldLabel(label) }
            FlowRow(spacing: 5) {
                ForEach(options, id: \.self) { opt in
                    Button { onPick(opt) } label: {
                        Chip(label: opt, selected: selection == opt,
                             tint: accentOptions.contains(opt) ? Organic.accent : tint)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dropdown: some View {
        HStack {
            if !label.isEmpty { FieldLabel(label) }
            Spacer()
            DropdownPill(value: options.contains(selection) ? selection : placeholder, compact: true) {
                ForEach(options, id: \.self) { opt in
                    Button { onPick(opt) } label: {
                        if opt == selection { Label(opt, systemImage: "checkmark") } else { Text(opt) }
                    }
                }
            }
        }
    }
}

/// A two-state chip that reads as a switch: "Cash / Point", "Records only /
/// Add to card debt". Always drawn selected, in the colour of its state.
struct ToggleChip: View {
    let label: String
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) { Chip(label: label, selected: true, tint: tint) }
            .buttonStyle(.plain)
    }
}

/// The chosen value as a pill that opens a menu. For lists too long for chips.
struct DropdownPill<Items: View>: View {
    let value: String
    var compact: Bool = false
    @ViewBuilder var items: () -> Items
    var body: some View {
        Menu {
            items()
        } label: {
            HStack(spacing: Organic.Space.s) {
                Text(value).font(Organic.rowValue).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(Organic.glyph).foregroundStyle(Organic.n500)
            }
            .padding(.horizontal, compact ? Organic.Space.row : Organic.Space.card)
            .padding(.vertical, compact ? 7 : Organic.Space.m)
            .background(Organic.bg, in: Capsule())
            .overlay(Capsule().stroke(Organic.n300, lineWidth: Organic.stroke))
            .foregroundStyle(Organic.text)
        }
    }
}

/// Label on the left, a DropdownPill on the right. The Settings row.
struct DropdownRow<Items: View>: View {
    let label: String
    let value: String
    @ViewBuilder var items: () -> Items
    var body: some View {
        HStack {
            Text(label).font(Organic.body)
            Spacer()
            DropdownPill(value: value, items: items)
        }
        .padding(.vertical, Organic.Space.s)
    }
}

/// Inline "Label  Value ⌄" menu for a secondary choice inside a form.
struct InlineMenu<Items: View>: View {
    let label: String
    let value: String
    @ViewBuilder var items: () -> Items
    var body: some View {
        Menu {
            items()
        } label: {
            HStack(spacing: Organic.Space.s) {
                Text(label).font(Organic.caption).foregroundStyle(Organic.n600)
                Text(value).font(Organic.valueStrong).foregroundStyle(Organic.text).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(Organic.glyph).foregroundStyle(Organic.n500)
                Spacer()
            }
        }
    }
}

// MARK: - Fields

/// The capsule text field used by every form in the app. Wrap any field, or
/// use the convenience init for a plain TextField with proper-noun-safe input.
struct FormField<V: View>: View {
    @ViewBuilder var field: V
    var body: some View {
        field.font(Organic.body)
            .padding(.horizontal, Organic.Space.card).padding(.vertical, Organic.Space.row)
            .background(Organic.bg, in: Capsule())
            .overlay(Capsule().stroke(Organic.n300, lineWidth: Organic.stroke))
    }
}

extension FormField where V == AnyView {
    /// A text field. Autocorrect is off: camera models, shops and lenders are
    /// proper nouns the keyboard "fixes" into nonsense.
    init(_ placeholder: String, text: Binding<String>, numeric: Bool = false, decimal: Bool = false) {
        self.init {
            AnyView(
                TextField(placeholder, text: text)
                    .keyboardType(numeric ? .numberPad : (decimal ? .decimalPad : .default))
                    .autocorrectionDisabled()
            )
        }
    }
}

/// The small label above a control or group of chips.
struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(Organic.captionStrong).foregroundStyle(Organic.n600)
    }
}

/// Help text under a control or title.
struct HelpText: View {
    let text: String
    var tone: Tone = .quiet
    enum Tone { case quiet, warning, positive }
    init(_ text: String, tone: Tone = .quiet) { self.text = text; self.tone = tone }
    var body: some View {
        Text(text).font(Organic.caption).foregroundStyle(colour)
    }
    private var colour: Color {
        switch tone {
        case .quiet: return Organic.n600
        case .warning: return Organic.a800
        case .positive: return Organic.s700
        }
    }
}

// MARK: - Data display

/// Label over value. The one shape for a figure with a name: item metrics,
/// plan figures, the hero's stats, Stats tiles.
struct Metric: View {
    let label: String
    let value: String
    var valueColor: Color = Organic.text
    var labelColor: Color = Organic.n600
    /// `statValue` instead of `rowValue` — hero cards and tiles.
    var large: Bool = false
    /// Draws its own tinted box (Stats tiles, Inventory summary).
    var boxed: Bool = false
    var fill: Color = Organic.n100
    var body: some View {
        let stack = VStack(alignment: .leading, spacing: 2) {
            Text(label).font(Organic.meta).foregroundStyle(labelColor)
            Text(value).font(large ? Organic.statValue : Organic.rowValue)
                .foregroundStyle(valueColor).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        if boxed {
            stack.padding(.horizontal, 11).padding(.vertical, 9)
                .background(fill, in: RoundedRectangle(cornerRadius: Organic.rInner, style: .continuous))
        } else {
            stack
        }
    }
}

/// Uppercase capsule tag: SOLD, NEW, CASH, POINT, an owner's name.
struct Badge: View {
    enum Tone { case accent, sage, neutral }
    let text: String
    var tone: Tone = .neutral
    /// Off for user-written names (a category), where shouting changes the meaning.
    var uppercase: Bool = true
    init(_ text: String, tone: Tone = .neutral, uppercase: Bool = true) {
        self.text = text; self.tone = tone; self.uppercase = uppercase
    }
    var body: some View {
        Text(uppercase ? text.uppercased() : text).font(Organic.badge)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(fill, in: Capsule()).foregroundStyle(foreground)
    }
    private var fill: Color {
        switch tone {
        case .accent: return Organic.a200
        case .sage: return Organic.s200
        case .neutral: return Organic.n200
        }
    }
    private var foreground: Color {
        switch tone {
        case .accent: return Organic.a900
        case .sage: return Organic.s900
        case .neutral: return Organic.n700
        }
    }
}

/// Row separator. An explicit rectangle, because a Divider inside a Button
/// label can resolve to the wrong axis.
struct Hairline: View {
    var color: Color = Organic.n200
    var body: some View {
        Rectangle().fill(color).frame(height: 1).frame(maxWidth: .infinity)
    }
}

/// One-line placeholder inside an otherwise empty card.
struct EmptyNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(Organic.value).foregroundStyle(Organic.n600)
            .padding(.vertical, Organic.Space.row)
    }
}

/// A callout strip inside a card: "Cash left after this date  ¥732,273".
struct CalloutRow: View {
    let label: String
    let value: String
    var positive: Bool = true
    var body: some View {
        HStack {
            Text(label).font(Organic.captionStrong)
            Spacer()
            Text(value).font(Organic.rowValue)
        }
        .foregroundStyle(positive ? Organic.s900 : Organic.a900)
        .padding(.horizontal, 11).padding(.vertical, Organic.Space.s)
        .background(positive ? Organic.s100 : Organic.a100,
                    in: RoundedRectangle(cornerRadius: Organic.rSmall, style: .continuous))
    }
}

// MARK: - Layout

/// Wrapping row of chips.
struct FlowRow: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxWidth { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}

/// Wraps a list row so it reads as tappable and carries its separator.
struct RowButton<Label: View>: View {
    var first: Bool = false
    let action: () -> Void
    @ViewBuilder var label: Label
    var body: some View {
        Button(action: action) {
            label
                .padding(.vertical, Organic.Space.row)
                .overlay(alignment: .top) { if !first { Hairline() } }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(Organic.text)
    }
}
