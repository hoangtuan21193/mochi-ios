import Foundation
import Observation

/// Single source of truth. Everything the UI reads is derived here so the
/// numbers can never disagree between screens.
@Observable
final class Store {
    var data: AppData

    /// The one book the app, Siri and the widgets' writer share. The app's
    /// scene holds it too, so an intent sees exactly what the screens show.
    static let shared = Store()

    /// Set by the "Scan a receipt" intent; the app opens the camera when it
    /// comes to the front.
    var pendingCapture = false
    /// Set by the Buy advice shortcut, read when the app comes forward.
    var pendingBuyAdvice = false

    /// Set when a write to disk fails. Settings shows it — a silent failure
    /// here means the user is typing into a book that is not being kept.
    var saveError: String?

    private let fileName = "mochi.json"

    /// A fresh install starts empty: no wallets, cards, items or owners beyond
    /// "Me". Sales channels are configuration rather than data, so the common
    /// Japanese marketplaces are pre-filled; they are editable in Settings.
    init(data: AppData = .empty) {
        self.data = data
        load()
        startLedgerIfNeeded()
        postDueSchedules()
        if !isEmptyBook { takeMonthlySnapshotIfDue() }
    }

    // MARK: - Money helpers

    var currency: Currency { Currency(rawValue: data.currency) ?? .jpy }

    func format(_ amount: Int) -> String { currency.format(amount) }
    /// "+¥1,000" / "-¥1,000": a flow or a change, not a balance.
    func signed(_ amount: Int) -> String { currency.signed(amount) }
    func short(_ amount: Int) -> String { currency.short(amount) }

    func setCurrency(_ c: Currency) {
        data.currency = c.rawValue
        save()
    }

    // MARK: - Language

    var language: AppLanguage { AppLanguage(rawValue: data.language) ?? .system }

    /// The language the process actually launched in, so Settings can say
    /// whether a change is still waiting on a restart.
    static let launchLanguage: AppLanguage = overriddenLanguage()

    /// The override this app has written, if any. Read from the app's own
    /// domain only: `UserDefaults.standard` would fall through to the device's
    /// global `AppleLanguages`, and "Follow device" would then read as "English".
    private static func overriddenLanguage() -> AppLanguage {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let own = UserDefaults.standard.persistentDomain(forName: bundleID),
              let first = (own["AppleLanguages"] as? [String])?.first else { return .system }
        return AppLanguage(rawValue: String(first.prefix(2))) ?? .system
    }

    var languageNeedsRestart: Bool { language != Store.launchLanguage }

    /// Writes the per-app language override iOS reads at launch. Nothing in
    /// the running process changes; the next launch comes up in the new
    /// language — strings, dates and numbers alike.
    func setLanguage(_ l: AppLanguage) {
        data.language = l.rawValue
        writeLanguageOverride(l)
        save()
    }

    /// Two keys, not one. `AppleLanguages` picks which .lproj the strings come
    /// from; `Locale.current` — month names, digit grouping — is built from
    /// `AppleLocale` and ignores the first. Setting only the language gave
    /// Vietnamese titles over English dates. The region stays the device's:
    /// a Vietnamese speaker in Japan still wants Japan's conventions.
    private func writeLanguageOverride(_ l: AppLanguage) {
        let defaults = UserDefaults.standard
        if let id = l.localeIdentifier {
            let region = Locale.current.region?.identifier ?? "JP"
            defaults.set([id], forKey: "AppleLanguages")
            defaults.set("\(id)_\(region)", forKey: "AppleLocale")
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
            defaults.removeObject(forKey: "AppleLocale")
        }
    }

    /// The book carries the choice; `AppleLanguages` is only a cache of it in
    /// this install. A restored book, or one saved before the setting had any
    /// effect, has to push its choice into the cache or "next launch" would
    /// never arrive.
    private func syncLanguageOverride() {
        let cached = Store.overriddenLanguage()
        let localeMissing = language != .system
            && UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?["AppleLocale"] == nil
        if cached != language || localeMissing { writeLanguageOverride(language) }
    }

    func channel(named name: String) -> SalesChannel? {
        data.channels.first { $0.name == name }
    }

    func owner(id: String) -> Owner? { data.owners.first { $0.id == id } }

    /// Item arithmetic lives in `Finance` so a test can run it on a made-up
    /// book; these keep the call sites the views already use.
    func shipping(_ item: Item) -> Int { Finance.shipping(item, data) }
    func commission(_ item: Item, channelName: String, price: Int? = nil) -> Int {
        Finance.commission(item, channelName: channelName, price: price, data)
    }
    func netProceeds(_ item: Item, channelName: String, price: Int? = nil) -> Int {
        Finance.netProceeds(item, channelName: channelName, price: price, data)
    }
    func expectedProfit(_ item: Item, channelName: String, price: Int? = nil) -> Int {
        Finance.expectedProfit(item, channelName: channelName, price: price, data)
    }
    /// The points the same sale would credit; 0 on a cash channel.
    func expectedPoints(_ item: Item, channelName: String, price: Int? = nil) -> Int {
        Finance.expectedPoints(item, channelName: channelName, price: price, data)
    }

    /// What an item made, or is expected to make, in cash: the sale as it was
    /// recorded once it is sold, its planned channel's payout while it is not.
    /// The one place a row works out an item's profit, so no screen does the
    /// subtraction itself and none of them can disagree.
    func profit(_ item: Item) -> Int { Finance.profit(item, data) }

    /// The points selling it would credit. Nothing on a cash channel, and
    /// nothing once it is sold — a sold item's points are in its record.
    func pointsOnSale(_ item: Item) -> Int {
        item.isSold ? 0 : Finance.expectedPoints(item, channelName: item.plannedChannel, data)
    }

    // MARK: - Derived totals

    // Every figure below is a `Finance` call. Four questions, four numbers,
    // never folded into one: cash today, safe to spend, this month's flow,
    // net worth. See Finance.swift for the rules that stop double counting.

    var unsold: [Item] { Finance.unsold(data) }
    var forSale: [Item] { Finance.forSale(data) }
    var keeping: [Item] { unsold.filter { $0.keep } }

    /// Every wallet is cash. Points are not.
    var cash: Int { Finance.cashNow(data) }
    /// Typed statements still owed. A statement whose due day has passed (known
    /// closing day) is treated as paid.
    var debt: Int { Finance.cardDebt(data) }
    /// Charged on a card, on no statement yet: this month's stock and bills.
    var unbilledCharges: Int { Finance.unbilledCharges(data) }

    var liquidation: Int { Finance.liquidation(data) }
    var inventoryCost: Int { Finance.inventoryCost(data) }
    var expectedProfit: Int { Finance.unrealizedProfit(data) }
    /// What the stock would pay back in points, for the stock planned to go to
    /// a point channel. Reported beside `liquidation`, never inside it.
    var pointsFromSelling: Int { Finance.pointsFromSelling(data) }

    /// The figures the Wallet sections add up to, so a total under a list is
    /// the same arithmetic wherever it appears.
    var pointsHeld: Int { Finance.pointsHeld(data) }
    var typedCardDebt: Int { Finance.typedCardDebt(data) }
    var monthlyCommitments: (income: Int, bills: Int) { Finance.monthlyCommitments(data) }

    var loansOwedToYou: Int { Finance.loansOwedToYou(data) }
    var loansYouOwe: Int { Finance.loansYouOwe(data) }

    /// Assets − liabilities, if everything were sold and settled. Long-term
    /// health; not the headline.
    var netWorth: Finance.NetWorth { Finance.netWorth(data) }

    var horizon: Finance.Horizon { Finance.Horizon.stored(data.horizon) }
    func setHorizon(_ h: Finance.Horizon) { data.horizon = h.storedValue; save() }

    /// The forecast's cash walk to the horizon. No longer on any screen
    /// (decision #36); the moves and Coming up still start from its cash.
    var safeToSpend: Finance.SafeToSpend { Finance.safeToSpend(data, horizon: horizon) }

    /// Home's headline: what you have, from the sources picked in Settings.
    var holdings: Finance.Holdings { Finance.holdings(data) }
    var holdingSources: [Finance.HoldingSource] { Finance.holdingSources(data) }
    /// What the cards take this round, and what is left once they are paid.
    var cardsDue: Int { Finance.cardsDue(data, today: .now) }
    var leftAfterCards: Int { Finance.leftAfterCards(data, today: .now) }

    func setHoldingSource(_ source: Finance.HoldingSource, counted: Bool) {
        var set = Set(holdingSources.map(\.rawValue))
        if counted { set.insert(source.rawValue) } else { set.remove(source.rawValue) }
        data.holdingSources = Finance.HoldingSource.allCases.map(\.rawValue).filter(set.contains)
        save()
    }
    /// What moves cash between now and the horizon, soonest first.
    var upcoming: [Finance.ScheduledEvent] { Finance.events(data, from: .now, to: horizon.end(data, today: .now)) }
    /// The same movements as the list reads them: cards on one line, plans on
    /// one line, everything else on its own.
    var upcomingLines: [Finance.EventGroup] {
        Finance.upcomingLines(data, from: .now, to: horizon.end(data, today: .now))
    }
    var forecast: Finance.Forecast { Finance.projectedCashBalance(data, to: horizon.end(data, today: .now)) }
    /// The same movements as a payment schedule: one row a day, running
    /// balance, so Overview can say what is still missing and by when.
    var paymentsDue: [Finance.DueDay] {
        Finance.paymentsDue(data, to: horizon.end(data, today: .now))
    }
    /// How much more cash has to be found before the horizon, and by when.
    var shortfall: (amount: Int, from: Date)? { Finance.shortfall(paymentsDue) }

    /// Month by month, oldest first — what Stats draws.
    func history(months: Int = 12) -> [Finance.MonthPoint] { Finance.history(data, months: months) }
    func summary(for period: Finance.Period) -> Finance.PeriodSummary { Finance.summary(data, for: period) }
    var yearsWithActivity: [Int] { Finance.yearsWithActivity(data) }
    var monthsWithActivity: [Finance.Period] { Finance.monthsWithActivity(data) }

    /// The inventory as a screen reads it: filtered and ordered in one place,
    /// so no view sorts a list itself.
    func items(status: Finance.ItemStatus, period: Finance.Period, sort: Finance.ItemSort,
               search: String = "") -> [Item] {
        Finance.items(data, status: status, period: period, sort: sort, search: search)
    }
    func daysHeld(_ item: Item) -> Int? { Finance.daysHeld(item) }
    var resale: Finance.ResaleBusiness { Finance.resaleBusiness(data) }

    func cycle(for card: CreditCard) -> Finance.CardCycle { Finance.cycle(for: card, data) }

    /// Nothing of the user's own yet. The ¥0 marketplace wallets a fresh
    /// install seeds do not count — they are configuration wearing a wallet's
    /// clothes.
    var isEmptyBook: Bool {
        data.wallets.allSatisfy { $0.balance == 0 } && data.cards.isEmpty
            && data.items.isEmpty && installments.isEmpty
    }

    // MARK: - Instalment plans

    var installments: [Installment] { data.installments ?? [] }

    /// Plans still owing, soonest debit first. Settled ones trail so they
    /// stop competing with the ones that still cost money.
    var installmentsByUrgency: [Installment] {
        installments.sorted {
            let a = $0.isSettled(), b = $1.isSettled()
            if a != b { return !a }
            let da = $0.nextDue()?.date ?? .distantFuture, db = $1.nextDue()?.date ?? .distantFuture
            if da != db { return da < db }
            return $0.remaining() > $1.remaining()
        }
    }

    var openInstallments: [Installment] { installments.filter { !$0.isSettled() } }

    /// Everything still owed across every plan — the figure that grows quietly
    /// when several things were each bought on sixty months.
    var installmentDebt: Int { Finance.installmentRemaining(data) }
    /// The debt part of that: fee not yet accrued is a cost to come, not owed.
    var installmentPrincipal: Int { Finance.installmentPrincipal(data) }

    /// What the plans will debit next month, added together.
    var installmentMonthly: Int { installments.reduce(0) { $0 + ($1.nextDue()?.amount ?? 0) } }

    func installment(for item: Item) -> Installment? {
        installments.first { $0.itemID == item.id }
    }

    func addInstallment(_ plan: Installment) {
        var list = installments
        list.append(plan)
        data.installments = list
        log(date: plan.firstDate, label: plan.name,
            detail: metaLine(String(localized: "Instalment plan"), plan.lender,
                             String(localized: "\(plan.months) months")),
            amount: 0, kind: "x")
        save()
    }

    func updateInstallment(_ plan: Installment) {
        guard let ix = installments.firstIndex(where: { $0.id == plan.id }) else { return }
        var list = installments
        list[ix] = plan
        data.installments = list
        save()
    }

    func deleteInstallment(_ plan: Installment) {
        var list = installments
        list.removeAll { $0.id == plan.id }
        data.installments = list
        log(label: plan.name, detail: String(localized: "Instalment plan removed"), amount: 0, kind: "x")
        save()
    }

    /// Days from today to the next time that day-of-month comes round. A bill
    /// due on the 4th read on the 27th is next month's, not three weeks ago.
    func daysUntilDue(_ day: Int) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        for month in 0...1 {
            guard let base = cal.date(byAdding: .month, value: month, to: today),
                  let range = cal.range(of: .day, in: .month, for: base) else { continue }
            var parts = cal.dateComponents([.year, .month], from: base)
            // A card due on the 31st still bills in February — clamp to the month.
            parts.day = min(day, range.count)
            guard let candidate = cal.date(from: parts) else { continue }
            let start = cal.startOfDay(for: candidate)
            if start >= today {
                return cal.dateComponents([.day], from: today, to: start).day ?? 0
            }
        }
        return 0
    }

    /// "in 5 days" / "tomorrow" / "today" — urgency reads faster than a date.
    func dueLabel(_ day: Int) -> String {
        switch daysUntilDue(day) {
        case 0: return String(localized: "due today")
        case 1: return String(localized: "due tomorrow")
        case let n: return String(localized: "in \(n) days")
        }
    }

    /// Cards in the order the money actually leaves: soonest bill first, and
    /// paid-off cards last so they stop competing for attention.
    var cardsByUrgency: [CreditCard] {
        data.cards.sorted {
            if ($0.debt > 0) != ($1.debt > 0) { return $0.debt > 0 }
            return daysUntilDue($0.dueDay) < daysUntilDue($1.dueDay)
        }
    }


    // MARK: - Items

    // Items never move money on their own. Wallet balances and card debt are
    // typed in by hand from the bank and the statement — the book has too many
    // outgoings that are not resale stock for a sale or a purchase to be trusted to
    // keep a balance right. Buying and selling are recorded in Activity as
    // events (kind "x"), not as movements.

    func addItem(_ item: Item) {
        data.items.insert(item, at: 0)
        bookPurchase(of: item)
        log(date: item.boughtOn, label: item.name, detail: metaLine(String(localized: "Bought"), item.cardName),
            amount: -item.buyPrice, kind: "x")
        save()
    }

    func update(_ item: Item) {
        guard let ix = data.items.firstIndex(where: { $0.id == item.id }) else { return }
        var item = item
        if item.estimatedPrice != data.items[ix].estimatedPrice {
            var history = item.valueHistory ?? []
            history.append(ValuePoint(date: .now, value: item.estimatedPrice))
            item.valueHistory = history
        }
        data.items[ix] = item
        syncPurchase(of: item)
        save()
    }

    /// Only the record goes; no balance or debt was ever tied to it.
    func deleteItem(_ item: Item) {
        guard let ix = data.items.firstIndex(where: { $0.id == item.id }) else { return }
        data.items.remove(at: ix)
        // The plan that paid for it stays — the debt does not leave with the
        // record — but it no longer points at an item that is not there.
        if var list = data.installments,
           let pix = list.firstIndex(where: { $0.itemID == item.id }) {
            list[pix].itemID = nil
            data.installments = list
        }
        // The purchase was booked with the item; it goes with it.
        data.transactions?.removeAll { $0.itemID == item.id }
        log(label: item.name, detail: String(localized: "Item deleted"), amount: 0, kind: "x")
        save()
    }

    /// Confirming a sale records what it fetched. The proceeds are the user's
    /// to type into a wallet when the marketplace actually pays out.
    func sell(_ item: Item, channelName: String, price: Int? = nil, into wallet: String? = nil) {
        guard let ix = data.items.firstIndex(where: { $0.id == item.id }) else { return }
        let listed = price ?? item.estimatedPrice
        var copy = item
        copy.estimatedPrice = listed
        let net = netProceeds(copy, channelName: channelName)
        data.items[ix].sale = SaleRecord(price: listed, channel: channelName, net: net,
                                         date: .now, shipping: shipping(item))
        if let wallet, !wallet.isEmpty {
            var list = data.transactions ?? []
            list.append(Transaction(date: .now, amount: net, kind: .income, account: wallet,
                                    merchant: channelName, note: item.name, itemID: item.id))
            data.transactions = list
        }
        log(label: item.name, detail: String(localized: "Sold · \(channelName)"), amount: net, kind: "x")
        save()
    }

    func unsell(_ item: Item) {
        guard let ix = data.items.firstIndex(where: { $0.id == item.id }),
              let sale = data.items[ix].sale else { return }
        data.items[ix].sale = nil
        data.transactions?.removeAll { $0.itemID == item.id && $0.kind == .income }
        log(label: item.name, detail: String(localized: "Sale undone · \(sale.channel)"), amount: -sale.net, kind: "x")
        save()
    }

    /// Items bought on a card in a calendar month, newest first, with what they
    /// came to. The statement a card sends is a month of purchases, so this is
    /// the view to check it against. Sold items still count: the card was charged.
    func purchases(on card: CreditCard, in month: Date) -> (items: [Item], total: Int) {
        let cal = Calendar.current
        let items = data.items
            .filter { $0.cardName == card.name && cal.isDate($0.boughtOn, equalTo: month, toGranularity: .month) }
            .sorted { $0.boughtOn > $1.boughtOn }
        return (items, items.reduce(0) { $0 + $1.buyPrice })
    }

    // MARK: - Wallets

    func addWallet(_ wallet: Wallet) { data.wallets.append(wallet); save() }

    /// `wallet.balance` here is what the user typed as the balance today. The
    /// opening figure stays; the difference is booked as an adjustment, so the
    /// transactions still explain the rest.
    func updateWallet(_ wallet: Wallet, oldName: String) {
        guard let ix = data.wallets.firstIndex(where: { $0.id == wallet.id }) else { return }
        let current = Finance.balance(of: data.wallets[ix], data)
        let delta = wallet.balance - current
        var kept = wallet
        kept.balance = data.wallets[ix].balance
        data.wallets[ix] = kept
        if oldName != wallet.name { renameAccount(oldName, to: wallet.name) }
        if delta != 0 {
            addTransaction(Transaction(date: .now, amount: delta, kind: .adjustment, account: wallet.name,
                                       note: String(localized: "Balance corrected")), applyRules: false)
        }
        if delta != 0 {
            log(label: wallet.name, detail: String(localized: "Balance corrected"), amount: delta,
                kind: delta > 0 ? "in" : "out")
        }
        save()
    }

    func deleteWallet(_ wallet: Wallet) {
        data.wallets.removeAll { $0.id == wallet.id }
        log(label: wallet.name, detail: String(localized: "Wallet removed"), amount: -wallet.balance, kind: "out")
        save()
    }

    /// Wallet to wallet. The source loses the full amount, the destination
    /// receives amount − fee (¥210 for a Mercari/Rakuma bank withdrawal).
    func transfer(from: String, to: String, amount: Int, fee: Int, on date: Date = .now) {
        guard from != to, amount > 0 else { return }
        var list = data.transactions ?? []
        list.append(Transaction(date: date, amount: amount - fee, kind: .move, account: from, toAccount: to,
                                merchant: String(localized: "Transfer")))
        if fee > 0 {
            list.append(Transaction(date: date, amount: -fee, kind: .spend, account: from,
                                    merchant: String(localized: "Transfer fee"), category: "Other"))
        }
        data.transactions = list
        let detail = fee > 0 ? String(localized: "\(from) → \(to) · fee \(format(fee))") : "\(from) → \(to)"
        log(label: String(localized: "Wallet transfer"), detail: detail, amount: amount, kind: "x")
        save()
    }

    // MARK: - Point wallets

    func addPointWallet(_ pw: PointWallet) { data.pointWallets.append(pw); save() }

    func updatePointWallet(_ pw: PointWallet, oldName: String) {
        guard let ix = data.pointWallets.firstIndex(where: { $0.id == pw.id }) else { return }
        data.pointWallets[ix] = pw
        save()
    }

    func deletePointWallet(_ pw: PointWallet) {
        data.pointWallets.removeAll { $0.id == pw.id }
        save()
    }

    // MARK: - Cards

    /// A card added with a balance already on it books that balance as an
    /// opening entry, so the activity log explains where the debt came from.
    func addCard(_ card: CreditCard) {
        var card = card
        card.statementDate = Finance.cycle(for: card, data).lastClosing
        data.cards.append(card)
        if card.debt > 0 {
            log(label: card.name, detail: String(localized: "Card added · opening balance"), amount: -card.debt, kind: "out")
        }
        save()
    }

    /// Renaming a card carries the items bought on it, so their purchases stay
    /// attached to the debt they created.
    func updateCard(_ card: CreditCard, oldName: String) {
        guard let ix = data.cards.firstIndex(where: { $0.id == card.id }) else { return }
        let delta = card.debt - Finance.cycle(for: data.cards[ix], data).statementAmount
        var card = card
        // A figure typed now is the statement that closed last, as of now.
        if delta != 0 || card.closingDay != data.cards[ix].closingDay {
            card.statementDate = Finance.cycle(for: card, data).lastClosing
        }
        data.cards[ix] = card
        if oldName != card.name {
            for i in data.items.indices where data.items[i].cardName == oldName {
                data.items[i].cardName = card.name
            }
            renameAccount(oldName, to: card.name)
        }
        if delta != 0 {
            log(label: card.name, detail: String(localized: "Debt corrected"), amount: delta, kind: delta > 0 ? "out" : "in")
        }
        save()
    }

    /// Items bought on a deleted card keep their history but lose the link —
    /// their purchase can no longer add to a debt that does not exist.
    func deleteCard(_ card: CreditCard) {
        data.cards.removeAll { $0.id == card.id }
        for i in data.items.indices where data.items[i].cardName == card.name {
            data.items[i].cardName = ""
        }
        // A bill that rode on this card now leaves cash on its own day.
        renameAccount(card.name, to: "")
        log(label: card.name, detail: String(localized: "Card removed"), amount: 0, kind: "x")
        save()
    }

    // MARK: - Owners

    func addOwner(_ owner: Owner) { data.owners.append(owner); save() }

    func updateOwner(_ owner: Owner) {
        guard let ix = data.owners.firstIndex(where: { $0.id == owner.id }) else { return }
        data.owners[ix] = owner
        save()
    }

    /// "Me" is structural — the drawdown splits mine / on behalf by it — and an
    /// owner still holding cards or wallets cannot be removed without orphaning
    /// them. Returns the reason it refused, or nil on success.
    @discardableResult
    func deleteOwner(_ owner: Owner) -> String? {
        if owner.id == "me" { return String(localized: "\"Me\" cannot be removed.") }
        let cards = data.cards.filter { $0.ownerID == owner.id }.count
        let wallets = data.wallets.filter { $0.ownerID == owner.id }.count
        if cards + wallets > 0 {
            return String(localized: "\(owner.name) still holds \(cards) cards and \(wallets) wallets. Move or delete those first.")
        }
        data.owners.removeAll { $0.id == owner.id }
        save()
        return nil
    }

    // MARK: - Channels

    func addChannel(_ ch: SalesChannel) { data.channels.append(ch); save() }

    func updateChannel(_ ch: SalesChannel, oldName: String) {
        guard let ix = data.channels.firstIndex(where: { $0.id == ch.id }) else { return }
        data.channels[ix] = ch
        if oldName != ch.name {
            for i in data.items.indices where data.items[i].plannedChannel == oldName {
                data.items[i].plannedChannel = ch.name
            }
        }
        save()
    }

    func deleteChannel(_ ch: SalesChannel) {
        data.channels.removeAll { $0.id == ch.id }
        save()
    }

    // MARK: - Categories

    func addCategory(_ category: Category) {
        guard !data.categories.contains(where: { $0.name == category.name }) else { return }
        data.categories.append(category)
        save()
    }

    /// Names used by items that are not categories yet — what an import leaves
    /// behind when the sheet names something this book has never had.
    var looseCategoryNames: [String] {
        let defined = Set(data.categories.map(\.name))
        let used = data.items.map(\.categoryName).filter { !$0.isEmpty }
        return Array(Set(used).subtracting(defined)).sorted()
    }

    func deleteCategory(_ category: Category) {
        data.categories.removeAll { $0.id == category.id }
        for i in data.items.indices where data.items[i].categoryName == category.name {
            data.items[i].categoryName = ""
        }
        save()
    }

    // MARK: - Recurring

    var recurring: [Recurring] { data.recurring ?? [] }
    /// Incomes first, then bills, each by day of month.
    var recurringByDay: [Recurring] {
        recurring.sorted {
            if $0.isIncome != $1.isIncome { return $0.isIncome }
            return $0.day < $1.day
        }
    }
    /// Names a bill can be paid by: every wallet, then every card. A card-paid
    /// bill rides on the card's statement instead of leaving cash on its day.
    var payers: [String] { data.wallets.map(\.name) + data.cards.map(\.name) }
    func isCard(_ name: String) -> Bool { data.cards.contains { $0.name == name } }

    func addRecurring(_ r: Recurring) {
        var list = recurring
        list.append(r)
        data.recurring = list
        save()
    }

    func updateRecurring(_ r: Recurring) {
        guard var list = data.recurring, let ix = list.firstIndex(where: { $0.id == r.id }) else { return }
        list[ix] = r
        data.recurring = list
        save()
    }

    func deleteRecurring(_ r: Recurring) {
        var list = recurring
        list.removeAll { $0.id == r.id }
        data.recurring = list
        save()
    }

    /// Bills, transactions, cards and plans point at an account by name; a
    /// rename carries them all along. Renaming to "" unlinks them.
    func renameAccount(_ old: String, to new: String) {
        guard !old.isEmpty, old != new else { return }
        if var list = data.recurring {
            for i in list.indices where list[i].paidBy == old { list[i].paidBy = new }
            data.recurring = list
        }
        guard !new.isEmpty else { return }
        if var list = data.transactions {
            for i in list.indices {
                if list[i].account == old { list[i].account = new }
                if list[i].toAccount == old { list[i].toAccount = new }
            }
            data.transactions = list
        }
        for i in data.cards.indices where data.cards[i].payFrom == old { data.cards[i].payFrom = new }
        if var plans = data.installments {
            for i in plans.indices where plans[i].payFrom == old { plans[i].payFrom = new }
            data.installments = plans
        }
    }

    func setSafetyBuffer(_ amount: Int) { data.safetyBuffer = max(0, amount); save() }

    // MARK: - Snapshots

    /// One per month, taken when the app opens: the only way "richer or poorer
    /// than last month" can be answered from typed balances. Nothing to type.
    func takeMonthlySnapshotIfDue(today: Date = .now) {
        let cal = Calendar.current
        var list = data.snapshots ?? []
        if list.contains(where: { cal.isDate($0.date, equalTo: today, toGranularity: .month) }) { return }
        list.append(Finance.snapshot(data, today: today))
        if list.count > 36 { list.removeFirst(list.count - 36) }
        data.snapshots = list
        save()
    }

    // MARK: - Loans

    func addLoan(_ loan: Loan) { data.loans.append(loan); save() }

    /// Recording a repayment shrinks the outstanding balance and, for yen loans
    /// settled through a wallet, moves the cash too.
    func repayLoan(_ loan: Loan, amount: Int, wallet walletName: String?) {
        guard amount > 0, let ix = data.loans.firstIndex(where: { $0.id == loan.id }) else { return }
        let paid = min(amount, data.loans[ix].amount)
        data.loans[ix].amount -= paid
        let text = loan.currency == "JPY" ? format(paid) : "\(paid.formatted()) ₫"
        data.loans[ix].history.insert(
            LoanEvent(date: .now, title: loan.direction > 0 ? "They paid back" : "You paid back", amount: text),
            at: 0)

        if let walletName, data.wallets.contains(where: { $0.name == walletName }) {
            // They pay you back: cash in. You pay them back: cash out. Either
            // way it is money you were owed or owed, not income or spending.
            var list = data.transactions ?? []
            list.append(loan.direction > 0
                ? Transaction(date: .now, amount: paid, kind: .move, account: loan.person, toAccount: walletName, merchant: loan.person)
                : Transaction(date: .now, amount: paid, kind: .move, account: walletName, toAccount: loan.person, merchant: loan.person))
            data.transactions = list
            log(label: loan.person, detail: loan.direction > 0 ? String(localized: "Loan repaid to you") : String(localized: "Loan repaid by you"),
                amount: loan.direction > 0 ? paid : -paid, kind: loan.direction > 0 ? "in" : "out")
        }
        save()
    }

    func deleteLoan(_ loan: Loan) {
        data.loans.removeAll { $0.id == loan.id }
        save()
    }

    // MARK: - Ledger

    func log(date: Date = .now, label: String, detail: String, amount: Int, kind: String) {
        data.ledger.insert(LedgerEntry(date: date, label: label, detail: detail,
                                       amount: amount, kind: kind), at: 0)
        if data.ledger.count > 500 { data.ledger.removeLast(data.ledger.count - 500) }
    }

    // MARK: - Demo data / reset

    func loadDemoData() {
        data = .sample
        // The sample starts 70 days back; its salary, bills, card payments
        // and plan debits since then are posted the way a real book's are.
        postDueSchedules()
        // This month's reading, as a launch on a real book takes it, so the
        // net worth line ends at today's figure.
        takeMonthlySnapshotIfDue()
        save()
    }

    /// Erase means erase: back to the fresh-install book, which is empty.
    func resetEverything() {
        data = .empty
        save()
    }

    // MARK: - Export

    enum ExportFormat: String, CaseIterable { case tsv, csv }
    enum ExportScope: String, CaseIterable { case all, forSale, sold }

    static let exportColumns = ["Name", "Category", "Status", "Date", "Buy", "Bought from",
                                "Card", "Est", "Channel", "Sold price", "Sold date", "Net",
                                "Profit", "Accessories", "Condition", "Attributes"]

    /// Everything an import can read, in reading order. Two more than Export
    /// writes: Shipping and Points come in from a sheet but are not exported,
    /// and leaving them out here made the screen say a column was ignored when
    /// it had in fact been read.
    static let importColumns = ["Name", "Category", "Status", "Date", "Buy", "Bought from",
                                "Card", "Points", "Est", "Channel", "Shipping",
                                "Sold price", "Sold date", "Net", "Profit",
                                "Accessories", "Condition", "Attributes"]

    func exportText(format: ExportFormat, scope: ExportScope) -> String {
        let df = DateFormatter(); df.dateFormat = "d/M/yyyy"
        let rows = data.items.filter {
            switch scope {
            case .all: return true
            case .sold: return $0.isSold
            case .forSale: return !$0.isSold && !$0.keep
            }
        }
        let sep = format == .csv ? "," : "\t"
        func cell(_ v: Any) -> String {
            let s = String(describing: v)
            if format == .csv, s.contains(where: { ",\"\n".contains($0) }) {
                return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return s.replacingOccurrences(of: "\t", with: " ")
        }
        let body = rows.map { i -> String in
            let net = i.sale?.net ?? netProceeds(i, channelName: i.plannedChannel)
            let status = i.isSold ? "sold" : (i.keep ? "keep" : "for sale")
            let cells: [Any] = [i.name, i.categoryName, status, df.string(from: i.boughtOn),
                                i.buyPrice, i.boughtFrom, i.cardName, i.estimatedPrice, i.plannedChannel,
                                i.sale?.shipping ?? shipping(i),
                                i.sale?.price ?? "", i.sale.map { df.string(from: $0.date) } ?? "",
                                net, net - i.buyPrice, i.accessories, i.condition,
                                i.attributes.map { "\($0[0])=\($0.count > 1 ? $0[1] : "")" }.joined(separator: "; ")]
            return cells.map(cell).joined(separator: sep)
        }
        return ([Store.exportColumns.joined(separator: sep)] + body).joined(separator: "\n")
    }

    // MARK: - Persistence (one local file, daily copies beside it)

    /// Application Support is not created for you on iOS. Writing into it
    /// without creating it first fails silently — which is how a book of
    /// finances quietly resets itself on every launch.
    private var localURL: URL? {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        if !fm.fileExists(atPath: dir.path) {
            do { try fm.createDirectory(at: dir, withIntermediateDirectories: true) }
            catch { saveError = String(localized: "Could not create the data folder: \(error.localizedDescription)"); return nil }
        }
        return dir.appendingPathComponent(fileName)
    }

    /// True after `load` could not read the file. Saves still go to disk so the
    /// app works, but the unreadable original has been copied aside first, so
    /// one bad build cannot take the only copy down with it.
    private(set) var loadFailed = false
    /// What the file on disk holds, so a save that changes nothing (a form
    /// re-emitting the value it was given) does not write or make a daily copy.
    private var lastWritten: Data?

    func save() {
        guard let url = localURL else { return }
        do {
            let blob = try JSONEncoder().encode(data)
            guard blob != lastWritten else { return }
            keepDailyCopy(of: url)
            try blob.write(to: url, options: .atomic)
            lastWritten = blob
            publishWidgetSnapshot()
            if !loadFailed { saveError = nil }
        } catch {
            saveError = String(localized: "Could not save: \(error.localizedDescription)")
        }
    }

    func load() {
        guard let url = localURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let blob = try Data(contentsOf: url)
            data = try JSONDecoder().decode(AppData.self, from: blob)
            lastWritten = blob
            loadFailed = false
            syncLanguageOverride()
        } catch {
            // A corrupt or older file must not be lost: copy it aside before
            // anything can overwrite it, keep the in-memory book, say so.
            loadFailed = true
            let rescue = url.deletingLastPathComponent().appendingPathComponent("mochi.unreadable.json")
            if !FileManager.default.fileExists(atPath: rescue.path) {
                try? FileManager.default.copyItem(at: url, to: rescue)
            }
            saveError = String(localized: "Saved data could not be read, so this is an empty book. The old file is kept as mochi.unreadable.json. \(error.localizedDescription)")
        }
    }

    // MARK: - Backups

    /// One copy of the book per day it changed, kept for `backupDays`. Taken
    /// from the file *before* the first write of the day, so yesterday's book
    /// survives anything today does to it — a bad build, a slip, a bad import.
    /// There is no cloud here: the app has no iCloud container, and a toggle
    /// that pretended otherwise cost a book once.
    private let backupDays = 30

    private var backupsDirectory: URL? {
        guard let dir = localURL?.deletingLastPathComponent() else { return nil }
        let folder = dir.appendingPathComponent("backups", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private static let dayFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    /// For the copy taken right before a restore: the day already has its
    /// copy, and that one is what is being gone back to.
    private static let stampFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f
    }()

    private func keepDailyCopy(of file: URL) {
        guard let folder = backupsDirectory, FileManager.default.fileExists(atPath: file.path) else { return }
        let today = folder.appendingPathComponent("mochi-\(Store.dayFormat.string(from: .now)).json")
        if !FileManager.default.fileExists(atPath: today.path) {
            try? FileManager.default.copyItem(at: file, to: today)
        }
        let extra = backups.dropFirst(backupDays)
        for old in extra { try? FileManager.default.removeItem(at: old.url) }
    }

    struct BackupFile: Identifiable {
        var id: String { url.lastPathComponent }
        let url: URL
        let day: Date
        /// true for the copy taken just before a restore; it carries a time.
        let timed: Bool
        let bytes: Int
        var label: String {
            timed ? day.formatted(date: .abbreviated, time: .shortened) : day.formatted(date: .abbreviated, time: .omitted)
        }
    }

    /// Newest first.
    var backups: [BackupFile] {
        guard let folder = backupsDirectory,
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        return names.compactMap { name -> BackupFile? in
            guard name.hasPrefix("mochi-"), name.hasSuffix(".json") else { return nil }
            let stem = String(name.dropFirst(6).dropLast(5))
            let timed = Store.stampFormat.date(from: stem)
            guard let day = timed ?? Store.dayFormat.date(from: stem) else { return nil }
            let url = folder.appendingPathComponent(name)
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            return BackupFile(url: url, day: day, timed: timed != nil, bytes: size)
        }
        .sorted { $0.day > $1.day }
    }

    /// Replaces the book with the file at `url`. The book as it stands is
    /// copied into today's backup first, so a wrong pick can be undone the
    /// same way. false when the file is not a Mochi book.
    @discardableResult
    func replaceBook(with url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let blob = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(AppData.self, from: blob) else { return false }
        if let current = localURL, let folder = backupsDirectory, FileManager.default.fileExists(atPath: current.path) {
            let stamp = folder.appendingPathComponent("mochi-\(Store.stampFormat.string(from: .now)).json")
            try? FileManager.default.removeItem(at: stamp)
            try? FileManager.default.copyItem(at: current, to: stamp)
        }
        data = decoded
        loadFailed = false
        lastWritten = nil
        syncLanguageOverride()
        save()
        return true
    }

    /// The whole book as a file to hand to the share sheet: Files, AirDrop,
    /// iCloud Drive — wherever the user keeps things. nil if it cannot be written.
    func exportBookFile() -> URL? {
        guard let blob = try? JSONEncoder().encode(data) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mochi-book-\(Store.dayFormat.string(from: .now)).json")
        do { try blob.write(to: url, options: .atomic) } catch { return nil }
        return url
    }
}
