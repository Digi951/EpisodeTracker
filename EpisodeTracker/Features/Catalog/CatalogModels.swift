import Foundation

struct CatalogEntry: Codable, Equatable {
    let number: Int?
    let kind: EpisodeKind
    let slug: String?
    let title: String
    let releaseYear: Int
    let collectionName: String?
    /// Streaming-Links, keyed by `StreamingService.rawValue`. Ersetzt die früheren
    /// vier festen URL-Felder: ein neuer Dienst braucht nur Katalogdaten, keine
    /// Änderung an Parser, Cache-Store oder Katalog-Pipeline.
    let links: [String: String]
    /// V2-Provenienzfelder (Datenvertrag §5.3). Alle optional bzw. mit
    /// `unknown`-Default → Legacy- und 1.17-Kataloge dekodieren unverändert,
    /// die Felder sind dann schlicht `nil` / `.unknown`. Noch keine UI
    /// (Paket 3/4); hier nur dekodiert und im Cache-Roundtrip erhalten.
    let releaseDate: Date?
    let releaseStatus: CatalogReleaseStatus
    let sourceCheckedAt: Date?
    let changedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case number
        case kind
        case slug
        case title
        case releaseYear
        case collectionName
        case links
        case releaseDate
        case releaseStatus
        case sourceCheckedAt
        case changedAt
        // Legacy-Felder: werden weiterhin gelesen, aber nicht mehr geschrieben.
        case spotifyURL
        case appleMusicURL
        case deezerURL
        case audibleURL
    }

    init(
        number: Int?,
        kind: EpisodeKind = .regular,
        slug: String? = nil,
        title: String,
        releaseYear: Int,
        collectionName: String? = nil,
        links: [String: String],
        releaseDate: Date? = nil,
        releaseStatus: CatalogReleaseStatus = .unknown,
        sourceCheckedAt: Date? = nil,
        changedAt: Date? = nil
    ) {
        self.number = number
        self.kind = kind
        self.slug = slug
        self.title = title
        self.releaseYear = releaseYear
        self.collectionName = collectionName
        self.links = Self.sanitized(links)
        self.releaseDate = releaseDate
        self.releaseStatus = releaseStatus
        self.sourceCheckedAt = sourceCheckedAt
        self.changedAt = changedAt
    }

    /// Convenience-Init mit den historischen benannten Feldern. Bleibt erhalten,
    /// damit bestehende Aufrufstellen und Tests unverändert kompilieren.
    init(
        number: Int?,
        kind: EpisodeKind = .regular,
        slug: String? = nil,
        title: String,
        releaseYear: Int,
        collectionName: String? = nil,
        spotifyURL: String? = nil,
        appleMusicURL: String? = nil,
        deezerURL: String? = nil,
        audibleURL: String? = nil,
        releaseDate: Date? = nil,
        releaseStatus: CatalogReleaseStatus = .unknown,
        sourceCheckedAt: Date? = nil,
        changedAt: Date? = nil
    ) {
        self.init(
            number: number,
            kind: kind,
            slug: slug,
            title: title,
            releaseYear: releaseYear,
            collectionName: collectionName,
            links: Self.linksFromLegacyFields(
                spotifyURL: spotifyURL,
                appleMusicURL: appleMusicURL,
                deezerURL: deezerURL,
                audibleURL: audibleURL
            ),
            releaseDate: releaseDate,
            releaseStatus: releaseStatus,
            sourceCheckedAt: sourceCheckedAt,
            changedAt: changedAt
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.decodeIfPresent(Int.self, forKey: .number)
        kind = try container.decodeIfPresent(EpisodeKind.self, forKey: .kind) ?? .regular
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        title = try container.decode(String.self, forKey: .title)
        // Manche Katalogquellen liefern kein releaseYear; 0 ist die etablierte
        // "unbekannt"-Konvention (siehe Episode.releaseYear, SmartListDetailView).
        releaseYear = try container.decodeIfPresent(Int.self, forKey: .releaseYear) ?? 0
        collectionName = try container.decodeIfPresent(String.self, forKey: .collectionName)

        var resolved = try container.decodeIfPresent([String: String].self, forKey: .links) ?? [:]

        let legacy = Self.linksFromLegacyFields(
            spotifyURL: try container.decodeIfPresent(String.self, forKey: .spotifyURL),
            appleMusicURL: try container.decodeIfPresent(String.self, forKey: .appleMusicURL),
            deezerURL: try container.decodeIfPresent(String.self, forKey: .deezerURL),
            audibleURL: try container.decodeIfPresent(String.self, forKey: .audibleURL)
        )
        // Explizite links-Einträge gewinnen gegen Legacy-Felder.
        for (key, value) in legacy where resolved[key] == nil {
            resolved[key] = value
        }

        links = Self.sanitized(resolved)

        // V2-Provenienzfelder. Fehlender Key / JSON-null → nil bzw. .unknown
        // (Legacy bleibt unverändert). Ein vorhandener, aber falsch getypter
        // Wert (z. B. Zahl statt yyyy-MM-dd-String) wirft weiter — Fail-Fast,
        // damit ein kaputtes Remote-JSON den Payload verwirft statt still ein
        // Feld zu verschlucken (siehe Playbook „decodeIfPresent statt try?").
        releaseDate = try Self.decodeCalendarDay(from: container, forKey: .releaseDate)
        sourceCheckedAt = try Self.decodeCalendarDay(from: container, forKey: .sourceCheckedAt)
        changedAt = try Self.decodeCalendarDay(from: container, forKey: .changedAt)
        releaseStatus = CatalogReleaseStatus.resolve(
            try container.decodeIfPresent(String.self, forKey: .releaseStatus)
        )
    }

    private static func decodeCalendarDay(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> Date? {
        guard let raw = try container.decodeIfPresent(String.self, forKey: key) else { return nil }
        guard let date = CalendarDayFormatter.date(from: raw) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Erwartet wurde yyyy-MM-dd, gelesen wurde \"\(raw)\""
            )
        }
        return date
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(number, forKey: .number)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(slug, forKey: .slug)
        try container.encode(title, forKey: .title)
        try container.encode(releaseYear, forKey: .releaseYear)
        try container.encodeIfPresent(collectionName, forKey: .collectionName)
        try container.encode(links, forKey: .links)
        // Nur schreiben, wenn belegt: ein Legacy-Eintrag ohne Provenienzfelder
        // wird byte-gleich wie vor Paket 1 serialisiert, der Disk-Cache ändert
        // sich für Bestandsdaten nicht.
        try container.encodeIfPresent(
            releaseDate.map(CalendarDayFormatter.string(from:)),
            forKey: .releaseDate
        )
        if releaseStatus != .unknown {
            try container.encode(releaseStatus, forKey: .releaseStatus)
        }
        try container.encodeIfPresent(
            sourceCheckedAt.map(CalendarDayFormatter.string(from:)),
            forKey: .sourceCheckedAt
        )
        try container.encodeIfPresent(
            changedAt.map(CalendarDayFormatter.string(from:)),
            forKey: .changedAt
        )
    }

    private static func linksFromLegacyFields(
        spotifyURL: String?,
        appleMusicURL: String?,
        deezerURL: String?,
        audibleURL: String?
    ) -> [String: String] {
        var result: [String: String] = [:]
        result[StreamingService.spotify.rawValue] = spotifyURL
        result[StreamingService.apple.rawValue] = appleMusicURL
        result[StreamingService.deezer.rawValue] = deezerURL
        result[StreamingService.audible.rawValue] = audibleURL
        return result
    }

    private static func sanitized(_ links: [String: String]) -> [String: String] {
        links.reduce(into: [String: String]()) { result, pair in
            let value = pair.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return }
            result[pair.key] = value
        }
    }

    var hasStreamingLink: Bool {
        !links.isEmpty
    }
}

extension CatalogEntry {
    /// Reservierter Link-Key für eine generische Quell-URL (Sender-Mediathek,
    /// Studio-Seite …). Kein `StreamingService`-Case — `StreamingService(rawValue:
    /// "source")` bleibt `nil`, die Quelle wird also nie als Dienst-Zeile
    /// gerendert, sondern nur als „Originalquelle öffnen"-Fallback.
    static let sourceLinkKey = "source"

    var sourceURL: URL? {
        guard let raw = links[Self.sourceLinkKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else { return nil }
        return URL(string: raw)
    }

    /// Erster verfügbarer Link entlang der übergebenen Dienst-Priorität.
    /// Ersetzt dienstspezifische Fallbacks wie `spotifyURL ?? appleMusicURL`.
    func preferredLink(for services: [StreamingService]) -> String? {
        for service in services {
            if let link = links[service.rawValue] { return link }
        }
        return nil
    }

    /// Kopie mit ersetztem `collectionName`, alle übrigen Felder unverändert.
    /// Der Parser normalisiert nur den Sammlungsnamen — dieser Helfer stellt
    /// sicher, dass dabei kein anderes Feld (inkl. der V2-Provenienzfelder)
    /// still verloren geht.
    func withCollectionName(_ newValue: String?) -> CatalogEntry {
        CatalogEntry(
            number: number,
            kind: kind,
            slug: slug,
            title: title,
            releaseYear: releaseYear,
            collectionName: newValue,
            links: links,
            releaseDate: releaseDate,
            releaseStatus: releaseStatus,
            sourceCheckedAt: sourceCheckedAt,
            changedAt: changedAt
        )
    }

    /// Kopie als `special` mit erzwungenem Slug, alle übrigen Felder (inkl. der
    /// V2-Provenienzfelder) unverändert. Für `CatalogStyleNormalizer`, damit die
    /// Anthologie-Invariante keine `releaseDate`/`releaseStatus`/`sourceCheckedAt`/
    /// `changedAt` still fallenlässt.
    func asSpecial(slug: String) -> CatalogEntry {
        CatalogEntry(
            number: number,
            kind: .special,
            slug: slug,
            title: title,
            releaseYear: releaseYear,
            collectionName: collectionName,
            links: links,
            releaseDate: releaseDate,
            releaseStatus: releaseStatus,
            sourceCheckedAt: sourceCheckedAt,
            changedAt: changedAt
        )
    }
}

struct CatalogManifest: Codable {
    let schemaVersion: Int
    let updatedAt: String?
    let catalogs: [ManagedCatalogSource]
}

struct ManagedCatalogSource: Codable, Equatable {
    let id: String
    let name: String
    let language: String?
    let style: String?
    let url: URL

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case language
        case style
        case url
    }

    init(id: String, name: String, language: String? = "de", style: String? = nil, url: URL) {
        self.id = id
        self.name = name
        self.language = language
        self.style = style
        self.url = url.normalizedGitHubRawURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        style = try container.decodeIfPresent(String.self, forKey: .style)
        url = try container.decode(URL.self, forKey: .url).normalizedGitHubRawURL
    }
}

extension ManagedCatalogSource {
    var effectiveLanguage: String {
        (language ?? "de").lowercased()
    }

    static var deviceLanguage: String {
        Locale.current.language.languageCode?.identifier ?? "de"
    }

    var matchesDeviceLanguage: Bool {
        effectiveLanguage == Self.deviceLanguage
    }

    var effectiveStyle: CatalogStyle {
        CatalogStyle.resolve(style)
    }
}

struct RemoteCatalogMetadata: Codable {
    var eTag: String?
    var lastModified: String?
    /// Zeitpunkt des letzten *erfolgreichen* Abrufs (HTTP 200 oder 304). Steuert
    /// den 6-h-Cooldown in `EpisodeCatalog.shouldRefresh`. Wird bei einem
    /// Fehlschlag bewusst nicht geschrieben, damit ein 404/500/Timeout den
    /// Refresh nicht für sechs Stunden einfriert.
    var lastCheckedAt: Date?
    /// Zeitpunkt des letzten Abrufversuchs, unabhängig vom Ausgang. Optional →
    /// Bestandsdateien ohne den Schlüssel lesen weiter (fehlender Key → nil).
    var lastAttemptAt: Date?
    /// Kennung des letzten Fehlschlags (`CatalogFetchError.kindLabel`), z. B.
    /// `"http:404"`. `nil` nach einem erfolgreichen Abruf.
    var lastFailureKind: String?
    /// Format der zuletzt geschriebenen Cache-Einträge
    /// (`CatalogSourceRegistry.currentCacheFormatVersion`). Ein niedrigerer Wert
    /// (oder `nil` bei Altbestand) löst genau einen unbedingten Voll-Refresh aus;
    /// danach wird der ETag wieder respektiert, auch wenn nicht jeder Marktdienst
    /// einen Link hat.
    var cacheFormatVersion: Int?
}

struct CatalogCacheStatus {
    let cachedEntryCount: Int?
    let lastCheckedAt: Date?

    var hasCache: Bool {
        cachedEntryCount != nil
    }
}

struct CatalogSnapshot: Codable, Equatable {
    let catalogID: String
    let name: String
    let version: Int?
    let lastUpdated: String?
    let entryCount: Int
    let episodeNumbers: [Int]
    let specialSlugs: [String]

    init(
        catalogID: String,
        name: String,
        version: Int?,
        lastUpdated: String?,
        entryCount: Int,
        episodeNumbers: [Int],
        specialSlugs: [String] = []
    ) {
        self.catalogID = catalogID
        self.name = name
        self.version = version
        self.lastUpdated = lastUpdated
        self.entryCount = entryCount
        self.episodeNumbers = Array(Set(episodeNumbers)).sorted()
        self.specialSlugs = Array(Set(specialSlugs)).sorted()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        catalogID = try container.decode(String.self, forKey: .catalogID)
        name = try container.decode(String.self, forKey: .name)
        version = try container.decodeIfPresent(Int.self, forKey: .version)
        lastUpdated = try container.decodeIfPresent(String.self, forKey: .lastUpdated)
        entryCount = try container.decode(Int.self, forKey: .entryCount)
        episodeNumbers = Array(Set(try container.decode([Int].self, forKey: .episodeNumbers))).sorted()
        let decodedSlugs = try container.decodeIfPresent([String].self, forKey: .specialSlugs) ?? []
        specialSlugs = Array(Set(decodedSlugs)).sorted()
    }
}

struct CatalogEpisodeDelta: Codable, Equatable {
    let catalogID: String
    let name: String
    let previousVersion: Int?
    let currentVersion: Int?
    let previousEntryCount: Int
    let currentEntryCount: Int
    let addedEntries: [CatalogEntry]

    var addedCount: Int {
        addedEntries.count
    }

    var firstAddedTitle: String? {
        addedEntries.first?.title
    }

    static func make(
        previous: CatalogSnapshot?,
        current: CatalogSnapshot,
        entries: [CatalogEntry]
    ) -> CatalogEpisodeDelta? {
        guard let previous else { return nil }

        let previousNumbers = Set(previous.episodeNumbers)
        let previousSlugs = Set(previous.specialSlugs)
        let addedEntries = entries
            .filter { entry in
                switch entry.kind {
                case .regular:
                    return entry.number.map { !previousNumbers.contains($0) } ?? false
                case .special:
                    return entry.slug.map { !previousSlugs.contains($0) } ?? false
                }
            }
            .sorted { lhs, rhs in
                switch (lhs.kind, rhs.kind) {
                case (.regular, .special):
                    return true
                case (.special, .regular):
                    return false
                case (.regular, .regular):
                    return (lhs.number ?? 0) < (rhs.number ?? 0)
                case (.special, .special):
                    return lhs.title.localizedCompare(rhs.title) == .orderedAscending
                }
            }

        guard !addedEntries.isEmpty else { return nil }

        return CatalogEpisodeDelta(
            catalogID: current.catalogID,
            name: current.name,
            previousVersion: previous.version,
            currentVersion: current.version,
            previousEntryCount: previous.entryCount,
            currentEntryCount: current.entryCount,
            addedEntries: addedEntries
        )
    }
}

struct NewCatalogAvailability: Codable, Equatable {
    let sources: [ManagedCatalogSource]

    var count: Int {
        sources.count
    }

    var firstName: String? {
        sources.first?.name
    }
}

enum CatalogSourceRegistry {
    static let bundledCollectionName = "Die drei ???"
    static let manifestURL = URL(string: "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/manifest.json")!
    static let manifestMetadataKey = "__catalog_manifest__"
    static let upcomingReleasesURL = URL(string: "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/upcoming_releases.json")!
    static let upcomingReleasesMetadataKey = "__upcoming_releases__"

    /// Format der gecachten Katalog-Einträge. 1 = `links`-Dictionary über alle
    /// Marktdienste (ersetzt die vier festen URL-Felder). Erhöhen, wenn sich die
    /// Struktur eines Cache-Eintrags ändert und ein einmaliger Voll-Refresh nötig
    /// wird; `RemoteCatalogMetadata.cacheFormatVersion` steuert das pro Quelle.
    static let currentCacheFormatVersion = 1

    // Wird aus View-Bodies, Bootstrap und Stores sehr häufig gelesen; ohne Cache
    // bedeutet jeder Zugriff einen Manifest-Read von der Platte plus JSON-Decode.
    // Einziger Schreibpfad ist `CatalogCacheStore.saveManifest`, das invalidiert.
    private static let managedSourcesLock = NSLock()
    private static var cachedAllKnownSources: [ManagedCatalogSource]?
    private static var cachedVisibleSources: [ManagedCatalogSource]?

    /// Every catalog source the app knows about — from a successfully validated
    /// manifest, or the bundled fallback — with **no** language filter. This is
    /// the "full registry": `ActiveCatalogStore` keys orphan-pruning and the
    /// removed-catalog check off this list, so a source that is only hidden by
    /// the catalog-language filter is never mistaken for a removed catalog.
    static var allKnownSources: [ManagedCatalogSource] {
        managedSourcesLock.lock()
        defer { managedSourcesLock.unlock() }
        return allKnownSourcesLocked()
    }

    /// The sources shown in "Reihen auswählen": `allKnownSources` narrowed to the
    /// active catalog languages. Until P3-D wires `CatalogLanguageFilterStore`
    /// this is the device language, so the visible set is identical to the
    /// pre-split `managedSources`.
    static var visibleSources: [ManagedCatalogSource] {
        managedSourcesLock.lock()
        defer { managedSourcesLock.unlock() }

        if let cachedVisibleSources { return cachedVisibleSources }

        let sources = narrowed(
            allKnownSourcesLocked(),
            toLanguages: [ManagedCatalogSource.deviceLanguage]
        )
        cachedVisibleSources = sources
        return sources
    }

    /// Deprecated alias for `visibleSources` — the sources visible in the UI.
    /// Retained so existing call sites stay correct while later Paket-3 commits
    /// migrate them deliberately. New code that means "every known source" must
    /// call `allKnownSources`.
    static var managedSources: [ManagedCatalogSource] { visibleSources }

    private static func allKnownSourcesLocked() -> [ManagedCatalogSource] {
        if let cachedAllKnownSources { return cachedAllKnownSources }

        let sources = deduplicatedManagedSources(
            CatalogCacheStore().loadManifest()?.catalogs ?? fallbackManagedSources
        )
        cachedAllKnownSources = sources
        return sources
    }

    /// Pure language projection — the core of `visibleSources`, covered directly
    /// by tests. Keeps only sources whose `effectiveLanguage` is in `languages`.
    static func narrowed(
        _ sources: [ManagedCatalogSource],
        toLanguages languages: Set<String>
    ) -> [ManagedCatalogSource] {
        sources.filter { languages.contains($0.effectiveLanguage) }
    }

    static func invalidateManagedSourcesCache() {
        managedSourcesLock.lock()
        defer { managedSourcesLock.unlock() }
        cachedAllKnownSources = nil
        cachedVisibleSources = nil
    }

    static func managedSource(named universeName: String) -> ManagedCatalogSource? {
        visibleSources.first {
            $0.name.caseInsensitiveCompare(universeName) == .orderedSame
        }
    }

    static func deduplicatedManagedSources(_ sources: [ManagedCatalogSource]) -> [ManagedCatalogSource] {
        var seenIDs = Set<String>()
        var seenNames = Set<String>()
        var result: [ManagedCatalogSource] = []

        for source in sources {
            let idKey = source.id
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let nameKey = source.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            guard !idKey.isEmpty,
                  !nameKey.isEmpty,
                  seenIDs.insert(idKey).inserted,
                  seenNames.insert(nameKey).inserted
            else {
                continue
            }

            result.append(source)
        }

        return result
    }

    static let fallbackManagedSources: [ManagedCatalogSource] = [
        ManagedCatalogSource(
            id: "die-drei-fragezeichen",
            name: "Die drei ???",
            url: URL(string: "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/de/the_three_investigators.json")!
        ),
        ManagedCatalogSource(
            id: "die-drei-fragezeichen-kids",
            name: "Die drei ??? Kids",
            url: URL(string: "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/de/the_three_investigators_kids.json")!
        ),
        ManagedCatalogSource(
            id: "bibi-blocksberg",
            name: "Bibi Blocksberg",
            url: URL(string: "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/de/bibi_blocksberg.json")!
        ),
        ManagedCatalogSource(
            id: "die-drei-ausrufezeichen",
            name: "Die drei !!!",
            url: URL(string: "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/de/the_three_exclamation_marks.json")!
        ),
        ManagedCatalogSource(
            id: "tkkg",
            name: "TKKG",
            url: URL(string: "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/de/tkkg.json")!
        )
    ]
}

private extension URL {
    var normalizedGitHubRawURL: URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let host = components.host
        else {
            return self
        }

        let pathParts = components.path.split(separator: "/").map(String.init)

        if host == "github.com", pathParts.count >= 5, pathParts[2] == "blob" {
            components.host = "raw.githubusercontent.com"
            components.path = "/" + ([pathParts[0], pathParts[1], pathParts[3]] + pathParts.dropFirst(4)).joined(separator: "/")
            return components.url ?? self
        }

        if host == "raw.githubusercontent.com", pathParts.count >= 5, pathParts[2] == "blob" {
            components.path = "/" + ([pathParts[0], pathParts[1], pathParts[3]] + pathParts.dropFirst(4)).joined(separator: "/")
            return components.url ?? self
        }

        return self
    }
}
