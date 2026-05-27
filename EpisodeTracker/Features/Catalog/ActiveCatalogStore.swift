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
        let visibleIDs = Set(CatalogSourceRegistry.managedSources.map(\.id))
        let currentIDs = activeIDs
        let orphaned = currentIDs.subtracting(visibleIDs)
        guard !orphaned.isEmpty else { return [] }
        activeIDs = currentIDs.intersection(visibleIDs)
        return orphaned.sorted()
    }

    private func defaultActiveIDs() -> Set<String> {
        Set(CatalogSourceRegistry.managedSources.map(\.id))
    }
}
