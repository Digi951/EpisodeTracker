import Foundation

/// Fills `Universe.managedCatalogID` so a collection is tied to a specific
/// managed catalog source rather than matched by normalized name every time.
///
/// Two entry points, both pure and idempotent:
/// - `bind(_:to:)` — used when the user activates a catalog: bind the collection
///   unless it already carries a *different* binding (a frozen identity).
/// - `reconcile(universes:sources:)` — the one-time V9 adoption backfill: bind a
///   still-unbound collection only when its normalized name matches **exactly
///   one** known source. Ambiguous or unmatched collections stay unbound.
enum CatalogBindingReconciler {

    struct Result: Equatable {
        var bound = 0
        var ambiguous = 0
        var unmatched = 0
    }

    /// Binds `universe` to `source` when it has no binding yet. A collection that
    /// already points at a different source is left untouched — its identity is
    /// frozen, the same way a special episode keeps its catalog slug. Returns
    /// `true` only when it actually wrote a new binding.
    @discardableResult
    static func bind(_ universe: Universe, to source: ManagedCatalogSource) -> Bool {
        guard universe.managedCatalogID == nil else { return false }
        universe.managedCatalogID = source.id
        return true
    }

    /// Adopts bindings for unbound collections whose normalized name matches
    /// exactly one entry in `sources`. Already-bound collections are never
    /// touched; ambiguous (two sources share a normalized name) and unmatched
    /// collections stay unbound and are only counted.
    @discardableResult
    static func reconcile(universes: [Universe], sources: [ManagedCatalogSource]) -> Result {
        var result = Result()
        guard !sources.isEmpty else { return result }

        var sourceIDsByName: [String: Set<String>] = [:]
        for source in sources {
            let key = CatalogLibraryMatcher.normalizedCollectionKey(source.name)
            guard !key.isEmpty else { continue }
            sourceIDsByName[key, default: []].insert(source.id)
        }

        for universe in universes where universe.managedCatalogID == nil {
            let key = CatalogLibraryMatcher.normalizedCollectionKey(universe.name)
            guard let ids = sourceIDsByName[key], !ids.isEmpty else {
                result.unmatched += 1
                continue
            }
            guard ids.count == 1, let id = ids.first else {
                result.ambiguous += 1
                continue
            }
            universe.managedCatalogID = id
            result.bound += 1
        }

        return result
    }
}
