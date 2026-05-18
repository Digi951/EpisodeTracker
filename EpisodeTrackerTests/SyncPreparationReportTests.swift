import XCTest
import SwiftData
@testable import EpisodeTracker

@MainActor
final class SyncPreparationReportTests: XCTestCase {

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func testPrepareReturnsEmptySummaryWhenNoRepairsNeeded() throws {
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

        let summary = SyncPreparation.prepare(context: context)

        XCTAssertEqual(summary.repairedEpisodeIDs, 0)
        XCTAssertEqual(summary.repairedMoodIDs, 0)
        XCTAssertEqual(summary.repairedUniverseIDs, 0)
        XCTAssertEqual(summary.mergedMoods, 0)
        XCTAssertEqual(summary.mergedUniverses, 0)
        XCTAssertEqual(summary.deduplicatedEpisodes, 0)
        XCTAssertEqual(summary.refreshedEpisodeSyncKeys, 0)
        XCTAssertEqual(summary.deduplicatedEpisodeMoods, 0)
        XCTAssertFalse(summary.hasChanges)
    }

    func testPrepareReportsDuplicateMoodMerge() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        // Two moods with same name but different case — should be merged
        let mood1 = Mood(name: "Spannend", iconName: nil)
        let mood2 = Mood(name: "spannend", iconName: nil)
        context.insert(mood1)
        context.insert(mood2)
        try context.save()

        let summary = SyncPreparation.prepare(context: context)

        XCTAssertEqual(summary.mergedMoods, 1)
        XCTAssertTrue(summary.hasChanges)
    }
}
