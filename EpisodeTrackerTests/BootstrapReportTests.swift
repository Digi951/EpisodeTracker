import XCTest
import SwiftData
@testable import EpisodeTracker

@MainActor
final class BootstrapReportTests: XCTestCase {

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func testBootstrapReturnsReport() async throws {
        let container = try makeInMemoryContainer()
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!

        let report = await AppDataBootstrapper.bootstrap(
            container: container,
            usesCloudSync: false,
            userDefaults: defaults
        )

        XCTAssertTrue(report.seededMoods)
        XCTAssertTrue(report.seededCollections)
    }

    func testBootstrapReportsOrphanAssignment() async throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        // Insert a universe so seeding is skipped, then insert an orphan episode
        let universe = Universe(name: "Die drei ???")
        context.insert(universe)
        let orphan = Episode(
            episodeNumber: 42,
            title: "Ohne Sammlung",
            releaseYear: 2000,
            universe: nil
        )
        context.insert(orphan)

        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!

        let report = await AppDataBootstrapper.bootstrap(
            container: container,
            usesCloudSync: false,
            userDefaults: defaults
        )

        XCTAssertGreaterThan(report.assignedOrphanEpisodes, 0)
    }

    func testLogDescriptionShowsNoChangesWhenEmpty() {
        let report = BootstrapReport()

        XCTAssertEqual(report.logDescription, "no changes")
    }

    func testLogDescriptionIncludesAllPopulatedFields() {
        var report = BootstrapReport()
        report.seededMoods = true
        report.seededCollections = true
        report.assignedOrphanEpisodes = 3
        report.repairedPostMigrationIDs = 1
        report.cloudMigrationStatus = "completed"

        let description = report.logDescription
        XCTAssertTrue(description.contains("seededMoods"))
        XCTAssertTrue(description.contains("seededCollections"))
        XCTAssertTrue(description.contains("assignedOrphans=3"))
        XCTAssertTrue(description.contains("repairedIDs=1"))
        XCTAssertTrue(description.contains("cloudMigration=completed"))
    }

    func testSecondBootstrapDoesNotReseed() async throws {
        let container = try makeInMemoryContainer()
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!

        // First bootstrap seeds everything
        let firstReport = await AppDataBootstrapper.bootstrap(
            container: container,
            usesCloudSync: false,
            userDefaults: defaults
        )
        XCTAssertTrue(firstReport.seededMoods)
        XCTAssertTrue(firstReport.seededCollections)

        // Second bootstrap should not re-seed
        let secondReport = await AppDataBootstrapper.bootstrap(
            container: container,
            usesCloudSync: false,
            userDefaults: defaults
        )
        XCTAssertFalse(secondReport.seededMoods)
        XCTAssertFalse(secondReport.seededCollections)
    }
}
