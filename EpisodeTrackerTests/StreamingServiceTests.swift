import XCTest
@testable import EpisodeTracker

final class StreamingServiceTests: XCTestCase {

    // MARK: - Catalog Direct Links

    func testCatalogURLReturnsSpotifyLink() {
        let entry = CatalogEntry(
            number: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            spotifyURL: "https://open.spotify.com/album/3x2yFMPCcRSrD2FwTVACKZ"
        )

        let url = StreamingService.spotify.catalogURL(from: entry)
        XCTAssertEqual(url?.absoluteString, "https://open.spotify.com/album/3x2yFMPCcRSrD2FwTVACKZ")
    }

    func testCatalogURLReturnsAppleMusicLink() {
        let entry = CatalogEntry(
            number: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            appleMusicURL: "https://music.apple.com/album/1234567"
        )

        let url = StreamingService.apple.catalogURL(from: entry)
        XCTAssertEqual(url?.absoluteString, "https://music.apple.com/album/1234567")
    }

    func testCatalogURLReturnsDeezerLink() {
        let entry = CatalogEntry(
            number: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            deezerURL: "https://www.deezer.com/album/1234567"
        )

        let url = StreamingService.deezer.catalogURL(from: entry)
        XCTAssertEqual(url?.absoluteString, "https://www.deezer.com/album/1234567")
    }

    func testCatalogURLReturnsAudibleLink() {
        let entry = CatalogEntry(
            number: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979,
            audibleURL: "https://www.audible.de/pd/B004V3EXGO"
        )

        let url = StreamingService.audible.catalogURL(from: entry)
        XCTAssertEqual(url?.absoluteString, "https://www.audible.de/pd/B004V3EXGO")
    }

    func testCatalogURLReturnsNilWhenMissing() {
        let entry = CatalogEntry(
            number: 1,
            title: "und der Super-Papagei",
            releaseYear: 1979
        )

        XCTAssertNil(StreamingService.spotify.catalogURL(from: entry))
        XCTAssertNil(StreamingService.apple.catalogURL(from: entry))
        XCTAssertNil(StreamingService.deezer.catalogURL(from: entry))
        XCTAssertNil(StreamingService.audible.catalogURL(from: entry))
    }

    func testCatalogURLReturnsNilForWrongService() {
        let entry = CatalogEntry(
            number: 1,
            title: "Test",
            releaseYear: 2000,
            spotifyURL: "https://open.spotify.com/album/abc"
        )

        XCTAssertNotNil(StreamingService.spotify.catalogURL(from: entry))
        XCTAssertNil(StreamingService.apple.catalogURL(from: entry))
        XCTAssertNil(StreamingService.deezer.catalogURL(from: entry))
        XCTAssertNil(StreamingService.audible.catalogURL(from: entry))
    }

    func testCatalogEntryDetectsStreamingLinks() {
        let linkedEntry = CatalogEntry(
            number: 1,
            title: "Test",
            releaseYear: 2000,
            appleMusicURL: " https://music.apple.com/de/album/test/123 "
        )
        let staleEntry = CatalogEntry(number: 2, title: "Alt", releaseYear: 2001)

        XCTAssertTrue(linkedEntry.hasStreamingLink)
        XCTAssertFalse(staleEntry.hasStreamingLink)
    }

    // MARK: - Direct URL from Episode

    func testDirectURLReturnsValidURL() {
        let url = StreamingService.spotify.directURL(from: "https://open.spotify.com/album/abc123")
        XCTAssertEqual(url?.absoluteString, "https://open.spotify.com/album/abc123")
    }

    func testDirectURLReturnsNilForNilInput() {
        XCTAssertNil(StreamingService.spotify.directURL(from: nil))
    }

    func testDirectURLReturnsNilForEmptyString() {
        XCTAssertNil(StreamingService.spotify.directURL(from: ""))
    }

    func testDirectURLTrimsWhitespace() {
        let url = StreamingService.spotify.directURL(from: " https://open.spotify.com/album/abc123 ")
        XCTAssertEqual(url?.absoluteString, "https://open.spotify.com/album/abc123")
    }

    // MARK: - Display Properties

    func testDisplayNames() {
        XCTAssertEqual(StreamingService.spotify.displayName, "Spotify")
        XCTAssertEqual(StreamingService.apple.displayName, "Apple")
        XCTAssertEqual(StreamingService.deezer.displayName, "Deezer")
        XCTAssertEqual(StreamingService.audible.displayName, "Audible")
    }

    func testAllCasesContainsSupportedServices() {
        XCTAssertEqual(StreamingService.allCases, [.spotify, .apple, .deezer, .audible])
    }

    // MARK: - Backward Compatibility

    func testAppleMusicRawValueParsesAsApple() {
        let service = StreamingService(rawValue: "appleMusic")
        XCTAssertEqual(service, .apple)
    }

    func testAppleRawValueParsesAsApple() {
        let service = StreamingService(rawValue: "apple")
        XCTAssertEqual(service, .apple)
    }

    func testAppleRawValueIsApple() {
        XCTAssertEqual(StreamingService.apple.rawValue, "apple")
    }

    // MARK: - Dynamic Display Names

    func testAppleDisplayNameForAppleMusicURL() {
        let name = StreamingService.apple.displayName(for: "https://music.apple.com/de/album/test/123")
        XCTAssertEqual(name, "Apple Music")
    }

    func testAppleDisplayNameForAppleBooksURL() {
        let name = StreamingService.apple.displayName(for: "https://books.apple.com/de/audiobook/test/id123")
        XCTAssertEqual(name, "Apple Books")
    }

    func testAppleDisplayNameForGenericURL() {
        let name = StreamingService.apple.displayName(for: "https://apple.com/something")
        XCTAssertEqual(name, "Apple")
    }

    func testAppleDisplayNameForNilURL() {
        let name = StreamingService.apple.displayName(for: nil)
        XCTAssertEqual(name, "Apple")
    }

    func testNonAppleServiceIgnoresURLForDisplayName() {
        let name = StreamingService.spotify.displayName(for: "https://music.apple.com/test")
        XCTAssertEqual(name, "Spotify")
    }

    // MARK: - Market Profile

    func testMarketProfileContainsAllServices() {
        let profile = StreamingMarketProfile.current
        XCTAssertFalse(profile.services.isEmpty)
        XCTAssertTrue(profile.services.contains(.spotify))
        XCTAssertTrue(profile.services.contains(.apple))
    }

    // MARK: - Link Resolver

    func testResolverPrioritizesDirectURLOverCatalog() {
        let catalog = EpisodeCatalog.shared
        let episode = Episode(
            episodeNumber: 1,
            title: "Test",
            releaseYear: 2020,
            isListened: false
        )
        episode.streamingURL = "https://open.spotify.com/album/direct123"

        let resolver = StreamingLinkResolver(service: .spotify, catalog: catalog)
        let result = resolver.resolve(for: episode)

        XCTAssertEqual(result?.url.absoluteString, "https://open.spotify.com/album/direct123")
    }

    func testResolverReturnsNilWhenNoLinksAvailable() {
        let catalog = EpisodeCatalog.shared
        let episode = Episode(
            episodeNumber: 99999,
            title: "Test",
            releaseYear: 2020,
            isListened: false
        )

        let resolver = StreamingLinkResolver(service: .spotify, catalog: catalog)
        let result = resolver.resolve(for: episode)

        XCTAssertNil(result)
    }
}
