import CoreLocation
import MapKit
import Observation

/// One reading of where the phone is, when the app opens, matched against
/// the places the user has saved spending at before. No map lookup, no
/// network: a place is only known because the book has been there.
@Observable
final class NearbyPlace: NSObject, CLLocationManagerDelegate {
    private(set) var place: Finance.Place?
    private(set) var location: CLLocation?
    private let manager = CLLocationManager()
    private weak var store: Store?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    /// Asks once. A user who said no is not asked again; the card just never shows.
    func look(in store: Store) {
        self.store = store
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        location = loc
        place = store?.place(near: loc.coordinate.latitude, loc.coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    /// The area a spot is in, from Apple Maps: a landmark when there is one
    /// ("Shibuya Station"), otherwise the ward and district ("渋谷区, 道玄坂").
    /// This sends the spot to Apple, as the Maps app does; nil offline.
    /// The shop a receipt came from, found on Apple Maps by what it printed:
    /// its phone number first — a match on the number is the shop itself —
    /// then its address, taken only when one place stands there or one
    /// carries the name partly read. Sends the number or the address to
    /// Apple; nil offline or when nothing is sure.
    static func shopName(phone: String?, address: String?, partialName: String,
                         near latitude: Double?, _ longitude: Double?) async -> (name: String, byPhone: Bool)? {
        let center = latitude.flatMap { lat in longitude.map { CLLocationCoordinate2D(latitude: lat, longitude: $0) } }
        if let phone {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = phone
            request.resultTypes = .pointOfInterest
            if let center { request.region = MKCoordinateRegion(center: center, latitudinalMeters: 20_000, longitudinalMeters: 20_000) }
            if let items = try? await MKLocalSearch(request: request).start().mapItems,
               let hit = items.first(where: { $0.phoneNumber.map { ReceiptParser.samePhone($0, phone) } ?? false }),
               let name = hit.name { return (name, true) }
        }
        if let address, let spot = try? await CLGeocoder().geocodeAddressString(address).first?.location {
            let request = MKLocalPointsOfInterestRequest(center: spot.coordinate, radius: 40)
            let items = (try? await MKLocalSearch(request: request).start().mapItems) ?? []
            let key = Finance.searchKey(partialName)
            if !key.isEmpty, let hit = items.first(where: { Finance.matches(nameKey: Finance.searchKey($0.name ?? ""), query: key) }),
               let name = hit.name { return (name, false) }
            if items.count == 1, let name = items[0].name { return (name, false) }
        }
        return nil
    }

    static func areaName(latitude: Double, longitude: Double) async -> String? {
        let marks = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude))
        guard let m = marks?.first else { return nil }
        if let landmark = m.areasOfInterest?.first, !landmark.isEmpty { return landmark }
        let parts = [m.locality, m.subLocality ?? m.thoroughfare].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? m.name : parts.joined(separator: ", ")
    }
}
