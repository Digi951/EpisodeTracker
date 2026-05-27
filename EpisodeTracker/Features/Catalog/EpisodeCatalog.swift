import Foundation

@MainActor @Observable
final class EpisodeCatalog {
    static let shared = EpisodeCatalog()

    private var entries: [CatalogEntry] = []
    private let parser: CatalogParser
    private let cacheStore: CatalogCacheStore
    private let remoteDataSource: any CatalogFetching
    private(set) var lastRefreshError: String?
    private(set) var newCatalogAvailability: NewCatalogAvailability?
    private(set) var removedCatalogBanner: CatalogUpdateBannerRecommendation?

    init() {
        parser = CatalogParser()
        cacheStore = CatalogCacheStore()
        remoteDataSource = CatalogRemoteDataSource()
        newCatalogAvailability = cacheStore.loadNewCatalogAvailability()
        reload()
    }

    init(cacheStore: CatalogCacheStore, remoteDataSource: any CatalogFetching = CatalogRemoteDataSource()) {
        self.parser = CatalogParser()
        self.cacheStore = cacheStore
        self.remoteDataSource = remoteDataSource
        self.newCatalogAvailability = cacheStore.loadNewCatalogAvailability()
        reload()
    }

    func reload() {
        entries = loadManagedEntriesFromCacheOrFallback() + cacheStore.loadCustomEntries()
    }

    var allEntries: [CatalogEntry] {
        entries
    }

    var managedSources: [ManagedCatalogSource] {
        CatalogSourceRegistry.deduplicatedManagedSources(
            cacheStore.loadManifest()?.catalogs ?? CatalogSourceRegistry.fallbackManagedSources
        )
    }

    var catalogEpisodeDeltas: [CatalogEpisodeDelta] {
        cacheStore.loadCatalogEpisodeDeltas()
    }

    func updateNewCatalogAvailability(_ availability: NewCatalogAvailability?) {
        newCatalogAvailability = availability
        if let availability {
            try? cacheStore.saveNewCatalogAvailability(availability)
        } else {
            try? cacheStore.clearNewCatalogAvailability()
        }
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
                collectionName: collectionName,
                spotifyURL: $0.spotifyURL,
                appleMusicURL: $0.appleMusicURL,
                deezerURL: $0.deezerURL,
                audibleURL: $0.audibleURL
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
        lastRefreshError = nil
        await refreshManifestIfNeeded(force: force)
        pruneOrphanedCatalogs()

        let activeCatalogIDs = ActiveCatalogStore().activeIDs
        for source in managedSources where activeCatalogIDs.contains(source.id) {
            await refreshManagedCatalogIfNeeded(source: source, force: force)
        }
        reload()
    }

    func refreshManagedCatalog(universeName: String, force: Bool = true) async {
        await refreshManifestIfNeeded(force: force)

        guard let source = managedSources.first(where: {
            $0.name.caseInsensitiveCompare(universeName) == .orderedSame
        }) else {
            return
        }

        await refreshManagedCatalogIfNeeded(source: source, force: force)
        reload()
    }

    private func refreshManifestIfNeeded(force: Bool) async {
        let previousMetadata = cacheStore.loadRemoteMetadata(universeName: CatalogSourceRegistry.manifestMetadataKey)
        guard force || shouldRefresh(previousMetadata) || cacheStore.loadManifest() == nil else { return }

        do {
            let previousSources = cacheStore.loadManifest()?.catalogs ?? CatalogSourceRegistry.fallbackManagedSources
            let result = try await remoteDataSource.fetch(
                from: CatalogSourceRegistry.manifestURL,
                metadata: previousMetadata
            )
            var metadata = previousMetadata ?? RemoteCatalogMetadata()

            switch result {
            case .updated(let data, let eTag, let lastModified):
                let manifest = try parser.parseManifest(from: data)
                let filteredCatalogs = manifest.catalogs.filter(\.matchesDeviceLanguage)
                let newSources = newCatalogSources(in: filteredCatalogs, previousSources: previousSources)
                updateNewCatalogAvailability(newSources.isEmpty ? nil : NewCatalogAvailability(sources: newSources))
                try cacheStore.saveManifest(manifest)
                metadata.eTag = eTag
                metadata.lastModified = lastModified
                metadata.lastCheckedAt = .now
                try cacheStore.saveRemoteMetadata(metadata, universeName: CatalogSourceRegistry.manifestMetadataKey)

            case .notModified, .skipped:
                metadata.lastCheckedAt = .now
                try cacheStore.saveRemoteMetadata(metadata, universeName: CatalogSourceRegistry.manifestMetadataKey)
            }
        } catch {
            lastRefreshError = "Katalogverzeichnis nicht erreichbar."
        }
    }

    func refreshManagedCatalogIfNeeded(source: ManagedCatalogSource, force: Bool) async {
        let previousMetadata = cacheStore.loadRemoteMetadata(universeName: source.name, cacheKey: source.id)
        let cachedEntries = cacheStore.loadRemoteCache(universeName: source.name, cacheKey: source.id)
        let hasCachedEntries = cachedEntries?.isEmpty == false
        let hasStreamingLinks = cachedEntries?.contains(where: \.hasStreamingLink) == true
        let hasDeezerLinks = cachedEntries?.contains { entry in
            entry.deezerURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        } == true
        let needsStreamingLinkRefresh = hasCachedEntries && !hasStreamingLinks
        let needsDeezerLinkRefresh = hasCachedEntries && hasStreamingLinks && !hasDeezerLinks
        guard force || !hasCachedEntries || needsStreamingLinkRefresh || needsDeezerLinkRefresh || shouldRefresh(previousMetadata) else { return }

        do {
            let requestMetadata = force || needsStreamingLinkRefresh || needsDeezerLinkRefresh ? nil : previousMetadata
            let result = try await remoteDataSource.fetch(from: source, metadata: requestMetadata)
            var metadata = previousMetadata ?? RemoteCatalogMetadata()

            switch result {
            case .updated(let data, let eTag, let lastModified):
                let document = try parser.parseNormalizedCatalogDocument(from: data, fallbackCollectionName: source.name)
                let normalizedEntries = document.entries.map {
                    CatalogEntry(
                        number: $0.number,
                        title: $0.title,
                        releaseYear: $0.releaseYear,
                        collectionName: source.name,
                        spotifyURL: $0.spotifyURL,
                        appleMusicURL: $0.appleMusicURL,
                        deezerURL: $0.deezerURL,
                        audibleURL: $0.audibleURL
                    )
                }
                let previousSnapshot = cacheStore.loadCatalogSnapshot(universeName: source.name, cacheKey: source.id)
                let currentSnapshot = CatalogSnapshot(
                    catalogID: source.id,
                    name: source.name,
                    version: document.version,
                    lastUpdated: document.lastUpdated,
                    entryCount: document.entryCount,
                    episodeNumbers: normalizedEntries.map(\.number)
                )
                if let delta = CatalogEpisodeDelta.make(
                    previous: previousSnapshot,
                    current: currentSnapshot,
                    entries: normalizedEntries
                ) {
                    try cacheStore.saveCatalogEpisodeDelta(delta)
                } else {
                    try cacheStore.clearCatalogEpisodeDelta(catalogID: source.id)
                }
                try cacheStore.saveRemoteCache(entries: normalizedEntries, universeName: source.name, cacheKey: source.id)
                try cacheStore.saveCatalogSnapshot(currentSnapshot, universeName: source.name, cacheKey: source.id)

                metadata.eTag = eTag
                metadata.lastModified = lastModified
                metadata.lastCheckedAt = .now
                try cacheStore.saveRemoteMetadata(metadata, universeName: source.name, cacheKey: source.id)

            case .notModified, .skipped:
                metadata.lastCheckedAt = .now
                try cacheStore.saveRemoteMetadata(metadata, universeName: source.name, cacheKey: source.id)
            }
        } catch {
            lastRefreshError = "Katalog \(source.name) nicht aktualisierbar."
        }
    }

    private func loadManagedEntriesFromCacheOrFallback() -> [CatalogEntry] {
        var result: [CatalogEntry] = []

        for source in managedSources {
            if let cachedEntries = cacheStore.loadRemoteCache(universeName: source.name, cacheKey: source.id) {
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

    private func pruneOrphanedCatalogs() {
        let store = ActiveCatalogStore()
        let orphanedIDs = store.pruneOrphanedIDs()
        guard !orphanedIDs.isEmpty else {
            removedCatalogBanner = nil
            return
        }
        let allCachedSources = cacheStore.loadManifest()?.catalogs ?? []
        let names = orphanedIDs.compactMap { orphanedID in
            allCachedSources.first { $0.id == orphanedID }?.name ?? orphanedID
        }
        removedCatalogBanner = CatalogUpdateBannerRecommendation.removedCatalogs(names)
    }

    private func newCatalogSources(
        in currentSources: [ManagedCatalogSource],
        previousSources: [ManagedCatalogSource]
    ) -> [ManagedCatalogSource] {
        let previousIDs = Set(previousSources.map { normalizedKey($0.id) })
        return currentSources.filter { !previousIDs.contains(normalizedKey($0.id)) }
    }

    private func normalizedKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
