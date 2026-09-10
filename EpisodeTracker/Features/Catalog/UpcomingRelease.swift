import Foundation

struct UpcomingRelease: Codable, Equatable, Identifiable {
    let catalogID: String
    /// Folgennummer bei `numbered`-Serien. Bei Anthologie-Zeilen `nil` — dort
    /// trägt `slug` die Identität (Datenvertrag §5.4).
    let number: Int?
    let slug: String?
    let title: String
    let releaseDate: Date
    /// Im Feed praktisch immer `announced`; `released`, sobald belegt (dann
    /// fällt die Zeile beim nächsten Lauf ohnehin raus). Fehlt das Feld,
    /// gilt `announced`.
    let releaseStatus: CatalogReleaseStatus

    var id: String { "\(catalogID)-\(number.map(String.init) ?? slug ?? "?")" }

    private enum CodingKeys: String, CodingKey {
        case catalogID, number, slug, title, releaseDate, releaseStatus
    }

    init(
        catalogID: String,
        number: Int? = nil,
        slug: String? = nil,
        title: String,
        releaseDate: Date,
        releaseStatus: CatalogReleaseStatus = .announced
    ) {
        self.catalogID = catalogID
        self.number = number
        self.slug = slug
        self.title = title
        self.releaseDate = releaseDate
        self.releaseStatus = releaseStatus
    }

    // Datum als reiner Kalendertag ("2026-09-18"), an lokale Mitternacht
    // verankert — siehe `CalendarDayFormatter`. Cache- und Remote-JSON nutzen
    // dasselbe Format, damit beide Wege denselben `Date`-Wert ergeben.

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        catalogID = try container.decode(String.self, forKey: .catalogID)
        number = try container.decodeIfPresent(Int.self, forKey: .number)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        title = try container.decode(String.self, forKey: .title)

        // Ohne Nummer und ohne Slug hätte die Zeile keine stabile Identität —
        // verwerfen (LenientRelease fängt das ab), statt eine id-lose Zeile
        // durchzulassen.
        guard number != nil || slug != nil else {
            throw DecodingError.dataCorruptedError(
                forKey: .number,
                in: container,
                debugDescription: "Terminzeile braucht number oder slug"
            )
        }

        let rawDate = try container.decode(String.self, forKey: .releaseDate)
        guard let date = CalendarDayFormatter.date(from: rawDate) else {
            throw DecodingError.dataCorruptedError(
                forKey: .releaseDate,
                in: container,
                debugDescription: "Erwartet wurde yyyy-MM-dd, gelesen wurde \"\(rawDate)\""
            )
        }
        releaseDate = date

        // Fehlt das Feld → announced (Feed-Semantik). Vorhandener, unbekannter
        // Rohwert → unknown (tolerant), nicht werfen.
        if let raw = try container.decodeIfPresent(String.self, forKey: .releaseStatus) {
            releaseStatus = CatalogReleaseStatus.resolve(raw)
        } else {
            releaseStatus = .announced
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(catalogID, forKey: .catalogID)
        try container.encodeIfPresent(number, forKey: .number)
        try container.encodeIfPresent(slug, forKey: .slug)
        try container.encode(title, forKey: .title)
        try container.encode(CalendarDayFormatter.string(from: releaseDate), forKey: .releaseDate)
        // Nur schreiben, wenn abweichend vom Default: eine heutige Cache-Zeile
        // (nur number/title/releaseDate) wird byte-gleich wie vor Paket 1
        // serialisiert.
        if releaseStatus != .announced {
            try container.encode(releaseStatus, forKey: .releaseStatus)
        }
    }
}

struct UpcomingReleasesDocument: Decodable {
    let updatedAt: String?
    /// Datenvertrag §5.4: `1` = additiv erweiterter Feed. Ein künftiger echter
    /// Bruch führt `2` + eine separate Datei ein. Aktuell nur gelesen, nicht
    /// ausgewertet.
    let feedVersion: Int?
    let releases: [UpcomingRelease]

    private enum CodingKeys: String, CodingKey {
        case updatedAt, feedVersion, releases
    }

    /// upcoming_releases.json wird wöchentlich automatisch erzeugt und nicht gegen
    /// ein Schema geprüft. Ein einzelner kaputter Eintrag darf deshalb nicht das
    /// gesamte Dokument verwerfen - dann stünde die Liste wortlos leer da.
    private struct LenientRelease: Decodable {
        let release: UpcomingRelease?

        init(from decoder: Decoder) throws {
            release = try? UpcomingRelease(from: decoder)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        feedVersion = try container.decodeIfPresent(Int.self, forKey: .feedVersion)
        releases = try container.decode([LenientRelease].self, forKey: .releases).compactMap(\.release)
    }
}
