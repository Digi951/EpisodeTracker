import Foundation

struct CatalogEntry: Codable, Equatable {
    let number: Int?
    let kind: EpisodeKind
    let slug: String?
    let title: String
    let releaseYear: Int
    let collectionName: String?
    let spotifyURL: String?
    let appleMusicURL: String?
    let deezerURL: String?
    let audibleURL: String?

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
        audibleURL: String? = nil
    ) {
        self.number = number
        self.kind = kind
        self.slug = slug
        self.title = title
        self.releaseYear = releaseYear
        self.collectionName = collectionName
        self.spotifyURL = spotifyURL
        self.appleMusicURL = appleMusicURL
        self.deezerURL = deezerURL
        self.audibleURL = audibleURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.decodeIfPresent(Int.self, forKey: .number)
        kind = try container.decodeIfPresent(EpisodeKind.self, forKey: .kind) ?? .regular
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
        title = try container.decode(String.self, forKey: .title)
        releaseYear = try container.decode(Int.self, forKey: .releaseYear)
        collectionName = try container.decodeIfPresent(String.self, forKey: .collectionName)
        spotifyURL = try container.decodeIfPresent(String.self, forKey: .spotifyURL)
        appleMusicURL = try container.decodeIfPresent(String.self, forKey: .appleMusicURL)
        deezerURL = try container.decodeIfPresent(String.self, forKey: .deezerURL)
        audibleURL = try container.decodeIfPresent(String.self, forKey: .audibleURL)
    }

    var hasStreamingLink: Bool {
        [spotifyURL, appleMusicURL, deezerURL, audibleURL].contains { urlString in
            urlString?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
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
    let url: URL

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case language
        case url
    }

    init(id: String, name: String, language: String? = "de", url: URL) {
        self.id = id
        self.name = name
        self.language = language
        self.url = url.normalizedGitHubRawURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        language = try container.decodeIfPresent(String.self, forKey: .language)
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
}

struct RemoteCatalogMetadata: Codable {
    var eTag: String?
    var lastModified: String?
    var lastCheckedAt: Date?
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

    static var managedSources: [ManagedCatalogSource] {
        deduplicatedManagedSources(CatalogCacheStore().loadManifest()?.catalogs ?? fallbackManagedSources)
            .filter(\.matchesDeviceLanguage)
    }

    static func managedSource(named universeName: String) -> ManagedCatalogSource? {
        managedSources.first {
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
