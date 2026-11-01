import SwiftUI

/// Home. What you have first, then what the cards take this round, from
/// which account, whether each account can pay it and what is left after —
/// the fastest ways to record something, and the long figures one tap from
/// their own screens. No list of what is coming: salary and the Every month
/// bills are plans to follow on Plan › Recurring, not money on its way. Every number is a `Store` property; the
/// view only lays them out.
struct HomeView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var move: Finance.TransferSuggestion?
    @State private var addingItem = false
    /// What "You have" is made of stays folded: the total answers the
    /// question, the lines are for when it looks wrong.
    @AppStorage("home.haveParts") private var haveParts = false
    /// The amounts on Home hidden, for when someone can see the screen.
    /// This phone only, like the fold: it is about who is looking.
    @AppStorage("home.hideAmounts") private var hideAmounts = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Organic.Space.l) {
                    header
                    // Wide screens: what you have and what to pay on the left,
                    // the long figures on the right.
                    AdaptiveColumns {
                        haveCard
                        if !store.data.cards.isEmpty { cardsCard }
                        captureRow
                    } trailing: {
                        if store.isEmptyBook { startCard } else { tiles }
                    }
                }
                .padding(.horizontal, Organic.Space.gutter).padding(.bottom, Organic.Space.gutter)
            }
            .background(Organic.bg)
            .navigationTitle("Home")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $move) { MoveSuggestionView(suggestion: $0) }
            // Bought to sell starts at the price question; the item is added from there.
            .sheet(isPresented: $addingItem) { ItemEditorView(item: nil).wideSheet() }
        }
    }

    private func short(_ d: Date) -> String { d.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }

    /// The day over the title, the gear beside it: Home is the one screen that
    /// says what day it is, because every figure on it is "as of today".
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(Organic.value).foregroundStyle(Organic.n600)
                Text("Home").font(Organic.screenTitle)
            }
            Spacer()
            NavigationLink { SettingsView() } label: {
                Image(systemName: "gearshape").font(.title3)
                    .frame(width: 44, height: 44)
                    .background(Organic.n100, in: Circle())
                    .overlay(Circle().stroke(Organic.n300, lineWidth: Organic.stroke))
                    .foregroundStyle(Organic.text)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, Organic.Space.s)
    }

    /// "before the long weekend": why the move cannot wait for the day before the debit.
    private func before(_ m: Finance.TransferSuggestion) -> String {
        let cal = Calendar.current
        var d = cal.date(byAdding: .day, value: 1, to: m.deadline)!
        var off = 0
        while d < m.debitDate { if !BusinessCalendar.isBusinessDay(d) { off += 1 }; d = cal.date(byAdding: .day, value: 1, to: d)! }
        switch off {
        case 0: return String(localized: "before the \(dayMonth(m.debitDate)) debit")
        case 1...2: return String(localized: "before the weekend")
        default: return String(localized: "before the long weekend")
        }
    }
    /// The business day before the debit has passed (it is the weekend now):
    /// "before the weekend" would read as still ahead, so say it is today.
    private func lateLine(_ m: Finance.TransferSuggestion) -> LocalizedStringKey {
        guard let last = m.lastBusinessDay else { return "Today" }
        return "Today: the last business day before it was \(short(last))"
    }
    private func dayMonth(_ d: Date) -> String { d.formatted(.dateTime.day().month(.abbreviated)) }

    // MARK: - Cards this round

    /// "To pay on cards in October": one figure, the verdict per account and
    /// the move that keeps a short account from failing. No row per card:
    /// Wallet › Cards and plans lists them, one tap away.
    private var cardsCard: some View {
        let debits = store.cardDebits
        let moves = store.cardMoves
        let months = Set(debits.map { Calendar.current.component(.month, from: $0.date) })
        let heading: String = months.count == 1 && debits.first != nil
            ? String(localized: "To pay on cards in \(debits[0].date.formatted(.dateTime.month(.wide)))")
            : String(localized: "To pay on cards by \(dayMonth(store.cardsHorizon))")
        return Card {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: heading).font(Organic.captionStrong).foregroundStyle(Organic.n600)
                    Spacer()
                    Button { router.open(.wallet) } label: {
                        Text("\(store.data.cards.count) cards ›").font(Organic.value).foregroundStyle(Organic.accent)
                    }
                    .buttonStyle(.plain)
                }
                // statValue, not hero: "You have" above is the one number Home is
                // about, and two heroes in a row read as two answers.
                Text(verbatim: shown(store.cardDebitsTotal))
                    .font(Organic.statValue).lineLimit(1).minimumScaleFactor(0.6)
                    .privacySensitive()
                if !debits.isEmpty {
                    let left = store.leftAfterCards
                    // Hidden with the total: it is the total less a figure on screen.
                    LineRow(label: "Left once they are paid", value: shown(left),
                            tone: left < 0 ? .negative : .neutral)
                }
                switch store.cardRound {
                case .accountShort(let s, let move):
                    Verdict(text: "\(whose(s.account)) is \(store.format(s.shortBy)) short on \(short(s.date))", positive: false)
                    if move == nil {
                        Text("No other account has that much to spare before then.")
                            .font(Organic.caption).foregroundStyle(Organic.n600)
                    }
                case .householdShort(let amount, let from):
                    Verdict(text: "Short \(store.format(amount)) by \(short(from))", positive: false)
                case .covered:
                    if !debits.isEmpty { Verdict(text: "Every account can pay its cards") }
                }
            }
            if debits.isEmpty {
                EmptyNote("No card statement is due before the next one closes.")
            }
            ForEach(moves) { m in
                Button { move = m } label: {
                    Banner(text: "Move \(store.format(m.amount)) from \(m.from) to \(m.to)", action: "Move ›",
                           symbol: "arrow.left.arrow.right", tone: .accent,
                           detail: m.isLate ? lateLine(m) : "By \(short(m.deadline)), \(before(m))")
                }
                .buttonStyle(.plain)
                .padding(.top, Organic.Space.s)
            }
        }
    }

    /// "Linh’s MUFG": an account someone else in the household owns, named
    /// with whose it is; your own stays its plain name.
    private func whose(_ account: String) -> String {
        guard let w = store.data.wallets.first(where: { $0.name == account }), w.ownerID != "me",
              let owner = store.owner(id: w.ownerID) else { return account }
        return String(localized: "\(owner.name)’s \(account)")
    }

    // MARK: - You have

    /// What you have, from the sources picked in Settings, each on a line.
    /// Nothing owed is taken off here: the cards due come next, in their own
    /// card, with what is left once they are paid (decision #36).
    private var haveCard: some View {
        let h = store.holdings
        return Card {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("You have").font(Organic.captionStrong).foregroundStyle(Organic.n600)
                    HideFiguresButton(hidden: $hideAmounts).padding(.leading, -8)
                    Spacer()
                    Button { router.open(.wallet) } label: {
                        Text("Wallet ›").font(Organic.value).foregroundStyle(Organic.accent)
                    }
                    .buttonStyle(.plain)
                }
                // The figure itself is the bigger target: a thumb reaches for
                // the number to cover it, not for the small eye beside the label.
                Button { hideAmounts.toggle() } label: {
                    Text(verbatim: shown(h.total))
                        .font(Organic.hero).lineLimit(1).minimumScaleFactor(0.6)
                        .foregroundStyle(Organic.text)
                        .privacySensitive()
                }
                .buttonStyle(.plain)
                .accessibilityHint(hideAmounts ? Text("Shows the amounts") : Text("Hides the amounts"))
            }
            if h.parts.isEmpty {
                EmptyNote("Nothing counted yet. Settings › What Home counts says which places add up here.")
            } else {
                VStack(spacing: 0) {
                    if haveParts {
                        ForEach(h.parts, id: \.source) { part in
                            LineRow(label: Self.name(part.source), value: shown(part.amount))
                        }
                        .privacySensitive()
                    }
                    Button { withAnimation(.easeOut(duration: 0.2)) { haveParts.toggle() } } label: {
                        HStack {
                            if haveParts {
                                LinkLabel("Show less", chevron: false)
                            } else {
                                LinkLabel("What it is made of")
                            }
                            Spacer()
                            if !haveParts {
                                Text("^[\(h.parts.count) place](inflect: true)").font(Organic.caption).foregroundStyle(Organic.n600)
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// A figure as Home prints it: dots while the amounts are hidden, so the
    /// layout does not jump and nothing can be read off the screen.
    private func shown(_ yen: Int) -> String {
        hideAmounts ? "••••••" : store.format(yen)
    }

    static func name(_ source: Finance.HoldingSource) -> LocalizedStringKey {
        switch source {
        case .accounts: return "Bank and cash"
        case .marketplace: return "Marketplace balances"
        case .gold: return "Gold"
        case .crypto: return "Crypto"
        case .funds: return "Funds (NISA, iDeCo)"
        case .points: return "Points you can spend anywhere"
        case .lent: return "Lent, owed back in yen"
        }
    }

    // MARK: - Capture

    private var captureRow: some View {
        HStack(spacing: Organic.Space.m) {
            captureButton("Scan receipt", symbol: "doc.text.viewfinder", primary: true) { router.capture = .scan }
            captureButton("Add a spend", symbol: "pencil") { router.capture = .type }
            captureButton("Add a belonging", symbol: "shippingbox") { addingItem = true }
        }
    }

    private func captureButton(_ title: LocalizedStringKey, symbol: String, primary: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(Organic.valueStrong).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(primary ? Organic.accentFill : Organic.n100,
                        in: RoundedRectangle(cornerRadius: Organic.rInner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Organic.rInner, style: .continuous)
                .stroke(primary ? .clear : Organic.n300, lineWidth: Organic.stroke))
            .foregroundStyle(primary ? .white : Organic.text)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tiles

    private var tiles: some View {
        let profit = store.profitThisMonth
        let resale = store.resale
        return TileGrid {
            Button { router.openProfit() } label: {
                Tile(label: "Profit this month", value: store.signed(profit.result.total),
                     sub: String(localized: "\(profit.sold) sold · points included"),
                     valueColor: profit.result.total < 0 ? Organic.a700 : Organic.s700)
            }
            .buttonStyle(.plain)
            Button { router.open(.belongings) } label: {
                Tile(label: "Things to sell", value: store.format(resale.liquidation),
                     sub: String(localized: "\(resale.unsoldCount) things · would bring now"))
            }
            .buttonStyle(.plain)
            Button { router.open(.wallet) } label: {
                if let c = store.netWorthThisYear {
                    Tile(label: "Net worth", value: store.format(store.netWorth.total),
                         sub: String(localized: "\(store.signed(c.change)) since January"),
                         subColor: c.change < 0 ? Organic.a700 : Organic.s700)
                } else {
                    Tile(label: "Net worth", value: store.format(store.netWorth.total),
                         sub: String(localized: "Assets less everything owed"))
                }
            }
            .buttonStyle(.plain)
            Button { router.open(.wallet) } label: {
                Tile(label: "Points", value: store.format(store.spendablePoints),
                     sub: store.shopPoints > 0 ? String(localized: "usable anywhere · \(store.shopPoints.formatted()) pt tied to a shop")
                                               : String(localized: "usable anywhere"))
            }
            .buttonStyle(.plain)
        }
    }

    private var startCard: some View {
        Card {
            Text("Start here").font(Organic.title)
            Text("""
                 1. Wallet — add the bank accounts and cash you hold, the cards you buy on, and what lands or leaves every month.
                 2. Scan a receipt or type a spend; Mochi remembers shops and places from then on.
                 3. Belongings — add the things you own and what they would sell for, to see what they really cost you.
                 """)
                .font(Organic.value).foregroundStyle(Organic.n700).padding(.top, 6)
            Button { router.open(.wallet) } label: { Text("Open Wallet").font(Organic.valueStrong).foregroundStyle(Organic.accent) }
                .padding(.top, 8)
            Text("Settings can load a sample book if you would rather look around first.")
                .font(Organic.caption).foregroundStyle(Organic.n600).padding(.top, 4)
        }
    }
}
