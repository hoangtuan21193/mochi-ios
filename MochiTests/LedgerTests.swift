import Foundation
import Testing
@testable import Mochi

/// The ledger rules: a balance is its opening figure plus its transactions,
/// a move is never spending, the schedules post on their day exactly once,
/// and a purchase on a card is owed exactly once. Same fixed "today" and the
/// same small book as `FinanceTests`, switched to keeping transactions on
/// 1 September.
struct LedgerTests {
    static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }
    let today = day(2026, 9, 6)

    func legacy() -> AppData {
        var a = AppData()
        a.wallets = [Wallet(name: "Bank", balance: 500_000)]
        a.cards = [CreditCard(name: "Card", dueDay: 10, debt: 300_000, closingDay: 15)]
        a.channels = [SalesChannel(name: "Mercari", rate: 10)]
        a.defaultShippingFee = 2_000
        a.recurring = [
            Recurring(name: "Salary", amount: 450_000, kind: "income", category: "salary", day: 25, paidBy: "Bank"),
            Recurring(name: "Rent", amount: 180_000, kind: "expense", category: "rent", day: 27, paidBy: "Card"),
            Recurring(name: "Insurance", amount: 20_000, kind: "expense", category: "insurance", day: 30, paidBy: "Bank"),
        ]
        a.safetyBuffer = 100_000
        return a
    }

    func ledger() -> AppData {
        var a = legacy()
        a.ledgerStart = Self.day(2026, 9, 1)
        a.postedThrough = Self.day(2026, 8, 31)
        a.transactions = []
        return a
    }

    func spend(_ amount: Int, on account: String, _ d: Date, category: String = "Groceries", merchant: String = "Shop") -> Transaction {
        Transaction(date: d, amount: -amount, kind: .spend, account: account, merchant: merchant, category: category)
    }

    @Test func switchingToTheLedgerChangesNoFigure() {
        let old = legacy(), new = ledger()
        #expect(Finance.cashNow(old) == Finance.cashNow(new))
        #expect(Finance.netWorth(old, today: today).total == Finance.netWorth(new, today: today).total)
        #expect(Finance.safeToSpend(old, horizon: .days(30), today: today).total
                == Finance.safeToSpend(new, horizon: .days(30), today: today).total)
        #expect(Finance.cardDebt(old, today: today) == Finance.cardDebt(new, today: today))
    }

    @Test func aWalletIsItsOpeningPlusItsTransactions() {
        var a = ledger()
        a.transactions = [spend(1_280, on: "Bank", Self.day(2026, 9, 3)),
                          Transaction(date: Self.day(2026, 9, 4), amount: 5_000, kind: .income, account: "Bank")]
        #expect(Finance.cashNow(a) == 500_000 - 1_280 + 5_000)
    }

    @Test func aMoveIsNeverSpendingAndChangesNoNetWorth() {
        var a = ledger()
        a.wallets.append(Wallet(name: "PayPay", balance: 0))
        let before = Finance.netWorth(a, today: today).total
        a.transactions = [Transaction(date: Self.day(2026, 9, 5), amount: 10_000, kind: .move, account: "Bank", toAccount: "PayPay")]
        let month = Calendar.current.dateInterval(of: .month, for: today)!
        #expect(Finance.spending(a, in: month) == 0)
        #expect(Finance.cashNow(a) == 500_000)
        #expect(Finance.netWorth(a, today: today).total == before)
    }

    @Test func spendingOnACardIsOwedOnceAndCountsAsSpending() {
        var a = ledger()
        let before = Finance.unbilledCharges(a, today: today)
        a.transactions = [spend(4_000, on: "Card", Self.day(2026, 9, 2), category: "Eating out")]
        #expect(Finance.unbilledCharges(a, today: today) == before + 4_000)
        #expect(Finance.cashNow(a) == 500_000)
        let month = Calendar.current.dateInterval(of: .month, for: today)!
        #expect(Finance.spending(a, in: month) == 4_000)
    }

    @Test func aBelongingBoughtOnACardIsOwedOnceAndIsNotSpending() {
        var a = ledger()
        let item = Item(name: "Lens", boughtOn: Self.day(2026, 9, 2), buyPrice: 100_000, cardName: "Card",
                        estimatedPrice: 90_000, plannedChannel: "Mercari")
        a.items = [item]
        a.transactions = [Transaction(date: item.boughtOn, amount: -100_000, kind: .asset, account: "Card", itemID: item.id)]
        #expect(Finance.cycle(for: a.cards[0], a, today: today).unbilledStockCost == 100_000)
        let month = Calendar.current.dateInterval(of: .month, for: today)!
        #expect(Finance.spending(a, in: month) == 0)
        #expect(Finance.belongingBuys(a, in: month) == 100_000)
    }

    @Test func payingTheStatementLowersCashAndWhatIsOwedTogether() {
        var a = ledger()
        let owed = Finance.cardDebt(a, today: today)
        let worth = Finance.netWorth(a, today: today).total
        a.transactions = [Transaction(date: Self.day(2026, 9, 5), amount: 300_000, kind: .move, account: "Bank", toAccount: "Card")]
        #expect(Finance.cardDebt(a, today: today) == owed - 300_000)
        #expect(Finance.cashNow(a) == 200_000)
        #expect(Finance.netWorth(a, today: today).total == worth)
    }

    @Test func theSchedulesPostSalaryBillsAndTheCardPaymentOnTheirDays() {
        var a = ledger()
        a.cards[0].payFrom = "Bank"
        let posted = Finance.duePostings(a, through: Self.day(2026, 9, 30))
        let payment = posted.first { $0.kind == .move && $0.toAccount == "Card" }
        #expect(payment?.amount == 300_000)
        #expect(Calendar.current.component(.day, from: payment!.date) == 10)
        #expect(posted.contains { $0.kind == .income && $0.amount == 450_000 && $0.account == "Bank" })
        #expect(posted.contains { $0.kind == .spend && $0.account == "Card" && $0.amount == -180_000 && $0.category == "Housing" })
        #expect(posted.contains { $0.kind == .spend && $0.account == "Bank" && $0.amount == -20_000 })
    }

    @Test func postingTwiceAddsNothingTheSecondTime() {
        var a = ledger()
        a.cards[0].payFrom = "Bank"
        let first = Finance.duePostings(a, through: Self.day(2026, 9, 30))
        a.transactions = first
        a.postedThrough = nil
        #expect(Finance.duePostings(a, through: Self.day(2026, 9, 30)).isEmpty)
    }

    @Test func aPostedBillIsNotCountedAgainFromTheList() {
        var a = ledger()
        let today = Self.day(2026, 9, 28)
        let without = Finance.cycle(for: a.cards[0], a, today: today)
        // Rent on the 27th falls after the book started: it is posted, not listed.
        #expect(without.unbilledBills == 0)
        a.transactions = Finance.duePostings(a, through: today)
        #expect(Finance.cycle(for: a.cards[0], a, today: today).unbilledStockCost == 180_000)
    }

    @Test func aNewStatementIsAddedUpFromTheBooksOwnCharges() {
        var a = ledger()
        a.transactions = [spend(12_000, on: "Card", Self.day(2026, 9, 3)), spend(8_000, on: "Card", Self.day(2026, 9, 14))]
        // The statement closing on 15 Sep is after the typed one (15 Aug): the
        // two charges, plus the rent of 27 Aug, which fell before the book kept
        // transactions and so still comes from the Every month list.
        let c = Finance.cycle(for: a.cards[0], a, today: Self.day(2026, 9, 20))
        #expect(c.statementAmount == 20_000 + 180_000)
        #expect(c.owedStatement == 200_000)
    }

    @Test func aTypedBalanceBooksTheDifferenceAsAnAdjustment() {
        var a = ledger()
        a.transactions = [spend(1_000, on: "Bank", Self.day(2026, 9, 2))]
        #expect(Finance.reconcile(a.wallets[0], to: 497_000, a) == -2_000)
    }

    @Test func aSplitCountsOnlyYourShareAsSpending() {
        var a = ledger()
        var t = spend(16_000, on: "Card", Self.day(2026, 9, 5), category: "Eating out")
        t.myShare = 4_000
        a.transactions = [t]
        let month = Calendar.current.dateInterval(of: .month, for: today)!
        #expect(Finance.spending(a, in: month) == 4_000)
        #expect(Finance.cycle(for: a.cards[0], a, today: today).unbilledStockCost == 16_000)
    }

    @Test func thePayPeriodRunsFromPaydayToTheDayBeforeTheNext() {
        let p = Finance.payPeriod(ledger(), today: today)
        #expect(Calendar.current.component(.day, from: p.start) == 25)
        #expect(Calendar.current.component(.month, from: p.start) == 8)
        #expect(Calendar.current.component(.day, from: p.end) == 25)
    }

    @Test func budgetLinesAddUpTheirCategories() {
        var a = ledger()
        a.budgets = [BudgetLine(category: "Groceries", limit: 40_000), BudgetLine(category: "Eating out", limit: 20_000)]
        a.transactions = [spend(6_000, on: "Bank", Self.day(2026, 9, 2)),
                          spend(2_000, on: "Bank", Self.day(2026, 9, 3), category: "Eating out"),
                          spend(85_000, on: "Bank", Self.day(2026, 9, 1), category: "Housing")]
        let b = Finance.budget(a, today: today)
        #expect(b.limit == 60_000)
        #expect(b.spent == 8_000)
        #expect(b.left == 52_000)
        #expect(b.unbudgeted == 85_000)
    }

    @Test func aGoalAsksForWhatIsLeftOverTheMonthsLeft() {
        let g = Goal(name: "車検", target: 120_000, saved: 45_000, due: Self.day(2027, 3, 6))
        #expect(Finance.monthlySetAside(g, today: today) == 12_500)
        #expect(Finance.monthlySetAside(Goal(name: "Fund", target: 600_000), today: today) == 0)
    }

    @Test func goalsAreKeptBackFromSafeToSpend() {
        var a = ledger()
        let before = Finance.safeToSpend(a, horizon: .days(30), today: today).total
        a.goals = [Goal(name: "Trip", target: 120_000, saved: 0, due: Self.day(2026, 12, 6))]
        #expect(Finance.safeToSpend(a, horizon: .days(30), today: today).total == before - 40_000)
    }

    @Test func aBelongingCostsWhatItLostOverTheMonthsItWasOwned() {
        let item = Item(name: "MacBook", boughtOn: Self.day(2025, 3, 6), buyPrice: 248_000, cardName: "",
                        estimatedPrice: 165_000, plannedChannel: "")
        #expect(Finance.realCostPerMonth(item, today: today) == 4_611)
        let fresh = Item(name: "Camera", boughtOn: Self.day(2026, 9, 1), buyPrice: 198_000, cardName: "",
                         estimatedPrice: 170_000, plannedChannel: "")
        #expect(Finance.realCostPerMonth(fresh, today: today) == nil)
    }

    @Test func aPlaceIsKnownFromWhereYouSpentBefore() {
        var a = ledger()
        var t = spend(650, on: "Bank", Self.day(2026, 9, 2), category: "Eating out", merchant: "Kobe Coffee")
        t.latitude = 35.6905; t.longitude = 139.7036
        a.transactions = [t, t, t]
        let p = Finance.place(near: 35.6906, 139.7037, a)
        #expect(p?.merchant == "Kobe Coffee")
        #expect(p?.usualAmount == 650)
        #expect(Finance.place(near: 35.70, 139.80, a) == nil)
    }

    @Test func aShopRuleMatchesTheMerchantsName() {
        var a = ledger()
        a.rules = [Rule(contains: "Tokyo Metro", category: "Transport")]
        #expect(Finance.rule(for: "TOKYO METRO SHINJUKU", a)?.category == "Transport")
        #expect(Finance.rule(for: "Sunmart", a) == nil)
    }

    @Test func aYearlyBillLandsOnlyInItsMonth() {
        var a = ledger()
        a.recurring = [Recurring(name: "Duolingo", amount: 4_440, kind: "expense", category: "subscription",
                                 day: 2, paidBy: "Bank", month: 2)]
        #expect(Finance.duePostings(a, through: Self.day(2026, 9, 30)).isEmpty)
        #expect(Finance.monthlyEquivalent(a.recurring![0]) == 370)
    }

    @Test func untilPaydayDoesNotCountThatDaysSalary() {
        let a = ledger()
        let s = Finance.safeToSpend(a, horizon: .payday, today: today)
        #expect(s.incoming == 0)
        #expect(Calendar.current.component(.day, from: s.end) == 25)
    }

    @Test func aSpotIsNamedFromTheBookBeforeAnythingIsAsked() {
        var d = AppData.empty
        var coffee = Transaction(date: Self.day(2026, 9, 1), amount: -650, kind: .spend, account: "Bank", merchant: "Kobe Coffee")
        coffee.latitude = 35.6900; coffee.longitude = 139.7000
        d.transactions = [coffee]
        // Only a shop paid near here: named after the shop.
        #expect(Finance.placeName(near: 35.6901, 139.7001, d) == .init(name: "Kobe Coffee", source: .nearShop))
        // A name kept with a spend here wins over the shop.
        coffee.placeName = "Shinjuku, 新宿三丁目"
        d.transactions = [coffee]
        #expect(Finance.placeName(near: 35.6901, 139.7001, d) == .init(name: "Shinjuku, 新宿三丁目", source: .saved))
        // Nothing within 80 m: the book has no name for it.
        #expect(Finance.placeName(near: 35.7000, 139.7000, d) == nil)
    }

    @Test func theRecurringPageListsEveryFixedItemOfTheMonth() {
        var d = AppData.empty
        d.recurring = [
            Recurring(name: "Salary", amount: 452_000, kind: "income", category: "salary", day: 25, paidBy: "Bank"),
            Recurring(name: "Rent", amount: 85_000, kind: "expense", category: "rent", day: 27, paidBy: "Card"),
            Recurring(name: "Netflix", amount: 1_590, kind: "expense", category: "subscription", day: 8, paidBy: "Card"),
            Recurring(name: "Car insurance", amount: 36_000, kind: "expense", category: "insurance", day: 18, paidBy: "Bank", month: 10),
            Recurring(name: "Gym", amount: 8_000, kind: "expense", category: "subscription", day: 2, paidBy: "Bank", active: false),
        ]
        let sep = Self.day(2026, 9, 10)
        let due = Finance.recurringDue(d, month: sep, today: sep)
        // The yearly one is not September's; the paused one moves nothing.
        #expect(due.map(\.recurring.name) == ["Netflix", "Salary", "Rent"])
        #expect(due.map(\.kind) == [.subscription, .income, .bill])
        #expect(due.map(\.done) == [true, false, false])
        let t = Finance.recurringTotals(due)
        // Upcoming: salary and rent; done: Netflix, ¥1,590 already gone.
        #expect(t == .init(income: 452_000, bills: 85_000, subscriptions: 1_590, stillToPay: 85_000,
                           stillToCome: 452_000, leftCount: 2, paid: 1_590))
        #expect(Finance.recurringIncomeByDay(due) == [25: 452_000])
        // October has the insurance too.
        #expect(Finance.recurringDue(d, month: Self.day(2026, 10, 1), today: sep).map(\.recurring.name)
                == ["Netflix", "Car insurance", "Salary", "Rent"])
    }

    @Test func aDayAddsUpWithoutItsMoves() {
        let d = Self.day(2026, 9, 3)
        var pay = Transaction(date: d, amount: 50_000, kind: .move, account: "Bank", merchant: "")
        pay.toAccount = "Card"
        var camera = spend(198_000, on: "Card", d)
        camera.kind = .asset
        let list = [spend(1_280, on: "Card", d), camera, pay,
                    spend(650, on: "Bank", Self.day(2026, 9, 4))]
        let days = Finance.days(list)
        #expect(days.map(\.day) == [Self.day(2026, 9, 4), d])
        // A belonging bought is on the day's total, the move between accounts is not.
        #expect(days.last?.total == -199_280)
        #expect(days.last?.rows.count == 3)
    }

    @Test func theReviewQueueNamesItsSourceOnlyWhenThereIsOne() {
        var a = ledger()
        var tap = spend(420, on: "Card", today, category: "")
        tap.needsReview = true; tap.source = .applePay
        a.transactions = [tap, tap, spend(900, on: "Bank", today, category: "")]
        a.transactions![1].id = "second"
        #expect(Finance.reviewQueue(a).count == 2)
        #expect(Finance.reviewQueue(a).source == .applePay)
        #expect(Finance.reviewQueue(a).uncategorised == 3)
        a.transactions![1].source = .email
        #expect(Finance.reviewQueue(a).source == nil)
    }

    @Test func theFixedCardListsThePayPeriodsBills() {
        var a = ledger()
        a.recurring = (a.recurring ?? []) + [Recurring(name: "Netflix", amount: 1_590, kind: "expense", category: "subscription", day: 3, paidBy: "Card")]
        // Pay period 25 Aug – 24 Sep on the 6th: rent on the 27th and insurance
        // on the 30th of August, Netflix on 3 September.
        let f = Finance.fixedInPayPeriod(a, today: today)
        #expect(f.bills.map(\.recurring.name) == ["Rent", "Insurance"])
        #expect(f.bills.allSatisfy { $0.done })
        #expect(f.subscriptions == 1_590)
        #expect(f.subscriptionCount == 1)
    }

    /// A card with no closing day reads living off its typed figure while that
    /// figure is owed, and stops once it has been paid: the charges after it
    /// are counted where they happened, not again as a month of living.
    @Test func aTypedFigurePaidOffIsNotLivingForever() {
        var a = AppData()
        a.ledgerStart = Self.day(2026, 9, 1)
        a.wallets = [Wallet(name: "Bank", balance: 500_000)]
        a.cards = [CreditCard(name: "Card", dueDay: 10, debt: 100_000, payFrom: "Bank")]
        a.cards[0].statementDate = Self.day(2026, 9, 1)
        a.transactions = []
        let before = Finance.cycle(for: a.cards[0], a, today: Self.day(2026, 9, 5))
        #expect(before.livingEstimate == 100_000)

        a.transactions = [
            Transaction(date: Self.day(2026, 9, 10), amount: 100_000, kind: .move, account: "Bank",
                        toAccount: "Card", merchant: "Card"),
            spend(20_000, on: "Card", Self.day(2026, 10, 15)),
        ]
        let after = Finance.cycle(for: a.cards[0], a, today: Self.day(2026, 10, 20))
        #expect(after.owedStatement == 20_000)
        #expect(after.livingEstimate == 0)
        #expect(after.projectedSteady == 0)
    }
}
