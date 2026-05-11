import XCTest
@testable import EpisodeTracker

final class SmartListTests: XCTestCase {

    // MARK: - Helpers

    private func makeUniverse(_ name: String) -> Universe {
        Universe(name: name)
    }

    private func makeEpisode(
        number: Int,
        title: String = "Folge",
        universe: Universe? = nil,
        isListened: Bool = false,
        rating: Int? = nil,
        listenCount: Int? = nil,
        lastListenedAt: Date? = nil,
        moods: [Mood] = []
    ) -> Episode {
        Episode(
            episodeNumber: number,
            title: title,
            releaseYear: 2020,
            isListened: isListened,
            rating: rating,
            listenCount: listenCount ?? (isListened ? 1 : 0),
            lastListenedAt: lastListenedAt,
            universe: universe,
            moods: moods
        )
    }

    private func date(_ daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    }

    // MARK: - Fortsetzen (Continue)

    func testContinuationReturnsNextEpisodePerUniverse() {
        let u1 = makeUniverse("Die drei ???")
        let u2 = makeUniverse("TKKG")
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true, lastListenedAt: date(1)),
            makeEpisode(number: 2, universe: u1, isListened: true, lastListenedAt: date(1)),
            makeEpisode(number: 3, universe: u1),
            makeEpisode(number: 4, universe: u1),
            makeEpisode(number: 1, universe: u2, isListened: true, lastListenedAt: date(5)),
            makeEpisode(number: 2, universe: u2),
        ]

        let result = SmartListDefinition.continuationEpisodes(from: episodes)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].episodeNumber, 3)
        XCTAssertEqual(result[0].universe?.name, "Die drei ???")
        XCTAssertEqual(result[1].episodeNumber, 2)
        XCTAssertEqual(result[1].universe?.name, "TKKG")
    }

    func testContinuationSkipsUniverseWithNoListenedEpisodes() {
        let u1 = makeUniverse("Test")
        let episodes = [
            makeEpisode(number: 1, universe: u1),
            makeEpisode(number: 2, universe: u1),
        ]

        let result = SmartListDefinition.continuationEpisodes(from: episodes)

        XCTAssertTrue(result.isEmpty)
    }

    func testContinuationSkipsUniverseFullyListened() {
        let u1 = makeUniverse("Test")
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true, lastListenedAt: date(1)),
            makeEpisode(number: 2, universe: u1, isListened: true, lastListenedAt: date(1)),
        ]

        let result = SmartListDefinition.continuationEpisodes(from: episodes)

        XCTAssertTrue(result.isEmpty)
    }

    func testContinuationHandlesGapsInEpisodeNumbers() {
        let u1 = makeUniverse("Test")
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true, lastListenedAt: date(1)),
            makeEpisode(number: 2, universe: u1, isListened: true, lastListenedAt: date(1)),
            makeEpisode(number: 5, universe: u1),
            makeEpisode(number: 10, universe: u1),
        ]

        let result = SmartListDefinition.continuationEpisodes(from: episodes)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].episodeNumber, 5)
    }

    func testContinuationSortsByMostRecentActivity() {
        let u1 = makeUniverse("Old")
        let u2 = makeUniverse("Recent")
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true, lastListenedAt: date(30)),
            makeEpisode(number: 2, universe: u1),
            makeEpisode(number: 1, universe: u2, isListened: true, lastListenedAt: date(1)),
            makeEpisode(number: 2, universe: u2),
        ]

        let result = SmartListDefinition.continuationEpisodes(from: episodes)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].universe?.name, "Recent")
        XCTAssertEqual(result[1].universe?.name, "Old")
    }

    // MARK: - Uebersprungen (Skipped)

    func testSkippedFindsGapsBelowMaxListened() {
        let u1 = makeUniverse("Die drei ???")
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true),
            makeEpisode(number: 2, universe: u1),            // skipped
            makeEpisode(number: 3, universe: u1),            // skipped
            makeEpisode(number: 4, universe: u1, isListened: true),
            makeEpisode(number: 5, universe: u1),            // NOT skipped (above max)
        ]

        let result = SmartListDefinition.skippedEpisodes(from: episodes)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].episodeNumber, 2)
        XCTAssertEqual(result[1].episodeNumber, 3)
    }

    func testSkippedAcrossMultipleUniversesSortedByNameThenNumber() {
        let tkkg = makeUniverse("TKKG")
        let ddf = makeUniverse("Die drei ???")
        let episodes = [
            makeEpisode(number: 1, universe: ddf, isListened: true),
            makeEpisode(number: 2, universe: ddf),            // skipped
            makeEpisode(number: 3, universe: ddf, isListened: true),
            makeEpisode(number: 1, universe: tkkg, isListened: true),
            makeEpisode(number: 2, universe: tkkg),           // skipped
            makeEpisode(number: 3, universe: tkkg, isListened: true),
        ]

        let result = SmartListDefinition.skippedEpisodes(from: episodes)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].universe?.name, "Die drei ???")
        XCTAssertEqual(result[0].episodeNumber, 2)
        XCTAssertEqual(result[1].universe?.name, "TKKG")
        XCTAssertEqual(result[1].episodeNumber, 2)
    }

    func testSkippedReturnsEmptyWhenNoGaps() {
        let u1 = makeUniverse("Test")
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true),
            makeEpisode(number: 2, universe: u1, isListened: true),
            makeEpisode(number: 3, universe: u1),
        ]

        let result = SmartListDefinition.skippedEpisodes(from: episodes)

        XCTAssertTrue(result.isEmpty)
    }
}
