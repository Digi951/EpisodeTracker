import XCTest
@testable import EpisodeTracker

final class SeasonalEpisodesTests: XCTestCase {
    private let active: Set<String> = ["tkkg"]

    func testChristmasSeasonRunsFromFirstToTwentySixthOfDecember() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!

        func season(_ month: Int, _ day: Int) -> CatalogSeason? {
            let date = calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
            return SeasonalContext.activeSeason(on: date, calendar: calendar)
        }

        XCTAssertNil(season(11, 30))
        XCTAssertEqual(season(12, 1), .christmas)
        XCTAssertEqual(season(12, 26), .christmas)
        XCTAssertNil(season(12, 27))
    }

    func testAccentOnlyInSeasonAndWhenEnabled() {
        let calendar = Calendar(identifier: .gregorian)
        let december = calendar.date(from: DateComponents(year: 2026, month: 12, day: 10, hour: 12))!
        let november = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))!

        XCTAssertEqual(SeasonalAccent.current(enabled: true, on: december)?.season, .christmas)
        XCTAssertNil(SeasonalAccent.current(enabled: false, on: december))
        XCTAssertNil(SeasonalAccent.current(enabled: true, on: november))
    }

    func testOwnedTaggedEpisodesComeFromLibraryAndMissingOnesFromCatalog() {
        let tkkg = Universe(name: "TKKG")
        let ownedOpen = Episode(episodeNumber: 165, title: "Advent mit Knall-Effekt", releaseYear: 2009, universe: tkkg)
        let ownedListened = Episode(episodeNumber: 134, title: "Wer stoppt die Weihnachts-Gangster", releaseYear: 2003, universe: tkkg)
        ownedListened.isListened = true
        let ownedUntagged = Episode(episodeNumber: 1, title: "Die Jagd nach den Millionendieben", releaseYear: 1981, universe: tkkg)
        let hidden = Episode(episodeNumber: 200, title: "Ausgeblendet", releaseYear: 2012, universe: tkkg)
        hidden.isHidden = true

        let entries = [
            entry(134, "Wer stoppt die Weihnachts-Gangster", year: 2003, season: .christmas),
            entry(165, "Advent mit Knall-Effekt", year: 2009, season: .christmas),
            entry(200, "Ausgeblendet", year: 2012, season: .christmas),
            entry(1, "Die Jagd nach den Millionendieben", year: 1981),
            CatalogEntry(
                number: nil,
                kind: .special,
                slug: "weihnachtsgeiseln",
                title: "Die Weihnachtsgeiseln (Adventskalender)",
                releaseYear: 2024,
                collectionName: "TKKG",
                links: [:],
                season: .christmas
            ),
            entry(5, "Weihnachten in Fünf Freunde", year: 1990, collection: "Fünf Freunde", season: .christmas)
        ]

        let content = SeasonalEpisodes.make(
            season: .christmas,
            entries: entries,
            activeCollectionNames: active,
            libraryEpisodes: [ownedOpen, ownedListened, ownedUntagged, hidden]
        )

        XCTAssertEqual(content.libraryEpisodes.map(\.episodeNumber), [165, 134], "Ungehörte zuerst, Ausgeblendete nie")
        XCTAssertEqual(
            content.catalogEntries.map(\.entry.title),
            ["Die Weihnachtsgeiseln (Adventskalender)"],
            "Inaktive Kataloge und vorhandene Folgen fehlen"
        )
    }

    func testOwnedSpecialMatchesBySlug() {
        let tkkg = Universe(name: "TKKG")
        let special = Episode(
            episodeNumber: 0,
            title: "Die Weihnachtsgeiseln",
            releaseYear: 2024,
            kind: .special,
            catalogSlug: "Weihnachtsgeiseln",
            universe: tkkg
        )
        let entries = [
            CatalogEntry(
                number: 9,
                kind: .special,
                slug: "weihnachtsgeiseln",
                title: "Die Weihnachtsgeiseln (Adventskalender)",
                releaseYear: 2024,
                collectionName: "TKKG",
                links: [:],
                season: .christmas
            )
        ]

        let content = SeasonalEpisodes.make(
            season: .christmas,
            entries: entries,
            activeCollectionNames: active,
            libraryEpisodes: [special]
        )

        XCTAssertEqual(content.libraryEpisodes.count, 1)
        XCTAssertTrue(content.catalogEntries.isEmpty)
    }

    /// Eine Sonderfolge mit Nummer (TKKG-Adventskalender Nr. 4) darf die
    /// reguläre Folge 4 nicht als „vorhanden“ verdecken.
    func testNumberedSpecialDoesNotHideRegularEpisodeWithSameNumber() {
        let tkkg = Universe(name: "TKKG")
        let special = Episode(
            episodeNumber: 134,
            title: "Sonderfolge",
            releaseYear: 2020,
            kind: .special,
            catalogSlug: "sonderfolge-2020",
            universe: tkkg
        )

        let content = SeasonalEpisodes.make(
            season: .christmas,
            entries: [entry(134, "Wer stoppt die Weihnachts-Gangster", year: 2002, season: .christmas)],
            activeCollectionNames: active,
            libraryEpisodes: [special]
        )

        XCTAssertTrue(content.libraryEpisodes.isEmpty)
        XCTAssertEqual(content.catalogEntries.map(\.entry.number), [134])
    }

    /// Katalog-Sonderfolgen ohne Slug werden über den Titel zugeordnet,
    /// sonst stünden sie nach dem Anlegen weiter als „fehlt“ in der Liste.
    func testUnsluggedSpecialMatchesByTitle() {
        let tkkg = Universe(name: "TKKG")
        let owned = Episode(
            episodeNumber: 0,
            title: "Weihnachtsmenü",
            releaseYear: 2018,
            kind: .special,
            universe: tkkg
        )
        let entries = [
            CatalogEntry(number: nil, kind: .special, title: "Weihnachtsmenü", releaseYear: 2018, collectionName: "TKKG", links: [:], season: .christmas)
        ]

        let before = SeasonalEpisodes.make(season: .christmas, entries: entries, activeCollectionNames: active, libraryEpisodes: [])
        let after = SeasonalEpisodes.make(season: .christmas, entries: entries, activeCollectionNames: active, libraryEpisodes: [owned])

        XCTAssertEqual(before.catalogEntries.count, 1)
        XCTAssertTrue(after.catalogEntries.isEmpty)
        XCTAssertEqual(after.libraryEpisodes.map(\.title), ["Weihnachtsmenü"])
    }

    func testSeasonDecodesAndUnknownSeasonIsIgnored() throws {
        let json = """
        [
          {"number": 1, "title": "A", "releaseYear": 2000, "season": "christmas"},
          {"number": 2, "title": "B", "releaseYear": 2000, "season": "Christmas"},
          {"number": 3, "title": "C", "releaseYear": 2000, "season": "halloween"},
          {"number": 4, "title": "D", "releaseYear": 2000}
        ]
        """
        let decoded = try JSONDecoder().decode([CatalogEntry].self, from: Data(json.utf8))

        XCTAssertEqual(decoded.map(\.season), [.christmas, .christmas, nil, nil])

        let roundTrip = try JSONDecoder().decode(
            [CatalogEntry].self,
            from: JSONEncoder().encode(decoded)
        )
        XCTAssertEqual(roundTrip, decoded)
        XCTAssertEqual(decoded[0].withCollectionName("X").season, .christmas)
    }

    private func entry(
        _ number: Int,
        _ title: String,
        year: Int,
        collection: String = "TKKG",
        season: CatalogSeason? = nil
    ) -> CatalogEntry {
        CatalogEntry(
            number: number,
            title: title,
            releaseYear: year,
            collectionName: collection,
            links: [:],
            season: season
        )
    }
}
