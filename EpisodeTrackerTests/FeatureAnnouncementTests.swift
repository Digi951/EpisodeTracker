import XCTest
@testable import EpisodeTracker

/// Covers the dismiss-once fingerprint mechanism behind the feature-announcement
/// banner. Visibility for empty libraries is handled at the display layer
/// (`!episodes.isEmpty` in the list views), not here.
final class FeatureAnnouncementTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "FeatureAnnouncementTest-\(UUID().uuidString)")!
    }

    func testAnnouncementPendingByDefault() {
        XCTAssertTrue(FeatureAnnouncement.isPending(in: makeDefaults()))
    }

    func testMarkSeenClearsPending() {
        let defaults = makeDefaults()
        FeatureAnnouncement.markSeen(in: defaults)
        XCTAssertFalse(FeatureAnnouncement.isPending(in: defaults))
    }
}
