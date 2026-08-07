import XCTest
@testable import EpisodeTracker

final class CatalogEntryLinksTests: XCTestCase {

    private func decode(_ json: String) throws -> CatalogEntry {
        try JSONDecoder().decode(CatalogEntry.self, from: Data(json.utf8))
    }

    func testMissingReleaseYearDefaultsToZero() throws {
        let entry = try decode("""
        {
          "number": 3,
          "title": "Ohne Jahresangabe"
        }
        """)

        XCTAssertEqual(entry.releaseYear, 0)
    }

    // MARK: - Legacy-Felder

    func testDecodesLegacyNamedFieldsIntoLinks() throws {
        let entry = try decode("""
        {
          "number": 1,
          "title": "und der Super-Papagei",
          "releaseYear": 1979,
          "spotifyURL": "https://open.spotify.com/album/abc",
          "appleMusicURL": "https://music.apple.com/album/1",
          "deezerURL": "https://deezer.com/album/2",
          "audibleURL": "https://audible.de/pd/3"
        }
        """)

        XCTAssertEqual(entry.links["spotify"], "https://open.spotify.com/album/abc")
        XCTAssertEqual(entry.links["apple"], "https://music.apple.com/album/1")
        XCTAssertEqual(entry.links["deezer"], "https://deezer.com/album/2")
        XCTAssertEqual(entry.links["audible"], "https://audible.de/pd/3")
    }

    func testExplicitLinksFieldDecodesDirectly() throws {
        let entry = try decode("""
        {
          "number": 1,
          "title": "Test",
          "releaseYear": 2000,
          "links": { "spotify": "https://open.spotify.com/album/xyz" }
        }
        """)

        XCTAssertEqual(entry.links["spotify"], "https://open.spotify.com/album/xyz")
        XCTAssertNil(entry.links["apple"])
    }

    // MARK: - Neues links-Feld

    func testDecodesLinksDictionary() throws {
        let entry = try decode("""
        {
          "number": null,
          "kind": "special",
          "slug": "weihnachten-2024",
          "title": "Sondersendung",
          "releaseYear": 2024,
          "links": { "audioteka": "https://audioteka.com/pl/audiobook/x" }
        }
        """)

        XCTAssertEqual(entry.links["audioteka"], "https://audioteka.com/pl/audiobook/x")
    }

    func testExplicitLinksWinOverLegacyFields() throws {
        let entry = try decode("""
        {
          "number": 1,
          "title": "Test",
          "releaseYear": 2000,
          "spotifyURL": "https://legacy.example/album",
          "links": { "spotify": "https://explicit.example/album" }
        }
        """)

        XCTAssertEqual(entry.links["spotify"], "https://explicit.example/album")
    }

    func testIgnoresEmptyAndWhitespaceLinkValues() throws {
        let entry = try decode("""
        {
          "number": 1,
          "title": "Test",
          "releaseYear": 2000,
          "spotifyURL": "   ",
          "links": { "deezer": "" }
        }
        """)

        XCTAssertTrue(entry.links.isEmpty)
        XCTAssertFalse(entry.hasStreamingLink)
    }

    // MARK: - Roundtrip

    func testEncodeDecodeRoundtripPreservesUnknownServices() throws {
        let original = CatalogEntry(
            number: 5,
            title: "Test",
            releaseYear: 2001,
            links: ["storytel": "https://storytel.com/nl/books/9"]
        )

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(CatalogEntry.self, from: data)

        XCTAssertEqual(restored.links["storytel"], "https://storytel.com/nl/books/9")
        XCTAssertEqual(restored, original)
    }

    func testConvenienceInitBuildsLinks() {
        let entry = CatalogEntry(
            number: 1,
            title: "Test",
            releaseYear: 2000,
            spotifyURL: "https://open.spotify.com/album/abc",
            audibleURL: nil
        )

        XCTAssertEqual(entry.links, ["spotify": "https://open.spotify.com/album/abc"])
    }

    // MARK: - Pipeline-Durchreichung

    func testParserPreservesUnknownServiceLinks() throws {
        let json = """
        {
          "version": 1,
          "entries": [
            {
              "number": 1,
              "title": "Odcinek pierwszy",
              "releaseYear": 2024,
              "links": { "audioteka": "https://audioteka.com/pl/audiobook/x" }
            }
          ]
        }
        """

        let document = try CatalogParser().parseNormalizedCatalogDocument(
            from: Data(json.utf8),
            fallbackCollectionName: "Testkatalog"
        )

        XCTAssertEqual(
            document.entries.first?.links["audioteka"],
            "https://audioteka.com/pl/audiobook/x"
        )
    }

    // MARK: - Bevorzugter Link ohne feste Dienstnamen

    func testPreferredLinkFollowsMarketProfileOrder() {
        let entry = CatalogEntry(
            number: 1,
            title: "Test",
            releaseYear: 2000,
            links: [
                "audible": "https://audible.de/pd/1",
                "spotify": "https://open.spotify.com/album/2"
            ]
        )

        XCTAssertEqual(
            entry.preferredLink(for: [.spotify, .apple, .deezer, .audible]),
            "https://open.spotify.com/album/2"
        )
        XCTAssertEqual(
            entry.preferredLink(for: [.audible, .spotify]),
            "https://audible.de/pd/1"
        )
    }

    func testPreferredLinkReturnsNilWhenNoServiceMatches() {
        let entry = CatalogEntry(
            number: 1,
            title: "Test",
            releaseYear: 2000,
            links: ["storytel": "https://storytel.com/nl/books/9"]
        )

        XCTAssertNil(entry.preferredLink(for: [.spotify, .apple]))
    }
}
