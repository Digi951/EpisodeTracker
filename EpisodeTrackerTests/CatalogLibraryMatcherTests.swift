// EpisodeTrackerTests/CatalogLibraryMatcherTests.swift
import XCTest
@testable import EpisodeTracker

final class CatalogLibraryMatcherTests: XCTestCase {
    private func entry(_ number: Int, _ title: String, _ collection: String) -> CatalogEntry {
        CatalogEntry(number: number, title: title, releaseYear: 2020, collectionName: collection)
    }

    func testNormalizationTrimsAndLowercases() {
        XCTAssertEqual(CatalogLibraryMatcher.normalizedCollectionKey("  Die DREI ???  "), "die drei ???")
    }

    func testExistingNumbersGroupedByNormalizedKey() {
        let u = Universe(name: " Die drei ??? ")
        let episodes = [
            Episode(episodeNumber: 1, title: "A", releaseYear: 1979, universe: u),
            Episode(episodeNumber: 2, title: "B", releaseYear: 1979, universe: u),
        ]

        let map = CatalogLibraryMatcher.existingNumbersByCollection(libraryEpisodes: episodes)

        XCTAssertEqual(map["die drei ???"], [1, 2])
    }

    func testMissingEntriesExcludesNumbersAlreadyInLibrary() {
        let u = Universe(name: "Die drei ???")
        let library = [
            Episode(episodeNumber: 1, title: "A", releaseYear: 1979, universe: u),
        ]
        let catalog = [
            entry(1, "A", "Die drei ???"),
            entry(2, "B", "Die drei ???"),
            entry(3, "C", "Die drei ???"),
        ]

        let missing = CatalogLibraryMatcher.missingEntries(catalogEntries: catalog, libraryEpisodes: library)

        XCTAssertEqual(missing.map(\.entry.number), [2, 3])
    }

    func testMatchingToleratesWhitespaceDriftBetweenLibraryAndCatalog() {
        let u = Universe(name: " Die drei ??? ")
        let library = [Episode(episodeNumber: 1, title: "A", releaseYear: 1979, universe: u)]
        let catalog = [entry(1, "A", "Die drei ???"), entry(2, "B", "Die drei ???")]

        let missing = CatalogLibraryMatcher.missingEntries(catalogEntries: catalog, libraryEpisodes: library)

        XCTAssertEqual(missing.map(\.entry.number), [2], "Folge 1 gilt trotz Whitespace als vorhanden")
    }

    func testEmptyLibraryYieldsNoMissingEntries() {
        let catalog = [entry(1, "A", "Die drei ???")]
        let missing = CatalogLibraryMatcher.missingEntries(catalogEntries: catalog, libraryEpisodes: [])
        XCTAssertTrue(missing.isEmpty)
    }
}
