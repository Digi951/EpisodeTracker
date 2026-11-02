import XCTest
@testable import EpisodeTracker

/// Regeln aus dem Design Review 2026-11 für die Folgenliste.
final class EpisodeListDesignReviewTests: XCTestCase {

    // MARK: - Reihenname vorne am Titel

    func testSeriesNameFollowedByLowercaseIsReplacedWithEllipsis() {
        let title = EpisodeListOrganizer.titleOmittingSeriesPrefix(
            "Fünf Freigeister auf Abenteuer",
            seriesNames: ["Fünf Freigeister"]
        )
        XCTAssertEqual(title, "… auf Abenteuer")
    }

    func testShortFormBeforeDashCountsAsPrefix() {
        let title = EpisodeListOrganizer.titleOmittingSeriesPrefix(
            "TKKF und der Bankräuber",
            seriesNames: ["TKKF – Team für knifflige Kriminalfälle"]
        )
        XCTAssertEqual(title, "… und der Bankräuber")
    }

    func testSeriesNameFollowedByColonKeepsRestWithoutEllipsis() {
        let title = EpisodeListOrganizer.titleOmittingSeriesPrefix(
            "Bibi Blocksberg: Das Hexenfest",
            seriesNames: ["Bibi Blocksberg"]
        )
        XCTAssertEqual(title, "Das Hexenfest")
    }

    func testSeriesNameFollowedByDashKeepsRest() {
        let title = EpisodeListOrganizer.titleOmittingSeriesPrefix(
            "TKKF – Der Fall im Park",
            seriesNames: ["TKKF – Team für knifflige Kriminalfälle"]
        )
        XCTAssertEqual(title, "Der Fall im Park")
    }

    /// Ein großgeschriebener Rest gehört zu einem eigenen Titel und bleibt stehen.
    func testCapitalizedRemainderIsLeftUntouched() {
        let title = EpisodeListOrganizer.titleOmittingSeriesPrefix(
            "Fünf Freunde Spezial",
            seriesNames: ["Fünf Freunde"]
        )
        XCTAssertEqual(title, "Fünf Freunde Spezial")
    }

    func testTitleWithoutSeriesPrefixIsUnchanged() {
        let title = EpisodeListOrganizer.titleOmittingSeriesPrefix(
            "… und der brennende Berg",
            seriesNames: ["Die drei Detektive"]
        )
        XCTAssertEqual(title, "… und der brennende Berg")
    }

    /// Ein Titel, der nur aus dem Reihennamen besteht, darf nicht leer werden.
    func testTitleEqualToSeriesNameIsUnchanged() {
        let title = EpisodeListOrganizer.titleOmittingSeriesPrefix(
            "Fünf Freigeister",
            seriesNames: ["Fünf Freigeister"]
        )
        XCTAssertEqual(title, "Fünf Freigeister")
    }

    /// Nur ganze Wörter: „Fünf Freigeisterin …“ ist kein Präfix-Treffer.
    func testPrefixMustEndAtWordBoundary() {
        let title = EpisodeListOrganizer.titleOmittingSeriesPrefix(
            "Fünf Freigeisterinnen unterwegs",
            seriesNames: ["Fünf Freigeister"]
        )
        XCTAssertEqual(title, "Fünf Freigeisterinnen unterwegs")
    }

    func testPrefixMatchIgnoresCase() {
        let title = EpisodeListOrganizer.titleOmittingSeriesPrefix(
            "die drei ??? und der Fluch",
            seriesNames: ["Die drei ???"]
        )
        XCTAssertEqual(title, "… und der Fluch")
    }

    // MARK: - Höchstens ein Banner

    func testFeatureAnnouncementHiddenWhileCatalogBannerIsShown() {
        XCTAssertFalse(EpisodeListOrganizer.shouldShowFeatureAnnouncement(
            hasCatalogBanner: true, hasActiveFilter: false, searchText: ""
        ))
    }

    func testFeatureAnnouncementShownWithoutCatalogBanner() {
        XCTAssertTrue(EpisodeListOrganizer.shouldShowFeatureAnnouncement(
            hasCatalogBanner: false, hasActiveFilter: false, searchText: ""
        ))
    }

    func testFeatureAnnouncementHiddenWhileFilteringOrSearching() {
        XCTAssertFalse(EpisodeListOrganizer.shouldShowFeatureAnnouncement(
            hasCatalogBanner: false, hasActiveFilter: true, searchText: ""
        ))
        XCTAssertFalse(EpisodeListOrganizer.shouldShowFeatureAnnouncement(
            hasCatalogBanner: false, hasActiveFilter: false, searchText: "Berg"
        ))
    }

    // MARK: - Reihen-Gruppen

    func testOnlyUniverseGroupsOmitSeriesPrefix() {
        XCTAssertTrue(EpisodeListGroup(id: "universe:die drei ???", title: "Die drei ???", episodes: [], progressTotalOverride: nil).isUniverseGroup)
        XCTAssertFalse(EpisodeListGroup(id: "range:1-25", title: "1–25", episodes: [], progressTotalOverride: nil).isUniverseGroup)
    }
}
