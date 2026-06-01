import XCTest
@testable import EpisodeTracker

final class EpisodeSyncKeyTests: XCTestCase {
    func testRegularSyncKeyUnchanged() {
        let key = Episode.makeSyncKey(universeSyncKey: "universe:abc", kind: .regular, episodeNumber: 42, catalogSlug: nil)
        XCTAssertEqual(key, "episode:universe:abc#42")
    }

    func testSpecialSyncKeyUsesSlug() {
        let key = Episode.makeSyncKey(universeSyncKey: "universe:abc", kind: .special, episodeNumber: 0, catalogSlug: "phantomsee-2024")
        XCTAssertEqual(key, "episode:universe:abc#special:phantomsee-2024")
    }

    func testSpecialWithNumberStillUsesSlug() {
        let key = Episode.makeSyncKey(universeSyncKey: "universe:abc", kind: .special, episodeNumber: 3, catalogSlug: "box-3-2024")
        XCTAssertEqual(key, "episode:universe:abc#special:box-3-2024")
    }

    func testSpecialWithoutSlugIsPending() {
        let key = Episode.makeSyncKey(universeSyncKey: "universe:abc", kind: .special, episodeNumber: 0, catalogSlug: nil)
        XCTAssertTrue(key.hasPrefix("episode:pending:"))
    }
}
