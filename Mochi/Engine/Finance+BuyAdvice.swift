import Foundation

// MARK: - Buy advice

/// Standing in a shop with a lens in hand, the question is the price, not the
/// profit: what is the most to pay and still make what you want once it is
/// sold on. The sale is the user's guess; everything between it and the
/// purchase — the marketplace's cut, postage, the withdrawal fee, the points
/// the shop pays back — comes from the book.
extension Finance {
    struct BuyAdvice: Equatable {
        let sellsFor: Int
        let channel: String
        /// The marketplace's cut, percentage and flat fee together.
        let fee: Int
        let feeRate: Double
        let postage: Int
        /// What taking the money out of the marketplace costs, and where it goes.
        let payoutFee: Int
        let payoutTo: String?
        let shop: String
        /// Percent of the price the shop pays back in points.
        let pointRate: Double
        let target: Int
        /// The most to pay, rounded down to the hundred.
        let maxPrice: Int

        /// What reaches the bank from the sale.
        var net: Int { sellsFor - fee - postage - payoutFee }
        /// The trade at a given price: cash is the sale's net less the price,
        /// points are what the shop gives back on that price.
        func result(at price: Int) -> TradeResult {
            TradeResult(cash: net - price, points: Int((Double(price) * pointRate / 100).rounded()))
        }
        /// How far an asking price is above the most to pay (negative: under it).
        func over(_ price: Int) -> Int { price - maxPrice }
    }

    /// The share of a purchase a shop has paid back in points, from what was
    /// bought there before. 0 for a shop the book has never bought from.
    static func pointRate(atShop shop: String, _ data: AppData) -> Double {
        let bought = data.items.filter { !shop.isEmpty && $0.boughtFrom == shop && $0.buyPrice > 0 }
        let paid = bought.reduce(0) { $0 + $1.buyPrice }
        guard paid > 0 else { return 0 }
        let rate = Double(bought.reduce(0) { $0 + $1.pointsEarned }) / Double(paid) * 100
        return (rate * 10).rounded() / 10
    }

    /// Shops the book has bought from, most used first and, between two used
    /// as often, the one bought from last.
    static func shops(_ data: AppData) -> [String] {
        let byShop = Dictionary(grouping: data.items.filter { !$0.boughtFrom.isEmpty }, by: \.boughtFrom)
        let last = byShop.mapValues { $0.map(\.boughtOn).max() ?? .distantPast }
        return byShop.keys.sorted { (byShop[$0]!.count, last[$0]!) > (byShop[$1]!.count, last[$1]!) }
    }

    /// The highest price that still makes `target` with points, from a sale at
    /// `sellFor` through `channel`. Solved from
    /// net − price + price × rate ≥ target, so price = (net − target) ÷ (1 − rate).
    static func buyAdvice(sellFor: Int, channel: String, postage: Int, shop: String,
                          target: Int, _ data: AppData) -> BuyAdvice {
        let ch = data.channels.first { $0.name == channel && !$0.isPoints }
        let feeRate = ch?.rate ?? 0
        let fee = Int(Double(sellFor) * feeRate / 100) + (ch?.fixedFee ?? 0)
        let wallet = data.wallets.first { $0.isMarketplace && $0.name == channel }
        let payoutFee = wallet?.payoutFee ?? 0
        let rate = pointRate(atShop: shop, data)
        let net = sellFor - fee - postage - payoutFee
        let raw = Double(net - target) / (1 - rate / 100)
        let maxPrice = max(0, Int((raw / 100).rounded(.down)) * 100)
        return BuyAdvice(sellsFor: sellFor, channel: channel, fee: fee, feeRate: feeRate, postage: postage,
                         payoutFee: payoutFee, payoutTo: wallet?.payoutTo, shop: shop, pointRate: rate,
                         target: target, maxPrice: maxPrice)
    }

    /// Things like it that have sold, newest first: the name typed is matched
    /// the way the Belongings search matches it, so "z 70-200" finds the lens.
    static func similarSales(_ name: String, _ data: AppData) -> [Item] {
        SoldIndex(data).similar(name)
    }

    /// What has sold, with each name's search key worked out once, so the
    /// screen can search it on every keystroke without folding every name again.
    struct SoldIndex {
        /// A name the book has sold under, or holds a thing under, for the
        /// suggestions under the field.
        struct Name: Equatable, Identifiable {
            var id: String { name }
            let name: String
            /// Times sold; 0 for a thing still owned and never sold.
            let times: Int
            /// The last sale's price, or what was paid for one still owned.
            let lastPrice: Int
            let lastDate: Date
            var sold: Bool { times > 0 }
        }

        private let entries: [(item: Item, key: SearchKey)]
        private let names: [(name: Name, key: SearchKey)]

        init(_ data: AppData) {
            let sold = data.items.filter(\.isSold)
                .sorted { ($0.sale?.date ?? .distantPast) > ($1.sale?.date ?? .distantPast) }
            entries = sold.map { ($0, Finance.searchKey($0.name)) }
            var seen: [String: Int] = [:]
            var list: [Name] = []
            for item in sold {
                let label = item.name.trimmingCharacters(in: .whitespaces)
                let k = label.lowercased()
                if let i = seen[k] {
                    let n = list[i]
                    list[i] = Name(name: n.name, times: n.times + 1, lastPrice: n.lastPrice, lastDate: n.lastDate)
                } else {
                    seen[k] = list.count
                    list.append(Name(name: label, times: 1, lastPrice: item.sale?.price ?? 0, lastDate: item.sale?.date ?? .distantPast))
                }
            }
            // Things owned and never sold come after: bought before is still a
            // name worth offering, but it has no sale to quote.
            for item in data.items.filter({ !$0.isSold }).sorted(by: { $0.boughtOn > $1.boughtOn }) {
                let label = item.name.trimmingCharacters(in: .whitespaces)
                guard seen[label.lowercased()] == nil else { continue }
                seen[label.lowercased()] = list.count
                list.append(Name(name: label, times: 0, lastPrice: item.buyPrice, lastDate: item.boughtOn))
            }
            names = list.map { ($0, Finance.searchKey($0.name)) }
        }

        /// Sales whose name answers `search`, newest first.
        func similar(_ search: String) -> [Item] {
            let q = Finance.searchKey(search)
            guard !q.isEmpty else { return [] }
            return entries.filter { Finance.matches(nameKey: $0.key, query: q) }.map(\.item)
        }

        /// Names sold before that answer what is being typed, last sold first.
        /// Nothing once the field already holds one of them as written.
        func suggestions(_ typed: String, limit: Int = 5) -> [Name] {
            let t = typed.trimmingCharacters(in: .whitespaces)
            let q = Finance.searchKey(t)
            guard !q.isEmpty, !names.contains(where: { $0.name.name.caseInsensitiveCompare(t) == .orderedSame }) else { return [] }
            return Array(names.filter { Finance.matches(nameKey: $0.key, query: q) }.map(\.name).prefix(limit))
        }
    }

}
