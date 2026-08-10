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
        // Nummernsuche betrifft nur reguläre Folgen; Sonderfolgen haben eine
        // eigene Nummerierung die mit der regulären kollidieren kann.
        return entries.reversed().first(where: {
            $0.kind == .regular && $0.number == number && $0.collectionName?.lowercased() == key
        })
    }

    @discardableResult
    func importCatalog(data: Data, into collectionName: String) throws -> Int {
        let parsedEntries = try parser.parseCatalogEntries(from: data, fallbackCollectionName: collectionName)
        let normalizedEntries = parsedEntries.map {
            CatalogEntry(
                number: $0.number,
                kind: $0.kind,
                slug: $0.slug,
                title: $0.title,
                releaseYear: $0.releaseYear,
                collectionName: collectionName,
                links: $0.links
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

    /// `ignoringThrottle` bypasses the 6h `shouldRefresh` cooldown while still sending
    /// conditional requests (ETag/If-Modified-Since), so a cold app launch can always
    /// check for updates without losing the cheap 304-not-modified path that `force` skips.
    func refreshManagedCatalogsIfNeeded(force: Bool = false, ignoringThrottle: Bool = false) async {
        lastRefreshError = nil
        await refreshManifestIfNeeded(force: force, ignoringThrottle: ignoringThrottle)
        pruneOrphanedCatalogs()

        let activeCatalogIDs = ActiveCatalogStore().activeIDs
        let sourcesToRefresh = managedSources.filter { activeCatalogIDs.contains($0.id) }
        // Child tasks stay MainActor-isolated, so the per-catalog disk writes (no
        // await inside them) still run to completion one at a time. Only the
        // network awaits overlap, which is the actual point of parallelizing.
        await withTaskGroup(of: Void.self) { group in
            for source in sourcesToRefresh {
                group.addTask { @MainActor in
                    await self.refreshManagedCatalogIfNeeded(source: source, force: force, ignoringThrottle: ignoringThrottle)
                }
            }
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

    private func refreshManifestIfNeeded(force: Bool, ignoringThrottle: Bool = false) async {
        let previousMetadata = cacheStore.loadRemoteMetadata(universeName: CatalogSourceRegistry.manifestMetadataKey)
        guard force || ignoringThrottle || shouldRefresh(previousMetadata) || cacheStore.loadManifest() == nil else { return }

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

    func refreshManagedCatalogIfNeeded(source: ManagedCatalogSource, force: Bool, ignoringThrottle: Bool = false) async {
        let previousMetadata = cacheStore.loadRemoteMetadata(universeName: source.name, cacheKey: source.id)
        let cachedEntries = cacheStore.loadRemoteCache(universeName: source.name, cacheKey: source.id)
        let hasCachedEntries = cachedEntries?.isEmpty == false
        let hasStreamingLinks = cachedEntries?.contains(where: \.hasStreamingLink) == true
        // Ein Cache, der vor der links-Umstellung geschrieben wurde, kennt nur die
        // vier historischen Dienste. Ein einmaliger Refresh holt die vollständigen
        // Links nach, sobald ein Dienst des Markts dieser Quelle im gesamten Cache
        // fehlt. Das Marktprofil richtet sich nach der Katalogsprache, nicht nach
        // der Geräte-UI-Sprache — sonst würde ein PL-Katalog auf einem DE-Gerät nie
        // als vollständig gelten und bei jedem Refresh den ETag-Cache verwerfen.
        let marketServices = StreamingMarketProfile.profile(forLanguageCode: source.effectiveLanguage).services
        let hasAllMarketLinks = marketServices.allSatisfy { service in
            cachedEntries?.contains { entry in entry.links[service.rawValue] != nil } == true
        }
        let needsStreamingLinkRefresh = hasCachedEntries && !hasStreamingLinks
        let needsMarketLinkRefresh = hasCachedEntries && hasStreamingLinks && !hasAllMarketLinks
        guard force || ignoringThrottle || !hasCachedEntries || needsStreamingLinkRefresh || needsMarketLinkRefresh || shouldRefresh(previousMetadata) else { return }

        do {
            let requestMetadata = force || needsStreamingLinkRefresh || needsMarketLinkRefresh ? nil : previousMetadata
            let result = try await remoteDataSource.fetch(from: source, metadata: requestMetadata)
            var metadata = previousMetadata ?? RemoteCatalogMetadata()

            switch result {
            case .updated(let data, let eTag, let lastModified):
                let document = try parser.parseNormalizedCatalogDocument(from: data, fallbackCollectionName: source.name)
                let normalizedEntries = document.entries.map {
                    CatalogEntry(
                        number: $0.number,
                        kind: $0.kind,
                        slug: $0.slug,
                        title: $0.title,
                        releaseYear: $0.releaseYear,
                        collectionName: source.name,
                        links: $0.links
                    )
                }
                let previousSnapshot = cacheStore.loadCatalogSnapshot(universeName: source.name, cacheKey: source.id)
                let currentSnapshot = CatalogSnapshot(
                    catalogID: source.id,
                    name: source.name,
                    version: document.version,
                    lastUpdated: document.lastUpdated,
                    entryCount: document.entryCount,
                    episodeNumbers: normalizedEntries.compactMap(\.number),
                    specialSlugs: normalizedEntries.compactMap { $0.kind == .special ? $0.slug : nil }
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
