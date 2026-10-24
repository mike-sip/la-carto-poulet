import MapKit
import Observation

@Observable @MainActor
final class MapViewModel {
    /// Wider than this (in degrees of latitude, ~110 km) the map shows the "Zoome" pill instead of loading.
    static let maxLatitudeSpan = 1.0

    private(set) var restaurants: [Restaurant] = []
    private(set) var isTooFar = false
    private(set) var isEmptyArea = false
    private(set) var isLoading = false
    private(set) var failed = false
    private(set) var foundRestaurants: [Restaurant] = []
    private(set) var foundPlaces: [Place] = []
    /// The query the found results belong to, so "no results" never shows for a query still being typed.
    private(set) var searchedQuery = ""

    private let repository: RestaurantRepository
    private let findPlaces: (String) async -> [Place]

    init(repository: RestaurantRepository = SupabaseRestaurantRepository(),
         findPlaces: @escaping (String) async -> [Place] = MapViewModel.applePlaces) {
        self.repository = repository
        self.findPlaces = findPlaces
    }

    struct Place: Identifiable {
        let id = UUID()
        let name: String
        let detail: String?
        let coordinate: CLLocationCoordinate2D
    }

    /// Restaurants by name and French towns or addresses. A failed half just shows no results.
    func search(_ query: String) async {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else {
            foundRestaurants = []
            foundPlaces = []
            return
        }
        async let restaurants = try? repository.search(query)
        async let places = findPlaces(query)
        let (r, p) = await (restaurants, places)
        guard !Task.isCancelled else { return }  // a newer query is on its way
        foundRestaurants = r ?? []
        foundPlaces = p
        searchedQuery = query
    }

    static func applePlaces(_ query: String) async -> [Place] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        request.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 46.6, longitude: 2.4),
                                            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10))
        let items = (try? await MKLocalSearch(request: request).start().mapItems) ?? []
        return items.filter { $0.placemark.isoCountryCode == "FR" }.prefix(5).map {
            Place(name: $0.name ?? query, detail: $0.placemark.postalCode, coordinate: $0.placemark.coordinate)
        }
    }

    /// One attempt. Returns false on a network error so the caller can retry; old markers stay.
    func load(_ region: MKCoordinateRegion) async -> Bool {
        isTooFar = region.span.latitudeDelta > Self.maxLatitudeSpan
        guard !isTooFar else { return true }
        isLoading = true
        defer { isLoading = false }
        do {
            restaurants = try await repository.restaurants(in: region)
            isEmptyArea = restaurants.isEmpty
            failed = false
            return true
        } catch {
            if Task.isCancelled { return true }  // the map moved on, a new load is running
            failed = true
            return false
        }
    }

    struct Cluster: Identifiable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let restaurants: [Restaurant]
    }

    /// Groups restaurants into a grid of about 4×6 cells over the visible region; one cell = one nest.
    static func clusters(_ restaurants: [Restaurant], in region: MKCoordinateRegion) -> [Cluster] {
        let cellLat = region.span.latitudeDelta / 6, cellLng = region.span.longitudeDelta / 4
        guard cellLat > 0, cellLng > 0 else { return [] }
        let cells = Dictionary(grouping: restaurants) {
            "\(Int((($0.lat) / cellLat).rounded(.down)))/\(Int(($0.lng / cellLng).rounded(.down)))"
        }
        return cells.map { key, members in
            let lat = members.map(\.lat).reduce(0, +) / Double(members.count)
            let lng = members.map(\.lng).reduce(0, +) / Double(members.count)
            return Cluster(id: members.count == 1 ? "r\(members[0].id)" : key,
                           coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                           restaurants: members)
        }
    }
}
