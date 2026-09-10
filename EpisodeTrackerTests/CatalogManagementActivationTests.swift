import XCTest
import SwiftData
@testable import EpisodeTracker

@MainActor
final class CatalogManagementActivationTests: XCTestCase {

    // MARK: - Test doubles

    /// Records every call and hands back a scripted outcome. Can optionally block
    /// until `release()` so a test can observe the `.running` state.
    private final class SpyRefresher: ManagedCatalogRefreshing {
        private(set) var calls: [String] = []
        var outcome: CatalogRefreshOutcome = CatalogRefreshOutcome()
        private var gate: CheckedContinuation<Void, Never>?
        var blocks = false

        var callCount: Int { calls.count }

        func refreshManagedCatalog(universeName: String, force: Bool) async -> CatalogRefreshOutcome {
            calls.append(universeName)
            if blocks {
                await withCheckedContinuation { gate = $0 }
            }
            return outcome
        }

        func release() {
            gate?.resume()
            gate = nil
        }
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func source(id: String = "tkkg", name: String = "TKKG") -> ManagedCatalogSource {
        ManagedCatalogSource(
            id: id,
            name: name,
            language: "de",
            url: URL(string: "https://example.com/\(id).json")!
        )
    }

    private func successOutcome(id: String, name: String) -> CatalogRefreshOutcome {
        CatalogRefreshOutcome(sources: [
            .init(id: id, name: name, status: .updated, lastAttemptAt: .now, lastSuccessAt: .now)
        ])
    }

    private func failureOutcome(id: String, name: String) -> CatalogRefreshOutcome {
        CatalogRefreshOutcome(sources: [
            .init(id: id, name: name, status: .failed(.http(status: 500)), lastAttemptAt: .now, lastSuccessAt: nil)
        ])
    }

    // MARK: - Fetch is triggered exactly once

    func testActivateTriggersExactlyOneSingleSourceRefresh() async throws {
        let spy = SpyRefresher()
        let src = source()
        spy.outcome = successOutcome(id: src.id, name: src.name)
        let handler = CatalogActivationHandler(refresher: spy)
        let context = try makeContext()

        handler.activate(source: src, modelContext: context, existingUniverses: [])
        await handler.refreshTasks[src.id]?.value

        XCTAssertEqual(spy.calls, ["TKKG"])
        XCTAssertEqual(handler.state(for: src.id), .idle)
    }

    func testRepeatedActivationWhileRunningDoesNotStackFetches() async throws {
        let spy = SpyRefresher()
        spy.blocks = true
        let src = source()
        spy.outcome = successOutcome(id: src.id, name: src.name)
        let handler = CatalogActivationHandler(refresher: spy)
        let context = try makeContext()

        handler.activate(source: src, modelContext: context, existingUniverses: [])
        // Let the first refresh task reach the blocking await.
        for _ in 0..<100 where spy.callCount == 0 { await Task.yield() }
        XCTAssertEqual(spy.callCount, 1)

        handler.activate(source: src, modelContext: context, existingUniverses: [])
        handler.retry(source: src)

        XCTAssertEqual(handler.state(for: src.id), .running)
        XCTAssertEqual(spy.callCount, 1, "a second tap while one fetch runs must not start another")

        spy.release()
        await handler.refreshTasks[src.id]?.value
        XCTAssertEqual(handler.state(for: src.id), .idle)
    }

    // MARK: - Failure keeps the activation

    func testFailedOutcomeSetsFailedStateWithoutTouchingActiveStore() async throws {
        let suite = "activation-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let activeStore = ActiveCatalogStore(userDefaults: defaults)
        activeStore.activeIDs = ["tkkg"]

        let spy = SpyRefresher()
        let src = source()
        spy.outcome = failureOutcome(id: src.id, name: src.name)
        let handler = CatalogActivationHandler(refresher: spy)
        let context = try makeContext()

        handler.activate(source: src, modelContext: context, existingUniverses: [])
        await handler.refreshTasks[src.id]?.value

        switch handler.state(for: src.id) {
        case .failed(let message):
            XCTAssertFalse(message.isEmpty)
        default:
            XCTFail("expected .failed, got \(handler.state(for: src.id))")
        }
        XCTAssertEqual(activeStore.activeIDs, ["tkkg"], "a failed fetch does not roll back the activation")
    }

    func testRetryReRunsTheFetchAfterAFailure() async throws {
        let spy = SpyRefresher()
        let src = source()
        spy.outcome = failureOutcome(id: src.id, name: src.name)
        let handler = CatalogActivationHandler(refresher: spy)
        let context = try makeContext()

        handler.activate(source: src, modelContext: context, existingUniverses: [])
        await handler.refreshTasks[src.id]?.value

        spy.outcome = successOutcome(id: src.id, name: src.name)
        handler.retry(source: src)
        await handler.refreshTasks[src.id]?.value

        XCTAssertEqual(spy.callCount, 2)
        XCTAssertEqual(handler.state(for: src.id), .idle)
    }

    // MARK: - Binding side effect

    func testActivateBindsAnExistingCollectionAndCreatesOneWhenMissing() async throws {
        let spy = SpyRefresher()
        let context = try makeContext()
        let existing = Universe(name: "TKKG")
        context.insert(existing)

        let tkkg = source(id: "tkkg", name: "TKKG")
        let bibi = source(id: "bibi-blocksberg", name: "Bibi Blocksberg")
        spy.outcome = CatalogRefreshOutcome()
        let handler = CatalogActivationHandler(refresher: spy)

        handler.activate(source: tkkg, modelContext: context, existingUniverses: [existing])
        handler.activate(source: bibi, modelContext: context, existingUniverses: [existing])
        await handler.refreshTasks["tkkg"]?.value
        await handler.refreshTasks["bibi-blocksberg"]?.value

        XCTAssertEqual(existing.managedCatalogID, "tkkg", "the name-matched collection is bound")

        let all = try context.fetch(FetchDescriptor<Universe>())
        let created = all.first { $0.name == "Bibi Blocksberg" }
        XCTAssertEqual(created?.managedCatalogID, "bibi-blocksberg", "a missing collection is created and bound")
        XCTAssertEqual(created?.style, bibi.effectiveStyle)
    }

    func testActivateNeverClobbersADifferentExistingBinding() async throws {
        let spy = SpyRefresher()
        let context = try makeContext()
        let existing = Universe(name: "TKKG")
        existing.managedCatalogID = "legacy-source"
        context.insert(existing)

        let src = source(id: "tkkg", name: "TKKG")
        spy.outcome = CatalogRefreshOutcome()
        let handler = CatalogActivationHandler(refresher: spy)

        handler.activate(source: src, modelContext: context, existingUniverses: [existing])
        await handler.refreshTasks[src.id]?.value

        XCTAssertEqual(existing.managedCatalogID, "legacy-source")
    }

    // MARK: - Pure outcome classification

    func testResultStateClassification() {
        let updated = CatalogRefreshOutcome(sources: [
            .init(id: "a", name: "A", status: .updated, lastAttemptAt: .now, lastSuccessAt: .now)
        ])
        XCTAssertEqual(
            CatalogActivationHandler.resultState(from: updated, sourceID: "a", sourceName: "A"),
            .idle
        )

        let failed = CatalogRefreshOutcome(sources: [
            .init(id: "a", name: "A", status: .failed(.notHTTP), lastAttemptAt: .now, lastSuccessAt: nil)
        ])
        if case .failed = CatalogActivationHandler.resultState(from: failed, sourceID: "a", sourceName: "A") {} else {
            XCTFail("a failed source result must map to .failed")
        }

        let manifestDown = CatalogRefreshOutcome(
            manifest: .init(id: "m", name: "Verzeichnis", status: .failed(.http(status: 503)), lastAttemptAt: .now, lastSuccessAt: nil),
            sources: []
        )
        if case .failed = CatalogActivationHandler.resultState(from: manifestDown, sourceID: "a", sourceName: "A") {} else {
            XCTFail("a directory failure before the source is fetched must surface as .failed")
        }

        let throttled = CatalogRefreshOutcome(sources: [])
        XCTAssertEqual(
            CatalogActivationHandler.resultState(from: throttled, sourceID: "a", sourceName: "A"),
            .idle,
            "a source the run never reached, with a healthy directory, is not an error"
        )
    }
}
