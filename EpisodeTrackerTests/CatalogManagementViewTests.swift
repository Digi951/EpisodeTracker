import XCTest
@testable import EpisodeTracker

final class CatalogManagementViewTests: XCTestCase {

    // MARK: - catalogSubtitle

    func testSubtitleNotLoadedWhenTitleCountNil() {
        XCTAssertEqual(CatalogToggleRow.catalogSubtitle(episodeCount: 0, titleCount: nil), "Nicht geladen")
    }

    func testSubtitleShowsTitleCountOnlyWhenNoEpisodesInLibrary() {
        XCTAssertEqual(CatalogToggleRow.catalogSubtitle(episodeCount: 0, titleCount: 256), "256 Titel")
    }

    func testSubtitleSingularFolgeWhenOneEpisodeInLibrary() {
        XCTAssertEqual(CatalogToggleRow.catalogSubtitle(episodeCount: 1, titleCount: 256), "1 Folge · 256 Titel")
    }

    func testSubtitlePluralFolgenWhenMultipleEpisodesInLibrary() {
        XCTAssertEqual(CatalogToggleRow.catalogSubtitle(episodeCount: 8, titleCount: 102), "8 Folgen · 102 Titel")
    }

    // MARK: - activeCountLabel

    func testActiveCountLabelFormatsCorrectly() {
        XCTAssertEqual(CatalogToggleRow.activeCountLabel(active: 3, total: 12), "3 von 12 aktiv")
    }

    func testActiveCountLabelWhenNoneActive() {
        XCTAssertEqual(CatalogToggleRow.activeCountLabel(active: 0, total: 5), "0 von 5 aktiv")
    }

    func testActiveCountLabelWhenAllActive() {
        XCTAssertEqual(CatalogToggleRow.activeCountLabel(active: 4, total: 4), "4 von 4 aktiv")
    }
}
