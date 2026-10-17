import CoreLocation

struct Restaurant: Decodable, Identifiable, Equatable {
    let id: Int
    let name: String
    let kind: String
    let address: String?
    let city: String?
    let lat: Double
    let lng: Double

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }
}
