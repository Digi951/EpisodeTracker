// EpisodeTrackerTests/EpisodeEditDraftTests.swift
import XCTest
@testable import EpisodeTracker

final class EpisodeEditDraftTests: XCTestCase {
    func testParsesNumberAndYearIgnoringWhitespace() {
        var draft = EpisodeEditDraft()
        draft.episodeNumberText = " 42 "
        draft.releaseYearText = "1979"

        XCTAssertEqual(draft.parsedEpisodeNumber, 42)
        XCTAssertEqual(draft.parsedReleaseYear, 1979)
    }

    func testParsedValuesAreNilForNonNumericInput() {
        var draft = EpisodeEditDraft()
        draft.episodeNumberText = "abc"
        draft.releaseYearText = ""

        XCTAssertNil(draft.parsedEpisodeNumber)
        XCTAssertNil(draft.parsedReleaseYear)
    }

    func testIsCompleteRequiresTitleNumberYearAndUniverse() {
        let universe = Universe(name: "Die drei ???")
        var draft = EpisodeEditDraft()
        XCTAssertFalse(draft.isComplete)

        draft.title = "Der Super-Papagei"
        draft.episodeNumberText = "1"
        draft.releaseYearText = "1979"
        XCTAssertFalse(draft.isComplete, "Universe fehlt noch")

        draft.selectedUniverse = universe
        XCTAssertTrue(draft.isComplete)
    }

    func testSpecialDraftIsCompleteWithoutNumber() {
        let universe = Universe(name: "Die drei ???")
        var draft = EpisodeEditDraft()
        draft.isSpecial = true
        draft.title = "Phantomsee"
        draft.releaseYearText = "2024"
        draft.selectedUniverse = universe
        draft.episodeNumberText = ""
        XCTAssertTrue(draft.isComplete)
    }

    func testRegularDraftStillNeedsNumber() {
        let universe = Universe(name: "Die drei ???")
        var draft = EpisodeEditDraft()
        draft.title = "Angreifer"
        draft.releaseYearText = "2024"
        draft.selectedUniverse = universe
        draft.episodeNumberText = ""
        XCTAssertFalse(draft.isComplete)
    }

    func testInitFromEpisodeCopiesAllFields() {
        let universe = Universe(name: "TKKG")
        let mood = Mood(name: "spannend")
        let episode = Episode(
            episodeNumber: 7,
            title: "Die Bettelmönche",
            releaseYear: 1981,
            personalNote: "Klassiker",
            isListened: true,
            rating: 4,
            universe: universe,
            moods: [mood]
        )
        episode.streamingURL = "https://example.com"
        episode.isHidden = true

        let draft = EpisodeEditDraft(episode: episode, universes: [universe])

        XCTAssertEqual(draft.title, "Die Bettelmönche")
        XCTAssertEqual(draft.episodeNumberText, "7")
        XCTAssertEqual(draft.releaseYearText, "1981")
        XCTAssertEqual(draft.personalNote, "Klassiker")
        XCTAssertTrue(draft.isListened)
        XCTAssertEqual(draft.rating, 4)
        XCTAssertEqual(draft.streamingURL, "https://example.com")
        XCTAssertTrue(draft.isHidden)
        XCTAssertEqual(draft.selectedMoods, [mood])
        XCTAssertEqual(draft.selectedUniverse, universe)
    }
}
