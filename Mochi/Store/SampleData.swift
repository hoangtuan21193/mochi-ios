import Foundation

/// A demo book: a household in Tokyo with a bank account, PayPay and cash,
/// two cards, two instalment plans, a salary and the usual bills, two months
/// of spending, and the things they own — a MacBook, a phone, a jacket, a new
/// camera. Dates are relative to today, so the book always looks current.
/// Loaded from Settings → Load sample data, or `-demo 1` at launch.
extension AppData {
    static var sample: AppData {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func ago(_ days: Int, _ hour: Int = 12) -> Date {
            cal.date(bySettingHour: hour, minute: 0, second: 0, of: cal.date(byAdding: .day, value: -days, to: today)!)!
        }
        func monthsAgo(_ m: Int) -> Date { cal.date(byAdding: .month, value: -m, to: today)! }

        var a = AppData()
        a.schemaVersion = 2
        a.owners = [Owner(id: "me", name: "Me"), Owner(id: "linh", name: "Linh")]
        a.spendingCategories = SpendingCategory.defaults

        // The book started keeping transactions 70 days ago; the balances
        // below were what the bank said then.
        a.ledgerStart = ago(70, 0)
        a.postedThrough = ago(71, 0)
        a.wallets = [
            Wallet(name: "SMBC bank", balance: 60_000, note: "salary comes in here"),
            Wallet(name: "PayPay", balance: 18_000, note: "shops and Mercari"),
            Wallet(name: "Cash", balance: 40_000),
            // Linh's bank pays Linh's card; it is short this round, which is
            // what Home's move suggestion is for.
            // ¥83,000 when the book started; the ¥52,000 statement typed on the
            // card has left it since, leaving ¥31,000 today.
            Wallet(name: "MUFG", balance: 83_000, note: "Linh", ownerID: "linh"),
            // Sales wait here until withdrawn to SMBC: ¥200 and three business days.
            Wallet(name: "Mercari", balance: 86_400, note: "sales, not withdrawn",
                   payoutTo: "SMBC bank", payoutFee: 200, payoutDays: 3),
        ]
        a.pointWallets = [
            PointWallet(name: "PayPay points", points: 8_200, spendAnywhere: true),
            PointWallet(name: "Rakuten points", points: 10_220, note: "expires monthly"),
        ]
        a.cards = [
            CreditCard(name: "Rakuten Card", dueDay: 10, debt: 96_000, closingDay: 15, payFrom: "SMBC bank", last4: "1234"),
            CreditCard(name: "SMBC Card", dueDay: 26, debt: 112_000, closingDay: 31, payFrom: "SMBC bank", last4: "5678"),
            CreditCard(name: "JCB Card W", dueDay: 10, debt: 52_000, ownerID: "linh", closingDay: 15, payFrom: "MUFG", last4: "4321"),
        ]
        a.channels = [
            SalesChannel(name: "Mercari", rate: 10, searchURL: "https://jp.mercari.com/search?keyword={item}&status=sold_out"),
            SalesChannel(name: "Rakuma", rate: 6.6, searchURL: "https://fril.jp/s?query={item}&transaction=soldout"),
            SalesChannel(name: "Trade-in", rate: 0),
        ]
        a.categories = [
            Category(name: "Computers", attributes: [AttributeSpec(name: "Battery cycles", kind: .number, unit: "cycles")]),
            Category(name: "Phones", attributes: [AttributeSpec(name: "Battery health", kind: .number, unit: "%")]),
            Category(name: "Cameras", attributes: [AttributeSpec(name: "Shutter count", kind: .number, unit: "shots")]),
            Category(name: "Clothes", attributes: []),
            Category(name: "Home", attributes: []),
        ]
        a.recurring = [
            Recurring(name: "Salary", amount: 452_000, kind: "income", category: "salary", day: 25, paidBy: "SMBC bank"),
            Recurring(name: "Rent", amount: 85_000, kind: "expense", category: "rent", day: 27, paidBy: "SMBC Card"),
            Recurring(name: "Electricity", amount: 9_800, kind: "expense", category: "utility", day: 20, paidBy: "SMBC bank"),
            Recurring(name: "Netflix", amount: 1_590, kind: "expense", category: "subscription", day: 8, paidBy: "SMBC Card"),
            Recurring(name: "YouTube Premium", amount: 1_280, kind: "expense", category: "subscription", day: 12, paidBy: "Rakuten Card"),
            Recurring(name: "Spotify", amount: 980, kind: "expense", category: "subscription", day: 15, paidBy: "Rakuten Card"),
            Recurring(name: "Amazon Prime", amount: 600, kind: "expense", category: "subscription", day: 1, paidBy: "Rakuten Card"),
            Recurring(name: "iCloud+ 200 GB", amount: 400, kind: "expense", category: "subscription", day: 4, paidBy: "Rakuten Card"),
            Recurring(name: "Kindle Unlimited", amount: 980, kind: "expense", category: "subscription",
                      day: cal.component(.day, from: cal.date(byAdding: .day, value: 3, to: today)!), paidBy: "Rakuten Card"),
            Recurring(name: "Duolingo", amount: 4_440, kind: "expense", category: "subscription", day: 2, paidBy: "Rakuten Card", month: 2),
        ]
        a.safetyBuffer = 100_000
        a.horizon = "cards"

        a.installments = [
            Installment(name: "iPhone 16 Pro", lender: "Shop credit", principal: 480_000, months: 24,
                        firstAmount: 20_000, firstDate: date(day: 15, in: monthsAgo(12)), payFrom: "SMBC bank"),
            Installment(name: "Washer-dryer", lender: "Shop credit", principal: 182_000, months: 18,
                        firstAmount: 12_000, firstDate: date(day: 27, in: monthsAgo(6)), payFrom: "SMBC bank"),
        ]

        // Things they own. The MacBook and the phone have a history of
        // worth, so their pages can draw a line.
        var mac = Item(name: "MacBook Pro 14″", categoryName: "Computers", keep: true, boughtOn: monthsAgo(18),
                       buyPrice: 248_000, boughtFrom: "Apple", cardName: "SMBC Card", pointsEarned: 12_400,
                       estimatedPrice: 165_000, plannedChannel: "Mercari")
        mac.valueHistory = [ValuePoint(date: monthsAgo(18), value: 248_000), ValuePoint(date: monthsAgo(12), value: 205_000),
                            ValuePoint(date: monthsAgo(6), value: 182_000), ValuePoint(date: ago(28), value: 165_000)]
        mac.warrantyUntil = cal.date(byAdding: .month, value: 18, to: today)
        mac.warrantyNote = "AppleCare+"
        var phone = Item(name: "iPhone 16 Pro", categoryName: "Phones", boughtOn: monthsAgo(23), buyPrice: 159_800,
                         boughtFrom: "Apple", cardName: "", pointsEarned: 0, estimatedPrice: 98_000, plannedChannel: "Mercari")
        phone.valueHistory = [ValuePoint(date: monthsAgo(23), value: 159_800), ValuePoint(date: monthsAgo(4), value: 98_000)]
        phone.warrantyUntil = cal.date(byAdding: .day, value: 18, to: today)
        phone.warrantyNote = "AppleCare+"
        var dyson = Item(name: "Dyson V12 vacuum", categoryName: "Home", keep: true, boughtOn: monthsAgo(22), buyPrice: 89_800,
                         boughtFrom: "Bic Camera", cardName: "", estimatedPrice: 38_000, plannedChannel: "Mercari")
        dyson.warrantyUntil = cal.date(byAdding: .day, value: 43, to: today)
        dyson.warrantyNote = "Maker"
        let jacket = Item(name: "Down jacket", categoryName: "Clothes", boughtOn: monthsAgo(10), buyPrice: 42_000,
                          boughtFrom: "Uniqlo", cardName: "", estimatedPrice: 24_000, plannedChannel: "Mercari")
        let chair = Item(name: "Desk chair", categoryName: "Home", keep: true, boughtOn: monthsAgo(31), buyPrice: 64_000,
                         cardName: "", estimatedPrice: 36_000, plannedChannel: "Mercari")
        var camera = Item(name: "Sony α7C II body", categoryName: "Cameras", keep: true, boughtOn: ago(1, 15), buyPrice: 198_000,
                          boughtFrom: "Hikari Camera 新宿本店", cardName: "Rakuten Card", pointsEarned: 19_800,
                          estimatedPrice: 170_000, plannedChannel: "Mercari")
        camera.valueHistory = [ValuePoint(date: ago(1, 15), value: 170_000)]
        camera.warrantyUntil = cal.date(byAdding: .year, value: 5, to: today)
        camera.warrantyNote = "Shop 5-year"
        let z6 = Item(name: "Nikon Z6 II", categoryName: "Cameras", boughtOn: monthsAgo(22), buyPrice: 189_000,
                      cardName: "", estimatedPrice: 150_000, plannedChannel: "Mercari",
                      sale: SaleRecord(price: 158_000, channel: "Mercari", net: 142_200, date: monthsAgo(2), shipping: 0))
        // Two of the same lens bought at MapCamera and sold on, so Buy advice
        // has a history to quote and a shop's points rate to learn.
        var lens1 = Item(name: "Nikon Z 70-200mm f/2.8 VR S", categoryName: "Cameras", boughtOn: monthsAgo(11), buyPrice: 205_000,
                         boughtFrom: "MapCamera", cardName: "Rakuten Card", pointsEarned: 8_200, estimatedPrice: 238_000,
                         plannedChannel: "Mercari",
                         sale: SaleRecord(price: 238_000, channel: "Mercari", net: 212_700, date: monthsAgo(7), shipping: 1_500))
        lens1.boughtToResell = true
        var lens2 = Item(name: "Z 70-200 f2.8 VR S", categoryName: "Cameras", boughtOn: monthsAgo(14), buyPrice: 215_000,
                         boughtFrom: "MapCamera", cardName: "Rakuten Card", pointsEarned: 8_600, estimatedPrice: 245_000,
                         plannedChannel: "Mercari",
                         sale: SaleRecord(price: 245_000, channel: "Mercari", net: 219_000, date: monthsAgo(11), shipping: 1_500))
        lens2.boughtToResell = true
        a.items = [camera, mac, phone, jacket, dyson, chair, z6, lens1, lens2]

        // Two months of spending, hand-shaped so every screen has something
        // true to show. Kobe Coffee is always the same corner of Shinjuku.
        let coffee = (35.6905, 139.7036), sunmart = (35.6581, 139.6975)
        var t: [Transaction] = []
        func spend(_ d: Int, _ amount: Int, _ merchant: String, _ cat: String, _ acct: String,
                   at place: (Double, Double)? = nil, review: Bool = false, source: TransactionSource = .manual, hour: Int = 12) {
            var x = Transaction(date: ago(d, hour), amount: -amount, kind: .spend, account: acct, merchant: merchant,
                                category: review ? "" : cat, source: source)
            if let place { x.latitude = place.0; x.longitude = place.1 }
            x.needsReview = review
            t.append(x)
        }
        for d in stride(from: 68, through: 2, by: -5) { spend(d, 650, "Kobe Coffee 新宿三丁目", "Eating out", "PayPay", at: coffee, hour: 9) }
        for d in stride(from: 66, through: 1, by: -4) { spend(d, 1_280 + (d % 3) * 410, "Sunmart 渋谷道玄坂店", "Groceries", "Rakuten Card", at: sunmart, hour: 19) }
        for d in stride(from: 64, through: 1, by: -7) { spend(d, 3_600 + (d % 5) * 300, "Life Supermarket", "Groceries", "Cash", hour: 18) }
        for d in stride(from: 63, through: 8, by: -3) { spend(d, 420, "Tokyo Metro", "Transport", "PayPay", hour: 8) }
        for d in stride(from: 60, through: 10, by: -12) { spend(d, 2_380, "Nishi Pharmacy", "Household", "SMBC Card") }
        for d in stride(from: 58, through: 12, by: -9) { spend(d, 890, "Hanamaru Udon", "Eating out", "PayPay", hour: 13) }
        spend(40, 6_800, "Tsutaya Books", "Fun", "Rakuten Card")
        spend(33, 4_200, "Toho Cinemas", "Fun", "SMBC Card", hour: 20)
        spend(18, 12_400, "Uniqlo Shibuya", "Other", "Rakuten Card")
        // Linh's card, in the cycle that last closed on the 15th: ¥96,200 due
        // from MUFG, which holds ¥31,000 — the gap Home suggests a move for.
        let jcbClosed = cal.dateComponents([.day], from: Finance.latest(day: 15, onOrBefore: today), to: today).day ?? 0
        spend(jcbClosed + 3, 36_200, "Bic Camera 新宿", "Household", "JCB Card W")
        spend(jcbClosed + 10, 21_600, "Nitori 渋谷", "Household", "JCB Card W")
        spend(jcbClosed + 18, 38_400, "Costco 川崎", "Groceries", "JCB Card W")
        // Three from Apple Pay this week, waiting for a category.
        spend(1, 420, "Tokyo Metro", "Transport", "PayPay", review: true, source: .applePay, hour: 8)
        spend(2, 2_380, "Nishi Pharmacy", "Household", "SMBC Card", review: true, source: .applePay)
        spend(3, 890, "Hanamaru Udon", "Eating out", "PayPay", review: true, source: .applePay, hour: 13)
        // A dinner split four ways.
        var dinner = Transaction(date: ago(4, 20), amount: -16_000, kind: .spend, account: "Rakuten Card",
                                 merchant: "Yakiniku Kinta 新宿", category: "Eating out")
        dinner.myShare = 4_000
        dinner.splitID = "split-dinner"
        t.append(dinner)
        // PayPay topped up from the bank, twice.
        t.append(Transaction(date: ago(50), amount: 20_000, kind: .move, account: "SMBC bank", toAccount: "PayPay", merchant: "チャージ"))
        t.append(Transaction(date: ago(20), amount: 20_000, kind: .move, account: "SMBC bank", toAccount: "PayPay", merchant: "チャージ"))
        // The camera, bought on the card yesterday: a belonging, not spending.
        t.append(Transaction(date: camera.boughtOn, amount: -198_000, kind: .asset, account: "Rakuten Card",
                             merchant: camera.boughtFrom, note: camera.name, itemID: camera.id))
        // The Z6 II's sale paid into PayPay.
        t.append(Transaction(date: z6.sale!.date, amount: 142_200, kind: .income, account: "PayPay", merchant: "Mercari",
                             note: z6.name, itemID: z6.id))
        a.transactions = t

        a.loans = [
            Loan(person: "Linh", direction: 1, amount: 5_200, currency: "JPY",
                 history: [LoanEvent(id: "split-dinner", date: ago(4), title: "Yakiniku Kinta", amount: "¥4,000"),
                           LoanEvent(date: ago(9), title: "Taxi", amount: "¥1,200")]),
            Loan(person: "Tanaka", direction: 1, amount: 4_000, currency: "JPY",
                 history: [LoanEvent(id: "split-dinner", date: ago(4), title: "Yakiniku Kinta", amount: "¥4,000")]),
            Loan(person: "Minh", direction: 1, amount: 4_000, currency: "JPY",
                 history: [LoanEvent(id: "split-dinner", date: ago(4), title: "Yakiniku Kinta", amount: "¥4,000")]),
            Loan(person: "Chị Hà", direction: 1, amount: 30_000, currency: "JPY",
                 history: [LoanEvent(date: monthsAgo(3), title: "Lent", amount: "¥30,000")],
                 expectedOn: cal.date(byAdding: .month, value: 2, to: today)),
            Loan(person: "Mẹ", direction: -1, amount: 20_000_000, currency: "VND",
                 history: [LoanEvent(date: monthsAgo(8), title: "Borrowed", amount: "20,000,000 ₫")]),
        ]

        a.budgets = [BudgetLine(category: "Groceries", limit: 40_000), BudgetLine(category: "Eating out", limit: 20_000),
                     BudgetLine(category: "Transport", limit: 12_000), BudgetLine(category: "Household", limit: 10_000),
                     BudgetLine(category: "Fun", limit: 15_000)]
        a.goals = [
            Goal(name: "Tết in Vietnam", note: "Flights and gifts", target: 250_000, saved: 130_000, due: cal.date(byAdding: .month, value: 4, to: today)),
            Goal(name: "車検", note: "Car inspection", target: 120_000, saved: 45_000, due: cal.date(byAdding: .month, value: 6, to: today)),
            Goal(name: "Emergency fund", note: "Three months of living", target: 600_000, saved: 420_000),
        ]
        a.rules = [
            Rule(contains: "Sunmart", category: "Groceries", account: "Rakuten Card"),
            Rule(latitude: coffee.0, longitude: coffee.1, placeName: "Kobe Coffee 新宿三丁目", category: "Eating out", account: "PayPay"),
            Rule(contains: "Metro", category: "Transport"),
            Rule(contains: "Amazon", ask: true),
            Rule(contains: "Camera", category: "Other", belongingOver: 30_000),
        ]
        a.investments = [
            Investment(name: "NISA つみたて投資枠", provider: "Rakuten Securities", kind: "tsumitate", contributed: 700_000,
                       contributedThisYear: 400_000, value: 820_000, updatedOn: ago(6), monthly: 50_000, monthlyDay: 27, paidBy: "SMBC bank"),
            Investment(name: "NISA 成長投資枠", provider: "Rakuten Securities", kind: "growth", contributed: 300_000,
                       contributedThisYear: 200_000, value: 370_600, updatedOn: ago(6)),
        ]
        a.rates = ["VND": 169.3, "USD": 0.0068]
        a.household = Household(partnerName: "Linh", partnerState: "", sharedAccounts: ["SMBC bank"])

        // Monthly readings, one missing on purpose: a month the app was not
        // opened in has none, and the chart has to survive the gap.
        a.snapshots = (1...9).reversed().compactMap { back -> CashSnapshot? in
            guard back != 6 else { return nil }
            let d = cal.date(byAdding: .month, value: -back, to: cal.dateInterval(of: .month, for: today)!.start)!
            // Climbing to about where the sample's own figures put net worth
            // today, so this month's reading continues the line.
            let worth = 950_000 + (9 - back) * 38_000 + (back % 2) * 9_000
            return CashSnapshot(date: d, cash: 420_000 + (9 - back) * 12_000, cardDebt: 190_000,
                                installmentDebt: 420_000, netWorth: worth)
        }
        return a
    }

    private static func date(day: Int, in month: Date) -> Date { Finance.date(day: day, in: month) }
}
