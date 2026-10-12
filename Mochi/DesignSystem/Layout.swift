import SwiftUI

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

    var body: some View {
        if sizeClass == .regular {
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
