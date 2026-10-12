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
    /// The balance the account was given when it was added or last read off
    /// the bank before the book kept transactions. What it holds today is this
    /// plus every transaction on it (`Finance.balance(of:)`); correcting it
    /// later books an adjustment instead of editing this figure.
    var balance: Int
    /// Free-text qualifier shown small next to the name ("bank", "not withdrawn").
    var note: String = ""
    var ownerID: String = "me"
    /// Set on a balance that waits on a marketplace (Mercari, ヤフオク!) until
    /// it is withdrawn: the account it withdraws to. Such a wallet is still
    /// yours and in net worth, but it pays no bill until it has been moved,
    /// so the forecast counts it only as a withdrawal that can arrive in time.
    var payoutTo: String? = nil
    /// What each withdrawal costs (Mercari ¥200).
    var payoutFee: Int? = nil
    /// Business days a withdrawal takes to arrive.
    var payoutDays: Int? = nil

    var isMarketplace: Bool { !(payoutTo ?? "").isEmpty }
}

extension Wallet {
    private enum CodingKeys: String, CodingKey { case id, name, balance, note, ownerID, payoutTo, payoutFee, payoutDays }
    /// Hand-written so a book written before a field existed still opens: the
/// synthesised decoder throws on a missing key, defaults or not.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        balance = try c.decodeIfPresent(Int.self, forKey: .balance) ?? 0
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        ownerID = try c.decodeIfPresent(String.self, forKey: .ownerID) ?? "me"
        payoutTo = try c.decodeIfPresent(String.self, forKey: .payoutTo)
        payoutFee = try c.decodeIfPresent(Int.self, forKey: .payoutFee)
        payoutDays = try c.decodeIfPresent(Int.self, forKey: .payoutDays)
    }
}

/// Points / store credit. Deliberately NOT counted as cash.
struct PointWallet: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var points: Int
    var note: String = ""
    /// Points that buy anything, anywhere (PayPay): worth their face value
    /// and counted in net worth. Points tied to one shop (MapCamera) are
    /// listed apart and left out of it. nil = tied to one shop.
    var spendAnywhere: Bool? = nil
    /// What one point is worth in the book's currency. nil = 1.
    var yenPerPoint: Double? = nil
}

extension PointWallet {
    private enum CodingKeys: String, CodingKey { case id, name, points, note, spendAnywhere, yenPerPoint }
    /// Hand-written so a book written before a field existed still opens: the
/// synthesised decoder throws on a missing key, defaults or not.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        points = try c.decodeIfPresent(Int.self, forKey: .points) ?? 0
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
        spendAnywhere = try c.decodeIfPresent(Bool.self, forKey: .spendAnywhere)
        yenPerPoint = try c.decodeIfPresent(Double.self, forKey: .yenPerPoint)
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
    /// The account the statement is paid from. With one set, the book posts
    /// the payment as a move on the due day, so cash drops when it really
    /// does and nobody has to retype the bank balance.
    var payFrom: String? = nil
    /// The closing the typed `debt` was read for (or, with no closing day,
    /// the day it was typed). A later closing means a new statement the book
    /// can add up from its own transactions.
    var statementDate: Date? = nil
    /// The last four digits a receipt prints (VISA ****1234), so a scanned
    /// receipt lands on the right card.
    var last4: String? = nil
}

extension CreditCard {
    private enum CodingKeys: String, CodingKey { case id, name, dueDay, limit, debt, ownerID, closingDay, payFrom, statementDate, last4 }
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
        payFrom = try c.decodeIfPresent(String.self, forKey: .payFrom)
        statementDate = try c.decodeIfPresent(Date.self, forKey: .statementDate)
        last4 = try c.decodeIfPresent(String.self, forKey: .last4)
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
    /// A flat fee on every sale, on top of `rate` (eBay's per-order fee). nil = none.
    var fixedFee: Int? = nil
    /// A page that lists what has sold, with {item} where the name goes
    /// (Mercari's sold search). Opened in Safari; nothing is read from it.
    var searchURL: String? = nil
}

extension SalesChannel {
    private enum CodingKeys: String, CodingKey { case id, name, rate, destination, isPoints, fixedFee, searchURL }
    /// Hand-written so a book written before a field existed still opens: the
/// synthesised decoder throws on a missing key, defaults or not.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        rate = try c.decodeIfPresent(Double.self, forKey: .rate) ?? 0
        destination = try c.decodeIfPresent(String.self, forKey: .destination) ?? ""
        isPoints = try c.decodeIfPresent(Bool.self, forKey: .isPoints) ?? false
        fixedFee = try c.decodeIfPresent(Int.self, forKey: .fixedFee)
        searchURL = try c.decodeIfPresent(String.self, forKey: .searchURL)
    }
}
