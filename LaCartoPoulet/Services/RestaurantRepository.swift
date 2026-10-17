import MapKit
import Supabase

protocol RestaurantRepository: Sendable {
    func restaurants(in region: MKCoordinateRegion) async throws -> [Restaurant]
}

struct SupabaseRestaurantRepository: RestaurantRepository {
    func restaurants(in region: MKCoordinateRegion) async throws -> [Restaurant] {
        let center = region.center, span = region.span
        return try await supabase.rpc("restaurants_in_bbox", params: [
            "min_lat": center.latitude - span.latitudeDelta / 2,
            "max_lat": center.latitude + span.latitudeDelta / 2,
            "min_lng": center.longitude - span.longitudeDelta / 2,
            "max_lng": center.longitude + span.longitudeDelta / 2,
        ]).execute().value
    }
}
