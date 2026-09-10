import XCTest
import SwiftData
@testable import EpisodeTracker

/// Coverage for the V1.18 Paket 3 schema step: freezing `SchemaV8` as an explicit
/// snapshot and adding `Universe.managedCatalogID` in `SchemaV9` with a
/// lightweight V8→V9 stage.
///
/// The test seeds a real on-disk store using the **frozen** `SchemaV8` model
/// definitions (no migration plan, so SwiftData stamps it as version 8), closes
/// it, then reopens it exactly as the app does on launch — live schema plus
/// `EpisodeTrackerMigrationPlan`. If the frozen `SchemaV8` snapshot does not
/// byte-match what 1.17 shipped, the reopen fails with "unknown model version".
@MainActor
final class SchemaMigrationV8toV9Tests: XCTestCase {

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SchemaMigrationV8toV9-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("EpisodeTracker.store")
    }

    func testV8StoreMigratesToV9AndPreservesData() throws {
        let storeURL = temporaryStoreURL()
        let storeDir = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDir) }

        // MARK: Seed a genuine V8 store from the frozen snapshot definitions.
        let episodeID = UUID()
        do {
            let v8Schema = Schema(versionedSchema: SchemaV8.self)
            let config = ModelConfiguration("V8Seed", schema: v8Schema, url: storeURL)
            let container = try ModelContainer(for: v8Schema, configurations: [config])
            let context = container.mainContext

            let universe = SchemaV8.Universe()
            universe.name = "Die drei ???"
            universe.syncKey = "universe:die drei ???"
            universe.styleRaw = "numbered"

            let mood = SchemaV8.Mood()
            mood.name = "Spannend"
            mood.iconName = "⚡"
            mood.syncKey = "mood:spannend"

            let episode = SchemaV8.Episode()
            episode.id = episodeID
            episode.episodeNumber = 1
            episode.title = "und der Super-Papagei"
            episode.releaseYear = 1979
            episode.syncKey = "episode:universe:die drei ???#1"
            episode.universe = universe
            episode.moodRelationships = [mood]

            context.insert(universe)
            context.insert(mood)
            context.insert(episode)
            try context.save()
        }

        // MARK: Reopen the way the app launches — live schema + staged plan.
        let schema = AppModelContainerFactory.schema()
        let configuration = ModelConfiguration("Default", schema: schema, url: storeURL)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: EpisodeTrackerMigrationPlan.self,
            configurations: [configuration]
        )
        let context = container.mainContext

        let universes = try context.fetch(FetchDescriptor<Universe>())
        let moods = try context.fetch(FetchDescriptor<Mood>())
        let episodes = try context.fetch(FetchDescriptor<Episode>())

        XCTAssertEqual(universes.count, 1, "The V8 universe must survive the migration")
        XCTAssertEqual(moods.count, 1)
        XCTAssertEqual(episodes.count, 1)

        let universe = try XCTUnwrap(universes.first)
        let episode = try XCTUnwrap(episodes.first)

        XCTAssertEqual(universe.name, "Die drei ???")
        XCTAssertEqual(universe.style, .numbered, "styleRaw must carry across V8→V9")
        XCTAssertNil(universe.managedCatalogID, "The new V9 field starts nil after a lightweight migration")

        XCTAssertEqual(episode.id, episodeID)
        XCTAssertEqual(episode.title, "und der Super-Papagei")
        XCTAssertEqual(episode.universe?.id, universe.id, "The episode→universe relationship must survive")
        XCTAssertEqual(episode.moods.map(\.name), ["Spannend"], "The episode→mood relationship must survive")
        XCTAssertEqual(universe.episodes.map(\.id), [episodeID], "The inverse universe→episode link must survive")
    }

    func testMigratedUniverseCanPersistABindingAfterUpgrade() throws {
        let storeURL = temporaryStoreURL()
        let storeDir = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDir) }

        do {
            let v8Schema = Schema(versionedSchema: SchemaV8.self)
            let config = ModelConfiguration("V8Seed", schema: v8Schema, url: storeURL)
            let container = try ModelContainer(for: v8Schema, configurations: [config])
            let universe = SchemaV8.Universe()
            universe.name = "TKKG"
            universe.syncKey = "universe:tkkg"
            container.mainContext.insert(universe)
            try container.mainContext.save()
        }

        let schema = AppModelContainerFactory.schema()
        let configuration = ModelConfiguration("Default", schema: schema, url: storeURL)

        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: EpisodeTrackerMigrationPlan.self,
                configurations: [configuration]
            )
            let universe = try XCTUnwrap(
                try container.mainContext.fetch(FetchDescriptor<Universe>()).first
            )
            XCTAssertNil(universe.managedCatalogID)
            universe.managedCatalogID = "tkkg"
            try container.mainContext.save()
        }

        let reopened = try ModelContainer(for: schema, configurations: [configuration])
        let universe = try XCTUnwrap(
            try reopened.mainContext.fetch(FetchDescriptor<Universe>()).first
        )
        XCTAssertEqual(universe.managedCatalogID, "tkkg")
    }
}
