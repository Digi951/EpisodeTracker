import XCTest
@testable import EpisodeTracker

final class EpisodeRowBadgeTests: XCTestCase {
    func test_hasCoverAnchor_ownCoverPresent_isTrue() {
        XCTAssertTrue(EpisodeRowView.hasCoverAnchor(coverImageName: "cover.jpg", anyEpisodeHasCover: false))
    }

    func test_hasCoverAnchor_noOwnCoverButCollectionHasCovers_isTrue() {
        XCTAssertTrue(EpisodeRowView.hasCoverAnchor(coverImageName: nil, anyEpisodeHasCover: true))
    }

    func test_hasCoverAnchor_emptyStringTreatedAsNoCover() {
        XCTAssertTrue(EpisodeRowView.hasCoverAnchor(coverImageName: "", anyEpisodeHasCover: true))
        XCTAssertFalse(EpisodeRowView.hasCoverAnchor(coverImageName: "", anyEpisodeHasCover: false))
    }

    func test_hasCoverAnchor_neitherPresent_isFalse() {
        XCTAssertFalse(EpisodeRowView.hasCoverAnchor(coverImageName: nil, anyEpisodeHasCover: false))
    }
}
