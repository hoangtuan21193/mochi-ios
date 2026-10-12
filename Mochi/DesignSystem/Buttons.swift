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
            .frame(maxWidth: .infinity, minHeight: Organic.buttonHeight)
            .background(Organic.accentFill, in: RoundedRectangle(cornerRadius: Organic.rInner, style: .continuous))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
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
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(fill, in: RoundedRectangle(cornerRadius: Organic.rInner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Organic.rInner, style: .continuous)
                .stroke(style == .warm ? .clear : Organic.n400, lineWidth: Organic.stroke))
            .foregroundStyle(foreground)
        }
        .buttonStyle(.plain)
    }
    private var fill: Color {
        switch style {
        case .quiet: return Organic.n100
        case .warm: return Organic.a100
        // Only the border: on the page or on a card, the ground shows through.
        case .outlined: return .clear
        }
    }
    private var foreground: Color {
        switch style {
        case .quiet: return Organic.text
        case .warm: return Organic.a800
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
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Organic.a100, in: RoundedRectangle(cornerRadius: Organic.rInner, style: .continuous))
                .foregroundStyle(Organic.a700)
        }
    }
}

/// The one way to say "add" in this app: a round +, never a full-width button.
/// It turns into an × while its form is open.
struct AddButton: View {
    var isOpen: Bool = false
    var fill: Color = Organic.n900
    var stroke: Color = .clear
    var symbol: Color = Organic.bg
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(Organic.rowValue)
                .frame(width: 34, height: 34)
                .background(fill, in: Circle())
                .overlay(Circle().stroke(stroke, lineWidth: Organic.stroke))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
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
                .background(Organic.accent, in: RoundedRectangle(cornerRadius: Organic.rSmall, style: .continuous))
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
                .frame(width: 40, height: 40)
                .background(filled ? Organic.n900 : Organic.n100, in: Circle())
                .overlay(Circle().stroke(filled ? .clear : Organic.n300, lineWidth: Organic.stroke))
                .foregroundStyle(filled ? Organic.bg : Organic.text)
                .frame(width: 44, height: 44)
        }
    }
}

/// `IconButton`'s circle opening a menu: the few things a screen keeps in
/// reach but out of the way (Belongings' warranties and categories).
struct IconMenu<Items: View>: View {
    var symbol = "ellipsis"
    let label: LocalizedStringKey
    @ViewBuilder var items: () -> Items
    var body: some View {
        Menu { items() } label: {
            Image(systemName: symbol).font(Organic.rowValue)
                .frame(width: 40, height: 40)
                .background(Organic.n100, in: Circle())
                .overlay(Circle().stroke(Organic.n300, lineWidth: Organic.stroke))
                .foregroundStyle(Organic.text)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(Text(label))
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

/// A site opened in Safari, as an outlined pill with the leave-the-app
/// arrow: Buy advice's sold-price searches. What the site shows changes
/// nothing in the book until it is typed in.
struct ExternalLinkButton: View {
    let title: String
    let url: URL
    var body: some View {
        Link(destination: url) {
            HStack(spacing: 4) {
                Text(verbatim: title).font(Organic.captionStrong).lineLimit(1)
                Image(systemName: "arrow.up.forward.square").font(Organic.glyph)
            }
            .padding(.horizontal, Organic.Space.m).frame(minHeight: 36)
            .background(Organic.n100, in: RoundedRectangle(cornerRadius: Organic.rSmall, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Organic.rSmall, style: .continuous).stroke(Organic.n400, lineWidth: Organic.stroke))
            .foregroundStyle(Organic.text)
        }
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

/// An eye beside a figure's label that hides the figure — for opening the
/// app on a train or with someone looking over a shoulder. No circle: it sits
/// in a caption line and must not compete with the figure it hides.
struct HideFiguresButton: View {
    @Binding var hidden: Bool
    var body: some View {
        Button { hidden.toggle() } label: {
            Image(systemName: hidden ? "eye.slash" : "eye").font(Organic.captionStrong)
                .foregroundStyle(Organic.n600)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -14)
        .accessibilityLabel(hidden ? Text("Show amounts") : Text("Hide amounts"))
    }
}

/// A round button over the camera picture: close, flash. Always on the dark
/// camera palette.
struct CameraRoundButton: View {
    let symbol: String
    let label: LocalizedStringKey
    var on = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(Organic.title)
                .frame(width: Organic.Camera.controlSize, height: Organic.Camera.controlSize)
                .background(on ? Organic.Camera.ink : Organic.Camera.control, in: Circle())
                .foregroundStyle(on ? Organic.Camera.bg : Organic.Camera.ink)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// The camera's shutter: a white disc in a white ring, the one thing on the
/// screen that keeps the photo.
struct ShutterButton: View {
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Circle().fill(Organic.Camera.ink)
                .padding(8)
                .overlay(Circle().stroke(Organic.Camera.ink, lineWidth: 4))
                .frame(width: Organic.Camera.shutterSize, height: Organic.Camera.shutterSize)
                .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(Text("Use this photo"))
    }
}

/// The label of a text button in the camera tray: "Photos", "Type instead".
/// A label rather than a button so a `PhotosPicker` can wear it too.
struct CameraTrayLabel: View {
    let title: LocalizedStringKey
    var symbol: String? = nil
    var body: some View {
        HStack(spacing: Organic.Space.s) {
            if let symbol { Image(systemName: symbol) }
            Text(title).lineLimit(1).minimumScaleFactor(0.8)
        }
        .font(Organic.valueStrong)
        .foregroundStyle(Organic.Camera.ink)
        .frame(width: 104, height: Organic.Camera.controlSize)
        .background(Organic.Camera.chip, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
