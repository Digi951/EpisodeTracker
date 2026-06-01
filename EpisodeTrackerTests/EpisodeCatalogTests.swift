import XCTest
import Observation
@testable import EpisodeTracker

@MainActor
final class EpisodeCatalogTests: XCTestCase {
    private final class MockCatalogFetcher: CatalogFetching, @unchecked Sendable {
        private(set) var sourceMetadataRequests: [RemoteCatalogMetadata?] = []
        var sourceResult: RemoteCatalogFetchResult

        init(sourceResult: RemoteCatalogFetchResult) {
            self.sourceResult = sourceResult
        }

        func fetch(from url: URL, metadata: RemoteCatalogMetadata?) async throws -> RemoteCatalogFetchResult {
            .skipped
        }

        func fetch(from source: ManagedCatalogSource, metadata: RemoteCatalogMetadata?) async throws -> RemoteCatalogFetchResult {
            sourceMetadataRequests.append(metadata)
            return sourceResult
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
        XCTAssertEqual(entry?.deezerURL, "https://www.deezer.com/album/1234567")
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
        XCTAssertEqual(catalog.entry(for: 1, in: source.name)?.deezerURL, "https://www.deezer.com/album/12761822")
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
