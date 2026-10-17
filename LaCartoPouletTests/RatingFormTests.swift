import Foundation
import Testing
@testable import LaCartoPoulet

final class FakeRatingRepository: RatingRepository, @unchecked Sendable {
    var mine: MyRating?
    var failure: Error?
    var saved: [(id: Int?, stars: Int, comment: String?)] = []
    var deleted: [Int] = []

    func ratings(for restaurantID: Int) async throws -> [Rating] { [] }
    func stats(for restaurantID: Int) async throws -> RatingStats? { nil }
    func myRating(for restaurantID: Int) async throws -> MyRating? { mine }
    func save(id: Int?, restaurantID: Int, stars: Int, comment: String?) async throws {
        if let failure { throw failure }
        saved.append((id, stars, comment))
    }
    func delete(id: Int) async throws {
        if let failure { throw failure }
        deleted.append(id)
    }
    func report(ratingID: Int, reason: ReportReason) async throws {}
}

@MainActor struct RatingFormTests {
    @Test func needsDrumsticksBeforePublishing() async {
        let repo = FakeRatingRepository()
        let model = RatingFormModel(restaurantID: 1, repository: repo)
        await model.load()
        #expect(!model.canPublish)
        #expect(model.word == nil)
        #expect(await model.publish() == false)
        model.stars = 4
        #expect(model.word == "Croustillant")
        #expect(model.canPublish)
    }

    @Test func commentLimitIs1000Characters() async {
        let model = RatingFormModel(restaurantID: 1, repository: FakeRatingRepository())
        await model.load()
        model.stars = 3
        model.comment = String(repeating: "x", count: 1000)
        #expect(model.canPublish)
        model.comment += "x"
        #expect(!model.canPublish)
    }

    @Test func newRatingIsAddedWithATrimmedComment() async {
        let repo = FakeRatingRepository()
        let model = RatingFormModel(restaurantID: 1, repository: repo)
        await model.load()
        model.stars = 5
        model.comment = "  \n "
        #expect(await model.publish())
        #expect(repo.saved.count == 1)
        #expect(repo.saved[0].id == nil && repo.saved[0].stars == 5 && repo.saved[0].comment == nil)
    }

    @Test func existingRatingIsPrefilledThenUpdatedOrDeleted() async {
        let repo = FakeRatingRepository()
        repo.mine = MyRating(id: 42, stars: 2, comment: "Bof")
        let model = RatingFormModel(restaurantID: 1, repository: repo)
        await model.load()
        #expect(model.stars == 2 && model.comment == "Bof")
        model.stars = 4
        #expect(await model.publish())
        #expect(repo.saved[0].id == 42 && repo.saved[0].stars == 4)
        #expect(await model.delete())
        #expect(repo.deleted == [42])
    }

    @Test func failureKeepsTheFormFilled() async {
        let repo = FakeRatingRepository()
        let model = RatingFormModel(restaurantID: 1, repository: repo)
        await model.load()
        repo.failure = URLError(.notConnectedToInternet)
        model.stars = 4
        model.comment = "Les tenders"
        #expect(await model.publish() == false)
        #expect(model.stars == 4 && model.comment == "Les tenders")
        #expect(model.error?.hasPrefix("Pas de connexion") == true)
    }
}
