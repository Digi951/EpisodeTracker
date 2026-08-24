import Foundation

struct UpcomingRelease: Codable, Equatable, Identifiable {
    let catalogID: String
    let number: Int
    let title: String
    let releaseDate: Date

    var id: String { "\(catalogID)-\(number)" }
}

struct UpcomingReleasesDocument: Codable {
    let updatedAt: String?
    let releases: [UpcomingRelease]

    /// releaseDate kommt als reines Datum ("yyyy-MM-dd") ohne Uhrzeit/Zeitzone vom
    /// wöchentlichen Katalog-Check - ein eigener Decoder statt der globalen
    /// Decoding-Strategie, damit andere Katalog-Typen (CatalogEntry etc.) unberührt bleiben.
    static var decoder: JSONDecoder {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
        return decoder
    }
}
