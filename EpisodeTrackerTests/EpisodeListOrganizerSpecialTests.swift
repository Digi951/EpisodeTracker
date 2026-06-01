import XCTest
@testable import EpisodeTracker

final class EpisodeListOrganizerSpecialTests: XCTestCase {
    private func makeRegulars(_ count: Int, universe: Universe) -> [Episode] {
        (1...count).map { Episode(episodeNumber: $0, title: "Folge \($0)", releaseYear: 1979, universe: universe) }
    }

    func testSpecialEpisodesGroupedSeparatelyAtEnd() {
        let universe = Universe(name: "Die drei ???")
        var episodes = makeRegulars(12, universe: universe)
        let special = Episode(
            episodeNumber: 0,
            title: "Phantomsee",
            releaseYear: 2024,
            kind: .special,
            catalogSlug: "phantomsee-2024",
            universe: universe
        )
        episodes.append(special)

        let groups = EpisodeListOrganizer.groups(
            for: episodes,
            sortOrder: .number,
            filterUniverse: universe,
            universeCount: 1
        )

        let specialGroup = try? XCTUnwrap(groups.last)
        XCTAssertEqual(specialGroup?.id, "special")
        XCTAssertEqual(specialGroup?.episodes.map(\.title), ["Phantomsee"])

        // Reguläre Bänder dürfen keine Sonderfolge enthalten.
        for group in groups where group.id != "special" {
            XCTAssertFalse(group.episodes.contains { $0.isSpecial })
        }
    }

    func testSortPushesSpecialsToEndForNumberOrder() {
        let universe = Universe(name: "Die drei ???")
        let regular1 = Episode(episodeNumber: 1, title: "A", releaseYear: 1979, universe: universe)
        let regular2 = Episode(episodeNumber: 2, title: "B", releaseYear: 1979, universe: universe)
        let special = Episode(episodeNumber: 0, title: "Special", releaseYear: 2024, kind: .special, catalogSlug: "s-2024", universe: universe)

        let sorted = EpisodeListOrganizer.filteredAndSortedEpisodes(
            episodes: [special, regular2, regular1],
            searchText: "",
            filterUniverse: nil,
            filterMood: nil,
            statusFilter: .all,
            sortOrder: .number
        )

        XCTAssertEqual(sorted.map(\.title), ["A", "B", "Special"])
    }
}
