import XCTest
@testable import EpisodeTracker

final class WidgetEpisodeSnapshotTests: XCTestCase {

    func testShowsSpecialBadgeIsFalseForAnthologyEpisode() {
        let snapshot = WidgetEpisodeSnapshot(
            id: UUID(),
            episodeNumber: 0,
            title: "Odcinek",
            releaseYear: 2024,
            isListened: false,
            kindRaw: "special",
            usesEpisodeNumbers: false
        )

        XCTAssertTrue(snapshot.isSpecial)
        XCTAssertFalse(snapshot.showsSpecialBadge)
    }

    func testShowsSpecialBadgeIsTrueForSpecialInNumberedCatalog() {
        let snapshot = WidgetEpisodeSnapshot(
            id: UUID(),
            episodeNumber: 0,
            title: "Jubiläum",
            releaseYear: 2024,
            isListened: false,
            kindRaw: "special",
            usesEpisodeNumbers: true
        )

        XCTAssertTrue(snapshot.showsSpecialBadge)
    }

    func testDecodingWithoutUsesEpisodeNumbersFieldDefaultsToTrue() throws {
        // Snapshot files written before this field existed lack the key entirely.
        let json = """
        {
          "id": "\(UUID().uuidString)",
          "episodeNumber": 1,
          "title": "Test",
          "releaseYear": 2000,
          "isListened": false,
          "kindRaw": "regular"
        }
        """
        let snapshot = try JSONDecoder().decode(WidgetEpisodeSnapshot.self, from: Data(json.utf8))

        XCTAssertTrue(snapshot.usesEpisodeNumbers)
    }
}
