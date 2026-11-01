import SwiftUI

// MARK: - Layout

/// Wrapping row of chips.
struct FlowRow: Layout {
    var spacing: CGFloat = 5
    /// Bounds arrive rounded to the pixel, so a row measured exactly as wide
    /// as its chips can come back a hair narrower and drop the last chip
    /// ("Sold" fell to a second row whenever "To use" was picked).
    static let slack: CGFloat = 1

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxWidth + Self.slack { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += s.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, s.height)
        }
        // Asked for its ideal width (`.fixedSize()`), it is one row as wide as
        // its chips; an infinite width here crashes the placement.
        return CGSize(width: maxWidth.isFinite ? maxWidth : widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX + Self.slack { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}

/// Wraps a list row so it reads as tappable and carries its separator.
struct RowButton<Label: View>: View {
    var first: Bool = false
    /// Tinted cards (the point wallets' a100) need a tinted separator.
    var hairline: Color = Organic.n200
    /// Off for a `ListRow`, which carries its own padding: twice over, a
    /// one-line row stood 84 pt tall.
    var padded = true
    let action: () -> Void
    @ViewBuilder var label: Label
    var body: some View {
        Button(action: action) {
            label
                .padding(.vertical, padded ? Organic.Space.row : 0)
                .overlay(alignment: .top) { if !first { Hairline(color: hairline) } }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(Organic.text)
    }
}

// MARK: - Wide screens

/// Two columns where the screen is wide (an iPad, the inner screen of a
/// foldable iPhone), one where it is not. Split by size class, not by
/// device: an iPad in Split View is compact again and gets the phone's
/// column. The leading column is what needs doing now; the trailing one is
/// what comes next and the overview.
struct AdaptiveColumns<Leading: View, Trailing: View>: View {
    var spacing: CGFloat = Organic.Space.l
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.paneWidth) private var paneWidth

    var body: some View {
        // In a `ListDetail`'s right column the screen is regular but the
        // column may be a phone's width and a half; two columns start at 720.
        if sizeClass == .regular && (paneWidth ?? .infinity) >= 720 {
            // Each column at its own natural height: without it a box that
            // fills its row (a boxed `Metric`) grew to the taller column's
            // height, and rows in the other were squeezed to one line.
            HStack(alignment: .top, spacing: Organic.Space.card) {
                VStack(alignment: .leading, spacing: spacing) { leading }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .top)
                VStack(alignment: .leading, spacing: spacing) { trailing }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
        } else {
            VStack(alignment: .leading, spacing: spacing) {
                leading
                trailing
            }
        }
    }
}

extension View {
    /// A list or a form on a wide screen: no wider than reads well, centred.
    /// A line of figures stretched across an iPad puts the amount a hand's
    /// width from its label. Nothing changes on a phone.
    func readableWidth(_ width: CGFloat = 680) -> some View {
        modifier(ReadableWidth(width: width))
    }
}

private struct ReadableWidth: ViewModifier {
    let width: CGFloat
    @Environment(\.horizontalSizeClass) private var sizeClass
    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content.frame(maxWidth: width).frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

// MARK: - List and detail

private struct ClosePaneKey: EnvironmentKey { static let defaultValue: (() -> Void)? = nil }
private struct PaneWidthKey: EnvironmentKey { static let defaultValue: CGFloat? = nil }

extension EnvironmentValues {
    /// How the form in a `ListDetail`'s right column closes. nil in a sheet,
    /// where the sheet's own dismiss does it; a form that ends itself (Save,
    /// Delete) asks this first.
    var closePane: (() -> Void)? {
        get { self[ClosePaneKey.self] }
        set { self[ClosePaneKey.self] = newValue }
    }
    /// The width of the `ListDetail` column a view is in; nil outside one.
    var paneWidth: CGFloat? {
        get { self[PaneWidthKey.self] }
        set { self[PaneWidthKey.self] = newValue }
    }
}

/// A wide screen's list and the row it opened, side by side (decision #41):
/// the list keeps its place while rows are looked at one after another, as
/// in Mail. Each column scrolls on its own. Regular width only; on a phone
/// the row opens as a sheet or a push, as it always has.
struct ListDetail<List: View, Detail: View>: View {
    @ViewBuilder var list: List
    @ViewBuilder var detail: Detail

    var body: some View {
        GeometryReader { g in
            // 42% of the width, kept between a phone's list and a little
            // more, so the detail gets what a wider screen adds.
            let listWidth = min(max(g.size.width * 0.42, 340), 460)
            HStack(spacing: 0) {
                list.frame(width: listWidth)
                    .environment(\.paneWidth, listWidth)
                Rectangle().fill(Organic.n200).frame(width: Organic.stroke)
                detail.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .environment(\.paneWidth, g.size.width - listWidth - Organic.stroke)
            }
        }
    }
}

/// The right column before a row is picked: what picking one will do.
struct DetailPlaceholder: View {
    let text: LocalizedStringKey
    var body: some View {
        Text(text).font(Organic.value).foregroundStyle(Organic.n600)
            .multilineTextAlignment(.center)
            .padding(Organic.Space.gutter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Organic.bg)
    }
}

extension View {
    /// A row in a `ListDetail` list that is open in the right column.
    func openInDetail(_ open: Bool) -> some View {
        background {
            if open {
                RoundedRectangle(cornerRadius: Organic.rSmall).fill(Organic.n200)
                    .padding(.horizontal, -Organic.Space.m)
            }
        }
    }
}

extension View {
    /// A sheet whose form has two columns on an iPad (Check and save, a
    /// belonging, an import): the page size instead of the narrow form
    /// sheet, from iOS 18. On a phone, and before 18, nothing changes.
    @ViewBuilder func wideSheet() -> some View {
        if #available(iOS 18, *) {
            presentationSizing(.page)
        } else {
            self
        }
    }
}

extension View {
    /// Tells the `AdaptiveColumns` inside how wide this is, for a sheet that
    /// may be a narrow form sheet or the page size: two columns only fit the
    /// latter.
    func measuresPaneWidth() -> some View { modifier(MeasuredPane()) }
}

private struct MeasuredPane: ViewModifier {
    @State private var width: CGFloat?
    func body(content: Content) -> some View {
        content
            .environment(\.paneWidth, width)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}
