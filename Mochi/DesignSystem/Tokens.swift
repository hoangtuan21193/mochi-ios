import SwiftUI

// Organic design system — tokens. The single place a colour, font, radius or
// spacing value is allowed to be written as a number. Views use the names.
// See design.md for the rules; CLAUDE.md for what a change here must go through.

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

    // MARK: Colour roles

    static let bg = Color(hex: "f5ead8")
    static let surface = Color(hex: "ebddc5")
    static let text = Color(hex: "201e1d")
    static let accent = Color(hex: "c67139")
    static let accent2 = Color(hex: "7a8a5e")

    // MARK: Neutral ramp — ink and paper

    static let n100 = Color(hex: "f9f4ed")
    static let n200 = Color(hex: "eee7db")
    static let n300 = Color(hex: "dcd3c4")
    static let n400 = Color(hex: "c0b6a5")
    static let n500 = Color(hex: "a19786")
    static let n600 = Color(hex: "82796a")
    static let n700 = Color(hex: "645c50")
    static let n800 = Color(hex: "474238")
    static let n900 = Color(hex: "2e2b25")

    // MARK: Accent ramp (terracotta) — debt, urgency, destructive, "new"

    static let a100 = Color(hex: "fff2eb")
    static let a200 = Color(hex: "ffe1d0")
    static let a300 = Color(hex: "ffc6a5")
    static let a400 = Color(hex: "f6a06b")
    static let a500 = Color(hex: "d67f48")
    static let a600 = Color(hex: "b2622d")
    static let a700 = Color(hex: "8c491a")
    static let a800 = Color(hex: "643312")
    static let a900 = Color(hex: "402310")

    // MARK: Second accent ramp (sage) — money in, settled, safe

    static let s100 = Color(hex: "f0fae1")
    static let s200 = Color(hex: "e1eecc")
    static let s300 = Color(hex: "ccdbb2")
    static let s400 = Color(hex: "aebf92")
    static let s500 = Color(hex: "8fa073")
    static let s600 = Color(hex: "728157")
    static let s700 = Color(hex: "56633f")
    static let s800 = Color(hex: "3d472b")
    static let s900 = Color(hex: "272e1b")

    // MARK: Type scale
    //
    // Seven sizes and no more: 15 / 13 / 12 / 11 / 10.5 / 9, plus the display
    // face. Half-point differences do not read as hierarchy, they read as a
    // mistake. `.font(.system(size:))` is not written outside this file.

    /// The one number a screen is about. At most one per screen.
    static let hero = Font.system(size: 32, weight: .heavy)
    /// Card titles, section headers, sheet headings.
    static let title = Font.system(size: 15, weight: .heavy)
    /// A stat's number in a hero or tile — bigger than a row value, smaller than the hero.
    static let statValue = Font.system(size: 16, weight: .heavy)
    /// Paragraph text, field text.
    static let body = Font.system(size: 13, weight: .regular)
    /// A list row's label.
    static let row = Font.system(size: 13, weight: .semibold)
    /// A list row's figure; also every button label.
    static let rowValue = Font.system(size: 13, weight: .heavy)
    /// Secondary figures and chip text.
    static let value = Font.system(size: 12, weight: .regular)
    static let valueStrong = Font.system(size: 12, weight: .heavy)
    /// Help text under a title, warnings, sublines.
    static let caption = Font.system(size: 11, weight: .regular)
    static let captionStrong = Font.system(size: 11, weight: .semibold)
    /// Labels over a value, notes, dates.
    static let meta = Font.system(size: 10.5, weight: .regular)
    static let metaStrong = Font.system(size: 10.5, weight: .bold)
    /// Uppercase tags: SOLD, NEW, CASH.
    static let badge = Font.system(size: 9, weight: .bold)
    /// Small symbols inside controls (chevrons, arrows).
    static let glyph = Font.system(size: 9, weight: .heavy)
    /// Sheet previews and column examples — data that has to line up.
    static let mono = Font.system(size: 11, design: .monospaced)

    /// Display face for hero numbers and screen titles. Caprasimo must be in the
    /// target and in Info.plist (UIAppFonts). It has no Vietnamese glyphs.
    static func display(_ size: CGFloat) -> Font { .custom("Caprasimo-Regular", size: size) }

    // MARK: Radii

    /// Cards and the hero.
    static let rCard: CGFloat = 20
    /// Blocks inside a card (a form group, a tile).
    static let rInner: CGFloat = 18
    /// Small callouts inside a block.
    static let rSmall: CGFloat = 12

    // MARK: Spacing
    //
    // Padding and spacing come from here. 16 is the screen gutter and the gap
    // between cards is 12; inside a card, 8 between controls, 10 for a row.

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 6
        static let m: CGFloat = 8
        static let row: CGFloat = 10
        static let l: CGFloat = 12
        static let card: CGFloat = 13
        static let gutter: CGFloat = 16
    }

    // MARK: Chrome

    /// Stroke on fields and outlined buttons.
    static let stroke: CGFloat = 1.5

    // MARK: UIKit bridging

    /// UIKit surfaces the app does not draw itself — alerts, date pickers, the
    /// keyboard, sheet grabbers — follow the window, not SwiftUI's
    /// `preferredColorScheme`. This pins the window to light so they match.
    static func pinInterfaceStyleToLight() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows { window.overrideUserInterfaceStyle = .light }
        }
    }

    /// Screen titles are display type too. UIKit owns the navigation bar, so the
    /// face has to be pushed through UINavigationBarAppearance once at launch.
    /// No-ops if Caprasimo is missing from the bundle — the system face stands in.
    static func applyNavigationBarAppearance() {
        // Two appearances, not one. A transparent bar everywhere lets cards
        // scroll under the status bar unreadable; a solid one at rest would put
        // a hard edge under the large title. Transparent at the top, the page
        // colour once anything has scrolled beneath it.
        let atRest = UINavigationBarAppearance()
        atRest.configureWithTransparentBackground()
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithOpaqueBackground()
        scrolled.backgroundColor = UIColor(bg)
        scrolled.shadowColor = .clear

        if let large = UIFont(name: "Caprasimo-Regular", size: 32),
           let inline = UIFont(name: "Caprasimo-Regular", size: 17) {
            for appearance in [atRest, scrolled] {
                appearance.largeTitleTextAttributes = [.font: large, .foregroundColor: UIColor(text)]
                appearance.titleTextAttributes = [.font: inline, .foregroundColor: UIColor(text)]
            }
        }
        UINavigationBar.appearance().standardAppearance = scrolled
        UINavigationBar.appearance().compactAppearance = scrolled
        UINavigationBar.appearance().scrollEdgeAppearance = atRest
    }
}

/// Joins the parts that have something in them with the app's " · ". A blank
/// field must take its separator with it — a row reading "· Mercari" looks like
/// a bug, and after an import half the items have no card at all.
func metaLine(_ parts: String...) -> String {
    parts.map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
}
