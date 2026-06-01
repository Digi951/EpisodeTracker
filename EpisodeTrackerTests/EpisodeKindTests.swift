import XCTest
@testable import EpisodeTracker

final class EpisodeKindTests: XCTestCase {
    func testDefaultKindIsRegular() {
        let episode = Episode(episodeNumber: 1, title: "Test", releaseYear: 2024)
        XCTAssertEqual(episode.kind, .regular)
        XCTAssertFalse(episode.isSpecial)
    }

    func testSettingSpecialKindPersistsRaw() {
        let episode = Episode(episodeNumber: 0, title: "Special", releaseYear: 2024)
        episode.kind = .special
        XCTAssertEqual(episode.kindRaw, "special")
        XCTAssertTrue(episode.isSpecial)
    }
}
