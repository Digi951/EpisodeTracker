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

        let url = StreamingService.appleMusic.catalogURL(from: entry)
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
        XCTAssertNil(StreamingService.appleMusic.catalogURL(from: entry))
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
        XCTAssertNil(StreamingService.appleMusic.catalogURL(from: entry))
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
        XCTAssertEqual(StreamingService.appleMusic.displayName, "Apple Music")
        XCTAssertEqual(StreamingService.deezer.displayName, "Deezer")
        XCTAssertEqual(StreamingService.audible.displayName, "Audible")
    }

    func testAllCasesContainsSupportedServices() {
        XCTAssertEqual(StreamingService.allCases, [.spotify, .appleMusic, .deezer, .audible])
    }
}
