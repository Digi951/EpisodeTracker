import Foundation

struct ActiveCatalogStore {
    private static let key = "activeCatalogIDs"
    private let defaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    var activeIDs: Set<String> {
        get {
            let stored = defaults.stringArray(forKey: Self.key)
            guard let stored else { return defaultActiveIDs() }
            return Set(stored)
        }
        nonmutating set {
            defaults.set(Array(newValue).sorted(), forKey: Self.key)
        }
    }

    func isActive(_ catalogID: String) -> Bool {
        activeIDs.contains(catalogID)
    }

    func setActive(_ catalogID: String, active: Bool) {
        var ids = activeIDs
        if active {
            ids.insert(catalogID)
        } else {
            ids.remove(catalogID)
        }
        activeIDs = ids
    }

    func pruneOrphanedIDs() -> [String] {
        pruneOrphanedIDs(knownIDs: Set(CatalogSourceRegistry.allKnownSources.map(\.id)))
    }

    /// Testable seam. `knownIDs` is the **full registry** (`allKnownSources`),
    /// not the language-filtered visible set: a catalog that is only hidden by
    /// the catalog-language filter must survive here, and only a catalog that is
    /// genuinely gone from the manifest gets pruned.
    func pruneOrphanedIDs(knownIDs: Set<String>) -> [String] {
        let currentIDs = activeIDs
        let orphaned = currentIDs.subtracting(knownIDs)
        guard !orphaned.isEmpty else { return [] }
        activeIDs = currentIDs.intersection(knownIDs)
        return orphaned.sorted()
    }

    /// Fresh-install default: activate the sources the user can currently see,
    /// i.e. their catalog languages — not every language in the registry.
    private func defaultActiveIDs() -> Set<String> {
        Set(CatalogSourceRegistry.visibleSources.map(\.id))
    }
}
