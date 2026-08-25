import Foundation

struct UpcomingRelease: Codable, Equatable, Identifiable {
    let catalogID: String
    let number: Int
    let title: String
    let releaseDate: Date

    var id: String { "\(catalogID)-\(number)" }

    private enum CodingKeys: String, CodingKey {
        case catalogID, number, title, releaseDate
    }

    init(catalogID: String, number: Int, title: String, releaseDate: Date) {
        self.catalogID = catalogID
        self.number = number
        self.title = title
        self.releaseDate = releaseDate
    }

    /// Das Datum kommt als reiner Kalendertag ("2026-09-18") ohne Uhrzeit. Es wird
    /// auf lokale Mitternacht verankert, nicht auf UTC: sonst zeigt eine Zeitzone
    /// westlich von UTC den Vortag an und blendet die Folge am Erscheinungstag aus.
    /// Cache und Remote-JSON nutzen dasselbe Format, damit beide Wege denselben
    /// Wert ergeben.
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(catalogID, forKey: .catalogID)
        try container.encode(number, forKey: .number)
        try container.encode(title, forKey: .title)
        try container.encode(Self.dayFormatter().string(from: releaseDate), forKey: .releaseDate)
    }
}

struct UpcomingReleasesDocument: Decodable {
    let updatedAt: String?
    let releases: [UpcomingRelease]

    private enum CodingKeys: String, CodingKey {
        case updatedAt, releases
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
        releases = try container.decode([LenientRelease].self, forKey: .releases).compactMap(\.release)
    }
}
