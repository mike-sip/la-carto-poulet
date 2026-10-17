import Foundation

/// A visible rating with its author's nickname (`rating_list` view; hidden ratings never come back).
struct Rating: Decodable, Identifiable, Equatable {
    let id: Int
    let stars: Int
    let comment: String?
    let createdAt: Date
    let nickname: String

    enum CodingKeys: String, CodingKey {
        case id, stars, comment, nickname
        case createdAt = "created_at"
    }
}

/// The signed-in user's own rating for one restaurant, to prefill the form.
struct MyRating: Decodable, Equatable {
    let id: Int
    let stars: Int
    let comment: String?
}
