import Foundation

/// Gold and coin prices looked up online (decision #31), read here so a test
/// can hold a reply and the price it must give. Only "XAU" and the coins'
/// ids are sent — never how much is held.
///
/// Gold is the world price (gold-api.com, US dollars a troy ounce) turned
/// into the book's money at the day's rate. A shop's price was the first
/// choice, but no Vietnamese or Japanese gold shop can be read by an app (the
/// SJC page answers with a bot check), so what a holding "would sell for" is
/// the world price for its weight and purity, and the screen says so.
/// Coins come from CoinGecko, priced in the book's currency directly.
enum Prices {
    static let goldSource = "gold-api.com"
    static let coinSource = "CoinGecko"

    static let goldURL = URL(string: "https://api.gold-api.com/price/XAU")!

    static func coinsURL(ids: [String], currency: String) -> URL {
        var c = URLComponents(string: "https://api.coingecko.com/api/v3/simple/price")!
        c.queryItems = [URLQueryItem(name: "ids", value: ids.joined(separator: ",")),
                        URLQueryItem(name: "vs_currencies", value: currency.lowercased())]
        return c.url!
    }

    static func searchURL(_ query: String) -> URL {
        var c = URLComponents(string: "https://api.coingecko.com/api/v3/search")!
        c.queryItems = [URLQueryItem(name: "query", value: query)]
        return c.url!
    }

    /// US dollars a troy ounce. nil for anything but a gold price.
    static func parseGold(_ data: Data) -> Double? {
        struct Reply: Decodable { let symbol: String; let currency: String; let price: Double }
        guard let r = try? JSONDecoder().decode(Reply.self, from: data),
              r.symbol == "XAU", r.currency == "USD", r.price > 0 else { return nil }
        return r.price
    }

    /// Each coin's price in `currency`, by id. Coins the reply leaves out
    /// (an id the source no longer knows) are simply missing.
    static func parseCoins(_ data: Data, currency: String) -> [String: Double] {
        guard let r = try? JSONDecoder().decode([String: [String: Double]].self, from: data) else { return [:] }
        return r.compactMapValues { $0[currency.lowercased()].flatMap { $0 > 0 ? $0 : nil } }
    }

    struct Coin: Equatable, Identifiable, Hashable {
        let id: String
        let symbol: String
        let name: String
    }

    /// What a search for a coin found, best match first, at most 20.
    static func parseSearch(_ data: Data) -> [Coin] {
        struct Reply: Decodable {
            struct C: Decodable { let id: String; let symbol: String; let name: String }
            let coins: [C]
        }
        guard let r = try? JSONDecoder().decode(Reply.self, from: data) else { return [] }
        return r.coins.prefix(20).map { Coin(id: $0.id, symbol: $0.symbol.uppercased(), name: $0.name) }
    }

    /// Shown before anything is typed. A fixed list: asking the source which
    /// coins are biggest would be one more call for the same ten names.
    static let popular: [Coin] = [
        .init(id: "bitcoin", symbol: "BTC", name: "Bitcoin"), .init(id: "ethereum", symbol: "ETH", name: "Ethereum"),
        .init(id: "solana", symbol: "SOL", name: "Solana"), .init(id: "ripple", symbol: "XRP", name: "XRP"),
        .init(id: "binancecoin", symbol: "BNB", name: "BNB"), .init(id: "dogecoin", symbol: "DOGE", name: "Dogecoin"),
        .init(id: "cardano", symbol: "ADA", name: "Cardano"), .init(id: "tron", symbol: "TRX", name: "TRON"),
        .init(id: "avalanche-2", symbol: "AVAX", name: "Avalanche"), .init(id: "chainlink", symbol: "LINK", name: "Chainlink"),
    ]

    // MARK: Gold

    /// Grams in one of each unit gold is sold by. 1 lượng = 10 chỉ = 37.5 g.
    static let grams: [String: Double] = ["chi": 3.75, "luong": 37.5, "gram": 1, "oz": 31.1034768]
    static let units = ["chi", "luong", "gram", "oz"]

    /// How much of the metal is gold.
    static let purity: [String: Double] = ["24K": 0.9999, "22K": 0.916, "18K": 0.75, "14K": 0.585]
    static let goldKinds = ["24K", "22K", "18K", "14K"]

    /// The unit a market sells gold by: chỉ in Vietnam, grams in Japan, troy
    /// ounces in dollars.
    static func defaultUnit(for currency: String) -> String {
        switch currency {
        case "VND": return "chi"
        case "USD": return "oz"
        default: return "gram"
        }
    }
}

extension Finance {
    /// One `unit` of gold of `kind`, in the book's money: the world price an
    /// ounce, by the grams in the unit, by its purity, at `usdRate` US
    /// dollars to one unit of the book's money (`AppData.rates["USD"]`; 1 for
    /// a book kept in dollars).
    static func goldUnitPrice(usdPerOunce: Double, unit: String, kind: String, usdRate: Double) -> Double? {
        guard let g = Prices.grams[unit], let p = Prices.purity[kind], usdRate > 0 else { return nil }
        return usdPerOunce / Prices.grams["oz"]! * g * p / usdRate
    }

    /// A holding priced afresh: `value` is quantity × price, rounded to the
    /// book's unit. Anything without a quantity is left as typed.
    static func priced(_ inv: Investment, unitPrice: Double, at date: Date) -> Investment {
        var out = inv
        guard let q = inv.quantity else { return out }
        out.unitPrice = unitPrice
        out.pricedAt = date
        out.value = Int((q * unitPrice).rounded())
        out.updatedOn = date
        return out
    }

    /// How far a priced holding is above what was paid for it; nil when
    /// nothing was typed as paid.
    static func gainOnPaid(_ inv: Investment) -> Int? {
        inv.contributed > 0 ? inv.value - inv.contributed : nil
    }

    /// Whether gold or the coins should be priced again: on, held, and the
    /// oldest price older than a day (gold — the source moves slowly and a
    /// shop's buying price far more) or an hour (coins).
    static func pricesDue(_ data: AppData, now: Date) -> (gold: Bool, coins: Bool) {
        guard data.lookUpPrices ?? true else { return (false, false) }
        func due(_ kind: String, after seconds: TimeInterval) -> Bool {
            (data.investments ?? []).filter { $0.kind == kind && $0.quantity != nil }
                .contains { $0.pricedAt.map { now.timeIntervalSince($0) > seconds } ?? true }
        }
        return (due("gold", after: 24 * 3600), due("crypto", after: 3600))
    }
}
