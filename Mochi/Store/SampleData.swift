import Foundation

/// Mirrors the prototype's seed data so the app has something to show on first
/// run. Loaded on demand from Settings — a fresh install starts on AppData.empty.
extension AppData {
    static var sample: AppData {
        func d(_ s: String) -> Date {
            let f = DateFormatter(); f.dateFormat = "d/M/yyyy"
            return f.date(from: s) ?? .now
        }

        var a = AppData()
        a.owners = [Owner(id: "me", name: "Me"), Owner(id: "wife", name: "Wife")]

        a.wallets = [
            Wallet(name: "Nishi Nippon", balance: 512002, note: "bank"),
            Wallet(name: "Mercari wallet", balance: 12400, note: "not withdrawn"),
            Wallet(name: "PayPay wallet", balance: 8300, note: "not withdrawn"),
            Wallet(name: "Rakuma wallet", balance: 0, note: "not withdrawn"),
            Wallet(name: "Cash", balance: 30000),
            Wallet(name: "Yucho", balance: 65881, note: "bank"),
            Wallet(name: "Fukuoka (salary)", balance: 450000, note: "bank")
        ]

        a.pointWallets = [
            PointWallet(name: "MapCamera points", points: 18400, note: "usable in store only"),
            PointWallet(name: "Rakuten points", points: 3200, note: "expires monthly")
        ]

        a.cards = [
            CreditCard(name: "Saison", dueDay: 4, debt: 398000),
            CreditCard(name: "Mercari", dueDay: 26, debt: 205000, closingDay: 31),
            CreditCard(name: "PayPay", dueDay: 27, debt: 55000),
            CreditCard(name: "Orico", dueDay: 27, debt: 105600),
            CreditCard(name: "Line (NL)", dueDay: 26, debt: 41310),
            CreditCard(name: "Rakuten", dueDay: 27, debt: 85149, ownerID: "wife")
        ]

        a.channels = [
            SalesChannel(name: "Mercari", rate: 10, destination: "Mercari wallet"),
            SalesChannel(name: "PayPay Flea", rate: 5, destination: "PayPay wallet"),
            SalesChannel(name: "Rakuma", rate: 10, destination: "Rakuma wallet"),
            SalesChannel(name: "Y!Auction", rate: 8.8, destination: "PayPay wallet"),
            SalesChannel(name: "MapCamera", rate: 0, destination: "Nishi Nippon"),
            SalesChannel(name: "MapCamera Point", rate: 10, destination: "MapCamera points", isPoints: true)
        ]

        a.categories = [
            Category(name: "Camera lens", attributes: [
                AttributeSpec(name: "Fungus", kind: .bool),
                AttributeSpec(name: "Dust", kind: .bool),
                AttributeSpec(name: "Scratches", kind: .bool),
                AttributeSpec(name: "Smoke smell", kind: .bool),
                AttributeSpec(name: "Hood", kind: .bool),
                AttributeSpec(name: "Full box", kind: .bool)
            ]),
            Category(name: "Camera body", attributes: [
                AttributeSpec(name: "Scratches", kind: .bool),
                AttributeSpec(name: "Full box", kind: .bool),
                AttributeSpec(name: "Shutter count", kind: .number, unit: "shots"),
                AttributeSpec(name: "Battery", kind: .number, unit: "%")
            ]),
            Category(name: "Macbook", attributes: [
                AttributeSpec(name: "Model", kind: .text),
                AttributeSpec(name: "RAM / SSD", kind: .text),
                AttributeSpec(name: "Battery cycles", kind: .number, unit: "cycles"),
                AttributeSpec(name: "Scratches", kind: .bool),
                AttributeSpec(name: "Full box", kind: .bool)
            ]),
            Category(name: "General electronics", attributes: [
                AttributeSpec(name: "Scratches", kind: .bool),
                AttributeSpec(name: "Works properly", kind: .bool),
                AttributeSpec(name: "Full box", kind: .bool)
            ])
        ]

        a.items = [
            Item(name: "Macbook Pro M1 Max 64GB/512", categoryName: "Macbook", keep: true,
                 boughtOn: d("14/4/2026"), buyPrice: 160000, cardName: "Mercari", pointsEarned: 1600,
                 estimatedPrice: 180000, plannedChannel: "Mercari",
                 accessories: "Full box, 140W charger", condition: "Clean shell, battery 210 cycles",
                 attributes: [["Model", "A2485 (2021)"], ["RAM / SSD", "64GB / 512GB"], ["Battery cycles", "210"]]),
            Item(name: "Lumix 200mm F2.8 Leica", categoryName: "Camera lens",
                 boughtOn: d("8/3/2026"), buyPrice: 151636, cardName: "Saison", pointsEarned: 1516,
                 estimatedPrice: 170000, plannedChannel: "MapCamera",
                 accessories: "Full box, hood, TC 1.4x", condition: "Clear glass, no fungus",
                 attributes: [["Fungus", "No"], ["Dust", "No"], ["Hood", "Yes"], ["Full box", "Yes"]]),
            Item(name: "OM System OM-1", categoryName: "Camera body",
                 boughtOn: d("10/2/2026"), buyPrice: 132800, cardName: "Saison", pointsEarned: 1328,
                 estimatedPrice: 130000, plannedChannel: "PayPay Flea",
                 condition: "Excellent cosmetics",
                 attributes: [["Shutter count", "12400"], ["Battery", "88"], ["Full box", "Yes"]]),
            Item(name: "EF 135mm F2 L", categoryName: "Camera lens",
                 boughtOn: d("7/3/2026"), buyPrice: 57090, cardName: "Mercari", pointsEarned: 571,
                 estimatedPrice: 62000, plannedChannel: "PayPay Flea",
                 condition: "Light dust, no effect on images",
                 attributes: [["Dust", "Yes"], ["Fungus", "No"]]),
            Item(name: "Godox TT600", keep: true,
                 boughtOn: d("12/3/2026"), buyPrice: 2000, cardName: "Mercari", pointsEarned: 20,
                 estimatedPrice: 6500, plannedChannel: "Mercari"),
            Item(name: "Nikon Z8 body", categoryName: "Camera body",
                 boughtOn: d("12/11/2025"), buyPrice: 398000, cardName: "Saison", pointsEarned: 3980,
                 estimatedPrice: 430000, plannedChannel: "Mercari",
                 sale: SaleRecord(price: 432000, channel: "Mercari", net: 387800, date: d("18/5/2026"))),
            Item(id: "sample-a7iv", name: "Sony A7 IV body", categoryName: "Camera body",
                 boughtOn: d("20/1/2026"), buyPrice: 298000, cardName: "",
                 estimatedPrice: 260000, plannedChannel: "Mercari",
                 sale: SaleRecord(price: 265000, channel: "Mercari", net: 237500, date: d("2/7/2026")))
        ]

        // Bought on 60 months at 0%, sold six months later. The camera is gone;
        // the debit on the 27th is not.
        a.installments = [
            Installment(name: "Sony A7 IV body", lender: "Orico", principal: 298000, months: 60,
                        firstAmount: 5900, firstDate: d("27/2/2026"), itemID: "sample-a7iv"),
            Installment(name: "Sigma 24-70 DG DN II", lender: "MapCamera credit", principal: 172000, months: 24,
                        firstAmount: 7200, firstDate: d("27/5/2026"))
        ]

        // Salary lands in the bank on the 25th; rent and the subscriptions go
        // on Saison, so they are part of its statement, not cash events.
        a.recurring = [
            Recurring(name: "Salary", amount: 450000, kind: "income", category: "salary", day: 25, paidBy: "Fukuoka (salary)"),
            Recurring(name: "Rent", amount: 85000, kind: "expense", category: "rent", day: 27, paidBy: "Saison"),
            Recurring(name: "Phone", amount: 3278, kind: "expense", category: "utility", day: 26, paidBy: "Saison"),
            Recurring(name: "Netflix", amount: 1490, kind: "expense", category: "subscription", day: 10, paidBy: "Saison"),
            Recurring(name: "Health insurance", amount: 18200, kind: "expense", category: "insurance", day: 30, paidBy: "Nishi Nippon")
        ]
        a.safetyBuffer = 100000

        // Eight months of readings, so the demo book can actually show the
        // history Stats draws. A real book collects these one a month on
        // launch; March is missing on purpose, because a month the app never
        // opened in has no reading and the chart has to survive the gap.
        a.snapshots = [
            CashSnapshot(date: d("1/2/2026"), cash: 612000, cardDebt: 410000,
                         installmentDebt: 520000, netWorth: 61000),
            CashSnapshot(date: d("1/4/2026"), cash: 704000, cardDebt: 455000,
                         installmentDebt: 486000, netWorth: 98000),
            CashSnapshot(date: d("1/5/2026"), cash: 668000, cardDebt: 612000,
                         installmentDebt: 474000, netWorth: 84000),
            CashSnapshot(date: d("1/6/2026"), cash: 845000, cardDebt: 588000,
                         installmentDebt: 462000, netWorth: 152000),
            CashSnapshot(date: d("1/7/2026"), cash: 921000, cardDebt: 640000,
                         installmentDebt: 449000, netWorth: 176000),
            CashSnapshot(date: d("1/8/2026"), cash: 878000, cardDebt: 719000,
                         installmentDebt: 437000, netWorth: 141000),
            CashSnapshot(date: d("1/9/2026"), cash: 1043000, cardDebt: 802000,
                         installmentDebt: 418000, netWorth: 227000),
        ]

        a.loans = [
            Loan(person: "Brother", direction: 1, amount: 120000, currency: "JPY",
                 history: [LoanEvent(date: d("2/6/2026"), title: "Lent for camera", amount: "+¥120,000")],
                 expectedOn: d("15/10/2026")),
            Loan(person: "Mum", direction: -1, amount: 5000000, currency: "VND",
                 history: [LoanEvent(date: d("14/4/2026"), title: "Borrowed", amount: "-5,000,000 ₫")])
        ]
        return a
    }
}
