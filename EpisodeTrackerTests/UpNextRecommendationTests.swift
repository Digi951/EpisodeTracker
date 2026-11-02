import XCTest
@testable import EpisodeTracker

final class UpNextRecommendationTests: XCTestCase {

    func testContinuationComesFirst() {
        let universe = Universe(name: "Die drei ???")
        let first = Episode(episodeNumber: 1, title: "Eins", releaseYear: 1979, universe: universe)
        first.isListened = true
        first.lastListenedAt = .now
        let second = Episode(episodeNumber: 2, title: "Zwei", releaseYear: 1979, universe: universe)
        let bookmarked = Episode(episodeNumber: 9, title: "Gemerkt", releaseYear: 1980, isBookmarked: true, universe: universe)

        let candidates = UpNextRecommendation.candidates(from: [first, second, bookmarked])

        XCTAssertEqual(candidates.first?.episode.title, "Zwei")
        XCTAssertEqual(candidates.first?.reason, .continueSeries)
    }

    func testBookmarkedBeforePlainOpenEpisodes() {
        let universe = Universe(name: "TKKG")
        let open = Episode(episodeNumber: 1, title: "Offen", releaseYear: 1981, universe: universe)
        let bookmarked = Episode(episodeNumber: 5, title: "Gemerkt", releaseYear: 1982, isBookmarked: true, universe: universe)

        let candidates = UpNextRecommendation.candidates(from: [open, bookmarked])

        XCTAssertEqual(candidates.map(\.episode.title), ["Gemerkt", "Offen"])
        XCTAssertEqual(candidates.map(\.reason), [.bookmarked, .open])
    }

    /// Eine Folge, die mehrere Regeln erfüllt, erscheint nur einmal — sonst
    /// zeigt „Anderer Vorschlag“ dieselbe Folge erneut.
    func testEpisodeAppearsOnlyOnce() {
        let universe = Universe(name: "Die drei ???")
        let first = Episode(episodeNumber: 1, title: "Eins", releaseYear: 1979, universe: universe)
        first.isListened = true
        let next = Episode(episodeNumber: 2, title: "Zwei", releaseYear: 1979, isBookmarked: true, universe: universe)

        let candidates = UpNextRecommendation.candidates(from: [first, next])

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.reason, .continueSeries)
    }

    func testListenedAndHiddenEpisodesAreNeverRecommended() {
        let universe = Universe(name: "TKKG")
        let listened = Episode(episodeNumber: 1, title: "Gehört", releaseYear: 1981, universe: universe)
        listened.isListened = true
        let hidden = Episode(episodeNumber: 2, title: "Ausgeblendet", releaseYear: 1981, universe: universe)
        hidden.isHidden = true

        XCTAssertTrue(UpNextRecommendation.candidates(from: [listened, hidden]).isEmpty)
    }

    /// Ohne `lastListenedAt` entschied bisher die Dictionary-Reihenfolge —
    /// die Empfehlung wechselte zwischen zwei Aufrufen.
    func testContinuationOrderIsStableWithoutListenDates() {
        let tkkg = Universe(name: "TKKG")
        let dreiFragezeichen = Universe(name: "Die drei ???")
        let a1 = Episode(episodeNumber: 1, title: "A1", releaseYear: 1979, universe: dreiFragezeichen)
        a1.isListened = true
        let a2 = Episode(episodeNumber: 2, title: "A2", releaseYear: 1979, universe: dreiFragezeichen)
        let b1 = Episode(episodeNumber: 1, title: "B1", releaseYear: 1981, universe: tkkg)
        b1.isListened = true
        let b2 = Episode(episodeNumber: 2, title: "B2", releaseYear: 1981, universe: tkkg)

        for _ in 0..<20 {
            let titles = UpNextRecommendation.candidates(from: [b2, a1, b1, a2]).map(\.episode.title)
            XCTAssertEqual(titles, ["A2", "B2"])
        }
    }
}
