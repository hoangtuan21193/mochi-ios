import SwiftUI

// MARK: - Fields

/// The capsule text field used by every form in the app. Wrap any field, or
/// use the convenience init for a plain TextField with proper-noun-safe input.
struct FormField<V: View>: View {
    @ViewBuilder var field: V
    var body: some View {
        field.font(Organic.body)
            .padding(.horizontal, Organic.Space.l).frame(minHeight: 44)
            .background(Organic.n100, in: RoundedRectangle(cornerRadius: Organic.rSmall, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Organic.rSmall, style: .continuous).stroke(Organic.n400, lineWidth: Organic.stroke))
    }
}

extension FormField where V == AnyView {
    /// A text field. Autocorrect is off: model names, shops and lenders are
    /// proper nouns the keyboard "fixes" into nonsense.
    init(_ placeholder: LocalizedStringKey, text: Binding<String>, numeric: Bool = false, decimal: Bool = false) {
        self.init {
            AnyView(
                TextField(placeholder, text: text)
                    .keyboardType(numeric ? .numberPad : (decimal ? .decimalPad : .default))
                    .autocorrectionDisabled()
            )
        }
    }
}

/// The one search field: a magnifier, what was typed, and a × that clears it.
/// It is the same `FormField` capsule as every other field, so a screen that
/// searches looks like a screen that types. Autocorrect and capitalisation are
/// off for the reason `FormField` turns them off — what gets typed here is
/// "200mm f2.8", not a sentence.
struct SearchField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    /// Takes the keyboard as soon as it appears — for a field that only exists
    /// because it was asked for, which is one tap already spent.
    var autofocus = false

    @FocusState private var focused: Bool

    init(_ placeholder: LocalizedStringKey, text: Binding<String>, autofocus: Bool = false) {
        self.placeholder = placeholder
        self._text = text
        self.autofocus = autofocus
    }

    var body: some View {
        FormField {
            HStack(spacing: Organic.Space.s) {
                Image(systemName: "magnifyingglass")
                    .font(Organic.captionStrong).foregroundStyle(Organic.n500)
                TextField(placeholder, text: $text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .focused($focused)
                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(Organic.captionStrong).foregroundStyle(Organic.n400)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear { if autofocus { focused = true } }
    }
}

/// The search field docked to the bottom of a screen, for
/// `.safeAreaInset(edge: .bottom)`. It rides up with the keyboard the way the
/// search bar in Mail does, which is the point: a screen only gives up room
/// for searching while something is being looked for, and the field ends up
/// next to the thumb rather than at the top of a list.
/// `note` is said under it — what the screen's other filters are hiding — and
/// Cancel is the way back out.
struct SearchDock: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var note: LocalizedStringKey? = nil
    let onCancel: () -> Void

    init(_ placeholder: LocalizedStringKey, text: Binding<String>,
         note: LocalizedStringKey? = nil, onCancel: @escaping () -> Void) {
        self.placeholder = placeholder
        self._text = text
        self.note = note
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Organic.Space.s) {
            HStack(spacing: Organic.Space.m) {
                SearchField(placeholder, text: $text, autofocus: true)
                Button(action: onCancel) { LinkLabel("Cancel", chevron: false) }
                    .buttonStyle(.plain)
            }
            if let note { HelpText(note) }
        }
        .padding(.horizontal, Organic.Space.gutter)
        .padding(.vertical, Organic.Space.m)
        .background(Organic.n100)
        .overlay(alignment: .top) { Hairline() }
    }
}

/// The amount field. Digits group themselves as they are typed (12000 →
/// 12,000), the currency symbol sits in the capsule, and + − × ÷ are evaluated
/// live, so "three lenses at 12,000 less the 1,500 fee" is typed the way it is
/// thought instead of on a calculator first. While the field has focus a row
/// of keyboard-styled keys, `+ − × ÷ =`, sits just above the number pad;
/// `=` settles the sum and puts the keyboard away, standing in for Done.
///
/// Binds to the number, not the text: callers never parse. `nil` is blank;
/// the `Binding<Int>` init treats 0 as blank so an empty form starts empty.
/// Reads `Store` from the environment for the book's currency (`.book`).
struct MoneyField: View {
    /// What the number is in. `.book` is the book's currency; `.currency` for
    /// a loan kept in another one; `.suffix("pt")` for points; `.none` for a
    /// plain count.
    enum Unit { case book, currency(Currency), suffix(String), none }

    /// Resolved on the way in. The field itself is a `UITextField`, whose
    /// `placeholder` is a plain `String`, so the translation has to be looked
    /// up here rather than handed to SwiftUI to look up later.
    let placeholder: String
    /// Held as a `Double` so a foreign figure keeps its cents; the `Int`
    /// inits round, and with `fractionDigits` 0 nothing but whole numbers
    /// can be typed anyway.
    @Binding var value: Double?
    var unit: Unit = .book
    /// Digits allowed after the decimal mark: 0 for yen and đồng, 2 for a
    /// dollar paid abroad (`Currency.fractionDigits(_:)`).
    var fractionDigits = 0
    /// Title-sized text — the sell planner's figures are the point of its card.
    var prominent = false
    var alignment: TextAlignment = .leading
    /// `.field` is the capsule every form uses. `.hero` is the figure a
    /// screen is about, typed in place: large and bold, no capsule, a small
    /// pencil beside it to say it can be changed (a scanned receipt's total).
    enum Style { case field, hero }
    var style: Style = .field

    @Environment(Store.self) private var store
    @State private var text = ""
    @State private var focused = false

    init(_ placeholder: String.LocalizationValue, value: Binding<Int?>, unit: Unit = .book,
         prominent: Bool = false, alignment: TextAlignment = .leading, style: Style = .field) {
        self.init(exact: placeholder,
                  value: Binding(get: { value.wrappedValue.map(Double.init) },
                                 set: { value.wrappedValue = $0.map { Int($0.rounded()) } }),
                  unit: unit, fractionDigits: 0, prominent: prominent, alignment: alignment, style: style)
    }

    /// A figure with a fractional part — what was paid in another currency.
    init(_ placeholder: String.LocalizationValue, value: Binding<Double>, unit: Unit = .book, fractionDigits: Int,
         prominent: Bool = false, alignment: TextAlignment = .leading, style: Style = .field) {
        self.init(exact: placeholder,
                  value: Binding(get: { value.wrappedValue == 0 ? nil : value.wrappedValue },
                                 set: { value.wrappedValue = $0 ?? 0 }),
                  unit: unit, fractionDigits: fractionDigits, prominent: prominent, alignment: alignment, style: style)
    }

    private init(exact placeholder: String.LocalizationValue, value: Binding<Double?>, unit: Unit, fractionDigits: Int,
                 prominent: Bool, alignment: TextAlignment, style: Style) {
        self.placeholder = String(localized: placeholder)
        self._value = value
        self.unit = unit
        self.fractionDigits = fractionDigits
        self.prominent = prominent
        self.alignment = alignment
        self.style = style
    }

    init(_ placeholder: String.LocalizationValue, value: Binding<Int>, unit: Unit = .book,
         prominent: Bool = false, alignment: TextAlignment = .leading, style: Style = .field) {
        self.init(placeholder,
                  value: Binding(get: { value.wrappedValue == 0 ? nil : value.wrappedValue },
                                 set: { value.wrappedValue = $0 ?? 0 }),
                  unit: unit, prominent: prominent, alignment: alignment, style: style)
    }

    var body: some View {
        Group {
            switch style {
            case .field: FormField { row }
            case .hero:
                HStack(alignment: .center, spacing: Organic.Space.s) {
                    row
                    Image(systemName: "pencil").font(Organic.valueStrong).foregroundStyle(Organic.n500)
                        .accessibilityHidden(true)
                }
            }
        }
        .onAppear { text = display(value) }
        .onChange(of: text) { _, typed in
            let normalised = MoneyExpression.normalise(typed, fractionDigits: fractionDigits)
            let shown = MoneyExpression.display(normalised)
            // Re-grouping changes the text, which fires this again with `shown`.
            if shown != typed { text = shown; return }
            let result = MoneyExpression.evaluateExact(normalised).map(rounded)
            if result != value { value = result }
        }
        .onChange(of: value) { _, external in
            // A chip ("Full", "No fee") or a reset wrote the number from outside;
            // typing lands here too, but then the text already says the same.
            let typed = MoneyExpression.evaluateExact(MoneyExpression.normalise(text, fractionDigits: fractionDigits)).map(rounded)
            if (typed ?? 0) != (external ?? 0) { text = display(external) }
        }
        .onChange(of: focused) { _, hasFocus in
            // Leaving the field settles "12,000×3" into "36,000".
            if !hasFocus { text = display(value) }
        }
        .preference(key: MoneyFieldFocusKey.self, value: focused)
    }

    /// The symbol, the number and the live sum. In `.hero` the symbol is the
    /// figure's own size and ink: "¥1,280" reads as one figure.
    private var row: some View {
        let symbolColour = style == .hero ? Organic.text : Organic.n500
        return HStack(spacing: style == .hero ? 2 : Organic.Space.s) {
            if let symbol = leadingSymbol {
                Text(symbol).foregroundStyle(symbolColour)
            }
            MoneyKeypadField(placeholder: placeholder, text: $text, focused: $focused, decimal: fractionDigits > 0,
                             font: style == .hero ? Organic.heroUI : (prominent ? Organic.titleUI : Organic.bodyUI),
                             alignment: alignment,
                             onOperator: insert, onEquals: settle)
            if let result = liveResult {
                Text("= \(result)").font(Organic.caption).foregroundStyle(Organic.n600)
                    .lineLimit(1).layoutPriority(1)
            }
            if let symbol = trailingSymbol {
                Text(symbol).foregroundStyle(symbolColour)
            }
        }
        .font(style == .hero ? Organic.hero : nil)
    }

    /// `=`: show the result as a plain number and put the keyboard away.
    private func settle() {
        text = display(value)
        KeyboardDismiss.now()
    }

    private func insert(_ op: String) {
        var s = text
        if let last = s.last, MoneyExpression.operatorGlyphs.contains(String(last)) { s.removeLast() }
        // Only a minus may open an expression — a negative balance is a real thing.
        guard !s.isEmpty || op == "−" else { return }
        s.append(op)
        text = s
    }

    private func display(_ v: Double?) -> String {
        v.map { MoneyExpression.display(MoneyExpression.plain($0, fractionDigits: fractionDigits)) } ?? ""
    }

    /// A sum like "10÷3" settles to the digits the currency has.
    private func rounded(_ v: Double) -> Double {
        let scale = pow(10, Double(fractionDigits))
        return (v * scale).rounded() / scale
    }

    private var currency: Currency? {
        switch unit {
        case .book: return store.currency
        case .currency(let c): return c
        case .suffix, .none: return nil
        }
    }
    private var leadingSymbol: String? {
        guard let c = currency, !c.symbolTrails else { return nil }
        return c.symbol
    }
    private var trailingSymbol: String? {
        if let c = currency, c.symbolTrails { return c.symbol }
        if case .suffix(let s) = unit { return s }
        return nil
    }
    /// Shown only while the text is an expression; a plain number needs no echo.
    private var liveResult: String? {
        let normalised = MoneyExpression.normalise(text, fractionDigits: fractionDigits)
        guard MoneyExpression.isExpression(normalised),
              let exact = MoneyExpression.evaluateExact(normalised) else { return nil }
        let v = rounded(exact)
        if fractionDigits == 0, let c = currency { return c.format(Int(v)) }
        let n = v.formatted(.number.precision(.fractionLength(0...fractionDigits)))
        if let c = currency { return c.symbolTrails ? "\(n) \(c.symbol)" : "\(c.symbol)\(n)" }
        if case .suffix(let s) = unit { return "\(n) \(s)" }
        return n
    }
}

/// The arithmetic behind `MoneyField`. Text goes through `normalise` (one
/// canonical character per operator, nothing else but digits), is shown through
/// `display` (grouped digits, typographic operators) and read through
/// `evaluate` (× ÷ before + −, a leading − is a sign, a trailing operator is
/// ignored so the result keeps up while the next number is still to come).
enum MoneyExpression {
    static let operatorGlyphs = ["+", "−", "×", "÷"]
    private static let operators: Set<Character> = ["+", "-", "*", "/"]

    /// The decimal mark as the keypad types it and `display` writes it.
    /// Inside the canonical text it is always ".".
    static var decimalMark: String { Locale.current.decimalSeparator ?? "." }

    /// `fractionDigits` 0 drops any decimal mark, as before; otherwise the
    /// locale's mark becomes "." and digits past the allowed ones are dropped.
    /// The grouping mark is dropped either way — in Vietnamese it is "."
    /// itself, so only the locale's decimal mark may mean a decimal.
    static func normalise(_ raw: String, fractionDigits: Int = 0) -> String {
        var out = ""
        var decimals: Int? = nil  // digits typed after the mark in this number
        let mark = Character(decimalMark)
        for ch in raw {
            if fractionDigits > 0, ch == mark {
                if decimals == nil { out.append(out.last?.isNumber == true ? "." : "0."); decimals = 0 }
                continue
            }
            if ch.isNumber, let d = decimals {
                if d >= fractionDigits { continue }
                decimals = d + 1
            }
            let canonical: Character?
            switch ch {
            case "0"..."9": canonical = ch
            // Full-width digits from a Japanese keyboard.
            case "０"..."９": canonical = Character(UnicodeScalar(ch.unicodeScalars.first!.value - 0xFF10 + 0x30)!)
            case "+": canonical = "+"
            case "-", "−", "–": canonical = "-"
            case "*", "×", "x", "X": canonical = "*"
            case "/", "÷": canonical = "/"
            default: canonical = nil
            }
            guard let c = canonical else { continue }
            if operators.contains(c) { decimals = nil }
            // Two operators in a row: the later one wins, so a mis-tap is a retap.
            if operators.contains(c), let last = out.last, operators.contains(last) { out.removeLast() }
            out.append(c)
        }
        return out
    }

    static func display(_ normalised: String) -> String {
        var out = "", run = ""
        func flush() {
            guard !run.isEmpty else { return }
            // "12." while the cents are still to come keeps its mark.
            let parts = run.split(separator: ".", omittingEmptySubsequences: false)
            let whole = String(parts[0])
            out += Int(whole).map { $0.formatted(.number.grouping(.automatic)) } ?? whole
            if parts.count > 1 { out += decimalMark + parts[1] }
            run = ""
        }
        for ch in normalised {
            if ch.isNumber || ch == "." { run.append(ch) } else { flush(); out.append(glyph(ch)) }
        }
        flush()
        return out
    }

    /// True once there is an operator between numbers; a leading − alone is a sign.
    static func isExpression(_ normalised: String) -> Bool {
        normalised.dropFirst().contains { operators.contains($0) }
    }

    /// A figure as canonical text: "1234.5", "1234" — what `display` groups.
    static func plain(_ v: Double, fractionDigits: Int) -> String {
        guard fractionDigits > 0 else { return String(Int(v.rounded())) }
        var s = String(format: "%.\(fractionDigits)f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    static func evaluate(_ normalised: String) -> Int? {
        evaluateExact(normalised).map { Int($0.rounded()) }
    }

    static func evaluateExact(_ normalised: String) -> Double? {
        var s = normalised
        while let last = s.last, operators.contains(last) { s.removeLast() }
        guard !s.isEmpty else { return nil }

        // Tokens: numbers and operators, with a sign folded into its number.
        enum Token { case num(Double), op(Character) }
        var tokens: [Token] = []
        var digits = ""
        var expectNumber = true
        for ch in s {
            if ch.isNumber || ch == "." { digits.append(ch); continue }
            if expectNumber && ch == "-" && digits.isEmpty { digits = "-"; continue }
            guard let n = Double(digits) else { return nil }
            tokens.append(.num(n)); digits = ""
            tokens.append(.op(ch)); expectNumber = true
        }
        guard let n = Double(digits) else { return nil }
        tokens.append(.num(n))

        // × ÷ first, then + − left to right.
        guard case .num(let first) = tokens[0] else { return nil }
        var values = [first]
        var pending: [Character] = []
        var i = 1
        while i + 1 < tokens.count {
            guard case .op(let o) = tokens[i], case .num(let rhs) = tokens[i + 1] else { return nil }
            switch o {
            case "*": values[values.count - 1] *= rhs
            case "/":
                guard rhs != 0 else { return nil }
                values[values.count - 1] /= rhs
            default: pending.append(o); values.append(rhs)
            }
            i += 2
        }
        var result = values[0]
        for (k, o) in pending.enumerated() {
            result = o == "+" ? result + values[k + 1] : result - values[k + 1]
        }
        guard result.isFinite, abs(result) < 1e15 else { return nil }
        return result
    }

    private static func glyph(_ op: Character) -> String {
        switch op {
        case "-": return "−"
        case "*": return "×"
        case "/": return "÷"
        default: return String(op)
        }
    }
}

/// The text field inside `MoneyField`. UIKit, not SwiftUI, because only a
/// `UITextField` owns an `inputAccessoryView`, and that is the one hook that
/// lets the operator row be drawn as keys: SwiftUI's keyboard toolbar is
/// glass pills, fixed in look and glued to the keyboard.
struct MoneyKeypadField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    @Binding var focused: Bool
    var decimal = false
    var font: UIFont
    var alignment: TextAlignment
    var onOperator: (String) -> Void
    var onEquals: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.keyboardType = decimal ? .decimalPad : .numberPad
        field.autocorrectionType = .no
        field.tintColor = UIColor(Organic.accent)
        field.textColor = UIColor(Organic.text)
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        // Take whatever width the HStack leaves, like a SwiftUI TextField would.
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let coordinator = context.coordinator
        field.inputAccessoryView = OperatorKeyRow(
            onOperator: { coordinator.parent.onOperator($0) },
            onEquals: { coordinator.parent.onEquals() })
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        // Each real key press is its own run-loop turn, and SwiftUI commits the
        // state it caused before the next one arrives, so writing the grouped
        // text back never eats a keystroke. Only synthetic input (`simctl`'s
        // text injection) lands several keys in one turn and loses digits;
        // test with the on-screen pad or the Paste button instead.
        if field.text != text { field.text = text }
        field.placeholder = placeholder
        field.font = font
        field.textAlignment = alignment == .trailing ? .right : (alignment == .center ? .center : .left)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: MoneyKeypadField
        init(parent: MoneyKeypadField) { self.parent = parent }
        @objc func changed(_ field: UITextField) { parent.text = field.text ?? "" }
        func textFieldDidBeginEditing(_ textField: UITextField) { parent.focused = true }
        func textFieldDidEndEditing(_ textField: UITextField) { parent.focused = false }
    }
}

/// The operator row: a rounded panel in the keyboard's grey holding five keys
/// in the keyboard's key style, spread evenly across the width, floating
/// `Keypad.lift` above the number pad. Every colour is a dynamic `UIColor`,
/// so a dark keyboard gets a dark row without the app knowing.
final class OperatorKeyRow: UIInputView {
    private let onOperator: (String) -> Void
    private let onEquals: () -> Void

    init(onOperator: @escaping (String) -> Void, onEquals: @escaping () -> Void) {
        self.onOperator = onOperator
        self.onEquals = onEquals
        let k = Organic.Keypad.self
        let height = k.margin * 2 + k.keyHeight + k.lift
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: height), inputViewStyle: .default)
        allowsSelfSizing = true
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: height).isActive = true
        backgroundColor = .clear

        let panel = UIView()
        panel.backgroundColor = k.panel
        panel.layer.cornerRadius = k.panelRadius
        panel.layer.cornerCurve = .continuous
        panel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(panel)

        let keys = MoneyExpression.operatorGlyphs + ["="]
        let stack = UIStackView(arrangedSubviews: keys.map(makeKey))
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = k.gap
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)

        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: k.margin),
            panel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -k.margin),
            panel.topAnchor.constraint(equalTo: topAnchor),
            panel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -k.lift),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: k.margin),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -k.margin),
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: k.margin),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -k.margin),
        ])
    }

    required init?(coder: NSCoder) { fatalError("OperatorKeyRow is built in code") }

    private func makeKey(_ title: String) -> UIButton {
        let k = Organic.Keypad.self
        let key = UIButton(type: .custom)
        key.setTitle(title, for: .normal)
        key.titleLabel?.font = k.keyFont
        key.setTitleColor(.label, for: .normal)
        key.backgroundColor = k.key
        key.layer.cornerRadius = k.keyRadius
        key.layer.cornerCurve = .continuous
        // The keyboard's keys carry a 1-pt shadow along the bottom edge.
        key.layer.shadowColor = UIColor.black.cgColor
        key.layer.shadowOpacity = 0.3
        key.layer.shadowOffset = CGSize(width: 0, height: 1)
        key.layer.shadowRadius = 0
        key.addAction(UIAction { [weak self] _ in
            title == "=" ? self?.onEquals() : self?.onOperator(title)
        }, for: .touchUpInside)
        key.addAction(UIAction { _ in key.backgroundColor = k.keyPressed }, for: .touchDown)
        key.addAction(UIAction { _ in key.backgroundColor = k.key },
                      for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return key
    }
}

/// What the book already knows, listed right under a field while it is typed
/// in: rows in the field's own capsule border, so they read as belonging to
/// it. Each row is a button that fills the field (Buy advice's names sold before).
struct SuggestionBox<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(Organic.n100, in: RoundedRectangle(cornerRadius: Organic.rSmall, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Organic.rSmall, style: .continuous).stroke(Organic.n400, lineWidth: Organic.stroke))
    }
}

/// The small label above a control or group of chips.
struct FieldLabel: View {
    let text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }
    var body: some View {
        Text(text).font(Organic.caption).foregroundStyle(Organic.n600)
    }
}

/// Help text under a control or title.
struct HelpText: View {
    let text: LocalizedStringKey
    var tone: Tone = .quiet
    enum Tone { case quiet, warning, positive }
    private let verbatim: String?
    init(_ text: LocalizedStringKey, tone: Tone = .quiet) {
        self.text = text; self.tone = tone; self.verbatim = nil
    }
    /// A line the app assembles out of names and dates — a `metaLine` — where
    /// the pieces were already translated on the way in and the join is not
    /// copy of its own.
    init(verbatim line: String, tone: Tone = .quiet) {
        self.text = ""; self.tone = tone; self.verbatim = line
    }
    var body: some View {
        (verbatim.map { Text(verbatim: $0) } ?? Text(text))
            .font(Organic.caption).foregroundStyle(colour)
    }
    private var colour: Color {
        switch tone {
        case .quiet: return Organic.n600
        case .warning: return Organic.a800
        case .positive: return Organic.s700
        }
    }
}
