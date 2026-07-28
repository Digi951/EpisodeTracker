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

    // MARK: - Manifest-Decoding

    private func decodeSource(_ json: String) throws -> ManagedCatalogSource {
        try JSONDecoder().decode(ManagedCatalogSource.self, from: Data(json.utf8))
    }

    func testManifestSourceWithoutStyleDefaultsToNumbered() throws {
        let source = try decodeSource("""
        { "id": "drei-fragezeichen", "name": "Die drei ???", "url": "https://example.com/a.json" }
        """)

        XCTAssertEqual(source.effectiveStyle, .numbered)
    }

    func testManifestSourceDecodesAnthologyStyle() throws {
        let source = try decodeSource("""
        {
          "id": "teatr-polskiego-radia",
          "name": "Teatr Polskiego Radia",
          "language": "pl",
          "style": "anthology",
          "url": "https://example.com/pl.json"
        }
        """)

        XCTAssertEqual(source.effectiveStyle, .anthology)
        XCTAssertEqual(source.effectiveLanguage, "pl")
    }

    func testManifestSourceWithUnknownStyleFallsBackToNumbered() throws {
        let source = try decodeSource("""
        { "id": "x", "name": "X", "style": "boxset", "url": "https://example.com/x.json" }
        """)

        XCTAssertEqual(source.effectiveStyle, .numbered)
    }
}
