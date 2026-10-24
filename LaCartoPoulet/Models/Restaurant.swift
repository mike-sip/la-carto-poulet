import CoreLocation

struct Restaurant: Decodable, Identifiable, Equatable {
    let id: Int
    let name: String
    let kind: String
    let address: String?
    let city: String?
    let lat: Double
    let lng: Double
    /// Only the map query sends it; nil when nobody rated the place.
    var avgStars: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, kind, address, city, lat, lng
        case avgStars = "avg_stars"
    }

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }
}
