import SwiftUI

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
