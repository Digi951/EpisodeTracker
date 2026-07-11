import XCTest
@testable import EpisodeTracker

/// Covers `FeatureAnnouncement.recordInstallOriginIfNeeded` (the once-per-install
/// established-vs-fresh determination) and `FeatureAnnouncement.shouldShow` (the
/// pure visibility rule the banner row evaluates).
final class FeatureAnnouncementTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "FeatureAnnouncementTest-\(UUID().uuidString)")!
    }

    // MARK: - recordInstallOriginIfNeeded

    func testFreshInstallIsNotEstablished() {
        let defaults = makeDefaults()
        FeatureAnnouncement.recordInstallOriginIfNeeded(lastSchemaVersion: 0, libraryIsEmpty: true, in: defaults)
        XCTAssertFalse(
            defaults.bool(forKey: FeatureAnnouncement.establishedInstallKey),
            "A genuine fresh install (no schema version, no data) must not be recorded as established"
        )
    }

    func testPreVersioningUpgraderWithDataIsEstablished() {
        let defaults = makeDefaults()
        FeatureAnnouncement.recordInstallOriginIfNeeded(lastSchemaVersion: 0, libraryIsEmpty: false, in: defaults)
        XCTAssertTrue(
            defaults.bool(forKey: FeatureAnnouncement.establishedInstallKey),
            "An upgrader from before schema-version tracking who already has data must be established"
        )
    }

    func testTrackedUpgraderIsEstablished() {
        let defaults = makeDefaults()
        FeatureAnnouncement.recordInstallOriginIfNeeded(lastSchemaVersion: 4, libraryIsEmpty: true, in: defaults)
        XCTAssertTrue(
            defaults.bool(forKey: FeatureAnnouncement.establishedInstallKey),
            "An upgrader whose store already had a recorded schema version must be established even with an empty library"
        )
    }

    func testRecordInstallOriginIsRecordedOnlyOnce() {
        let defaults = makeDefaults()
        FeatureAnnouncement.recordInstallOriginIfNeeded(lastSchemaVersion: 0, libraryIsEmpty: true, in: defaults)
        FeatureAnnouncement.recordInstallOriginIfNeeded(lastSchemaVersion: 6, libraryIsEmpty: true, in: defaults)
        XCTAssertFalse(
            defaults.bool(forKey: FeatureAnnouncement.establishedInstallKey),
            "A later bootstrap (already-tracked schema version) must not overwrite the original fresh-install fact"
        )
    }

    // MARK: - shouldShow

    func testShouldShowFalseWhenNotPending() {
        XCTAssertFalse(FeatureAnnouncement.shouldShow(isPending: false, libraryIsEmpty: true, isEstablishedInstall: true))
    }

    func testShouldShowTrueWhenLibraryNotEmpty() {
        XCTAssertTrue(FeatureAnnouncement.shouldShow(isPending: true, libraryIsEmpty: false, isEstablishedInstall: false))
    }

    func testShouldShowTrueWhenEstablishedEvenIfLibraryEmpty() {
        XCTAssertTrue(FeatureAnnouncement.shouldShow(isPending: true, libraryIsEmpty: true, isEstablishedInstall: true))
    }

    func testShouldShowFalseWhenFreshInstallAndLibraryEmpty() {
        XCTAssertFalse(FeatureAnnouncement.shouldShow(isPending: true, libraryIsEmpty: true, isEstablishedInstall: false))
    }
}
