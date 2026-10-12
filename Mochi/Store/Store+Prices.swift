import Foundation

extension Store {
    var lookUpPrices: Bool { data.lookUpPrices ?? true }

    func setLookUpPrices(_ on: Bool) {
        data.lookUpPrices = on
        save()
        if on { Task { await refreshPrices() } }
    }

    var goldHoldings: [Investment] { investments.filter { $0.kind == "gold" } }
    var coinHoldings: [Investment] { investments.filter { $0.kind == "crypto" } }

    /// Prices gold and coins when due (`Finance.pricesDue`), or now with
    /// `force`, and writes each holding's value. Offline, a holding keeps
    /// its last price and the time it came (decision #31).
    func refreshPrices(force: Bool = false) async {
        guard lookUpPrices else { return }
        let due = Finance.pricesDue(data, now: .now)
        let book = currency.code
        var prices: [String: Double] = [:]  // investment id → unit price

        if (force || due.gold), !goldHoldings.isEmpty, let usdPerOunce = await goldPrice() {
            let usdRate = book == "USD" ? 1 : await rate(for: "USD")
            for g in goldHoldings {
                if let usdRate, let p = Finance.goldUnitPrice(usdPerOunce: usdPerOunce, unit: g.unit ?? "gram",
                                                              kind: g.goldKind ?? "24K", usdRate: usdRate) {
                    prices[g.id] = p
                }
            }
        }
        let ids = Array(Set(coinHoldings.compactMap(\.coinID))).sorted()
        if (force || due.coins), !ids.isEmpty {
            let found = await coinPrices(ids)
            for c in coinHoldings { if let id = c.coinID, let p = found[id] { prices[c.id] = p } }
        }
        // The book may have changed currency, or a holding gone, meanwhile.
        guard !prices.isEmpty, currency.code == book else { return }
        let now = Date.now
        data.investments = investments.map { inv in prices[inv.id].map { Finance.priced(inv, unitPrice: $0, at: now) } ?? inv }
        save()
    }

    private func goldPrice() async -> Double? {
        guard let (body, _) = try? await URLSession.shared.data(from: Prices.goldURL) else { return nil }
        return Prices.parseGold(body)
    }

    /// The coins' prices in the book's money, by id; empty when offline.
    func coinPrices(_ ids: [String]) async -> [String: Double] {
        guard lookUpPrices, !ids.isEmpty,
              let (body, _) = try? await URLSession.shared.data(from: Prices.coinsURL(ids: ids, currency: currency.code))
        else { return [:] }
        return Prices.parseCoins(body, currency: currency.code)
    }

    /// One unit of gold of `kind` now, for the Add gold sheet's preview.
    func goldUnitPrice(unit: String, kind: String) async -> Double? {
        guard lookUpPrices, let usdPerOunce = await goldPrice() else { return nil }
        let usdRate = currency.code == "USD" ? 1 : await rate(for: "USD")
        return usdRate.flatMap { Finance.goldUnitPrice(usdPerOunce: usdPerOunce, unit: unit, kind: kind, usdRate: $0) }
    }

    /// Coins whose name or ticker matches what was typed. Only the typed text
    /// is sent.
    func searchCoins(_ query: String) async -> [Prices.Coin] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard lookUpPrices, q.count >= 2,
              let (body, _) = try? await URLSession.shared.data(from: Prices.searchURL(q)) else { return [] }
        return Prices.parseSearch(body)
    }
}
