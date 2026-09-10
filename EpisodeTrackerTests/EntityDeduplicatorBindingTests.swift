import XCTest
import SwiftData
@testable import EpisodeTracker

@MainActor
final class EntityDeduplicatorBindingTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    /// Makes `name` the dedup keeper by giving it one episode (the sort prefers
    /// the universe with more episodes).
    @discardableResult
    private func universe(
        _ name: String,
        binding: String?,
        episodeCount: Int,
        in context: ModelContext
    ) -> Universe {
        let u = Universe(name: name)
        u.managedCatalogID = binding
        context.insert(u)
        for i in 0..<episodeCount {
            let e = Episode(episodeNumber: i + 1, title: "F\(i + 1)", releaseYear: 2000, universe: u)
            context.insert(e)
        }
        return u
    }

    func testConflictingBindingsKeepBothAndCountTheSkip() throws {
        let context = try makeContext()
        let keeper = universe("TKKG", binding: "tkkg-a", episodeCount: 1, in: context)
        let other = universe("TKKG", binding: "tkkg-b", episodeCount: 0, in: context)

        var summary = SyncPreparation.ChangeSummary()
        let didChange = EntityDeduplicator.deduplicateUniverses(
            [keeper, other], in: context, summary: &summary
        )
        try context.save()

        let universes = try context.fetch(FetchDescriptor<Universe>())
        XCTAssertEqual(universes.count, 2, "conflicting catalog bindings must not be merged")
        XCTAssertEqual(Set(universes.compactMap(\.managedCatalogID)), ["tkkg-a", "tkkg-b"])
        XCTAssertEqual(summary.skippedConflictingBindingMerges, 1)
        XCTAssertEqual(summary.mergedUniverses, 0)
        XCTAssertFalse(didChange, "a skip mutates nothing")
    }

    func testConflictingSkipLeavesTheOtherSideEpisodesAlone() throws {
        let context = try makeContext()
        let keeper = universe("TKKG", binding: "tkkg-a", episodeCount: 1, in: context)
        let other = universe("TKKG", binding: "tkkg-b", episodeCount: 2, in: context)
        // `other` has more episodes, so it would be the keeper — force `keeper`
        // to win by giving it the most.
        for i in 0..<3 {
            context.insert(Episode(episodeNumber: 10 + i, title: "K\(i)", releaseYear: 2001, universe: keeper))
        }

        var summary = SyncPreparation.ChangeSummary()
        _ = EntityDeduplicator.deduplicateUniverses([keeper, other], in: context, summary: &summary)
        try context.save()

        let universes = try context.fetch(FetchDescriptor<Universe>())
        XCTAssertEqual(universes.count, 2)
        let otherAfter = try XCTUnwrap(universes.first { $0.managedCatalogID == "tkkg-b" })
        XCTAssertEqual(otherAfter.episodes.count, 2, "the skipped duplicate keeps its own episodes")
    }

    func testOneSidedBindingIsAdoptedByTheSurvivor() throws {
        let context = try makeContext()
        let keeper = universe("TKKG", binding: nil, episodeCount: 1, in: context)
        let other = universe("TKKG", binding: "tkkg", episodeCount: 0, in: context)

        var summary = SyncPreparation.ChangeSummary()
        let didChange = EntityDeduplicator.deduplicateUniverses(
            [keeper, other], in: context, summary: &summary
        )
        try context.save()

        let universes = try context.fetch(FetchDescriptor<Universe>())
        XCTAssertEqual(universes.count, 1)
        XCTAssertEqual(universes.first?.managedCatalogID, "tkkg", "the survivor adopts the only binding")
        XCTAssertEqual(summary.mergedUniverses, 1)
        XCTAssertEqual(summary.skippedConflictingBindingMerges, 0)
        XCTAssertTrue(didChange)
    }

    func testSurvivorKeepsItsOwnBindingWhenTheDuplicateIsUnbound() throws {
        let context = try makeContext()
        let keeper = universe("TKKG", binding: "tkkg", episodeCount: 1, in: context)
        let other = universe("TKKG", binding: nil, episodeCount: 0, in: context)

        var summary = SyncPreparation.ChangeSummary()
        _ = EntityDeduplicator.deduplicateUniverses([keeper, other], in: context, summary: &summary)
        try context.save()

        let universes = try context.fetch(FetchDescriptor<Universe>())
        XCTAssertEqual(universes.count, 1)
        XCTAssertEqual(universes.first?.managedCatalogID, "tkkg")
        XCTAssertEqual(summary.mergedUniverses, 1)
    }

    func testIdenticalBindingsMergeAsBefore() throws {
        let context = try makeContext()
        let keeper = universe("TKKG", binding: "tkkg", episodeCount: 1, in: context)
        let other = universe("TKKG", binding: "tkkg", episodeCount: 0, in: context)

        var summary = SyncPreparation.ChangeSummary()
        _ = EntityDeduplicator.deduplicateUniverses([keeper, other], in: context, summary: &summary)
        try context.save()

        let universes = try context.fetch(FetchDescriptor<Universe>())
        XCTAssertEqual(universes.count, 1)
        XCTAssertEqual(universes.first?.managedCatalogID, "tkkg")
        XCTAssertEqual(summary.mergedUniverses, 1)
        XCTAssertEqual(summary.skippedConflictingBindingMerges, 0)
    }

    func testUnboundPairStillMergesRegression() throws {
        let context = try makeContext()
        let keeper = universe("TKKG", binding: nil, episodeCount: 1, in: context)
        let other = universe("TKKG", binding: nil, episodeCount: 0, in: context)

        var summary = SyncPreparation.ChangeSummary()
        _ = EntityDeduplicator.deduplicateUniverses([keeper, other], in: context, summary: &summary)
        try context.save()

        let universes = try context.fetch(FetchDescriptor<Universe>())
        XCTAssertEqual(universes.count, 1)
        XCTAssertNil(universes.first?.managedCatalogID)
        XCTAssertEqual(summary.mergedUniverses, 1)
        XCTAssertEqual(summary.skippedConflictingBindingMerges, 0)
    }

    func testChangeSummaryMergeCarriesTheSkipCounter() {
        var a = SyncPreparation.ChangeSummary()
        a.skippedConflictingBindingMerges = 2
        var b = SyncPreparation.ChangeSummary()
        b.skippedConflictingBindingMerges = 3

        a.merge(b)

        XCTAssertEqual(a.skippedConflictingBindingMerges, 5)
        XCTAssertTrue(a.logDescription.contains("skippedConflictingBindingMerges=5"))
        XCTAssertFalse(a.hasChanges, "a skip-only summary reports no changes")
    }
}
