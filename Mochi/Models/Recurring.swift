import Foundation
import SwiftUI

/// Something that happens every month on the same day without being a
/// purchase you would enter: salary landing, rent, a subscription, insurance.
/// A commitment, not a debt — next year's rent is not owed today — so it
/// shapes Safe to spend and the forecast but never net worth.
struct Recurring: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var amount: Int
    /// "income" or "expense".
    var kind: String
    /// "salary", "rent", "utility", "subscription", "insurance", "other".
    var category: String = "other"
    /// Day of the month it lands or is charged (1…31).
    var day: Int
    /// Where it lands (income) or what pays it: a wallet name, or a **card**
    /// name. A card-paid bill is not a cash event on its day — it is part of
    /// that card's next statement, and cash leaves on the card's due day.
    var paidBy: String = ""
    var active: Bool = true

    var isIncome: Bool { kind == "income" }

    static let expenseCategories = ["rent", "utility", "subscription", "insurance", "other"]
    /// The stored raw value written out for a person to read. The raw value is
    /// what the book keeps and what a picker compares, so it never changes with
    /// the language; only this does.
    static func categoryName(_ raw: String) -> LocalizedStringKey {
        switch raw {
        case "salary": return "Salary"
        case "rent": return "Rent"
        case "utility": return "Utilities"
        case "subscription": return "Subscription"
        case "insurance": return "Insurance"
        default: return "Other"
        }
    }
}

extension Recurring {
    private enum CodingKeys: String, CodingKey { case id, name, amount, kind, category, day, paidBy, active }
    /// Hand-written so a book written before a field existed still opens: the
/// synthesised decoder throws on a missing key, defaults or not.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        amount = try c.decodeIfPresent(Int.self, forKey: .amount) ?? 0
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "expense"
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? "other"
        day = try c.decodeIfPresent(Int.self, forKey: .day) ?? 1
        paidBy = try c.decodeIfPresent(String.self, forKey: .paidBy) ?? ""
        active = try c.decodeIfPresent(Bool.self, forKey: .active) ?? true
    }
}

/// The book's shape on one day, kept so the month can be compared with the
/// last: is cash actually up or down, is net worth. Taken by the app on its
/// own once a month; never typed.
struct CashSnapshot: Codable, Hashable {
    var date: Date
    var cash: Int
    var cardDebt: Int
    var installmentDebt: Int
    var netWorth: Int
}
