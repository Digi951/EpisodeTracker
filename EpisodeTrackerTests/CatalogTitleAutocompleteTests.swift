import XCTest
@testable import EpisodeTracker

final class CatalogTitleAutocompleteTests: XCTestCase {
    func testSuggestionsStartAfterTwoCharactersAndMatchTitleSubstring() {
        let entries = [
            entry(1, "Der Super-Papagei", "Die drei ???"),
            entry(2, "Die singende Schlange", "Die drei ???")
        ]

        XCTAssertTrue(
            CatalogTitleAutocomplete.suggestions(
                for: "s",
                entries: entries,
                activeCollectionNames: ["die drei ???"],
                selectedCollectionName: "Die drei ???",
                existingEpisodeNumbersByCollection: [:]
            ).isEmpty
        )

        let suggestions = CatalogTitleAutocomplete.suggestions(
            for: "super",
            entries: entries,
            activeCollectionNames: ["die drei ???"],
            selectedCollectionName: "Die drei ???",
            existingEpisodeNumbersByCollection: [:]
        )

        XCTAssertEqual(suggestions.map(\.number), [1])
    }

    func testSuggestionsSearchAcrossActiveCatalogsWhenNoCatalogIsSelected() {
        let entries = [
            entry(1, "Der Schatz", "Die drei ???"),
            entry(1, "Der Schatz", "TKKG"),
            entry(1, "Der Schatz", "Inaktiv")
        ]

        let suggestions = CatalogTitleAutocomplete.suggestions(
            for: "schatz",
            entries: entries,
            activeCollectionNames: ["die drei ???", "tkkg"],
            selectedCollectionName: nil,
            existingEpisodeNumbersByCollection: [:]
        )

        XCTAssertEqual(suggestions.map { $0.collectionName }, ["Die drei ???", "TKKG"])
    }

    func testSuggestionsStayInsideSelectedActiveCatalog() {
        let entries = [
            entry(1, "Der Schatz", "Die drei ???"),
            entry(1, "Der Schatz", "TKKG")
        ]

        let suggestions = CatalogTitleAutocomplete.suggestions(
            for: "schatz",
            entries: entries,
            activeCollectionNames: ["die drei ???", "tkkg"],
            selectedCollectionName: "TKKG",
            existingEpisodeNumbersByCollection: [:]
        )

        XCTAssertEqual(suggestions.map { $0.collectionName }, ["TKKG"])
    }

    func testSuggestionsExcludeExistingLibraryEpisodesAndCapAtTen() {
        let entries = (1...12).map {
            entry($0, "Der Fall \($0)", "Die drei ???")
        }

        let suggestions = CatalogTitleAutocomplete.suggestions(
            for: "fall",
            entries: entries,
            activeCollectionNames: ["die drei ???"],
            selectedCollectionName: "Die drei ???",
            existingEpisodeNumbersByCollection: ["die drei ???": [1, 2]]
        )

        XCTAssertEqual(suggestions.count, 10)
        XCTAssertEqual(suggestions.first?.number, 3)
        XCTAssertEqual(suggestions.last?.number, 12)
    }

    private func entry(_ number: Int, _ title: String, _ collectionName: String) -> CatalogEntry {
        CatalogEntry(
            number: number,
            title: title,
            releaseYear: 2020,
            collectionName: collectionName
        )
    }
}
