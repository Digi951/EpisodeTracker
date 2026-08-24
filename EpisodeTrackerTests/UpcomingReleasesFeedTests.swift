import XCTest
@testable import EpisodeTracker

final class UpcomingReleasesFeedTests: XCTestCase {

    private let today = Date(timeIntervalSince1970: 1_756_000_000)

    private func release(_ catalogID: String, _ number: Int, daysFromToday: Int) -> UpcomingRelease {
        UpcomingRelease(
            catalogID: catalogID,
            number: number,
            title: "Folge \(number)",
            releaseDate: today.addingTimeInterval(Double(daysFromToday) * 86_400)
        )
    }

    func testFiltersOutInactiveCatalogs() {
        let feed = UpcomingReleasesFeed.make(
            releases: [release("tkkg", 243, daysFromToday: 5), release("bibi-blocksberg", 1, daysFromToday: 5)],
            activeCatalogIDs: ["tkkg"],
            namesByCatalogID: ["tkkg": "TKKG", "bibi-blocksberg": "Bibi Blocksberg"],
            seenReleaseIDs: [],
            today: today
        )

        XCTAssertEqual(feed.rows.map(\.release.catalogID), ["tkkg"])
    }

    func testFiltersOutAlreadyReleasedEpisodes() {
        let feed = UpcomingReleasesFeed.make(
            releases: [release("tkkg", 242, daysFromToday: -1), release("tkkg", 243, daysFromToday: 3)],
            activeCatalogIDs: ["tkkg"],
            namesByCatalogID: ["tkkg": "TKKG"],
            seenReleaseIDs: [],
            today: today
        )

        XCTAssertEqual(feed.rows.map(\.release.number), [243])
    }

    func testKeepsEpisodeReleasingToday() {
        let feed = UpcomingReleasesFeed.make(
            releases: [release("tkkg", 243, daysFromToday: 0)],
            activeCatalogIDs: ["tkkg"],
            namesByCatalogID: ["tkkg": "TKKG"],
            seenReleaseIDs: [],
            today: today
        )

        XCTAssertEqual(feed.rows.map(\.release.number), [243])
    }

    func testSortsByReleaseDateAscending() {
        let feed = UpcomingReleasesFeed.make(
            releases: [release("tkkg", 244, daysFromToday: 20), release("tkkg", 243, daysFromToday: 3)],
            activeCatalogIDs: ["tkkg"],
            namesByCatalogID: ["tkkg": "TKKG"],
            seenReleaseIDs: [],
            today: today
        )

        XCTAssertEqual(feed.rows.map(\.release.number), [243, 244])
    }

    func testResolvesSeriesNameAndSkipsUnknownCatalogs() {
        let feed = UpcomingReleasesFeed.make(
            releases: [release("tkkg", 243, daysFromToday: 3), release("was-auch-immer", 1, daysFromToday: 3)],
            activeCatalogIDs: ["tkkg", "was-auch-immer"],
            namesByCatalogID: ["tkkg": "TKKG"],
            seenReleaseIDs: [],
            today: today
        )

        XCTAssertEqual(feed.rows.count, 1)
        XCTAssertEqual(feed.rows.first?.seriesName, "TKKG")
    }

    func testHasUnseenIsTrueWhenAVisibleReleaseWasNotSeenYet() {
        let feed = UpcomingReleasesFeed.make(
            releases: [release("tkkg", 243, daysFromToday: 3)],
            activeCatalogIDs: ["tkkg"],
            namesByCatalogID: ["tkkg": "TKKG"],
            seenReleaseIDs: [],
            today: today
        )

        XCTAssertTrue(feed.hasUnseen)
    }

    func testHasUnseenIsFalseWhenAllVisibleReleasesWereSeen() {
        let feed = UpcomingReleasesFeed.make(
            releases: [release("tkkg", 243, daysFromToday: 3)],
            activeCatalogIDs: ["tkkg"],
            namesByCatalogID: ["tkkg": "TKKG"],
            seenReleaseIDs: ["tkkg-243"],
            today: today
        )

        XCTAssertFalse(feed.hasUnseen)
    }

    func testSeenIDsOnlyCoverCurrentlyVisibleRows() {
        // Verhindert, dass die gespeicherte Menge über Jahre mitwächst:
        // beim Merken wird nur der aktuell sichtbare Stand geschrieben.
        let feed = UpcomingReleasesFeed.make(
            releases: [release("tkkg", 242, daysFromToday: -5), release("tkkg", 243, daysFromToday: 3)],
            activeCatalogIDs: ["tkkg"],
            namesByCatalogID: ["tkkg": "TKKG"],
            seenReleaseIDs: ["tkkg-100", "tkkg-242"],
            today: today
        )

        XCTAssertEqual(feed.visibleReleaseIDs, ["tkkg-243"])
    }
}
