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

    // MARK: - Lange nicht gehoert (Long Pause)

    func testLongPauseFindsUniversesPausedOverThreshold() {
        let u1 = makeUniverse("Paused")
        let u2 = makeUniverse("Active")
        let referenceDate = Date()
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true, lastListenedAt: date(60)),
            makeEpisode(number: 2, universe: u1),
            makeEpisode(number: 1, universe: u2, isListened: true, lastListenedAt: date(5)),
            makeEpisode(number: 2, universe: u2),
        ]

        let result = SmartListDefinition.longPauseEpisodes(from: episodes, referenceDate: referenceDate)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].universe?.name, "Paused")
        XCTAssertEqual(result[0].episodeNumber, 2)
    }

    func testLongPauseSortsByLongestPauseFirst() {
        let u1 = makeUniverse("Short Pause")
        let u2 = makeUniverse("Long Pause")
        let referenceDate = Date()
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true, lastListenedAt: date(35)),
            makeEpisode(number: 2, universe: u1),
            makeEpisode(number: 1, universe: u2, isListened: true, lastListenedAt: date(90)),
            makeEpisode(number: 2, universe: u2),
        ]

        let result = SmartListDefinition.longPauseEpisodes(from: episodes, referenceDate: referenceDate)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].universe?.name, "Long Pause")
        XCTAssertEqual(result[1].universe?.name, "Short Pause")
    }

    func testLongPauseExcludesFullyListenedUniverses() {
        let u1 = makeUniverse("Done")
        let referenceDate = Date()
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true, lastListenedAt: date(60)),
            makeEpisode(number: 2, universe: u1, isListened: true, lastListenedAt: date(60)),
        ]

        let result = SmartListDefinition.longPauseEpisodes(from: episodes, referenceDate: referenceDate)

        XCTAssertTrue(result.isEmpty)
    }

    func testLongPauseUsesThresholdBoundary() {
        let u1 = makeUniverse("Exactly30")
        let referenceDate = Date()
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true, lastListenedAt: date(30)),
            makeEpisode(number: 2, universe: u1),
        ]

        let result = SmartListDefinition.longPauseEpisodes(from: episodes, referenceDate: referenceDate)

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Top bewertet (Top Rated)

    func testTopRatedReturnsOnlyUnlistenedWithRating() {
        let u1 = makeUniverse("Test")
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: false, rating: 5),
            makeEpisode(number: 2, universe: u1, isListened: true, rating: 5),
            makeEpisode(number: 3, universe: u1, isListened: false),
            makeEpisode(number: 4, universe: u1, isListened: false, rating: 3),
        ]

        let result = SmartListDefinition.topRatedEpisodes(from: episodes)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].episodeNumber, 1)
        XCTAssertEqual(result[1].episodeNumber, 4)
    }

    func testTopRatedSortsByRatingDescendingThenNumberAscending() {
        let u1 = makeUniverse("Test")
        let episodes = [
            makeEpisode(number: 10, universe: u1, isListened: false, rating: 4),
            makeEpisode(number: 5, universe: u1, isListened: false, rating: 4),
            makeEpisode(number: 1, universe: u1, isListened: false, rating: 5),
        ]

        let result = SmartListDefinition.topRatedEpisodes(from: episodes)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].episodeNumber, 1)
        XCTAssertEqual(result[1].episodeNumber, 5)
        XCTAssertEqual(result[2].episodeNumber, 10)
    }

    func testTopRatedReturnsEmptyWhenNoRatedUnlistened() {
        let u1 = makeUniverse("Test")
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true, rating: 5),
            makeEpisode(number: 2, universe: u1, isListened: false),
        ]

        let result = SmartListDefinition.topRatedEpisodes(from: episodes)

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Zufaellig (Random)

    func testRandomReturnsOnlyUnlistenedEpisodes() {
        let u1 = makeUniverse("Test")
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true),
            makeEpisode(number: 2, universe: u1),
            makeEpisode(number: 3, universe: u1),
            makeEpisode(number: 4, universe: u1, isListened: true),
            makeEpisode(number: 5, universe: u1),
        ]

        let result = SmartListDefinition.randomEpisodes(from: episodes)

        XCTAssertEqual(result.count, 3)
        for episode in result {
            XCTAssertFalse(episode.isListened)
        }
    }

    func testRandomRespectsCountLimit() {
        let u1 = makeUniverse("Test")
        var episodes: [Episode] = []
        for i in 1...20 {
            episodes.append(makeEpisode(number: i, universe: u1))
        }

        let result = SmartListDefinition.randomEpisodes(from: episodes, count: 5)

        XCTAssertEqual(result.count, 5)
    }

    func testRandomReturnsAllWhenFewerThanCount() {
        let u1 = makeUniverse("Test")
        let episodes = [
            makeEpisode(number: 1, universe: u1),
            makeEpisode(number: 2, universe: u1),
        ]

        let result = SmartListDefinition.randomEpisodes(from: episodes, count: 10)

        XCTAssertEqual(result.count, 2)
    }

    func testRandomReturnsEmptyWhenAllListened() {
        let u1 = makeUniverse("Test")
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true),
            makeEpisode(number: 2, universe: u1, isListened: true),
        ]

        let result = SmartListDefinition.randomEpisodes(from: episodes)

        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Zufaellig nach Stimmung (Random by Mood)

    func testEpisodesForMoodReturnsOnlyMatchingUnlistened() {
        let mood1 = Mood(name: "Gruselig", iconName: "😱")
        let mood2 = Mood(name: "Witzig", iconName: "😄")
        let u1 = makeUniverse("Test")
        let episodes = [
            makeEpisode(number: 1, universe: u1, moods: [mood1]),
            makeEpisode(number: 2, universe: u1, isListened: true, moods: [mood1]),
            makeEpisode(number: 3, universe: u1, moods: [mood2]),
            makeEpisode(number: 4, universe: u1, moods: [mood1, mood2]),
            makeEpisode(number: 5, universe: u1),
        ]

        let result = SmartListDefinition.episodesForMood(mood1, from: episodes)

        XCTAssertEqual(result.count, 2)
        for episode in result {
            XCTAssertFalse(episode.isListened)
            XCTAssertTrue(episode.moods.contains(where: { $0 === mood1 }))
        }
    }

    func testEpisodesForMoodRespectsCountLimit() {
        let mood = Mood(name: "Test", iconName: "🧪")
        let u1 = makeUniverse("Test")
        var episodes: [Episode] = []
        for i in 1...20 {
            episodes.append(makeEpisode(number: i, universe: u1, moods: [mood]))
        }

        let result = SmartListDefinition.episodesForMood(mood, from: episodes, count: 5)

        XCTAssertEqual(result.count, 5)
    }

    // MARK: - Available Moods

    func testAvailableMoodsReturnsOnlyMoodsWithUnlistenedEpisodes() {
        let mood1 = Mood(name: "Gruselig", iconName: "😱")
        let mood2 = Mood(name: "Witzig", iconName: "😄")
        let mood3 = Mood(name: "Leer", iconName: "🫥")
        let u1 = makeUniverse("Test")
        let episodes = [
            makeEpisode(number: 1, universe: u1, moods: [mood1]),
            makeEpisode(number: 2, universe: u1, moods: [mood1]),
            makeEpisode(number: 3, universe: u1, moods: [mood2]),
            makeEpisode(number: 4, universe: u1, isListened: true, moods: [mood3]),
        ]

        let result = SmartListDefinition.availableMoods(from: episodes, allMoods: [mood1, mood2, mood3])

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].mood.name, "Gruselig")
        XCTAssertEqual(result[0].count, 2)
        XCTAssertEqual(result[1].mood.name, "Witzig")
        XCTAssertEqual(result[1].count, 1)
    }

    func testAvailableMoodsReturnsEmptyWhenNoUnlistenedWithMoods() {
        let mood1 = Mood(name: "Test", iconName: "🧪")
        let u1 = makeUniverse("Test")
        let episodes = [
            makeEpisode(number: 1, universe: u1, isListened: true, moods: [mood1]),
            makeEpisode(number: 2, universe: u1),
        ]

        let result = SmartListDefinition.availableMoods(from: episodes, allMoods: [mood1])

        XCTAssertTrue(result.isEmpty)
    }
}
