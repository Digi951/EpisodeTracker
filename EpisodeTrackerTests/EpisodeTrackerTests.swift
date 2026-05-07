import XCTest
@testable import EpisodeTracker

final class EpisodeTrackerTests: XCTestCase {
    private let parser = CatalogParser()

    func testParsesWrappedCatalogEntriesWithFallbackCollection() throws {
        let json = """
        {
          "collectionName": "Die drei ???",
          "entries": [
            {
              "number": 1,
              "title": "und der Super-Papagei",
              "releaseYear": 1979
            }
          ]
        }
        """

        let entries = try parser.parseCatalogEntries(
            from: Data(json.utf8),
            fallbackCollectionName: "Fallback"
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].number, 1)
        XCTAssertEqual(entries[0].title, "und der Super-Papagei")
        XCTAssertEqual(entries[0].releaseYear, 1979)
        XCTAssertEqual(entries[0].collectionName, "Die drei ???")
    }

    func testParsesFlatCatalogEntriesWithFallbackCollection() throws {
        let json = """
        [
          {
            "number": 1,
            "title": "und der Super-Papagei",
            "releaseYear": 1979
          }
        ]
        """

        let entries = try parser.parseCatalogEntries(
            from: Data(json.utf8),
            fallbackCollectionName: "Die drei ???"
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].collectionName, "Die drei ???")
    }

    func testParsesManifestAndNormalizesGitHubBlobURLs() throws {
        let json = """
        {
          "schemaVersion": 1,
          "updatedAt": "2026-05-03",
          "catalogs": [
            {
              "id": "die-drei-fragezeichen",
              "name": "Die drei ???",
              "language": "de",
              "url": "https://github.com/Digi951/hoerspiel-kataloge/blob/main/catalogs/The_three_questionmarks.json"
            }
          ]
        }
        """

        let manifest = try parser.parseManifest(from: Data(json.utf8))

        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.catalogs.count, 1)
        XCTAssertEqual(manifest.catalogs[0].url.absoluteString, "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/The_three_questionmarks.json")
    }

    func testFreemiumPreparationDoesNotBlockCreationYet() {
        XCTAssertFalse(FreemiumAccess.isEnforcementEnabled)
        XCTAssertTrue(
            FreemiumAccess.canCreateEpisode(
                currentEpisodeCount: FreemiumAccess.freeEpisodeLimit,
                isPlusUnlocked: false
            )
        )
    }

    func testFreemiumUsageTextShowsFreeLimitAndPlusState() {
        XCTAssertEqual(
            FreemiumAccess.freePlanUsageText(currentEpisodeCount: 12, isPlusUnlocked: false),
            "12 von \(FreemiumAccess.freeEpisodeLimit)"
        )
        XCTAssertEqual(
            FreemiumAccess.freePlanUsageText(currentEpisodeCount: 99, isPlusUnlocked: true),
            "Unbegrenzt"
        )
    }
}
