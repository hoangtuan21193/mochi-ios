import Foundation

struct Loan: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var person: String
    /// +1 you lent, -1 you owe.
    var direction: Int
    var amount: Int
    var currency: String   // "JPY" or "VND"
    var history: [LoanEvent] = []
    /// When the money is expected to move — they pay you back, or you pay
    /// them. Only a loan with a date enters the cash forecast; without one it
    /// counts in net worth and nowhere else.
    var expectedOn: Date? = nil
}

extension Loan {
    private enum CodingKeys: String, CodingKey { case id, person, direction, amount, currency, history, expectedOn }
    /// Hand-written so a book written before a field existed still opens: the
/// synthesised decoder throws on a missing key, defaults or not.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        person = try c.decode(String.self, forKey: .person)
        direction = try c.decodeIfPresent(Int.self, forKey: .direction) ?? 1
        amount = try c.decodeIfPresent(Int.self, forKey: .amount) ?? 0
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? "JPY"
        history = try c.decodeIfPresent([LoanEvent].self, forKey: .history) ?? []
        expectedOn = try c.decodeIfPresent(Date.self, forKey: .expectedOn)
    }
}

struct LoanEvent: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var date: Date
    var title: String
    var amount: String
}
