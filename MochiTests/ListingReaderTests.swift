import Foundation
import Testing
@testable import Mochi

/// Item pages as shops print them for link previews. The Mercari one is the
/// `<head>` of a real item page (2026-10-12), cut to the tags that matter.
struct ListingReaderTests {

    static let mercari = """
    <!DOCTYPE html><html lang="ja"><head><meta charSet="utf-8"/>
    <meta name="application-name" content="メルカリ"/>
    <meta name="product:price:currency" content="JPY"/>
    <meta name="product:price:amount" content="105000"/>
    <meta property="og:title" content="SONY α7III ILCE-7M3 ボディ by メルカリ"/>
    <meta property="og:url" content="https://jp.mercari.com/item/m42404194676"/>
    <meta property="og:site_name" content="メルカリ"/>
    <meta property="og:image" content="https://static.mercdn.net/item/detail/orig/photos/m42404194676_1.jpg?1791699199"/>
    <title>SONY α7III ILCE-7M3 ボディ - メルカリ</title></head><body></body></html>
    """

    @Test func aMercariPageGivesItsNameAndPrice() {
        let l = ListingReader.read(html: Self.mercari)
        #expect(l.title == "SONY α7III ILCE-7M3 ボディ")
        #expect(l.price == 105_000)
        #expect(l.foreignCurrency == nil)
        #expect(l.site == "メルカリ")
        #expect(l.image?.host == "static.mercdn.net")
    }

    @Test func theShopLandsOnTheNameTheBookAlreadyUses() {
        #expect(ListingReader.shopName(site: "メルカリ", host: "jp.mercari.com", known: ["MapCamera", "mercari"]) == "mercari")
        #expect(ListingReader.shopName(site: "メルカリ", host: "jp.mercari.com", known: []) == "Mercari")
        #expect(ListingReader.shopName(site: nil, host: "item.rakuten.co.jp", known: []) == "Rakuten")
        #expect(ListingReader.shopName(site: "Some Shop", host: "shop.example.jp", known: []) == "Some Shop")
        #expect(ListingReader.shopName(site: nil, host: "shop.example.jp", known: []) == "shop.example.jp")
    }

    @Test func aPageWithOnlyAnOfferStillGivesItsPrice() {
        let html = """
        <html><head><meta property='og:title' content='Nikon Z8 | Some Camera Shop'>
        <meta property='og:site_name' content='Some Camera Shop'>
        <script type="application/ld+json">{"@type":"Product","name":"Nikon Z8","offers":{"@type":"Offer","price":"468,000","priceCurrency":"JPY"}}</script>
        </head></html>
        """
        let l = ListingReader.read(html: html)
        #expect(l.title == "Nikon Z8")
        #expect(l.price == 468_000)
    }

    @Test func aPriceInAnotherCurrencyIsLeftForTheUserToType() {
        let html = #"<meta property="og:title" content="Leica M6"><meta name="product:price:amount" content="1230.00"><meta name="product:price:currency" content="USD">"#
        let l = ListingReader.read(html: html)
        #expect(l.price == nil)
        #expect(l.foreignCurrency == "USD")
        #expect(l.title == "Leica M6")
    }

    @Test func aPageWithNoPriceGuessesNone() {
        let html = "<html><head><title>Sigma 56mm F1.4 &amp; hood</title></head><body>¥36,500</body></html>"
        let l = ListingReader.read(html: html)
        #expect(l.price == nil)
        #expect(l.title == "Sigma 56mm F1.4 & hood")
    }

    @Test func rubbishReadsAsNothing() {
        #expect(ListingReader.read(html: "") == Listing())
        #expect(ListingReader.read(html: "<meta content=><meta property=\"og:title\">") == Listing())
    }

    @Test func aTitleKeepsADashThatIsNotTheShops() {
        #expect(ListingReader.cleanTitle("EF 70-200 f2.8 - mint", site: "メルカリ") == "EF 70-200 f2.8 - mint")
        #expect(ListingReader.cleanTitle("iPhone 15 - Yahoo!フリマ（旧PayPayフリマ）", site: "Yahoo!フリマ") == "iPhone 15")
    }

    @Test func theLinkIsFoundInWhateverWasShared() {
        #expect(ListingReader.firstURL(in: "SONY α7III ボディ https://jp.mercari.com/item/m42404194676 #メルカリ")?.absoluteString
                == "https://jp.mercari.com/item/m42404194676")
        #expect(ListingReader.firstURL(in: "no link here") == nil)
    }
}
