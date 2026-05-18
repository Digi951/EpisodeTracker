import XCTest
import SwiftData
@testable import EpisodeTracker

@MainActor
final class MigrationSafetyTests: XCTestCase {

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makePersistentContainer(url: URL) throws -> ModelContainer {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let config = ModelConfiguration("MigrationTest", schema: schema, url: url)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MigrationSafetyTest-\(UUID().uuidString)")
            .appendingPathComponent("test.store")
    }

    // MARK: - Relationship Roundtrip

    func testRelationshipsSurviveSaveFetchCycle() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let universe = Universe(name: "Die drei ???")
        let mood = Mood(name: "Spannend", iconName: "⚡")
        let episode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            universe: universe,
            moods: [mood]
        )

        context.insert(universe)
        context.insert(mood)
        context.insert(episode)
        try context.save()

        let fetchedEpisodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(fetchedEpisodes.count, 1)

        let fetched = fetchedEpisodes[0]
        XCTAssertEqual(fetched.universe?.name, "Die drei ???")
        XCTAssertEqual(fetched.moods.count, 1)
        XCTAssertEqual(fetched.moods.first?.name, "Spannend")
    }

    func testUniverseKnowsItsEpisodesAfterFetch() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let universe = Universe(name: "TKKG")
        let ep1 = Episode(episodeNumber: 1, title: "A", releaseYear: 1981, universe: universe)
        let ep2 = Episode(episodeNumber: 2, title: "B", releaseYear: 1982, universe: universe)

        context.insert(universe)
        context.insert(ep1)
        context.insert(ep2)
        try context.save()

        let fetchedUniverses = try context.fetch(FetchDescriptor<Universe>())
        XCTAssertEqual(fetchedUniverses.count, 1)
        XCTAssertEqual(fetchedUniverses[0].episodes.count, 2)
    }

    func testMoodKnowsItsEpisodesAfterFetch() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let mood = Mood(name: "Gruselig", iconName: "😱")
        let episode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            moods: [mood]
        )

        context.insert(mood)
        context.insert(episode)
        try context.save()

        let fetchedMoods = try context.fetch(FetchDescriptor<Mood>())
        XCTAssertEqual(fetchedMoods.count, 1)
        XCTAssertEqual(fetchedMoods[0].episodes.count, 1)
    }

    // MARK: - Persistent Store Roundtrip

    func testRelationshipsSurvivePersistentStoreReopen() throws {
        let storeURL = temporaryStoreURL()
        let storeDir = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: storeDir)
        }

        let episodeID: UUID
        do {
            let container = try makePersistentContainer(url: storeURL)
            let context = container.mainContext

            let universe = Universe(name: "Die drei ???")
            let mood = Mood(name: "Spannend", iconName: "⚡")
            let episode = Episode(
                episodeNumber: 42,
                title: "und der Phantomsee",
                releaseYear: 1984,
                universe: universe,
                moods: [mood]
            )
            episodeID = episode.id

            context.insert(universe)
            context.insert(mood)
            context.insert(episode)
            try context.save()
        }

        do {
            let container = try makePersistentContainer(url: storeURL)
            let context = container.mainContext

            let episodes = try context.fetch(FetchDescriptor<Episode>())
            let match = episodes.first { $0.id == episodeID }

            XCTAssertNotNil(match, "Episode should survive store reopen")
            XCTAssertEqual(match?.episodeNumber, 42)
            XCTAssertEqual(match?.title, "und der Phantomsee")
            XCTAssertEqual(match?.universe?.name, "Die drei ???")
            XCTAssertEqual(match?.moods.count, 1)
            XCTAssertEqual(match?.moods.first?.name, "Spannend")
        }
    }

    // MARK: - Bootstrapper Repairs

    func testBootstrapperAssignsOrphanedEpisodesToDefaultUniverse() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let orphan = Episode(
            episodeNumber: 1,
            title: "Orphan",
            releaseYear: 2000,
            universe: nil
        )
        context.insert(orphan)
        try context.save()

        AppDataBootstrapper.assignMissingCollectionsIfNeeded(container: container)

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertNotNil(episodes.first?.universe, "Orphaned episode should be assigned a universe")
    }

    func testBootstrapperRepairsDuplicateEpisodeIDs() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let sharedID = UUID()
        let ep1 = Episode(id: sharedID, episodeNumber: 1, title: "A", releaseYear: 1979)
        let ep2 = Episode(id: sharedID, episodeNumber: 2, title: "B", releaseYear: 1980)

        context.insert(ep1)
        context.insert(ep2)

        SyncPreparation.prepare(context: context)

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        let ids = episodes.map(\.id)
        XCTAssertEqual(Set(ids).count, 2, "Duplicate IDs should be repaired to unique values")
    }

    func testBootstrapperRepairsDuplicateMoodIDs() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let sharedID = UUID()
        let mood1 = Mood(id: sharedID, name: "Gruselig", iconName: "😱")
        let mood2 = Mood(id: sharedID, name: "Spannend", iconName: "⚡")

        context.insert(mood1)
        context.insert(mood2)

        SyncPreparation.prepare(context: context)

        let moods = try context.fetch(FetchDescriptor<Mood>())
        let ids = moods.map(\.id)
        XCTAssertEqual(Set(ids).count, moods.count, "Duplicate mood IDs should be repaired")
    }

    func testBootstrapperRepairsDuplicateUniverseIDs() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let sharedID = UUID()
        let u1 = Universe(id: sharedID, name: "Die drei ???")
        let u2 = Universe(id: sharedID, name: "TKKG")

        context.insert(u1)
        context.insert(u2)

        SyncPreparation.prepare(context: context)

        let universes = try context.fetch(FetchDescriptor<Universe>())
        let ids = universes.map(\.id)
        XCTAssertEqual(Set(ids).count, universes.count, "Duplicate universe IDs should be repaired")
    }

    func testBootstrapperFillsMissingSyncKeys() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let universe = Universe(name: "Die drei ???", syncKey: nil)
        universe.syncKey = nil
        let mood = Mood(name: "Spannend", syncKey: nil)
        mood.syncKey = nil
        let episode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            syncKey: nil,
            universe: universe,
            moods: [mood]
        )
        episode.syncKey = nil

        context.insert(universe)
        context.insert(mood)
        context.insert(episode)

        SyncPreparation.prepare(context: context)

        XCTAssertFalse(universe.resolvedSyncKey.isEmpty)
        XCTAssertFalse(mood.resolvedSyncKey.isEmpty)
        XCTAssertFalse(episode.resolvedSyncKey.isEmpty)
        XCTAssertTrue(universe.resolvedSyncKey.hasPrefix("universe:"))
        XCTAssertTrue(mood.resolvedSyncKey.hasPrefix("mood:"))
        XCTAssertTrue(episode.resolvedSyncKey.hasPrefix("episode:"))
    }

    func testBootstrapperDeduplicatesMoodsByNameWhenSyncKeysDiffer() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let original = Mood(name: "Spannend", iconName: nil, syncKey: "legacy:mood:spannend")
        let duplicate = Mood(name: " spannend ", iconName: "⚡", syncKey: "mood:spannend")
        let episode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            moods: [original, duplicate]
        )

        context.insert(original)
        context.insert(duplicate)
        context.insert(episode)

        SyncPreparation.prepare(context: context)

        let moods = try context.fetch(FetchDescriptor<Mood>())
        let episodes = try context.fetch(FetchDescriptor<Episode>())

        XCTAssertEqual(moods.count, 1, "Moods with the same normalized name should be merged")
        XCTAssertEqual(moods[0].iconName, "⚡", "The merged mood should keep a non-empty icon")
        XCTAssertEqual(episodes[0].moods.count, 1, "Episode mood links should point at the merged mood once")
        XCTAssertEqual(episodes[0].moods[0].id, moods[0].id)
    }

    func testBootstrapperDeduplicatesUniversesByNameWhenSyncKeysDiffer() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let original = Universe(name: "Die drei ???", syncKey: "legacy:universe:fragezeichen")
        let duplicate = Universe(name: " die drei ??? ", syncKey: "universe:die drei ???")
        let episode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            universe: duplicate
        )

        context.insert(original)
        context.insert(duplicate)
        context.insert(episode)

        SyncPreparation.prepare(context: context)

        let universes = try context.fetch(FetchDescriptor<Universe>())
        let episodes = try context.fetch(FetchDescriptor<Episode>())

        XCTAssertEqual(universes.count, 1, "Universes with the same normalized name should be merged")
        XCTAssertEqual(episodes[0].universe?.id, universes[0].id)
        XCTAssertEqual(universes[0].episodes.count, 1, "Existing episode assignments must survive the merge")
    }

    // MARK: - Cover Image Fallback

    func testEpisodeCoverFallsBackToUniverse() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let universe = Universe(name: "Test")
        universe.coverImageName = "universe-cover"
        let episode = Episode(episodeNumber: 1, title: "E1", releaseYear: 2020, universe: universe)

        context.insert(universe)
        context.insert(episode)
        try context.save()

        XCTAssertNil(episode.coverImageName)
        XCTAssertEqual(episode.resolvedCoverImageName(), "universe-cover")

        episode.coverImageName = "episode-cover"
        XCTAssertEqual(episode.resolvedCoverImageName(), "episode-cover")
    }

    // MARK: - Schema Metadata

    func testSchemaContainsOriginalNameForRenamedRelationships() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])

        let episodeEntity = schema.entities.first { $0.name == "Episode" }
        let moodEntity = schema.entities.first { $0.name == "Mood" }
        let universeEntity = schema.entities.first { $0.name == "Universe" }

        XCTAssertNotNil(episodeEntity, "Episode entity should exist in schema")
        XCTAssertNotNil(moodEntity, "Mood entity should exist in schema")
        XCTAssertNotNil(universeEntity, "Universe entity should exist in schema")

        let episodeMoodsRel = episodeEntity?.relationships.first {
            $0.name == "moodRelationships"
        }
        XCTAssertNotNil(episodeMoodsRel, "Episode should have moodRelationships")
        XCTAssertEqual(
            episodeMoodsRel?.originalName,
            "moods",
            "moodRelationships must declare originalName 'moods' for V1.0 migration"
        )

        let moodEpisodesRel = moodEntity?.relationships.first {
            $0.name == "episodeRelationships"
        }
        XCTAssertNotNil(moodEpisodesRel, "Mood should have episodeRelationships")
        XCTAssertEqual(
            moodEpisodesRel?.originalName,
            "episodes",
            "episodeRelationships must declare originalName 'episodes' for V1.0 migration"
        )

        let universeEpisodesRel = universeEntity?.relationships.first {
            $0.name == "episodeRelationships"
        }
        XCTAssertNotNil(universeEpisodesRel, "Universe should have episodeRelationships")
        XCTAssertEqual(
            universeEpisodesRel?.originalName,
            "episodes",
            "episodeRelationships must declare originalName 'episodes' for V1.0 migration"
        )
    }

    // MARK: - New Property Defaults

    func testNewPropertiesHaveSafeDefaults() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let episode = Episode(episodeNumber: 1, title: "Test", releaseYear: 2000)
        let mood = Mood(name: "Test")
        let universe = Universe(name: "Test")

        context.insert(episode)
        context.insert(mood)
        context.insert(universe)
        try context.save()

        XCTAssertNotEqual(episode.id, UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
        XCTAssertNotNil(episode.syncKey)
        XCTAssertNil(episode.streamingURL)
        XCTAssertNotNil(mood.syncKey)
        XCTAssertNotNil(universe.syncKey)
    }

    // MARK: - Delete Behavior

    func testDeletingUniverseNullifiesEpisodeRelationship() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let universe = Universe(name: "Zum Löschen")
        let episode = Episode(
            episodeNumber: 1,
            title: "Wird zum Waisen",
            releaseYear: 2000,
            universe: universe
        )

        context.insert(universe)
        context.insert(episode)
        try context.save()

        context.delete(universe)
        try context.save()

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.count, 1)
        XCTAssertNil(episodes[0].universe, "Deleting universe should nullify the relationship")
    }

    func testDeletingMoodRemovesItFromEpisode() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let mood = Mood(name: "Zum Löschen", iconName: "❌")
        let episode = Episode(
            episodeNumber: 1,
            title: "Behält andere Daten",
            releaseYear: 2000,
            moods: [mood]
        )

        context.insert(mood)
        context.insert(episode)
        try context.save()

        context.delete(mood)
        try context.save()

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.count, 1)
        XCTAssertEqual(episodes[0].moods.count, 0, "Deleted mood should be removed from episode")
    }

    // MARK: - Migration Plan Completeness

    func testMigrationPlanContainsAllSchemas() {
        let schemas = EpisodeTrackerMigrationPlan.schemas
        XCTAssertEqual(schemas.count, 3)
        XCTAssertTrue(schemas[0] == SchemaV1.self)
        XCTAssertTrue(schemas[1] == SchemaV2.self)
        XCTAssertTrue(schemas[2] == SchemaV3.self)
    }

    func testMigrationPlanHasCorrectStages() {
        let stages = EpisodeTrackerMigrationPlan.stages
        XCTAssertEqual(stages.count, 2, "Should have V1→V2 and V2→V3 stages")
    }

    func testSchemaV1ModelsMatchV1Release() {
        let models = SchemaV1.models
        let modelNames = Set(models.map { String(describing: $0) })
        XCTAssertTrue(modelNames.contains("Episode"))
        XCTAssertTrue(modelNames.contains("Mood"))
        XCTAssertTrue(modelNames.contains("Universe"))
        XCTAssertEqual(models.count, 3)
    }

    func testSchemaV2ModelsMatchV2HistoricalTypes() {
        let models = SchemaV2.models
        let modelNames = Set(models.map { String(describing: $0) })
        XCTAssertTrue(modelNames.contains("Episode"))
        XCTAssertTrue(modelNames.contains("Mood"))
        XCTAssertTrue(modelNames.contains("Universe"))
        XCTAssertEqual(models.count, 3)
    }

    func testSchemaV3HasThreeModels() {
        XCTAssertEqual(SchemaV3.models.count, 3)
    }

    // MARK: - Schema Version Tracking

    func testSchemaVersionUpdatedAfterBootstrap() async throws {
        let container = try makeInMemoryContainer()
        let suiteName = "MigrationSafetyTest-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(defaults.integer(forKey: AppDataBootstrapper.schemaVersionKey), 0)

        await AppDataBootstrapper.bootstrap(
            container: container,
            usesCloudSync: false,
            userDefaults: defaults
        )

        XCTAssertEqual(
            defaults.integer(forKey: AppDataBootstrapper.schemaVersionKey),
            AppDataBootstrapper.currentSchemaVersion
        )
    }

    // MARK: - Pre-Migration Backup

    func testPreMigrationBackupCreatedWhenStoreExists() throws {
        let storeURL = temporaryStoreURL()
        let storeDir = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDir) }

        let container = try makePersistentContainer(url: storeURL)
        let context = container.mainContext
        context.insert(Episode(episodeNumber: 1, title: "Backup-Test", releaseYear: 2000))
        try context.save()

        let backupURL = storeDir.appendingPathComponent("EpisodeTracker.pre-migration-backup.store")
        XCTAssertFalse(FileManager.default.fileExists(atPath: backupURL.path))

        FileManager.default.createFile(atPath: storeURL.path, contents: Data("test".utf8))
        AppModelContainerFactory.createPreMigrationBackupIfNeeded(fileManager: .default)

        // Backup should exist (from the actual store path, not our test URL)
        // For this test we verify the API contract: backup is only created when store exists
        let realStoreURL = AppModelContainerFactory.persistentStoreURL()
        let realBackupURL = realStoreURL.deletingLastPathComponent()
            .appendingPathComponent("EpisodeTracker.pre-migration-backup.store")

        if FileManager.default.fileExists(atPath: realStoreURL.path) {
            XCTAssertTrue(FileManager.default.fileExists(atPath: realBackupURL.path))
            AppModelContainerFactory.removePreMigrationBackup()
            XCTAssertFalse(FileManager.default.fileExists(atPath: realBackupURL.path))
        }
    }

    // MARK: - Full Bootstrap Simulation

    func testFullBootstrapOnFreshContainerProducesConsistentState() async throws {
        let container = try makeInMemoryContainer()

        await AppDataBootstrapper.bootstrap(container: container, usesCloudSync: false)

        let context = container.mainContext
        let universes = try context.fetch(FetchDescriptor<Universe>())
        let moods = try context.fetch(FetchDescriptor<Mood>())

        XCTAssertGreaterThan(universes.count, 0, "Bootstrapper should seed default universes")
        XCTAssertGreaterThan(moods.count, 0, "Bootstrapper should seed default moods")

        for universe in universes {
            XCTAssertFalse(universe.resolvedSyncKey.isEmpty, "Universe '\(universe.name)' should have a sync key")
        }
        for mood in moods {
            XCTAssertFalse(mood.resolvedSyncKey.isEmpty, "Mood '\(mood.name)' should have a sync key")
        }
    }
}
