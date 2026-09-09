import XCTest
@testable import EpisodeTracker

@MainActor
final class EpisodeCatalogUpcomingReleasesTests: XCTestCase {
    private final class MockURLFetcher: CatalogFetching, @unchecked Sendable {
        var urlResult: RemoteCatalogFetchResult = .notModified
        private(set) var lastMetadata: RemoteCatalogMetadata??

        func fetch(from url: URL, metadata: RemoteCatalogMetadata?) async throws -> RemoteCatalogFetchResult {
            lastMetadata = .some(metadata)
            return urlResult
        }

        func fetch(from source: ManagedCatalogSource, metadata: RemoteCatalogMetadata?) async throws -> RemoteCatalogFetchResult {
            .notModified
        }
    }

    private func makeTempCacheStore() -> CatalogCacheStore {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EpisodeCatalogUpcomingReleasesTests-\(UUID().uuidString)")
        return CatalogCacheStore(directoryURL: tempDir)
    }

    func testUpcomingReleasesEmptyBeforeRefresh() {
        let catalog = EpisodeCatalog(cacheStore: makeTempCacheStore())
        XCTAssertEqual(catalog.upcomingReleases, [])
    }

    func testRefreshPopulatesUpcomingReleasesFromFetchedJSON() async throws {
        let json = """
        {
          "updatedAt": "2026-08-24",
          "releases": [
            {
              "catalogID": "die-drei-fragezeichen",
              "number": 241,
              "title": "Meister des Lichts",
              "releaseDate": "2026-09-18"
            }
          ]
        }
        """
        let fetcher = MockURLFetcher()
        fetcher.urlResult = .updated(data: Data(json.utf8), eTag: "abc", lastModified: nil)

        let catalog = EpisodeCatalog(cacheStore: makeTempCacheStore(), remoteDataSource: fetcher)
        await catalog.refreshUpcomingReleasesIfNeeded(force: true)

        XCTAssertEqual(catalog.upcomingReleases.count, 1)
        XCTAssertEqual(catalog.upcomingReleases.first?.catalogID, "die-drei-fragezeichen")
        XCTAssertEqual(catalog.upcomingReleases.first?.number, 241)
    }

    func testRefreshPersistsAcrossReinit() async throws {
        let json = """
        {
          "updatedAt": "2026-08-24",
          "releases": [
            { "catalogID": "tkkg", "number": 243, "title": "Die Fährte des Hehlers", "releaseDate": "2026-09-11" }
          ]
        }
        """
        let fetcher = MockURLFetcher()
        fetcher.urlResult = .updated(data: Data(json.utf8), eTag: nil, lastModified: nil)
        let store = makeTempCacheStore()

        let catalog = EpisodeCatalog(cacheStore: store, remoteDataSource: fetcher)
        await catalog.refreshUpcomingReleasesIfNeeded(force: true)

        let reloaded = EpisodeCatalog(cacheStore: store)
        XCTAssertEqual(reloaded.upcomingReleases.count, 1)
        XCTAssertEqual(reloaded.upcomingReleases.first?.catalogID, "tkkg")
    }

    func testUnreadableCacheIsRepairedBecauseNoETagIsSent() async throws {
        // Eine Cache-Datei in einem alten oder beschädigten Format dekodiert zu [].
        // Würde trotzdem der ETag mitgeschickt, antwortete der Server mit 304 und
        // die Liste bliebe dauerhaft leer.
        let store = makeTempCacheStore()
        var staleMetadata = RemoteCatalogMetadata()
        staleMetadata.eTag = "alter-etag"
        staleMetadata.lastCheckedAt = .now
        try store.saveRemoteMetadata(staleMetadata, universeName: CatalogSourceRegistry.upcomingReleasesMetadataKey)

        let json = """
        {
          "releases": [
            { "catalogID": "tkkg", "number": 243, "title": "Die Fährte des Hehlers", "releaseDate": "2026-09-11" }
          ]
        }
        """
        let fetcher = MockURLFetcher()
        fetcher.urlResult = .updated(data: Data(json.utf8), eTag: "neuer-etag", lastModified: nil)

        let catalog = EpisodeCatalog(cacheStore: store, remoteDataSource: fetcher)
        await catalog.refreshUpcomingReleasesIfNeeded()

        XCTAssertNotNil(fetcher.lastMetadata, "Es muss überhaupt ein Request rausgegangen sein")
        XCTAssertNil(fetcher.lastMetadata ?? nil, "Ohne Daten im Cache darf kein ETag gesendet werden")
        XCTAssertEqual(catalog.upcomingReleases.count, 1)
    }

    func testETagIsSentOnceDataIsCached() async throws {
        let store = makeTempCacheStore()
        let json = """
        {
          "releases": [
            { "catalogID": "tkkg", "number": 243, "title": "Die Fährte des Hehlers", "releaseDate": "2026-09-11" }
          ]
        }
        """
        let fetcher = MockURLFetcher()
        fetcher.urlResult = .updated(data: Data(json.utf8), eTag: "etag-1", lastModified: nil)

        let catalog = EpisodeCatalog(cacheStore: store, remoteDataSource: fetcher)
        await catalog.refreshUpcomingReleasesIfNeeded(force: true)
        await catalog.refreshUpcomingReleasesIfNeeded(force: true)

        XCTAssertEqual(fetcher.lastMetadata??.eTag, "etag-1")
    }

    func testMalformedPayloadLeavesCatalogUsableAndDoesNotSetRefreshError() async throws {
        let fetcher = MockURLFetcher()
        fetcher.urlResult = .updated(data: Data("nicht json".utf8), eTag: nil, lastModified: nil)

        let catalog = EpisodeCatalog(cacheStore: makeTempCacheStore(), remoteDataSource: fetcher)
        await catalog.refreshUpcomingReleasesIfNeeded(force: true)

        XCTAssertEqual(catalog.upcomingReleases, [])
        XCTAssertNil(catalog.lastRefreshError)
    }
}
