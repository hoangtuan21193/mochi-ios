import Foundation
import Observation

/// Single source of truth. Everything the UI reads is derived here so the
/// numbers can never disagree between screens.
@Observable
final class Store {
    var data: AppData

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
        resolveICloudURL()
    }

    // MARK: - Money helpers

    var currency: Currency { Currency(rawValue: data.currency) ?? .jpy }

    func format(_ amount: Int) -> String {
        let sign = amount < 0 ? "-" : ""
        let n = abs(amount).formatted(.number.grouping(.automatic))
        let c = currency
        return c.symbolTrails ? "\(sign)\(n) \(c.symbol)" : "\(sign)\(c.symbol)\(n)"
    }

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

    /// What postage this item is expected to cost.
    func shipping(_ item: Item) -> Int { item.shippingFee ?? data.defaultShippingFee }

    /// The marketplace's cut alone, before postage.
    func commission(_ item: Item, channelName: String, price: Int? = nil) -> Int {
        guard let ch = channel(named: channelName), !ch.isPoints else { return 0 }
        return Int(Double(price ?? item.estimatedPrice) * (ch.rate / 100))
    }

    /// What a sale of `item` through `channelName` actually puts in a wallet
    /// (or in points, for a point channel).
    ///
    /// On a cash channel postage comes out of the payout, the way Mercari and
    /// Rakuma actually settle. A point channel credits its points in full and
    /// the postage is booked separately as cash leaving a wallet, because
    /// points and yen are not the same pocket.
    func netProceeds(_ item: Item, channelName: String, price: Int? = nil) -> Int {
        let listed = price ?? item.estimatedPrice
        guard let ch = channel(named: channelName) else { return listed }
        if ch.isPoints {
            let rate = item.pointRateOverride ?? ch.rate
            return Int(Double(listed) * (1 + rate / 100))
        }
        return Int(Double(listed) * (1 - ch.rate / 100)) - shipping(item)
    }

    /// What the sale leaves you once the item's own cost is counted. Postage on
    /// a point sale is a cash cost that the point credit never covers.
    func expectedProfit(_ item: Item, channelName: String, price: Int? = nil) -> Int {
        let net = netProceeds(item, channelName: channelName, price: price)
        let postageOnPoints = channel(named: channelName)?.isPoints == true ? shipping(item) : 0
        return net - item.buyPrice - postageOnPoints
    }

    // MARK: - Derived totals

    var unsold: [Item] { data.items.filter { !$0.isSold } }
    var forSale: [Item] { unsold.filter { !$0.keep } }
    var keeping: [Item] { unsold.filter { $0.keep } }

    /// Every wallet is cash. Points are not.
    var cash: Int { data.wallets.reduce(0) { $0 + $1.balance } }
    var debt: Int { data.cards.reduce(0) { $0 + $1.debt } }
    /// The headline number: what you would have if every card bill came due
    /// today and every instalment plan were settled at once. A plan with fifty
    /// months to run is still money you owe.
    var realCash: Int { cash - debt - installmentDebt }

    /// Proceeds if every item marked for sale sold at its estimate through its
    /// planned channel. Items marked "keep" are excluded.
    var liquidation: Int { forSale.reduce(0) { $0 + netProceeds($1, channelName: $1.plannedChannel) } }
    var cashAfterSellingAll: Int { realCash + liquidation }

    var inventoryCost: Int { forSale.reduce(0) { $0 + $1.buyPrice } }
    /// Postage already comes out of a cash payout; on a point sale it is a cash
    /// cost sitting outside the points, so it is subtracted here.
    private var postageOnPointSales: Int {
        forSale.filter { channel(named: $0.plannedChannel)?.isPoints == true }
            .reduce(0) { $0 + shipping($1) }
    }
    var expectedProfit: Int { liquidation - inventoryCost - postageOnPointSales }

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
    /// when several cameras were each bought on sixty months.
    var installmentDebt: Int { installments.reduce(0) { $0 + $1.remaining() } }

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
            detail: metaLine("Instalment plan", plan.lender, "\(plan.months) months"),
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

    /// A lump sum paid ahead of the schedule. Cash leaves the wallet named, if
    /// any; the plan's months fall away from the end.
    func prepayInstallment(_ plan: Installment, amount: Int, from walletName: String?) {
        guard amount > 0, let ix = installments.firstIndex(where: { $0.id == plan.id }) else { return }
        var list = installments
        let paid = min(amount, list[ix].remaining())
        guard paid > 0 else { return }
        list[ix].extraPaid += paid
        if list[ix].remaining() == 0 { list[ix].closed = true }
        data.installments = list
        if let walletName, let wix = data.wallets.firstIndex(where: { $0.name == walletName }) {
            data.wallets[wix].balance -= paid
        }
        log(label: plan.name, detail: metaLine("Paid early", walletName ?? ""), amount: -paid, kind: "out")
        save()
    }

    func deleteInstallment(_ plan: Installment) {
        var list = installments
        list.removeAll { $0.id == plan.id }
        data.installments = list
        log(label: plan.name, detail: "Instalment plan removed", amount: 0, kind: "x")
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
        case 0: return "due today"
        case 1: return "due tomorrow"
        case let n: return "in \(n) days"
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

    /// Due dates in payment order, treating a day before the 15th as next month.
    var dueDays: [Int] {
        Set(data.cards.map(\.dueDay)).sorted {
            ($0 < 15 ? $0 + 31 : $0) < ($1 < 15 ? $1 + 31 : $1)
        }
    }

    struct DueCycle: Identifiable {
        var id: Int { day }
        let day: Int
        let cards: [CreditCard]
        let total: Int
        let mine: Int
        let onBehalf: Int
        /// Cash left after paying this date, running down from today's cash.
        let cashAfter: Int
        var isShort: Bool { cashAfter < 0 }
    }

    /// The Overview drawdown: cash minus each due date in turn.
    var dueCycles: [DueCycle] {
        var running = cash
        return dueDays.map { day in
            let cs = data.cards.filter { $0.dueDay == day }
            let mine = cs.filter { $0.ownerID == "me" }.reduce(0) { $0 + $1.debt }
            let other = cs.filter { $0.ownerID != "me" }.reduce(0) { $0 + $1.debt }
            let total = mine + other
            running -= total
            return DueCycle(day: day, cards: cs.filter { $0.debt > 0 }, total: total,
                            mine: mine, onBehalf: other, cashAfter: running)
        }
    }

    /// Highest-net items first, until the shortfall is covered. Empty when cash
    /// already covers every bill — the Overview hides the card in that case.
    var sellSuggestions: [Item] {
        var need = max(0, debt - cash)
        guard need > 0 else { return [] }
        var out: [Item] = []
        for item in forSale.sorted(by: { netProceeds($0, channelName: $0.plannedChannel) > netProceeds($1, channelName: $1.plannedChannel) }) {
            if need <= 0 { break }
            out.append(item)
            need -= netProceeds(item, channelName: item.plannedChannel)
        }
        return out
    }

    // MARK: - Items

    /// Buying on a card raises that card's debt by the purchase price.
    func addItem(_ item: Item) {
        data.items.insert(item, at: 0)
        if let ix = data.cards.firstIndex(where: { $0.name == item.cardName }) {
            data.cards[ix].debt += item.buyPrice
        }
        log(date: item.boughtOn, label: item.name, detail: metaLine("Bought", item.cardName),
            amount: -item.buyPrice, kind: "out")
        save()
    }

    /// Editing an item's price or card has to move the card debt with it,
    /// otherwise the debt total drifts away from what was actually charged.
    func update(_ item: Item) {
        guard let ix = data.items.firstIndex(where: { $0.id == item.id }) else { return }
        let old = data.items[ix]
        if !old.isSold {
            if old.cardName == item.cardName {
                let delta = item.buyPrice - old.buyPrice
                if delta != 0, let c = cardIndex(old.cardName) { data.cards[c].debt += delta }
            } else {
                if let c = cardIndex(old.cardName) { data.cards[c].debt -= old.buyPrice }
                if let c = cardIndex(item.cardName) { data.cards[c].debt += item.buyPrice }
            }
        }
        data.items[ix] = item
        save()
    }

    /// Deleting an unsold item reverses the purchase: the card debt it created
    /// goes away with it. A sold item keeps its money — only the record goes.
    func deleteItem(_ item: Item) {
        guard let ix = data.items.firstIndex(where: { $0.id == item.id }) else { return }
        if !item.isSold, let c = cardIndex(item.cardName) {
            data.cards[c].debt -= item.buyPrice
        }
        data.items.remove(at: ix)
        // The plan that paid for it stays — the debt does not leave with the
        // record — but it no longer points at an item that is not there.
        if var list = data.installments,
           let pix = list.firstIndex(where: { $0.itemID == item.id }) {
            list[pix].itemID = nil
            data.installments = list
        }
        log(label: item.name, detail: "Item deleted", amount: 0, kind: "x")
        save()
    }

    /// Confirming a sale: record it, then credit the destination wallet
    /// (or the point wallet named by the channel, for a point channel).
    func sell(_ item: Item, channelName: String, price: Int? = nil) {
        guard let ix = data.items.firstIndex(where: { $0.id == item.id }) else { return }
        let listed = price ?? item.estimatedPrice
        var copy = item
        copy.estimatedPrice = listed
        let net = netProceeds(copy, channelName: channelName)
        let ch = channel(named: channelName)
        let postage = shipping(item)
        data.items[ix].sale = SaleRecord(price: listed, channel: channelName, net: net,
                                         date: .now, shipping: postage)
        credit(net, channel: ch)

        // On a cash channel the postage is already inside `net`. On a point
        // channel it is real money leaving a real wallet.
        if ch?.isPoints == true, postage > 0, let wix = data.wallets.indices.max(by: {
            data.wallets[$0].balance < data.wallets[$1].balance
        }) {
            data.wallets[wix].balance -= postage
            log(label: item.name, detail: "Postage · \(data.wallets[wix].name)",
                amount: -postage, kind: "out")
        }
        log(label: item.name, detail: "Sold · \(channelName)", amount: net, kind: "in")
        save()
    }

    /// Undo a sale — the money comes back out of wherever it landed.
    func unsell(_ item: Item) {
        guard let ix = data.items.firstIndex(where: { $0.id == item.id }),
              let sale = data.items[ix].sale else { return }
        credit(-sale.net, channel: channel(named: sale.channel))
        if channel(named: sale.channel)?.isPoints == true, sale.shipping > 0,
           let wix = data.wallets.indices.max(by: {
               data.wallets[$0].balance < data.wallets[$1].balance
           }) {
            data.wallets[wix].balance += sale.shipping
        }
        data.items[ix].sale = nil
        log(label: item.name, detail: "Sale undone · \(sale.channel)", amount: -sale.net, kind: "out")
        save()
    }

    /// Move a sale's proceeds into the right pocket. Point channels pay into the
    /// point wallet the channel names as its destination — never into cash.
    private func credit(_ net: Int, channel ch: SalesChannel?) {
        guard let ch else { return }
        if ch.isPoints {
            if let pix = pointWalletIndex(ch.destination) {
                data.pointWallets[pix].points += net
            }
        } else {
            let dest = ch.destination.isEmpty ? (data.wallets.first?.name ?? "") : ch.destination
            if let wix = data.wallets.firstIndex(where: { $0.name == dest }) {
                data.wallets[wix].balance += net
            }
        }
    }

    private func cardIndex(_ name: String) -> Int? { data.cards.firstIndex { $0.name == name } }
    private func pointWalletIndex(_ name: String) -> Int? {
        guard !name.isEmpty else { return nil }
        return data.pointWallets.firstIndex { $0.name == name }
    }

    // MARK: - Wallets

    func addWallet(_ wallet: Wallet) { data.wallets.append(wallet); save() }

    /// Renaming cascades into the channels that pay into this wallet, so a
    /// rename never orphans a sale destination.
    func updateWallet(_ wallet: Wallet, oldName: String) {
        guard let ix = data.wallets.firstIndex(where: { $0.id == wallet.id }) else { return }
        let delta = wallet.balance - data.wallets[ix].balance
        data.wallets[ix] = wallet
        if oldName != wallet.name {
            for i in data.channels.indices where data.channels[i].destination == oldName {
                data.channels[i].destination = wallet.name
            }
        }
        if delta != 0 {
            log(label: wallet.name, detail: "Balance corrected", amount: delta,
                kind: delta > 0 ? "in" : "out")
        }
        save()
    }

    func deleteWallet(_ wallet: Wallet) {
        data.wallets.removeAll { $0.id == wallet.id }
        for i in data.channels.indices where data.channels[i].destination == wallet.name {
            data.channels[i].destination = ""
        }
        log(label: wallet.name, detail: "Wallet removed", amount: -wallet.balance, kind: "out")
        save()
    }

    /// Wallet to wallet. The source loses the full amount, the destination
    /// receives amount − fee (¥210 for a Mercari/Rakuma bank withdrawal).
    func transfer(from: String, to: String, amount: Int, fee: Int) {
        guard from != to, amount > 0 else { return }
        if let f = data.wallets.firstIndex(where: { $0.name == from }) { data.wallets[f].balance -= amount }
        if let t = data.wallets.firstIndex(where: { $0.name == to }) { data.wallets[t].balance += (amount - fee) }
        let detail = fee > 0 ? "\(from) → \(to) · 手数料 \(format(fee))" : "\(from) → \(to)"
        log(label: "Wallet transfer", detail: detail, amount: amount, kind: "x")
        save()
    }

    // MARK: - Point wallets

    func addPointWallet(_ pw: PointWallet) { data.pointWallets.append(pw); save() }

    func updatePointWallet(_ pw: PointWallet, oldName: String) {
        guard let ix = data.pointWallets.firstIndex(where: { $0.id == pw.id }) else { return }
        data.pointWallets[ix] = pw
        if oldName != pw.name {
            for i in data.channels.indices where data.channels[i].isPoints && data.channels[i].destination == oldName {
                data.channels[i].destination = pw.name
            }
        }
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
        data.cards.append(card)
        if card.debt > 0 {
            log(label: card.name, detail: "Card added · opening balance", amount: -card.debt, kind: "out")
        }
        save()
    }

    /// Renaming a card carries the items bought on it, so their purchases stay
    /// attached to the debt they created.
    func updateCard(_ card: CreditCard, oldName: String) {
        guard let ix = data.cards.firstIndex(where: { $0.id == card.id }) else { return }
        let delta = card.debt - data.cards[ix].debt
        data.cards[ix] = card
        if oldName != card.name {
            for i in data.items.indices where data.items[i].cardName == oldName {
                data.items[i].cardName = card.name
            }
        }
        if delta != 0 {
            log(label: card.name, detail: "Debt corrected", amount: delta, kind: delta > 0 ? "out" : "in")
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
        log(label: card.name, detail: "Card removed", amount: 0, kind: "x")
        save()
    }

    /// Paying a bill is the other half of the loop: cash leaves a wallet and the
    /// card's debt drops by the same amount. Partial payments are allowed.
    func payCard(_ card: CreditCard, amount: Int, from walletName: String) {
        guard amount > 0, let cix = data.cards.firstIndex(where: { $0.id == card.id }) else { return }
        let paid = min(amount, data.cards[cix].debt)
        guard paid > 0 else { return }
        data.cards[cix].debt -= paid
        if let wix = data.wallets.firstIndex(where: { $0.name == walletName }) {
            data.wallets[wix].balance -= paid
        }
        log(label: "Paid \(card.name)", detail: walletName, amount: -paid, kind: "out")
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
        if owner.id == "me" { return "\"Me\" cannot be removed." }
        let cards = data.cards.filter { $0.ownerID == owner.id }.count
        let wallets = data.wallets.filter { $0.ownerID == owner.id }.count
        if cards + wallets > 0 {
            return "\(owner.name) still holds \(cards) card(s) and \(wallets) wallet(s). Move or delete those first."
        }
        data.owners.removeAll { $0.id == owner.id }
        save()
        return nil
    }

    // MARK: - Channels

    /// The wallet a channel pays into, made on the spot. A marketplace holds
    /// the money until it is withdrawn, so its balance starts at zero and reads
    /// "not withdrawn" — the same shape the sample book gives Mercari. Returns
    /// the name so the caller can point the channel at it. No-op if a wallet
    /// (or point wallet) of that name already exists.
    @discardableResult
    func makeDestination(for ch: SalesChannel) -> String {
        let name = SalesChannel.defaultDestinationName(for: ch.name, isPoints: ch.isPoints)
        if ch.isPoints {
            if !data.pointWallets.contains(where: { $0.name == name }) {
                data.pointWallets.append(PointWallet(name: name, points: 0, note: "from \(ch.name) sales"))
            }
        } else if !data.wallets.contains(where: { $0.name == name }) {
            data.wallets.append(Wallet(name: name, balance: 0, note: "not withdrawn"))
        }
        return name
    }

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

        if let walletName, let wix = data.wallets.firstIndex(where: { $0.name == walletName }) {
            // They pay you back: cash in. You pay them back: cash out.
            data.wallets[wix].balance += loan.direction > 0 ? paid : -paid
            log(label: loan.person, detail: loan.direction > 0 ? "Loan repaid to you" : "Loan repaid by you",
                amount: loan.direction > 0 ? paid : -paid, kind: loan.direction > 0 ? "in" : "out")
        }
        save()
    }

    func deleteLoan(_ loan: Loan) {
        data.loans.removeAll { $0.id == loan.id }
        save()
    }

    // MARK: - Ledger

    private func log(date: Date = .now, label: String, detail: String, amount: Int, kind: String) {
        data.ledger.insert(LedgerEntry(date: date, label: label, detail: detail,
                                       amount: amount, kind: kind), at: 0)
        if data.ledger.count > 500 { data.ledger.removeLast(data.ledger.count - 500) }
    }

    var recentLedger: [LedgerEntry] {
        data.ledger.sorted { $0.date > $1.date }
    }

    // MARK: - Demo data / reset

    func loadDemoData() {
        data = .sample
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

    // MARK: - Persistence (local file + iCloud Documents copy)

    /// Application Support is not created for you on iOS. Writing into it
    /// without creating it first fails silently — which is how a book of
    /// finances quietly resets itself on every launch.
    private var localURL: URL? {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        if !fm.fileExists(atPath: dir.path) {
            do { try fm.createDirectory(at: dir, withIntermediateDirectories: true) }
            catch { saveError = "Could not create the data folder: \(error.localizedDescription)"; return nil }
        }
        return dir.appendingPathComponent(fileName)
    }

    /// nil when the user is not signed into iCloud or the container is missing.
    /// `url(forUbiquityContainerIdentifier:)` can take seconds and must never be
    /// called on the main thread, so it is resolved once in the background and
    /// cached; backups before it resolves simply no-op.
    private var cachedICloudURL: URL?
    private var iCloudResolved = false

    private var iCloudURL: URL? { cachedICloudURL }

    private func resolveICloudURL() {
        guard !iCloudResolved else { return }
        iCloudResolved = true
        let name = fileName
        Task.detached(priority: .utility) {
            let url = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents").appendingPathComponent(name)
            await MainActor.run { [weak self] in self?.cachedICloudURL = url }
        }
    }

    func save() {
        guard let url = localURL else { return }
        do {
            let blob = try JSONEncoder().encode(data)
            try blob.write(to: url, options: .atomic)
            saveError = nil
            if data.autoBackup { backupToCloud(blob) }
        } catch {
            saveError = "Could not save: \(error.localizedDescription)"
        }
    }

    func load() {
        guard let url = localURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            data = try JSONDecoder().decode(AppData.self, from: Data(contentsOf: url))
            syncLanguageOverride()
        } catch {
            // A corrupt or older file must not wipe what is on disk: keep the
            // in-memory book, surface the problem, leave the file untouched.
            saveError = "Saved data could not be read: \(error.localizedDescription)"
        }
    }

    func backupNow() {
        guard let blob = try? JSONEncoder().encode(data) else { return }
        backupToCloud(blob)
    }

    private func backupToCloud(_ blob: Data) {
        guard let url = iCloudURL else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try? blob.write(to: url, options: .atomic)
        data.lastBackup = .now
    }

    func restoreFromCloud() -> Bool {
        guard let url = iCloudURL, let blob = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(AppData.self, from: blob) else { return false }
        data = decoded
        syncLanguageOverride()
        save()
        return true
    }
}
