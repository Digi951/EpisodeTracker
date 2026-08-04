import XCTest
import SwiftData
@testable import EpisodeTracker

@MainActor
final class BackupRestorerTests: XCTestCase {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeEpisodeData(
        episodeNumber: Int = 1,
        kind: EpisodeKind = .regular,
        catalogSlug: String? = nil,
        title: String = "Folge",
        releaseYear: Int = 2020,
        isListened: Bool = false,
        rating: Int? = nil,
        listenCount: Int = 0,
        collectionName: String? = "Die drei ???",
        moodNames: [String] = []
    ) -> BackupEpisode {
        BackupEpisode(
            episodeNumber: episodeNumber,
            kind: kind,
            catalogSlug: catalogSlug,
            title: title,
            releaseYear: releaseYear,
            personalNote: nil,
            isListened: isListened,
            rating: rating,
            listenCount: listenCount,
            lastListenedAt: nil,
            collectionName: collectionName,
            moodNames: moodNames
        )
    }

    func testImportIntoEmptyLibraryCreatesUniverseAndEpisode() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let payload = BackupPayload(
            exportedAt: .now,
            schemaVersion: 2,
            collections: nil,
            moods: [],
            episodes: [makeEpisodeData(episodeNumber: 1, title: "Und der Super-Papagei")]
        )

        BackupRestorer.apply(payload, existingUniverses: [], existingMoods: [], existingEpisodes: [], context: context)

        let universes = try context.fetch(FetchDescriptor<Universe>())
        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(universes.map(\.name), ["Die drei ???"])
        XCTAssertEqual(episodes.first?.title, "Und der Super-Papagei")
    }

    /// Reimport desselben Backups darf keine Duplikate erzeugen — das ist der
    /// Kernvertrag von "Backup importieren" gegenüber "Backup einspielen und
    /// alles doppelt haben".
    func testReimportUpdatesExistingEpisodeInsteadOfDuplicating() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let universe = Universe(name: "Die drei ???")
        context.insert(universe)
        let episode = Episode(episodeNumber: 1, title: "Alter Titel", releaseYear: 2019, universe: universe)
        context.insert(episode)

        let payload = BackupPayload(
            exportedAt: .now,
            schemaVersion: 2,
            collections: nil,
            moods: [],
            episodes: [makeEpisodeData(episodeNumber: 1, title: "Neuer Titel", isListened: true)]
        )

        BackupRestorer.apply(
            payload,
            existingUniverses: [universe],
            existingMoods: [],
            existingEpisodes: [episode],
            context: context
        )

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.count, 1)
        XCTAssertEqual(episodes.first?.title, "Neuer Titel")
        XCTAssertTrue(episodes.first?.isListened ?? false)
    }

    /// Sammlungsnamen im Backup dürfen von zusätzlichem Whitespace begleitet sein
    /// (z.B. aus einem älteren Export), ohne dass daraus eine zweite Sammlung
    /// entsteht — dieselbe Normalisierung wie in `CatalogManagementView`.
    func testUniverseMatchingIgnoresWhitespaceDrift() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let universe = Universe(name: "Die drei ???")
        context.insert(universe)

        let payload = BackupPayload(
            exportedAt: .now,
            schemaVersion: 2,
            collections: [BackupCollection(name: " Die drei ??? ")],
            moods: [],
            episodes: [makeEpisodeData(episodeNumber: 1, collectionName: " Die drei ??? ")]
        )

        BackupRestorer.apply(
            payload,
            existingUniverses: [universe],
            existingMoods: [],
            existingEpisodes: [],
            context: context
        )

        let universes = try context.fetch(FetchDescriptor<Universe>())
        XCTAssertEqual(universes.count, 1, "Whitespace-Drift darf keine zweite Sammlung erzeugen")
    }

    func testSpecialEpisodeMatchesBySlugNotNumber() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let universe = Universe(name: "Die drei ???")
        context.insert(universe)
        let special = Episode(
            episodeNumber: 0,
            title: "Phantomsee",
            releaseYear: 2024,
            kind: .special,
            catalogSlug: "phantomsee-2024",
            universe: universe
        )
        context.insert(special)

        let payload = BackupPayload(
            exportedAt: .now,
            schemaVersion: 2,
            collections: nil,
            moods: [],
            episodes: [
                makeEpisodeData(episodeNumber: 0, kind: .special, catalogSlug: "phantomsee-2024", title: "Phantomsee (aktualisiert)")
            ]
        )

        BackupRestorer.apply(
            payload,
            existingUniverses: [universe],
            existingMoods: [],
            existingEpisodes: [special],
            context: context
        )

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.count, 1)
        XCTAssertEqual(episodes.first?.title, "Phantomsee (aktualisiert)")
    }

    func testMoodsAreMergedByNameAndAssignedToEpisode() throws {
        let context = ModelContext(try makeInMemoryContainer())
        let payload = BackupPayload(
            exportedAt: .now,
            schemaVersion: 2,
            collections: nil,
            moods: [BackupMood(name: "Spannend", iconName: "bolt")],
            episodes: [makeEpisodeData(moodNames: ["Spannend"])]
        )

        BackupRestorer.apply(payload, existingUniverses: [], existingMoods: [], existingEpisodes: [], context: context)

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.first?.moods.map(\.name), ["Spannend"])
    }
}
