import SwiftUI

// Organic design system — tokens lifted verbatim from styles.css.
// Do not introduce colors outside these ramps.

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 6 { s += "ff" }
        let v = UInt32(s, radix: 16) ?? 0
        self.init(.sRGB,
                  red: Double((v >> 24) & 0xff) / 255,
                  green: Double((v >> 16) & 0xff) / 255,
                  blue: Double((v >> 8) & 0xff) / 255,
                  opacity: Double(v & 0xff) / 255)
    }
}

enum Organic {
    // roles
    static let bg = Color(hex: "f5ead8")
    static let surface = Color(hex: "ebddc5")
    static let text = Color(hex: "201e1d")
    static let accent = Color(hex: "c67139")
    static let accent2 = Color(hex: "7a8a5e")

    // neutral ramp
    static let n100 = Color(hex: "f9f4ed")
    static let n200 = Color(hex: "eee7db")
    static let n300 = Color(hex: "dcd3c4")
    static let n400 = Color(hex: "c0b6a5")
    static let n500 = Color(hex: "a19786")
    static let n600 = Color(hex: "82796a")
    static let n700 = Color(hex: "645c50")
    static let n800 = Color(hex: "474238")
    static let n900 = Color(hex: "2e2b25")

    // accent ramp (terracotta)
    static let a100 = Color(hex: "fff2eb")
    static let a200 = Color(hex: "ffe1d0")
    static let a300 = Color(hex: "ffc6a5")
    static let a400 = Color(hex: "f6a06b")
    static let a500 = Color(hex: "d67f48")
    static let a600 = Color(hex: "b2622d")
    static let a700 = Color(hex: "8c491a")
    static let a800 = Color(hex: "643312")
    static let a900 = Color(hex: "402310")

    // second accent ramp (sage)
    static let s100 = Color(hex: "f0fae1")
    static let s200 = Color(hex: "e1eecc")
    static let s300 = Color(hex: "ccdbb2")
    static let s400 = Color(hex: "aebf92")
    static let s500 = Color(hex: "8fa073")
    static let s600 = Color(hex: "728157")
    static let s700 = Color(hex: "56633f")
    static let s800 = Color(hex: "3d472b")
    static let s900 = Color(hex: "272e1b")

    // radii — the HTML uses 20-22 for cards, 18 for inner blocks, 999 for pills
    static let rCard: CGFloat = 20
    static let rInner: CGFloat = 18
    static let rSmall: CGFloat = 12

    // display face. Caprasimo must be added to the target and registered in
    // Info.plist (UIAppFonts). Body copy is the system font.
    static func display(_ size: CGFloat) -> Font { .custom("Caprasimo-Regular", size: size) }
}

// MARK: - Reusable chrome

/// The pill chip used everywhere for single-select rows (owner, card, channel, category).
struct Chip: View {
    let label: String
    let selected: Bool
    var tint: Color = Organic.n900
    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(selected ? tint : Organic.n200)
            .foregroundStyle(selected ? Organic.bg : Organic.n700)
            .clipShape(Capsule())
    }
}

/// Section header with the round + button used on Wallet (wallets, cards, owners).
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var isOpen: Bool = false
    var onAdd: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.system(size: 14, weight: .heavy))
                Spacer()
                if let onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .heavy))
                            .frame(width: 30, height: 30)
                            .background(Organic.accent, in: Circle())
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(isOpen ? 45 : 0))
                    }
                    .animation(.easeOut(duration: 0.18), value: isOpen)
                }
            }
            if let subtitle {
                Text(subtitle).font(.system(size: 11.5)).foregroundStyle(Organic.n600)
            }
        }
        .padding(.horizontal, 2)
    }
}

/// Cream card container. Every list block in the app sits in one of these.
struct Card<Content: View>: View {
    var fill: Color = Organic.n100
    var padding: EdgeInsets = EdgeInsets(top: 13, leading: 15, bottom: 13, trailing: 15)
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: Organic.rCard, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
    }
}

/// Full-width primary action (Save, Add wallet, Copy everything…).
struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon { Image(systemName: icon).font(.system(size: 14, weight: .heavy)) }
                Text(title).font(.system(size: 14, weight: .heavy))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(Organic.accent, in: Capsule())
            .foregroundStyle(.white)
        }
    }
}
