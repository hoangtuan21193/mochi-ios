import Foundation
import Testing
@testable import Mochi

/// Every formula on the Overview, run on a small made-up book with a fixed
/// "today", so a change to Finance that moves a number is caught here rather
/// than on the 26th.
///
/// The book: one wallet, one card that closes on the 15th and is paid on the
/// 10th, rent on that card, salary on the 25th, one 0% plan, one loan out.
struct FinanceTests {
    static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }
    /// Sunday 6 September 2026: after the card closed (Aug 15) and before it is paid (Sep 10).
    let today = day(2026, 9, 6)

    func book() -> AppData {
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

    // MARK: cash

    @Test func cashNowIsWalletsOnly() {
        var a = book()
        a.pointWallets = [PointWallet(name: "Points", points: 99_999)]
        #expect(Finance.cashNow(a) == 500_000)
    }

    // MARK: cards

    @Test func cardCycleFindsClosingAndDueDates() {
        let c = Finance.cycle(for: book().cards[0], book(), today: today)
        #expect(c.lastClosing == Self.day(2026, 8, 15))
        #expect(c.previousClosing == Self.day(2026, 7, 15))
        #expect(c.nextClosing == Self.day(2026, 9, 15))
        #expect(c.statementDue == Self.day(2026, 9, 10))
        // 10 Oct 2026 is a Saturday and the 12th is Sports Day: it leaves Tue 13 Oct.
        #expect(c.unbilledDue == Self.day(2026, 10, 13))
        #expect(c.statementOpen)
    }

    @Test func statementPastDueDayCountsAsPaid() {
        // 12 September: the Sep 10 payment has gone; the typed figure is stale.
        let later = Self.day(2026, 9, 12)
        let c = Finance.cycle(for: book().cards[0], book(), today: later)
        #expect(!c.statementOpen)
        #expect(c.owedStatement == 0)
        #expect(Finance.cardDebt(book(), today: later) == 0)
    }

    @Test func unknownClosingDayNeverPutsTwoStatementsOnOneDay() {
        // Saison in the sample: due on the 4th, closing day not entered. On Sep 6 the
        // 4th has passed, so the typed figure is taken as due Oct 4 — and this
        // month's charges must then be due Nov 4, not also Oct 4.
        var a = book()
        a.cards = [CreditCard(name: "Saison", dueDay: 4, debt: 398_000)]
        let c = Finance.cycle(for: a.cards[0], a, today: today)
        #expect(c.statementOpen)
        // 4 Oct 2026 is a Sunday, so the debit leaves Monday the 5th.
        #expect(c.statementDue == Self.day(2026, 10, 5))
        #expect(c.unbilledDue == Self.day(2026, 11, 4))
        let list = Finance.events(a, from: today, to: Finance.Horizon.days(60).end(a, today: today))
        #expect(list.filter { $0.label == "Saison" }.count == 2)
        #expect(list.filter { $0.label == "Saison" && Calendar.current.isDate($0.date, inSameDayAs: Self.day(2026, 10, 5)) }.count == 1)
    }

    @Test func stockBoughtThisMonthIsUnbilledNotStatement() {
        var a = book()
        a.items = [Item(name: "Lens", boughtOn: Self.day(2026, 9, 2), buyPrice: 300_000, cardName: "Card",
                        estimatedPrice: 330_000, plannedChannel: "Mercari")]
        let c = Finance.cycle(for: a.cards[0], a, today: today)
        #expect(c.unbilledStockCost == 300_000)
        #expect(c.statementStockCost == 0)
        // Rent for Aug 27 is inside the typed statement window (Jul 15, Aug 15]? No: Aug 27 > Aug 15,
        // so it is unbilled; Jul 27 is in the statement.
        #expect(c.statementBills == 180_000)
        #expect(c.unbilledBills == 180_000)
        #expect(c.livingEstimate == 300_000 - 180_000)
        #expect(c.projectedNext == 300_000 + 180_000 + 120_000)
    }

    // MARK: net worth

    @Test func cardStockPurchaseMovesNetWorthByMarginOnly() {
        let before = Finance.netWorth(book(), today: today).total
        var a = book()
        a.items = [Item(name: "Lens", boughtOn: Self.day(2026, 9, 2), buyPrice: 300_000, cardName: "Card",
                        estimatedPrice: 330_000, plannedChannel: "Mercari")]
        let after = Finance.netWorth(a, today: today)
        // Resale 330,000 − 10% fee − 2,000 postage = 295,000 in; 300,000 charged and unbilled.
        #expect(after.inventory == 295_000)
        #expect(after.unbilledCharges - Finance.netWorth(book(), today: today).unbilledCharges == 300_000)
        #expect(after.total - before == 295_000 - 300_000)
    }

    @Test func normalCardShoppingIsALiabilityWithNoAsset() {
        // Ordinary spending is not entered item by item; it shows up when the
        // statement is typed. Typing a bigger statement lowers net worth one for one.
        var a = book()
        a.cards[0].debt += 50_000
        #expect(Finance.netWorth(a, today: today).total == Finance.netWorth(book(), today: today).total - 50_000)
    }

    @Test func rentIsNotALiability() {
        var a = book()
        a.recurring = []
        // Removing every recurring line changes net worth only through the card-paid
        // rent that was already charged and unbilled (Aug 27 on the card).
        let withRent = Finance.netWorth(book(), today: today)
        let without = Finance.netWorth(a, today: today)
        #expect(withRent.unbilledCharges - without.unbilledCharges == 180_000)
        #expect(withRent.installmentPrincipal == without.installmentPrincipal)
        #expect(withRent.cardDebt == without.cardDebt)
    }

    @Test func installmentPrincipalExcludesFutureFee() {
        var a = book()
        // 12 payments of 10,000 = 120,000 of which 12,000 is fee. Started Mar 2026: by Sep 6, 7 payments made.
        a.installments = [Installment(name: "Body", principal: 120_000, months: 12, firstAmount: 10_000,
                                      firstDate: Self.day(2026, 3, 1), feeTotal: 12_000)]
        let remaining = Finance.installmentRemaining(a, today: today)
        #expect(remaining == 50_000)
        #expect(Finance.installmentPrincipal(a, today: today) == 50_000 - 12_000 * 5 / 12)
    }

    @Test func loansEnterNetWorthBothWays() {
        var a = book()
        a.loans = [Loan(person: "A", direction: 1, amount: 120_000, currency: "JPY"),
                   Loan(person: "B", direction: -1, amount: 2_000_000, currency: "JPY"),
                   Loan(person: "C", direction: -1, amount: 5_000_000, currency: "VND")]
        let w = Finance.netWorth(a, today: today)
        #expect(w.receivables == 120_000)
        #expect(w.loansYouOwe == 2_000_000)
    }

    // MARK: sales

    @Test func realizedProfitIsRevenueMinusCostFeesAndShipping() {
        var item = Item(name: "Lens", boughtOn: Self.day(2026, 8, 1), buyPrice: 300_000, cardName: "Card",
                        estimatedPrice: 330_000, plannedChannel: "Mercari")
        let net = Finance.netProceeds(item, channelName: "Mercari", price: 330_000, book())
        #expect(net == 330_000 - 33_000 - 2_000)
        item.sale = SaleRecord(price: 330_000, channel: "Mercari", net: net, date: Self.day(2026, 9, 3), shipping: 2_000)
        #expect(Finance.realizedProfit(item) == -5_000)
        var a = book(); a.items = [item]
        let month = Calendar.current.dateInterval(of: .month, for: today)!
        #expect(Finance.realizedSalesProfit(a, in: month) == -5_000)
        // Sold stock is no longer inventory, but its card charge is still owed.
        let w = Finance.netWorth(a, today: today)
        #expect(w.inventory == 0)
        #expect(Finance.cycle(for: a.cards[0], a, today: today).unbilledStockCost == 0)   // bought Aug 1, in statement
    }

    @Test func pointsAreReportedApartFromCash() {
        // The real case: ¥785,266 lens on a PayPay campaign paying ¥94,328 of
        // points, sold for ¥780,000 with ¥40,000 of fee and postage. Cash is
        // down ¥45,266; the trade still made ¥49,062 once points are counted —
        // and the book must say both without adding them together.
        var a = book()
        a.channels = [SalesChannel(name: "PayPay Flea", rate: 5)]
        var item = Item(name: "Lens", boughtOn: Self.day(2026, 9, 1), buyPrice: 785_266, cardName: "Card",
                        pointsEarned: 94_328, estimatedPrice: 780_000, plannedChannel: "PayPay Flea")
        item.shippingFee = 1_000                       // ¥39,000 fee + ¥1,000 postage = the ¥40,000 kept back
        let net = Finance.netProceeds(item, channelName: "PayPay Flea", price: 780_000, a)
        #expect(net == 740_000)
        item.sale = SaleRecord(price: 780_000, channel: "PayPay Flea", net: net, date: Self.day(2026, 9, 4), shipping: 1_000)
        a.items = [item]

        let month = Calendar.current.dateInterval(of: .month, for: today)!
        #expect(Finance.realizedSalesProfit(a, in: month) == -45_266)
        #expect(Finance.pointsEarned(a, in: month) == 94_328)
        #expect(Finance.resaleBusiness(a, today: today).realizedThisMonth == -45_266)
        // Points are not cash and not net worth: only the yen moved.
        #expect(Finance.cashNow(a) == 500_000)
        #expect(Finance.netWorth(a, today: today).assets == 500_000)
    }

    @Test func pointsOnUnsoldStockAreCounted() {
        var a = book()
        a.items = [Item(name: "Lens", boughtOn: Self.day(2026, 9, 2), buyPrice: 300_000, cardName: "Card",
                        pointsEarned: 3_000, estimatedPrice: 330_000, plannedChannel: "Mercari")]
        #expect(Finance.pointsOnStock(a) == 3_000)
        #expect(Finance.pointsEarned(a, in: Calendar.current.dateInterval(of: .month, for: today)!) == 3_000)
    }

    @Test func aPointChannelSaleIsCountedInPointsNotYen() {
        // A MapCamera trade-in pays in points. The stock's price must never
        // land in a yen total — inside "sell-all proceeds" it would reach net
        // worth as money — so the two figures are kept apart.
        var a = book()
        a.channels = [SalesChannel(name: "Mercari", rate: 10),
                      SalesChannel(name: "MapCamera Point", rate: 10, isPoints: true)]
        let cash = Item(name: "Body", boughtOn: Self.day(2026, 8, 1), buyPrice: 100_000, cardName: "Card",
                        estimatedPrice: 200_000, plannedChannel: "Mercari")
        let points = Item(name: "Lens", boughtOn: Self.day(2026, 8, 1), buyPrice: 300_000, cardName: "Card",
                          estimatedPrice: 400_000, plannedChannel: "MapCamera Point")
        a.items = [cash, points]

        // Cash side: only the Mercari item, at 10% fee less ¥2,000 postage.
        #expect(Finance.liquidation(a) == 200_000 - 20_000 - 2_000)
        // Point side: the trade-in credits the price plus its 10% bonus.
        #expect(Finance.pointsFromSelling(a) == 440_000)
        // Net worth counts the yen and nothing else.
        #expect(Finance.netWorth(a, today: today).inventory == 178_000)

        // The point sale earns no yen: the purchase and the postage go out and
        // nothing comes back, and that loss is the whole cash story.
        #expect(Finance.expectedProfit(points, channelName: "MapCamera Point", a) == -302_000)
        #expect(Finance.expectedPoints(points, channelName: "MapCamera Point", a) == 440_000)
        #expect(Finance.expectedPoints(cash, channelName: "Mercari", a) == 0)
        #expect(Finance.unrealizedProfit(a) == 78_000 - 302_000)
    }

    @Test func walletSectionTotalsMatchTheirRows() {
        var a = book()
        a.wallets = [Wallet(name: "Bank", balance: 500_000), Wallet(name: "Cash", balance: 30_000)]
        a.pointWallets = [PointWallet(name: "MapCamera", points: 18_400),
                          PointWallet(name: "Rakuten", points: 3_200)]
        a.cards = [CreditCard(name: "Card", dueDay: 10, debt: 300_000, closingDay: 15),
                   CreditCard(name: "Second", dueDay: 27, debt: 55_000)]
        #expect(Finance.cashNow(a) == 530_000)
        #expect(Finance.pointsHeld(a) == 21_600)
        // The rows show what was typed against each card, so the total does too
        // — unlike `cardDebt`, which drops a statement already past its due day.
        #expect(Finance.typedCardDebt(a) == 355_000)

        a.recurring?.append(Recurring(name: "Old gym", amount: 9_000, kind: "expense",
                                      category: "subscription", day: 3, paidBy: "Bank", active: false))
        let commitments = Finance.monthlyCommitments(a)
        #expect(commitments.income == 450_000)
        // Paused entries are out: nothing leaves for them.
        #expect(commitments.bills == 200_000)
    }

    @Test func upcomingLinesCollapseCardsAndPlansAndStillAddUp() {
        var a = book()
        a.cards = [CreditCard(name: "Card", dueDay: 10, debt: 300_000, closingDay: 15),
                   CreditCard(name: "Second", dueDay: 20, debt: 80_000, closingDay: 15)]
        // Two plans still running, both debited on the 27th.
        a.installments = [
            Installment(name: "Body", lender: "Orico", principal: 240_000, months: 60,
                        firstAmount: 4_000, firstDate: Self.day(2026, 1, 27)),
            Installment(name: "Lens", lender: "Jaccs", principal: 120_000, months: 24,
                        firstAmount: 5_000, firstDate: Self.day(2026, 3, 27)),
        ]
        let end = Finance.Horizon.days(30).end(a, today: today)
        let events = Finance.events(a, from: today, to: end)
        let lines = Finance.upcomingLines(a, from: today, to: end)

        // Fewer lines than movements, and not one yen lost or counted twice.
        #expect(lines.count < events.count)
        #expect(lines.reduce(0) { $0 + $1.amount } == events.reduce(0) { $0 + $1.amount })
        // Every movement is inside exactly one line.
        #expect(lines.reduce(0) { $0 + $1.count } == events.count)

        let cards = lines.first { $0.kind == .card && $0.single == nil }
        let plans = lines.first { $0.kind == .installment && $0.single == nil }
        #expect(cards?.amount == events.filter { $0.kind == .card }.reduce(0) { $0 + $1.amount })
        #expect(plans?.amount == events.filter { $0.kind == .installment }.reduce(0) { $0 + $1.amount })
        // A collapsed line sorts on the soonest of them and remembers the last.
        #expect(cards?.first == events.filter { $0.kind == .card }.map(\.date).min())
        #expect(cards?.last == events.filter { $0.kind == .card }.map(\.date).max())
        // Salary is one movement, so it keeps its own name.
        #expect(lines.contains { $0.single?.label == "Salary" })
        // Sorted soonest first, like the events they came from.
        #expect(lines.map(\.first) == lines.map(\.first).sorted())
    }

    @Test func aLoneCardKeepsItsOwnName() {
        var a = book()
        a.installments = []
        let end = Finance.Horizon.days(30).end(a, today: today)
        let lines = Finance.upcomingLines(a, from: today, to: end)
        // One card movement in the window is not worth collapsing: "Credit
        // cards · 1 payment" tells you less than the card's own name.
        let cardLines = lines.filter { $0.kind == .card }
        #expect(cardLines.allSatisfy { $0.single != nil })
        #expect(cardLines.allSatisfy { $0.single?.label == "Card" })
    }

    @Test func againstPlanIsTheRealMoveLessThePlannedOne() {
        var a = book()
        // A snapshot at the start of this month gives the month something to
        // be compared against; without one there is nothing to answer with.
        #expect(Finance.monthlyCashFlow(a, month: today, today: today).againstPlan == nil)

        let flowBefore = Finance.monthlyCashFlow(a, month: today, today: today)
        a.snapshots = [CashSnapshot(date: Self.day(2026, 9, 1), cash: 500_000, cardDebt: 300_000,
                                    installmentDebt: 0, netWorth: 200_000)]
        let flow = Finance.monthlyCashFlow(a, month: today, today: today)
        guard let actual = flow.actualNetWorthDelta else {
            #expect(Bool(false), "a snapshot in this month should give an actual delta")
            return
        }
        // The plan is unchanged by the snapshot; only the comparison appears.
        #expect(flow.planned == flowBefore.planned)
        #expect(flow.againstPlan == actual - flow.planned)
    }

    @Test func aCardWithNoClosingDayCountsEachChargeOnce() {
        // The bug this guards: rent on the 5th paid by the card appeared both
        // inside the typed debt *and* as an unbilled charge, so a ¥50,000 bill
        // added ¥50,000 to net worth every month.
        var a = AppData()
        a.wallets = [Wallet(name: "Bank", balance: 1_000_000)]
        a.cards = [CreditCard(name: "Saison", dueDay: 4, debt: 200_000)]   // no closing day
        a.recurring = [Recurring(name: "Rent", amount: 50_000, kind: "expense",
                                 category: "rent", day: 5, paidBy: "Saison")]
        let c = Finance.cycle(for: a.cards[0], a, today: today)

        // Without a closing day nothing can be known to be unbilled: the typed
        // figure is everything charged so far.
        #expect(c.unbilled == 0)
        #expect(c.unbilledBills == 0)
        #expect(c.owedStatement == 200_000)
        // The rent already charged this month is recognised as inside `debt`,
        // so it is not mistaken for living costs either.
        #expect(c.statementBills == 50_000)
        #expect(c.livingEstimate == 150_000)
        // Next month's rent is still ahead, and lands on the next statement.
        #expect(c.comingBills == 50_000)
        #expect(c.projectedNext == 200_000)
        // The statement closed today, so its due day is always still ahead.
        #expect(c.statementDue > today)

        // The figure the user reads: the card is owed exactly what was typed.
        let w = Finance.netWorth(a, today: today)
        #expect(w.cardDebt == 200_000)
        #expect(w.unbilledCharges == 0)
        #expect(w.liabilities == 200_000)
    }

    @Test func aCardWithAClosingDayStillSplitsBilledFromUnbilled() {
        // The other half of the contract: once the closing day is known, a
        // charge made after it really is extra, and must be counted.
        var a = AppData()
        a.wallets = [Wallet(name: "Bank", balance: 1_000_000)]
        a.cards = [CreditCard(name: "Saison", dueDay: 26, debt: 200_000, closingDay: 31)]
        a.recurring = [Recurring(name: "Rent", amount: 50_000, kind: "expense",
                                 category: "rent", day: 5, paidBy: "Saison")]
        let c = Finance.cycle(for: a.cards[0], a, today: today)   // today: 6 Sep
        #expect(c.statementBills == 50_000)     // August rent, inside the typed figure
        #expect(c.unbilledBills == 50_000)      // September rent, charged since it closed
        #expect(c.unbilled == 50_000)
        #expect(Finance.netWorth(a, today: today).liabilities == 250_000)
    }

    // MARK: paying the bills

    @Test func paymentScheduleRunsTheBalanceDownAndNamesTheShortfall() {
        var a = book()
        // Comfortably ahead: the card on the 10th, the salary on the 25th.
        a.wallets = [Wallet(name: "Bank", balance: 600_000)]
        let end = Finance.Horizon.days(30).end(a, today: today)
        let days = Finance.paymentsDue(a, to: end, today: today)

        // One row a day, oldest first, and the balance carries between them.
        #expect(days.map(\.date) == days.map(\.date).sorted())
        var running = 600_000
        for day in days {
            running += day.amount
            #expect(day.balanceAfter == running)
        }
        // Salary is a row of its own, named after what comes in, and says
        // which account it lands in.
        let salaryDay = days.first { $0.amount > 0 }
        #expect(salaryDay?.names == ["Salary"])
        #expect(salaryDay?.amount == 450_000)
        // The card is named on the day it is paid.
        #expect(days.contains { $0.names.contains("Card") })

        // Everything clears here, so there is nothing to find.
        #expect(days.allSatisfy { $0.shortfall == 0 })
        #expect(Finance.shortfall(days) == nil)
    }

    @Test func shortfallReportsTheWorstAmountAndTheFirstDate() {
        var a = book()
        // Far too little: the card alone is 300,000.
        a.wallets = [Wallet(name: "Bank", balance: 10_000)]
        let end = Finance.Horizon.days(30).end(a, today: today)
        let days = Finance.paymentsDue(a, to: end, today: today)
        let short = days.filter { $0.shortfall > 0 }
        #expect(!short.isEmpty)

        guard let found = Finance.shortfall(days) else {
            #expect(Bool(false), "a book this short must report a shortfall")
            return
        }
        // The amount is the worst day — that is the sum to line up — and the
        // date is the first, because that is the deadline.
        #expect(found.amount == short.map(\.shortfall).max())
        #expect(found.from == short.first?.date)
        // A day that clears reports nothing, even after a day that did not.
        #expect(days.filter { $0.balanceAfter >= 0 }.allSatisfy { $0.shortfall == 0 })
    }

    // MARK: history

    @Test func historyReportsSalesEveryMonthAndBalancesOnlyWhereSnapshotsExist() {
        var a = book()
        a.channels = [SalesChannel(name: "Mercari", rate: 10)]
        var sold = Item(name: "Body", boughtOn: Self.day(2026, 6, 1), buyPrice: 100_000, cardName: "Card",
                        pointsEarned: 2_000, estimatedPrice: 150_000, plannedChannel: "Mercari")
        sold.sale = SaleRecord(price: 150_000, channel: "Mercari", net: 133_000,
                               date: Self.day(2026, 7, 10), shipping: 2_000)
        a.items = [sold]
        // Two months have a reading; the months between them never opened.
        a.snapshots = [CashSnapshot(date: Self.day(2026, 7, 2), cash: 400_000, cardDebt: 0,
                                    installmentDebt: 0, netWorth: 400_000),
                       CashSnapshot(date: Self.day(2026, 9, 1), cash: 500_000, cardDebt: 0,
                                    installmentDebt: 0, netWorth: 520_000)]

        let months = Finance.history(a, months: 6, today: today)
        #expect(months.count == 6)
        // Oldest first, ending in the month "today" falls in.
        #expect(Calendar.current.isDate(months.last!.month, equalTo: today, toGranularity: .month))
        #expect(months.map(\.month) == months.map(\.month).sorted())

        let july = months.first { Calendar.current.isDate($0.month, equalTo: Self.day(2026, 7, 1), toGranularity: .month) }
        #expect(july?.cash == 400_000)
        #expect(july?.profit == 33_000)          // 133,000 net − 100,000 cost
        #expect(july?.soldCount == 1)
        // Points land on the buy date, so they are June's, not July's.
        #expect(july?.points == 0)
        let june = months.first { Calendar.current.isDate($0.month, equalTo: Self.day(2026, 6, 1), toGranularity: .month) }
        #expect(june?.points == 2_000)
        // A month with no snapshot has no balance to report, but its sales are
        // still known: a gap in the balances is not a gap in the history.
        #expect(june?.cash == nil)
        #expect(months.first { Calendar.current.isDate($0.month, equalTo: Self.day(2026, 8, 1), toGranularity: .month) }?.cash == nil)
        #expect(months.last?.cash == 500_000)
        #expect(months.last?.netWorth == 520_000)
    }

    @Test func aMonthWithTwoSnapshotsReportsTheLater() {
        var a = book()
        a.snapshots = [CashSnapshot(date: Self.day(2026, 9, 1), cash: 100_000, cardDebt: 0,
                                    installmentDebt: 0, netWorth: 100_000),
                       CashSnapshot(date: Self.day(2026, 9, 4), cash: 250_000, cardDebt: 0,
                                    installmentDebt: 0, netWorth: 250_000)]
        // A book restored mid-month can hold two readings; the later one is
        // the truer answer to "where did the month end up".
        #expect(Finance.history(a, months: 1, today: today).last?.cash == 250_000)
    }

    @Test func periodSummaryIsThatWindowAndNothingElse() {
        var a = book()
        a.channels = [SalesChannel(name: "Mercari", rate: 10)]
        var thisYear = Item(name: "Body", boughtOn: Self.day(2026, 3, 1), buyPrice: 100_000, cardName: "Card",
                            pointsEarned: 1_000, estimatedPrice: 150_000, plannedChannel: "Mercari")
        thisYear.sale = SaleRecord(price: 150_000, channel: "Mercari", net: 133_000,
                                   date: Self.day(2026, 4, 20), shipping: 2_000)
        var lastYear = Item(name: "Lens", boughtOn: Self.day(2025, 3, 1), buyPrice: 50_000, cardName: "Card",
                            pointsEarned: 9_999, estimatedPrice: 60_000, plannedChannel: "Mercari")
        lastYear.sale = SaleRecord(price: 60_000, channel: "Mercari", net: 52_000,
                                   date: Self.day(2025, 4, 1), shipping: 2_000)
        a.items = [thisYear, lastYear]

        let y = Finance.summary(a, for: .year(2026))
        #expect(y.soldCount == 1)
        #expect(y.revenue == 133_000)
        #expect(y.profit == 33_000)
        #expect(y.points == 1_000)
        #expect(y.averageDaysHeld == 50)         // 1 Mar to 20 Apr
        // Last year is its own year, untouched by this one.
        #expect(Finance.summary(a, for: .year(2025)).profit == 2_000)
        #expect(Finance.summary(a, for: .year(2024)).soldCount == 0)
        #expect(Finance.summary(a, for: .year(2024)).averageDaysHeld == nil)

        // One month, not the year around it: April holds the sale, March the
        // purchase that earned the points.
        #expect(Finance.summary(a, for: .month(year: 2026, month: 4)).soldCount == 1)
        #expect(Finance.summary(a, for: .month(year: 2026, month: 4)).points == 0)
        #expect(Finance.summary(a, for: .month(year: 2026, month: 3)).soldCount == 0)
        #expect(Finance.summary(a, for: .month(year: 2026, month: 3)).points == 1_000)
        // Everything is the whole book, both years at once.
        #expect(Finance.summary(a, for: .all).soldCount == 2)
        #expect(Finance.summary(a, for: .all).profit == 35_000)

        // The picker offers the years with something in them, newest first,
        // and always this one.
        #expect(Finance.yearsWithActivity(a, today: today) == [2026, 2025])
        #expect(Finance.yearsWithActivity(book(), today: today) == [2026])
        // Months likewise: Mar and Apr 2026, Mar and Apr 2025, and this one.
        #expect(Finance.monthsWithActivity(a, today: today).count == 5)
        #expect(Finance.monthsWithActivity(a, today: today).first == .month(year: 2026, month: 9))
    }

    @Test func periodRoundTripsThroughItsId() {
        for p: Finance.Period in [.all, .year(2026), .month(year: 2026, month: 3)] {
            #expect(Finance.Period.from(id: p.id) == p)
        }
        #expect(Finance.Period.from(id: "nonsense") == nil)
    }

    // MARK: browsing the inventory

    @Test func inventorySortsAndFiltersInOnePlace() {
        var a = book()
        a.channels = [SalesChannel(name: "Mercari", rate: 10)]
        // Cheap and quick, sold at a profit.
        var quick = Item(name: "Quick", boughtOn: Self.day(2026, 8, 1), buyPrice: 10_000, cardName: "Card",
                         pointsEarned: 100, estimatedPrice: 30_000, plannedChannel: "Mercari")
        quick.sale = SaleRecord(price: 30_000, channel: "Mercari", net: 25_000,
                                date: Self.day(2026, 8, 11), shipping: 2_000)   // 10 days
        // Dear and slow, sold at a loss.
        var slow = Item(name: "Slow", boughtOn: Self.day(2026, 1, 1), buyPrice: 500_000, cardName: "Card",
                        pointsEarned: 9_000, estimatedPrice: 400_000, plannedChannel: "Mercari")
        slow.sale = SaleRecord(price: 400_000, channel: "Mercari", net: 358_000,
                               date: Self.day(2026, 7, 1), shipping: 2_000)      // 181 days
        let onSale = Item(name: "Listed", boughtOn: Self.day(2026, 9, 2), buyPrice: 40_000, cardName: "Card",
                          estimatedPrice: 90_000, plannedChannel: "Mercari")
        let kept = Item(name: "Kept", keep: true, boughtOn: Self.day(2026, 5, 5), buyPrice: 20_000,
                        cardName: "Card", estimatedPrice: 25_000, plannedChannel: "Mercari")
        a.items = [quick, slow, onSale, kept]

        func names(_ status: Finance.ItemStatus, _ period: Finance.Period, _ sort: Finance.ItemSort) -> [String] {
            Finance.items(a, status: status, period: period, sort: sort).map(\.name)
        }

        // Status decides what is in the list.
        #expect(names(.forSale, .all, .newest) == ["Listed"])
        #expect(names(.keeping, .all, .newest) == ["Kept"])
        #expect(Set(names(.sold, .all, .newest)) == ["Quick", "Slow"])
        #expect(names(.all, .all, .newest).count == 4)

        // Sold items are dated by the sale, everything else by the purchase.
        #expect(names(.all, .month(year: 2026, month: 8), .newest) == ["Quick"])
        #expect(names(.all, .month(year: 2026, month: 5), .newest) == ["Kept"])
        #expect(names(.all, .month(year: 2026, month: 1), .newest) == [])  // bought Jan, sold Jul

        // Every order, on the figures the rows actually show.
        #expect(names(.all, .all, .newest) == ["Listed", "Quick", "Slow", "Kept"])
        #expect(names(.all, .all, .oldest) == ["Kept", "Slow", "Quick", "Listed"])
        #expect(names(.all, .all, .priceHigh).first == "Slow")
        #expect(names(.all, .all, .priceLow).first == "Kept")
        // Realised and expected profit sort together, because that is the one
        // figure the rows show: Listed has not sold but stands to make 39,000,
        // ahead of the 15,000 Quick actually made.
        #expect(names(.all, .all, .profitHigh).prefix(2) == ["Listed", "Quick"])
        #expect(names(.all, .all, .profitLow).first == "Slow")     // −142,000
        #expect(names(.sold, .all, .profitHigh) == ["Quick", "Slow"])
        // Points count in the order, as they do on the row: a small cash loss
        // with a large point payback ranks as the trade it is.
        var b = a
        if let i = b.items.firstIndex(where: { $0.name == "Slow" }) { b.items[i].pointsEarned = 500_000 }
        #expect(Finance.items(b, status: .sold, period: .all, sort: .profitHigh, search: "").map(\.name) == ["Slow", "Quick"])
        #expect(names(.all, .all, .points).first == "Slow")        // 9,000 pt
        // Unsold sink to the bottom under either day-count order: there is no
        // answer for them, which is not the same as zero days.
        #expect(names(.all, .all, .fastest).prefix(2) == ["Quick", "Slow"])
        #expect(names(.all, .all, .slowest).prefix(2) == ["Slow", "Quick"])
        #expect(Set(names(.all, .all, .fastest).suffix(2)) == ["Listed", "Kept"])
        #expect(Set(names(.all, .all, .slowest).suffix(2)) == ["Listed", "Kept"])

        #expect(Finance.daysHeld(quick) == 10)
        #expect(Finance.daysHeld(slow) == 181)
        #expect(Finance.daysHeld(onSale) == nil)
    }

    @Test func searchingByNameForgivesSpacesAndPunctuation() {
        var a = book()
        let spelt = Item(name: "SIGMA 200mm f2.8 APO", boughtOn: Self.day(2026, 8, 1), buyPrice: 100_000,
                         cardName: "Card", estimatedPrice: 200_000, plannedChannel: "Mercari")
        let terse = Item(name: "Sigma 200 f2.8", boughtOn: Self.day(2026, 8, 2), buyPrice: 90_000,
                         cardName: "Card", estimatedPrice: 190_000, plannedChannel: "Mercari")
        let other = Item(name: "Canon 24-70 f2.8", boughtOn: Self.day(2026, 8, 3), buyPrice: 80_000,
                         cardName: "Card", estimatedPrice: 150_000, plannedChannel: "Mercari")
        let sold = Item(name: "Nikon 50mm f1.8", keep: false, boughtOn: Self.day(2026, 1, 3), buyPrice: 20_000,
                        cardName: "Card", estimatedPrice: 25_000, plannedChannel: "Mercari")
        a.items = [spelt, terse, other, sold]

        func found(_ q: String) -> Set<String> {
            Set(Finance.items(a, status: .all, period: .all, sort: .newest, search: q).map(\.name))
        }

        // The written-out name and the terse one find each other, typed with
        // no spaces and with the "mm" the terse name never had.
        #expect(found("200mmf2.8") == ["SIGMA 200mm f2.8 APO", "Sigma 200 f2.8"])
        #expect(found("200 f2.8") == ["SIGMA 200mm f2.8 APO", "Sigma 200 f2.8"])
        #expect(found("200mm f2.8") == ["SIGMA 200mm f2.8 APO", "Sigma 200 f2.8"])
        #expect(found("200f28") == ["SIGMA 200mm f2.8 APO", "Sigma 200 f2.8"])
        // The other 2.8 is not a 200.
        #expect(found("2470") == ["Canon 24-70 f2.8"])
        #expect(found("f2.8").count == 3)
        // Letters alone, case and part-way through a word.
        #expect(found("sig") == ["SIGMA 200mm f2.8 APO", "Sigma 200 f2.8"])
        #expect(found("NIKON") == ["Nikon 50mm f1.8"])
        #expect(found("leica").isEmpty)
        // Letters still count when a number matches: the 200 is a Sigma's.
        #expect(found("canon 200").isEmpty)
        // Empty query is not a filter at all.
        #expect(found("").count == 4)
        #expect(found("  ").count == 4)

        // Searching narrows within the status and the period, never past them.
        #expect(Finance.items(a, status: .all, period: .month(year: 2026, month: 1), sort: .newest,
                              search: "f2.8").isEmpty)
    }

    // MARK: schedule and safe to spend

    @Test func cardPaidBillsNeverAppearOnTheirOwnDay() {
        let end = Finance.Horizon.days(30).end(book(), today: today)
        let list = Finance.events(book(), from: today, to: end)
        #expect(!list.contains { $0.label == "Rent" })
        #expect(list.contains { $0.label == "Insurance" && $0.amount == -20_000 })
        #expect(list.contains { $0.label == "Salary" && $0.amount == 450_000 })
    }

    @Test func safeToSpendThirtyDays() {
        let s = Finance.safeToSpend(book(), horizon: .days(30), today: today)
        // Card: statement 300,000 on Sep 10. Next statement Oct 10 is outside 30 days (Oct 6).
        #expect(s.cards == 300_000)
        #expect(s.incoming == 450_000)
        #expect(s.bills == 20_000)
        #expect(s.installments == 0)
        #expect(s.total == 500_000 + 450_000 - 300_000 - 20_000 - 100_000)
    }

    @Test func sixtyDaysIncludesTheProjectedNextStatement() {
        let s = Finance.safeToSpend(book(), horizon: .days(60), today: today)
        let c = Finance.cycle(for: book().cards[0], book(), today: today)
        #expect(s.cards == 300_000 + c.projectedNext)
        #expect(s.incoming == 900_000)
    }

    @Test func paydayHorizonEndsOnSalary() {
        #expect(Finance.Horizon.payday.end(book(), today: today) == Self.day(2026, 9, 25))
        var a = book(); a.recurring = []
        #expect(Finance.Horizon.payday.end(a, today: today) == Self.day(2026, 10, 6))
    }

    @Test func installmentDebitsAreScheduledNotLumped() {
        var a = book()
        a.installments = [Installment(name: "Body", principal: 600_000, months: 60, firstAmount: 10_000,
                                      firstDate: Self.day(2026, 3, 27))]
        let s = Finance.safeToSpend(a, horizon: .days(30), today: today)
        #expect(s.installments == 10_000)                 // Sep 27 only
        #expect(Finance.installmentRemaining(a, today: today) == 600_000 - 6 * 10_000)
    }

    @Test func receivableWithDateIsIncoming() {
        var a = book()
        a.loans = [Loan(person: "A", direction: 1, amount: 120_000, currency: "JPY", expectedOn: Self.day(2026, 9, 20)),
                   Loan(person: "B", direction: 1, amount: 50_000, currency: "JPY")]
        let s = Finance.safeToSpend(a, horizon: .days(30), today: today)
        #expect(s.incoming == 450_000 + 120_000)
    }

    @Test func forecastFindsTheLowestDay() {
        let f = Finance.projectedCashBalance(book(), to: Finance.Horizon.days(30).end(book(), today: today), today: today)
        // 500,000 → Sep 10 pays 300,000 → 200,000 (lowest) → Sep 25 +450,000 → Sep 30 −20,000.
        #expect(f.lowest.balance == 200_000)
        #expect(f.lowest.date == Self.day(2026, 9, 10))
        #expect(f.shortfall == 0)
        #expect(f.points.last?.balance == 630_000)
    }

    @Test func forecastWarnsUnderTheBuffer() {
        var a = book(); a.wallets[0].balance = 350_000
        let f = Finance.projectedCashBalance(a, to: Finance.Horizon.days(30).end(a, today: today), today: today)
        #expect(f.lowest.balance == 50_000)
        #expect(f.shortfall == 50_000)
    }

    // MARK: monthly cash flow

    @Test func monthlyFlowCountsFeeNotPrincipal() {
        var a = book()
        a.installments = [Installment(name: "Body", principal: 120_000, months: 12, firstAmount: 10_000,
                                      firstDate: Self.day(2026, 3, 27), feeTotal: 12_000)]
        let f = Finance.monthlyCashFlow(a, month: today, today: today)
        #expect(f.income == 450_000)
        #expect(f.fixedBills == 200_000)
        #expect(f.interest == 1_000)
        #expect(f.livingEstimate == 300_000 - 180_000)
        #expect(f.planned == 450_000 - 200_000 - 120_000 - 1_000)
    }

    @Test func snapshotsGiveActualDeltas() {
        var a = book()
        a.snapshots = [CashSnapshot(date: Self.day(2026, 9, 1), cash: 450_000, cardDebt: 300_000,
                                    installmentDebt: 0, netWorth: 100_000)]
        let f = Finance.monthlyCashFlow(a, month: today, today: today)
        #expect(f.actualCashDelta == 50_000)
        #expect(f.actualNetWorthDelta == Finance.netWorth(a, today: today).total - 100_000)
    }

    // MARK: the same yen only once

    @Test func netWorthPartsAddUp() {
        var a = book()
        a.items = [Item(name: "Lens", boughtOn: Self.day(2026, 9, 2), buyPrice: 300_000, cardName: "Card",
                        estimatedPrice: 330_000, plannedChannel: "Mercari")]
        a.installments = [Installment(name: "Body", principal: 600_000, months: 60, firstAmount: 10_000,
                                      firstDate: Self.day(2026, 3, 27))]
        a.loans = [Loan(person: "A", direction: 1, amount: 120_000, currency: "JPY")]
        let w = Finance.netWorth(a, today: today)
        #expect(w.assets == w.cash + w.inventory + w.receivables)
        #expect(w.liabilities == w.cardDebt + w.unbilledCharges + w.installmentPrincipal + w.loansYouOwe)
        #expect(w.total == w.assets - w.liabilities)
        // Paying the card moves cash and debt together: net worth unchanged.
        var paid = a
        paid.wallets[0].balance -= 300_000
        paid.cards[0].debt = 0
        #expect(Finance.netWorth(paid, today: today).total == w.total)
    }

    // MARK: calendar helpers

    @Test func dayClampsToShortMonths() {
        #expect(Finance.date(day: 31, in: Self.day(2026, 2, 10)) == Self.day(2026, 2, 28))
        #expect(Finance.next(day: 25, after: Self.day(2026, 9, 25)) == Self.day(2026, 10, 25))
        #expect(Finance.latest(day: 15, onOrBefore: Self.day(2026, 9, 6)) == Self.day(2026, 8, 15))
        #expect(Finance.dates(day: 27, after: Self.day(2026, 9, 6), through: Self.day(2026, 11, 6)).count == 2)
    }
}


/// A book written by an older build has none of the keys added since. It must
/// still open — a version-1 file once read as an empty book because `var x = 0`
/// does not decode a missing key.
struct CompatibilityTests {
    let version1 = """
    {"items":[{"id":"i1","name":"Lens","boughtOn":700000000,"buyPrice":100000,"cardName":"Saison",
               "estimatedPrice":120000,"plannedChannel":"Mercari"}],
     "wallets":[{"id":"w1","name":"Bank","balance":500000}],
     "pointWallets":[],
     "cards":[{"id":"c1","name":"Saison","dueDay":4,"limit":0,"debt":398000}],
     "channels":[{"id":"s1","name":"Mercari","rate":10}],
     "categories":[],"owners":[{"id":"me","name":"Me"}],
     "loans":[{"id":"l1","person":"A","direction":1,"amount":120000,"currency":"JPY"}],
     "ledger":[],
     "installments":[{"id":"p1","name":"Body","principal":298000,"months":60,"firstAmount":5900,"firstDate":700000000}],
     "currency":"¥","language":"system","autoBackup":true,"defaultTransferFee":210,"defaultShippingFee":1000}
    """

    @Test func version1BookDecodes() throws {
        let a = try JSONDecoder().decode(AppData.self, from: Data(version1.utf8))
        #expect(a.wallets.count == 1)
        #expect(a.cards[0].closingDay == nil)
        #expect(a.installments?.first?.feeTotal == 0)
        #expect(a.loans[0].expectedOn == nil)
        #expect(a.recurring == nil && a.snapshots == nil)
        #expect(a.safetyBuffer == 0 && a.horizon == "30d" && a.schemaVersion == 1)
        #expect(a.targetProfit == nil)
        #expect(a.ratesFetched == nil && a.lookUpRates == nil && a.lookUpPrices == nil && a.holdingSources == nil)
        #expect(a.investments?.allSatisfy { $0.quantity == nil && $0.pricedAt == nil } ?? true)
        #expect(Finance.cashNow(a) == 500_000)
    }

    @Test func currentBookRoundTrips() throws {
        let blob = try JSONEncoder().encode(AppData.sample)
        let back = try JSONDecoder().decode(AppData.self, from: blob)
        #expect(back.recurring?.count == AppData.sample.recurring?.count)
        #expect(back.cards.map(\.closingDay) == AppData.sample.cards.map(\.closingDay))
        #expect(back.safetyBuffer == AppData.sample.safetyBuffer)
    }
}
