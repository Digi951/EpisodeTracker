import XCTest
@testable import EpisodeTracker

final class UpcomingReleaseTests: XCTestCase {

    private func decode(_ json: String) throws -> UpcomingReleasesDocument {
        try JSONDecoder().decode(UpcomingReleasesDocument.self, from: Data(json.utf8))
    }

    func testDecodesReleaseDateAsLocalMidnight() throws {
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
        let document = try decode(json)

        XCTAssertEqual(document.releases.count, 1)
        let release = document.releases[0]
        XCTAssertEqual(release.catalogID, "die-drei-fragezeichen")
        XCTAssertEqual(release.number, 241)
        XCTAssertEqual(release.title, "Meister des Lichts")

        // Der Tag muss im lokalen Kalender der 18.09. sein - sonst zeigt die UI
        // westlich von UTC den Vortag an und blendet die Folge zu früh aus.
        let components = Calendar.current.dateComponents([.year, .month, .day], from: release.releaseDate)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 9)
        XCTAssertEqual(components.day, 18)
        XCTAssertEqual(release.releaseDate, Calendar.current.startOfDay(for: release.releaseDate))
    }

    func testSkipsMalformedEntryButKeepsTheRest() throws {
        let json = """
        {
          "updatedAt": "2026-08-24",
          "releases": [
            { "catalogID": "tkkg", "number": 243, "title": "Die Fährte des Hehlers", "releaseDate": "18.09.2026" },
            { "catalogID": "die-drei-fragezeichen", "number": 241, "title": "Meister des Lichts", "releaseDate": "2026-09-18" },
            { "catalogID": "bibi-blocksberg", "number": 1 }
          ]
        }
        """
        let document = try decode(json)

        XCTAssertEqual(document.releases.map(\.catalogID), ["die-drei-fragezeichen"])
    }

    func testRoundTripsThroughEncoderWithoutDriftingByADay() throws {
        let json = """
        {
          "updatedAt": "2026-08-24",
          "releases": [
            { "catalogID": "tkkg", "number": 243, "title": "Die Fährte des Hehlers", "releaseDate": "2026-09-11" }
          ]
        }
        """
        let original = try decode(json).releases

        let encoded = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode([UpcomingRelease].self, from: encoded)

        XCTAssertEqual(restored, original)
    }

    func testDecodingFailsForCompletelyMalformedPayload() {
        XCTAssertThrowsError(try decode("nicht json"))
    }
}
