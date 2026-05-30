import XCTest
@testable import EpisodeTracker

/// Covers that feature-announcement banners only reach users who actually updated
/// from an older version — not fresh installs.
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

    func testFreshInstallSuppressesAnnouncement() {
        let defaults = makeDefaults()
        AppDataBootstrapper.suppressFeatureAnnouncementsIfFreshInstall(
            lastSchemaVersion: 0,
            libraryIsEmpty: true,
            userDefaults: defaults
        )
        XCTAssertFalse(
            FeatureAnnouncement.isPending(in: defaults),
            "A fresh install must not see the 'new feature' announcement"
        )
    }

    func testPreVersioningUpgraderWithDataStillSeesAnnouncement() {
        let defaults = makeDefaults()
        AppDataBootstrapper.suppressFeatureAnnouncementsIfFreshInstall(
            lastSchemaVersion: 0,
            libraryIsEmpty: false,
            userDefaults: defaults
        )
        XCTAssertTrue(
            FeatureAnnouncement.isPending(in: defaults),
            "An upgrader from before schema-version tracking (has data) must still see it"
        )
    }

    func testTrackedUpgraderStillSeesAnnouncement() {
        let defaults = makeDefaults()
        AppDataBootstrapper.suppressFeatureAnnouncementsIfFreshInstall(
            lastSchemaVersion: 4,
            libraryIsEmpty: true,
            userDefaults: defaults
        )
        XCTAssertTrue(
            FeatureAnnouncement.isPending(in: defaults),
            "An upgrader whose store already had a recorded schema version must still see it"
        )
    }
}
