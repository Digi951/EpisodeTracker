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
        // Wie die echten Daten auf lokale Mitternacht verankert - UpcomingRelease
        // speichert nur den Kalendertag, eine Uhrzeit ginge beim Schreiben verloren.
        let release = UpcomingRelease(
            catalogID: "die-drei-fragezeichen",
            number: 241,
            title: "Meister des Lichts",
            releaseDate: Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_789_000_000))
        )

        try store.saveUpcomingReleases([release])

        XCTAssertEqual(store.loadUpcomingReleases(), [release])
    }

    func testSaveDropsTimeOfDayBecauseOnlyTheCalendarDayIsStored() throws {
        let store = makeStore()
        let noon = Date(timeIntervalSince1970: 1_789_000_000)
        let release = UpcomingRelease(
            catalogID: "tkkg",
            number: 243,
            title: "Die Fährte des Hehlers",
            releaseDate: noon
        )

        try store.saveUpcomingReleases([release])

        XCTAssertEqual(
            store.loadUpcomingReleases().first?.releaseDate,
            Calendar.current.startOfDay(for: noon)
        )
    }
}
