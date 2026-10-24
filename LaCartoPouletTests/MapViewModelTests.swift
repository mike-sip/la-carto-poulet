import MapKit
import Testing
@testable import LaCartoPoulet

private struct Offline: Error {}

private final class FakeRepository: RestaurantRepository, @unchecked Sendable {
    var result: Result<[Restaurant], Error>
    var calls = 0
    init(_ result: Result<[Restaurant], Error>) { self.result = result }

    func restaurants(in region: MKCoordinateRegion) async throws -> [Restaurant] {
        calls += 1
        return try result.get()
    }

    func search(_ query: String) async throws -> [Restaurant] {
        calls += 1
        return try result.get()
    }
}

private func restaurant(_ id: Int, _ lat: Double, _ lng: Double) -> Restaurant {
    Restaurant(id: id, name: "Poulet \(id)", kind: "fast_food", address: nil, city: nil, lat: lat, lng: lng)
}

private let lyon = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 45.76, longitude: 4.84),
                                      span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))

@MainActor
struct MapViewModelTests {
    @Test func loadShowsRestaurants() async {
        let model = MapViewModel(repository: FakeRepository(.success([restaurant(1, 45.76, 4.84)])))
        #expect(await model.load(lyon))
        #expect(model.restaurants.map(\.id) == [1])
        #expect(!model.failed && !model.isEmptyArea)
    }

    @Test func errorKeepsOldMarkers() async {
        let repository = FakeRepository(.success([restaurant(1, 45.76, 4.84)]))
        let model = MapViewModel(repository: repository)
        _ = await model.load(lyon)
        repository.result = .failure(Offline())
        #expect(await model.load(lyon) == false)
        #expect(model.failed)
        #expect(model.restaurants.map(\.id) == [1])
    }

    @Test func zoomedOutDoesNotLoad() async {
        let repository = FakeRepository(.success([]))
        let model = MapViewModel(repository: repository)
        let france = MKCoordinateRegion(center: lyon.center, span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8))
        #expect(await model.load(france))
        #expect(model.isTooFar)
        #expect(repository.calls == 0)
    }

    @Test func emptyArea() async {
        let model = MapViewModel(repository: FakeRepository(.success([])))
        _ = await model.load(lyon)
        #expect(model.isEmptyArea)
    }

    @Test func closeRestaurantsShareANest() {
        let clusters = MapViewModel.clusters(
            [restaurant(1, 45.7601, 4.8401), restaurant(2, 45.7602, 4.8402), restaurant(3, 45.79, 4.87)], in: lyon)
        #expect(clusters.map(\.restaurants.count).sorted() == [1, 2])
    }

    @Test func searchFindsRestaurants() async {
        let model = MapViewModel(repository: FakeRepository(.success([restaurant(1, 45.76, 4.84)])), findPlaces: { _ in [] })
        await model.search("poulet")
        #expect(model.foundRestaurants.map(\.id) == [1])
    }

    @Test func searchNeedsTwoLetters() async {
        let repository = FakeRepository(.success([restaurant(1, 45.76, 4.84)]))
        let model = MapViewModel(repository: repository, findPlaces: { _ in [] })
        await model.search(" p ")
        #expect(model.foundRestaurants.isEmpty)
        #expect(repository.calls == 0)
    }

    @Test func offlineSearchFindsNothing() async {
        let model = MapViewModel(repository: FakeRepository(.failure(Offline())), findPlaces: { _ in [] })
        await model.search("poulet")
        #expect(model.foundRestaurants.isEmpty)
    }
}
