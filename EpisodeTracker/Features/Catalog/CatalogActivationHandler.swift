import Foundation
import SwiftData

/// The single-source refresh `CatalogActivationHandler` needs. `EpisodeCatalog`
/// already provides `refreshManagedCatalog(universeName:force:)`; the protocol
/// exists so tests can inject a spy instead of hitting the network.
@MainActor
protocol ManagedCatalogRefreshing: AnyObject {
    func refreshManagedCatalog(universeName: String, force: Bool) async -> CatalogRefreshOutcome
}

extension EpisodeCatalog: ManagedCatalogRefreshing {}

/// Owns "activate a managed catalog" for `CatalogManagementView`:
///
/// 1. bind the collection to the source (P3-B rules — never clobber a different
///    existing binding), creating a collection when none matches by name;
/// 2. kick off exactly one immediate single-source catalog download;
/// 3. track per-source progress so the row can show a spinner, or an error plus
///    "Erneut versuchen".
///
/// A failed fetch never rolls the activation back (spec §4.A / D6) — this type
/// does not touch `ActiveCatalogStore` at all; the view flips the active flag
/// before calling `activate`.
@MainActor
@Observable
final class CatalogActivationHandler {

    enum State: Equatable {
        case idle
        case running
        case failed(String)
    }

    private let refresher: any ManagedCatalogRefreshing
    private(set) var states: [String: State] = [:]
    /// The in-flight refresh per source. Exposed only so tests can await a
    /// refresh deterministically; the view never reads it.
    private(set) var refreshTasks: [String: Task<Void, Never>] = [:]
    /// Captured from the `modelContext` passed to `activate`, so `retry` (which
    /// only gets the source) can still run the post-refresh reconciliation.
    private var lastContainer: ModelContainer?

    init(refresher: any ManagedCatalogRefreshing = EpisodeCatalog.shared) {
        self.refresher = refresher
    }

    func state(for sourceID: String) -> State {
        states[sourceID] ?? .idle
    }

    /// Binds `source` to a collection and starts its first catalog download.
    /// The fetch is a no-op while one is already in flight for this source, so
    /// repeated taps do not stack requests.
    func activate(
        source: ManagedCatalogSource,
        modelContext: ModelContext,
        existingUniverses: [Universe]
    ) {
        lastContainer = modelContext.container
        bind(source: source, modelContext: modelContext, existingUniverses: existingUniverses)
        startRefresh(sourceID: source.id, sourceName: source.name)
    }

    /// Re-runs only the fetch (the binding already exists) — the row's
    /// "Erneut versuchen" action.
    func retry(source: ManagedCatalogSource) {
        startRefresh(sourceID: source.id, sourceName: source.name)
    }

    private func bind(
        source: ManagedCatalogSource,
        modelContext: ModelContext,
        existingUniverses: [Universe]
    ) {
        let key = CatalogLibraryMatcher.normalizedCollectionKey(source.name)
        if let existing = existingUniverses.first(where: {
            CatalogLibraryMatcher.normalizedCollectionKey($0.name) == key
        }) {
            CatalogBindingReconciler.bind(existing, to: source)
        } else {
            let universe = Universe(name: source.name)
            universe.style = source.effectiveStyle
            universe.managedCatalogID = source.id
            modelContext.insert(universe)
        }
    }

    private func startRefresh(sourceID: String, sourceName: String) {
        guard state(for: sourceID) != .running else { return }
        states[sourceID] = .running
        refreshTasks[sourceID] = Task {
            let outcome = await refresher.refreshManagedCatalog(universeName: sourceName, force: true)
            if let lastContainer {
                AppDataBootstrapper.reconcileAfterCatalogRefresh(container: lastContainer)
            }
            states[sourceID] = Self.resultState(from: outcome, sourceID: sourceID, sourceName: sourceName)
        }
    }

    /// Pure classification of a refresh outcome for one source. Directory failure
    /// and a failed source result both surface an error; an updated / not-modified
    /// source, or one the run never reached without a directory failure, is back
    /// to `idle`.
    static func resultState(
        from outcome: CatalogRefreshOutcome,
        sourceID: String,
        sourceName: String
    ) -> State {
        if outcome.sources.contains(where: { $0.id == sourceID && $0.didFail }) {
            return .failed(AppLocalization.format(
                "Catalog.RefreshSingleFailure",
                defaultValue: "Katalog „%@“ nicht aktualisierbar.",
                sourceName
            ))
        }
        if outcome.sources.contains(where: { $0.id == sourceID }) {
            return .idle
        }
        if outcome.manifestFailed {
            return .failed(AppLocalization.format(
                "Catalog.DirectoryUnreachable",
                defaultValue: "Katalogverzeichnis nicht erreichbar."
            ))
        }
        return .idle
    }
}
