import SwiftUI

// Mochi design system — tokens. The single place a colour, font, radius or
// spacing value is allowed to be written as a number. Views use the names.
// See design.md for the rules; CLAUDE.md for what a change here must go through.
//
// The namespace is still called `Organic` so no view had to change its calls
// when the look did: a neutral ground, white cards with a thin border, ink
// text and one warm accent. Every colour has a light and a dark value and
// resolves against the trait of whatever draws it.

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// One colour for light and one for dark, resolved by the system.
    static func dynamic(_ light: String, _ dark: String) -> Color {
        Color(uiColor: UIColor.dynamic(light, dark))
    }
}

extension UIColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        if s.count == 6 { s += "ff" }
        let v = UInt32(s, radix: 16) ?? 0
        self.init(red: CGFloat((v >> 24) & 0xff) / 255,
                  green: CGFloat((v >> 16) & 0xff) / 255,
                  blue: CGFloat((v >> 8) & 0xff) / 255,
                  alpha: CGFloat(v & 0xff) / 255)
    }

    static func dynamic(_ light: String, _ dark: String) -> UIColor {
        let l = UIColor(hex: light), d = UIColor(hex: dark)
        return UIColor { $0.userInterfaceStyle == .dark ? d : l }
    }
}

enum Organic {

    // MARK: Colour roles

    /// The page.
    static let bg = Color.dynamic("F4F3F0", "111113")
    /// A block inside a card, a segmented track.
    static let surface = Color.dynamic("F0EEEA", "2A2A2F")
    /// Ink.
    static let text = Color.dynamic("18181B", "F2F1EE")
    /// The one primary action, the active tab, links.
    static let accent = Color.dynamic("C2461A", "F08A5D")
    /// The accent as a fill under white text: the same in both themes,
    /// because the lighter dark-mode accent is too pale for white on it.
    static let accentFill = Color.dynamic("C2461A", "C2461A")
    /// The chosen segment of a `SegmentedTabs`, raised above its track: white
    /// on light, a lighter grey on dark. `n100` read darker than the track in
    /// dark mode, so the choice looked inverted.
    static let raised = Color.dynamic("FFFFFF", "3A3A40")
    /// Information and belongings: blue.
    static let accent2 = Color.dynamic("2361C9", "7AA7FF")

    // MARK: Neutral ramp — card to ink

    /// Cards.
    static let n100 = Color.dynamic("FFFFFF", "1C1C1F")
    /// Quiet fills: an unselected chip, a thumbnail, a track.
    static let n200 = Color.dynamic("F0EEEA", "2A2A2F")
    /// Card borders, hairlines.
    static let n300 = Color.dynamic("E4E2DD", "2C2C31")
    /// Field borders.
    static let n400 = Color.dynamic("D7D4CC", "3A3A40")
    /// Chevrons, disabled.
    static let n500 = Color.dynamic("9A98A0", "6E6C75")
    /// Secondary text.
    static let n600 = Color.dynamic("5F5E66", "A3A1AA")
    static let n700 = Color.dynamic("46454C", "C9C7CF")
    static let n800 = Color.dynamic("2E2D33", "E0DEE3")
    /// Ink, and the selected chip's fill.
    static let n900 = Color.dynamic("18181B", "F2F1EE")

    // MARK: Warm ramp — debt, money going out, destructive, the accent

    static let a100 = Color.dynamic("FBE9E1", "3A2118")
    static let a200 = Color.dynamic("F8D8C8", "4A2A1D")
    static let a300 = Color.dynamic("F0A988", "C97556")
    static let a400 = Color.dynamic("E57E55", "E08A66")
    static let a500 = Color.dynamic("D25E2E", "EE8B62")
    static let a600 = Color.dynamic("C2461A", "F08A5D")
    /// Owed, due, short: the red a figure is printed in.
    static let a700 = Color.dynamic("B3261E", "FF7A6E")
    static let a800 = Color.dynamic("8E1F18", "FF9A90")
    static let a900 = Color.dynamic("5C1510", "FFC5BE")

    // MARK: Green ramp — money in, settled, "cash covers it"

    static let s100 = Color.dynamic("E3F2E9", "16301F")
    static let s200 = Color.dynamic("C8E6D3", "1F4029")
    static let s300 = Color.dynamic("8FD1A9", "5FD394")
    static let s400 = Color.dynamic("5DB283", "5FD394")
    static let s500 = Color.dynamic("3A9464", "5FD394")
    static let s600 = Color.dynamic("2A8456", "5FD394")
    static let s700 = Color.dynamic("1E7A4A", "5FD394")
    static let s800 = Color.dynamic("14502F", "8BE3B0")
    static let s900 = Color.dynamic("0B3A20", "C2F0D5")

    // MARK: Information and caution

    /// Belongings, a place you have been, "not spending".
    static let info = Color.dynamic("2361C9", "7AA7FF")
    static let infoSoft = Color.dynamic("E6EEFB", "17243D")
    /// Text on `infoSoft`: darker than `info` so a whole sentence reads.
    static let infoInk = Color.dynamic("1D3A6E", "B9C8E6")
    /// A field the scan was not sure of; something to look at.
    static let warn = Color.dynamic("9A6400", "E9B64A")
    static let warnSoft = Color.dynamic("FFF4D6", "3A2E10")
    static let warnInk = Color.dynamic("5C3D00", "F2CF7E")
    /// Something that fails unless you act: a debit an account cannot pay.
    static let alertSoft = Color.dynamic("FBE4E1", "3A1A17")
    static let alertInk = Color.dynamic("8A1C14", "FFB4AB")

    /// Chart colours, in order. Each differs in lightness as well as hue, so
    /// two neighbours can be told apart without colour vision.
    static let chart: [Color] = [
        .dynamic("2F6FDB", "5B8DEF"), .dynamic("E0A21B", "E0A21B"), .dynamic("1F9E8F", "2BB8A6"),
        .dynamic("D9577E", "E77A9B"), .dynamic("3F8F3A", "5DB257"), .dynamic("7B61D6", "9B85EA"),
        .dynamic("B8B5AE", "7A7880"), .dynamic("8C6A43", "B99368"), .dynamic("0E7490", "38A3C4"),
    ]
    static func chartColor(_ index: Int) -> Color { chart[((index % chart.count) + chart.count) % chart.count] }

    /// The receipt camera. Always dark, whatever the phone is set to: it sits
    /// over a live picture, and a white tray there would glare and hide the
    /// paper's edges.
    enum Camera {
        static let bg = Color(hex: "111113")
        /// The tray at the bottom: what was found, and the shutter.
        static let tray = Color(hex: "1C1C1F")
        /// Round buttons and the pill over the picture.
        static let control = Color.white.opacity(0.14)
        /// A found chip, a text button in the tray.
        static let chip = Color.white.opacity(0.10)
        static let ink = Color.white
        static let quiet = Color(hex: "B9B8BF")
        /// The tick on a field that has been read.
        static let found = Color(hex: "7FD4A3")
        /// The viewfinder corners and the outline round each line read.
        static let frame = Color(hex: "F0874F")
        static let trayRadius: CGFloat = 22
        static let controlSize: CGFloat = 44
        static let shutterSize: CGFloat = 72
    }

    // MARK: Type scale
    //
    // The system face throughout: it has every kana, kanji and Vietnamese tone
    // mark, and figures that line up (`monospacedDigit`). `.font(.system(size:))`
    // is not written outside this file.

    /// The one number a screen is about. At most one per screen.
    static let hero = Font.system(size: 36, weight: .bold).monospacedDigit()
    /// Screen titles.
    static let screenTitle = Font.system(size: 28, weight: .bold)
    /// Card titles, section headers, sheet headings.
    static let title = Font.system(size: 15, weight: .semibold)
    /// A figure in a tile.
    static let statValue = Font.system(size: 20, weight: .semibold).monospacedDigit()
    /// Paragraph text, field text.
    static let body = Font.system(size: 14, weight: .regular)
    /// A list row's label.
    static let row = Font.system(size: 14, weight: .medium)
    /// A list row's figure; also every button label.
    static let rowValue = Font.system(size: 14, weight: .semibold).monospacedDigit()
    /// Secondary figures and chip text.
    static let value = Font.system(size: 13, weight: .regular)
    static let valueStrong = Font.system(size: 13, weight: .semibold)
    /// Help text, sublines.
    static let caption = Font.system(size: 12, weight: .regular)
    static let captionStrong = Font.system(size: 12, weight: .semibold)
    /// Labels over a value, notes, dates.
    static let meta = Font.system(size: 11, weight: .regular)
    static let metaStrong = Font.system(size: 11, weight: .semibold)
    /// Uppercase tags: SOLD, MAY SELL.
    static let badge = Font.system(size: 10, weight: .bold)
    /// Small symbols inside controls (chevrons, arrows).
    static let glyph = Font.system(size: 10, weight: .semibold)
    /// Receipt text and column examples — data that has to line up.
    static let mono = Font.system(size: 12, design: .monospaced)

    /// UIKit twins of `body` and `title`, for the one UIKit-backed field
    /// (`MoneyField`). Same sizes, same weights; a mismatch would show as a
    /// field that sits a hair off its neighbours.
    static let bodyUI = UIFont.systemFont(ofSize: 14, weight: .regular)
    static let titleUI = UIFont.systemFont(ofSize: 15, weight: .semibold)
    /// The hero figure typed in place (`MoneyField(style: .hero)`): the same
    /// size and weight as `hero`, figures lined up.
    static let heroUI: UIFont = {
        let base = UIFont.systemFont(ofSize: 36, weight: .bold)
        let digits = base.fontDescriptor.addingAttributes([.featureSettings: [[
            UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
            UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector]]])
        return UIFont(descriptor: digits, size: 36)
    }()

    /// The operator row `MoneyField` puts above the number pad. It is drawn
    /// as one more keyboard panel — the keyboard's greys, the keyboard's key
    /// shape — so the eye reads it as keys, not as app chrome. Colours are
    /// dynamic: they resolve against the keyboard's own light or dark trait.
    enum Keypad {
        static let keyHeight: CGFloat = 46
        static let keyRadius: CGFloat = 10
        static let gap: CGFloat = 6
        static let margin: CGFloat = 6
        /// All four corners: the row is its own panel, floating above the keyboard.
        static let panelRadius: CGFloat = 22
        /// Space between the row and the keyboard proper.
        static let lift: CGFloat = 8
        static let keyFont = UIFont.systemFont(ofSize: 22, weight: .regular)

        /// The system keyboard's panel and key greys, light and dark. UIKit
        /// does not expose them, so they are copied here.
        static let panel = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1)
            : UIColor(red: 0.87, green: 0.875, blue: 0.895, alpha: 1) }
        static let key = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.42, green: 0.42, blue: 0.43, alpha: 1)
            : .white }
        static let keyPressed = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.28, green: 0.28, blue: 0.29, alpha: 1)
            : UIColor(red: 0.72, green: 0.73, blue: 0.76, alpha: 1) }
    }

    /// Big numbers on sheets and cards. Kept as a function so the call sites
    /// that asked for "display at this size" still read that way; the face is
    /// the system's, bold, with figures that line up.
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold).monospacedDigit()
    }

    // MARK: Radii

    /// Cards.
    static let rCard: CGFloat = 16
    /// Tiles, buttons, blocks inside a card.
    static let rInner: CGFloat = 14
    /// Fields, callout strips.
    static let rSmall: CGFloat = 10

    // MARK: Spacing
    //
    // 16 is the screen gutter and the gap between cards is 12; inside a card,
    // 8 between controls, 10 for a row.

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 6
        static let m: CGFloat = 8
        static let row: CGFloat = 10
        static let l: CGFloat = 12
        static let card: CGFloat = 16
        static let gutter: CGFloat = 16
    }

    // MARK: Chrome

    /// Card and field borders.
    static let stroke: CGFloat = 1
    /// A selected chip's border.
    static let strokeStrong: CGFloat = 1.5
    /// Tallest touch target the app draws: primary buttons.
    static let buttonHeight: CGFloat = 52

    // MARK: UIKit bridging

    /// Titles in the navigation bar follow the page: transparent at rest,
    /// the page colour once anything has scrolled beneath it.
    static func applyNavigationBarAppearance() {
        let atRest = UINavigationBarAppearance()
        atRest.configureWithTransparentBackground()
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithOpaqueBackground()
        scrolled.backgroundColor = UIColor.dynamic("F4F3F0", "111113")
        scrolled.shadowColor = .clear
        let ink = UIColor.dynamic("18181B", "F2F1EE")
        for appearance in [atRest, scrolled] {
            appearance.largeTitleTextAttributes = [.font: UIFont.systemFont(ofSize: 30, weight: .bold), .foregroundColor: ink]
            appearance.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 17, weight: .semibold), .foregroundColor: ink]
        }
        UINavigationBar.appearance().standardAppearance = scrolled
        UINavigationBar.appearance().compactAppearance = scrolled
        UINavigationBar.appearance().scrollEdgeAppearance = atRest
        UINavigationBar.appearance().tintColor = UIColor.dynamic("C2461A", "E0602F")
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
