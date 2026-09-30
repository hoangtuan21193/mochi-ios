import Foundation

enum AttributeKind: String, Codable, CaseIterable {
    /// Yes/No, a fixed list, a plain number, or free text. `number` exists
    /// because things like a shutter count are a figure you read off the body,
    /// not one of four buckets someone guessed at in advance.
    case bool, options, number, text
}

struct AttributeSpec: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var kind: AttributeKind
    var options: [String] = []
    /// Shown after a number field: "shots", "%", "cycles".
    var unit: String = ""
}

extension AttributeSpec {
    private enum CodingKeys: String, CodingKey { case id, name, kind, options, unit }
    /// Hand-written so a book written before a field existed still opens: the
/// synthesised decoder throws on a missing key, defaults or not.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decodeIfPresent(AttributeKind.self, forKey: .kind) ?? .text
        options = try c.decodeIfPresent([String].self, forKey: .options) ?? []
        unit = try c.decodeIfPresent(String.self, forKey: .unit) ?? ""
    }
}

/// A category shapes an item's attribute checklist. "Other" is not stored —
/// it is the built-in empty choice.
struct Category: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var attributes: [AttributeSpec]
}

struct SaleRecord: Codable, Hashable {
    var price: Int
    var channel: String
    /// What actually arrived after fees and postage.
    var net: Int
    var date: Date
    /// What postage cost on this sale.
    var shipping: Int = 0
}

extension SaleRecord {
    private enum CodingKeys: String, CodingKey { case price, channel, net, date, shipping }
    /// Hand-written so a book written before a field existed still opens: the
/// synthesised decoder throws on a missing key, defaults or not.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        price = try c.decode(Int.self, forKey: .price)
        channel = try c.decodeIfPresent(String.self, forKey: .channel) ?? ""
        net = try c.decodeIfPresent(Int.self, forKey: .net) ?? price
        date = try c.decode(Date.self, forKey: .date)
        shipping = try c.decodeIfPresent(Int.self, forKey: .shipping) ?? 0
    }
}

struct Item: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var categoryName: String = ""
    /// true = keeping it, excluded from resale projections and net-cash-after-selling.
    var keep: Bool = false
    var boughtOn: Date
    var buyPrice: Int
    /// The shop it came from — MapCamera, Hardoff, a Mercari seller. Distinct
    /// from `cardName`, which is only how it was paid for.
    var boughtFrom: String = ""
    var cardName: String
    var pointsEarned: Int = 0
    var estimatedPrice: Int
    var plannedChannel: String
    var accessories: String = ""
    var condition: String = ""
    /// Ordered key/value pairs, seeded from the category and editable per item.
    var attributes: [[String]] = []
    var sale: SaleRecord? = nil
    /// Per-item override of a point channel's bonus rate, in percent.
    var pointRateOverride: Double? = nil
    /// What postage is expected to cost. nil falls back to the app-wide default
    /// — a lens in a small box is not a tripod.
    var shippingFee: Int? = nil

    var isSold: Bool { sale != nil }
}

extension Item {
    private enum CodingKeys: String, CodingKey {
        case id, name, categoryName, keep, boughtOn, buyPrice, boughtFrom, cardName, pointsEarned
        case estimatedPrice, plannedChannel, accessories, condition, attributes, sale, pointRateOverride, shippingFee
    }
    /// Hand-written so a book written before a field existed still opens: the
/// synthesised decoder throws on a missing key, defaults or not.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        categoryName = try c.decodeIfPresent(String.self, forKey: .categoryName) ?? ""
        keep = try c.decodeIfPresent(Bool.self, forKey: .keep) ?? false
        boughtOn = try c.decodeIfPresent(Date.self, forKey: .boughtOn) ?? .distantPast
        buyPrice = try c.decodeIfPresent(Int.self, forKey: .buyPrice) ?? 0
        boughtFrom = try c.decodeIfPresent(String.self, forKey: .boughtFrom) ?? ""
        cardName = try c.decodeIfPresent(String.self, forKey: .cardName) ?? ""
        pointsEarned = try c.decodeIfPresent(Int.self, forKey: .pointsEarned) ?? 0
        estimatedPrice = try c.decodeIfPresent(Int.self, forKey: .estimatedPrice) ?? 0
        plannedChannel = try c.decodeIfPresent(String.self, forKey: .plannedChannel) ?? ""
        accessories = try c.decodeIfPresent(String.self, forKey: .accessories) ?? ""
        condition = try c.decodeIfPresent(String.self, forKey: .condition) ?? ""
        attributes = try c.decodeIfPresent([[String]].self, forKey: .attributes) ?? []
        sale = try c.decodeIfPresent(SaleRecord.self, forKey: .sale)
        pointRateOverride = try c.decodeIfPresent(Double.self, forKey: .pointRateOverride)
        shippingFee = try c.decodeIfPresent(Int.self, forKey: .shippingFee)
    }
}
