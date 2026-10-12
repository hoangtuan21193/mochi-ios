import Foundation

/// Exchange rates looked up online (decision #31), read here so a test can
/// hold a reply and the rates it must give. Only the book's currency code is
/// sent — never an amount, a shop or a date. The source is ExchangeRate-API's
/// open endpoint: free, no key, updated once a day, every currency the
/// receipts are read in (the ECB's list has no đồng).
enum ExchangeRates {
    /// Credited where the switch is, as the open endpoint's terms ask.
    static let source = "ExchangeRate-API"

    static func url(base: String) -> URL {
        URL(string: "https://open.er-api.com/v6/latest/\(base)")!
    }

    /// The rates in a reply, as units of each currency per one of `base` —
    /// the way `AppData.rates` keeps them. nil for an error reply, another
    /// base, or anything unreadable.
    static func parse(_ data: Data, base: String) -> [String: Double]? {
        struct Reply: Decodable {
            let result: String
            let base_code: String?
            let rates: [String: Double]?
        }
        guard let r = try? JSONDecoder().decode(Reply.self, from: data), r.result == "success",
              r.base_code == base, var rates = r.rates?.filter({ $0.value > 0 }), !rates.isEmpty else { return nil }
        rates[base] = nil
        return rates
    }
}

extension Finance {
    /// Whether the rates are old enough to look up again: on, and none yet
    /// or the last lookup over 12 hours before `now`. The source changes once
    /// a day; twice is enough to catch it without asking on every launch.
    static func ratesDue(_ data: AppData, now: Date) -> Bool {
        guard data.lookUpRates ?? true else { return false }
        guard let last = data.ratesFetched else { return true }
        return now.timeIntervalSince(last) > 12 * 3600
    }
}
