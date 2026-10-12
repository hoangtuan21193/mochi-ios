import Foundation

/// Which days a Japanese bank moves money on. Salary that falls on a weekend
/// or holiday is paid the business day before; a card or plan debit on one
/// leaves the business day after. Getting this wrong puts the 25th's salary
/// two days late and a card debit three days early, which is exactly the
/// window "can I pay?" is asked about.
///
/// The holidays are worked out from the law (fixed days, Happy Monday, the
/// equinoxes, 振替休日, 国民の休日), not from a table, so no year runs off the
/// end. Banks also close 31 Dec – 3 Jan. A one-off holiday the Diet adds (as
/// for the 2020 Olympics) is not here and would need adding by hand.
enum BusinessCalendar {
    enum Shift {
        /// Paid on the nominal day whatever it is — a charge on a card.
        case none
        /// Moved back to the business day before — salary.
        case earlier
        /// Moved on to the business day after — debits.
        case later
    }

    static func shift(_ date: Date, _ rule: Shift) -> Date {
        let cal = Calendar.current
        var d = cal.startOfDay(for: date)
        switch rule {
        case .none: return d
        case .earlier:
            while !isBusinessDay(d) { d = cal.date(byAdding: .day, value: -1, to: d)! }
        case .later:
            while !isBusinessDay(d) { d = cal.date(byAdding: .day, value: 1, to: d)! }
        }
        return d
    }

    /// The business day `n` business days after `date` — a marketplace
    /// withdrawal requested today that takes three of them.
    static func adding(businessDays n: Int, to date: Date) -> Date {
        let cal = Calendar.current
        var d = cal.startOfDay(for: date)
        var left = n
        while left > 0 {
            d = cal.date(byAdding: .day, value: 1, to: d)!
            if isBusinessDay(d) { left -= 1 }
        }
        return d
    }

    /// The latest business day a request can be made and still land before
    /// `deadline` — a debit leaves early on its day, so money arriving that
    /// same day is too late.
    static func latestStart(businessDays n: Int, arrivingBy deadline: Date) -> Date {
        let cal = Calendar.current
        let end = cal.startOfDay(for: deadline)
        var d = cal.date(byAdding: .day, value: -1, to: end)!
        while !isBusinessDay(d) || adding(businessDays: n, to: d) >= end {
            d = cal.date(byAdding: .day, value: -1, to: d)!
        }
        return d
    }

    static func isBusinessDay(_ date: Date) -> Bool {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 { return false }
        let c = cal.dateComponents([.year, .month, .day], from: date)
        let (m, d) = (c.month!, c.day!)
        if (m == 12 && d == 31) || (m == 1 && d <= 3) { return false }
        return !holidays(in: c.year!).contains(key(m, d))
    }

    static func isHoliday(_ date: Date) -> Bool {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return holidays(in: c.year!).contains(key(c.month!, c.day!))
    }

    // MARK: - The national holidays

    private static func key(_ month: Int, _ day: Int) -> Int { month * 100 + day }

    private static let cache = NSCache<NSNumber, NSSet>()

    /// Every national holiday of `year`, as month * 100 + day.
    static func holidays(in year: Int) -> Set<Int> {
        if let hit = cache.object(forKey: NSNumber(value: year)) as? Set<Int> { return hit }
        var days: Set<Int> = [key(1, 1), key(2, 11), key(2, 23), key(4, 29), key(5, 3), key(5, 4),
                              key(5, 5), key(8, 11), key(11, 3), key(11, 23)]
        days.insert(key(1, nthMonday(2, of: 1, year)))   // 成人の日
        days.insert(key(7, nthMonday(3, of: 7, year)))   // 海の日
        days.insert(key(9, nthMonday(3, of: 9, year)))   // 敬老の日
        days.insert(key(10, nthMonday(2, of: 10, year))) // スポーツの日
        days.insert(key(3, equinox(year, base: 20.8431)))  // 春分の日
        days.insert(key(9, equinox(year, base: 23.2488)))  // 秋分の日

        let cal = Calendar.current
        func date(_ k: Int) -> Date { cal.date(from: DateComponents(year: year, month: k / 100, day: k % 100))! }
        func k(_ d: Date) -> Int { key(cal.component(.month, from: d), cal.component(.day, from: d)) }

        // 国民の休日: an ordinary day with a holiday on both sides.
        for h in days {
            let twoOn = cal.date(byAdding: .day, value: 2, to: date(h))!
            let between = cal.date(byAdding: .day, value: 1, to: date(h))!
            if cal.component(.year, from: twoOn) == year, days.contains(k(twoOn)), !days.contains(k(between)),
               cal.component(.weekday, from: between) != 1 {
                days.insert(k(between))
            }
        }
        // 振替休日: a holiday on a Sunday moves to the next day that is not one.
        for h in days.sorted() where cal.component(.weekday, from: date(h)) == 1 {
            var d = cal.date(byAdding: .day, value: 1, to: date(h))!
            while days.contains(k(d)) { d = cal.date(byAdding: .day, value: 1, to: d)! }
            if cal.component(.year, from: d) == year { days.insert(k(d)) }
        }
        cache.setObject(days as NSSet, forKey: NSNumber(value: year))
        return days
    }

    private static func nthMonday(_ n: Int, of month: Int, _ year: Int) -> Int {
        let cal = Calendar.current
        let first = cal.date(from: DateComponents(year: year, month: month, day: 1))!
        let weekday = cal.component(.weekday, from: first) // 1 = Sunday, 2 = Monday
        let firstMonday = 1 + (9 - weekday) % 7
        return firstMonday + 7 * (n - 1)
    }

    /// The equinox day by the formula valid for 1980–2099.
    private static func equinox(_ year: Int, base: Double) -> Int {
        let y = Double(year - 1980)
        return Int(base + 0.242194 * y - floor(y / 4))
    }
}
