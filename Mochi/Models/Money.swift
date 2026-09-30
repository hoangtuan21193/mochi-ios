import Foundation

// MARK: - Where money sits, and what it is owed to

struct Owner: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
}

/// A place cash sits: bank account, marketplace wallet, physical cash.
/// There is no grouping — every wallet counts as real cash.
struct Wallet: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var balance: Int
    /// Free-text qualifier shown small next to the name ("bank", "not withdrawn").
    var note: String = ""
    var ownerID: String = "me"
}

extension Wallet {
    private enum CodingKeys: String, CodingKey { case id, name, balance, note, ownerID }
    /// Hand-written so a book written before a field existed still opens: the
/// synthesised decoder throws on a missing key, defaults or not.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        balance = try c.decodeIfPresent(Int.self, forKey: .balance) ?? 0
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        ownerID = try c.decodeIfPresent(String.self, forKey: .ownerID) ?? "me"
    }
}

/// Points / store credit. Deliberately NOT counted as cash.
struct PointWallet: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var points: Int
    var note: String = ""
}

extension PointWallet {
    private enum CodingKeys: String, CodingKey { case id, name, points, note }
    /// Hand-written so a book written before a field existed still opens: the
/// synthesised decoder throws on a missing key, defaults or not.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        points = try c.decodeIfPresent(Int.self, forKey: .points) ?? 0
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

struct CreditCard: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    /// Day of month the statement is paid (26, 27, 4…).
    var dueDay: Int
    /// Dead: the limit was never a number anyone acted on. Kept with a default
    /// so books that stored it still decode; nothing reads or shows it.
    var limit: Int = 0
    /// What the last statement said, typed in by hand.
    var debt: Int
    var ownerID: String = "me"
    /// 締め日 — the day the statement closes. Charges after it are not in
    /// `debt` yet; they land on the statement after. nil means unknown, and the
    /// book falls back to the calendar month.
    var closingDay: Int? = nil
}

extension CreditCard {
    private enum CodingKeys: String, CodingKey { case id, name, dueDay, limit, debt, ownerID, closingDay }
    /// Hand-written so a book written before a field existed still opens: the
/// synthesised decoder throws on a missing key, defaults or not.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        dueDay = try c.decodeIfPresent(Int.self, forKey: .dueDay) ?? 1
        limit = try c.decodeIfPresent(Int.self, forKey: .limit) ?? 0
        debt = try c.decodeIfPresent(Int.self, forKey: .debt) ?? 0
        ownerID = try c.decodeIfPresent(String.self, forKey: .ownerID) ?? "me"
        closingDay = try c.decodeIfPresent(Int.self, forKey: .closingDay)
    }
}

/// How an item gets sold. Cash channels take a % fee; point channels pay a % bonus in points.
struct SalesChannel: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    /// Percent. Fee for cash channels, bonus rate for point channels.
    var rate: Double
    /// Kept only so older books decode. Sales no longer credit a wallet, so
    /// nothing reads or writes it.
    var destination: String = ""
    var isPoints: Bool = false
}

extension SalesChannel {
    private enum CodingKeys: String, CodingKey { case id, name, rate, destination, isPoints }
    /// Hand-written so a book written before a field existed still opens: the
/// synthesised decoder throws on a missing key, defaults or not.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        rate = try c.decodeIfPresent(Double.self, forKey: .rate) ?? 0
        destination = try c.decodeIfPresent(String.self, forKey: .destination) ?? ""
        isPoints = try c.decodeIfPresent(Bool.self, forKey: .isPoints) ?? false
    }
}
