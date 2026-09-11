import XCTest
import SwiftData
@testable import EpisodeTracker

@MainActor
final class NewsBookmarkHandlerTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func makeEvent(episodeNumber: Int? = 241, slug: String? = nil, universeName: String = "Die drei ???") -> NewsEvent {
        NewsEvent(
            kind: .newEpisode,
            universeName: universeName,
            catalogID: "die-drei-fragezeichen",
            episodeNumber: episodeNumber,
            slug: slug,
            title: "Meister des Lichts",
            revision: "5",
            discoveredAt: Date(timeIntervalSince1970: 1_789_000_000)
        )
    }

    // MARK: Neu anlegen

    func testTogglingAnEventWithoutALibraryMatchCreatesABookmarkedEpisode() throws {
        let context = try makeContext()
        let event = makeEvent()

        let episode = NewsBookmarkHandler.toggleBookmark(
            for: event,
            modelContext: context,
            existingEpisodes: [],
            existingUniverses: []
        )

        XCTAssertTrue(episode.isBookmarked)
        XCTAssertFalse(episode.isListened)
        XCTAssertEqual(episode.episodeNumber, 241)
        XCTAssertEqual(episode.universe?.name, "Die drei ???")
    }

    func testCreatingAnEpisodeBindsToAnExistingUniverseInsteadOfMakingADuplicate() throws {
        let context = try makeContext()
        let existingUniverse = Universe(name: "Die drei ???")
        context.insert(existingUniverse)

        let episode = NewsBookmarkHandler.toggleBookmark(
            for: makeEvent(),
            modelContext: context,
            existingEpisodes: [],
            existingUniverses: [existingUniverse]
        )

        XCTAssertTrue(episode.universe === existingUniverse)
        let allUniverses = try context.fetch(FetchDescriptor<Universe>())
        XCTAssertEqual(allUniverses.count, 1, "must not create a second Universe for the same collection")
    }

    // MARK: Existierende Folge

    func testTogglingAnEventWithAnExistingLibraryMatchSetsTheFlagWithoutCreatingAnything() throws {
        let context = try makeContext()
        let universe = Universe(name: "Die drei ???")
        context.insert(universe)
        let existingEpisode = Episode(episodeNumber: 241, title: "Meister des Lichts", releaseYear: 2026, universe: universe)
        context.insert(existingEpisode)

        let result = NewsBookmarkHandler.toggleBookmark(
            for: makeEvent(),
            modelContext: context,
            existingEpisodes: [existingEpisode],
            existingUniverses: [universe]
        )

        XCTAssertTrue(result === existingEpisode)
        XCTAssertTrue(result.isBookmarked)
        let allEpisodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(allEpisodes.count, 1, "must not insert a second episode")
    }

    func testUnbookmarkingAPreExistingEpisodeOnlyClearsTheFlagAndLeavesPersonalDataUntouched() throws {
        let context = try makeContext()
        let universe = Universe(name: "Die drei ???")
        context.insert(universe)
        let existingEpisode = Episode(
            episodeNumber: 241,
            title: "Meister des Lichts",
            releaseYear: 2026,
            personalNote: "Tolle Folge!",
            isListened: true,
            rating: 5,
            isBookmarked: true,
            universe: universe
        )
        context.insert(existingEpisode)

        let result = NewsBookmarkHandler.toggleBookmark(
            for: makeEvent(),
            modelContext: context,
            existingEpisodes: [existingEpisode],
            existingUniverses: [universe]
        )

        XCTAssertFalse(result.isBookmarked)
        XCTAssertTrue(result.isListened, "un-bookmarking must not touch listen status")
        XCTAssertEqual(result.rating, 5, "un-bookmarking must not touch the rating")
        XCTAssertEqual(result.personalNote, "Tolle Folge!", "un-bookmarking must not touch the note")
        let allEpisodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(allEpisodes.count, 1, "un-bookmarking a pre-existing episode must never delete it")
    }

    // MARK: Wiederholtes Tippen / eigens angelegte Folge

    func testRepeatedTapsNeverCreateMoreThanOneEpisode() throws {
        let context = try makeContext()
        var episodes: [Episode] = []
        var universes: [Universe] = []

        for _ in 0..<3 {
            let episode = NewsBookmarkHandler.toggleBookmark(
                for: makeEvent(),
                modelContext: context,
                existingEpisodes: episodes,
                existingUniverses: universes
            )
            if !episodes.contains(where: { $0 === episode }) {
                episodes.append(episode)
            }
            if let universe = episode.universe, !universes.contains(where: { $0 === universe }) {
                universes.append(universe)
            }
        }

        XCTAssertEqual(episodes.count, 1)
        // Erster Tap: gemerkt. Zweiter: entmerkt. Dritter: wieder gemerkt.
        XCTAssertTrue(episodes[0].isBookmarked)
    }

    func testUnbookmarkingASelfCreatedEpisodeOnlyClearsTheFlagAndNeverDeletesIt() throws {
        let context = try makeContext()
        let event = makeEvent()

        let created = NewsBookmarkHandler.toggleBookmark(
            for: event,
            modelContext: context,
            existingEpisodes: [],
            existingUniverses: []
        )
        XCTAssertTrue(created.isBookmarked)

        let toggledAgain = NewsBookmarkHandler.toggleBookmark(
            for: event,
            modelContext: context,
            existingEpisodes: [created],
            existingUniverses: [created.universe].compactMap { $0 }
        )

        XCTAssertTrue(toggledAgain === created)
        XCTAssertFalse(toggledAgain.isBookmarked)
        let allEpisodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(allEpisodes.count, 1, "un-bookmarking a self-created episode must never delete it")
    }

    // MARK: Sonderfolge über Slug

    func testSpecialEpisodeWithoutANumberMatchesBySlug() throws {
        let context = try makeContext()
        let universe = Universe(name: "Die drei ???")
        context.insert(universe)
        let existingSpecial = Episode(episodeNumber: 0, title: "Jubiläumsfolge", releaseYear: 2026, kind: .special, catalogSlug: "jubilaeum", universe: universe)
        context.insert(existingSpecial)

        let event = makeEvent(episodeNumber: nil, slug: "jubilaeum")
        let result = NewsBookmarkHandler.toggleBookmark(
            for: event,
            modelContext: context,
            existingEpisodes: [existingSpecial],
            existingUniverses: [universe]
        )

        XCTAssertTrue(result === existingSpecial)
    }
}
