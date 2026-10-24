import MapKit
import Supabase

protocol RestaurantRepository: Sendable {
    func restaurants(in region: MKCoordinateRegion) async throws -> [Restaurant]
    /// Name contains the query, ignoring case and accents; at most 20.
    func search(_ query: String) async throws -> [Restaurant]
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

    func search(_ query: String) async throws -> [Restaurant] {
        try await supabase.rpc("search_restaurants", params: ["q": query]).execute().value
    }
}

protocol RatingRepository: Sendable {
    /// Visible ratings, newest first.
    func ratings(for restaurantID: Int) async throws -> [Rating]
    /// Nil when nobody rated it yet.
    func stats(for restaurantID: Int) async throws -> RatingStats?
    /// The signed-in user's rating here, nil if they haven't rated it.
    func myRating(for restaurantID: Int) async throws -> MyRating?
    /// Adds my rating, or updates it when `id` is given.
    func save(id: Int?, restaurantID: Int, stars: Int, comment: String?) async throws
    func delete(id: Int) async throws
    /// Reporting twice counts as done.
    func report(ratingID: Int, reason: ReportReason) async throws
}

struct SupabaseRatingRepository: RatingRepository {
    func ratings(for restaurantID: Int) async throws -> [Rating] {
        try await supabase.from("rating_list")
            .select("id, stars, comment, created_at, nickname, user_id, is_mine")
            .eq("restaurant_id", value: restaurantID)
            .order("created_at", ascending: false)
            .execute().value
    }

    func stats(for restaurantID: Int) async throws -> RatingStats? {
        let rows: [RatingStats] = try await supabase.from("restaurant_stats")
            .select("avg_stars, rating_count")
            .eq("restaurant_id", value: restaurantID)
            .execute().value
        return rows.first
    }

    func myRating(for restaurantID: Int) async throws -> MyRating? {
        let userID = try await supabase.auth.session.user.id
        let mine: [MyRating] = try await supabase.from("ratings")
            .select("id, stars, comment, hidden")
            .eq("restaurant_id", value: restaurantID)
            .eq("user_id", value: userID)
            .execute().value
        return mine.first
    }

    func save(id: Int?, restaurantID: Int, stars: Int, comment: String?) async throws {
        // AnyJSON so a removed comment is sent as null instead of being left out.
        var fields: [String: AnyJSON] = ["stars": .integer(stars), "comment": comment.map(AnyJSON.string) ?? .null]
        if let id {
            try await supabase.from("ratings").update(fields).eq("id", value: id).execute()
        } else {
            fields["restaurant_id"] = .integer(restaurantID)
            fields["user_id"] = .string(try await supabase.auth.session.user.id.uuidString)
            try await supabase.from("ratings").insert(fields).execute()
        }
    }

    func delete(id: Int) async throws {
        try await supabase.from("ratings").delete().eq("id", value: id).execute()
    }

    func report(ratingID: Int, reason: ReportReason) async throws {
        do {
            let userID = try await supabase.auth.session.user.id
            try await supabase.from("reports")
                .insert(["rating_id": AnyJSON.integer(ratingID), "reporter_id": .string(userID.uuidString),
                         "reason": .string(reason.rawValue)])
                .execute()
        } catch let error as PostgrestError where error.code == "23505" {}
    }
}
