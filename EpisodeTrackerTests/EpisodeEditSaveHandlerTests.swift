// EpisodeTrackerTests/EpisodeEditSaveHandlerTests.swift
import XCTest
import SwiftData
@testable import EpisodeTracker

final class EpisodeEditSaveHandlerTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testSaveInsertsNewEpisode() throws {
        let context = try makeInMemoryContext()
        let universe = Universe(name: "Die drei ???")
        context.insert(universe)

        var draft = EpisodeEditDraft()
        draft.title = "Der Super-Papagei"
        draft.episodeNumberText = "1"
        draft.releaseYearText = "1979"
        draft.selectedUniverse = universe

        let outcome = EpisodeEditSaveHandler.save(
            draft: draft,
            existingEpisode: nil,
            existingEpisodes: [],
            coverChange: .keep,
            in: context
        )

        XCTAssertEqual(outcome, .saved)
        let stored = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.title, "Der Super-Papagei")
        XCTAssertEqual(stored.first?.episodeNumber, 1)
    }

    func testSaveRejectsDuplicateNumberInSameUniverse() throws {
        let context = try makeInMemoryContext()
        let universe = Universe(name: "Die drei ???")
        context.insert(universe)
        let existing = Episode(episodeNumber: 1, title: "Bestand", releaseYear: 1979, universe: universe)
        context.insert(existing)

        var draft = EpisodeEditDraft()
        draft.title = "Neu"
        draft.episodeNumberText = "1"
        draft.releaseYearText = "1980"
        draft.selectedUniverse = universe

        let outcome = EpisodeEditSaveHandler.save(
            draft: draft,
            existingEpisode: nil,
            existingEpisodes: [existing],
            coverChange: .keep,
            in: context
        )

        XCTAssertEqual(outcome, .duplicateNumber)
        let stored = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(stored.count, 1, "Keine neue Folge angelegt")
    }

    func testSaveUpdatesExistingEpisodeAndSetsListenTimestamps() throws {
        let context = try makeInMemoryContext()
        let universe = Universe(name: "TKKG")
        context.insert(universe)
        let episode = Episode(episodeNumber: 5, title: "Alt", releaseYear: 1981, universe: universe)
        context.insert(episode)

        var draft = EpisodeEditDraft(episode: episode, universes: [universe])
        draft.title = "Neu"
        draft.isListened = true

        let outcome = EpisodeEditSaveHandler.save(
            draft: draft,
            existingEpisode: episode,
            existingEpisodes: [episode],
            coverChange: .keep,
            in: context
        )

        XCTAssertEqual(outcome, .saved)
        XCTAssertEqual(episode.title, "Neu")
        XCTAssertTrue(episode.isListened)
        XCTAssertEqual(episode.listenCount, 1)
        XCTAssertNotNil(episode.lastListenedAt)
        XCTAssertNotNil(episode.listenStatusUpdatedAt)
    }

    func testSaveClearsBookmarkWhenMarkedListened() throws {
        let context = try makeInMemoryContext()
        let universe = Universe(name: "TKKG")
        context.insert(universe)
        let episode = Episode(episodeNumber: 5, title: "Alt", releaseYear: 1981, universe: universe)
        episode.isBookmarked = true
        context.insert(episode)

        var draft = EpisodeEditDraft(episode: episode, universes: [universe])
        draft.isListened = true

        _ = EpisodeEditSaveHandler.save(
            draft: draft,
            existingEpisode: episode,
            existingEpisodes: [episode],
            coverChange: .keep,
            in: context
        )

        XCTAssertFalse(episode.isBookmarked)
        XCTAssertNotNil(episode.bookmarkedUpdatedAt)
    }

    func testSaveRejectsDuplicateNumberWhenEditingExistingEpisode() throws {
        let context = try makeInMemoryContext()
        let universe = Universe(name: "Die drei ???")
        context.insert(universe)
        let episode1 = Episode(episodeNumber: 1, title: "A", releaseYear: 1979, universe: universe)
        let episode2 = Episode(episodeNumber: 2, title: "B", releaseYear: 1980, universe: universe)
        context.insert(episode1)
        context.insert(episode2)

        var draft = EpisodeEditDraft(episode: episode1, universes: [universe])
        draft.episodeNumberText = "2"

        let outcome = EpisodeEditSaveHandler.save(
            draft: draft,
            existingEpisode: episode1,
            existingEpisodes: [episode1, episode2],
            coverChange: .keep,
            in: context
        )

        XCTAssertEqual(outcome, .duplicateNumber)
    }

    func testSaveSetsTimestampsWhenNoteRatingAndURLChange() throws {
        let context = try makeInMemoryContext()
        let universe = Universe(name: "TKKG")
        context.insert(universe)
        let episode = Episode(episodeNumber: 5, title: "Alt", releaseYear: 1981, universe: universe)
        context.insert(episode)

        var draft = EpisodeEditDraft(episode: episode, universes: [universe])
        draft.personalNote = "Neue Notiz"
        draft.rating = 5
        draft.streamingURL = "https://open.spotify.com/album/abc"

        let outcome = EpisodeEditSaveHandler.save(
            draft: draft,
            existingEpisode: episode,
            existingEpisodes: [episode],
            coverChange: .keep,
            in: context
        )

        XCTAssertEqual(outcome, .saved)
        XCTAssertNotNil(episode.noteUpdatedAt)
        XCTAssertNotNil(episode.ratingUpdatedAt)
        XCTAssertNotNil(episode.streamingURLUpdatedAt)
    }
}
