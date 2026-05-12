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

    func testLargeNumberSortedLibraryGroupsIntoEpisodeRanges() {
        let universe = Universe(name: "Die drei ???")
        let episodes = (1...55).map { number in
            Episode(episodeNumber: number, title: "Folge \(number)", releaseYear: 1980, universe: universe)
        }

        let sorted = EpisodeListOrganizer.filteredAndSortedEpisodes(
            episodes: episodes,
            searchText: "",
            filterUniverse: universe,
            filterMood: nil,
            statusFilter: .all,
            sortOrder: .number
        )
        let groups = EpisodeListOrganizer.groups(
            for: sorted,
            sortOrder: .number,
            filterUniverse: universe,
            universeCount: 1
        )

        XCTAssertEqual(groups.map(\.title), ["1-25", "26-50", "51-75"])
        XCTAssertEqual(groups.map(\.episodes.count), [25, 25, 5])
    }

    func testSmallLibrariesStayUngroupedByDefault() {
        let universe = Universe(name: "Die drei ???")
        let episodes = [
            Episode(episodeNumber: 1, title: "und der Super-Papagei", releaseYear: 1979, universe: universe)
        ]

        let groups = EpisodeListOrganizer.groups(
            for: episodes,
            sortOrder: .number,
            filterUniverse: nil,
            universeCount: 2
        )

        XCTAssertTrue(groups.isEmpty)
    }

    func testStatusFilterKeepsOnlyOpenEpisodes() {
        let episodes = [
            Episode(episodeNumber: 1, title: "Gehört", releaseYear: 1980, isListened: true),
            Episode(episodeNumber: 2, title: "Offen", releaseYear: 1981, isListened: false)
        ]

        let result = EpisodeListOrganizer.filteredAndSortedEpisodes(
            episodes: episodes,
            searchText: "",
            filterUniverse: nil,
            filterMood: nil,
            statusFilter: .open,
            sortOrder: .number
        )

        XCTAssertEqual(result.map(\.title), ["Offen"])
    }

    func testGroupSummaryCountsListenedAndOpenEpisodes() {
        let group = EpisodeListGroup(
            id: "test",
            title: "Test",
            episodes: [
                Episode(episodeNumber: 1, title: "Gehört", releaseYear: 1980, isListened: true),
                Episode(episodeNumber: 2, title: "Offen", releaseYear: 1981, isListened: false),
                Episode(episodeNumber: 3, title: "Auch offen", releaseYear: 1982, isListened: false)
            ]
        )

        XCTAssertEqual(group.listenedCount, 1)
        XCTAssertEqual(group.openCount, 2)
        XCTAssertEqual(group.summary, "3 Folgen · 1 gehört · 2 offen")
    }
}
