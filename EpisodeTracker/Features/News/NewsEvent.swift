import Foundation

/// Art eines Neuigkeiten-Ereignisses (Datenvertrag Paket 4 §4.D1).
enum NewsEventKind: String, Codable, Equatable {
    case newEpisode
    case upcoming
    case dateChanged
    case newCatalog
    /// Unbekannter Rohwert aus einer älteren/neueren App-Version — wird
    /// toleriert statt das ganze Dokument zu verwerfen (siehe `resolve`).
    case unknown

    static func resolve(_ raw: String) -> NewsEventKind {
        NewsEventKind(rawValue: raw) ?? .unknown
    }
}

/// Ein dauerhaftes Neuigkeiten-Ereignis im lokalen `NewsStore`.
///
/// Stabile Identität folgt dem `UpcomingRelease.id`-Muster: `kind` + `catalogID`
/// + (`episodeNumber` oder `slug`). Das erlaubt `NewsReconciler`, ein
/// bestehendes Ereignis wiederzuerkennen und bei einer neuen `revision` in
/// place zu aktualisieren statt eine Dublette anzulegen (Datenvertrag §4.D3).
struct NewsEvent: Codable, Equatable, Identifiable {
    let kind: NewsEventKind
    let universeName: String
    let catalogID: String
    /// Folgennummer bei `numbered`-Serien; bei Anthologie-/Sonderfolgen `nil` —
    /// dort trägt `slug` die Identität (analog `UpcomingRelease`).
    let episodeNumber: Int?
    let slug: String?
    let title: String
    /// Revisionsmarke der Quelle (z. B. Snapshot-Version, Feed-`releaseDate`
    /// als String) — ein Wechsel löst `seenAt = nil` erneut aus, ohne eine
    /// zweite Zeile für dasselbe Ereignis anzulegen.
    let revision: String
    let discoveredAt: Date
    var seenAt: Date?

    var id: String {
        "\(kind.rawValue)-\(catalogID)-\(episodeNumber.map(String.init) ?? slug ?? "?")"
    }

    private enum CodingKeys: String, CodingKey {
        case kind, universeName, catalogID, episodeNumber, slug, title, revision, discoveredAt, seenAt
    }

    init(
        kind: NewsEventKind,
        universeName: String,
        catalogID: String,
        episodeNumber: Int? = nil,
        slug: String? = nil,
        title: String,
        revision: String,
        discoveredAt: Date,
        seenAt: Date? = nil
    ) {
        self.kind = kind
        self.universeName = universeName
        self.catalogID = catalogID
        self.episodeNumber = episodeNumber
        self.slug = slug
        self.title = title
        self.revision = revision
        self.discoveredAt = discoveredAt
        self.seenAt = seenAt
    }

    // Toleranter Decode: ein unbekannter `kind`-Rohwert aus einer neueren
    // App-Version verwirft die Zeile nicht, sondern markiert sie `.unknown`
    // (die UI blendet sie dann aus, statt den ganzen Store zu verlieren).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawKind = try container.decode(String.self, forKey: .kind)
        kind = NewsEventKind.resolve(rawKind)
        universeName = try container.decode(String.self, forKey: .universeName)
        catalogID = try container.decode(String.self, forKey: .catalogID)
        episodeNumber = try container.decodeIfPresent(Int.self, forKey: .episodeNumber)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        title = try container.decode(String.self, forKey: .title)
        revision = try container.decode(String.self, forKey: .revision)
        discoveredAt = try container.decode(Date.self, forKey: .discoveredAt)
        seenAt = try container.decodeIfPresent(Date.self, forKey: .seenAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind.rawValue, forKey: .kind)
        try container.encode(universeName, forKey: .universeName)
        try container.encode(catalogID, forKey: .catalogID)
        try container.encodeIfPresent(episodeNumber, forKey: .episodeNumber)
        try container.encodeIfPresent(slug, forKey: .slug)
        try container.encode(title, forKey: .title)
        try container.encode(revision, forKey: .revision)
        try container.encode(discoveredAt, forKey: .discoveredAt)
        try container.encodeIfPresent(seenAt, forKey: .seenAt)
    }
}

/// Wurzeldokument des dauerhaften Neuigkeiten-Stores (Datenvertrag §4.D1).
///
/// `lastReconciledRevisions` überlebt das 90-Tage-Aufräumen (P4-D) bewusst
/// getrennt von `events`, damit ein bereits gesehenes, dann geprüftes Ereignis
/// ohne Revisionswechsel nicht erneut auftaucht, nachdem seine Zeile geprüft
/// wurde (Datenvertrag §4.D5).
struct NewsStoreDocument: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var hasEstablishedBaseline: Bool
    var events: [NewsEvent]
    /// Ereignis-`id` → zuletzt verarbeitete `revision`.
    var lastReconciledRevisions: [String: String]

    init(
        schemaVersion: Int = NewsStoreDocument.currentSchemaVersion,
        hasEstablishedBaseline: Bool = false,
        events: [NewsEvent] = [],
        lastReconciledRevisions: [String: String] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.hasEstablishedBaseline = hasEstablishedBaseline
        self.events = events
        self.lastReconciledRevisions = lastReconciledRevisions
    }

    /// Markiert genau ein Ereignis als gesehen, falls es noch ungesehen ist —
    /// sonst ein No-op. Rein, ohne Seiteneffekt: der Aufrufer entscheidet, ob
    /// und wann gespeichert wird. Gedacht für zeilenweises Markieren beim
    /// tatsächlichen Rendern einer Zeile (Review-Fund #2) statt eines
    /// pauschalen "alles im Store gilt als gesehen" beim Öffnen des Screens.
    func markingSeen(eventID: String, now: Date = Date()) -> NewsStoreDocument {
        var result = self
        guard let index = result.events.firstIndex(where: { $0.id == eventID }),
              result.events[index].seenAt == nil
        else {
            return self
        }
        result.events[index].seenAt = now
        return result
    }
}
