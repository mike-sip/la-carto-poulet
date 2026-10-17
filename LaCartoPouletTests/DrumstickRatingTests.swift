import Testing
@testable import LaCartoPoulet

struct DrumstickRatingTests {
    @Test(arguments: [(4.3, 4.5), (4.2, 4.0), (4.25, 4.5), (1.0, 1.0), (4.8, 5.0)])
    func roundsToTheNearestHalf(value: Double, expected: Double) {
        #expect(DrumstickRating.rounded(value) == expected)
    }

    @Test func showsACommaDecimal() {
        #expect(DrumstickRating.formatted(4.3) == "4,3")
        #expect(DrumstickRating.formatted(4) == "4,0")
    }
}
