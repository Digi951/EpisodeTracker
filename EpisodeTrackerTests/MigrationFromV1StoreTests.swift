import XCTest
import SwiftData
@testable import EpisodeTracker

/// Regression coverage for the v1.11 launch crash.
///
/// Users updating from v1.0–v1.3 (released without a `VersionedSchema`) crashed at
/// launch with `NSCocoaErrorDomain` 134504 — "Cannot use staged migration with an
/// unknown model version" — because `SchemaV1` did not byte-match the pre-versioned
/// on-disk model (its to-many relationships were optional, the real v1.0 store's were
/// not). The whole existing migration suite passed because it only ever exercises the
/// *current* schema in memory and never opens a genuine pre-versioned store.
///
/// This test loads a real v1.0 store (captured from the shipped v1.0 build: no version
/// identifier, no `id`/`syncKey`, non-optional to-many relationships) and runs it
/// through the production migration plan.
@MainActor
final class MigrationFromV1StoreTests: XCTestCase {

    private func fixtureURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("v1_0_seeded.store")
    }

    func testPreVersionedV1StoreMigratesThroughFullPlan() throws {
        let fixture = fixtureURL()
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: fixture.path),
            "v1.0 fixture store missing at \(fixture.path)"
        )

        // Copy to a throwaway location — opening migrates the store in place, and the
        // committed fixture must stay a pristine pre-versioned v1.0 store.
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("V1MigrationTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }
        let storeURL = workDir.appendingPathComponent("EpisodeTracker.store")
        try FileManager.default.copyItem(at: fixture, to: storeURL)

        // Open exactly as the app does on launch: current schema + staged migration plan.
        let schema = AppModelContainerFactory.schema()
        let configuration = ModelConfiguration("Default", schema: schema, url: storeURL)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: EpisodeTrackerMigrationPlan.self,
            configurations: [configuration]
        )

        // The v1.0 seed data (5 universes, 6 moods) must survive the migration to V6.
        let context = container.mainContext
        let universes = try context.fetch(FetchDescriptor<Universe>())
        let moods = try context.fetch(FetchDescriptor<Mood>())
        XCTAssertEqual(universes.count, 5, "v1.0 seeded universes must survive the migration")
        XCTAssertEqual(moods.count, 6, "v1.0 seeded moods must survive the migration")

        // After migration every record must carry the V2+ sync identity so iCloud sync
        // and deduplication can operate — proving the staged chain ran end to end.
        for universe in universes {
            XCTAssertFalse(universe.resolvedSyncKey.isEmpty)
        }
    }
}
