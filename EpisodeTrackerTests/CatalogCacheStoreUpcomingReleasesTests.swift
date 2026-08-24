import XCTest
@testable import EpisodeTracker

final class CatalogCacheStoreUpcomingReleasesTests: XCTestCase {

    private func makeStore() -> CatalogCacheStore {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CatalogCacheStoreUpcomingReleasesTests-\(UUID().uuidString)")
        return CatalogCacheStore(directoryURL: tempDir)
    }

    func testLoadUpcomingReleasesReturnsEmptyWhenNothingCached() {
        let store = makeStore()
        XCTAssertEqual(store.loadUpcomingReleases(), [])
    }

    func testSaveAndLoadUpcomingReleasesRoundTrips() throws {
        let store = makeStore()
        let release = UpcomingRelease(
            catalogID: "die-drei-fragezeichen",
            number: 241,
            title: "Meister des Lichts",
            releaseDate: Date(timeIntervalSince1970: 1_789_000_000)
        )

        try store.saveUpcomingReleases([release])

        XCTAssertEqual(store.loadUpcomingReleases(), [release])
    }
}
