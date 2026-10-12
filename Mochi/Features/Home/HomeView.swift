import SwiftUI

/// Home. What you have first, then what the cards take this round, from
/// which account, whether each account can pay it and what is left after —
/// the fastest ways to record something, what is coming, and the long figures
/// one tap from their own screens. Every number is a `Store` property; the
/// view only lays them out.
struct HomeView: View {
    @Environment(Store.self) private var store
    @Environment(Router.self) private var router
    @State private var move: Finance.TransferSuggestion?
    @State private var addingItem = false
    /// The card list is folded to the cards that need something done, so
    /// six cards do not push everything else off Home. Remembered on this
    /// phone only: it is a way of looking, not part of the book.
    @AppStorage("home.allCards") private var allCards = false
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
                    // Wide screens: what to pay and what is safe on the left,
                    // what comes next on the right.
                    AdaptiveColumns {
                        haveCard
                        if !store.data.cards.isEmpty { cardsCard }
                        captureRow
                    } trailing: {
                        if store.isEmptyBook { startCard } else {
                            comingUp
                            tiles
                        }
                    }
                }
                .padding(.horizontal, Organic.Space.gutter).padding(.bottom, Organic.Space.gutter)
            }
            .background(Organic.bg)
            .navigationTitle("Home")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $move) { MoveSuggestionView(suggestion: $0) }
            // Bought to sell starts at the price question; the item is added from there.
            .sheet(isPresented: $addingItem) { ItemEditorView(item: nil) }
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
    /// "the 10th": the day a weekend moved a payment from.
    private func ordinalDay(_ d: Date) -> String {
        let f = NumberFormatter(); f.numberStyle = .ordinal
        return f.string(from: NSNumber(value: Calendar.current.component(.day, from: d))) ?? ""
    }
    private func dayMonth(_ d: Date) -> String { d.formatted(.dateTime.day().month(.abbreviated)) }

    // MARK: - Cards this round

    /// "To pay on cards in October": one figure, the verdict per account, a
    /// row per card, and the move that keeps a short account from failing.
    private var cardsCard: some View {
        let debits = store.cardDebits
        let moves = store.cardMoves
        let shorts = store.cardShortfalls
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
            // A debit is flagged when its account fails that day, whether or
            // not a move can save it — and, when the household is short, a
            // card with no account to pay from, which is the one to sort out.
            let householdShort: Bool = {
                if case .householdShort = store.cardRound { return true }
                return false
            }()
            let needsMove: (Finance.ScheduledEvent) -> Bool = { e in
                if e.account == nil { return householdShort }
                return shorts.contains { $0.account == e.account && Calendar.current.isDate($0.date, inSameDayAs: e.date) }
            }
            let shown = allCards ? debits : debits.filter(needsMove)
            let folded = debits.filter { !needsMove($0) }
            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { i, e in
                    dueRow(e.date,
                           title: withOwner(card: e.label),
                           sub: leavesLine(e),
                           amount: store.signed(e.amount),
                           amountColor: needsMove(e) ? Organic.a700 : Organic.text,
                           right: e.account.flatMap { a in store.balance(ofAccount: a).map { "\(a) \(store.format($0))" } },
                           first: i == 0)
                }
                if !folded.isEmpty {
                    Button { withAnimation(.easeOut(duration: 0.2)) { allCards.toggle() } } label: {
                        HStack {
                            if allCards {
                                LinkLabel("Show fewer", chevron: false)
                            } else {
                                LinkLabel("Show all \(debits.count) cards")
                            }
                            Spacer()
                            if !allCards {
                                Text(verbatim: foldedLine(folded)).font(Organic.caption).foregroundStyle(Organic.n600)
                                    .lineLimit(1)
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) { if !shown.isEmpty { Hairline() } }
                }
            }
            .padding(.top, Organic.Space.s)
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

    /// "JCB Card W · Linh": a card in someone else's name.
    private func withOwner(card name: String) -> String {
        guard let c = store.data.cards.first(where: { $0.name == name }), c.ownerID != "me",
              let owner = store.owner(id: c.ownerID) else { return name }
        return "\(name) · \(owner.name)"
    }

    /// What the folded rows hold, in a line: "Rakuten Card on 27 Oct".
    private func foldedLine(_ folded: [Finance.ScheduledEvent]) -> String {
        guard let f = folded.first else { return "" }
        let first = String(localized: "\(f.label) on \(dayMonth(f.date))")
        return folded.count == 1 ? first : String(localized: "\(first) and \(folded.count - 1) more")
    }

    private func leavesLine(_ e: Finance.ScheduledEvent) -> String {
        let from = e.account.map { String(localized: "Leaves \($0)") } ?? String(localized: "No account set to pay it")
        guard let was = e.movedFrom else { return from }
        return from + " · " + String(localized: "moved from the \(ordinalDay(was))")
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

    // MARK: - Coming up

    private var comingUp: some View {
        let days = Array(store.paymentsDue.prefix(6))
        return Card(padding: .list) {
            HStack {
                Text("Coming up").font(Organic.title)
                Spacer()
                Text("Household cash after").font(Organic.caption).foregroundStyle(Organic.n600)
            }
            .padding(.top, Organic.Space.l).padding(.bottom, Organic.Space.s)
            if days.isEmpty {
                EmptyNote("Nothing due before then. Add cards, plans and monthly bills in Wallet.")
            }
            // The moves Home suggests, on the day they have to be made: they
            // change no household figure, so the row says ±¥0.
            ForEach(store.transfersNeeded) { m in
                // The household holds the same after a move: what it holds then.
                let before = store.paymentsDue.last { $0.date <= m.deadline }?.balanceAfter ?? store.safeToSpend.cash
                dueRow(m.deadline, title: String(localized: "Move to \(m.to)"),
                       sub: String(localized: "\(m.from) → \(m.to) · your own accounts"),
                       amount: "±\(store.format(0))", amountColor: Organic.n600, right: store.format(before), first: false)
            }
            ForEach(days) { day in
                dueRow(day.date,
                       title: dayTitle(day.names),
                       sub: comingLine(day),
                       amount: store.signed(day.amount),
                       amountColor: day.amount > 0 ? Organic.s700 : Organic.a700,
                       right: day.shortfall > 0 ? String(localized: "short \(store.format(day.shortfall))") : store.format(day.balanceAfter),
                       rightColor: day.shortfall > 0 ? Organic.a700 : Organic.n600,
                       first: false)
            }
        }
    }

    /// Two short names side by side, otherwise the first and how many more:
    /// a row title is one line.
    private func dayTitle(_ names: [String]) -> String {
        let both = names.joined(separator: " · ")
        if names.count <= 1 || (names.count == 2 && both.count <= 24) { return both }
        return String(localized: "\(names[0]) + \(names.count - 1) more")
    }

    private func comingLine(_ day: Finance.DueDay) -> String {
        var parts: [String] = []
        // One account by name; several would wrap the line, so they are counted.
        if day.accounts.count == 1 { parts.append(day.accounts[0]) }
        else if day.accounts.count > 1 { parts.append(String(localized: "\(day.accounts.count) accounts")) }
        if day.count > 1 { parts.append(String(localized: "\(day.count) payments")) }
        if let was = day.movedFrom { parts.append(String(localized: "moved from the \(ordinalDay(was))")) }
        return parts.joined(separator: " · ")
    }

    /// A dated row: the day in a small square, what and from where, the
    /// figure and what it leaves.
    private func dueRow(_ date: Date, title: String, sub: String, amount: String, amountColor: Color,
                        right: String?, rightColor: Color = Organic.n600, first: Bool) -> some View {
        HStack(spacing: Organic.Space.l) {
            VStack(spacing: 0) {
                Text(date.formatted(.dateTime.day())).font(Organic.title)
                Text(date.formatted(.dateTime.month(.abbreviated))).font(Organic.meta).foregroundStyle(Organic.n600)
            }
            .frame(width: 40, height: 40)
            .background(Organic.bg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(Organic.row).lineLimit(1)
                if !sub.isEmpty {
                    Text(verbatim: sub).font(Organic.caption).foregroundStyle(Organic.n600)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(verbatim: amount).font(Organic.rowValue).foregroundStyle(amountColor)
                if let right { Text(verbatim: right).font(Organic.meta).foregroundStyle(rightColor) }
            }
            .fixedSize()
        }
        .padding(.vertical, Organic.Space.row)
        .overlay(alignment: .top) { if !first { Hairline() } }
    }

    // MARK: - Tiles

    private var tiles: some View {
        let profit = store.profitThisYear
        let resale = store.resale
        return TileGrid {
            Button { router.open(.belongings) } label: {
                Tile(label: "Profit this year", value: store.signed(profit.result.total),
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
