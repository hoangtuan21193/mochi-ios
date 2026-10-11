import Foundation

/// A shopping-credit plan (ショッピングクレジット): a fixed sum paid back in
/// equal monthly instalments at 0% interest. Distinct from a card — there is no
/// limit and no revolving balance — and from a `Loan`, which has no schedule.
/// The item it bought may be long gone; the debt is not.
struct Installment: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    /// Who is collecting: Orico, Jaccs, MapCamera credit…
    var lender: String = ""
    /// The whole amount borrowed.
    var principal: Int
    /// 12 / 24 / 36 / 60.
    var months: Int
    /// The first payment usually differs from the rest — the lender rounds the
    /// monthly figure and puts the remainder in month one.
    var firstAmount: Int
    /// When the first payment left the bank. Every later payment falls on the
    /// same day of the following months.
    var firstDate: Date
    /// The inventory item this bought, if it is in the book. nil when the item
    /// was never entered or has since been deleted.
    var itemID: String? = nil
    /// Paid ahead of schedule (一括返済 or a partial lump sum). Dead: nothing
    /// records one any more, but a book that has one still counts it.
    var extraPaid: Int = 0
    /// Settled in full before the schedule ran out.
    var closed: Bool = false
    /// 分割手数料 over the whole plan, in yen. `principal` already includes it
    /// (it is what leaves the bank); this says how much of that is interest,
    /// so the cash-flow view can count the interest as a cost and the rest as
    /// debt going down. 0 for the usual 0% shopping credit.
    var feeTotal: Int = 0
    /// The account each debit leaves. With one set, the book posts every
    /// debit on its day as a move against the plan.
    var payFrom: String? = nil
}

extension Installment {
    private enum CodingKeys: String, CodingKey {
        case id, name, lender, principal, months, firstAmount, firstDate, itemID, extraPaid, closed, feeTotal, payFrom
    }

    /// Every field added after the first release is read with `decodeIfPresent`.
    /// A `var x: Int = 0` does **not** decode a book that lacks the key — the
    /// synthesised decoder throws and the whole book reads as empty — so the
    /// defaults are restated here, where they actually apply.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try c.decode(String.self, forKey: .name)
        lender = try c.decodeIfPresent(String.self, forKey: .lender) ?? ""
        principal = try c.decode(Int.self, forKey: .principal)
        months = try c.decode(Int.self, forKey: .months)
        firstAmount = try c.decode(Int.self, forKey: .firstAmount)
        firstDate = try c.decode(Date.self, forKey: .firstDate)
        itemID = try c.decodeIfPresent(String.self, forKey: .itemID)
        extraPaid = try c.decodeIfPresent(Int.self, forKey: .extraPaid) ?? 0
        closed = try c.decodeIfPresent(Bool.self, forKey: .closed) ?? false
        feeTotal = try c.decodeIfPresent(Int.self, forKey: .feeTotal) ?? 0
        payFrom = try c.decodeIfPresent(String.self, forKey: .payFrom)
    }
}

/// A plan as the lender's confirmation prints it: 分割支払回数, 初回お支払金額,
/// 2回目以降お支払金額, お支払期間 and 毎月のお支払日. The book stores a principal
/// and works the monthly figure out again, so the sum is done here — one place,
/// so the three forms that take a plan cannot disagree about it.
struct InstallmentSchedule {
    var months = 0
    var firstAmount = 0
    /// 2回目以降お支払金額: every payment after the first.
    var monthly = 0
    /// The month お支払期間 starts: year and 1…12, as printed in "2025/03".
    var startYear = 0
    var startMonth = 0
    /// 毎月のお支払日.
    var payDay = 0

    /// The whole borrowed sum, added back up from the schedule.
    var principal: Int { months > 0 ? firstAmount + monthly * max(0, months - 1) : 0 }

    /// The day the first payment leaves the bank. Days past the 28th are pulled
    /// back so a February start cannot fall out of its own month.
    var firstDate: Date? {
        guard startYear > 1000, (1...12).contains(startMonth) else { return nil }
        return Calendar.current.date(from: DateComponents(year: startYear, month: startMonth,
                                                          day: min(max(payDay, 1), 28)))
    }

    var isComplete: Bool { months > 0 && principal > 0 && firstDate != nil }

    /// nil until every figure the lender printed has been typed in.
    func plan(name: String, lender: String = "", itemID: String? = nil) -> Installment? {
        guard isComplete, let firstDate else { return nil }
        return Installment(name: name, lender: lender, principal: principal, months: months,
                           firstAmount: firstAmount, firstDate: firstDate, itemID: itemID)
    }
}

extension Installment {
    /// The plan read back as the lender's own schedule, to fill an edit form.
    var schedule: InstallmentSchedule {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: firstDate)
        return InstallmentSchedule(months: months, firstAmount: firstAmount, monthly: regular,
                                   startYear: parts.year ?? 0, startMonth: parts.month ?? 0,
                                   payDay: parts.day ?? 1)
    }
}

extension Installment {
    /// What each month after the first costs. Integer division: any remainder
    /// is absorbed by the last payment, so the schedule always sums to the principal.
    var regular: Int {
        guard months > 1 else { return 0 }
        return (principal - firstAmount) / (months - 1)
    }

    /// Payment number `k` (0-based) as the lender will actually debit it.
    func amount(at k: Int) -> Int {
        guard k >= 0, k < months else { return 0 }
        if months == 1 { return principal }
        if k == 0 { return firstAmount }
        if k == months - 1 { return principal - firstAmount - regular * (months - 2) }
        return regular
    }

    /// A debit due on a weekend or holiday leaves the next business day, and
    /// "months paid" is counted from that day too.
    func dueDate(at k: Int) -> Date {
        BusinessCalendar.shift(Calendar.current.date(byAdding: .month, value: k, to: firstDate) ?? firstDate, .later)
    }

    /// The last scheduled payment.
    var endDate: Date { dueDate(at: max(0, months - 1)) }

    /// Payments whose date has come. Counted from the calendar, not ticked by
    /// hand: the bank debits these on its own, and five plans over sixty
    /// months would be three hundred taps.
    func paidCount(on today: Date = .now) -> Int {
        let cal = Calendar.current
        let day = cal.startOfDay(for: today)
        var n = 0
        for k in 0..<months where cal.startOfDay(for: dueDate(at: k)) <= day { n += 1 }
        return n
    }

    func paidBySchedule(on today: Date = .now) -> Int {
        (0..<paidCount(on: today)).reduce(0) { $0 + amount(at: $1) }
    }

    func remaining(on today: Date = .now) -> Int {
        if closed { return 0 }
        return max(0, principal - paidBySchedule(on: today) - extraPaid)
    }

    func isSettled(on today: Date = .now) -> Bool { remaining(on: today) == 0 }

    /// Months still to be debited. A lump sum paid early takes months off the
    /// end of the plan rather than shrinking each payment.
    func monthsLeft(on today: Date = .now) -> Int {
        let left = remaining(on: today)
        guard left > 0 else { return 0 }
        let bySchedule = months - paidCount(on: today)
        guard extraPaid > 0, regular > 0 else { return bySchedule }
        return min(bySchedule, Int((Double(left) / Double(regular)).rounded(.up)))
    }

    /// The next debit, or nil once the plan is done.
    func nextDue(on today: Date = .now) -> (date: Date, amount: Int)? {
        let k = paidCount(on: today)
        guard !isSettled(on: today), k < months else { return nil }
        return (dueDate(at: k), min(amount(at: k), remaining(on: today)))
    }

    /// When the last payment actually leaves, allowing for money paid early.
    func projectedEnd(on today: Date = .now) -> Date {
        let left = monthsLeft(on: today)
        guard left > 0 else { return dueDate(at: max(0, paidCount(on: today) - 1)) }
        return dueDate(at: paidCount(on: today) + left - 1)
    }
}
