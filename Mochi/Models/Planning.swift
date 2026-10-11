import Foundation

/// Money set aside for something already known to be coming: 車検, a trip,
/// a tax bill. What is set aside each month is kept back in Safe to spend,
/// so it never looks free to spend.
struct Goal: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var note: String = ""
    var target: Int
    /// Put aside so far. Typed, or raised by "Add to goal".
    var saved: Int = 0
    /// nil for an open-ended pot like an emergency fund.
    var due: Date? = nil
}

extension Goal {
    private enum CodingKeys: String, CodingKey { case id, name, note, target, saved, due }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        target = try c.decodeIfPresent(Int.self, forKey: .target) ?? 0
        saved = try c.decodeIfPresent(Int.self, forKey: .saved) ?? 0
        due = try c.decodeIfPresent(Date.self, forKey: .due)
    }
}

/// How much a spending category may take in one pay period.
struct BudgetLine: Identifiable, Codable, Hashable {
    var id: String { category }
    var category: String
    var limit: Int
}

/// Fills a transaction in so the same choice is not made twice: a shop or a
/// place decides the category, and optionally the account.
struct Rule: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    /// Matched against the merchant, folded like search is. Empty with a place.
    var contains: String = ""
    /// A place: saved within `radius` metres of here.
    var latitude: Double? = nil
    var longitude: Double? = nil
    var radius: Double = 80
    var placeName: String = ""
    var category: String = ""
    var account: String? = nil
    /// "Ask every time" — the shop sells everything (Amazon).
    var ask: Bool = false
    /// A line over this much here is offered as a belonging.
    var belongingOver: Int? = nil
}

extension Rule {
    private enum CodingKeys: String, CodingKey {
        case id, contains, latitude, longitude, radius, placeName, category, account, ask, belongingOver
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        contains = try c.decodeIfPresent(String.self, forKey: .contains) ?? ""
        latitude = try c.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try c.decodeIfPresent(Double.self, forKey: .longitude)
        radius = try c.decodeIfPresent(Double.self, forKey: .radius) ?? 80
        placeName = try c.decodeIfPresent(String.self, forKey: .placeName) ?? ""
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        account = try c.decodeIfPresent(String.self, forKey: .account)
        ask = try c.decodeIfPresent(Bool.self, forKey: .ask) ?? false
        belongingOver = try c.decodeIfPresent(Int.self, forKey: .belongingOver)
    }
}

/// A holding typed from a broker's statement (NISA, iDeCo). Mochi records it;
/// it gives no advice about it.
struct Investment: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var provider: String = ""
    /// "tsumitate", "growth", "ideco", "other" — how the NISA allowance is counted.
    var kind: String = "other"
    /// What has gone in over the years.
    var contributed: Int = 0
    /// Contributions made in the current calendar year, for the allowance.
    var contributedThisYear: Int = 0
    var value: Int
    var updatedOn: Date = .now
    /// A regular purchase: amount, day and what pays it. It shows in the
    /// forecast like any card charge.
    var monthly: Int = 0
    var monthlyDay: Int = 27
    var paidBy: String = ""
}

extension Investment {
    private enum CodingKeys: String, CodingKey {
        case id, name, provider, kind, contributed, contributedThisYear, value, updatedOn, monthly, monthlyDay, paidBy
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        provider = try c.decodeIfPresent(String.self, forKey: .provider) ?? ""
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "other"
        contributed = try c.decodeIfPresent(Int.self, forKey: .contributed) ?? 0
        contributedThisYear = try c.decodeIfPresent(Int.self, forKey: .contributedThisYear) ?? 0
        value = try c.decodeIfPresent(Int.self, forKey: .value) ?? 0
        updatedOn = try c.decodeIfPresent(Date.self, forKey: .updatedOn) ?? .now
        monthly = try c.decodeIfPresent(Int.self, forKey: .monthly) ?? 0
        monthlyDay = try c.decodeIfPresent(Int.self, forKey: .monthlyDay) ?? 27
        paidBy = try c.decodeIfPresent(String.self, forKey: .paidBy) ?? ""
    }
}

/// Who shares the book, and which accounts the partner sees.
struct Household: Codable, Hashable {
    var partnerName: String = ""
    /// "invited", "joined" or "" when nobody is invited.
    var partnerState: String = ""
    /// Accounts both can see and add to. The rest stay the owner's.
    var sharedAccounts: [String] = []
    var shareGoals: Bool = true
    var shareBills: Bool = true
}

/// Which local notifications the user wants. Every one is worked out on the
/// device; nothing is sent to a server.
struct NotificationPrefs: Codable, Hashable {
    var payments = true
    var shortfall = true
    var largeSpend = true
    var largeSpendOver = 30_000
    var subscriptions = true
    var weeklyCheckin = true
    var warranty = false
    var worthReminder = false
}

extension NotificationPrefs {
    private enum CodingKeys: String, CodingKey {
        case payments, shortfall, largeSpend, largeSpendOver, subscriptions, weeklyCheckin, warranty, worthReminder
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        payments = try c.decodeIfPresent(Bool.self, forKey: .payments) ?? true
        shortfall = try c.decodeIfPresent(Bool.self, forKey: .shortfall) ?? true
        largeSpend = try c.decodeIfPresent(Bool.self, forKey: .largeSpend) ?? true
        largeSpendOver = try c.decodeIfPresent(Int.self, forKey: .largeSpendOver) ?? 30_000
        subscriptions = try c.decodeIfPresent(Bool.self, forKey: .subscriptions) ?? true
        weeklyCheckin = try c.decodeIfPresent(Bool.self, forKey: .weeklyCheckin) ?? true
        warranty = try c.decodeIfPresent(Bool.self, forKey: .warranty) ?? false
        worthReminder = try c.decodeIfPresent(Bool.self, forKey: .worthReminder) ?? false
    }
}

extension Household {
    private enum CodingKeys: String, CodingKey { case partnerName, partnerState, sharedAccounts, shareGoals, shareBills }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        partnerName = try c.decodeIfPresent(String.self, forKey: .partnerName) ?? ""
        partnerState = try c.decodeIfPresent(String.self, forKey: .partnerState) ?? ""
        sharedAccounts = try c.decodeIfPresent([String].self, forKey: .sharedAccounts) ?? []
        shareGoals = try c.decodeIfPresent(Bool.self, forKey: .shareGoals) ?? true
        shareBills = try c.decodeIfPresent(Bool.self, forKey: .shareBills) ?? true
    }
}
