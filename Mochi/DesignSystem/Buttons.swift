import SwiftUI

// MARK: - Buttons

/// Full-width primary action. One per screen or sheet: Save, Import, Move it.
struct PrimaryButton: View {
    let title: LocalizedStringKey
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
    let title: LocalizedStringKey
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
    let title: LocalizedStringKey
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
    var title: LocalizedStringKey = "Add"
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
    let title: LocalizedStringKey
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
    let text: LocalizedStringKey
    /// The chevron says "there is a menu under this". A link that just does
    /// the thing — Cancel — asks for `chevron: false`, or it promises a list
    /// that never opens.
    var chevron = true
    init(_ text: LocalizedStringKey, chevron: Bool = true) {
        self.text = text
        self.chevron = chevron
    }
    var body: some View {
        HStack(spacing: 2) {
            Text(text)
            if chevron { Image(systemName: "chevron.down").font(Organic.glyph) }
        }
        .font(Organic.captionStrong).foregroundStyle(Organic.accent)
    }
}
