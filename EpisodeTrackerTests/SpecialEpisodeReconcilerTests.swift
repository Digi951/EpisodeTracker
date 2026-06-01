import XCTest
@testable import EpisodeTracker

final class SpecialEpisodeReconcilerTests: XCTestCase {
    func testReconcilerAdoptsCatalogSlugOnTitleYearCollectionMatch() {
        let u = Universe(name: "Die drei ???")
        let manual = Episode(
            episodeNumber: 0,
            title: "Phantomsee",
            releaseYear: 2024,
            kind: .special,
            catalogSlug: "phantomsee-2024-manual",
            universe: u
        )
        let catalog = [
            CatalogEntry(
                number: nil,
                kind: .special,
                slug: "phantomsee-2024",
                title: "Phantomsee",
                releaseYear: 2024,
                collectionName: "Die drei ???",
                spotifyURL: "https://open.spotify.com/album/abc"
            )
        ]

        SpecialEpisodeReconciler.reconcile(libraryEpisodes: [manual], catalogEntries: catalog)

        XCTAssertEqual(manual.catalogSlug, "phantomsee-2024")
        XCTAssertEqual(manual.streamingURL, "https://open.spotify.com/album/abc")
        XCTAssertNotNil(manual.specialUpdatedAt)
        XCTAssertEqual(manual.resolvedSyncKey, manual.syncKey)
    }

    func testReconcilerSkipsOnYearMismatch() {
        let u = Universe(name: "Die drei ???")
        let manual = Episode(
            episodeNumber: 0,
            title: "Phantomsee",
            releaseYear: 2023,
            kind: .special,
            catalogSlug: "phantomsee-2023-manual",
            universe: u
        )
        let catalog = [
            CatalogEntry(number: nil, kind: .special, slug: "phantomsee-2024", title: "Phantomsee", releaseYear: 2024, collectionName: "Die drei ???")
        ]

        SpecialEpisodeReconciler.reconcile(libraryEpisodes: [manual], catalogEntries: catalog)

        XCTAssertEqual(manual.catalogSlug, "phantomsee-2023-manual")
    }

    func testReconcilerSkipsOnAmbiguousMatch() {
        let u = Universe(name: "Die drei ???")
        let manual = Episode(
            episodeNumber: 0,
            title: "Phantomsee",
            releaseYear: 2024,
            kind: .special,
            catalogSlug: "phantomsee-manual",
            universe: u
        )
        let catalog = [
            CatalogEntry(number: nil, kind: .special, slug: "phantomsee-a", title: "Phantomsee", releaseYear: 2024, collectionName: "Die drei ???"),
            CatalogEntry(number: nil, kind: .special, slug: "phantomsee-b", title: "Phantomsee", releaseYear: 2024, collectionName: "Die drei ???"),
        ]

        SpecialEpisodeReconciler.reconcile(libraryEpisodes: [manual], catalogEntries: catalog)

        XCTAssertEqual(manual.catalogSlug, "phantomsee-manual")
    }
}
