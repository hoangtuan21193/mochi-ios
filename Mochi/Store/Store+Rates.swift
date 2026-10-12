import Foundation

extension Store {
    var lookUpRates: Bool { data.lookUpRates ?? true }

    func setLookUpRates(_ on: Bool) {
        data.lookUpRates = on
        save()
        if on { Task { await refreshRates() } }
    }

    /// Looks the rates up when they are due (`Finance.ratesDue`), or now with
    /// `force`. Typed rates for a currency the source has are replaced: a
    /// typed rate stays on the spend it was typed for. False when off or
    /// offline; the rates already kept stay as they were.
    @discardableResult
    func refreshRates(force: Bool = false) async -> Bool {
        guard lookUpRates, force || Finance.ratesDue(data, now: .now) else { return false }
        let base = currency.code
        guard let (body, _) = try? await URLSession.shared.data(from: ExchangeRates.url(base: base)),
              let fetched = ExchangeRates.parse(body, base: base) else { return false }
        // The book may have changed currency while the request was out.
        guard currency.code == base else { return false }
        data.rates = (data.rates ?? [:]).merging(fetched) { _, new in new }
        data.ratesFetched = .now
        save()
        return true
    }

    /// The rate for `code`, looked up first when the book has none yet.
    func rate(for code: String) async -> Double? {
        if let r = data.rates?[code] { return r }
        await refreshRates(force: true)
        return data.rates?[code]
    }
}
