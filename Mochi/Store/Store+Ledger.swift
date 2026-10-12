import Foundation
import UIKit

/// Transactions, the schedules that post them, and the planning pieces that
/// read them. Every figure is still a `Finance` call; this file only writes.
extension Store {

    // MARK: - Starting and keeping the ledger

    /// A book from before transactions starts keeping them today. Its balances
    /// become the openings and nothing already typed is counted again.
    func startLedgerIfNeeded(today: Date = .now) {
        guard data.ledgerStart == nil else { return }
        let start = Calendar.current.startOfDay(for: today)
        data.ledgerStart = start
        data.postedThrough = Calendar.current.date(byAdding: .day, value: -1, to: start)
        if data.transactions == nil { data.transactions = [] }
        if data.spendingCategories == nil { data.spendingCategories = SpendingCategory.defaults }
        data.schemaVersion = max(data.schemaVersion, 2)
        save()
    }

    /// Salary, bills, card payments, plan debits and regular investments due
    /// since the app last looked. Called on launch and whenever it comes back
    /// to the front, so a balance moves on the day the money does.
    func postDueSchedules(today: Date = .now) {
        let due = Finance.duePostings(data, through: today)
        let day = Calendar.current.startOfDay(for: today)
        guard !due.isEmpty || data.postedThrough.map({ $0 < day }) == true else { return }
        var list = data.transactions ?? []
        list.append(contentsOf: due)
        data.transactions = list
        // A regular investment raises what the holding is worth and what has
        // gone into it; the broker's next statement corrects the value.
        for t in due where t.kind == .move {
            guard var invs = data.investments, let ix = invs.firstIndex(where: { $0.name == t.toAccount }) else { continue }
            invs[ix].value += t.amount
            invs[ix].contributed += t.amount
            invs[ix].contributedThisYear += t.amount
            data.investments = invs
        }
        data.postedThrough = day
        save()
    }

    // MARK: - Transactions

    var transactions: [Transaction] { data.transactions ?? [] }
    var spendingCategories: [SpendingCategory] { data.spendingCategories ?? SpendingCategory.defaults }
    var reviewCount: Int { transactions.filter(\.needsReview).count }
    var reviewQueue: Finance.ReviewQueue { Finance.reviewQueue(data) }
    func days(_ list: [Transaction]) -> [Finance.TransactionDay] { Finance.days(list) }

    /// Adds one, filling the category and account from a rule when the user
    /// left them for the book to decide.
    func addTransaction(_ t: Transaction, applyRules: Bool = true) {
        var t = t
        if applyRules { fill(&t) }
        var list = data.transactions ?? []
        list.append(t)
        data.transactions = list
        log(date: t.date, label: t.merchant.isEmpty ? t.kind.rawValue : t.merchant,
            detail: t.category, amount: t.amount, kind: t.amount < 0 ? "out" : "in")
        save()
    }

    func updateTransaction(_ t: Transaction) {
        guard var list = data.transactions, let ix = list.firstIndex(where: { $0.id == t.id }) else { return }
        list[ix] = t
        data.transactions = list
        save()
    }

    /// Takes the transaction and anything it created with it: the IOUs of a
    /// split, and its receipt photo.
    func deleteTransaction(_ t: Transaction) {
        data.transactions?.removeAll { $0.id == t.id }
        if let split = t.splitID {
            data.loans.removeAll { $0.history.contains { $0.id == split } }
        }
        if let file = t.receiptFile { deleteReceipt(file) }
        save()
    }

    func markReviewed(_ t: Transaction, category: String? = nil) {
        var t = t
        t.needsReview = false
        if let category { t.category = category }
        updateTransaction(t)
    }

    /// The rule for this shop or place, applied only where the user left a
    /// field empty: what they chose always wins over a rule.
    func fill(_ t: inout Transaction) {
        guard let r = Finance.rule(for: t.merchant, latitude: t.latitude, longitude: t.longitude, data) else { return }
        if t.category.isEmpty, !r.ask { t.category = r.category }
        if t.account.isEmpty, let a = r.account { t.account = a }
        if t.merchant.isEmpty { t.merchant = r.placeName }
    }

    /// The accounts a transaction can be on: wallets first, then cards.
    var accountNames: [String] { data.wallets.map(\.name) + data.cards.map(\.name) }

    func balance(of wallet: Wallet) -> Int { Finance.balance(of: wallet, data) }

    // MARK: - Belongings and their purchase

    /// A belonging bought since the book kept transactions was paid for from
    /// somewhere: that is booked as an asset purchase, so the card or wallet
    /// moves and Spending does not.
    func bookPurchase(of item: Item) {
        guard !item.cardName.isEmpty, !Finance.isLegacy(item.boughtOn, data) else { return }
        var list = data.transactions ?? []
        list.append(Transaction(date: item.boughtOn, amount: -item.buyPrice, kind: .asset,
                                account: item.cardName, merchant: item.boughtFrom, note: item.name,
                                itemID: item.id, receiptFile: item.receiptFile))
        data.transactions = list
    }

    /// Keeps the booked purchase in step with an edited item.
    func syncPurchase(of item: Item) {
        guard var list = data.transactions else { bookPurchase(of: item); return }
        if let ix = list.firstIndex(where: { $0.itemID == item.id && $0.kind == .asset }) {
            if item.cardName.isEmpty { list.remove(at: ix) } else {
                list[ix].amount = -item.buyPrice
                list[ix].date = item.boughtOn
                list[ix].account = item.cardName
                list[ix].merchant = item.boughtFrom
                list[ix].note = item.name
            }
            data.transactions = list
        } else {
            bookPurchase(of: item)
        }
    }

    /// Turns a line of a receipt into a belonging: the item, and the
    /// transaction that paid for it switched from spend to asset.
    func makeBelonging(from t: Transaction, name: String, worth: Int, points: Int, toResell: Bool) -> Item {
        var item = Item(name: name, boughtOn: t.date, buyPrice: -t.amount, boughtFrom: t.merchant,
                        cardName: t.account, pointsEarned: points, estimatedPrice: worth,
                        plannedChannel: data.channels.first?.name ?? "")
        item.receiptFile = t.receiptFile
        item.boughtToResell = toResell
        item.keep = !toResell
        item.valueHistory = [ValuePoint(date: t.date, value: worth)]
        data.items.insert(item, at: 0)
        var tx = t
        tx.kind = .asset
        tx.itemID = item.id
        tx.category = ""
        var list = data.transactions ?? []
        if let ix = list.firstIndex(where: { $0.id == t.id }) { list[ix] = tx } else { list.append(tx) }
        data.transactions = list
        save()
        return item
    }

    // MARK: - Splitting a bill

    /// Keeps your share as spending and turns everyone else's into money owed
    /// to you, one IOU per person, all linked back to this bill.
    func split(_ t: Transaction, myShare: Int, others: [(name: String, amount: Int)]) {
        var t = t
        let splitID = UUID().uuidString
        t.myShare = myShare
        t.splitID = splitID
        for o in others where o.amount > 0 {
            if let ix = data.loans.firstIndex(where: { $0.person == o.name && $0.direction > 0 && $0.currency == "JPY" }) {
                data.loans[ix].amount += o.amount
                data.loans[ix].history.insert(LoanEvent(id: splitID, date: t.date, title: t.merchant, amount: format(o.amount)), at: 0)
            } else {
                data.loans.append(Loan(person: o.name, direction: 1, amount: o.amount, currency: "JPY",
                                       history: [LoanEvent(id: splitID, date: t.date, title: t.merchant, amount: format(o.amount))]))
            }
        }
        if var list = data.transactions, let ix = list.firstIndex(where: { $0.id == t.id }) {
            list[ix] = t
            data.transactions = list
        } else {
            addTransaction(t, applyRules: false)
        }
        save()
    }

    // MARK: - Categories and rules

    func addSpendingCategory(_ c: SpendingCategory) {
        var list = spendingCategories
        guard !list.contains(where: { $0.name == c.name }) else { return }
        list.append(c)
        data.spendingCategories = list
        save()
    }

    func deleteSpendingCategory(_ c: SpendingCategory) {
        var list = spendingCategories
        list.removeAll { $0.id == c.id }
        data.spendingCategories = list
        if var txs = data.transactions {
            for i in txs.indices where txs[i].category == c.name { txs[i].category = "" }
            data.transactions = txs
        }
        save()
    }

    var rules: [Rule] { data.rules ?? [] }

    /// Adds a rule and fills in the transactions already in the book that it
    /// matches and the user has not categorised.
    func addRule(_ r: Rule) {
        var list = rules
        list.append(r)
        data.rules = list
        if var txs = data.transactions {
            for i in txs.indices where txs[i].category.isEmpty && txs[i].kind == .spend {
                if Finance.rule(for: txs[i].merchant, latitude: txs[i].latitude, longitude: txs[i].longitude, data)?.id == r.id {
                    txs[i].category = r.category
                }
            }
            data.transactions = txs
        }
        save()
    }

    func deleteRule(_ r: Rule) {
        data.rules?.removeAll { $0.id == r.id }
        save()
    }

    /// A category chosen for the same shop this many times is worth a rule.
    func suggestedRule(for merchant: String) -> Rule? {
        guard !merchant.isEmpty, Finance.rule(for: merchant, data) == nil else { return nil }
        let same = transactions.filter { $0.merchant == merchant && !$0.category.isEmpty }
        guard same.count >= 3, let top = Dictionary(grouping: same, by: \.category).max(by: { $0.value.count < $1.value.count }),
              top.value.count >= 3 else { return nil }
        return Rule(contains: merchant, category: top.key)
    }

    // MARK: - Plan

    var goals: [Goal] { data.goals ?? [] }
    func saveGoal(_ g: Goal) {
        var list = goals
        if let ix = list.firstIndex(where: { $0.id == g.id }) { list[ix] = g } else { list.append(g) }
        data.goals = list
        save()
    }
    func deleteGoal(_ g: Goal) { data.goals?.removeAll { $0.id == g.id }; save() }

    func setBudget(_ category: String, limit: Int) {
        var list = data.budgets ?? []
        list.removeAll { $0.category == category }
        if limit > 0 { list.append(BudgetLine(category: category, limit: limit)) }
        data.budgets = list
        save()
    }

    func answerStillUsing(_ r: Recurring, keep: Bool) {
        var r = r
        r.lastAsked = .now
        if !keep { r.active = false }
        updateRecurring(r)
    }

    var investments: [Investment] { data.investments ?? [] }
    func saveInvestment(_ i: Investment) {
        var list = investments
        if let ix = list.firstIndex(where: { $0.id == i.id }) { list[ix] = i } else { list.append(i) }
        data.investments = list
        save()
    }
    func deleteInvestment(_ i: Investment) { data.investments?.removeAll { $0.id == i.id }; save() }

    func setRate(_ code: String, _ rate: Double) {
        var r = data.rates ?? [:]
        r[code] = rate
        data.rates = r
        save()
    }

    var notificationPrefs: NotificationPrefs { data.notifications ?? NotificationPrefs() }
    func setNotificationPrefs(_ p: NotificationPrefs) { data.notifications = p; save() }

    var household: Household { data.household ?? Household() }
    func setHousehold(_ h: Household) { data.household = h; save() }

    func finishCheckin() { data.lastCheckin = .now; save() }

    // MARK: - Figures the new screens read

    var thisMonth: DateInterval { Calendar.current.dateInterval(of: .month, for: .now)! }
    var lastMonth: DateInterval {
        let start = Calendar.current.date(byAdding: .month, value: -1, to: thisMonth.start)!
        return Calendar.current.dateInterval(of: .month, for: start)!
    }
    func spending(in interval: DateInterval) -> Int { Finance.spending(data, in: interval) }
    func spendingByCategory(in interval: DateInterval) -> [Finance.Share] { Finance.spendingByCategory(data, in: interval) }
    func spendingByMerchant(in interval: DateInterval) -> [Finance.Share] { Finance.spendingByMerchant(data, in: interval) }
    func monthlySpending(months: Int = 6) -> [Finance.MonthSpend] { Finance.monthlySpending(data, months: months) }
    func belongingBuys(in interval: DateInterval) -> Int { Finance.belongingBuys(data, in: interval) }
    func spendingSummary(_ p: Finance.SpendingPeriod, containing date: Date, by split: Finance.SpendingSplit) -> Finance.SpendingSummary {
        Finance.spendingSummary(data, p, containing: date, by: split)
    }
    func nextSpendingInterval(_ p: Finance.SpendingPeriod, after i: DateInterval) -> DateInterval? {
        Finance.nextSpendingInterval(data, p, after: i)
    }
    func incomeFlow(in interval: DateInterval, shares: [Finance.Share]) -> Finance.IncomeFlow {
        Finance.incomeFlow(data, in: interval, shares: shares)
    }
    /// Pay period is a choice only when there is a payday to count from.
    var spendingPeriods: [Finance.SpendingPeriod] {
        Finance.salary(data) == nil ? [.month, .year] : Finance.SpendingPeriod.allCases
    }
    func flow(in interval: DateInterval) -> Finance.Flow { Finance.flow(data, in: interval) }
    func transactions(in interval: DateInterval?, filter: Finance.TransactionFilter = .all, search: String = "") -> [Transaction] {
        Finance.transactions(data, in: interval, filter: filter, search: search)
    }
    var budget: Finance.BudgetStatus { Finance.budget(data) }
    var goalsMonthly: Int { Finance.goalsMonthly(data) }
    var goalsSaved: Int { Finance.goalsSaved(data) }
    var goalsTarget: Int { Finance.goalsTarget(data) }
    var belongingsMonthlyCost: Int { Finance.belongingsMonthlyCost(data) }

    /// A month's real cost said the right way round: something worth more
    /// than was paid is gaining, not "costing -¥374".
    func monthlyCostLine(_ cost: Int) -> String {
        cost > 0 ? String(localized: "Costing \(format(cost)) a month")
            : cost < 0 ? String(localized: "Gaining \(format(-cost)) a month")
            : String(localized: "Holding its value")
    }

    /// The same for a row's figure: "¥2,400/mo", "+¥374/mo".
    func perMonth(_ cost: Int) -> String {
        cost < 0 ? String(localized: "+\(format(-cost))/mo") : String(localized: "\(format(cost))/mo")
    }
    var belongingsWorth: Int { Finance.belongingsWorth(data) }
    var belongingsPaid: Int { Finance.belongingsPaid(data) }
    func realCostPerMonth(_ item: Item) -> Int? { Finance.realCostPerMonth(item) }
    var subscriptions: [Recurring] { Finance.subscriptions(data).sorted { Finance.nextOccurrence($0, after: .now) < Finance.nextOccurrence($1, after: .now) } }
    var subscriptionsMonthly: Int { Finance.subscriptionsMonthly(data) }
    func recurringDue(month: Date) -> [Finance.RecurringDue] { Finance.recurringDue(data, month: month) }
    func recurringTotals(month: Date) -> Finance.RecurringTotals { Finance.recurringTotals(recurringDue(month: month)) }
    var investmentsValue: Int { Finance.investmentsValue(data) }
    func place(near lat: Double, _ lon: Double) -> Finance.Place? { Finance.place(near: lat, lon, data) }

    // MARK: - Receipts on disk

    /// Photos live beside the book, never inside it.
    private var receiptsDirectory: URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let folder = dir.appendingPathComponent("receipts", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    /// Saves the photo and returns the file name a transaction keeps.
    func saveReceipt(_ image: UIImage) -> String? {
        guard let folder = receiptsDirectory, let jpeg = image.jpegData(compressionQuality: 0.7) else { return nil }
        let name = "\(UUID().uuidString).jpg"
        do { try jpeg.write(to: folder.appendingPathComponent(name), options: .atomic) } catch { return nil }
        return name
    }

    func receiptImage(_ name: String) -> UIImage? {
        guard let url = receiptsDirectory?.appendingPathComponent(name) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    func receiptURL(_ name: String) -> URL? { receiptsDirectory?.appendingPathComponent(name) }

    func deleteReceipt(_ name: String) {
        guard let url = receiptsDirectory?.appendingPathComponent(name) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    var receiptFiles: [URL] {
        guard let folder = receiptsDirectory,
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        return names.filter { $0.hasSuffix(".jpg") }.map { folder.appendingPathComponent($0) }
    }
}
