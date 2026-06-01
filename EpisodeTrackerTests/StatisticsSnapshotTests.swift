import XCTest
@testable import EpisodeTracker

final class StatisticsSnapshotTests: XCTestCase {
    func testSnapshotCountsEpisodesRatingsAndListens() {
        let universe = Universe(name: "Die drei ???")
        let episodes = [
            makeEpisode(number: 1, universe: universe, isListened: true, rating: 5, listenCount: 3),
            makeEpisode(number: 2, universe: universe, isListened: false, rating: 3, listenCount: 0),
            makeEpisode(number: 3, universe: universe, isListened: false, rating: nil, listenCount: 1)
        ]

        let snapshot = StatisticsSnapshot(episodes: episodes)

        XCTAssertEqual(snapshot.listenedCount, 1)
        XCTAssertEqual(snapshot.unlistenedCount, 2)
        XCTAssertEqual(snapshot.averageRating, 4.0)
        XCTAssertEqual(snapshot.totalListens, 4)
    }

    func testStatisticsExcludeSpecials() {
        let universe = Universe(name: "Die drei ???")
        let regular1 = Episode(episodeNumber: 1, title: "A", releaseYear: 2020, isListened: true, listenCount: 1, universe: universe)
        let regular2 = Episode(episodeNumber: 2, title: "B", releaseYear: 2020, isListened: false, universe: universe)
        let special = Episode(episodeNumber: 0, title: "Special", releaseYear: 2024, kind: .special, catalogSlug: "s-2024", isListened: true, listenCount: 2, universe: universe)

        let snapshot = StatisticsSnapshot(episodes: [regular1, regular2, special])

        XCTAssertEqual(snapshot.listenedCount, 1, "Sonderfolge darf nicht in die Reihen-Hörzahl zählen")
        XCTAssertEqual(snapshot.unlistenedCount, 1)
        XCTAssertEqual(snapshot.totalListens, 3, "Hörzähler bleibt global über alle Folgen")
    }

    func testSnapshotSortsTopRatedByRatingUniverseAndEpisodeNumber() {
        let alpha = Universe(name: "Alpha")
        let beta = Universe(name: "Beta")
        let episodes = [
            makeEpisode(number: 3, universe: beta, rating: 4),
            makeEpisode(number: 2, universe: alpha, rating: 5),
            makeEpisode(number: 1, universe: alpha, rating: 5),
            makeEpisode(number: 1, universe: beta, rating: 5),
            makeEpisode(number: 4, universe: beta, rating: 3),
            makeEpisode(number: 5, universe: beta, rating: 2)
        ]

        let snapshot = StatisticsSnapshot(episodes: episodes)

        XCTAssertEqual(snapshot.topRated.map(\.episodeNumber), [1, 2, 1, 3, 4])
        XCTAssertEqual(snapshot.topRated.map { $0.universe?.name }, ["Alpha", "Alpha", "Beta", "Beta", "Beta"])
    }

    func testSnapshotCountsEachMoodOncePerEpisodeAndUsesCanonicalMood() {
        let preferredMood = Mood(name: "Gruselig", iconName: "ghost", syncKey: "mood:gruselig")
        let duplicateMood = Mood(name: " gruselig ", iconName: nil, syncKey: "legacy-gruselig")
        let otherMood = Mood(name: "Witzig", iconName: "face.smiling")
        let episodes = [
            makeEpisode(number: 1, moods: [duplicateMood, preferredMood]),
            makeEpisode(number: 2, moods: [duplicateMood]),
            makeEpisode(number: 3, moods: [otherMood])
        ]

        let snapshot = StatisticsSnapshot(episodes: episodes)

        XCTAssertEqual(snapshot.moodDistribution.map(\.0.name), ["Gruselig", "Witzig"])
        XCTAssertEqual(snapshot.moodDistribution.map(\.1), [2, 1])
        XCTAssertEqual(snapshot.moodDistribution.first?.0.iconName, "ghost")
    }

    func testOverviewPreferencesDropUnavailableItemsAndAppendMissingItems() {
        let order = StatisticsOverviewPreferences.orderedItems(
            from: "totalListens,missing,listened,totalListens",
            availableKinds: [.episodes, .listened, .totalListens]
        )

        XCTAssertEqual(order, [.totalListens, .listened, .episodes])
    }

    func testSnapshotCountsFavorites() {
        let universe = Universe(name: "Test")
        let ep1 = makeEpisode(number: 1, universe: universe, isListened: true)
        ep1.isFavorite = true
        let ep2 = makeEpisode(number: 2, universe: universe, isListened: false)
        ep2.isFavorite = true
        let ep3 = makeEpisode(number: 3, universe: universe, isListened: false)

        let snapshot = StatisticsSnapshot(episodes: [ep1, ep2, ep3])

        XCTAssertEqual(snapshot.favoriteCount, 2)
    }

    func testSnapshotFavoriteCountIsZeroWhenNone() {
        let universe = Universe(name: "Test")
        let episodes = [
            makeEpisode(number: 1, universe: universe),
            makeEpisode(number: 2, universe: universe)
        ]

        let snapshot = StatisticsSnapshot(episodes: episodes)

        XCTAssertEqual(snapshot.favoriteCount, 0)
    }

    private func makeEpisode(
        number: Int,
        universe: Universe? = nil,
        isListened: Bool = false,
        rating: Int? = nil,
        listenCount: Int = 0,
        moods: [Mood] = []
    ) -> Episode {
        Episode(
            episodeNumber: number,
            title: "Folge \(number)",
            releaseYear: 2020,
            isListened: isListened,
            rating: rating,
            listenCount: listenCount,
            universe: universe,
            moods: moods
        )
    }
}
