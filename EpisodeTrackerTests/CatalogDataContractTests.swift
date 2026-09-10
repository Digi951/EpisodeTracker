import XCTest
@testable import EpisodeTracker

/// Datenvertrag Paket 1 — Fixture-Validierung.
///
/// Beweist: der heutige App-Decoder liest V2-Kataloge (neue optionale
/// Provenienzfelder) verlustfrei, Legacy-Kataloge bleiben Bit für Bit
/// unverändert, kaputte/unbekannte Werte scheitern bzw. werden tolerant
/// behandelt wie im Vertrag festgelegt. Der V1.17-Decoder-Gegenbeweis
/// (eingefrorene Structs) folgt in Commit P1-D.
///
/// `@MainActor`, weil `CatalogEntry` / `CatalogParser` unter der
/// Default-Isolation des App-Targets main-actor-isoliert sind (wie
/// `MigrationFromV1StoreTests`).
@MainActor
final class CatalogDataContractTests: XCTestCase {

    // MARK: - Fixture-Zugriff

    private func fixtureData(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/CatalogContract", isDirectory: true)
            .appendingPathComponent(name)
        return try Data(contentsOf: url)
    }

    private func decodeDocument(_ fixture: String) throws -> CatalogParser.CatalogDocument {
        try JSONDecoder().decode(CatalogParser.CatalogDocument.self, from: fixtureData(fixture))
    }

    private func day(_ raw: String) -> Date? { CalendarDayFormatter.date(from: raw) }

    // MARK: - 1. V2 numbered

    func testV2NumberedDecodesAllProvenanceFields() throws {
        let doc = try decodeDocument("catalog_v2_numbered.json")

        XCTAssertEqual(doc.catalogFormat, 2)
        XCTAssertEqual(doc.version, 3)
        XCTAssertEqual(doc.entries.count, 3)

        let first = doc.entries[0]
        XCTAssertEqual(first.number, 1)
        XCTAssertEqual(first.releaseStatus, .released)
        XCTAssertEqual(first.releaseDate, day("2001-05-04"))
        XCTAssertEqual(first.sourceCheckedAt, day("2026-09-01"))
        XCTAssertEqual(first.changedAt, day("2026-08-15"))
        XCTAssertEqual(first.links["source"], "https://www.example-sender.de/mediathek/der-erste-fall")
        XCTAssertEqual(first.sourceURL?.absoluteString, "https://www.example-sender.de/mediathek/der-erste-fall")
        XCTAssertEqual(first.links["spotify"], "https://open.spotify.com/album/aaa")

        let second = doc.entries[1]
        XCTAssertEqual(second.releaseStatus, .announced)
        XCTAssertEqual(second.releaseDate, day("2026-12-01"))
        XCTAssertNil(second.sourceCheckedAt)
        XCTAssertEqual(second.changedAt, day("2026-09-09"))

        let special = doc.entries[2]
        XCTAssertEqual(special.kind, .special)
        XCTAssertEqual(special.slug, "live-hoerspiel-2019")
        XCTAssertEqual(special.releaseStatus, .unknown) // Feld fehlt → unknown
        XCTAssertNil(special.releaseDate)
    }

    // MARK: - 2. V2 anthology

    func testV2AnthologyEntriesHaveSlugNoNumberAndAreSpecial() throws {
        let doc = try decodeDocument("catalog_v2_anthology.json")

        XCTAssertEqual(doc.entries.count, 2)
        for entry in doc.entries {
            XCTAssertEqual(entry.kind, .special)
            XCTAssertNil(entry.number)
            XCTAssertNotNil(entry.slug)
            XCTAssertNotNil(entry.links["source"])
            XCTAssertEqual(entry.releaseStatus, .released)
        }
        XCTAssertEqual(doc.entries[0].slug, "la-premiere-enquete")
        XCTAssertEqual(doc.entries[0].sourceCheckedAt, day("2026-09-05"))
    }

    // MARK: - 3. Legacy bleibt unverändert

    func testLegacyFlatDecodesExactlyAsBefore() throws {
        let doc = try decodeDocument("catalog_legacy_flat.json")

        XCTAssertNil(doc.catalogFormat)
        XCTAssertEqual(doc.entries.count, 2)

        let first = doc.entries[0]
        XCTAssertEqual(first.links["spotify"], "https://open.spotify.com/album/4N9tvSjWfZXx3eHKblYEWQ")
        XCTAssertEqual(first.links["apple"], "https://music.apple.com/de/album/folge-1/1092529875")
        XCTAssertEqual(first.links["deezer"], "https://www.deezer.com/album/12761822")
        XCTAssertEqual(first.links["audible"], "https://www.audible.de/pd/B0B1QKF361")

        // Neue Felder: leer für Legacy.
        XCTAssertNil(first.releaseDate)
        XCTAssertNil(first.sourceCheckedAt)
        XCTAssertNil(first.changedAt)
        XCTAssertEqual(first.releaseStatus, .unknown)

        // Leere Legacy-URLs werden weiterhin verworfen (sanitized).
        let second = doc.entries[1]
        XCTAssertEqual(second.links, ["spotify": "https://open.spotify.com/album/0xldqK4Ocdt8dwQSxUzt6x"])
    }

    /// Ein Legacy-Eintrag muss ohne die neuen Keys serialisiert werden — sonst
    /// änderte sich der Disk-Cache für alle Bestandsdaten beim nächsten Schreiben.
    func testLegacyEntryEncodesWithoutTheNewKeys() throws {
        let doc = try decodeDocument("catalog_legacy_flat.json")
        let encoded = try JSONEncoder().encode(doc.entries[0])
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        XCTAssertNil(object["releaseDate"])
        XCTAssertNil(object["releaseStatus"])
        XCTAssertNil(object["sourceCheckedAt"])
        XCTAssertNil(object["changedAt"])

        let restored = try JSONDecoder().decode(CatalogEntry.self, from: encoded)
        XCTAssertEqual(restored, doc.entries[0])
    }

    // MARK: - 4. Unbekannte Felder

    func testUnknownFieldsAreIgnored() throws {
        let doc = try decodeDocument("catalog_v2_unknown_fields.json")

        XCTAssertEqual(doc.entries.count, 1)
        let entry = doc.entries[0]
        XCTAssertEqual(entry.title, "Mit Zusatzfeldern")
        XCTAssertEqual(entry.releaseStatus, .released)
        XCTAssertEqual(entry.changedAt, day("2026-09-01"))
        // Unbekannter links-Key bleibt erhalten (links ist bewusst offen),
        // wird aber von keiner Dienst-/Quell-Logik aufgegriffen.
        XCTAssertEqual(entry.links["youtube"], "https://youtube.com/watch?v=unknownkey")
        XCTAssertEqual(entry.links["spotify"], "https://open.spotify.com/album/known")
    }

    // MARK: - 5. Unbekannter Statuswert → unknown (kein Throw)

    func testUnknownReleaseStatusFallsBackToUnknown() throws {
        let doc = try decodeDocument("catalog_v2_bad_status.json")
        XCTAssertEqual(doc.entries[0].releaseStatus, .unknown)
    }

    // MARK: - 6. Falsch getyptes Datum → Fail-Fast

    func testWronglyTypedReleaseDateThrows() throws {
        let data = try fixtureData("catalog_v2_wrong_type.json")
        XCTAssertThrowsError(try JSONDecoder().decode(CatalogParser.CatalogDocument.self, from: data))
        // Auch über den Parser-Pfad darf der Payload nicht still teil-akzeptiert werden.
        XCTAssertThrowsError(
            try CatalogParser().parseNormalizedCatalogDocument(from: data, fallbackCollectionName: "X")
        )
    }

    // MARK: - 7. Cache-Roundtrip erhält die neuen Felder

    func testCacheRoundTripPreservesProvenanceFields() throws {
        let original = CatalogEntry(
            number: 7,
            kind: .regular,
            slug: nil,
            title: "Roundtrip",
            releaseYear: 2026,
            collectionName: "RT",
            links: ["spotify": "https://open.spotify.com/album/rt", "source": "https://sender.de/rt"],
            releaseDate: day("2026-11-30"),
            releaseStatus: .announced,
            sourceCheckedAt: day("2026-09-10"),
            changedAt: day("2026-09-08")
        )

        let encoded = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(CatalogEntry.self, from: encoded)

        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.releaseDate, day("2026-11-30"))
        XCTAssertEqual(restored.releaseStatus, .announced)
        XCTAssertEqual(restored.sourceCheckedAt, day("2026-09-10"))
        XCTAssertEqual(restored.changedAt, day("2026-09-08"))
    }

    // MARK: - 7b. Parser reicht die Felder durch (withCollectionName ist verlustfrei)

    func testParserKeepsProvenanceFieldsWhenNormalisingCollectionName() throws {
        let data = try fixtureData("catalog_v2_numbered.json")
        let normalized = try CatalogParser().parseNormalizedCatalogDocument(
            from: data,
            fallbackCollectionName: "Fallback"
        )

        XCTAssertEqual(normalized.catalogFormat, 2)
        XCTAssertEqual(normalized.collectionName, "Contract Test Reihe")
        let first = normalized.entries[0]
        XCTAssertEqual(first.collectionName, "Contract Test Reihe")
        XCTAssertEqual(first.releaseStatus, .released)
        XCTAssertEqual(first.releaseDate, day("2001-05-04"))
        XCTAssertEqual(first.sourceCheckedAt, day("2026-09-01"))
        XCTAssertEqual(first.changedAt, day("2026-08-15"))
    }

    // MARK: - 8. Terminfeed V2: number- und slug-Zeilen koexistieren

    func testFeedV2DecodesNumberedAndAnthologyRows() throws {
        let doc = try JSONDecoder().decode(
            UpcomingReleasesDocument.self,
            from: fixtureData("upcoming_feed_v2.json")
        )

        XCTAssertEqual(doc.feedVersion, 1)
        XCTAssertEqual(doc.releases.count, 3)

        let numbered = try XCTUnwrap(doc.releases.first { $0.catalogID == "die-drei-fragezeichen" })
        XCTAssertEqual(numbered.number, 241)
        XCTAssertNil(numbered.slug)
        XCTAssertEqual(numbered.releaseStatus, .announced)
        XCTAssertEqual(numbered.id, "die-drei-fragezeichen-241")

        let released = try XCTUnwrap(doc.releases.first { $0.catalogID == "tkkg" })
        XCTAssertEqual(released.releaseStatus, .released)

        let anthology = try XCTUnwrap(doc.releases.first { $0.catalogID == "fr-anthologie-pilot" })
        XCTAssertNil(anthology.number)
        XCTAssertEqual(anthology.slug, "le-secret-de-la-tour")
        XCTAssertEqual(anthology.releaseStatus, .announced) // Feld fehlt → announced
        XCTAssertEqual(anthology.id, "fr-anthologie-pilot-le-secret-de-la-tour")

        // IDs eindeutig.
        XCTAssertEqual(Set(doc.releases.map(\.id)).count, doc.releases.count)
    }

    // MARK: - 9. Zeile ohne number UND slug wird verworfen, der Rest bleibt

    func testFeedV2DropsIdlessRowButKeepsTheRest() throws {
        let doc = try JSONDecoder().decode(
            UpcomingReleasesDocument.self,
            from: fixtureData("upcoming_feed_v2_idless.json")
        )

        XCTAssertEqual(doc.releases.count, 2)
        XCTAssertEqual(
            Set(doc.releases.map(\.catalogID)),
            ["die-drei-fragezeichen", "fr-anthologie-pilot"]
        )
    }

    // MARK: - 10. V1.17-Decoder-Gegenbeweis (eingefrorene Structs)

    /// Ein 1.17-Client dekodiert einen V2-Katalog ohne Throw: die neuen
    /// optionalen Keys (`releaseDate`, `releaseStatus`, `sourceCheckedAt`,
    /// `changedAt`, `catalogFormat`) hat sein `CodingKeys`-Enum nicht, also
    /// werden sie schlicht ignoriert. Bekannte Felder kommen unverändert an.
    func testFrozen117CatalogDecoderReadsV2FixtureUnchanged() throws {
        let doc = try JSONDecoder().decode(
            LegacyCatalogDoc17.self,
            from: fixtureData("catalog_v2_numbered.json")
        )

        XCTAssertEqual(doc.entries.count, 3)

        let first = doc.entries[0]
        XCTAssertEqual(first.number, 1)
        XCTAssertEqual(first.title, "Der erste Fall")
        XCTAssertEqual(first.releaseYear, 2001)
        XCTAssertEqual(first.links["spotify"], "https://open.spotify.com/album/aaa")
        XCTAssertEqual(first.links["apple"], "https://music.apple.com/de/album/aaa")
        XCTAssertEqual(
            first.links["source"],
            "https://www.example-sender.de/mediathek/der-erste-fall"
        )

        let special = doc.entries[2]
        XCTAssertEqual(special.kind, .special)
        XCTAssertEqual(special.slug, "live-hoerspiel-2019")
        XCTAssertEqual(special.number, 1)
    }

    /// Ein 1.17-Client liest den erweiterten Terminfeed: `number`-Zeilen kommen
    /// unverändert durch, die Anthologie-Zeile (nur `slug`, kein `number`) lässt
    /// seinen `try container.decode(Int.self, forKey: .number)` werfen — die
    /// `LenientRow17`-Kapsel verwirft genau diese eine Zeile, kein Crash, der
    /// Rest der Liste bleibt.
    func testFrozen117FeedDecoderKeepsNumberedRowsDropsSlugOnly() throws {
        let doc = try JSONDecoder().decode(
            LegacyUpcomingDoc17.self,
            from: fixtureData("upcoming_feed_v2.json")
        )

        XCTAssertEqual(doc.releases.count, 2)
        XCTAssertEqual(doc.releases.map(\.number), [241, 243])
        XCTAssertEqual(doc.releases.map(\.catalogID), ["die-drei-fragezeichen", "tkkg"])
        XCTAssertFalse(doc.releases.contains { $0.catalogID == "fr-anthologie-pilot" })
        XCTAssertEqual(doc.releases[0].releaseDate, day("2026-09-18"))
    }

    /// Dieselbe Kapsel darf auch an einer komplett id-losen Zeile nicht scheitern:
    /// nur die `number`-Zeile überlebt, die id-lose und die slug-only Zeile
    /// fallen beide weg.
    func testFrozen117FeedDecoderSurvivesFullyBrokenRow() throws {
        let doc = try JSONDecoder().decode(
            LegacyUpcomingDoc17.self,
            from: fixtureData("upcoming_feed_v2_idless.json")
        )

        XCTAssertEqual(doc.releases.map(\.number), [241])
    }

    // MARK: - Sortierung mit gemischten number/slug-Zeilen bleibt stabil

    func testFeedSortOrdersMixedRowsDeterministically() throws {
        let doc = try JSONDecoder().decode(
            UpcomingReleasesDocument.self,
            from: fixtureData("upcoming_feed_v2.json")
        )
        let feed = UpcomingReleasesFeed.make(
            releases: doc.releases,
            activeCatalogIDs: ["die-drei-fragezeichen", "tkkg", "fr-anthologie-pilot"],
            namesByCatalogID: [
                "die-drei-fragezeichen": "Die drei ???",
                "tkkg": "TKKG",
                "fr-anthologie-pilot": "FR Anthologie"
            ],
            seenReleaseIDs: [],
            today: day("2026-09-01")!
        )

        // 09-11 TKKG, dann 09-18 (numbered vor slug: 241 < .max), dann 09-18 slug.
        XCTAssertEqual(
            feed.rows.map(\.id),
            [
                "tkkg-243",
                "die-drei-fragezeichen-241",
                "fr-anthologie-pilot-le-secret-de-la-tour"
            ]
        )
    }
}

// MARK: - Eingefrorene V1.17-Decoder-Doubles
//
// Wortgetreue Kopie der `CatalogEntry`- bzw. `UpcomingRelease`-Dekodierung, wie
// sie in 1.17 (Commit b97eef7, vor Paket 1) ausgeliefert wurde. Der Zweck ist,
// diesen Stand einzufrieren: solange diese Structs die Paket-1-Fixtures ohne
// Throw/Crash lesen, kann ein 1.17-Client die V2-Daten verarbeiten. Nicht
// anfassen, wenn sich die Produktions-Structs ändern — das ist der Punkt.
//
// `kind` wird bewusst über `EpisodeKind(rawValue:)` (nonisolated) statt über die
// synthetisierte, main-actor-isolierte `Decodable`-Conformance gelesen, damit die
// Doubles nonisolated bleiben können.

private struct LegacyCatalogDoc17: Decodable {
    let entries: [LegacyCatalogEntry17]
}

private struct LegacyCatalogEntry17: Decodable {
    let number: Int?
    let kind: EpisodeKind
    let slug: String?
    let title: String
    let releaseYear: Int
    let collectionName: String?
    let links: [String: String]

    private enum CodingKeys: String, CodingKey {
        case number, kind, slug, title, releaseYear, collectionName, links
        case spotifyURL, appleMusicURL, deezerURL, audibleURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.decodeIfPresent(Int.self, forKey: .number)
        kind = EpisodeKind(rawValue: try container.decodeIfPresent(String.self, forKey: .kind) ?? "") ?? .regular
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        title = try container.decode(String.self, forKey: .title)
        releaseYear = try container.decodeIfPresent(Int.self, forKey: .releaseYear) ?? 0
        collectionName = try container.decodeIfPresent(String.self, forKey: .collectionName)

        var resolved = try container.decodeIfPresent([String: String].self, forKey: .links) ?? [:]
        let legacy: [String: String?] = [
            "spotify": try container.decodeIfPresent(String.self, forKey: .spotifyURL),
            "apple": try container.decodeIfPresent(String.self, forKey: .appleMusicURL),
            "deezer": try container.decodeIfPresent(String.self, forKey: .deezerURL),
            "audible": try container.decodeIfPresent(String.self, forKey: .audibleURL)
        ]
        for (key, value) in legacy {
            guard let value, resolved[key] == nil else { continue }
            resolved[key] = value
        }
        links = resolved.reduce(into: [String: String]()) { result, pair in
            let trimmed = pair.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            result[pair.key] = trimmed
        }
    }
}

private struct LegacyUpcomingDoc17: Decodable {
    let releases: [LegacyUpcomingRelease17]

    private enum CodingKeys: String, CodingKey {
        case updatedAt, releases
    }

    private struct LenientRow17: Decodable {
        let release: LegacyUpcomingRelease17?
        init(from decoder: Decoder) throws {
            release = try? LegacyUpcomingRelease17(from: decoder)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        releases = try container.decode([LenientRow17].self, forKey: .releases).compactMap(\.release)
    }
}

private struct LegacyUpcomingRelease17: Decodable {
    let catalogID: String
    let number: Int
    let title: String
    let releaseDate: Date

    private enum CodingKeys: String, CodingKey {
        case catalogID, number, title, releaseDate
    }

    private static func dayFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        catalogID = try container.decode(String.self, forKey: .catalogID)
        number = try container.decode(Int.self, forKey: .number)
        title = try container.decode(String.self, forKey: .title)
        let rawDate = try container.decode(String.self, forKey: .releaseDate)
        guard let date = Self.dayFormatter().date(from: rawDate) else {
            throw DecodingError.dataCorruptedError(
                forKey: .releaseDate,
                in: container,
                debugDescription: "Erwartet wurde yyyy-MM-dd, gelesen wurde \"\(rawDate)\""
            )
        }
        releaseDate = date
    }
}
