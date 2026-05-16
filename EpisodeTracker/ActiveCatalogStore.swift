import Foundation

struct ActiveCatalogStore {
    private static let key = "activeCatalogIDs"

    var activeIDs: Set<String> {
        get {
            let stored = UserDefaults.standard.stringArray(forKey: Self.key)
            guard let stored else { return defaultActiveIDs() }
            return Set(stored)
        }
        nonmutating set {
            UserDefaults.standard.set(Array(newValue).sorted(), forKey: Self.key)
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

    /// First launch: activate all catalogs that have a matching Universe with episodes.
    private func defaultActiveIDs() -> Set<String> {
        Set(CatalogSourceRegistry.managedSources.map(\.id))
    }
}
