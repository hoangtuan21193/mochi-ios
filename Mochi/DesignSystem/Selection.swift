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
            .padding(.horizontal, Organic.Space.l).frame(minHeight: 34)
            .background(selected ? tint : Organic.n100)
            .foregroundStyle(selected ? Organic.bg : Organic.text)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(selected ? .clear : Organic.n400, lineWidth: Organic.stroke))
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
                Image(systemName: "chevron.down").font(Organic.glyph).foregroundStyle(Organic.n500)
            }
            .padding(.horizontal, compact ? Organic.Space.row : Organic.Space.card)
            .padding(.vertical, compact ? 7 : Organic.Space.m)
            .background(Organic.n100, in: RoundedRectangle(cornerRadius: Organic.rSmall, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Organic.rSmall, style: .continuous).stroke(Organic.n400, lineWidth: Organic.stroke))
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
                Image(systemName: "chevron.down").font(Organic.glyph).foregroundStyle(Organic.n500)
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

// MARK: - Redesign selection

/// Two or three views of one screen: List | Spending, Budget | Goals |
/// Subscriptions. Tabs, not chips: exactly one is always showing.
struct SegmentedTabs<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    /// The small one that sits beside a card's title ("Where it went |
    /// Categories Shops Places"): caption type, sized to its words.
    var compact = false
    /// A figure under each name (Accounts ¥311,400 · Cards and plans
    /// −¥893,000): the tabs then say what is behind them before a tap.
    var detail: ((T) -> String)? = nil
    let label: (T) -> LocalizedStringKey
    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { o in
                Button { selection = o } label: {
                    VStack(spacing: 1) {
                        Text(label(o))
                        if let detail { Text(verbatim: detail(o)).font(Organic.meta).foregroundStyle(Organic.n600) }
                    }
                        .padding(.vertical, detail == nil ? 0 : 6)
                        .font(compact ? (selection == o ? Organic.captionStrong : Organic.caption)
                                      : (selection == o ? Organic.valueStrong : Organic.value))
                        .padding(.horizontal, compact ? 10 : 0)
                        .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? 28 : 34)
                        .background(selection == o ? Organic.raised : .clear,
                                    in: RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous))
                        .foregroundStyle(selection == o ? Organic.text : Organic.n600)
                        .shadow(color: .black.opacity(selection == o ? 0.08 : 0), radius: 1, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == o ? .isSelected : [])
            }
        }
        .padding(compact ? 2 : 3)
        .background(Organic.surface, in: RoundedRectangle(cornerRadius: compact ? 8 : Organic.rSmall, style: .continuous))
    }
}

/// ◀ 25 Sep – 24 Oct ▶ — `MonthStepper` for any period: the caller says what
/// the period is called and where a step goes. `forward` nil greys the ▶:
/// what was spent cannot be looked at ahead.
struct PeriodStepper: View {
    let title: String
    let back: () -> Void
    var forward: (() -> Void)?
    var body: some View {
        HStack(spacing: 2) {
            Button(action: back) { Image(systemName: "chevron.left").frame(width: 32, height: 32) }
                .accessibilityLabel("Earlier")
            Text(verbatim: title).font(Organic.title).lineLimit(1).fixedSize()
            Button { forward?() } label: { Image(systemName: "chevron.right").frame(width: 32, height: 32) }
                .disabled(forward == nil)
                .foregroundStyle(forward == nil ? Organic.n500 : Organic.text)
                .accessibilityLabel("Later")
        }
        .foregroundStyle(Organic.text)
        .buttonStyle(.plain)
    }
}

/// Three ways to draw the same figures — a ring, columns, a flow — as a row of
/// symbols, the chosen one on a quiet square. Only for a choice of *view*;
/// a choice of data is `SegmentedTabs`.
struct IconSegments<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let symbol: (T) -> String
    let label: (T) -> LocalizedStringKey
    var body: some View {
        HStack(spacing: Organic.Space.m) {
            ForEach(options, id: \.self) { o in
                Button { selection = o } label: {
                    Image(systemName: symbol(o))
                        .font(Organic.value)
                        .frame(width: 36, height: 36)
                        .foregroundStyle(selection == o ? Organic.text : Organic.n600)
                        .background(selection == o ? Organic.n200 : .clear,
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(o))
                .accessibilityAddTraits(selection == o ? .isSelected : [])
            }
        }
    }
}

/// ◀ September 2026 ▶ — steps a month at a time, never past this one.
struct MonthStepper: View {
    @Binding var month: Date
    /// Fixed items can be looked at ahead; what was spent cannot.
    var allowsFuture = false
    /// Arrows at the edges and the month centred, for a page that is all
    /// about the month (Recurring); otherwise they hug the month.
    var spread = false
    var body: some View {
        let cal = Calendar.current
        let atNow = cal.isDate(month, equalTo: .now, toGranularity: .month)
        HStack(spacing: 2) {
            Button { month = cal.date(byAdding: .month, value: -1, to: month)! } label: {
                Image(systemName: "chevron.left").frame(width: 32, height: 32)
            }
            .accessibilityLabel("Previous month")
            if spread { Spacer() }
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(Organic.title).lineLimit(1).fixedSize()
            if spread { Spacer() }
            Button { month = cal.date(byAdding: .month, value: 1, to: month)! } label: {
                Image(systemName: "chevron.right").frame(width: 32, height: 32)
            }
            .disabled(atNow && !allowsFuture)
            // The plain style keeps the row's ink on a disabled button, so the
            // way that is shut has to be greyed by hand.
            .foregroundStyle(atNow && !allowsFuture ? Organic.n500 : Organic.text)
            .accessibilityLabel("Next month")
        }
        .foregroundStyle(Organic.text)
        .buttonStyle(.plain)
    }
}

/// A row of filter chips that scrolls sideways when it runs out of room.
struct FilterChips<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> Text
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Organic.Space.m) {
                ForEach(options, id: \.self) { o in
                    Button { selection = o } label: { Chip(label: label(o), selected: selection == o) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

/// A month as a grid, Monday first: each day with a dot per thing on it and an
/// optional short figure, today ringed, one day selectable. The Recurring
/// calendar; the colours say what each dot is and a `ChartLegend` names them.
struct CalendarMonth: View {
    let month: Date
    /// Dot colours per day of the month.
    let marks: [Int: [Color]]
    /// A short figure under a day ("+452k").
    var labels: [Int: String] = [:]
    @Binding var selected: Int?

    var body: some View {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .month, for: month)!.start
        let days = cal.range(of: .day, in: .month, for: month)!.count
        // Monday = 0.
        let lead = (cal.component(.weekday, from: start) + 5) % 7
        let today = cal.isDate(.now, equalTo: month, toGranularity: .month) ? cal.component(.day, from: .now) : nil
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        LazyVGrid(columns: columns, spacing: 4) {
            // One list of cells with one id each: header, blank and day
            // cells in separate ForEach ranges shared 0…6, and the grid
            // dropped the first days of the month.
            ForEach(cells(lead: lead, days: days), id: \.self) { cell in
                switch cell {
                case .header(let i):
                    // Monday first, named in the reader's language.
                    Text(verbatim: Self.weekdays[i]).font(Organic.metaStrong).foregroundStyle(Organic.n500)
                case .blank:
                    Color.clear.frame(height: 48)
                case .day(let day):
                    dayCell(day, today: today)
                }
            }
        }
    }

    private enum Cell: Hashable { case header(Int), blank(Int), day(Int) }

    private static var weekdays: [String] {
        let s = Calendar.current.shortWeekdaySymbols   // Sunday first
        return Array(s[1...] + s[..<1])
    }

    private func cells(lead: Int, days: Int) -> [Cell] {
        (0..<7).map(Cell.header) + (0..<lead).map(Cell.blank) + (1...days).map(Cell.day)
    }

    private func dayCell(_ day: Int, today: Int?) -> some View {
        Button { selected = selected == day ? nil : day } label: {
            VStack(spacing: 2) {
                Text(verbatim: "\(day)").font(Organic.valueStrong)
                    .frame(width: 26, height: 26)
                    .background(selected == day ? Organic.n900 : .clear, in: Circle())
                    .overlay(Circle().stroke(today == day && selected != day ? Organic.text : .clear, lineWidth: 1.5))
                    .foregroundStyle(selected == day ? Organic.bg : Organic.text)
                HStack(spacing: 2) {
                    ForEach(Array((marks[day] ?? []).prefix(3).enumerated()), id: \.offset) { _, c in
                        Circle().fill(c).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
                Text(verbatim: labels[day] ?? " ").font(Organic.badge).foregroundStyle(Organic.s700).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(day)"))
    }
}
