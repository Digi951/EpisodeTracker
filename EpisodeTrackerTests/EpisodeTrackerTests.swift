import XCTest
import SwiftData
import SwiftUI
@testable import EpisodeTracker

@MainActor
final class EpisodeTrackerTests: XCTestCase {
    private let parser = CatalogParser()

    private func makeCloudKitContainer(schema: Schema) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            UUID().uuidString,
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .automatic
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: AppModelContainerFactory.schema(),
            configurations: ModelConfiguration(
                schema: AppModelContainerFactory.schema(),
                isStoredInMemoryOnly: true
            )
        )
    }

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

    func testFallbackManagedSourcesUseExpectedCatalogURLs() {
        let sources = CatalogSourceRegistry.fallbackManagedSources

        XCTAssertEqual(
            sources.first(where: { $0.name == "Die drei !!!" })?.url.absoluteString,
            "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/de/the_three_exclamation_marks.json"
        )
        XCTAssertEqual(
            sources.first(where: { $0.name == "Die drei ???" })?.id,
            "die-drei-fragezeichen"
        )
        XCTAssertEqual(
            sources.first(where: { $0.name == "Die drei !!!" })?.id,
            "die-drei-ausrufezeichen"
        )
    }

    func testManagedCatalogSourcesAreDeduplicatedByIDAndName() {
        let url = URL(string: "https://example.com/catalog.json")!
        let sources = [
            ManagedCatalogSource(id: "die-drei-fragezeichen", name: "Die drei ???", url: url),
            ManagedCatalogSource(id: "DIE-DREI-FRAGEZEICHEN", name: "Die drei ??? Kopie", url: url),
            ManagedCatalogSource(id: "alternate-id", name: " die drei ??? ", url: url),
            ManagedCatalogSource(id: "tkkg", name: "TKKG", url: url)
        ]

        let deduplicated = CatalogSourceRegistry.deduplicatedManagedSources(sources)

        XCTAssertEqual(deduplicated.map(\.id), ["die-drei-fragezeichen", "tkkg"])
    }

    func testContainerFactoryUsesPreviewModeForPreviewEnvironment() {
        let mode = AppModelContainerFactory.resolveMode(
            environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"]
        )

        XCTAssertEqual(mode, .previewInMemory)
    }

    func testContainerFactoryDefaultsToPersistentMode() {
        let mode = AppModelContainerFactory.resolveMode(environment: [:])

        XCTAssertEqual(mode, .localPersistent)
    }

    func testContainerFactoryBuildsContainerSetForLocalMode() {
        let containerSet = AppModelContainerFactory.makeSharedContainerSet(environment: [:])

        XCTAssertEqual(containerSet.runtimeMode, .localPersistent)
        XCTAssertNotNil(containerSet.localPersistent)
        XCTAssertNil(containerSet.cloudPersistent)
    }

    func testContainerFactoryBuildsContainerSetForPreviewMode() {
        let containerSet = AppModelContainerFactory.makeSharedContainerSet(
            environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"]
        )

        XCTAssertEqual(containerSet.runtimeMode, .previewInMemory)
        XCTAssertNil(containerSet.localPersistent)
        XCTAssertNil(containerSet.cloudPersistent)
    }

    func testContainerFactoryKeepsCloudModeDisabledWithoutGuard() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(true, forKey: AppModelContainerFactory.cloudSyncPreferenceKey)

        let mode = AppModelContainerFactory.resolveMode(
            environment: [:],
            userDefaults: defaults
        )

        XCTAssertEqual(mode, .localPersistent)
    }

    func testContainerFactoryKeepsCloudModeDisabledWithoutUserPreference() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let mode = AppModelContainerFactory.resolveMode(
            environment: [AppModelContainerFactory.cloudSyncGuardEnvironmentKey: "1"],
            userDefaults: defaults
        )

        XCTAssertEqual(mode, .localPersistent)
    }

    func testContainerFactoryUsesCloudModeWhenPreferenceAndGuardAreEnabled() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(true, forKey: AppModelContainerFactory.cloudSyncPreferenceKey)

        let mode = AppModelContainerFactory.resolveMode(
            environment: [AppModelContainerFactory.cloudSyncGuardEnvironmentKey: "1"],
            userDefaults: defaults
        )

        XCTAssertEqual(mode, .cloudPersistent(containerIdentifier: AppModelContainerFactory.cloudContainerIdentifier))
    }

    func testContainerFactoryParsesCloudGuardEnvironmentValues() {
        XCTAssertTrue(
            AppModelContainerFactory.isCloudSyncGuardEnabled(
                environment: [AppModelContainerFactory.cloudSyncGuardEnvironmentKey: "true"]
            )
        )
        XCTAssertTrue(
            AppModelContainerFactory.isCloudSyncGuardEnabled(
                environment: [AppModelContainerFactory.cloudSyncGuardEnvironmentKey: "YES"]
            )
        )
        XCTAssertFalse(
            AppModelContainerFactory.isCloudSyncGuardEnabled(
                environment: [AppModelContainerFactory.cloudSyncGuardEnvironmentKey: "0"]
            )
        )
    }

    func testContainerModeProvidesDebugTitles() {
        XCTAssertEqual(AppModelContainerMode.previewInMemory.debugTitle, "Preview (In-Memory)")
        XCTAssertEqual(AppModelContainerMode.localPersistent.debugTitle, "Lokal")
        XCTAssertEqual(
            AppModelContainerMode.cloudPersistent(containerIdentifier: "iCloud.example").debugTitle,
            "Cloud PoC"
        )
    }

    func testContainerFactoryBuildsExpectedPersistentStoreURL() {
        let fileManager = FileManager.default
        let storeURL = AppModelContainerFactory.persistentStoreURL(fileManager: fileManager)

        XCTAssertEqual(storeURL.lastPathComponent, "EpisodeTracker.store")
        XCTAssertEqual(storeURL.deletingLastPathComponent().lastPathComponent, "EpisodeTracker")
    }

    func testSchemaSupportsCloudKitContainerCreation() throws {
        let schema = Schema([
            Episode.self,
            Mood.self,
            Universe.self,
        ])

        XCTAssertNoThrow(try makeCloudKitContainer(schema: schema))
    }

    @MainActor
    func testUniverseAndMoodDefaultToDeterministicSyncKeys() {
        let universe = Universe(name: "Die drei ???")
        let mood = Mood(name: "Gruselig", iconName: "😱")

        XCTAssertEqual(universe.resolvedSyncKey, "universe:die drei ???")
        XCTAssertEqual(mood.resolvedSyncKey, "mood:gruselig")
    }

    @MainActor
    func testEpisodeSyncKeyUsesUniverseSyncKeyAndNumber() {
        let universe = Universe(name: "Die drei ???")
        let episode = Episode(
            episodeNumber: 7,
            title: "und der unheimliche Drache",
            releaseYear: 1979,
            universe: universe
        )

        XCTAssertEqual(episode.resolvedSyncKey, "episode:universe:die drei ???#7")
    }

    @MainActor
    func testEpisodeRefreshesSyncKeyAfterUniverseAssignment() {
        let episode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            universe: nil
        )
        let originalSyncKey = episode.resolvedSyncKey
        let universe = Universe(name: "Die drei ???")

        episode.universe = universe
        episode.refreshSyncKeyIfPossible()

        XCTAssertNotEqual(episode.resolvedSyncKey, originalSyncKey)
        XCTAssertEqual(episode.resolvedSyncKey, "episode:universe:die drei ???#1")
    }

    func testLocalLibrarySnapshotCapturesResolvedSyncKeysAndRelationships() throws {
        let container = try ModelContainer(
            for: AppModelContainerFactory.schema(),
            configurations: ModelConfiguration(schema: AppModelContainerFactory.schema(), isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let universe = Universe(name: "Die drei ???")
        let mood = Mood(name: "Spannend", iconName: "⚡")
        let episode = Episode(
            episodeNumber: 42,
            title: "und der weisse Leopard",
            releaseYear: 1987,
            personalNote: "Merken",
            isListened: true,
            rating: 5,
            listenCount: 3,
            lastListenedAt: Date(timeIntervalSince1970: 1_000),
            universe: universe,
            moods: [mood]
        )

        context.insert(universe)
        context.insert(mood)
        context.insert(episode)

        let snapshot = LocalLibrarySnapshot.capture(context: context)

        XCTAssertEqual(snapshot.universes, [
            .init(syncKey: "universe:die drei ???", name: "Die drei ???")
        ])
        XCTAssertEqual(snapshot.moods, [
            .init(syncKey: "mood:spannend", name: "Spannend", iconName: "⚡")
        ])
        XCTAssertEqual(snapshot.episodes.count, 1)
        XCTAssertEqual(snapshot.episodes[0].syncKey, "episode:universe:die drei ???#42")
        XCTAssertEqual(snapshot.episodes[0].universeSyncKey, "universe:die drei ???")
        XCTAssertEqual(snapshot.episodes[0].moodSyncKeys, ["mood:spannend"])
    }

    func testSyncMigrationValidatorFindsDuplicateEpisodeKeysAndMissingReferences() {
        let snapshot = LocalLibrarySnapshot(
            universes: [],
            moods: [],
            episodes: [
                .init(
                    syncKey: "episode:universe:die drei ???#1",
                    episodeNumber: 1,
                    title: "A",
                    releaseYear: 1979,
                    personalNote: nil,
                    isListened: false,
                    rating: nil,
                    listenCount: 0,
                    lastListenedAt: nil,
                    universeSyncKey: "universe:die drei ???",
                    moodSyncKeys: ["mood:spannend"]
                ),
                .init(
                    syncKey: "episode:universe:die drei ???#1",
                    episodeNumber: 1,
                    title: "B",
                    releaseYear: 1979,
                    personalNote: nil,
                    isListened: false,
                    rating: nil,
                    listenCount: 0,
                    lastListenedAt: nil,
                    universeSyncKey: nil,
                    moodSyncKeys: []
                )
            ]
        )

        let issues = SyncMigrationValidator.validate(snapshot: snapshot)

        XCTAssertEqual(
            Set(issues),
            Set([
                .duplicateEpisodeSyncKey("episode:universe:die drei ???#1"),
                .missingUniverseReference(
                    episodeSyncKey: "episode:universe:die drei ???#1",
                    universeSyncKey: "universe:die drei ???"
                ),
                .missingMoodReference(
                    episodeSyncKey: "episode:universe:die drei ???#1",
                    moodSyncKey: "mood:spannend"
                ),
            ])
        )
    }

    func testSyncMigrationEpisodeMergerUsesConservativeListenCountAndLatestDate() {
        let local = LocalLibrarySnapshot.EpisodeRecord(
            syncKey: "episode:universe:die drei ???#1",
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            personalNote: "Kurze Notiz",
            isListened: false,
            rating: 4,
            listenCount: 2,
            lastListenedAt: Date(timeIntervalSince1970: 1_000),
            universeSyncKey: "universe:die drei ???",
            moodSyncKeys: ["mood:spannend"]
        )
        let cloud = LocalLibrarySnapshot.EpisodeRecord(
            syncKey: "episode:universe:die drei ???#1",
            episodeNumber: 1,
            title: "",
            releaseYear: 0,
            personalNote: "Das ist die deutlich laengere Notiz",
            isListened: true,
            rating: 5,
            listenCount: 5,
            lastListenedAt: Date(timeIntervalSince1970: 2_000),
            universeSyncKey: "universe:die drei ???",
            moodSyncKeys: ["mood:gruselig"]
        )

        let merged = SyncMigrationEpisodeMerger.merge(local: local, cloud: cloud)

        XCTAssertEqual(merged.title, "und der Super-Papagei")
        XCTAssertEqual(merged.releaseYear, 1979)
        XCTAssertEqual(merged.personalNote, "Das ist die deutlich laengere Notiz")
        XCTAssertTrue(merged.isListened)
        XCTAssertEqual(merged.rating, 4)
        XCTAssertEqual(merged.listenCount, 5)
        XCTAssertEqual(merged.lastListenedAt, Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(merged.moodSyncKeys, ["mood:gruselig", "mood:spannend"])
    }

    func testSyncMigrationStateStorePersistsCompletionMarker() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        XCTAssertFalse(
            SyncMigrationStateStore.hasCompletedLocalToCloudMigration(userDefaults: defaults)
        )

        SyncMigrationStateStore.markLocalToCloudMigrationCompleted(userDefaults: defaults)

        XCTAssertTrue(
            SyncMigrationStateStore.hasCompletedLocalToCloudMigration(userDefaults: defaults)
        )
    }

    func testSyncMigrationCoordinatorImportsSnapshotIntoEmptyTarget() throws {
        let sourceContainer = try makeInMemoryContainer()
        let sourceContext = sourceContainer.mainContext

        let universe = Universe(name: "Die drei ???")
        let mood = Mood(name: "Spannend", iconName: "⚡")
        let episode = Episode(
            episodeNumber: 7,
            title: "und der unheimliche Drache",
            releaseYear: 1979,
            personalNote: "Merken",
            isListened: true,
            rating: 4,
            listenCount: 2,
            lastListenedAt: Date(timeIntervalSince1970: 1_000),
            universe: universe,
            moods: [mood]
        )
        sourceContext.insert(universe)
        sourceContext.insert(mood)
        sourceContext.insert(episode)

        let snapshot = LocalLibrarySnapshot.capture(context: sourceContext)

        let targetContainer = try makeInMemoryContainer()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let report = try SyncMigrationCoordinator.migrate(
            snapshot: snapshot,
            into: targetContainer.mainContext,
            userDefaults: defaults
        )

        XCTAssertEqual(report.migratedUniverseCount, 1)
        XCTAssertEqual(report.migratedMoodCount, 1)
        XCTAssertEqual(report.migratedEpisodeCount, 1)
        XCTAssertTrue(report.validationIssues.isEmpty)
        XCTAssertTrue(report.markedCompleted)
        XCTAssertTrue(SyncMigrationStateStore.hasCompletedLocalToCloudMigration(userDefaults: defaults))

        let importedSnapshot = LocalLibrarySnapshot.capture(context: targetContainer.mainContext)
        XCTAssertEqual(importedSnapshot, snapshot)
    }

    func testSyncMigrationCoordinatorMergesIntoExistingTargetConservatively() throws {
        let sourceSnapshot = LocalLibrarySnapshot(
            universes: [
                .init(syncKey: "universe:die drei ???", name: "Die drei ???")
            ],
            moods: [
                .init(syncKey: "mood:spannend", name: "Spannend", iconName: "⚡")
            ],
            episodes: [
                .init(
                    syncKey: "episode:universe:die drei ???#1",
                    episodeNumber: 1,
                    title: "und der Super-Papagei",
                    releaseYear: 1979,
                    personalNote: "Kurz",
                    isListened: false,
                    rating: 4,
                    listenCount: 2,
                    lastListenedAt: Date(timeIntervalSince1970: 1_000),
                    universeSyncKey: "universe:die drei ???",
                    moodSyncKeys: ["mood:spannend"]
                )
            ]
        )

        let targetContainer = try makeInMemoryContainer()
        let targetContext = targetContainer.mainContext

        let existingUniverse = Universe(name: "Die drei ???")
        let existingMood = Mood(name: "Gruselig", iconName: "😱")
        let existingEpisode = Episode(
            episodeNumber: 1,
            title: "",
            releaseYear: 0,
            syncKey: "episode:universe:die drei ???#1",
            personalNote: "Das ist die deutlich laengere Notiz",
            isListened: true,
            rating: 5,
            listenCount: 5,
            lastListenedAt: Date(timeIntervalSince1970: 2_000),
            universe: existingUniverse,
            moods: [existingMood]
        )

        targetContext.insert(existingUniverse)
        targetContext.insert(existingMood)
        targetContext.insert(existingEpisode)

        let report = try SyncMigrationCoordinator.migrate(
            snapshot: sourceSnapshot,
            into: targetContext,
            userDefaults: UserDefaults(suiteName: "\(#function)-defaults")!
        )

        XCTAssertTrue(report.validationIssues.isEmpty)

        let mergedSnapshot = LocalLibrarySnapshot.capture(context: targetContext)
        XCTAssertEqual(mergedSnapshot.universes.count, 1)
        XCTAssertEqual(mergedSnapshot.moods.count, 2)
        XCTAssertEqual(mergedSnapshot.episodes.count, 1)
        XCTAssertEqual(mergedSnapshot.episodes[0].title, "und der Super-Papagei")
        XCTAssertEqual(mergedSnapshot.episodes[0].releaseYear, 1979)
        XCTAssertEqual(mergedSnapshot.episodes[0].personalNote, "Das ist die deutlich laengere Notiz")
        XCTAssertTrue(mergedSnapshot.episodes[0].isListened)
        XCTAssertEqual(mergedSnapshot.episodes[0].rating, 4)
        XCTAssertEqual(mergedSnapshot.episodes[0].listenCount, 5)
        XCTAssertEqual(mergedSnapshot.episodes[0].lastListenedAt, Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(mergedSnapshot.episodes[0].moodSyncKeys, ["mood:gruselig", "mood:spannend"])
    }

    func testSyncMigrationCoordinatorDoesNotMarkCompletedWhenValidationIssuesRemain() throws {
        let sourceSnapshot = LocalLibrarySnapshot(
            universes: [],
            moods: [],
            episodes: [
                .init(
                    syncKey: "episode:universe:bibi blocksberg#1",
                    episodeNumber: 1,
                    title: "Hexen gibt es doch",
                    releaseYear: 1980,
                    personalNote: nil,
                    isListened: false,
                    rating: nil,
                    listenCount: 0,
                    lastListenedAt: nil,
                    universeSyncKey: "universe:bibi blocksberg",
                    moodSyncKeys: []
                )
            ]
        )

        let targetContainer = try makeInMemoryContainer()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let report = try SyncMigrationCoordinator.migrate(
            snapshot: sourceSnapshot,
            into: targetContainer.mainContext,
            userDefaults: defaults
        )

        XCTAssertFalse(report.validationIssues.isEmpty)
        XCTAssertFalse(report.markedCompleted)
        XCTAssertFalse(SyncMigrationStateStore.hasCompletedLocalToCloudMigration(userDefaults: defaults))
    }

    func testSyncMigrationReadinessRequiresContainersDataAndCleanSnapshot() throws {
        let localContainer = try makeInMemoryContainer()
        let localContext = localContainer.mainContext
        let universe = Universe(name: "Die drei ???")
        let mood = Mood(name: "Spannend", iconName: "⚡")
        let episode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            universe: universe,
            moods: [mood]
        )
        localContext.insert(universe)
        localContext.insert(mood)
        localContext.insert(episode)

        let cloudContainer = try makeInMemoryContainer()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let readiness = SyncMigrationReadinessEvaluator.evaluate(
            containerSet: AppModelContainerSet(
                primary: localContainer,
                localPersistent: localContainer,
                cloudPersistent: cloudContainer,
                runtimeMode: .localPersistent
            ),
            userDefaults: defaults
        )

        XCTAssertFalse(readiness.hasCompletedMigration)
        XCTAssertTrue(readiness.hasLocalPersistentContainer)
        XCTAssertTrue(readiness.hasCloudPersistentContainer)
        XCTAssertEqual(readiness.localEpisodeCount, 1)
        XCTAssertTrue(readiness.localValidationIssues.isEmpty)
        XCTAssertTrue(readiness.canAttemptMigration)
    }

    func testSyncMigrationReadinessBlocksWhenAlreadyCompletedOrNoData() throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        SyncMigrationStateStore.markLocalToCloudMigrationCompleted(userDefaults: defaults)

        let container = try makeInMemoryContainer()
        let readiness = SyncMigrationReadinessEvaluator.evaluate(
            containerSet: AppModelContainerSet(
                primary: container,
                localPersistent: container,
                cloudPersistent: nil,
                runtimeMode: .localPersistent
            ),
            userDefaults: defaults
        )

        XCTAssertTrue(readiness.hasCompletedMigration)
        XCTAssertFalse(readiness.hasCloudPersistentContainer)
        XCTAssertFalse(readiness.hasLocalData)
        XCTAssertFalse(readiness.canAttemptMigration)
    }

    @MainActor
    func testBootstrapAutomaticallyMigratesLocalDataIntoCloudContainer() async throws {
        let localContainer = try makeInMemoryContainer()
        let localContext = localContainer.mainContext

        let universe = Universe(name: "Bibi Blocksberg")
        let mood = Mood(name: "Witzig", iconName: "😄")
        let episode = Episode(
            episodeNumber: 1,
            title: "Hexen gibt es doch",
            releaseYear: 1980,
            universe: universe,
            moods: [mood]
        )

        localContext.insert(universe)
        localContext.insert(mood)
        localContext.insert(episode)

        let cloudContainer = try makeInMemoryContainer()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        await AppDataBootstrapper.bootstrap(
            containerSet: AppModelContainerSet(
                primary: cloudContainer,
                localPersistent: localContainer,
                cloudPersistent: cloudContainer,
                runtimeMode: .cloudPersistent(containerIdentifier: "iCloud.com.Digi.EpisodeTracker")
            ),
            userDefaults: defaults
        )

        let cloudSnapshot = LocalLibrarySnapshot.capture(context: cloudContainer.mainContext)
        let migratedEpisode = try XCTUnwrap(
            cloudSnapshot.episodes.first(where: { $0.title == "Hexen gibt es doch" })
        )

        XCTAssertEqual(cloudSnapshot.episodes.count, 1)
        XCTAssertTrue(cloudSnapshot.universes.contains(where: { $0.name == "Bibi Blocksberg" }))
        XCTAssertEqual(migratedEpisode.syncKey, "episode:universe:bibi blocksberg#1")
        XCTAssertTrue(SyncMigrationStateStore.hasCompletedLocalToCloudMigration(userDefaults: defaults))
    }

    @MainActor
    func testBootstrapMigratesOrphanEpisodeIntoDefaultUniverseForCloud() async throws {
        let localContainer = try makeInMemoryContainer()
        let localContext = localContainer.mainContext

        let orphanEpisode = Episode(
            episodeNumber: 5,
            title: "Ohne Sammlung",
            releaseYear: 1995,
            universe: nil
        )

        localContext.insert(orphanEpisode)

        let cloudContainer = try makeInMemoryContainer()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        await AppDataBootstrapper.bootstrap(
            containerSet: AppModelContainerSet(
                primary: cloudContainer,
                localPersistent: localContainer,
                cloudPersistent: cloudContainer,
                runtimeMode: .cloudPersistent(containerIdentifier: "iCloud.com.Digi.EpisodeTracker")
            ),
            userDefaults: defaults
        )

        let cloudSnapshot = LocalLibrarySnapshot.capture(context: cloudContainer.mainContext)
        let migratedEpisode = try XCTUnwrap(
            cloudSnapshot.episodes.first(where: { $0.title == "Ohne Sammlung" })
        )

        XCTAssertEqual(migratedEpisode.universeSyncKey, "universe:allgemein")
        XCTAssertEqual(migratedEpisode.syncKey, "episode:universe:allgemein#5")
        XCTAssertTrue(cloudSnapshot.universes.contains(where: { $0.syncKey == "universe:allgemein" }))
    }

    @MainActor
    func testBootstrapAutomaticallyMergesLocalDataIntoExistingCloudEpisode() async throws {
        let localContainer = try makeInMemoryContainer()
        let localContext = localContainer.mainContext

        let localUniverse = Universe(name: "Die drei ???")
        let localMood = Mood(name: "Spannend", iconName: "⚡")
        let localEpisode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            personalNote: "Kurz",
            isListened: false,
            rating: 4,
            listenCount: 2,
            lastListenedAt: Date(timeIntervalSince1970: 1_000),
            universe: localUniverse,
            moods: [localMood]
        )

        localContext.insert(localUniverse)
        localContext.insert(localMood)
        localContext.insert(localEpisode)

        let cloudContainer = try makeInMemoryContainer()
        let cloudContext = cloudContainer.mainContext

        let cloudUniverse = Universe(name: "Die drei ???")
        let cloudMood = Mood(name: "Gruselig", iconName: "😱")
        let cloudEpisode = Episode(
            episodeNumber: 1,
            title: "",
            releaseYear: 0,
            syncKey: "episode:universe:die drei ???#1",
            personalNote: "Das ist die deutlich laengere Notiz",
            isListened: true,
            rating: 5,
            listenCount: 5,
            lastListenedAt: Date(timeIntervalSince1970: 2_000),
            universe: cloudUniverse,
            moods: [cloudMood]
        )

        cloudContext.insert(cloudUniverse)
        cloudContext.insert(cloudMood)
        cloudContext.insert(cloudEpisode)

        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        await AppDataBootstrapper.bootstrap(
            containerSet: AppModelContainerSet(
                primary: cloudContainer,
                localPersistent: localContainer,
                cloudPersistent: cloudContainer,
                runtimeMode: .cloudPersistent(containerIdentifier: "iCloud.com.Digi.EpisodeTracker")
            ),
            userDefaults: defaults
        )

        let cloudSnapshot = LocalLibrarySnapshot.capture(context: cloudContainer.mainContext)
        let mergedEpisode = try XCTUnwrap(
            cloudSnapshot.episodes.first(where: { $0.syncKey == "episode:universe:die drei ???#1" })
        )

        XCTAssertEqual(cloudSnapshot.episodes.count, 1)
        XCTAssertEqual(mergedEpisode.title, "und der Super-Papagei")
        XCTAssertEqual(mergedEpisode.personalNote, "Das ist die deutlich laengere Notiz")
        XCTAssertTrue(mergedEpisode.isListened)
        XCTAssertEqual(mergedEpisode.rating, 4)
        XCTAssertEqual(mergedEpisode.listenCount, 5)
        XCTAssertEqual(mergedEpisode.lastListenedAt, Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(mergedEpisode.moodSyncKeys, ["mood:gruselig", "mood:spannend"])
    }

    @MainActor
    func testBootstrapDoesNotRepeatAutomaticCloudMigrationAfterCompletionMarker() async throws {
        let localContainer = try makeInMemoryContainer()
        let localContext = localContainer.mainContext

        let universe = Universe(name: "Bibi Blocksberg")
        let episode = Episode(
            episodeNumber: 3,
            title: "Die Mathekrankheit",
            releaseYear: 1981,
            universe: universe
        )

        localContext.insert(universe)
        localContext.insert(episode)

        let cloudContainer = try makeInMemoryContainer()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        SyncMigrationStateStore.markLocalToCloudMigrationCompleted(userDefaults: defaults)

        await AppDataBootstrapper.bootstrap(
            containerSet: AppModelContainerSet(
                primary: cloudContainer,
                localPersistent: localContainer,
                cloudPersistent: cloudContainer,
                runtimeMode: .cloudPersistent(containerIdentifier: "iCloud.com.Digi.EpisodeTracker")
            ),
            userDefaults: defaults
        )

        let cloudSnapshot = LocalLibrarySnapshot.capture(context: cloudContainer.mainContext)

        XCTAssertFalse(cloudSnapshot.episodes.contains(where: { $0.title == "Die Mathekrankheit" }))
        XCTAssertTrue(SyncMigrationStateStore.hasCompletedLocalToCloudMigration(userDefaults: defaults))
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

    func testMultipleCatalogEpisodesGroupEarlyForOverviewProgress() {
        let firstUniverse = Universe(name: "Die drei ???")
        let secondUniverse = Universe(name: "TKKG")
        let episodes = [
            Episode(episodeNumber: 1, title: "und der Super-Papagei", releaseYear: 1979, universe: firstUniverse),
            Episode(episodeNumber: 1, title: "Die Jagd nach den Millionendieben", releaseYear: 1981, universe: secondUniverse)
        ]

        let groups = EpisodeListOrganizer.groups(
            for: episodes,
            sortOrder: .number,
            filterUniverse: nil,
            universeCount: 2
        )

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups.map(\.title), ["Die drei ???", "TKKG"])
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

    func testMoodFilterMatchesEquivalentMoodByName() {
        let assignedMood = Mood(name: "Gruselig", iconName: "😱")
        let selectedMood = Mood(name: "Gruselig", iconName: "😱")
        let episodes = [
            Episode(episodeNumber: 1, title: "A", releaseYear: 1980, moods: [assignedMood]),
            Episode(episodeNumber: 2, title: "B", releaseYear: 1981)
        ]

        let result = EpisodeListOrganizer.filteredAndSortedEpisodes(
            episodes: episodes,
            searchText: "",
            filterUniverse: nil,
            filterMood: selectedMood,
            statusFilter: .all,
            sortOrder: .number
        )

        XCTAssertEqual(result.map(\.title), ["A"])
    }

    func testGroupSummaryCountsListenedAndOpenEpisodes() {
        let group = EpisodeListGroup(
            id: "test",
            title: "Test",
            episodes: [
                Episode(episodeNumber: 1, title: "Gehört", releaseYear: 1980, isListened: true),
                Episode(episodeNumber: 2, title: "Offen", releaseYear: 1981, isListened: false),
                Episode(episodeNumber: 3, title: "Auch offen", releaseYear: 1982, isListened: false)
            ],
            progressTotalOverride: nil
        )

        XCTAssertEqual(group.listenedCount, 1)
        XCTAssertEqual(group.openCount, 2)
        XCTAssertEqual(group.summary, "1 von 3 gehört · 2 offen")
        XCTAssertEqual(group.progress, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testUniverseGroupsCanUseCatalogTotalForProgress() {
        let universe = Universe(name: "Die drei ???")
        let episodes = [
            Episode(episodeNumber: 1, title: "A", releaseYear: 1980, isListened: true, universe: universe),
            Episode(episodeNumber: 2, title: "B", releaseYear: 1981, isListened: true, universe: universe),
            Episode(episodeNumber: 3, title: "C", releaseYear: 1982, isListened: false, universe: universe)
        ]

        let groups = EpisodeListOrganizer.groups(
            for: episodes,
            sortOrder: .number,
            filterUniverse: nil,
            universeCount: 2,
            catalogTotalsByUniverse: ["die drei ???": 7],
            preferCatalogTotals: true
        )

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].summary, "2 von 7 gehört · 5 offen")
        XCTAssertEqual(groups[0].progress, 2.0 / 7.0, accuracy: 0.0001)
    }

    func testAvailableMoodsAndMoodEpisodesMatchByNameWhenInstancesDiffer() {
        let libraryMood = Mood(name: "Gruselig", iconName: "😱")
        let pickerMood = Mood(name: "Gruselig", iconName: "😱")
        let episodes = [
            Episode(episodeNumber: 1, title: "A", releaseYear: 1980, moods: [libraryMood]),
            Episode(episodeNumber: 2, title: "B", releaseYear: 1981, isListened: true, moods: [libraryMood])
        ]

        let available = SmartListDefinition.availableMoods(
            from: episodes,
            filter: .all,
            allMoods: [pickerMood]
        )
        let matching = SmartListDefinition.episodesForMood(
            pickerMood,
            from: episodes,
            filter: .all,
            count: 10
        )

        XCTAssertEqual(available.count, 1)
        XCTAssertEqual(available.first?.count, 2)
        XCTAssertEqual(matching.count, 2)
    }

    func testCollapseStoreRoundTripsScopedState() {
        let state: [String: Set<String>] = [
            "Nummer|__all__|Alle|multi": ["universe:Die drei ???", "universe:TKKG"],
            "Bewertung|__all__|Alle|multi": ["rating:5"]
        ]

        let encoded = EpisodeGroupCollapseStore.encode(state)
        let decoded = EpisodeGroupCollapseStore.decode(encoded)

        XCTAssertEqual(decoded["Nummer|__all__|Alle|multi"] ?? [], ["universe:Die drei ???", "universe:TKKG"])
        XCTAssertEqual(decoded["Bewertung|__all__|Alle|multi"] ?? [], ["rating:5"])
    }

    func testCollapseStoreScopeKeySeparatesDifferentContexts() {
        let byNumber = EpisodeGroupCollapseStore.scopeKey(
            sortOrder: "Nummer",
            filterUniverseName: nil,
            statusFilter: .all,
            isMultiUniverse: true
        )
        let byRating = EpisodeGroupCollapseStore.scopeKey(
            sortOrder: "Bewertung",
            filterUniverseName: nil,
            statusFilter: .all,
            isMultiUniverse: true
        )

        XCTAssertNotEqual(byNumber, byRating)
    }

    func testCollapseStoreCanToggleGroupInScopedRawValue() {
        let scopeKey = EpisodeGroupCollapseStore.scopeKey(
            sortOrder: "Nummer",
            filterUniverseName: nil,
            statusFilter: .all,
            isMultiUniverse: true
        )

        let encoded = EpisodeGroupCollapseStore.toggle(
            groupID: "universe:Die drei ???",
            in: "",
            scopeKey: scopeKey
        )
        let collapsed = EpisodeGroupCollapseStore.collapsedIDs(from: encoded, scopeKey: scopeKey)

        XCTAssertEqual(collapsed, ["universe:Die drei ???"])
    }

    func testEpisodeDeleteStateBuildsSingleEpisodeConfirmation() {
        var deleteState = EpisodeDeleteState()
        let episode = Episode(episodeNumber: 1, title: "und der Super-Papagei", releaseYear: 1979)

        deleteState.request(episode)

        XCTAssertTrue(deleteState.isActive)
        XCTAssertEqual(deleteState.title, "Folge löschen?")
        XCTAssertTrue(deleteState.message.contains("Super-Papagei"))
    }

    func testEpisodeDeleteStateCanCollectMultipleEpisodesFromOffsets() {
        var deleteState = EpisodeDeleteState()
        let episodes = [
            Episode(episodeNumber: 1, title: "A", releaseYear: 1979),
            Episode(episodeNumber: 2, title: "B", releaseYear: 1980),
            Episode(episodeNumber: 3, title: "C", releaseYear: 1981)
        ]

        deleteState.request(from: episodes, at: IndexSet([0, 2]))

        XCTAssertEqual(deleteState.pendingEpisodes.map(\.title), ["A", "C"])
        XCTAssertEqual(deleteState.title, "2 Folgen löschen?")
    }

    func testStatisticsOverviewPreferencesRestoreDefaultOrderWhenEmpty() {
        let sections = StatisticsOverviewPreferences.orderedItems(
            from: "",
            availableKinds: Set(StatisticsOverviewKind.allCases)
        )

        XCTAssertEqual(sections, StatisticsOverviewKind.allCases)
    }

    func testStatisticsOverviewPreferencesKeepSavedOrderAndAppendMissingItems() {
        let sections = StatisticsOverviewPreferences.orderedItems(
            from: "averageRating,episodes",
            availableKinds: Set(StatisticsOverviewKind.allCases)
        )

        XCTAssertEqual(sections, [.averageRating, .episodes, .listened, .open, .totalListens])
    }

    func testStatisticsOverviewPreferencesDecodeHiddenItems() {
        let hidden = StatisticsOverviewPreferences.hiddenItems(
            from: "episodes,averageRating",
            availableKinds: Set(StatisticsOverviewKind.allCases)
        )

        XCTAssertEqual(hidden, [.episodes, .averageRating])
    }

    @MainActor
    func testSyncPreparationDeduplicatesReferenceDataBySyncKey() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let keeperUniverse = Universe(name: "Die drei ???")
        let duplicateUniverse = Universe(name: "Die drei ???", syncKey: "universe:die drei ???")
        let keeperMood = Mood(name: "Gruselig", iconName: "😱")
        let duplicateMood = Mood(name: "Gruselig", iconName: nil, syncKey: "mood:gruselig")
        let episode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            universe: duplicateUniverse,
            moods: [duplicateMood]
        )

        context.insert(keeperUniverse)
        context.insert(duplicateUniverse)
        context.insert(keeperMood)
        context.insert(duplicateMood)
        context.insert(episode)

        SyncPreparation.prepare(context: context)

        let universes = try context.fetch(FetchDescriptor<Universe>())
        let moods = try context.fetch(FetchDescriptor<Mood>())
        let episodes = try context.fetch(FetchDescriptor<Episode>())

        XCTAssertEqual(universes.count, 1)
        XCTAssertEqual(moods.count, 1)
        XCTAssertEqual(episodes.count, 1)
        XCTAssertEqual(episodes[0].universe?.resolvedSyncKey, "universe:die drei ???")
        XCTAssertEqual(episodes[0].moods.map(\.resolvedSyncKey), ["mood:gruselig"])
        XCTAssertEqual(episodes[0].resolvedSyncKey, "episode:universe:die drei ???#1")
    }

    @MainActor
    func testSyncPreparationDeduplicatesSeededMoodAfterCloudImport() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let seededMood = Mood(name: "Gruselig", iconName: "😱")
        let cloudMood = Mood(name: "Gruselig", iconName: nil, syncKey: "legacy-cloud:mood:gruselig")
        let universe = Universe(name: "Die drei ???")
        let episode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            universe: universe,
            moods: [cloudMood]
        )

        context.insert(seededMood)
        context.insert(cloudMood)
        context.insert(universe)
        context.insert(episode)

        SyncPreparation.prepare(context: context)

        let moods = try context.fetch(FetchDescriptor<Mood>())
        let episodes = try context.fetch(FetchDescriptor<Episode>())

        XCTAssertEqual(moods.count, 1)
        XCTAssertEqual(episodes[0].moods.count, 1)
        XCTAssertEqual(episodes[0].moods[0].normalizedName, "gruselig")
    }

    @MainActor
    func testSyncPreparationRepairsDuplicateReferenceDataAfterPostStartCloudImport() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let seededUniverse = Universe(name: "Bibi Blocksberg")
        let seededMood = Mood(name: "Witzig", iconName: "😄")
        context.insert(seededUniverse)
        context.insert(seededMood)

        SyncPreparation.prepare(context: context)

        let importedUniverse = Universe(name: " bibi blocksberg ", syncKey: "legacy-cloud:universe:bibi")
        let importedMood = Mood(name: " Witzig ", iconName: nil, syncKey: "legacy-cloud:mood:witzig")
        let importedEpisode = Episode(
            episodeNumber: 1,
            title: "Hexen gibt es doch",
            releaseYear: 1980,
            universe: importedUniverse,
            moods: [importedMood]
        )

        context.insert(importedUniverse)
        context.insert(importedMood)
        context.insert(importedEpisode)

        SyncPreparation.prepare(context: context)

        let universes = try context.fetch(FetchDescriptor<Universe>())
        let moods = try context.fetch(FetchDescriptor<Mood>())
        let episodes = try context.fetch(FetchDescriptor<Episode>())

        XCTAssertEqual(universes.count, 1)
        XCTAssertEqual(moods.count, 1)
        XCTAssertEqual(episodes.count, 1)
        XCTAssertEqual(episodes[0].universe?.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), "bibi blocksberg")
        XCTAssertEqual(episodes[0].moods.map(\.normalizedName), ["witzig"])
    }

    @MainActor
    func testSyncPreparationDeduplicatesEpisodesBySameUniverseAndNumber() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let universe = Universe(name: "Die drei ???")
        let moodA = Mood(name: "Spannend", iconName: "⚡")
        let moodB = Mood(name: "Gruselig", iconName: "😱")

        // Episode A: listened, rating 4, has moodA
        let episodeA = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            isListened: true,
            rating: 4,
            listenCount: 2,
            universe: universe,
            moods: [moodA]
        )

        // Episode B: duplicate with rating 2, has moodB and a note
        let episodeB = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            personalNote: "Klassiker!",
            isListened: false,
            rating: 2,
            listenCount: 1,
            universe: universe,
            moods: [moodB]
        )

        context.insert(universe)
        context.insert(moodA)
        context.insert(moodB)
        context.insert(episodeA)
        context.insert(episodeB)

        SyncPreparation.prepare(context: context)

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.count, 1, "Duplicate episode should be removed")

        let keeper = episodes[0]
        XCTAssertTrue(keeper.isListened, "Keeper should be the listened episode")
        XCTAssertEqual(keeper.rating, 4, "Keeper should have the higher rating")
        XCTAssertEqual(keeper.listenCount, 2, "Keeper should have higher listen count")
        XCTAssertEqual(keeper.personalNote, "Klassiker!", "Note should be merged from duplicate")
        XCTAssertEqual(keeper.moods.count, 2, "Moods from both episodes should be merged")
    }

    @MainActor
    func testSyncPreparationKeepsEpisodesWithDifferentNumbers() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let universe = Universe(name: "Die drei ???")
        let ep1 = Episode(episodeNumber: 1, title: "Super-Papagei", releaseYear: 1979, universe: universe)
        let ep2 = Episode(episodeNumber: 2, title: "Phantomsee", releaseYear: 1979, universe: universe)

        context.insert(universe)
        context.insert(ep1)
        context.insert(ep2)

        SyncPreparation.prepare(context: context)

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.count, 2, "Different episode numbers should not be deduplicated")
    }

    @MainActor
    func testSyncPreparationSkipsOrphanEpisodesWithoutUniverse() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        // Two episodes with same number but no universe — should NOT be deduplicated
        let ep1 = Episode(episodeNumber: 1, title: "Orphan A", releaseYear: 2000, isListened: true)
        let ep2 = Episode(episodeNumber: 1, title: "Orphan B", releaseYear: 2000)

        context.insert(ep1)
        context.insert(ep2)

        SyncPreparation.prepare(context: context)

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.count, 2, "Orphan episodes without universe should not be deduplicated")
    }

    @MainActor
    func testSyncPreparationDeduplicatesAcrossUniversesIndependently() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let universe1 = Universe(name: "Die drei ???")
        let universe2 = Universe(name: "TKKG")

        // Same episode number in different universes — NOT duplicates
        let ep1 = Episode(episodeNumber: 1, title: "Super-Papagei", releaseYear: 1979, universe: universe1)
        let ep2 = Episode(episodeNumber: 1, title: "Die Jagd nach den Millionendieben", releaseYear: 1981, universe: universe2)

        context.insert(universe1)
        context.insert(universe2)
        context.insert(ep1)
        context.insert(ep2)

        SyncPreparation.prepare(context: context)

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.count, 2, "Same number in different universes should not be deduplicated")
    }

    @MainActor
    func testSyncPreparationMergesLastListenedAtFromDuplicate() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let universe = Universe(name: "Die drei ???")
        let olderDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newerDate = Date(timeIntervalSince1970: 1_710_000_000)

        let episodeA = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            isListened: true,
            rating: 5,
            listenCount: 3,
            lastListenedAt: olderDate,
            universe: universe
        )
        let episodeB = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            isListened: false,
            lastListenedAt: newerDate,
            universe: universe
        )

        context.insert(universe)
        context.insert(episodeA)
        context.insert(episodeB)

        SyncPreparation.prepare(context: context)

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.count, 1)
        XCTAssertEqual(episodes[0].lastListenedAt, newerDate, "Should keep the more recent lastListenedAt")
        XCTAssertEqual(episodes[0].rating, 5, "Should keep the keeper's rating")
    }

    @MainActor
    func testSyncPreparationConcatenatesNotesFromBothEpisodes() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let universe = Universe(name: "Die drei ???")

        let episodeA = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            personalNote: "Erste Folge",
            isListened: true,
            rating: 4,
            universe: universe
        )
        let episodeB = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            personalNote: "Klassiker!",
            isListened: false,
            universe: universe
        )

        context.insert(universe)
        context.insert(episodeA)
        context.insert(episodeB)

        SyncPreparation.prepare(context: context)

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.count, 1)
        XCTAssertEqual(episodes[0].personalNote, "Erste Folge\nKlassiker!", "Both notes should be concatenated")
    }

    @MainActor
    func testBootstrapperProvidesDefaultUniverseWhenMissing() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )

        let universe = AppDataBootstrapper.ensureDefaultUniverse(in: container.mainContext)

        XCTAssertEqual(universe?.name, "Allgemein")
        XCTAssertEqual(universe?.resolvedSyncKey, "universe:allgemein")
    }

    @MainActor
    func testCloudReadinessRepairRefreshesEpisodeSyncKey() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let universe = Universe(name: "Die drei ???")
        let episode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            syncKey: nil,
            universe: universe
        )
        episode.syncKey = ""
        context.insert(universe)
        context.insert(episode)

        AppDataBootstrapper.repairCloudSyncReadinessIfNeeded(container: container)

        XCTAssertEqual(episode.resolvedSyncKey, "episode:universe:die drei ???#1")
        XCTAssertEqual(episode.syncKey, "episode:universe:die drei ???#1")
    }

    @MainActor
    func testAssignMissingCollectionsReplacesPendingEpisodeSyncKeyWithDefaultUniverseKey() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let episode = Episode(
            episodeNumber: 5,
            title: "Ohne Sammlung",
            releaseYear: 1995,
            universe: nil
        )
        let pendingKey = episode.resolvedSyncKey
        context.insert(episode)

        AppDataBootstrapper.assignMissingCollectionsIfNeeded(container: container)
        AppDataBootstrapper.repairCloudSyncReadinessIfNeeded(container: container)

        XCTAssertTrue(pendingKey.hasPrefix("episode:pending:"))
        XCTAssertEqual(episode.universe?.resolvedSyncKey, "universe:allgemein")
        XCTAssertEqual(episode.resolvedSyncKey, "episode:universe:allgemein#5")
    }

    func testEpisodeListControlsDetectActiveFiltersAndCanResetThem() {
        let mood = Mood(name: "Gruselig", iconName: "😱")
        let universe = Universe(name: "Die drei ???")
        var controls = EpisodeListControlsState(
            searchText: "Papagei",
            filterMood: mood,
            filterUniverse: universe,
            statusFilter: .rated,
            sortOrder: .title
        )

        XCTAssertTrue(controls.hasActiveFilter)

        controls.resetFilters()

        XCTAssertNil(controls.filterMood)
        XCTAssertNil(controls.filterUniverse)
        XCTAssertEqual(controls.statusFilter, .all)
        XCTAssertEqual(controls.searchText, "Papagei")
        XCTAssertEqual(controls.sortOrder, .title)
    }

    func testEpisodeListControlsCanKeepMoodFilterWhenResettingForIPad() {
        let mood = Mood(name: "Abenteuer", iconName: "🧭")
        var controls = EpisodeListControlsState(filterMood: mood, statusFilter: .listened)

        controls.resetFilters(resetMood: false)

        XCTAssertEqual(controls.filterMood?.name, "Abenteuer")
        XCTAssertEqual(controls.statusFilter, .all)
    }

    func testSplitLayoutDeciderUsesRegularSizeClassEvenBelowThreshold() {
        XCTAssertTrue(
            SplitLayoutDecider.shouldUseSplitLayout(
                horizontalSizeClass: .regular,
                width: 700
            )
        )
    }

    func testSplitLayoutDeciderUsesWidthThresholdForCompactSizeClass() {
        XCTAssertFalse(
            SplitLayoutDecider.shouldUseSplitLayout(
                horizontalSizeClass: .compact,
                width: 760
            )
        )

        XCTAssertTrue(
            SplitLayoutDecider.shouldUseSplitLayout(
                horizontalSizeClass: .compact,
                width: 800
            )
        )
    }

    func testStatisticsRegularLayoutUsesSingleDetailColumnForPortraitLikeWidths() {
        let layout = StatisticsRegularLayout(containerWidth: 820)

        XCTAssertEqual(layout.detailColumns.count, 1)
        XCTAssertLessThanOrEqual(layout.contentWidth, 760)
        XCTAssertGreaterThanOrEqual(layout.horizontalPadding, 24)
    }

    func testStatisticsRegularLayoutUsesTwoDetailColumnsForWideWidths() {
        let layout = StatisticsRegularLayout(containerWidth: 1180)

        XCTAssertEqual(layout.detailColumns.count, 2)
        XCTAssertLessThanOrEqual(layout.contentWidth, 1100)
        XCTAssertGreaterThan(layout.horizontalPadding, 24)
    }
}
