import Foundation
import Testing
@testable import Mochi

/// When a Japanese bank moves money: the national holidays worked out from
/// the law, and the two directions a payment slides when its day is not a
/// business day.
struct BusinessCalendarTests {
    static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func holidays2026MatchTheCabinetOfficeList() {
        let expected: Set<Int> = [101, 112, 211, 223, 320, 429, 503, 504, 505, 506,
                                  720, 811, 921, 922, 923, 1012, 1103, 1123]
        #expect(BusinessCalendar.holidays(in: 2026) == expected)
    }

    @Test func holidays2027MatchTheCabinetOfficeList() {
        // 2027: 春分 21 Mar is a Sunday, so the 22nd is off; 秋分 23 Sep.
        let expected: Set<Int> = [101, 111, 211, 223, 321, 322, 429, 503, 504, 505,
                                  719, 811, 920, 923, 1011, 1103, 1123]
        #expect(BusinessCalendar.holidays(in: 2027) == expected)
    }

    @Test func salaryOnASundayIsPaidTheFridayBefore() {
        // 25 Oct 2026 is a Sunday.
        #expect(BusinessCalendar.shift(Self.day(2026, 10, 25), .earlier) == Self.day(2026, 10, 23))
    }

    @Test func aDebitOnALongWeekendLeavesTheTuesdayAfter() {
        // 10 Oct 2026 is a Saturday and the 12th is Sports Day.
        #expect(BusinessCalendar.shift(Self.day(2026, 10, 10), .later) == Self.day(2026, 10, 13))
        #expect(BusinessCalendar.shift(Self.day(2026, 12, 27), .later) == Self.day(2026, 12, 28))
    }

    @Test func banksAreClosedOverNewYear() {
        // 31 Dec 2026 is a Thursday, 4 Jan 2027 a Monday.
        #expect(BusinessCalendar.shift(Self.day(2026, 12, 31), .later) == Self.day(2027, 1, 4))
        #expect(BusinessCalendar.shift(Self.day(2027, 1, 2), .earlier) == Self.day(2026, 12, 30))
    }

    @Test func aCardChargeIsNotMoved() {
        #expect(BusinessCalendar.shift(Self.day(2026, 10, 10), .none) == Self.day(2026, 10, 10))
    }

    @Test func businessDaysSkipWeekendsAndHolidays() {
        // Thu 1 Oct + 3 business days: Fri 2, Mon 5, Tue 6.
        #expect(BusinessCalendar.adding(businessDays: 3, to: Self.day(2026, 10, 1)) == Self.day(2026, 10, 6))
        // To arrive by Tue 27 Oct, three business days before: Wed 21 (22, 23, 26).
        #expect(BusinessCalendar.latestStart(businessDays: 3, arrivingBy: Self.day(2026, 10, 27)) == Self.day(2026, 10, 21))
    }

    // MARK: in the forecast and the book

    func book() -> AppData {
        var a = AppData()
        a.wallets = [Wallet(name: "Bank", balance: 500_000)]
        a.cards = [CreditCard(name: "Card", dueDay: 27, debt: 100_000, closingDay: 31, payFrom: "Bank")]
        a.recurring = [Recurring(name: "Salary", amount: 380_000, kind: "income", category: "salary", day: 25, paidBy: "Bank"),
                       Recurring(name: "Phone", amount: 5_000, kind: "expense", category: "utility", day: 25, paidBy: "Card")]
        return a
    }

    @Test func theForecastPutsSalaryOnTheFridayBefore() {
        let a = book()
        let events = Finance.events(a, from: Self.day(2026, 10, 1), to: Self.day(2026, 10, 31))
        let salary = events.first { $0.label == "Salary" }
        #expect(salary.map { Calendar.current.isDate($0.date, inSameDayAs: Self.day(2026, 10, 23)) } == true)
    }

    @Test func untilPaydayEndsTheDayTheSalaryLands() {
        let a = book()
        #expect(Finance.Horizon.payday.end(a, today: Self.day(2026, 10, 1)) == Self.day(2026, 10, 23))
    }

    @Test func salaryPostsOnTheDayItLandsAndOnlyThen() {
        var a = book()
        a.ledgerStart = Self.day(2026, 10, 1)
        a.postedThrough = Self.day(2026, 9, 30)
        a.transactions = []
        let posted = Finance.duePostings(a, through: Self.day(2026, 10, 26)).filter { $0.merchant == "Salary" }
        #expect(posted.count == 1)
        #expect(posted.first.map { Calendar.current.isDate($0.date, inSameDayAs: Self.day(2026, 10, 23)) } == true)
    }

    @Test func aBillOnACardKeepsItsDay() {
        // Charged on the card on Sunday the 25th; only the card's own debit moves.
        let a = book()
        #expect(Finance.shift(for: a.recurring![1], a) == .none)
        #expect(Finance.shift(for: a.recurring![0], a) == .earlier)
    }
}
