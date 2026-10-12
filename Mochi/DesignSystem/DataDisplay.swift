import SwiftUI
import Charts

// MARK: - Data display

/// Label over value. The one shape for a figure with a name: item metrics,
/// plan figures, the hero's stats, Stats tiles.
struct Metric: View {
    let label: LocalizedStringKey
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
            // "Sell-all proceeds" is one line; "Tiền thu nếu bán hết" is two.
            // A boxed metric stretches to the tallest in its row so the boxes
            // stay the same size, and the spacer holds every value down on the
            // same line instead of letting each float under its own label.
            if boxed { Spacer(minLength: 2) }
            Text(value).font(large ? Organic.statValue : Organic.rowValue)
                .foregroundStyle(valueColor).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: boxed ? .infinity : nil, alignment: .topLeading)
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
    private let label: Text
    private let shout: Bool
    var tone: Tone = .neutral
    /// A tag the app writes: SOLD, CASH, POINT. Translated, then shouted —
    /// through `.textCase`, which follows the locale's own casing rules, and
    /// which Japanese simply has nothing to do, so a kanji tag comes out as
    /// written.
    init(_ key: LocalizedStringKey, tone: Tone = .neutral) {
        self.label = Text(key); self.tone = tone; self.shout = true
    }
    /// A name the user wrote — a category, an owner. Never translated.
    /// `shout` off for a category, where capitals change what the name says.
    init(verbatim name: String, tone: Tone = .neutral, shout: Bool = false) {
        self.label = Text(verbatim: name); self.tone = tone; self.shout = shout
    }
    var body: some View {
        label.font(Organic.badge)
            .textCase(shout ? .uppercase : nil)
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

/// The closing line of a list card: what the rows above add up to, under a
/// hairline. Every section that can be added up ends in one of these, so a
/// total never reads as one more row — and it is the only place the rows a
/// section collapses out of sight are still counted.
struct SectionTotal: View {
    let label: LocalizedStringKey
    let value: String
    /// A second, quieter figure on the left, for a section that adds up two
    /// ways at once: instalments owe a debit next month and a total before
    /// they are done.
    var note: LocalizedStringKey? = nil
    var tint: Color = Organic.n700
    /// The card's own hairline colour — the terracotta cards draw a200.
    var hairline: Color = Organic.n200
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let note {
                Text(note).font(Organic.meta).foregroundStyle(tint.opacity(0.75))
            }
            Spacer(minLength: 8)
            Text(label).font(Organic.metaStrong).foregroundStyle(tint.opacity(0.75))
            Text(verbatim: value).font(Organic.rowValue).foregroundStyle(tint)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) { Hairline(color: hairline) }
    }
}

/// The key to a chart: one swatch and one word per mark drawn.
///
/// A chart with hidden axes is a shape until something says what it plots.
/// This is that something, and it is a component rather than three `Text`s in
/// a row so every chart in the app explains itself the same way.
struct ChartLegend: View {
    struct Key {
        /// What the mark is drawn in — the same colour as the mark itself.
        let colour: Color
        let mark: Mark
        let label: LocalizedStringKey
        /// A series is a line, a threshold is dashed, a single reading is a
        /// dot, a bar chart's colour is a block.
        enum Mark { case line, dashed, dot, bar }

        init(_ label: LocalizedStringKey, _ mark: Mark, _ colour: Color) {
            self.label = label; self.mark = mark; self.colour = colour
        }
    }
    let keys: [Key]
    init(_ keys: Key...) { self.keys = keys }

    var body: some View {
        FlowRow(spacing: 10) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                HStack(spacing: 4) {
                    swatch(key)
                    Text(key.label)
                }
            }
        }
        .font(Organic.meta).foregroundStyle(Organic.n600)
    }

    @ViewBuilder
    private func swatch(_ key: Key) -> some View {
        switch key.mark {
        case .line:
            Capsule().fill(key.colour).frame(width: 13, height: 2.5)
        case .dashed:
            // A path, not a capsule: the dash has to read as the dash on the
            // chart, and a short solid bar would look like the series line.
            Path { $0.addLines([CGPoint(x: 0, y: 1), CGPoint(x: 13, y: 1)]) }
                .stroke(key.colour, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                .frame(width: 13, height: 2)
        case .dot:
            Circle().fill(key.colour).frame(width: 6, height: 6)
        case .bar:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(key.colour).frame(width: 9, height: 9)
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
    let text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }
    var body: some View {
        Text(text).font(Organic.value).foregroundStyle(Organic.n600)
            .padding(.vertical, Organic.Space.row)
    }
}

/// A callout strip inside a card: "Cash left after this date  ¥732,273".
struct CalloutRow: View {
    let label: LocalizedStringKey
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

/// One line of a breakdown: label on the left, figure on the right. The
/// plain shape for "cash + incoming − committed = safe": no tint, no box, so
/// a stack of them reads as a sum rather than as five separate alerts.
/// `tone` colours the figure only; the label stays quiet.
struct LineRow: View {
    enum Tone { case neutral, positive, negative, quiet }
    let label: LocalizedStringKey
    let value: String
    var tone: Tone = .neutral
    /// White text for a dark card.
    var onDark: Bool = false
    /// Heavier: the line the others add up to.
    var total: Bool = false
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(total ? Organic.captionStrong : Organic.caption)
                .foregroundStyle(onDark ? .white.opacity(total ? 0.9 : 0.65) : (total ? Organic.text : Organic.n600))
            Spacer(minLength: 8)
            Text(value).font(total ? Organic.title : Organic.rowValue)
                .foregroundStyle(colour).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.vertical, total ? 5 : 3)
    }
    private var colour: Color {
        switch tone {
        case .neutral: return onDark ? .white : Organic.text
        case .positive: return onDark ? Organic.s300 : Organic.s700
        case .negative: return onDark ? Organic.a300 : Organic.a700
        case .quiet: return onDark ? .white.opacity(0.6) : Organic.n500
        }
    }
}

/// Long-press a name to put it on the clipboard, with a tap-back and a badge
/// that fades to say it happened. Wraps the item name wherever it is printed —
/// the list row and the item's own page — because that name is what gets
/// pasted into a marketplace listing or a chat, and retyping
/// "SIGMA 200mm f2.8 APO" is how it comes out wrong.
private struct CopyOnLongPress: ViewModifier {
    let value: String
    /// Counts the copies rather than flagging one, so a second long press
    /// still buzzes: `sensoryFeedback` only fires when its trigger changes.
    @State private var copies = 0
    @State private var showing = false

    func body(content: Content) -> some View {
        content
            // High priority, not simultaneous: the row is a navigation link,
            // and a plain button fires its action on release even after a long
            // press — copying and then opening the item at once.
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 0.4).onEnded { _ in copy() }
            )
            .sensoryFeedback(.success, trigger: copies)
            .overlay(alignment: .topTrailing) {
                if showing {
                    Badge("Copied", tone: .sage)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
    }

    private func copy() {
        guard !value.isEmpty else { return }
        UIPasteboard.general.string = value
        copies += 1
        withAnimation(.easeOut(duration: 0.15)) { showing = true }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.easeIn(duration: 0.2)) { showing = false }
        }
    }
}

extension View {
    /// Long press to copy `value` — the user's own text, never app copy.
    func copyOnLongPress(_ value: String) -> some View {
        modifier(CopyOnLongPress(value: value))
    }
}

// MARK: - Redesign parts

/// A figure in a box, label over value with an optional line under it: the
/// 2×2 grids at the top of Home, Spending, Net worth and Belongings.
struct Tile: View {
    let label: LocalizedStringKey
    let value: String
    var sub: String? = nil
    var valueColor: Color = Organic.text
    var subColor: Color = Organic.n600
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Organic.caption).foregroundStyle(Organic.n600)
            Text(verbatim: value).font(Organic.statValue).foregroundStyle(valueColor)
                .lineLimit(1).minimumScaleFactor(0.6)
            if let sub { Text(verbatim: sub).font(Organic.caption).foregroundStyle(subColor).lineLimit(2) }
        }
        .padding(Organic.Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Organic.n100, in: RoundedRectangle(cornerRadius: Organic.rInner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Organic.rInner, style: .continuous).stroke(Organic.n300, lineWidth: Organic.stroke))
    }
}

/// Two tiles a row, the same height across.
struct TileGrid<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) { content }
    }
}

/// The square at the start of a row: an SF Symbol or two letters of a name,
/// on a tint that says what kind of thing it is.
struct LeadMark: View {
    /// `dated` is a day on a calendar leaf — "TUE" over "27", "TODAY" over
    /// "12" — for a list of things that happen on a date.
    enum Glyph { case symbol(String), initials(String), dated(String, Int) }
    let glyph: Glyph
    var tint: Color = Organic.n200
    var ink: Color = Organic.text
    var size: CGFloat = 36
    /// A circle instead of the rounded square: for a way in to a feature,
    /// where the square would read as one more thing in a list.
    var round = false
    var body: some View {
        Group {
            switch glyph {
            case .symbol(let s): Image(systemName: s).font(Organic.valueStrong)
            case .initials(let s): Text(verbatim: String(s.prefix(2))).font(Organic.valueStrong)
            case .dated(let top, let day):
                VStack(spacing: 0) {
                    Text(verbatim: top.uppercased()).font(Organic.badge)
                    Text(verbatim: "\(day)").font(Organic.title)
                }
            }
        }
        .frame(width: size, height: size)
        .background(tint, in: RoundedRectangle(cornerRadius: round ? size / 2 : size * 0.28, style: .continuous))
        .foregroundStyle(ink)
    }
}

/// A list row: mark, title and subline on the left, figure and a quieter
/// line on the right. Every list in the redesign is a stack of these.
struct ListRow: View {
    let title: String
    var sub: String? = nil
    var value: String? = nil
    var valueSub: String? = nil
    var valueColor: Color = Organic.text
    var subColor: Color = Organic.n600
    var mark: LeadMark? = nil
    var chevron = false
    /// Semibold title: the line a list adds up to ("You keep"), or a row that
    /// is a way in rather than a thing ("Buy advice").
    var strong = false
    var body: some View {
        HStack(spacing: Organic.Space.l) {
            if let mark { mark }
            VStack(alignment: .leading, spacing: 2) {
                // Two lines before an ellipsis: a name cut at "f/2…" loses what tells
                // two lenses apart.
                Text(verbatim: title).font(strong ? Organic.rowValue : Organic.row).lineLimit(2)
                if let sub, !sub.isEmpty { Text(verbatim: sub).font(Organic.caption).foregroundStyle(subColor).lineLimit(3) }
            }
            Spacer(minLength: 8)
            if value != nil || valueSub != nil {
                VStack(alignment: .trailing, spacing: 2) {
                    if let value { Text(verbatim: value).font(Organic.rowValue).foregroundStyle(valueColor) }
                    if let valueSub { Text(verbatim: valueSub).font(Organic.meta).foregroundStyle(Organic.n600) }
                }
                .fixedSize()
            }
            if chevron { Image(systemName: "chevron.right").font(Organic.glyph).foregroundStyle(Organic.n500) }
        }
        .frame(minHeight: 44)
        .padding(.vertical, Organic.Space.row)
        .contentShape(Rectangle())
    }
}

/// A verdict said in one line: a mark and a sentence, in the colour of what
/// it means. Never a pill — a pill looks like something to tap.
struct Verdict: View {
    let text: LocalizedStringKey
    var positive = true
    var body: some View {
        Label { Text(text) } icon: { Image(systemName: positive ? "checkmark" : "exclamationmark.triangle") }
            .font(Organic.valueStrong)
            .foregroundStyle(positive ? Organic.s700 : Organic.a700)
    }
}

/// A thin bar: how much of a budget or a goal is used.
struct ProgressBar: View {
    let fraction: Double
    var tint: Color = Organic.info
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Organic.n200)
                Capsule().fill(tint).frame(width: max(0, min(1, fraction)) * g.size.width)
            }
        }
        .frame(height: 6)
    }
}

/// A tinted strip with a mark, a sentence and an action on the right:
/// "3 came in from Apple Pay · Review".
struct Banner: View {
    enum Tone { case info, warn, positive, accent }
    let text: LocalizedStringKey
    var action: LocalizedStringKey? = nil
    var symbol = "info.circle"
    var tone: Tone = .info
    /// A second, smaller line under the sentence: the deadline under "Move
    /// ¥66,000 from SMBC to MUFG". With it the sentence is set bold.
    var detail: LocalizedStringKey? = nil
    var body: some View {
        HStack(spacing: Organic.Space.row) {
            Image(systemName: symbol).font(detail == nil ? Organic.value : .title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(text).font(detail == nil ? Organic.value : Organic.valueStrong)
                if let detail { Text(detail).font(Organic.caption) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let action { Text(action).font(Organic.valueStrong) }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, Organic.Space.l).padding(.vertical, Organic.Space.row)
        .background(fill, in: RoundedRectangle(cornerRadius: Organic.rSmall, style: .continuous))
    }
    private var fill: Color {
        switch tone { case .info: Organic.infoSoft; case .warn: Organic.warnSoft; case .positive: Organic.s100; case .accent: Organic.alertSoft }
    }
    private var ink: Color {
        switch tone { case .info: Organic.infoInk; case .warn: Organic.warnInk; case .positive: Organic.s800; case .accent: Organic.alertInk }
    }
}

/// The heading over a list card: a name on the left, a figure on the right.
struct ListHeading: View {
    let title: LocalizedStringKey
    var trailing: String? = nil
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let trailing { Text(verbatim: trailing) }
        }
        .font(Organic.captionStrong).foregroundStyle(Organic.n600)
        .padding(.horizontal, 4)
    }
}

/// A pill of words over the camera picture: "Read on this iPhone · nothing
/// uploaded". Says a fact; it is not a button.
struct CameraPill: View {
    let text: LocalizedStringKey
    var symbol: String? = nil
    var body: some View {
        HStack(spacing: Organic.Space.s) {
            if let symbol { Image(systemName: symbol) }
            Text(text).lineLimit(1).minimumScaleFactor(0.8)
        }
        .font(Organic.captionStrong)
        .foregroundStyle(Organic.Camera.ink)
        .padding(.horizontal, Organic.Space.l).padding(.vertical, Organic.Space.m)
        .background(Organic.Camera.control, in: Capsule())
    }
}

/// One field the camera has read so far: a tick, what it is, what it says.
/// The tray fills with these while the receipt is held still.
struct FoundChip: View {
    let label: LocalizedStringKey
    let value: String
    var body: some View {
        HStack(spacing: Organic.Space.s) {
            Image(systemName: "checkmark").font(Organic.metaStrong).foregroundStyle(Organic.Camera.found)
            Text(label).foregroundStyle(Organic.Camera.quiet)
            Text(verbatim: value).fontWeight(.semibold).foregroundStyle(Organic.Camera.ink)
        }
        .font(Organic.value)
        .lineLimit(1)
        .padding(.horizontal, Organic.Space.row).padding(.vertical, Organic.Space.m)
        .background(Organic.Camera.chip, in: RoundedRectangle(cornerRadius: Organic.rSmall, style: .continuous))
    }
}

/// The four corners of the viewfinder: where to hold the receipt.
struct ViewfinderCorners: Shape {
    var arm: CGFloat = 36
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + arm)); p.addLine(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + arm, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - arm, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + arm))
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - arm)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX - arm, y: r.maxY))
        p.move(to: CGPoint(x: r.minX + arm, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY - arm))
        return p
    }
}

/// The outline round one line the camera read, through the line's own four
/// corners (top left, top right, bottom right, bottom left) and a few points
/// outside them, so it follows a receipt held at a slant instead of boxing it
/// square.
struct LineOutline: Shape {
    let corners: [CGPoint]
    var pad: CGFloat = 4
    func path(in _: CGRect) -> Path {
        guard corners.count == 4 else { return Path() }
        let cx = corners.map(\.x).reduce(0, +) / 4, cy = corners.map(\.y).reduce(0, +) / 4
        let out = corners.map { p -> CGPoint in
            let dx = p.x - cx, dy = p.y - cy, l = max(hypot(dx, dy), 1)
            return CGPoint(x: p.x + dx / l * pad, y: p.y + dy / l * pad)
        }
        var path = Path()
        path.addLines(out)
        path.closeSubpath()
        return path
    }
}

// MARK: - Shares of a total

/// One slice, column or stream of a total: what it is, how much, its colour,
/// and a symbol when it has one (a category) — otherwise its initials.
struct ChartShare: Identifiable {
    var id: String { name }
    let name: String
    let amount: Int
    let color: Color
    var symbol: String? = nil
}

/// The shares as a ring with the total in the hole.
struct ShareRing: View {
    let shares: [ChartShare]
    let total: String
    var body: some View {
        ZStack {
            Chart(shares) { s in
                SectorMark(angle: .value("Amount", s.amount), innerRadius: .ratio(0.69))
                    .foregroundStyle(s.color)
            }
            .frame(width: 142, height: 142)
            VStack(spacing: 2) {
                Text("Total").font(Organic.caption).foregroundStyle(Organic.n600)
                Text(verbatim: total).font(Organic.statValue)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .accessibilityElement(children: .combine)
    }
}

/// The shares as columns, largest first: a short figure on top ("85k"), the
/// symbol or initials underneath. Names and exact amounts are in the list
/// that always follows it, so the columns carry no names.
struct ShareColumns: View {
    let shares: [ChartShare]
    /// "85k" from an amount.
    let short: (Int) -> String
    var height: CGFloat = 170
    var body: some View {
        let top = max(shares.map(\.amount).max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: Organic.Space.m) {
            ForEach(shares) { s in
                VStack(spacing: 6) {
                    Text(verbatim: short(s.amount)).font(Organic.metaStrong).lineLimit(1).minimumScaleFactor(0.7)
                    UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 2, bottomTrailingRadius: 2, topTrailingRadius: 6)
                        .fill(s.color)
                        .frame(maxWidth: 32)
                        .frame(height: max(4, height * CGFloat(s.amount) / CGFloat(top)))
                    LeadMark(glyph: s.symbol.map { .symbol($0) } ?? .initials(s.name), tint: Organic.n200, ink: s.color, size: 28)
                        .accessibilityLabel(Text(verbatim: s.name))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height + 60, alignment: .bottom)
    }
}

/// Money followed from where it came to where it went: one column on the
/// left (income, and what was taken from savings when spending ran past it),
/// streams to one bar per destination on the right, each named with its
/// figure. Not a balance over time — decision #3 still stands.
struct FlowChart: View {
    struct Node: Identifiable {
        var id: String { name }
        let name: String
        let value: String
        let amount: Int
        let color: Color
    }
    let sources: [Node]
    let targets: [Node]
    var height: CGFloat = 300

    var body: some View {
        GeometryReader { g in
            let layout = Layout(sources: sources, targets: targets, width: g.size.width, height: height)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    for link in layout.links {
                        var p = Path()
                        let mid = (layout.leftX + layout.barW + layout.rightX) / 2
                        p.move(to: CGPoint(x: layout.leftX + layout.barW, y: link.from.lowerBound))
                        p.addCurve(to: CGPoint(x: layout.rightX, y: link.to.lowerBound),
                                   control1: CGPoint(x: mid, y: link.from.lowerBound), control2: CGPoint(x: mid, y: link.to.lowerBound))
                        p.addLine(to: CGPoint(x: layout.rightX, y: link.to.upperBound))
                        p.addCurve(to: CGPoint(x: layout.leftX + layout.barW, y: link.from.upperBound),
                                   control1: CGPoint(x: mid, y: link.to.upperBound), control2: CGPoint(x: mid, y: link.from.upperBound))
                        p.closeSubpath()
                        ctx.fill(p, with: .color(link.color.opacity(0.28)))
                    }
                    for (i, r) in layout.sourceBars.enumerated() {
                        ctx.fill(Path(roundedRect: CGRect(x: layout.leftX, y: r.lowerBound, width: layout.barW, height: r.upperBound - r.lowerBound), cornerRadius: 2),
                                 with: .color(i == 0 ? Organic.text : Organic.n500))
                    }
                    for (i, r) in layout.targetBars.enumerated() {
                        ctx.fill(Path(roundedRect: CGRect(x: layout.rightX, y: r.lowerBound, width: 8, height: r.upperBound - r.lowerBound), cornerRadius: 2),
                                 with: .color(targets[i].color))
                    }
                }
                ForEach(Array(sources.enumerated()), id: \.element.id) { i, n in
                    label(n).offset(x: 0, y: i == 0 ? layout.sourceBars[0].lowerBound - 22 : layout.sourceBars[i].upperBound + 4)
                }
                ForEach(Array(targets.enumerated()), id: \.element.id) { i, n in
                    label(n).offset(x: layout.rightX + 14, y: layout.labelY[i])
                }
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .combine)
    }

    private func label(_ n: Node) -> some View {
        (Text(verbatim: n.name).font(Organic.captionStrong) + Text(verbatim: " " + n.value).font(Organic.caption).foregroundStyle(Organic.n600))
            .lineLimit(1).fixedSize()
    }

    /// Where every bar and stream sits: the left column takes the whole
    /// total, the right bars share it with a gap between each (a thin one
    /// still drawn 4 pt tall), and the labels are pushed apart so none
    /// overlaps the one above.
    private struct Layout {
        struct Link { let from: ClosedRange<CGFloat>; let to: ClosedRange<CGFloat>; let color: Color }
        let leftX: CGFloat = 0, barW: CGFloat = 10
        let rightX: CGFloat
        var sourceBars: [ClosedRange<CGFloat>] = []
        var targetBars: [ClosedRange<CGFloat>] = []
        var links: [Link] = []
        var labelY: [CGFloat] = []

        init(sources: [Node], targets: [Node], width: CGFloat, height: CGFloat) {
            rightX = min(width * 0.56, width - 150)
            let total = CGFloat(max(targets.reduce(0) { $0 + $1.amount }, 1))
            let gap: CGFloat = 14, top: CGFloat = 12
            let right = height - top * 2 - gap * CGFloat(max(targets.count - 1, 0))
            let leftH = right * 0.8
            let leftTop = (height - leftH) / 2
            var y = leftTop
            for s in sources {
                let h = leftH * CGFloat(s.amount) / total
                sourceBars.append(y...(y + h)); y += h
            }
            var ty = top, ly = leftTop
            for t in targets {
                let h = max(4, right * CGFloat(t.amount) / total)
                let lh = leftH * CGFloat(t.amount) / total
                targetBars.append(ty...(ty + h))
                links.append(Link(from: ly...(ly + lh), to: ty...(ty + h), color: t.color))
                ty += h + gap; ly += lh
            }
            var last: CGFloat = -100
            for r in targetBars {
                let want = max((r.lowerBound + r.upperBound) / 2 - 9, last + 18)
                labelY.append(want); last = want
            }
        }
    }
}

/// Six months side by side, each with its short figure on top; the one on
/// screen is in full colour, the rest faint. Tapping one picks it.
struct MonthBars: View {
    struct Bar: Identifiable {
        var id: Date { month }
        let month: Date
        let amount: Int
    }
    let bars: [Bar]
    let selected: Date
    let short: (Int) -> String
    var color: Color = Organic.chartColor(0)
    let onPick: (Date) -> Void
    var body: some View {
        let top = max(bars.map(\.amount).max() ?? 1, 1)
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(bars) { b in
                    let on = Calendar.current.isDate(b.month, equalTo: selected, toGranularity: .month)
                    Button { onPick(b.month) } label: {
                        VStack(spacing: 4) {
                            Text(verbatim: short(b.amount)).font(Organic.meta).foregroundStyle(Organic.n600)
                            UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6)
                                .fill(on ? color : color.opacity(0.25))
                                .frame(height: max(2, 96 * CGFloat(b.amount) / CGFloat(top)))
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text(verbatim: "\(b.month.formatted(.dateTime.month(.wide))) \(short(b.amount))"))
                }
            }
            .frame(height: 120, alignment: .bottom)
            .overlay(alignment: .bottom) { Hairline() }
            HStack(spacing: 14) {
                ForEach(bars) { b in
                    Text(b.month.formatted(.dateTime.month(.abbreviated))).font(Organic.caption).foregroundStyle(Organic.n600)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

/// Net worth month by month, drawn small at the head of Wallet: a line with
/// a soft fill, the latest reading ringed, a month name every other month.
/// The one wealth line the app draws; its full chart is Net worth's.
struct NetWorthLine: View {
    let points: [(month: Date, value: Int)]
    var color: Color = Organic.chartColor(0)
    var body: some View {
        let low = points.map(\.value).min() ?? 0
        let high = points.map(\.value).max() ?? 1
        let pad = max(1, (high - low) / 6)
        Chart {
            ForEach(points, id: \.month) { p in
                // Plotted on the first of the month, not in the middle of a
                // month-wide bin: the month names then stand under their points.
                AreaMark(x: .value("Month", p.month), yStart: .value("Floor", low - pad), yEnd: .value("Net worth", p.value))
                    .foregroundStyle(color.opacity(0.12))
                LineMark(x: .value("Month", p.month), y: .value("Net worth", p.value))
                    .foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 2))
            }
            if let last = points.last {
                PointMark(x: .value("Month", last.month), y: .value("Net worth", last.value))
                    .symbol { Circle().strokeBorder(color, lineWidth: 2).background(Circle().fill(Organic.n100)).frame(width: 9, height: 9) }
            }
        }
        .chartYScale(domain: (low - pad)...(high + pad))
        // Room at both ends so the first and last month names are not cut.
        .chartXScale(range: .plotDimension(padding: 14))
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated), anchor: .top).font(Organic.meta)
            }
        }
        .frame(height: 90)
        .accessibilityLabel("Net worth by month")
    }
}

/// Figures that sit beside a total and are not in it ("Bought as belongings ·
/// not in the total"), on the info tint so they read as an aside.
struct AsideStrip: View {
    struct Line: Identifiable {
        let id = UUID()
        let label: LocalizedStringKey
        let value: String
    }
    let lines: [Line]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(lines) { l in
                HStack(alignment: .firstTextBaseline) {
                    Text(l.label).font(Organic.value)
                    Spacer(minLength: 8)
                    Text(verbatim: l.value).font(Organic.valueStrong)
                }
            }
        }
        .foregroundStyle(Organic.infoInk)
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Organic.infoSoft, in: RoundedRectangle(cornerRadius: Organic.rInner, style: .continuous))
    }
}
