import XCTest
import SwiftData
@testable import EpisodeTracker

@MainActor
final class CatalogBindingReconcilerTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func source(id: String, name: String) -> ManagedCatalogSource {
        ManagedCatalogSource(
            id: id,
            name: name,
            language: "de",
            url: URL(string: "https://example.com/\(id).json")!
        )
    }

    // MARK: - bind(_:to:)

    func testBindSetsIDOnUnboundCollection() throws {
        let context = try makeContext()
        let universe = Universe(name: "Die drei ???")
        context.insert(universe)

        let didBind = CatalogBindingReconciler.bind(universe, to: source(id: "drei-fragezeichen", name: "Die drei ???"))

        XCTAssertTrue(didBind)
        XCTAssertEqual(universe.managedCatalogID, "drei-fragezeichen")
    }

    func testBindIsNoOpWhenAlreadyBoundToSameSource() throws {
        let context = try makeContext()
        let universe = Universe(name: "Die drei ???")
        universe.managedCatalogID = "drei-fragezeichen"
        context.insert(universe)

        let didBind = CatalogBindingReconciler.bind(universe, to: source(id: "drei-fragezeichen", name: "Die drei ???"))

        XCTAssertFalse(didBind)
        XCTAssertEqual(universe.managedCatalogID, "drei-fragezeichen")
    }

    func testBindNeverOverwritesADifferentExistingBinding() throws {
        let context = try makeContext()
        let universe = Universe(name: "Die drei ???")
        universe.managedCatalogID = "legacy-source"
        context.insert(universe)

        let didBind = CatalogBindingReconciler.bind(universe, to: source(id: "drei-fragezeichen", name: "Die drei ???"))

        XCTAssertFalse(didBind)
        XCTAssertEqual(universe.managedCatalogID, "legacy-source", "a frozen binding must not be clobbered")
    }

    // MARK: - reconcile(universes:sources:)

    func testReconcileBindsOnUniqueNameMatch() throws {
        let context = try makeContext()
        let matched = Universe(name: "TKKG")
        let manual = Universe(name: "Meine Sammlung")
        context.insert(matched)
        context.insert(manual)

        let result = CatalogBindingReconciler.reconcile(
            universes: [matched, manual],
            sources: [source(id: "tkkg", name: "TKKG"), source(id: "bibi", name: "Bibi Blocksberg")]
        )

        XCTAssertEqual(matched.managedCatalogID, "tkkg")
        XCTAssertNil(manual.managedCatalogID)
        XCTAssertEqual(result, .init(bound: 1, ambiguous: 0, unmatched: 1))
    }

    func testReconcileMatchesCaseAndWhitespaceInsensitively() throws {
        let context = try makeContext()
        let universe = Universe(name: "  tkkg ")
        context.insert(universe)

        let result = CatalogBindingReconciler.reconcile(
            universes: [universe],
            sources: [source(id: "tkkg", name: "TKKG")]
        )

        XCTAssertEqual(universe.managedCatalogID, "tkkg")
        XCTAssertEqual(result.bound, 1)
    }

    func testReconcileLeavesAmbiguousMatchesUnbound() throws {
        let context = try makeContext()
        let universe = Universe(name: "Sammlung")
        context.insert(universe)

        let result = CatalogBindingReconciler.reconcile(
            universes: [universe],
            sources: [source(id: "one", name: "Sammlung"), source(id: "two", name: " sammlung ")]
        )

        XCTAssertNil(universe.managedCatalogID)
        XCTAssertEqual(result, .init(bound: 0, ambiguous: 1, unmatched: 0))
    }

    func testReconcileNeverTouchesAlreadyBoundCollections() throws {
        let context = try makeContext()
        let universe = Universe(name: "TKKG")
        universe.managedCatalogID = "legacy-source"
        context.insert(universe)

        let result = CatalogBindingReconciler.reconcile(
            universes: [universe],
            sources: [source(id: "tkkg", name: "TKKG")]
        )

        XCTAssertEqual(universe.managedCatalogID, "legacy-source")
        XCTAssertEqual(result, .init(bound: 0, ambiguous: 0, unmatched: 0))
    }

    func testReconcileIsNoOpWithoutSources() throws {
        let context = try makeContext()
        let universe = Universe(name: "TKKG")
        context.insert(universe)

        let result = CatalogBindingReconciler.reconcile(universes: [universe], sources: [])

        XCTAssertNil(universe.managedCatalogID)
        XCTAssertEqual(result, .init())
    }

    func testReconcileIsIdempotentOnASecondRun() throws {
        let context = try makeContext()
        let universe = Universe(name: "TKKG")
        context.insert(universe)
        let sources = [source(id: "tkkg", name: "TKKG")]

        _ = CatalogBindingReconciler.reconcile(universes: [universe], sources: sources)
        let second = CatalogBindingReconciler.reconcile(universes: [universe], sources: sources)

        XCTAssertEqual(universe.managedCatalogID, "tkkg")
        XCTAssertEqual(second, .init(bound: 0, ambiguous: 0, unmatched: 0), "already-bound on the second pass")
    }

    // MARK: - Bootstrap adoption gate

    func testAdoptCatalogBindingsRunsOnceThenSkips() async throws {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        let suite = "CatalogBindingAdoption-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        // A collection named like a real shipping catalog, still unbound.
        let context = container.mainContext
        let universe = Universe(name: CatalogSourceRegistry.allKnownSources.first?.name ?? "Die drei ???")
        context.insert(universe)
        try context.save()

        AppDataBootstrapper.adoptCatalogBindingsIfNeeded(container: container, userDefaults: defaults)

        XCTAssertNotNil(universe.managedCatalogID, "an unambiguous name match is bound on the first run")
        XCTAssertTrue(defaults.bool(forKey: AppDataBootstrapper.catalogBindingAdoptionKey))

        // Second run must not re-touch a manually re-cleared binding.
        universe.managedCatalogID = nil
        try context.save()
        AppDataBootstrapper.adoptCatalogBindingsIfNeeded(container: container, userDefaults: defaults)

        XCTAssertNil(universe.managedCatalogID, "the flag makes the second run a no-op")
    }
}
