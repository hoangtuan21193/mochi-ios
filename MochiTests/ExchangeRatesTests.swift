import Foundation
import Testing
@testable import Mochi

/// Rates looked up online: only a reply for the book's own currency is read,
/// and they are looked up at most twice a day, never when switched off.
struct ExchangeRatesTests {
    let reply = #"{"result":"success","provider":"https://www.exchangerate-api.com","base_code":"JPY","time_last_update_unix":1791676951,"rates":{"JPY":1,"USD":0.0068,"VND":169.3,"TWD":0.2172,"XXX":0}}"#

    @Test func aReplyGivesUnitsPerYen() throws {
        let rates = try #require(ExchangeRates.parse(Data(reply.utf8), base: "JPY"))
        #expect(rates["USD"] == 0.0068)
        #expect(rates["VND"] == 169.3)
        #expect(rates["JPY"] == nil, "the book's own currency is not a rate")
        #expect(rates["XXX"] == nil, "a zero rate would book nothing")
        // $25.35 at the looked-up rate.
        #expect(Finance.convert(25.35, rate: rates["USD"]!) == 3_728)
    }

    @Test func aReplyForAnotherBaseOrAnErrorIsNotRead() {
        #expect(ExchangeRates.parse(Data(reply.utf8), base: "VND") == nil)
        #expect(ExchangeRates.parse(Data(#"{"result":"error","error-type":"unsupported-code"}"#.utf8), base: "JPY") == nil)
        #expect(ExchangeRates.parse(Data("<html>".utf8), base: "JPY") == nil)
    }

    @Test func ratesAreLookedUpAtMostTwiceADayAndNeverWhenOff() {
        let now = Date(timeIntervalSince1970: 1_791_700_000)
        var a = AppData.empty
        #expect(Finance.ratesDue(a, now: now), "never looked up")
        a.ratesFetched = now.addingTimeInterval(-3 * 3600)
        #expect(!Finance.ratesDue(a, now: now))
        a.ratesFetched = now.addingTimeInterval(-13 * 3600)
        #expect(Finance.ratesDue(a, now: now))
        a.lookUpRates = false
        #expect(!Finance.ratesDue(a, now: now))
    }
}
