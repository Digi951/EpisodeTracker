import XCTest
@testable import EpisodeTracker

final class CatalogStyleTests: XCTestCase {

    func testRawValuesAreStable() {
        XCTAssertEqual(CatalogStyle.numbered.rawValue, "numbered")
        XCTAssertEqual(CatalogStyle.anthology.rawValue, "anthology")
    }

    func testResolveDefaultsToNumberedForNil() {
        XCTAssertEqual(CatalogStyle.resolve(nil), .numbered)
    }

    func testResolveDefaultsToNumberedForUnknownValue() {
        XCTAssertEqual(CatalogStyle.resolve("boxset"), .numbered)
    }

    func testResolveIsCaseInsensitiveAndTrims() {
        XCTAssertEqual(CatalogStyle.resolve("  Anthology "), .anthology)
    }

    func testUsesEpisodeNumbers() {
        XCTAssertTrue(CatalogStyle.numbered.usesEpisodeNumbers)
        XCTAssertFalse(CatalogStyle.anthology.usesEpisodeNumbers)
    }
}
