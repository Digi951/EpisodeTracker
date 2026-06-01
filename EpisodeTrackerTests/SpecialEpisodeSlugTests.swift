import XCTest
@testable import EpisodeTracker

final class SpecialEpisodeSlugTests: XCTestCase {
    func testBasicTransliteration() {
        XCTAssertEqual(
            SpecialEpisodeSlug.make(title: "Und der Phantomsee (Jubiläum)", releaseYear: 2024),
            "und-der-phantomsee-jubilaeum-2024"
        )
    }

    func testUmlautsAndSharpS() {
        XCTAssertEqual(
            SpecialEpisodeSlug.make(title: "Über die Straße", releaseYear: 2020),
            "ueber-die-strasse-2020"
        )
    }

    func testQuestionMarksCollapse() {
        XCTAssertEqual(
            SpecialEpisodeSlug.make(title: "Die drei ??? Spezial", releaseYear: 2019),
            "die-drei-spezial-2019"
        )
    }

    func testMultipleSpaces() {
        XCTAssertEqual(
            SpecialEpisodeSlug.make(title: "A    B", releaseYear: 2000),
            "a-b-2000"
        )
    }

    func testEmptyAfterTransliterationFallsBackToHash() {
        let slug = SpecialEpisodeSlug.make(title: "???", releaseYear: 2021, universeKey: "the-three")
        XCTAssertTrue(slug.hasPrefix("h-"), "Erwartet Hash-Fallback, war: \(slug)")
        XCTAssertEqual(slug, SpecialEpisodeSlug.make(title: "???", releaseYear: 2021, universeKey: "the-three"))
    }
}
