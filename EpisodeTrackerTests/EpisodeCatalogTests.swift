import XCTest
import Observation
@testable import EpisodeTracker

@MainActor
final class EpisodeCatalogTests: XCTestCase {
    private final class MockCatalogFetcher: CatalogFetching, @unchecked Sendable {
        private(set) var sourceMetadataRequests: [RemoteCatalogMetadata?] = []
        private(set) var requestedSourceIDs: [String] = []
        var sourceResult: RemoteCatalogFetchResult
        /// Per-Quelle-Ergebnis; überschreibt `sourceResult` für die passende ID.
        var resultsBySourceID: [String: RemoteCatalogFetchResult] = [:]

        init(sourceResult: RemoteCatalogFetchResult) {
            self.sourceResult = sourceResult
        }

        func fetch(from url: URL, metadata: RemoteCatalogMetadata?) async -> RemoteCatalogFetchResult {
            // Echter Suspension-Punkt: nur so können nebenläufige Refreshes
            // interleaven und der In-Flight-Guard greift beobachtbar.
            await Task.yield()
            return .notModified
        }

        func fetch(from source: ManagedCatalogSource, metadata: RemoteCatalogMetadata?) async -> RemoteCatalogFetchResult {
            await Task.yield()
            sourceMetadataRequests.append(metadata)
            requestedSourceIDs.append(source.id)
            return resultsBySourceID[source.id] ?? sourceResult
        }
    }

    // MARK: - Helpers

    private func makeTempCacheStore() -> CatalogCacheStore {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EpisodeCatalogTests-\(UUID().uuidString)")
        return CatalogCacheStore(directoryURL: tempDir)
    }

    private func makeSource(id: String = "test", name: String = "Test Katalog") -> ManagedCatalogSource {
        ManagedCatalogSource(
            id: id,
            name: name,
            url: URL(string: "https://example.com/\(id).json")!
        )
    }

    // MARK: - Initialisation

    func testNewCatalogAvailabilityIsNilWhenCacheIsEmpty() {
        let catalog = EpisodeCatalog(cacheStore: makeTempCacheStore())
        XCTAssertNil(catalog.newCatalogAvailability)
    }

    func testNewCatalogAvailabilityIsLoadedFromCacheOnInit() throws {
        let store = makeTempCacheStore()
        let source = makeSource(name: "Die Playmos")
        try store.saveNewCatalogAvailability(NewCatalogAvailability(sources: [source]))

        let catalog = EpisodeCatalog(cacheStore: store)

        XCTAssertEqual(catalog.newCatalogAvailability?.sources.first?.name, "Die Playmos")
    }

    // MARK: - Observable behaviour

    func testNewCatalogAvailabilityObservationFiresWhenSet() {
        let catalog = EpisodeCatalog(cacheStore: makeTempCacheStore())

        var observationFired = false
        withObservationTracking {
            _ = catalog.newCatalogAvailability
        } onChange: {
            observationFired = true
        }

        catalog.updateNewCatalogAvailability(NewCatalogAvailability(sources: [makeSource()]))

        XCTAssertTrue(
            observationFired,
            "newCatalogAvailability must be a stored @Observable property so SwiftUI re-renders the banner"
        )
        XCTAssertNotNil(catalog.newCatalogAvailability)
    }

    func testNewCatalogAvailabilityObservationFiresWhenCleared() throws {
        let store = makeTempCacheStore()
        try store.saveNewCatalogAvailability(NewCatalogAvailability(sources: [makeSource()]))
        let catalog = EpisodeCatalog(cacheStore: store)

        XCTAssertNotNil(catalog.newCatalogAvailability)

        var observationFired = false
        withObservationTracking {
            _ = catalog.newCatalogAvailability
        } onChange: {
            observationFired = true
        }

        catalog.updateNewCatalogAvailability(nil)

        XCTAssertTrue(
            observationFired,
            "Clearing newCatalogAvailability must trigger observation so the banner disappears"
        )
        XCTAssertNil(catalog.newCatalogAvailability)
    }

    // MARK: - Imports

    func testImportCatalogPreservesDeezerLinks() throws {
        let catalog = EpisodeCatalog(cacheStore: makeTempCacheStore())
        let json = """
        {
          "collectionName": "Test Katalog",
          "entries": [
            {
              "number": 1,
              "title": "Testfolge",
              "releaseYear": 2026,
              "deezerURL": "https://www.deezer.com/album/1234567"
            }
          ]
        }
        """

        try catalog.importCatalog(data: Data(json.utf8), into: "Test Katalog")

        let entry = catalog.entry(for: 1, in: "Test Katalog")
        XCTAssertEqual(entry?.links["deezer"], "https://www.deezer.com/album/1234567")
        XCTAssertEqual(
            entry.flatMap { StreamingService.deezer.catalogURL(from: $0) }?.absoluteString,
            "https://www.deezer.com/album/1234567"
        )
    }

    func testForcedManagedCatalogRefreshBypassesMetadataAndRewritesDeezerCache() async throws {
        let store = makeTempCacheStore()
        let source = CatalogSourceRegistry.fallbackManagedSources[0]
        try store.saveRemoteCache(
            entries: [
                CatalogEntry(
                    number: 1,
                    title: "und der Super-Papagei",
                    releaseYear: 1979,
                    collectionName: source.name,
                    spotifyURL: "https://open.spotify.com/album/4N9tvSjWfZXx3eHKblYEWQ"
                )
            ],
            universeName: source.name,
            cacheKey: source.id
        )
        try store.saveRemoteMetadata(
            RemoteCatalogMetadata(eTag: "\"old\"", lastModified: "Fri, 22 May 2026 12:00:00 GMT", lastCheckedAt: .now),
            universeName: source.name,
            cacheKey: source.id
        )
        let json = """
        {
          "collectionName": "\(source.name)",
          "entries": [
            {
              "number": 1,
              "title": "und der Super-Papagei",
              "releaseYear": 1979,
              "deezerURL": "https://www.deezer.com/album/12761822"
            }
          ]
        }
        """
        let fetcher = MockCatalogFetcher(
            sourceResult: .updated(data: Data(json.utf8), eTag: "\"new\"", lastModified: nil)
        )
        let catalog = EpisodeCatalog(cacheStore: store, remoteDataSource: fetcher)

        await catalog.refreshManagedCatalog(universeName: source.name, force: true)

        XCTAssertEqual(fetcher.sourceMetadataRequests.count, 1)
        XCTAssertNil(fetcher.sourceMetadataRequests[0])
        XCTAssertEqual(catalog.entry(for: 1, in: source.name)?.links["deezer"], "https://www.deezer.com/album/12761822")
    }

    func testUnforcedRefreshBackfillsWhenAMarketServiceLinkIsMissingEverywhere() async throws {
        let store = makeTempCacheStore()
        let source = CatalogSourceRegistry.fallbackManagedSources[0]
        // Cache predates the links-Umstellung: only an Apple link, no Spotify/Deezer/Audible anywhere.
        try store.saveRemoteCache(
            entries: [
                CatalogEntry(
                    number: 1,
                    title: "und der Super-Papagei",
                    releaseYear: 1979,
                    collectionName: source.name,
                    links: ["apple": "https://music.apple.com/album/123"]
                )
            ],
            universeName: source.name,
            cacheKey: source.id
        )
        try store.saveRemoteMetadata(
            RemoteCatalogMetadata(eTag: "\"old\"", lastModified: nil, lastCheckedAt: .now),
            universeName: source.name,
            cacheKey: source.id
        )
        let json = """
        {
          "collectionName": "\(source.name)",
          "entries": [
            {
              "number": 1,
              "title": "und der Super-Papagei",
              "releaseYear": 1979,
              "links": {
                "apple": "https://music.apple.com/album/123",
                "spotify": "https://open.spotify.com/album/456",
                "deezer": "https://www.deezer.com/album/789",
                "audible": "https://www.audible.de/pd/999"
              }
            }
          ]
        }
        """
        let fetcher = MockCatalogFetcher(
            sourceResult: .updated(data: Data(json.utf8), eTag: "\"new\"", lastModified: nil)
        )
        let catalog = EpisodeCatalog(cacheStore: store, remoteDataSource: fetcher)

        await catalog.refreshManagedCatalog(universeName: source.name, force: false)

        XCTAssertEqual(fetcher.sourceMetadataRequests.count, 1)
        XCTAssertNil(
            fetcher.sourceMetadataRequests[0],
            "a market service missing from every cached entry must force an unconditional refetch even without force:true"
        )
        XCTAssertEqual(catalog.entry(for: 1, in: source.name)?.links["spotify"], "https://open.spotify.com/album/456")
    }

    func testUnforcedRefreshSkipsBackfillOnceEveryMarketServiceHasAtLeastOneLink() async throws {
        let store = makeTempCacheStore()
        let source = CatalogSourceRegistry.fallbackManagedSources[0]
        try store.saveRemoteCache(
            entries: [
                CatalogEntry(
                    number: 1,
                    title: "und der Super-Papagei",
                    releaseYear: 1979,
                    collectionName: source.name,
                    links: [
                        "apple": "https://music.apple.com/album/123",
                        "spotify": "https://open.spotify.com/album/456",
                        "deezer": "https://www.deezer.com/album/789",
                        "audible": "https://www.audible.de/pd/999"
                    ]
                )
            ],
            universeName: source.name,
            cacheKey: source.id
        )
        try store.saveRemoteMetadata(
            RemoteCatalogMetadata(eTag: "\"current\"", lastModified: nil, lastCheckedAt: .now),
            universeName: source.name,
            cacheKey: source.id
        )
        let fetcher = MockCatalogFetcher(sourceResult: .notModified)
        let catalog = EpisodeCatalog(cacheStore: store, remoteDataSource: fetcher)

        await catalog.refreshManagedCatalog(universeName: source.name, force: false)

        XCTAssertTrue(
            fetcher.sourceMetadataRequests.isEmpty,
            "no refresh should be triggered once every market service already has a link somewhere in the cache"
        )
    }

    func testIgnoringThrottleRefetchesEvenWhenRecentlyChecked() async throws {
        let store = makeTempCacheStore()
        let source = CatalogSourceRegistry.fallbackManagedSources[0]
        try store.saveRemoteCache(
            entries: [CatalogEntry(number: 1, title: "Alt", releaseYear: 1979, collectionName: source.name)],
            universeName: source.name,
            cacheKey: source.id
        )
        // A cooldown that just started must normally block a re-fetch (see
        // testUnforcedRefreshSkipsBackfillOnceEveryMarketServiceHasAtLeastOneLink).
        try store.saveRemoteMetadata(
            RemoteCatalogMetadata(eTag: "\"old\"", lastModified: nil, lastCheckedAt: .now),
            universeName: source.name,
            cacheKey: source.id
        )
        let fetcher = MockCatalogFetcher(sourceResult: .notModified)
        let catalog = EpisodeCatalog(cacheStore: store, remoteDataSource: fetcher)

        await catalog.refreshManagedCatalogsIfNeeded(ignoringThrottle: true)

        XCTAssertFalse(
            fetcher.sourceMetadataRequests.isEmpty,
            "ignoringThrottle must bypass the 6h cooldown so a cold app launch can pick up server-side catalog updates"
        )
    }

    // MARK: - Commit B: typed outcome, failed fetch does not freeze the cooldown

    func testFailedSourceFetchKeepsCacheAndMetadataAndDoesNotStartCooldown() async throws {
        let store = makeTempCacheStore()
        let source = CatalogSourceRegistry.fallbackManagedSources[0]
        let staleCheck = Date().addingTimeInterval(-7 * 60 * 60) // älter als 6h → shouldRefresh == true
        try store.saveRemoteCache(
            entries: [CatalogEntry(number: 1, title: "Bestand", releaseYear: 1979, collectionName: source.name,
                                   links: ["spotify": "https://open.spotify.com/album/keep", "apple": "https://music.apple.com/keep", "deezer": "https://deezer.com/keep", "audible": "https://audible.de/keep"])],
            universeName: source.name,
            cacheKey: source.id
        )
        try store.saveRemoteMetadata(
            RemoteCatalogMetadata(eTag: "\"keep\"", lastModified: "keep-date", lastCheckedAt: staleCheck),
            universeName: source.name,
            cacheKey: source.id
        )
        let fetcher = MockCatalogFetcher(sourceResult: .notModified)
        fetcher.resultsBySourceID[source.id] = .failed(.http(status: 503))
        let catalog = EpisodeCatalog(cacheStore: store, remoteDataSource: fetcher)

        let outcome = await catalog.refreshManagedCatalog(universeName: source.name, force: false)

        // Ergebnis meldet den Fehlschlag, nicht Erfolg.
        XCTAssertEqual(outcome.failedCatalogNames, [source.name])
        XCTAssertTrue(outcome.hadAnyFailure)
        XCTAssertNotNil(catalog.lastRefreshError)

        // Cache-Einträge bleiben erhalten.
        XCTAssertEqual(catalog.entry(for: 1, in: source.name)?.links["spotify"], "https://open.spotify.com/album/keep")

        // eTag / lastModified / lastCheckedAt unangetastet; nur der Versuch protokolliert.
        let saved = try XCTUnwrap(store.loadRemoteMetadata(universeName: source.name, cacheKey: source.id))
        XCTAssertEqual(saved.eTag, "\"keep\"")
        XCTAssertEqual(saved.lastModified, "keep-date")
        XCTAssertEqual(saved.lastCheckedAt?.timeIntervalSince1970 ?? 0, staleCheck.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(saved.lastFailureKind, "http:503")
        XCTAssertNotNil(saved.lastAttemptAt)

        // Cooldown nicht gestartet: ein zweiter Lauf versucht erneut zu fetchen.
        let requestsBefore = fetcher.requestedSourceIDs.count
        await catalog.refreshManagedCatalog(universeName: source.name, force: false)
        XCTAssertGreaterThan(fetcher.requestedSourceIDs.count, requestsBefore)
    }

    func testSuccessfulFetchClearsFailureKindAndSetsAttempt() async throws {
        let store = makeTempCacheStore()
        let source = CatalogSourceRegistry.fallbackManagedSources[0]
        try store.saveRemoteMetadata(
            RemoteCatalogMetadata(eTag: "\"old\"", lastModified: nil, lastCheckedAt: Date().addingTimeInterval(-7 * 60 * 60),
                                  lastAttemptAt: Date().addingTimeInterval(-7 * 60 * 60), lastFailureKind: "http:500"),
            universeName: source.name,
            cacheKey: source.id
        )
        let json = """
        { "collectionName": "\(source.name)", "entries": [ { "number": 1, "title": "Neu", "releaseYear": 1979 } ] }
        """
        let fetcher = MockCatalogFetcher(sourceResult: .notModified)
        fetcher.resultsBySourceID[source.id] = .updated(data: Data(json.utf8), eTag: "\"fresh\"", lastModified: nil)
        let catalog = EpisodeCatalog(cacheStore: store, remoteDataSource: fetcher)

        let outcome = await catalog.refreshManagedCatalog(universeName: source.name, force: false)

        XCTAssertTrue(outcome.hadAnySuccess)
        XCTAssertFalse(outcome.hadAnyFailure)
        XCTAssertNil(catalog.lastRefreshError)
        let saved = try XCTUnwrap(store.loadRemoteMetadata(universeName: source.name, cacheKey: source.id))
        XCTAssertNil(saved.lastFailureKind)
        XCTAssertEqual(saved.eTag, "\"fresh\"")
        XCTAssertNotNil(saved.lastAttemptAt)
        XCTAssertNotNil(saved.lastCheckedAt)
    }

    func testInvalidJSONOnUpdatedIsReportedAsFailureAndKeepsCache() async throws {
        let store = makeTempCacheStore()
        let source = CatalogSourceRegistry.fallbackManagedSources[0]
        try store.saveRemoteCache(
            entries: [CatalogEntry(number: 1, title: "Bestand", releaseYear: 1979, collectionName: source.name,
                                   links: ["spotify": "https://open.spotify.com/album/keep", "apple": "https://music.apple.com/keep", "deezer": "https://deezer.com/keep", "audible": "https://audible.de/keep"])],
            universeName: source.name,
            cacheKey: source.id
        )
        try store.saveRemoteMetadata(
            RemoteCatalogMetadata(eTag: "\"keep\"", lastModified: nil, lastCheckedAt: Date().addingTimeInterval(-7 * 60 * 60)),
            universeName: source.name,
            cacheKey: source.id
        )
        let fetcher = MockCatalogFetcher(sourceResult: .notModified)
        fetcher.resultsBySourceID[source.id] = .updated(data: Data("kein json".utf8), eTag: "\"broken\"", lastModified: nil)
        let catalog = EpisodeCatalog(cacheStore: store, remoteDataSource: fetcher)

        let outcome = await catalog.refreshManagedCatalog(universeName: source.name, force: false)

        XCTAssertTrue(outcome.hadAnyFailure)
        XCTAssertEqual(outcome.failedCatalogNames, [source.name])
        XCTAssertEqual(catalog.entry(for: 1, in: source.name)?.links["spotify"], "https://open.spotify.com/album/keep")
        let saved = try XCTUnwrap(store.loadRemoteMetadata(universeName: source.name, cacheKey: source.id))
        XCTAssertEqual(saved.eTag, "\"keep\"", "ein kaputter Payload darf den bestätigten ETag nicht überschreiben")
        XCTAssertEqual(saved.lastFailureKind, "decoding")
    }

    func testPartialSuccessAggregatesPerSource() async throws {
        let store = makeTempCacheStore()
        let failing = CatalogSourceRegistry.fallbackManagedSources[0]
        let fetcher = MockCatalogFetcher(sourceResult: .notModified)
        fetcher.resultsBySourceID[failing.id] = .failed(.http(status: 500))
        let catalog = EpisodeCatalog(cacheStore: store, remoteDataSource: fetcher)

        let outcome = await catalog.refreshManagedCatalogsIfNeeded(ignoringThrottle: true)

        XCTAssertTrue(outcome.hadAnySuccess)
        XCTAssertTrue(outcome.hadAnyFailure)
        XCTAssertEqual(outcome.failedCatalogNames, [failing.name])
        XCTAssertGreaterThan(outcome.attemptedCatalogCount, 1)
        XCTAssertEqual(catalog.lastRefreshOutcome, outcome)
        XCTAssertNotNil(catalog.lastRefreshError)
    }

    // MARK: - Commit C: concurrent refreshes coalesce, force bypasses

    func testConcurrentUnforcedRefreshesShareOneFetchPass() async {
        let store = makeTempCacheStore()
        let fetcher = MockCatalogFetcher(sourceResult: .notModified)
        let catalog = EpisodeCatalog(cacheStore: store, remoteDataSource: fetcher)
        let activeCount = CatalogSourceRegistry.fallbackManagedSources.count

        async let first = catalog.refreshManagedCatalogsIfNeeded(ignoringThrottle: true)
        async let second = catalog.refreshManagedCatalogsIfNeeded(ignoringThrottle: true)
        let (a, b) = await (first, second)

        XCTAssertEqual(a, b, "der zweite Aufruf hängt sich an den laufenden Refresh")
        XCTAssertEqual(
            fetcher.requestedSourceIDs.count, activeCount,
            "nur ein Fetch-Satz, nicht doppelt"
        )
    }

    func testConcurrentForcedRefreshesEachRunTheirOwnPass() async {
        let store = makeTempCacheStore()
        let fetcher = MockCatalogFetcher(sourceResult: .notModified)
        let catalog = EpisodeCatalog(cacheStore: store, remoteDataSource: fetcher)
        let activeCount = CatalogSourceRegistry.fallbackManagedSources.count

        async let first = catalog.refreshManagedCatalogsIfNeeded(force: true)
        async let second = catalog.refreshManagedCatalogsIfNeeded(force: true)
        _ = await (first, second)

        XCTAssertEqual(
            fetcher.requestedSourceIDs.count, activeCount * 2,
            "force umgeht das Coalescing: beide Läufe fetchen"
        )
    }

    func testRefreshIsAvailableAgainAfterInFlightCompletes() async {
        let store = makeTempCacheStore()
        let fetcher = MockCatalogFetcher(sourceResult: .notModified)
        let catalog = EpisodeCatalog(cacheStore: store, remoteDataSource: fetcher)
        let activeCount = CatalogSourceRegistry.fallbackManagedSources.count

        await catalog.refreshManagedCatalogsIfNeeded(ignoringThrottle: true)
        await catalog.refreshManagedCatalogsIfNeeded(ignoringThrottle: true)

        XCTAssertEqual(
            fetcher.requestedSourceIDs.count, activeCount * 2,
            "nach Abschluss des ersten Laufs ist der In-Flight-Guard wieder frei"
        )
    }

    func testCatalogEntryDecodesSpecialKindAndSlug() throws {
        let json = """
        {"title":"Phantomsee","releaseYear":2024,"kind":"special","slug":"phantomsee-2024"}
        """.data(using: .utf8)!
        let entry = try JSONDecoder().decode(CatalogEntry.self, from: json)
        XCTAssertEqual(entry.kind, .special)
        XCTAssertEqual(entry.slug, "phantomsee-2024")
        XCTAssertNil(entry.number)
    }

    func testCatalogEntryDefaultsToRegularWhenKindMissing() throws {
        let json = """
        {"number":42,"title":"Angreifer","releaseYear":2024}
        """.data(using: .utf8)!
        let entry = try JSONDecoder().decode(CatalogEntry.self, from: json)
        XCTAssertEqual(entry.kind, .regular)
        XCTAssertEqual(entry.number, 42)
    }

    func testDeltaDetectsNewSpecialBySlug() {
        let previous = CatalogSnapshot(catalogID: "x", name: "X", version: 1, lastUpdated: nil, entryCount: 1, episodeNumbers: [1], specialSlugs: [])
        let current = CatalogSnapshot(catalogID: "x", name: "X", version: 2, lastUpdated: nil, entryCount: 2, episodeNumbers: [1], specialSlugs: ["phantomsee-2024"])
        let entries = [
            CatalogEntry(number: 1, title: "A", releaseYear: 2020),
            CatalogEntry(number: nil, kind: .special, slug: "phantomsee-2024", title: "Phantomsee", releaseYear: 2024)
        ]
        let delta = CatalogEpisodeDelta.make(previous: previous, current: current, entries: entries)
        XCTAssertEqual(delta?.addedEntries.count, 1)
        XCTAssertEqual(delta?.addedEntries.first?.slug, "phantomsee-2024")
    }

    func testOldSnapshotWithoutSpecialSlugsDecodesAsEmpty() throws {
        let json = """
        {"catalogID":"x","name":"X","version":1,"entryCount":1,"episodeNumbers":[1]}
        """.data(using: .utf8)!
        let snapshot = try JSONDecoder().decode(CatalogSnapshot.self, from: json)
        XCTAssertEqual(snapshot.specialSlugs, [])
    }
}
