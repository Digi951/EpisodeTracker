import Foundation

@MainActor @Observable
final class EpisodeCatalog {
    static let shared = EpisodeCatalog()

    private var entries: [CatalogEntry] = []
    private let parser: CatalogParser
    private let cacheStore: CatalogCacheStore
    private let remoteDataSource: any CatalogFetching
    /// Abgeleiteter Anzeige-String für den bestehenden Katalog-Banner. Quelle der
    /// Wahrheit ist `lastRefreshOutcome`; dieser Wert wird daraus berechnet.
    private(set) var lastRefreshError: String?
    /// Strukturiertes Ergebnis des letzten Refresh-Laufs (Teil-Erfolg, Fehler pro
    /// Quelle). Für Settings-/Neuigkeiten-Statusanzeigen.
    private(set) var lastRefreshOutcome: CatalogRefreshOutcome?
    private(set) var newCatalogAvailability: NewCatalogAvailability?
    private(set) var removedCatalogBanner: CatalogUpdateBannerRecommendation?
    private(set) var upcomingReleases: [UpcomingRelease] = []
    /// Laufender Voll-Refresh. Ein zweiter nebenläufiger Aufruf (Vordergrund +
    /// manuell) hängt sich an dieses Ergebnis, statt einen zweiten Fetch-Satz
    /// auszulösen. `force: true` umgeht das bewusst.
    private var inFlightRefresh: Task<CatalogRefreshOutcome, Never>?

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
        upcomingReleases = cacheStore.loadUpcomingReleases()
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

    private static let manifestSourceName = "Katalogverzeichnis"
    private static let upcomingSourceName = "Bald verfügbar"

    /// `ignoringThrottle` bypasses the 6h `shouldRefresh` cooldown while still sending
    /// conditional requests (ETag/If-Modified-Since), so a cold app launch can always
    /// check for updates without losing the cheap 304-not-modified path that `force` skips.
    ///
    /// Nebenläufige Aufrufe ohne `force` teilen sich einen laufenden Refresh
    /// (`inFlightRefresh`), damit Vordergrund-Rückkehr und ein manueller Aufruf
    /// nicht denselben Fetch-Satz doppelt auslösen.
    @discardableResult
    func refreshManagedCatalogsIfNeeded(force: Bool = false, ignoringThrottle: Bool = false) async -> CatalogRefreshOutcome {
        if !force, let inFlightRefresh {
            return await inFlightRefresh.value
        }

        let task = Task { await self.performManagedCatalogsRefresh(force: force, ignoringThrottle: ignoringThrottle) }
        let didRegister = !force
        if didRegister { inFlightRefresh = task }
        let outcome = await task.value
        if didRegister { inFlightRefresh = nil }
        return outcome
    }

    private func performManagedCatalogsRefresh(force: Bool, ignoringThrottle: Bool) async -> CatalogRefreshOutcome {
        let manifestResult = await refreshManifestIfNeeded(force: force, ignoringThrottle: ignoringThrottle)
        pruneOrphanedCatalogs()

        let activeCatalogIDs = ActiveCatalogStore().activeIDs
        let sourcesToRefresh = managedSources.filter { activeCatalogIDs.contains($0.id) }

        var sourceResults: [CatalogRefreshOutcome.SourceResult] = []
        var upcomingResult: CatalogRefreshOutcome.SourceResult?

        // Child tasks stay MainActor-isolated, so the per-catalog disk writes (no
        // await inside them) still run to completion one at a time. Only the
        // network awaits overlap, which is the actual point of parallelizing.
        await withTaskGroup(of: RefreshSlot.self) { group in
            // Hängt an keiner Manifest-Information, darf also parallel zu den
            // Katalogen laufen statt den Start der Gruppe zu verzögern.
            group.addTask { @MainActor in
                .upcoming(await self.refreshUpcomingReleasesIfNeeded(force: force, ignoringThrottle: ignoringThrottle))
            }
            for source in sourcesToRefresh {
                group.addTask { @MainActor in
                    .source(await self.refreshManagedCatalogIfNeeded(source: source, force: force, ignoringThrottle: ignoringThrottle))
                }
            }
            for await slot in group {
                switch slot {
                case .upcoming(let result): upcomingResult = result
                case .source(let result): if let result { sourceResults.append(result) }
                }
            }
        }
        reload()

        let outcome = CatalogRefreshOutcome(
            manifest: manifestResult,
            upcoming: upcomingResult,
            sources: sourceResults
        )
        lastRefreshOutcome = outcome
        lastRefreshError = Self.derivedRefreshError(from: outcome)
        return outcome
    }

    private enum RefreshSlot {
        case source(CatalogRefreshOutcome.SourceResult?)
        case upcoming(CatalogRefreshOutcome.SourceResult?)
    }

    @discardableResult
    func refreshManagedCatalog(universeName: String, force: Bool = true) async -> CatalogRefreshOutcome {
        let manifestResult = await refreshManifestIfNeeded(force: force)

        guard let source = managedSources.first(where: {
            $0.name.caseInsensitiveCompare(universeName) == .orderedSame
        }) else {
            let outcome = CatalogRefreshOutcome(manifest: manifestResult)
            lastRefreshOutcome = outcome
            lastRefreshError = Self.derivedRefreshError(from: outcome)
            return outcome
        }

        let sourceResult = await refreshManagedCatalogIfNeeded(source: source, force: force)
        reload()

        let outcome = CatalogRefreshOutcome(
            manifest: manifestResult,
            sources: sourceResult.map { [$0] } ?? []
        )
        lastRefreshOutcome = outcome
        lastRefreshError = Self.derivedRefreshError(from: outcome)
        return outcome
    }

    /// `nil` bedeutet: in diesem Lauf nicht angefasst (gedrosselt).
    @discardableResult
    private func refreshManifestIfNeeded(force: Bool, ignoringThrottle: Bool = false) async -> CatalogRefreshOutcome.SourceResult? {
        let previousMetadata = cacheStore.loadRemoteMetadata(universeName: CatalogSourceRegistry.manifestMetadataKey)
        guard force || ignoringThrottle || shouldRefresh(previousMetadata) || cacheStore.loadManifest() == nil else { return nil }

        let attemptAt = Date()
        let result = await remoteDataSource.fetch(
            from: CatalogSourceRegistry.manifestURL,
            metadata: previousMetadata
        )
        var metadata = previousMetadata ?? RemoteCatalogMetadata()

        do {
            switch result {
            case .updated(let data, let eTag, let lastModified):
                let previousSources = cacheStore.loadManifest()?.catalogs ?? CatalogSourceRegistry.fallbackManagedSources
                let manifest = try parser.parseManifest(from: data)
                let filteredCatalogs = manifest.catalogs.filter(\.matchesDeviceLanguage)
                let newSources = newCatalogSources(in: filteredCatalogs, previousSources: previousSources)
                updateNewCatalogAvailability(newSources.isEmpty ? nil : NewCatalogAvailability(sources: newSources))
                try cacheStore.saveManifest(manifest)
                metadata.eTag = eTag
                metadata.lastModified = lastModified
                metadata.lastCheckedAt = .now
                metadata.lastAttemptAt = attemptAt
                metadata.lastFailureKind = nil
                try cacheStore.saveRemoteMetadata(metadata, universeName: CatalogSourceRegistry.manifestMetadataKey)
                return manifestSourceResult(status: .updated, attemptAt: attemptAt, previousMetadata: previousMetadata, savedMetadata: metadata)

            case .notModified:
                metadata.lastCheckedAt = .now
                metadata.lastAttemptAt = attemptAt
                metadata.lastFailureKind = nil
                try cacheStore.saveRemoteMetadata(metadata, universeName: CatalogSourceRegistry.manifestMetadataKey)
                return manifestSourceResult(status: .notModified, attemptAt: attemptAt, previousMetadata: previousMetadata, savedMetadata: metadata)

            case .failed(let error):
                // Fehlschlag: eTag/lastModified/lastCheckedAt unangetastet lassen,
                // nur den Versuch protokollieren. Der Cooldown startet damit nicht.
                metadata.lastAttemptAt = attemptAt
                metadata.lastFailureKind = error.kindLabel
                try? cacheStore.saveRemoteMetadata(metadata, universeName: CatalogSourceRegistry.manifestMetadataKey)
                return manifestSourceResult(status: .failed(error), attemptAt: attemptAt, previousMetadata: previousMetadata, savedMetadata: metadata)
            }
        } catch {
            // Antwort kam an, ließ sich aber nicht verarbeiten (Parsen oder
            // Persistieren). Wie ein Fehlschlag behandeln: Bestand bleibt gültig.
            metadata.lastAttemptAt = attemptAt
            metadata.lastFailureKind = CatalogFetchError.decoding(String(describing: error)).kindLabel
            try? cacheStore.saveRemoteMetadata(metadata, universeName: CatalogSourceRegistry.manifestMetadataKey)
            return manifestSourceResult(
                status: .failed(.decoding(String(describing: error))),
                attemptAt: attemptAt,
                previousMetadata: previousMetadata,
                savedMetadata: metadata
            )
        }
    }

    private func manifestSourceResult(
        status: CatalogRefreshOutcome.Status,
        attemptAt: Date,
        previousMetadata: RemoteCatalogMetadata?,
        savedMetadata: RemoteCatalogMetadata
    ) -> CatalogRefreshOutcome.SourceResult {
        CatalogRefreshOutcome.SourceResult(
            id: CatalogSourceRegistry.manifestMetadataKey,
            name: Self.manifestSourceName,
            status: status,
            lastAttemptAt: attemptAt,
            lastSuccessAt: status.isSuccess ? savedMetadata.lastCheckedAt : previousMetadata?.lastCheckedAt
        )
    }

    @discardableResult
    func refreshUpcomingReleasesIfNeeded(force: Bool = false, ignoringThrottle: Bool = false) async -> CatalogRefreshOutcome.SourceResult? {
        let previousMetadata = cacheStore.loadRemoteMetadata(universeName: CatalogSourceRegistry.upcomingReleasesMetadataKey)
        let hasCachedReleases = !cacheStore.loadUpcomingReleases().isEmpty
        guard force || ignoringThrottle || !hasCachedReleases || shouldRefresh(previousMetadata) else { return nil }

        let attemptAt = Date()
        // Ohne verwertbare Daten im Cache darf kein 304 zurückkommen: sonst bliebe
        // die Liste dauerhaft leer, sobald die Cache-Datei einmal nicht lesbar ist
        // (beschädigt oder in einem älteren Format geschrieben).
        let result = await remoteDataSource.fetch(
            from: CatalogSourceRegistry.upcomingReleasesURL,
            metadata: hasCachedReleases ? previousMetadata : nil
        )
        var metadata = previousMetadata ?? RemoteCatalogMetadata()

        func upcomingResult(_ status: CatalogRefreshOutcome.Status) -> CatalogRefreshOutcome.SourceResult {
            CatalogRefreshOutcome.SourceResult(
                id: CatalogSourceRegistry.upcomingReleasesMetadataKey,
                name: Self.upcomingSourceName,
                status: status,
                lastAttemptAt: attemptAt,
                lastSuccessAt: status.isSuccess ? metadata.lastCheckedAt : previousMetadata?.lastCheckedAt
            )
        }

        do {
            switch result {
            case .updated(let data, let eTag, let lastModified):
                let document = try JSONDecoder().decode(UpcomingReleasesDocument.self, from: data)
                try cacheStore.saveUpcomingReleases(document.releases)
                upcomingReleases = document.releases
                metadata.eTag = eTag
                metadata.lastModified = lastModified
                metadata.lastCheckedAt = .now
                metadata.lastAttemptAt = attemptAt
                metadata.lastFailureKind = nil
                try cacheStore.saveRemoteMetadata(metadata, universeName: CatalogSourceRegistry.upcomingReleasesMetadataKey)
                return upcomingResult(.updated)

            case .notModified:
                metadata.lastCheckedAt = .now
                metadata.lastAttemptAt = attemptAt
                metadata.lastFailureKind = nil
                try cacheStore.saveRemoteMetadata(metadata, universeName: CatalogSourceRegistry.upcomingReleasesMetadataKey)
                return upcomingResult(.notModified)

            case .failed(let error):
                metadata.lastAttemptAt = attemptAt
                metadata.lastFailureKind = error.kindLabel
                try? cacheStore.saveRemoteMetadata(metadata, universeName: CatalogSourceRegistry.upcomingReleasesMetadataKey)
                return upcomingResult(.failed(error))
            }
        } catch {
            metadata.lastAttemptAt = attemptAt
            metadata.lastFailureKind = CatalogFetchError.decoding(String(describing: error)).kindLabel
            try? cacheStore.saveRemoteMetadata(metadata, universeName: CatalogSourceRegistry.upcomingReleasesMetadataKey)
            return upcomingResult(.failed(.decoding(String(describing: error))))
        }
    }

    @discardableResult
    func refreshManagedCatalogIfNeeded(source: ManagedCatalogSource, force: Bool, ignoringThrottle: Bool = false) async -> CatalogRefreshOutcome.SourceResult? {
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
        guard force || ignoringThrottle || !hasCachedEntries || needsStreamingLinkRefresh || needsMarketLinkRefresh || shouldRefresh(previousMetadata) else { return nil }

        let attemptAt = Date()
        let requestMetadata = force || needsStreamingLinkRefresh || needsMarketLinkRefresh ? nil : previousMetadata
        let result = await remoteDataSource.fetch(from: source, metadata: requestMetadata)
        var metadata = previousMetadata ?? RemoteCatalogMetadata()

        func sourceResult(_ status: CatalogRefreshOutcome.Status) -> CatalogRefreshOutcome.SourceResult {
            CatalogRefreshOutcome.SourceResult(
                id: source.id,
                name: source.name,
                status: status,
                lastAttemptAt: attemptAt,
                lastSuccessAt: status.isSuccess ? metadata.lastCheckedAt : previousMetadata?.lastCheckedAt
            )
        }

        do {
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
                metadata.lastAttemptAt = attemptAt
                metadata.lastFailureKind = nil
                try cacheStore.saveRemoteMetadata(metadata, universeName: source.name, cacheKey: source.id)
                return sourceResult(.updated)

            case .notModified:
                metadata.lastCheckedAt = .now
                metadata.lastAttemptAt = attemptAt
                metadata.lastFailureKind = nil
                try cacheStore.saveRemoteMetadata(metadata, universeName: source.name, cacheKey: source.id)
                return sourceResult(.notModified)

            case .failed(let error):
                // eTag/lastModified/lastCheckedAt und die Cache-Einträge bleiben
                // unangetastet; nur der Versuch wird protokolliert.
                metadata.lastAttemptAt = attemptAt
                metadata.lastFailureKind = error.kindLabel
                try? cacheStore.saveRemoteMetadata(metadata, universeName: source.name, cacheKey: source.id)
                return sourceResult(.failed(error))
            }
        } catch {
            metadata.lastAttemptAt = attemptAt
            metadata.lastFailureKind = CatalogFetchError.decoding(String(describing: error)).kindLabel
            try? cacheStore.saveRemoteMetadata(metadata, universeName: source.name, cacheKey: source.id)
            return sourceResult(.failed(.decoding(String(describing: error))))
        }
    }

    /// Baut den Anzeige-String für den bestehenden Katalog-Banner. Ein Fehlschlag
    /// des Bald-verfügbar-Feeds zählt bewusst nicht mit.
    private static func derivedRefreshError(from outcome: CatalogRefreshOutcome) -> String? {
        if outcome.manifestFailed {
            return AppLocalization.format(
                "Catalog.DirectoryUnreachable",
                defaultValue: "Katalogverzeichnis nicht erreichbar."
            )
        }
        let failedNames = outcome.failedCatalogNames
        guard !failedNames.isEmpty else { return nil }
        if failedNames.count == 1 {
            return AppLocalization.format(
                "Catalog.RefreshSingleFailure",
                defaultValue: "Katalog „%@“ nicht aktualisierbar.",
                failedNames[0]
            )
        }
        return AppLocalization.format(
            "Catalog.RefreshPartialFailure",
            defaultValue: "%1$@ von %2$@ Katalogen nicht aktualisierbar.",
            String(failedNames.count),
            String(outcome.attemptedCatalogCount)
        )
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
