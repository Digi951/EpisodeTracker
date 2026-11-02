import XCTest
@testable import EpisodeTracker

final class CatalogEpisodeSearchTests: XCTestCase {
    private let active: Set<String> = ["die drei ???", "tkkg"]

    func testNumberFindsEpisodeInEveryActiveCatalogBeforeTitleMatches() {
        let entries = [
            entry(247, "Geisterbaum", "Die drei ???"),
            entry(12, "Die 247 Stufen", "TKKG"),
            entry(247, "Irgendwas", "TKKG"),
            entry(247, "Inaktiv", "Fünf Freunde")
        ]

        let results = search("247", entries)

        XCTAssertEqual(results.map(\.entry.title), ["Geisterbaum", "Irgendwas", "Die 247 Stufen"])
    }

    func testSingleDigitIsEnoughButSingleLetterIsNot() {
        let entries = [entry(1, "Der Super-Papagei", "Die drei ???")]

        XCTAssertEqual(search("1", entries).count, 1)
        XCTAssertTrue(search("s", entries).isEmpty)
        XCTAssertEqual(search("papagei", entries).count, 1)
    }

    func testEpisodesAlreadyInLibraryAreHidden() {
        let universe = Universe(name: "Die drei ???")
        let owned = Episode(episodeNumber: 1, title: "Der Super-Papagei", releaseYear: 1979, universe: universe)
        let ownedSpecial = Episode(
            episodeNumber: 0,
            title: "Adventskalender",
            releaseYear: 2026,
            kind: .special,
            catalogSlug: "advent-2026",
            universe: universe
        )
        let entries = [
            entry(1, "Der Super-Papagei", "Die drei ???"),
            entry(2, "Der Phantomsee", "Die drei ???"),
            CatalogEntry(number: nil, kind: .special, slug: "advent-2026", title: "Adventskalender", releaseYear: 2026, collectionName: "Die drei ???", links: [:]),
            CatalogEntry(number: nil, kind: .special, slug: "weihnacht-2026", title: "Weihnachtsfolge", releaseYear: 2026, collectionName: "Die drei ???", links: [:])
        ]

        let results = CatalogEpisodeSearch.results(
            for: "e",
            entries: entries,
            activeCollectionNames: active,
            libraryEpisodes: [owned, ownedSpecial]
        )
        XCTAssertTrue(results.isEmpty, "Ein Buchstabe reicht nicht")

        let titles = CatalogEpisodeSearch.results(
            for: "de",
            entries: entries,
            activeCollectionNames: active,
            libraryEpisodes: [owned, ownedSpecial]
        ).map(\.entry.title)
        XCTAssertEqual(titles, ["Der Phantomsee"])

        let specials = CatalogEpisodeSearch.results(
            for: "2026",
            entries: entries,
            activeCollectionNames: active,
            libraryEpisodes: [owned, ownedSpecial]
        )
        XCTAssertTrue(specials.isEmpty, "Jahre sind keine Folgennummern")

        let christmas = CatalogEpisodeSearch.results(
            for: "weihnacht",
            entries: entries,
            activeCollectionNames: active,
            libraryEpisodes: [owned, ownedSpecial]
        )
        XCTAssertEqual(christmas.map(\.entry.slug), ["weihnacht-2026"])
    }

    func testDuplicateCatalogRowsAppearOnce() {
        let entries = [
            entry(5, "Der Doppelgänger", "TKKG"),
            entry(5, "Der Doppelgänger", "TKKG")
        ]

        XCTAssertEqual(search("doppel", entries).count, 1)
    }

    func testEmptyQueryReturnsNothing() {
        XCTAssertTrue(search("   ", [entry(1, "Eins", "TKKG")]).isEmpty)
    }

    private func search(_ query: String, _ entries: [CatalogEntry]) -> [CatalogEpisodeSearch.Result] {
        CatalogEpisodeSearch.results(
            for: query,
            entries: entries,
            activeCollectionNames: active,
            libraryEpisodes: []
        )
    }

    private func entry(_ number: Int, _ title: String, _ collection: String) -> CatalogEntry {
        CatalogEntry(number: number, title: title, releaseYear: 1990, collectionName: collection, links: [:])
    }
}
