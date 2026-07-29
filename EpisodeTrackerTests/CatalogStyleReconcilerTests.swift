import XCTest
import SwiftData
@testable import EpisodeTracker

@MainActor
final class CatalogStyleReconcilerTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func source(name: String, style: String?) -> ManagedCatalogSource {
        ManagedCatalogSource(
            id: name.lowercased(),
            name: name,
            language: "de",
            style: style,
            url: URL(string: "https://example.com/\(name).json")!
        )
    }

    func testAppliesAnthologyStyleFromManifest() throws {
        let context = try makeContext()
        let universe = Universe(name: "Teatr Polskiego Radia")
        context.insert(universe)

        CatalogStyleReconciler.reconcile(
            universes: [universe],
            sources: [source(name: "Teatr Polskiego Radia", style: "anthology")]
        )

        XCTAssertEqual(universe.style, .anthology)
    }

    func testMatchesCollectionNameCaseInsensitively() throws {
        let context = try makeContext()
        let universe = Universe(name: "teatr polskiego radia")
        context.insert(universe)

        CatalogStyleReconciler.reconcile(
            universes: [universe],
            sources: [source(name: "Teatr Polskiego Radia", style: "anthology")]
        )

        XCTAssertEqual(universe.style, .anthology)
    }

    func testLeavesManualCollectionsUntouched() throws {
        let context = try makeContext()
        let universe = Universe(name: "Meine eigene Sammlung")
        context.insert(universe)

        CatalogStyleReconciler.reconcile(
            universes: [universe],
            sources: [source(name: "Teatr Polskiego Radia", style: "anthology")]
        )

        XCTAssertEqual(universe.style, .numbered)
    }

    func testResetsStyleWhenManifestSwitchesBackToNumbered() throws {
        let context = try makeContext()
        let universe = Universe(name: "Wechselkatalog")
        universe.style = .anthology
        context.insert(universe)

        CatalogStyleReconciler.reconcile(
            universes: [universe],
            sources: [source(name: "Wechselkatalog", style: "numbered")]
        )

        XCTAssertEqual(universe.style, .numbered)
    }

    func testIsNoOpWithoutSources() throws {
        let context = try makeContext()
        let universe = Universe(name: "Die drei ???")
        universe.style = .anthology
        context.insert(universe)

        CatalogStyleReconciler.reconcile(universes: [universe], sources: [])

        XCTAssertEqual(universe.style, .anthology)
    }

    // MARK: - Dedupe

    func testDeduplicationKeepsDeclaredAnthologyStyle() throws {
        let context = try makeContext()

        let winner = Universe(name: "Teatr Polskiego Radia")
        let loser = Universe(name: "Teatr Polskiego Radia")
        loser.style = .anthology
        context.insert(winner)
        context.insert(loser)

        EntityDeduplicator.mergeUniverseStyle(from: loser, into: winner)

        XCTAssertEqual(winner.style, .anthology)
    }

    func testDeduplicationDoesNotDowngradeAnthologyToNumbered() throws {
        let context = try makeContext()

        let winner = Universe(name: "Teatr Polskiego Radia")
        winner.style = .anthology
        let loser = Universe(name: "Teatr Polskiego Radia")
        context.insert(winner)
        context.insert(loser)

        EntityDeduplicator.mergeUniverseStyle(from: loser, into: winner)

        XCTAssertEqual(winner.style, .anthology)
    }
}
