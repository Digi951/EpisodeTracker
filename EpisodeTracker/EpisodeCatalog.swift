import Foundation

@MainActor
final class EpisodeCatalog {
    static let shared = EpisodeCatalog()

    private var entries: [CatalogEntry] = []
    private let parser: CatalogParser
    private let cacheStore: CatalogCacheStore
    private let remoteDataSource: CatalogRemoteDataSource

    init() {
        parser = CatalogParser()
        cacheStore = CatalogCacheStore()
        remoteDataSource = CatalogRemoteDataSource()
        reload()
    }

    func reload() {
        entries = loadManagedEntriesFromCacheOrFallback() + cacheStore.loadCustomEntries()
    }

    func entry(for number: Int, in collectionName: String?) -> CatalogEntry? {
        guard let key = collectionName?.lowercased(), !key.isEmpty else { return nil }
        return entries.reversed().first(where: {
            $0.number == number && $0.collectionName?.lowercased() == key
        })
    }

    @discardableResult
    func importCatalog(data: Data, into collectionName: String) throws -> Int {
        let parsedEntries = try parser.parseCatalogEntries(from: data, fallbackCollectionName: collectionName)
        let normalizedEntries = parsedEntries.map {
            CatalogEntry(
                number: $0.number,
                title: $0.title,
                releaseYear: $0.releaseYear,
                collectionName: collectionName
            )
        }
        try cacheStore.replaceCustomCatalog(collectionName: collectionName, entries: normalizedEntries)
        reload()
        return normalizedEntries.count
    }

    @discardableResult
    func importCatalog(from endpointURL: URL, into collectionName: String) async throws -> Int {
        let (data, _) = try await URLSession.shared.data(from: endpointURL)
        return try importCatalog(data: data, into: collectionName)
    }

    func refreshManagedCatalogsIfNeeded(force: Bool = false) async {
        for source in CatalogSourceRegistry.managedSources {
            await refreshManagedCatalogIfNeeded(source: source, force: force)
        }
        reload()
    }

    func refreshManagedCatalog(universeName: String, force: Bool = true) async {
        guard let source = CatalogSourceRegistry.managedSources.first(where: {
            $0.name.caseInsensitiveCompare(universeName) == .orderedSame
        }) else {
            return
        }

        await refreshManagedCatalogIfNeeded(source: source, force: force)
        reload()
    }

    private func refreshManagedCatalogIfNeeded(source: ManagedCatalogSource, force: Bool) async {
        let previousMetadata = cacheStore.loadRemoteMetadata(universeName: source.name)
        guard force || shouldRefresh(previousMetadata) else { return }

        do {
            let result = try await remoteDataSource.fetch(from: source, metadata: previousMetadata)
            var metadata = previousMetadata ?? RemoteCatalogMetadata()

            switch result {
            case .updated(let data, let eTag, let lastModified):
                let parsedEntries = try parser.parseCatalogEntries(from: data, fallbackCollectionName: source.name)
                let normalizedEntries = parsedEntries.map {
                    CatalogEntry(
                        number: $0.number,
                        title: $0.title,
                        releaseYear: $0.releaseYear,
                        collectionName: source.name
                    )
                }
                try cacheStore.saveRemoteCache(entries: normalizedEntries, universeName: source.name)

                metadata.eTag = eTag
                metadata.lastModified = lastModified
                metadata.lastCheckedAt = .now
                try cacheStore.saveRemoteMetadata(metadata, universeName: source.name)

            case .notModified, .skipped:
                metadata.lastCheckedAt = .now
                try cacheStore.saveRemoteMetadata(metadata, universeName: source.name)
            }
        } catch {
            // Keep existing cache/fallback data when network refresh fails.
        }
    }

    private func loadManagedEntriesFromCacheOrFallback() -> [CatalogEntry] {
        var result: [CatalogEntry] = []

        for source in CatalogSourceRegistry.managedSources {
            if let cachedEntries = cacheStore.loadRemoteCache(universeName: source.name) {
                result.append(contentsOf: cachedEntries)
            } else if source.name == CatalogSourceRegistry.bundledCollectionName {
                result.append(contentsOf: cacheStore.loadBundledFallbackEntries())
            }
        }

        return result
    }

    private func shouldRefresh(_ metadata: RemoteCatalogMetadata?) -> Bool {
        guard let metadata,
              let lastCheckedAt = metadata.lastCheckedAt
        else {
            return true
        }

        return Date().timeIntervalSince(lastCheckedAt) > 60 * 60 * 6
    }
}
