import WidgetKit
import SwiftUI
import AppIntents

/// Home Screen and Lock Screen widgets, and a Control Center control. They
/// read the small file the app writes to the App Group on every save — the
/// widget never opens the book — and open the app by `mochi://` links.
/// Every one says Mochi and what it does, so a scan button is never taken for
/// another app's scanner.

struct Snapshot: Codable {
    var safeToSpend: Int
    var until: Date
    var covered: Bool
    var nextName: String
    var nextAmount: Int
    var nextDate: Date?
    var cashAfter: Int
    var reviewCount: Int
    var currencySymbol: String
    var updated: Date
    // Optional: a file written by an older build has none of these.
    var horizonIsCards: Bool? = nil
    var cardName: String? = nil
    var cardDate: Date? = nil
    var cardAmount: Int? = nil
    var cardAccount: String? = nil
    var cardShortBy: Int? = nil
    var cardMoveBy: Date? = nil
    var cardDays: [CardDayLine]? = nil
    var moveAmount: Int? = nil
    var moveBy: Date? = nil
    var shortAccount: String? = nil
    var shortBy: Int? = nil
    var shortOn: Date? = nil
    var have: Int? = nil
    var leftAfterCards: Int? = nil

    struct CardDayLine: Codable {
        var date: Date
        var amount: Int
        var cards: [String]
    }

    var cardsTotal: Int { (cardDays ?? []).reduce(0) { $0 + $1.amount } }
    var cardsCount: Int { (cardDays ?? []).reduce(0) { $0 + $1.cards.count } }

    static let appGroup = "group.com.hoangtuan.mochi"

    static func read() -> Snapshot? {
        guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup),
              let data = try? Data(contentsOf: dir.appendingPathComponent("widget.json")) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    static let placeholder = Snapshot(safeToSpend: 262_500, until: .now.addingTimeInterval(86_400 * 25), covered: true,
                                      nextName: "JCB Card W", nextAmount: 96_200, nextDate: .now.addingTimeInterval(86_400 * 11),
                                      cashAfter: 370_100, reviewCount: 3, currencySymbol: "¥", updated: .now,
                                      horizonIsCards: true, cardName: "JCB Card W", cardDate: .now.addingTimeInterval(86_400 * 11),
                                      cardAmount: 96_200, cardAccount: "MUFG", cardShortBy: 65_200,
                                      cardMoveBy: .now.addingTimeInterval(86_400 * 7),
                                      cardDays: [CardDayLine(date: .now.addingTimeInterval(86_400 * 11), amount: 132_750,
                                                             cards: ["Rakuten Card", "JCB Card W"]),
                                                 CardDayLine(date: .now.addingTimeInterval(86_400 * 24), amount: 95_550,
                                                             cards: ["SMBC Card"])],
                                      moveAmount: 66_000, moveBy: .now.addingTimeInterval(86_400 * 7),
                                      shortAccount: "MUFG", shortBy: 65_200, shortOn: .now.addingTimeInterval(86_400 * 11))

    /// A figure as the app prints it; a negative one with a true minus sign.
    func money(_ v: Int) -> String {
        let n = abs(v).formatted(.number.grouping(.automatic))
        return (v < 0 ? "−" : "") + (currencySymbol == "₫" ? "\(n) ₫" : "\(currencySymbol)\(n)")
    }
}

/// `snap` is nil until the app has saved once with the App Group in place.
/// The gallery preview gets example figures; a widget on the Home Screen
/// never does, because an invented ¥262,500 there reads as the user's own.
struct Entry: TimelineEntry {
    let date: Date
    let snap: Snapshot?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now, snap: .placeholder) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, snap: Snapshot.read() ?? (context.isPreview ? .placeholder : nil)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = Entry(date: .now, snap: Snapshot.read())
        // The app reloads the timeline on every save; this is the fallback.
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600))))
    }
}

// The widget extension does not carry the app's design system, so it keeps
// the few colours it needs, copied from the tokens (n100, n900, n600, s700,
// a700, accent, a100), light and dark.
private func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
    func ui(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
    return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
}
private let surface = dynamic(0xFFFFFF, 0x1C1C1F)
private let ink = dynamic(0x18181B, 0xF2F1EE)
private let quiet = dynamic(0x5F5E66, 0xA3A1AA)
private let green = dynamic(0x1E7A4A, 0x5FD394)
private let red = dynamic(0xB3261E, 0xFF7A6E)
private let accent = dynamic(0xC2461A, 0xE0602F)
private let accentSoft = dynamic(0xFBE9E1, 0x3A2118)

private func dayMonth(_ d: Date) -> String { d.formatted(.dateTime.day().month(.abbreviated)) }
private func weekdayDayMonth(_ d: Date) -> String { d.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }

/// What every widget says before the app has written its figures.
private struct OpenOnce: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Mochi").font(.caption.weight(.semibold)).foregroundStyle(quiet)
            Spacer()
            Text("Open Mochi once to show your figures here").font(.caption).foregroundStyle(quiet)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The round mark in the middle of a one-action widget.
private struct ActionMark: View {
    let symbol: String
    var size: CGFloat = 64
    var body: some View {
        Image(systemName: symbol).font(size > 40 ? .title.weight(.medium) : .subheadline.weight(.semibold))
            .frame(width: size, height: size)
            .background(accentSoft, in: Circle())
            .foregroundStyle(accent)
    }
}

// MARK: - You have

/// What you have, as Home heads with it, and what is left once the cards
/// due are paid. The kind is still "SafeToSpend" so widgets already placed
/// keep working; Safe to spend itself is gone (decision #36).
struct SafeToSpendView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry

    var body: some View {
        Group {
            if let s = entry.snap { figures(s) } else if family == .accessoryInline { Text("Mochi") } else { OpenOnce() }
        }
        .widgetURL(URL(string: "mochi://home"))
    }

    /// A file from a build before "You have" carries only Safe to spend.
    private func have(_ s: Snapshot) -> Int { s.have ?? s.safeToSpend }

    @ViewBuilder private func figures(_ s: Snapshot) -> some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text("Mochi · You have").font(.caption2)
                Text(verbatim: s.money(have(s))).font(.title3.weight(.bold)).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Text("You have \(s.money(have(s)))")
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text("Mochi · You have").font(.caption.weight(.semibold)).foregroundStyle(quiet)
                Spacer()
                Text(verbatim: s.money(have(s))).font(.title.weight(.bold)).foregroundStyle(ink)
                    .minimumScaleFactor(0.6).lineLimit(1)
                if s.cardsTotal > 0 {
                    Text("Cards \(s.money(s.cardsTotal))").font(.caption).foregroundStyle(quiet)
                }
                Spacer()
                if let left = s.leftAfterCards {
                    Text("\(s.money(left)) left after").font(.caption.weight(.semibold)).foregroundStyle(left < 0 ? red : green)
                        .minimumScaleFactor(0.7).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SafeToSpendWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SafeToSpend", provider: Provider()) { entry in
            SafeToSpendView(entry: entry).containerBackground(surface, for: .widget)
        }
        .configurationDisplayName("Mochi · You have")
        .description("What you have, and what is left once the cards due are paid.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Cards to pay

/// Every card due before the end of the cards' nearest statements, added up and a day to a
/// line, so several cards on one day are one line and the total is the
/// figure. The Lock Screen circle keeps the next day alone.
struct CardsToPayView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry

    var body: some View {
        if let s = entry.snap, let days = s.cardDays, let first = days.first {
            figures(s, days: days, first: first).widgetURL(URL(string: "mochi://home"))
        } else if family == .accessoryCircular {
            ZStack { AccessoryWidgetBackground(); Image(systemName: "creditcard") }
        } else if entry.snap != nil {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mochi · Cards to pay").font(.caption.weight(.semibold)).foregroundStyle(quiet)
                Spacer()
                Text("No card is due before \(dayMonth(entry.snap!.until))").font(.subheadline).foregroundStyle(ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            OpenOnce()
        }
    }

    private func countLine(_ s: Snapshot, last: Date) -> String {
        s.cardsCount == 1 ? String(localized: "1 card to \(dayMonth(last))")
                          : String(localized: "\(s.cardsCount) cards to \(dayMonth(last))")
    }

    @ViewBuilder private func figures(_ s: Snapshot, days: [Snapshot.CardDayLine], first: Snapshot.CardDayLine) -> some View {
        let last = days.last!.date
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: -1) {
                    Text(verbatim: first.date.formatted(.dateTime.day())).font(.title3.weight(.bold))
                    Text("\(first.date.formatted(.dateTime.month(.abbreviated))) card").font(.caption2)
                }
            }
        case .systemSmall:
            VStack(alignment: .leading, spacing: 2) {
                Text("Mochi · Cards to pay").font(.caption.weight(.semibold)).foregroundStyle(quiet)
                Spacer()
                Text(verbatim: s.money(-s.cardsTotal)).font(.title.weight(.bold)).foregroundStyle(red)
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text(verbatim: countLine(s, last: last)).font(.caption).foregroundStyle(quiet)
                Spacer()
                if let amount = s.moveAmount, let by = s.moveBy {
                    Label("Move \(s.money(amount)) by \(dayMonth(by))", systemImage: "exclamationmark.triangle")
                        .font(.caption2.weight(.semibold)).foregroundStyle(red).lineLimit(1).minimumScaleFactor(0.8)
                } else if let account = s.shortAccount, let short = s.shortBy {
                    // Short with nothing to move from: still short.
                    Label("\(account) \(s.money(short)) short", systemImage: "exclamationmark.triangle")
                        .font(.caption2.weight(.semibold)).foregroundStyle(red).lineLimit(1).minimumScaleFactor(0.8)
                } else {
                    Label("Every account can pay", systemImage: "checkmark")
                        .font(.caption2.weight(.semibold)).foregroundStyle(green).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Mochi · Cards to pay").font(.caption.weight(.semibold)).foregroundStyle(quiet)
                    Spacer()
                    Link(destination: URL(string: "mochi://scan")!) { ActionMark(symbol: "doc.text.viewfinder", size: 32) }
                        .accessibilityLabel(Text("Scan a receipt"))
                }
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: s.money(-s.cardsTotal)).font(.title2.weight(.bold)).foregroundStyle(red)
                            .minimumScaleFactor(0.6).lineLimit(1)
                        Text(verbatim: countLine(s, last: last)).font(.caption).foregroundStyle(quiet)
                    }
                    .frame(width: 120, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(days.prefix(2), id: \.date) { d in
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text(verbatim: weekdayDayMonth(d.date)).font(.caption.weight(.semibold)).foregroundStyle(ink)
                                    Spacer()
                                    Text(verbatim: s.money(-d.amount)).font(.caption.weight(.bold)).foregroundStyle(red)
                                }
                                Text(verbatim: d.cards.joined(separator: " · ")).font(.caption2).foregroundStyle(quiet).lineLimit(1)
                            }
                        }
                        if days.count > 2 {
                            Text("+\(days.count - 2) more days").font(.caption2).foregroundStyle(quiet)
                        }
                    }
                }
                Spacer(minLength: 0)
                if let account = s.shortAccount, let short = s.shortBy, let on = s.shortOn, let by = s.moveBy {
                    Label("\(account) \(s.money(short)) short on \(dayMonth(on)) · move by \(weekdayDayMonth(by))",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption.weight(.semibold)).foregroundStyle(red).lineLimit(1).minimumScaleFactor(0.8)
                } else if let account = s.shortAccount, let short = s.shortBy, let on = s.shortOn {
                    Label("\(account) \(s.money(short)) short on \(dayMonth(on))", systemImage: "exclamationmark.triangle")
                        .font(.caption.weight(.semibold)).foregroundStyle(red).lineLimit(1).minimumScaleFactor(0.8)
                } else {
                    Label("Every account can pay its cards", systemImage: "checkmark")
                        .font(.caption.weight(.semibold)).foregroundStyle(green).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CardsToPayWidget: Widget {
    var body: some WidgetConfiguration {
        // The kind stays "NextCard" so a widget already placed keeps working.
        StaticConfiguration(kind: "NextCard", provider: Provider()) { entry in
            CardsToPayView(entry: entry).containerBackground(surface, for: .widget)
        }
        .configurationDisplayName("Mochi · Cards to pay")
        .description("Every card due before the next debits, added up, and whether each account can pay.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

// MARK: - One-tap ways in

/// One action and nothing else. It reads no figures, so it needs no snapshot
/// and is never out of date.
struct ActionView: View {
    @Environment(\.widgetFamily) private var family
    let symbol: String
    let title: LocalizedStringKey
    let line: LocalizedStringKey
    let url: String
    var body: some View {
        Group {
            if family == .accessoryCircular {
                ZStack { AccessoryWidgetBackground(); Image(systemName: symbol).font(.title2) }
            } else {
                VStack(spacing: 4) {
                    ActionMark(symbol: symbol)
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(ink).padding(.top, 8)
                    Text(line).font(.caption).foregroundStyle(quiet).multilineTextAlignment(.center)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .padding(.horizontal, -4)
            }
        }
        .widgetURL(URL(string: url))
    }
}

struct ScanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Scan", provider: StaticProvider()) { _ in
            ActionView(symbol: "doc.text.viewfinder", title: "Scan a receipt", line: "Opens Mochi’s camera", url: "mochi://scan")
                .containerBackground(surface, for: .widget)
        }
        .configurationDisplayName("Mochi · Scan a receipt")
        .description("Opens Mochi’s receipt camera.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct BuyAdviceWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BuyAdvice", provider: StaticProvider()) { _ in
            ActionView(symbol: "lightbulb", title: "Buy advice", line: "What to pay, in the shop", url: "mochi://buy")
                .containerBackground(surface, for: .widget)
        }
        .configurationDisplayName("Mochi · Buy advice")
        .description("The most to pay for something you will sell on, worked out in the shop.")
        .supportedFamilies([.systemSmall])
    }
}

struct StaticProvider: TimelineProvider {
    struct Empty: TimelineEntry { let date = Date.now }
    func placeholder(in context: Context) -> Empty { Empty() }
    func getSnapshot(in context: Context, completion: @escaping (Empty) -> Void) { completion(Empty()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Empty>) -> Void) {
        completion(Timeline(entries: [Empty()], policy: .never))
    }
}

// MARK: - Control Center, Lock Screen, Action button

@available(iOS 18.0, *)
struct ScanControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.hoangtuan.mochi.scan") {
            ControlWidgetButton(action: OpenScanIntent()) {
                Label("Scan receipt", systemImage: "doc.text.viewfinder")
            }
        }
        .displayName("Scan receipt")
        .description("Opens Mochi’s receipt camera, even from the Lock Screen.")
    }
}

@available(iOS 18.0, *)
struct OpenScanIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan a receipt"
    static let openAppWhenRun = true
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "mochi://scan")!))
    }
}

@main
struct MochiWidgetBundle: WidgetBundle {
    var body: some Widget {
        SafeToSpendWidget()
        CardsToPayWidget()
        ScanWidget()
        BuyAdviceWidget()
        if #available(iOS 18.0, *) { ScanControl() }
    }
}
