import Foundation

/// A visible rating with its author's nickname (`rating_list` view; hidden ratings never come back).
struct Rating: Decodable, Identifiable, Equatable {
    let id: Int
    let stars: Int
    let comment: String?
    let createdAt: Date
    let nickname: String
    let userID: UUID
    /// Written by the signed-in user: no "Signaler" or "Bloquer" on it.
    let isMine: Bool

    enum CodingKeys: String, CodingKey {
        case id, stars, comment, nickname
        case createdAt = "created_at"
        case userID = "user_id"
        case isMine = "is_mine"
    }
}

/// The signed-in user's own rating for one restaurant, to prefill the form.
struct MyRating: Decodable, Equatable {
    let id: Int
    let stars: Int
    let comment: String?
    /// Hidden after 3 reports: only its author still sees it, in the form.
    var hidden = false
}

enum ReportReason: String, CaseIterable, Identifiable {
    case insult, spam, offTopic = "off_topic", other
    var id: Self { self }
    var label: String {
        switch self {
        case .insult: "Insultant"
        case .spam: "Spam"
        case .offTopic: "Hors sujet"
        case .other: "Autre"
        }
    }
}
