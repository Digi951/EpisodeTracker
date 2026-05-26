import XCTest
import SwiftData
import SwiftUI
import UIKit
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
              "releaseYear": 1979,
              "deezerURL": "https://www.deezer.com/album/1234567"
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
        XCTAssertEqual(entries[0].deezerURL, "https://www.deezer.com/album/1234567")
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

    func testParsesNormalizedCatalogDocumentMetadata() throws {
        let json = """
        {
          "collectionName": "Bibi und Tina",
          "version": 2,
          "lastUpdated": "2026-05-19",
          "entryCount": 124,
          "entries": [
            {
              "number": 1,
              "title": "Das Fohlen",
              "releaseYear": 1991,
              "deezerURL": "https://www.deezer.com/album/7654321"
            }
          ]
        }
        """

        let document = try parser.parseNormalizedCatalogDocument(
            from: Data(json.utf8),
            fallbackCollectionName: "Fallback"
        )

        XCTAssertEqual(document.collectionName, "Bibi und Tina")
        XCTAssertEqual(document.version, 2)
        XCTAssertEqual(document.lastUpdated, "2026-05-19")
        XCTAssertEqual(document.entryCount, 124)
        XCTAssertEqual(document.entries.map(\.number), [1])
        XCTAssertEqual(document.entries[0].collectionName, "Bibi und Tina")
        XCTAssertEqual(document.entries[0].deezerURL, "https://www.deezer.com/album/7654321")
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
        XCTAssertTrue(
            AppModelContainerFactory.isCloudSyncGuardEnabled(
                environment: [AppModelContainerFactory.legacyCloudSyncGuardEnvironmentKey: "1"]
            )
        )
    }

    func testContainerModeProvidesDebugTitles() {
        XCTAssertEqual(AppModelContainerMode.previewInMemory.debugTitle, "Preview (In-Memory)")
        XCTAssertEqual(AppModelContainerMode.localPersistent.debugTitle, "Lokal")
        XCTAssertEqual(
            AppModelContainerMode.cloudPersistent(containerIdentifier: "iCloud.example").debugTitle,
            "Cloud"
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
        episode.coverImageName = "cover-\(episode.id.uuidString)"

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
        XCTAssertEqual(snapshot.episodes[0].coverImageName, "cover-\(episode.id.uuidString)")
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
            coverImageName: "local-cover",
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
            coverImageName: "cloud-cover",
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
        XCTAssertEqual(merged.coverImageName, "local-cover")
        XCTAssertEqual(merged.moodSyncKeys, ["mood:spannend"])
    }

    func testSyncMigrationEpisodeMergerUsesNewerFieldTimestampsWhenBothExist() {
        let local = LocalLibrarySnapshot.EpisodeRecord(
            syncKey: "episode:universe:die drei ???#1",
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            personalNote: nil,
            isListened: false,
            rating: nil,
            listenCount: 0,
            lastListenedAt: nil,
            coverImageName: "local-cover",
            coverUpdatedAt: Date(timeIntervalSince1970: 1_000),
            moodsUpdatedAt: Date(timeIntervalSince1970: 1_000),
            universeSyncKey: "universe:die drei ???",
            moodSyncKeys: ["mood:spannend"]
        )
        let cloud = LocalLibrarySnapshot.EpisodeRecord(
            syncKey: "episode:universe:die drei ???#1",
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            personalNote: nil,
            isListened: false,
            rating: nil,
            listenCount: 0,
            lastListenedAt: nil,
            coverImageName: "cloud-cover",
            coverUpdatedAt: Date(timeIntervalSince1970: 2_000),
            moodsUpdatedAt: Date(timeIntervalSince1970: 2_000),
            universeSyncKey: "universe:die drei ???",
            moodSyncKeys: ["mood:gruselig"]
        )

        let merged = SyncMigrationEpisodeMerger.merge(local: local, cloud: cloud)

        XCTAssertEqual(merged.coverImageName, "cloud-cover")
        XCTAssertEqual(merged.coverUpdatedAt, Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(merged.moodSyncKeys, ["mood:gruselig"])
        XCTAssertEqual(merged.moodsUpdatedAt, Date(timeIntervalSince1970: 2_000))
    }

    func testSyncMigrationEpisodeMergerKeepsLocalFieldsWhenTimestampsAreMissing() {
        let local = LocalLibrarySnapshot.EpisodeRecord(
            syncKey: "episode:universe:die drei ???#1",
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            personalNote: nil,
            isListened: false,
            rating: nil,
            listenCount: 0,
            lastListenedAt: nil,
            coverImageName: "local-cover",
            universeSyncKey: "universe:die drei ???",
            moodSyncKeys: []
        )
        let cloud = LocalLibrarySnapshot.EpisodeRecord(
            syncKey: "episode:universe:die drei ???#1",
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            personalNote: nil,
            isListened: false,
            rating: nil,
            listenCount: 0,
            lastListenedAt: nil,
            coverImageName: "cloud-cover",
            coverUpdatedAt: Date(timeIntervalSince1970: 2_000),
            moodsUpdatedAt: Date(timeIntervalSince1970: 2_000),
            universeSyncKey: "universe:die drei ???",
            moodSyncKeys: ["mood:gruselig"]
        )

        let merged = SyncMigrationEpisodeMerger.merge(local: local, cloud: cloud)

        XCTAssertEqual(merged.coverImageName, "local-cover")
        XCTAssertNil(merged.coverUpdatedAt)
        XCTAssertTrue(merged.moodSyncKeys.isEmpty)
        XCTAssertNil(merged.moodsUpdatedAt)
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
                    coverImageName: "source-cover",
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
        XCTAssertEqual(mergedSnapshot.episodes[0].coverImageName, "source-cover")
        XCTAssertEqual(mergedSnapshot.episodes[0].moodSyncKeys, ["mood:spannend"])
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
        XCTAssertTrue(
            defaults.string(forKey: AppDataBootstrapper.automaticCloudMigrationStatusKey)?
                .hasPrefix("Automatische Cloud-Migration erfolgreich: 1 Folgen") == true
        )
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
        localEpisode.coverImageName = "local-cover"

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
        XCTAssertEqual(mergedEpisode.coverImageName, "local-cover")
        XCTAssertEqual(mergedEpisode.moodSyncKeys, ["mood:spannend"])
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

    @MainActor
    func testBootstrapRepairsMissingCoverAfterCompletedMigrationMarker() async throws {
        let localContainer = try makeInMemoryContainer()
        let localContext = localContainer.mainContext

        let localUniverse = Universe(name: "Die drei ???")
        let localEpisode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            universe: localUniverse
        )
        localEpisode.coverImageName = "local-cover"

        localContext.insert(localUniverse)
        localContext.insert(localEpisode)

        let cloudContainer = try makeInMemoryContainer()
        let cloudContext = cloudContainer.mainContext
        let cloudUniverse = Universe(name: "Die drei ???")
        let cloudMood = Mood(name: "Gruselig", iconName: "😱")
        let cloudEpisode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            syncKey: "episode:universe:die drei ???#1",
            universe: cloudUniverse,
            moods: [cloudMood]
        )

        cloudContext.insert(cloudUniverse)
        cloudContext.insert(cloudMood)
        cloudContext.insert(cloudEpisode)

        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defaults.set(4, forKey: AppDataBootstrapper.schemaVersionKey)
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
        let repairedEpisode = try XCTUnwrap(
            cloudSnapshot.episodes.first(where: { $0.syncKey == "episode:universe:die drei ???#1" })
        )

        XCTAssertEqual(cloudSnapshot.episodes.count, 1)
        XCTAssertEqual(repairedEpisode.coverImageName, "local-cover")
        XCTAssertEqual(repairedEpisode.moodSyncKeys, ["mood:gruselig"])
        XCTAssertTrue(SyncMigrationStateStore.hasCompletedLocalToCloudRepair(userDefaults: defaults))
        XCTAssertEqual(
            defaults.string(forKey: AppDataBootstrapper.automaticCloudMigrationStatusKey),
            "Automatische Cloud-Migration repariert: 1 Cover ergänzt."
        )
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

    func testCatalogUpdateBannerSummarizesMissingActiveCatalogEpisodes() {
        let source = ManagedCatalogSource(
            id: "die-drei-fragezeichen",
            name: "Die drei ???",
            url: URL(string: "https://example.com/catalog.json")!
        )
        let universe = Universe(name: "Die drei ???")
        let library = [
            Episode(episodeNumber: 1, title: "A", releaseYear: 1979, universe: universe)
        ]
        let catalog = [
            CatalogEntry(number: 1, title: "A", releaseYear: 1979, collectionName: "Die drei ???"),
            CatalogEntry(number: 2, title: "Phantomsee", releaseYear: 1979, collectionName: "Die drei ???"),
            CatalogEntry(number: 3, title: "Karpatenhund", releaseYear: 1980, collectionName: "Die drei ???")
        ]

        let recommendation = EpisodeListOrganizer.catalogUpdateBannerRecommendation(
            catalogEntries: catalog,
            libraryEpisodes: library,
            activeCatalogIDs: [source.id],
            managedSources: [source]
        )

        XCTAssertEqual(recommendation?.missingEpisodeCount, 2)
        XCTAssertEqual(recommendation?.universeCount, 1)
        XCTAssertEqual(recommendation?.firstUniverseName, "Die drei ???")
        XCTAssertEqual(recommendation?.firstEpisodeTitle, "Phantomsee")
        XCTAssertEqual(recommendation?.title, "2 neue Katalogfolgen")
    }

    func testCatalogUpdateBannerIgnoresInactiveCatalogs() {
        let source = ManagedCatalogSource(
            id: "tkkg",
            name: "TKKG",
            url: URL(string: "https://example.com/catalog.json")!
        )
        let library = [
            Episode(episodeNumber: 1, title: "A", releaseYear: 1979, universe: Universe(name: "TKKG"))
        ]
        let catalog = [
            CatalogEntry(number: 2, title: "Millionendiebe", releaseYear: 1981, collectionName: "TKKG")
        ]

        let recommendation = EpisodeListOrganizer.catalogUpdateBannerRecommendation(
            catalogEntries: catalog,
            libraryEpisodes: library,
            activeCatalogIDs: [],
            managedSources: [source]
        )

        XCTAssertNil(recommendation)
    }

    func testCatalogUpdateBannerHidesWhenLibraryAlreadyContainsCatalogEpisodes() {
        let source = ManagedCatalogSource(
            id: "die-drei-fragezeichen",
            name: "Die drei ???",
            url: URL(string: "https://example.com/catalog.json")!
        )
        let universe = Universe(name: "Die drei ???")
        let library = [
            Episode(episodeNumber: 1, title: "A", releaseYear: 1979, universe: universe),
            Episode(episodeNumber: 2, title: "B", releaseYear: 1979, universe: universe)
        ]
        let catalog = [
            CatalogEntry(number: 1, title: "A", releaseYear: 1979, collectionName: "Die drei ???"),
            CatalogEntry(number: 2, title: "B", releaseYear: 1979, collectionName: "Die drei ???")
        ]

        let recommendation = EpisodeListOrganizer.catalogUpdateBannerRecommendation(
            catalogEntries: catalog,
            libraryEpisodes: library,
            activeCatalogIDs: [source.id],
            managedSources: [source]
        )

        XCTAssertNil(recommendation)
    }

    func testCatalogEpisodeDeltaUsesEpisodeNumbersAsDiffKey() {
        let previous = CatalogSnapshot(
            catalogID: "bibi-und-tina",
            name: "Bibi und Tina",
            version: 1,
            lastUpdated: "2026-05-18",
            entryCount: 2,
            episodeNumbers: [1, 2]
        )
        let current = CatalogSnapshot(
            catalogID: "bibi-und-tina",
            name: "Bibi und Tina",
            version: 2,
            lastUpdated: "2026-05-19",
            entryCount: 4,
            episodeNumbers: [1, 2, 3, 4]
        )
        let entries = [
            CatalogEntry(number: 1, title: "Das Fohlen", releaseYear: 1991, collectionName: "Bibi und Tina"),
            CatalogEntry(number: 2, title: "Am See", releaseYear: 1991, collectionName: "Bibi und Tina"),
            CatalogEntry(number: 3, title: "Der neue Reiterhof", releaseYear: 1992, collectionName: "Bibi und Tina"),
            CatalogEntry(number: 4, title: "Das Zeltlager", releaseYear: 1992, collectionName: "Bibi und Tina")
        ]

        let delta = CatalogEpisodeDelta.make(previous: previous, current: current, entries: entries)

        XCTAssertEqual(delta?.previousVersion, 1)
        XCTAssertEqual(delta?.currentVersion, 2)
        XCTAssertEqual(delta?.previousEntryCount, 2)
        XCTAssertEqual(delta?.currentEntryCount, 4)
        XCTAssertEqual(delta?.addedEntries.map(\.number), [3, 4])
    }

    func testCatalogEpisodeDeltaIgnoresMetadataOnlyUpdates() {
        let previous = CatalogSnapshot(
            catalogID: "bibi-und-tina",
            name: "Bibi und Tina",
            version: 1,
            lastUpdated: "2026-05-18",
            entryCount: 2,
            episodeNumbers: [1, 2]
        )
        let current = CatalogSnapshot(
            catalogID: "bibi-und-tina",
            name: "Bibi und Tina",
            version: 2,
            lastUpdated: "2026-05-19",
            entryCount: 2,
            episodeNumbers: [1, 2]
        )
        let entries = [
            CatalogEntry(number: 1, title: "Das Fohlen", releaseYear: 1991, collectionName: "Bibi und Tina"),
            CatalogEntry(number: 2, title: "Am See", releaseYear: 1991, collectionName: "Bibi und Tina")
        ]

        XCTAssertNil(CatalogEpisodeDelta.make(previous: previous, current: current, entries: entries))
    }

    func testDeltaCatalogUpdateBannerPrefersNewCatalogAvailability() {
        let url = URL(string: "https://example.com/catalog.json")!
        let availability = NewCatalogAvailability(sources: [
            ManagedCatalogSource(id: "bibi-blocksberg", name: "Bibi Blocksberg", url: url)
        ])
        let delta = CatalogEpisodeDelta(
            catalogID: "bibi-und-tina",
            name: "Bibi und Tina",
            previousVersion: 1,
            currentVersion: 2,
            previousEntryCount: 2,
            currentEntryCount: 3,
            addedEntries: [
                CatalogEntry(number: 3, title: "Der neue Reiterhof", releaseYear: 1992, collectionName: "Bibi und Tina")
            ]
        )

        let recommendation = EpisodeListOrganizer.catalogUpdateBannerRecommendation(
            newCatalogAvailability: availability,
            catalogEpisodeDeltas: [delta],
            activeCatalogIDs: ["bibi-und-tina"]
        )

        XCTAssertEqual(recommendation?.title, "1 neuer Katalog verfügbar")
        XCTAssertEqual(recommendation?.message, "Bibi Blocksberg kann in den Katalogen aktiviert werden.")
    }

    func testDeltaCatalogUpdateBannerHidesActivatedNewCatalogs() {
        let url = URL(string: "https://example.com/catalog.json")!
        let availability = NewCatalogAvailability(sources: [
            ManagedCatalogSource(id: "bibi-blocksberg", name: "Bibi Blocksberg", url: url)
        ])

        let recommendation = EpisodeListOrganizer.catalogUpdateBannerRecommendation(
            newCatalogAvailability: availability,
            catalogEpisodeDeltas: [],
            activeCatalogIDs: ["bibi-blocksberg"]
        )

        XCTAssertNil(recommendation)
    }

    func testDeltaCatalogUpdateBannerFiltersInactiveCatalogs() {
        let activeDelta = CatalogEpisodeDelta(
            catalogID: "bibi-und-tina",
            name: "Bibi und Tina",
            previousVersion: 1,
            currentVersion: 2,
            previousEntryCount: 2,
            currentEntryCount: 4,
            addedEntries: [
                CatalogEntry(number: 3, title: "Der neue Reiterhof", releaseYear: 1992, collectionName: "Bibi und Tina"),
                CatalogEntry(number: 4, title: "Das Zeltlager", releaseYear: 1992, collectionName: "Bibi und Tina")
            ]
        )
        let inactiveDelta = CatalogEpisodeDelta(
            catalogID: "tkkg",
            name: "TKKG",
            previousVersion: 1,
            currentVersion: 2,
            previousEntryCount: 1,
            currentEntryCount: 4,
            addedEntries: [
                CatalogEntry(number: 2, title: "Der blinde Hellseher", releaseYear: 1982, collectionName: "TKKG"),
                CatalogEntry(number: 3, title: "Das leere Grab im Moor", releaseYear: 1982, collectionName: "TKKG"),
                CatalogEntry(number: 4, title: "Das Paket mit dem Totenkopf", releaseYear: 1982, collectionName: "TKKG")
            ]
        )

        let recommendation = EpisodeListOrganizer.catalogUpdateBannerRecommendation(
            newCatalogAvailability: nil,
            catalogEpisodeDeltas: [inactiveDelta, activeDelta],
            activeCatalogIDs: ["bibi-und-tina"]
        )

        XCTAssertEqual(recommendation?.title, "2 neue Katalogfolgen in Bibi und Tina")
        XCTAssertEqual(recommendation?.message, "Der neue Reiterhof und weitere neue Folgen wurden ergänzt.")
        XCTAssertEqual(recommendation?.compactMessage, "Version 1 -> 2 - 4 Folgen")
    }

    func testDeltaCatalogUpdateBannerAggregatesMultipleActiveCatalogs() {
        let bibiDelta = CatalogEpisodeDelta(
            catalogID: "bibi-und-tina",
            name: "Bibi und Tina",
            previousVersion: 1,
            currentVersion: 2,
            previousEntryCount: 2,
            currentEntryCount: 4,
            addedEntries: [
                CatalogEntry(number: 3, title: "Der neue Reiterhof", releaseYear: 1992, collectionName: "Bibi und Tina"),
                CatalogEntry(number: 4, title: "Das Zeltlager", releaseYear: 1992, collectionName: "Bibi und Tina")
            ]
        )
        let tkkgDelta = CatalogEpisodeDelta(
            catalogID: "tkkg",
            name: "TKKG",
            previousVersion: 1,
            currentVersion: 2,
            previousEntryCount: 1,
            currentEntryCount: 4,
            addedEntries: [
                CatalogEntry(number: 2, title: "Der blinde Hellseher", releaseYear: 1982, collectionName: "TKKG"),
                CatalogEntry(number: 3, title: "Das leere Grab im Moor", releaseYear: 1982, collectionName: "TKKG"),
                CatalogEntry(number: 4, title: "Das Paket mit dem Totenkopf", releaseYear: 1982, collectionName: "TKKG")
            ]
        )

        let recommendation = EpisodeListOrganizer.catalogUpdateBannerRecommendation(
            newCatalogAvailability: nil,
            catalogEpisodeDeltas: [bibiDelta, tkkgDelta],
            activeCatalogIDs: ["bibi-und-tina", "tkkg"]
        )

        XCTAssertEqual(recommendation?.title, "5 neue Katalogfolgen in 2 Katalogen")
        XCTAssertEqual(recommendation?.missingEpisodeCount, 5)
        XCTAssertEqual(recommendation?.universeCount, 2)
        // TKKG has more new episodes, so it is ranked and named first.
        XCTAssertEqual(recommendation?.message, "Neue Folgen in TKKG und Bibi und Tina.")
    }

    // MARK: - Banner-Fingerprint

    func testFingerprintChangesWhenCatalogStateChanges() {
        let bannerA = CatalogUpdateBannerRecommendation(
            missingEpisodeCount: 3,
            universeCount: 1,
            firstUniverseName: "Die drei ???",
            firstEpisodeTitle: "und der Super-Papagei"
        )
        let bannerB = CatalogUpdateBannerRecommendation(
            missingEpisodeCount: 5,
            universeCount: 1,
            firstUniverseName: "Die drei ???",
            firstEpisodeTitle: "und der Super-Papagei"
        )

        XCTAssertNotEqual(bannerA.fingerprint, bannerB.fingerprint)
    }

    func testFingerprintStableForSameState() {
        let bannerA = CatalogUpdateBannerRecommendation(
            missingEpisodeCount: 3,
            universeCount: 1,
            firstUniverseName: "Die drei ???",
            firstEpisodeTitle: "und der Super-Papagei"
        )
        let bannerB = CatalogUpdateBannerRecommendation(
            missingEpisodeCount: 3,
            universeCount: 1,
            firstUniverseName: "Die drei ???",
            firstEpisodeTitle: "und der Super-Papagei"
        )

        XCTAssertEqual(bannerA.fingerprint, bannerB.fingerprint)
    }

    func testFingerprintChangesWhenSameCatalogGainsDifferentEpisodes() {
        // Two separate updates to the same catalog that each add the same
        // number of episodes must not collide — otherwise the second banner
        // stays hidden once the first was dismissed.
        let firstUpdate = CatalogUpdateBannerRecommendation(
            missingEpisodeCount: 2,
            universeCount: 1,
            firstUniverseName: "Die drei ???",
            firstEpisodeTitle: "und der Super-Papagei"
        )
        let secondUpdate = CatalogUpdateBannerRecommendation(
            missingEpisodeCount: 2,
            universeCount: 1,
            firstUniverseName: "Die drei ???",
            firstEpisodeTitle: "und der Phantomsee"
        )

        XCTAssertNotEqual(firstUpdate.fingerprint, secondUpdate.fingerprint)
    }

    func testNewCatalogBannerFingerprintDiffersFromEpisodeBanner() {
        let newCatalogBanner = CatalogUpdateBannerRecommendation.newCatalogs(
            NewCatalogAvailability(sources: [
                ManagedCatalogSource(id: "bibi", name: "Bibi und Tina", url: URL(string: "https://example.com")!)
            ])
        )
        let episodeBanner = CatalogUpdateBannerRecommendation(
            missingEpisodeCount: 1,
            universeCount: 1,
            firstUniverseName: "Bibi und Tina",
            firstEpisodeTitle: "Das Fohlen"
        )

        XCTAssertNotNil(newCatalogBanner)
        XCTAssertNotEqual(newCatalogBanner?.fingerprint, episodeBanner.fingerprint)
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
        XCTAssertTrue(deleteState.message(usesCloudSync: false).contains("Super-Papagei"))
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

    func testEpisodeSelectionControllerTogglesAllVisibleEpisodes() {
        let episodes = [
            Episode(episodeNumber: 1, title: "A", releaseYear: 1979),
            Episode(episodeNumber: 2, title: "B", releaseYear: 1980)
        ]
        var controller = EpisodeSelectionController()

        controller.toggleAllVisible(episodes)

        XCTAssertEqual(controller.count, 2)
        XCTAssertEqual(controller.selectAllButtonTitle(visibleEpisodes: episodes), "Keine")

        controller.toggleAllVisible(episodes)

        XCTAssertTrue(controller.isEmpty)
        XCTAssertEqual(controller.selectAllButtonTitle(visibleEpisodes: episodes), "Alle")
    }

    func testEpisodeSelectionControllerReturnsSelectedEpisodes() {
        let episodes = [
            Episode(episodeNumber: 1, title: "A", releaseYear: 1979),
            Episode(episodeNumber: 2, title: "B", releaseYear: 1980),
            Episode(episodeNumber: 3, title: "C", releaseYear: 1981)
        ]
        var controller = EpisodeSelectionController()
        controller.selectedIDs = [
            episodes[0].persistentModelID,
            episodes[2].persistentModelID
        ]

        XCTAssertEqual(controller.selectedEpisodes(from: episodes).map(\.title), ["A", "C"])
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

        XCTAssertEqual(sections, [.averageRating, .episodes, .listened, .open, .totalListens, .favorites])
    }

    func testStatisticsOverviewPreferencesDecodeHiddenItems() {
        let hidden = StatisticsOverviewPreferences.hiddenItems(
            from: "episodes,averageRating",
            availableKinds: Set(StatisticsOverviewKind.allCases)
        )

        XCTAssertEqual(hidden, [.episodes, .averageRating])
    }

    // MARK: - Smart List Preferences

    func testSmartListPreferencesVisibleListsReturnsAllWhenEmpty() {
        let visible = SmartListPreferences.visibleLists(orderRaw: "", hiddenRaw: "")
        XCTAssertEqual(visible, SmartListDefinition.allCases)
    }

    func testSmartListPreferencesHiddenListsExcludesFromVisible() {
        let hidden = SmartListPreferences.encodeHidden([.random, .skipped])
        let visible = SmartListPreferences.visibleLists(orderRaw: "", hiddenRaw: hidden)

        XCTAssertFalse(visible.contains(.random))
        XCTAssertFalse(visible.contains(.skipped))
        XCTAssertEqual(visible.count, SmartListDefinition.allCases.count - 2)
    }

    func testSmartListPreferencesHiddenRoundTrip() {
        let original: Set<SmartListDefinition> = [.laterListen, .favorites]
        let encoded = SmartListPreferences.encodeHidden(original)
        let decoded = SmartListPreferences.hiddenLists(from: encoded)

        XCTAssertEqual(decoded, original)
    }

    func testSmartListPreferencesOrderReturnsAllWhenEmpty() {
        let order = SmartListPreferences.orderedLists(from: "")
        XCTAssertEqual(order, SmartListDefinition.allCases)
    }

    func testSmartListPreferencesOrderRespectsCustomOrderAndAppendsMissing() {
        let order = SmartListPreferences.orderedLists(from: "random,favorites")

        XCTAssertEqual(order[0], .random)
        XCTAssertEqual(order[1], .favorites)
        XCTAssertEqual(order.count, SmartListDefinition.allCases.count)
    }

    func testSmartListPreferencesVisibleListsRespectsOrderAndHidden() {
        let orderRaw = SmartListPreferences.encodeOrder([.topRated, .random, .favorites, .laterListen, .continueListening, .nextFromCatalog, .longPaused, .skipped, .randomByMood])
        let hiddenRaw = SmartListPreferences.encodeHidden([.random])
        let visible = SmartListPreferences.visibleLists(orderRaw: orderRaw, hiddenRaw: hiddenRaw)

        XCTAssertEqual(visible[0], .topRated)
        XCTAssertEqual(visible[1], .favorites)
        XCTAssertFalse(visible.contains(.random))
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
        XCTAssertEqual(
            Set(keeper.moods.map(\.resolvedSyncKey)),
            Set(["mood:spannend", "mood:gruselig"]),
            "Keeper should preserve the union of moods from duplicate episodes"
        )
    }

    @MainActor
    func testSyncPreparationDeduplicatesEpisodesByUniverseNameWhenUniverseKeysDiffer() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let localUniverse = Universe(name: "Die drei ???", syncKey: "legacy-local-universe")
        let importedUniverse = Universe(name: "Die drei ???", syncKey: "universe:die drei ???")

        let localEpisode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            isListened: false,
            universe: localUniverse
        )
        let importedEpisode = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            isListened: true,
            listenCount: 1,
            universe: importedUniverse
        )

        context.insert(localUniverse)
        context.insert(importedUniverse)
        context.insert(localEpisode)
        context.insert(importedEpisode)

        SyncPreparation.prepare(context: context)

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.count, 1)
        XCTAssertTrue(episodes[0].isListened)
        XCTAssertEqual(episodes[0].listenCount, 1)
        XCTAssertEqual(episodes[0].universe?.name, "Die drei ???")
    }

    @MainActor
    func testSyncPreparationCollapsesTriplicatedUpgradeStateByVisibleKeys() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let universes = [
            Universe(name: "Die drei ???", syncKey: "legacy-local"),
            Universe(name: "Die drei ???", syncKey: "episode-import"),
            Universe(name: "Die drei ???", syncKey: "universe:die drei ???")
        ]
        let moods = [
            Mood(name: "Gruselig", iconName: "😱", syncKey: "legacy-gruselig"),
            Mood(name: "Gruselig", iconName: "😱", syncKey: "mood:gruselig"),
            Mood(name: "Klassiker", iconName: "⭐", syncKey: "mood:klassiker")
        ]

        for universe in universes {
            context.insert(universe)
        }
        for mood in moods {
            context.insert(mood)
        }

        let episodes = [
            Episode(episodeNumber: 1, title: "und der Super-Papagei", releaseYear: 1979, universe: universes[0]),
            Episode(episodeNumber: 1, title: "und der Super-Papagei", releaseYear: 1979, isListened: true, rating: 4, listenCount: 1, universe: universes[1], moods: [moods[0]]),
            Episode(episodeNumber: 1, title: "und der Super-Papagei", releaseYear: 1979, isListened: true, rating: 4, listenCount: 1, universe: universes[2], moods: [moods[2]]),
            Episode(episodeNumber: 2, title: "und der Phantomsee", releaseYear: 1979, universe: universes[0]),
            Episode(episodeNumber: 2, title: "und der Phantomsee", releaseYear: 1979, isListened: true, rating: 3, listenCount: 1, universe: universes[1], moods: [moods[1]]),
            Episode(episodeNumber: 2, title: "und der Phantomsee", releaseYear: 1979, isListened: true, rating: 3, listenCount: 1, universe: universes[2], moods: [moods[2]]),
            Episode(episodeNumber: 25, title: "und die singende Schlange", releaseYear: 1981, universe: universes[0]),
            Episode(episodeNumber: 25, title: "und die singende Schlange", releaseYear: 1981, isListened: true, rating: 3, listenCount: 1, universe: universes[1], moods: [moods[0], moods[2]]),
            Episode(episodeNumber: 25, title: "und die singende Schlange", releaseYear: 1981, rating: 3, universe: universes[2])
        ]
        for episode in episodes {
            context.insert(episode)
        }

        let summary = SyncPreparation.prepare(context: context)

        let remainingUniverses = try context.fetch(FetchDescriptor<Universe>())
        let remainingMoods = try context.fetch(FetchDescriptor<Mood>())
        let remainingEpisodes = try context.fetch(FetchDescriptor<Episode>())
        let remainingNumbers = remainingEpisodes.map(\.episodeNumber).sorted()

        XCTAssertEqual(remainingUniverses.count, 1)
        XCTAssertEqual(Set(remainingMoods.map(\.normalizedName)), ["gruselig", "klassiker"])
        XCTAssertEqual(remainingMoods.count, 2)
        XCTAssertEqual(remainingEpisodes.count, 3)
        XCTAssertEqual(remainingNumbers, [1, 2, 25])
        XCTAssertEqual(summary.deduplicatedEpisodes, 6)
        XCTAssertTrue(remainingEpisodes.allSatisfy { $0.universe?.name == "Die drei ???" })
        XCTAssertTrue(remainingEpisodes.allSatisfy { $0.moods.count <= 2 })
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
    func testSyncPreparationMergesCoverImageNameFromDuplicate() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        let universe = Universe(name: "Die drei ???")
        let coverStore = CoverImageStore()
        let coverName = "cover-25-\(UUID().uuidString)"
        try coverStore.save(makeTestCoverImage(), name: coverName)
        defer { try? coverStore.delete(name: coverName) }

        let episodeWithCover = Episode(
            episodeNumber: 25,
            title: "und die singende Schlange",
            releaseYear: 1981,
            isListened: true,
            rating: 3,
            universe: universe
        )
        episodeWithCover.coverImageName = coverName

        let episodeWithout = Episode(
            episodeNumber: 25,
            title: "und die singende Schlange",
            releaseYear: 1981,
            isListened: true,
            rating: 3,
            universe: universe
        )

        context.insert(universe)
        context.insert(episodeWithout)
        context.insert(episodeWithCover)

        SyncPreparation.prepare(context: context)

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.count, 1)
        XCTAssertEqual(episodes[0].coverImageName, coverName, "Cover should be preserved from the duplicate with a cover")
    }

    @MainActor
    func testSyncPreparationMergesStreamingURLFromDuplicate() throws {
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
            isListened: true,
            rating: 4,
            universe: universe
        )

        let episodeB = Episode(
            episodeNumber: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            isListened: false,
            universe: universe
        )
        episodeB.streamingURL = "https://open.spotify.com/album/abc"

        context.insert(universe)
        context.insert(episodeA)
        context.insert(episodeB)

        SyncPreparation.prepare(context: context)

        let episodes = try context.fetch(FetchDescriptor<Episode>())
        XCTAssertEqual(episodes.count, 1)
        XCTAssertEqual(episodes[0].streamingURL, "https://open.spotify.com/album/abc", "Streaming URL should be merged from duplicate")
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
    func testBootstrapperCreatesAllgemeinUniverseWhenOtherUniverseExists() throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext

        context.insert(Universe(name: "Bibi Blocksberg"))

        let universe = AppDataBootstrapper.ensureDefaultUniverse(in: context)
        let universes = try context.fetch(FetchDescriptor<Universe>())

        XCTAssertEqual(universe?.name, "Allgemein")
        XCTAssertTrue(universes.contains(where: { $0.name == "Allgemein" }))
    }

    @MainActor
    func testBootstrapRecordsAutomaticCloudMigrationSkipReasonWhenLocalContainerIsUnavailable() async throws {
        let cloudContainer = try makeInMemoryContainer()
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        await AppDataBootstrapper.bootstrap(
            containerSet: AppModelContainerSet(
                primary: cloudContainer,
                localPersistent: nil,
                cloudPersistent: cloudContainer,
                runtimeMode: .cloudPersistent(containerIdentifier: "iCloud.com.Digi.EpisodeTracker")
            ),
            userDefaults: defaults
        )

        XCTAssertEqual(
            defaults.string(forKey: AppDataBootstrapper.automaticCloudMigrationStatusKey),
            "Automatische Cloud-Migration übersprungen: lokaler Container ist nicht verfügbar."
        )
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

    // MARK: - Manifest Language Filter

    func testEffectiveLanguageDefaultsToGermanWhenNil() {
        let url = URL(string: "https://example.com/catalog.json")!
        let source = ManagedCatalogSource(id: "test", name: "Test", language: nil, url: url)

        XCTAssertEqual(source.effectiveLanguage, "de")
    }

    func testEffectiveLanguageReturnsExplicitLanguage() {
        let url = URL(string: "https://example.com/catalog.json")!
        let deSource = ManagedCatalogSource(id: "test-de", name: "Test DE", language: "de", url: url)
        let enSource = ManagedCatalogSource(id: "test-en", name: "Test EN", language: "en", url: url)

        XCTAssertEqual(deSource.effectiveLanguage, "de")
        XCTAssertEqual(enSource.effectiveLanguage, "en")
    }

    func testEffectiveLanguageNormalizesToLowercase() {
        let url = URL(string: "https://example.com/catalog.json")!
        let source = ManagedCatalogSource(id: "test", name: "Test", language: "EN", url: url)

        XCTAssertEqual(source.effectiveLanguage, "en")
    }

    func testDeduplicatedManagedSourcesFilteredByLanguageExcludesForeignCatalogs() {
        let url = URL(string: "https://example.com/catalog.json")!
        let sources = [
            ManagedCatalogSource(id: "de-catalog", name: "Die drei ???", language: "de", url: url),
            ManagedCatalogSource(id: "en-catalog", name: "Famous Five", language: "en", url: url),
            ManagedCatalogSource(id: "nil-catalog", name: "Fallback", language: nil, url: url),
        ]

        let deduplicated = CatalogSourceRegistry.deduplicatedManagedSources(sources)
        let germanOnly = deduplicated.filter { $0.effectiveLanguage == "de" }

        XCTAssertEqual(germanOnly.map(\.id), ["de-catalog", "nil-catalog"])
        XCTAssertFalse(germanOnly.contains { $0.id == "en-catalog" })
    }

    func testManifestWithMixedLanguagesFiltersCorrectly() throws {
        let json = """
        {
          "schemaVersion": 1,
          "updatedAt": "2026-05-26",
          "catalogs": [
            {
              "id": "die-drei-fragezeichen",
              "name": "Die drei ???",
              "language": "de",
              "url": "https://example.com/de/drei.json"
            },
            {
              "id": "famous-five",
              "name": "Famous Five",
              "language": "en",
              "url": "https://example.com/en/famous-five.json"
            },
            {
              "id": "legacy-catalog",
              "name": "Legacy",
              "url": "https://example.com/legacy.json"
            }
          ]
        }
        """

        let manifest = try parser.parseManifest(from: Data(json.utf8))

        XCTAssertEqual(manifest.catalogs.count, 3)

        let germanCatalogs = manifest.catalogs.filter { $0.effectiveLanguage == "de" }
        XCTAssertEqual(germanCatalogs.count, 2)
        XCTAssertTrue(germanCatalogs.contains { $0.id == "die-drei-fragezeichen" })
        XCTAssertTrue(germanCatalogs.contains { $0.id == "legacy-catalog" })

        let englishCatalogs = manifest.catalogs.filter { $0.effectiveLanguage == "en" }
        XCTAssertEqual(englishCatalogs.count, 1)
        XCTAssertEqual(englishCatalogs[0].id, "famous-five")
    }

    func testActiveCatalogStorePrunesOrphanedIDs() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = ActiveCatalogStore(userDefaults: defaults)
        let visibleIDs = Set(CatalogSourceRegistry.managedSources.map(\.id))
        store.activeIDs = visibleIDs.union(["removed-catalog", "another-removed"])

        let orphaned = store.pruneOrphanedIDs()

        XCTAssertEqual(Set(orphaned), ["another-removed", "removed-catalog"])
        XCTAssertEqual(store.activeIDs, visibleIDs)
    }

    func testActiveCatalogStorePruneReturnsEmptyWhenNoOrphans() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = ActiveCatalogStore(userDefaults: defaults)
        let visibleIDs = Set(CatalogSourceRegistry.managedSources.map(\.id))
        store.activeIDs = visibleIDs

        let orphaned = store.pruneOrphanedIDs()

        XCTAssertTrue(orphaned.isEmpty)
    }

    func testRemovedCatalogsBannerShowsCorrectTextForSingleCatalog() {
        let banner = CatalogUpdateBannerRecommendation.removedCatalogs(["TKKG"])

        XCTAssertNotNil(banner)
        XCTAssertEqual(banner?.title, "Katalog nicht mehr verfügbar")
        XCTAssertEqual(banner?.iconName, "text.badge.minus")
        XCTAssertEqual(banner?.iconColorName, "orange")
    }

    func testRemovedCatalogsBannerShowsCorrectTextForMultipleCatalogs() {
        let banner = CatalogUpdateBannerRecommendation.removedCatalogs(["TKKG", "Bibi Blocksberg"])

        XCTAssertNotNil(banner)
        XCTAssertEqual(banner?.title, "2 Kataloge nicht mehr verfügbar")
        XCTAssertEqual(banner?.iconName, "text.badge.minus")
    }

    func testRemovedCatalogsBannerReturnsNilForEmptyList() {
        let banner = CatalogUpdateBannerRecommendation.removedCatalogs([])

        XCTAssertNil(banner)
    }

    private func makeTestCoverImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
    }
}
