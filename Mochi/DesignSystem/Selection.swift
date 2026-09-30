import SwiftUI

// MARK: - Selection

/// The pill chip used everywhere for single-select rows.
struct Chip: View {
    let label: Text
    let selected: Bool
    var tint: Color = Organic.n900
    var body: some View {
        label
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
    var label: LocalizedStringKey = ""
    /// The options as the app stores and compares them. A wallet's name, a
    /// stored raw value: identity, never translated on the way through, or
    /// picking a chip would write a Vietnamese word into the book.
    let options: [String]
    let selection: String
    var tint: Color = Organic.n900
    /// Options drawn in accent as chips ("New: Mercari wallet", a point channel).
    var accentOptions: Set<String> = []
    var placeholder: LocalizedStringKey = "Choose"
    /// How an option is written on its chip. Most pickers list names the user
    /// typed, so the default shows them as they are; a picker whose options are
    /// the app's own words passes the translation in here.
    var display: (String) -> Text = { Text(verbatim: $0) }
    let onPick: (String) -> Void

    static let chipLimit = 4

    var body: some View {
        if options.count > Self.chipLimit { dropdown } else { chips }
    }

    private var chips: some View {
        VStack(alignment: .leading, spacing: 5) {
            if hasLabel { FieldLabel(label) }
            FlowRow(spacing: 5) {
                ForEach(options, id: \.self) { opt in
                    Button { onPick(opt) } label: {
                        Chip(label: display(opt), selected: selection == opt,
                             tint: accentOptions.contains(opt) ? Organic.accent : tint)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dropdown: some View {
        HStack {
            if hasLabel { FieldLabel(label) }
            Spacer()
            DropdownPill(value: options.contains(selection) ? display(selection) : Text(placeholder), compact: true) {
                ForEach(options, id: \.self) { opt in
                    Button { onPick(opt) } label: {
                        if opt == selection {
                            Label { display(opt) } icon: { Image(systemName: "checkmark") }
                        } else {
                            display(opt)
                        }
                    }
                }
            }
        }
    }

    /// `LocalizedStringKey` has no `isEmpty`; the empty key is the one default
    /// the pickers without a label rely on, so compare against it directly.
    private var hasLabel: Bool { label != "" }
}

/// A two-state chip that reads as a switch: "Cash / Point", "Records only /
/// Add to card debt". Always drawn selected, in the colour of its state.
struct ToggleChip: View {
    let label: LocalizedStringKey
    let tint: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) { Chip(label: Text(label), selected: true, tint: tint) }
            .buttonStyle(.plain)
    }
}

/// The chosen value as a pill that opens a menu. For lists too long for chips.
struct DropdownPill<Items: View>: View {
    /// Already a `Text`: a pill shows a wallet's name as often as one of the
    /// app's own words, and only the caller knows which it has.
    let value: Text
    var compact: Bool = false
    @ViewBuilder var items: () -> Items
    var body: some View {
        Menu {
            items()
        } label: {
            HStack(spacing: Organic.Space.s) {
                value.font(Organic.rowValue).lineLimit(1)
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
    let label: LocalizedStringKey
    let value: Text
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
    let label: LocalizedStringKey
    let value: Text
    @ViewBuilder var items: () -> Items
    var body: some View {
        Menu {
            items()
        } label: {
            HStack(spacing: Organic.Space.s) {
                Text(label).font(Organic.caption).foregroundStyle(Organic.n600)
                value.font(Organic.valueStrong).foregroundStyle(Organic.text).lineLimit(1)
                Image(systemName: "chevron.up.chevron.down").font(Organic.glyph).foregroundStyle(Organic.n500)
                Spacer()
            }
        }
    }
}

/// A year and a month, as a menu of years each holding its twelve. A plan
/// starts on a month the lender prints as "2025/03": a text field would let
/// "2025/13" through, and a date picker would ask for a day that is stated on
/// its own line.
struct MonthPicker: View {
    let label: LocalizedStringKey
    @Binding var year: Int
    @Binding var month: Int
    /// Plans can be years old, and one can start next month.
    var back = 6
    var ahead = 1

    private var years: [Int] {
        let now = Calendar.current.component(.year, from: .now)
        return Array((now - back)...(now + ahead)).reversed()
    }

    var body: some View {
        InlineMenu(label: label, value: Text(verbatim: MonthPicker.text(year: year, month: month))) {
            ForEach(years, id: \.self) { y in
                Menu(String(y)) {
                    ForEach(1...12, id: \.self) { m in
                        Button(MonthPicker.name(m)) { year = y; month = m }
                    }
                }
            }
        }
    }

    static func name(_ month: Int) -> String {
        let names = Calendar.current.shortMonthSymbols
        return names.indices.contains(month - 1) ? names[month - 1] : "—"
    }

    static func text(year: Int, month: Int) -> String {
        guard year > 1000, (1...12).contains(month) else { return "Pick a month" }
        return "\(name(month)) \(year)"
    }
}
