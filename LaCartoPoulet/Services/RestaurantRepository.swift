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

protocol RatingRepository: Sendable {
    /// Visible ratings, newest first.
    func ratings(for restaurantID: Int) async throws -> [Rating]
}

struct SupabaseRatingRepository: RatingRepository {
    func ratings(for restaurantID: Int) async throws -> [Rating] {
        try await supabase.from("rating_list")
            .select("id, stars, comment, created_at, nickname")
            .eq("restaurant_id", value: restaurantID)
            .order("created_at", ascending: false)
            .execute().value
    }
}
