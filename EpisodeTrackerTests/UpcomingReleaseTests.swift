import XCTest
@testable import EpisodeTracker

final class UpcomingReleaseTests: XCTestCase {

    func testDecodesReleaseDateFromISODateString() throws {
        let json = """
        {
          "updatedAt": "2026-08-24",
          "releases": [
            {
              "catalogID": "die-drei-fragezeichen",
              "number": 241,
              "title": "Meister des Lichts",
              "releaseDate": "2026-09-18"
            }
          ]
        }
        """
        let document = try UpcomingReleasesDocument.decoder.decode(
            UpcomingReleasesDocument.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(document.releases.count, 1)
        let release = document.releases[0]
        XCTAssertEqual(release.catalogID, "die-drei-fragezeichen")
        XCTAssertEqual(release.number, 241)
        XCTAssertEqual(release.title, "Meister des Lichts")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents([.year, .month, .day], from: release.releaseDate)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 9)
        XCTAssertEqual(components.day, 18)
    }

    func testDecodingFailsForMalformedDate() {
        let json = """
        {
          "updatedAt": "2026-08-24",
          "releases": [
            {
              "catalogID": "tkkg",
              "number": 243,
              "title": "Die Fährte des Hehlers",
              "releaseDate": "18.09.2026"
            }
          ]
        }
        """
        XCTAssertThrowsError(
            try UpcomingReleasesDocument.decoder.decode(UpcomingReleasesDocument.self, from: Data(json.utf8))
        )
    }
}
