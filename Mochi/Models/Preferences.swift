import Foundation

// MARK: - Preferences

/// The money the book is kept in. Raw value is the symbol, because that is
/// what `AppData.currency` has always stored on disk.
enum Currency: String, CaseIterable, Identifiable {
    case jpy = "¥", vnd = "₫", usd = "$", eur = "€"

    var id: String { rawValue }
    var symbol: String { rawValue }
    var code: String {
        switch self {
        case .jpy: return "JPY"
        case .vnd: return "VND"
        case .usd: return "USD"
        case .eur: return "EUR"
        }
    }
    /// A `String.LocalizationValue`, not a `LocalizedStringKey`: the name is
    /// shown on its own *and* embedded in a sentence, and only this one can be
    /// resolved to a `String` to be embedded.
    var name: String.LocalizationValue {
        switch self {
        case .jpy: return "Japanese yen"
        case .vnd: return "Vietnamese đồng"
        case .usd: return "US dollar"
        case .eur: return "Euro"
        }
    }
    /// Đồng is written after the number ("5,000,000 ₫"); the others before.
    var symbolTrails: Bool { self == .vnd }

    /// Looks a currency up by its ISO code ("JPY"); loans store the code, not the symbol.
    init?(code: String) {
        guard let match = Currency.allCases.first(where: { $0.code == code }) else { return nil }
        self = match
    }

    /// "¥12,000" / "-12,000 ₫". Grouping follows the device locale, like every
    /// other figure in the app. `Store.format` is this for the book's currency.
    func format(_ amount: Int) -> String {
        let sign = amount < 0 ? "-" : ""
        let n = abs(amount).formatted(.number.grouping(.automatic))
        return symbolTrails ? "\(sign)\(n) \(symbol)" : "\(sign)\(symbol)\(n)"
    }

    /// "+¥123,456" / "-¥123,456" / "¥0" — for a figure whose direction is the
    /// point (a flow, a change), where a bare positive number would read as
    /// a balance.
    func signed(_ amount: Int) -> String {
        amount > 0 ? "+" + format(amount) : format(amount)
    }
}

/// UI language. Applied through `AppleLanguages`, the way iOS itself picks a
/// per-app language, so it takes effect on the next launch and reaches every
/// system-formatted date and number as well as the app's own strings.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, en, vi, ja

    var id: String { rawValue }
    /// Each language is named in itself — that is how a person finds their own
    /// in a list they cannot otherwise read — so only "Follow device" is copy.
    var name: String.LocalizationValue {
        switch self {
        case .system: return "Follow device"
        case .en: return "English"
        case .vi: return "Tiếng Việt"
        case .ja: return "日本語"
        }
    }
    /// The identifier handed to `AppleLanguages`; nil clears the override.
    var localeIdentifier: String? { self == .system ? nil : rawValue }
}
