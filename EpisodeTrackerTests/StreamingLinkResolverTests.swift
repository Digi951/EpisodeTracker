import XCTest
import SwiftData
@testable import EpisodeTracker

@MainActor
final class StreamingLinkResolverTests: XCTestCase {

    private func makeTempCacheStore() -> CatalogCacheStore {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StreamingLinkResolverTests-\(UUID().uuidString)")
        return CatalogCacheStore(directoryURL: tempDir)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    /// Baut einen Katalog mit den übergebenen Roh-Einträgen für „France Culture".
    private func makeCatalog(entriesJSON: String) throws -> EpisodeCatalog {
        let store = makeTempCacheStore()
        let catalog = EpisodeCatalog(cacheStore: store)
        let json = """
        { "collectionName": "France Culture", "entries": \(entriesJSON) }
        """
        try catalog.importCatalog(data: Data(json.utf8), into: "France Culture")
        return catalog
    }

    private func makeEpisode(
        in context: ModelContext,
        number: Int = 0,
        kind: EpisodeKind = .special,
        slug: String? = "le-horla-2019"
    ) -> Episode {
        let universe = Universe(name: "France Culture")
        context.insert(universe)
        let episode = Episode(
            episodeNumber: number,
            title: "Le Horla",
            releaseYear: 2019,
            kind: kind,
            catalogSlug: slug,
            universe: universe
        )
        context.insert(episode)
        return episode
    }

    func testResolvesTheReservedSourceKeyWhenNoStreamingServiceMatches() throws {
        let context = try makeContext()
        let catalog = try makeCatalog(entriesJSON: """
        [ { "number": null, "kind": "special", "slug": "le-horla-2019", "title": "Le Horla",
            "releaseYear": 2019, "links": { "source": "https://www.radiofrance.fr/x" } } ]
        """)
        let episode = makeEpisode(in: context)

        let result = StreamingLinkResolver(service: .spotify, catalog: catalog).resolve(for: episode)

        XCTAssertEqual(result?.url.absoluteString, "https://www.radiofrance.fr/x")
        XCTAssertEqual(result?.systemImage, "arrow.up.forward.square")
        XCTAssertFalse(result?.label.isEmpty ?? true)
        XCTAssertNotEqual(result?.systemImage, StreamingService.spotify.iconName)
    }

    func testStreamingServiceWinsOverTheSourceKey() throws {
        let context = try makeContext()
        let catalog = try makeCatalog(entriesJSON: """
        [ { "number": 1, "kind": "regular", "title": "Le Horla", "releaseYear": 2019,
            "links": { "spotify": "https://open.spotify.com/album/2",
                       "source": "https://www.radiofrance.fr/x" } } ]
        """)
        let episode = makeEpisode(in: context, number: 1, kind: .regular, slug: nil)

        let result = StreamingLinkResolver(service: .spotify, catalog: catalog).resolve(for: episode)

        XCTAssertEqual(result?.url.absoluteString, "https://open.spotify.com/album/2")
        XCTAssertEqual(result?.systemImage, StreamingService.spotify.iconName)
    }

    func testSourceKeyIsAFallbackNotNilWhenThePreferredServiceHasNoLink() throws {
        let context = try makeContext()
        let catalog = try makeCatalog(entriesJSON: """
        [ { "number": 1, "kind": "regular", "title": "Le Horla", "releaseYear": 2019,
            "links": { "source": "https://www.radiofrance.fr/x" } } ]
        """)
        let episode = makeEpisode(in: context, number: 1, kind: .regular, slug: nil)

        let result = StreamingLinkResolver(service: .apple, catalog: catalog).resolve(for: episode)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.url.absoluteString, "https://www.radiofrance.fr/x")
    }

    func testReturnsNilWhenNeitherAServiceLinkNorASourceLinkExists() throws {
        let context = try makeContext()
        let catalog = try makeCatalog(entriesJSON: """
        [ { "number": 1, "kind": "regular", "title": "Le Horla", "releaseYear": 2019, "links": {} } ]
        """)
        let episode = makeEpisode(in: context, number: 1, kind: .regular, slug: nil)

        let result = StreamingLinkResolver(service: .spotify, catalog: catalog).resolve(for: episode)

        XCTAssertNil(result)
    }

    func testAnthologySpecialFindsItsSourceViaSlugLookup() throws {
        let context = try makeContext()
        let catalog = try makeCatalog(entriesJSON: """
        [ { "number": null, "kind": "special", "slug": "le-horla-2019", "title": "Le Horla",
            "releaseYear": 2019, "links": { "source": "https://www.radiofrance.fr/le-horla" } } ]
        """)
        // episodeNumber 0 → Nummernsuche greift nicht; nur der Slug führt zum Eintrag.
        let episode = makeEpisode(in: context, number: 0, kind: .special, slug: "le-horla-2019")

        let result = StreamingLinkResolver(service: .spotify, catalog: catalog).resolve(for: episode)

        XCTAssertEqual(result?.url.absoluteString, "https://www.radiofrance.fr/le-horla")
    }
}
