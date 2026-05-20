import Foundation

struct CatalogEntry: Codable, Equatable {
    let number: Int
    let title: String
    let releaseYear: Int
    let collectionName: String?
    let spotifyURL: String?
    let appleMusicURL: String?

    init(
        number: Int,
        title: String,
        releaseYear: Int,
        collectionName: String? = nil,
        spotifyURL: String? = nil,
        appleMusicURL: String? = nil
    ) {
        self.number = number
        self.title = title
        self.releaseYear = releaseYear
        self.collectionName = collectionName
        self.spotifyURL = spotifyURL
        self.appleMusicURL = appleMusicURL
    }

    var hasStreamingLink: Bool {
        [spotifyURL, appleMusicURL].contains { urlString in
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

    init(
        catalogID: String,
        name: String,
        version: Int?,
        lastUpdated: String?,
        entryCount: Int,
        episodeNumbers: [Int]
    ) {
        self.catalogID = catalogID
        self.name = name
        self.version = version
        self.lastUpdated = lastUpdated
        self.entryCount = entryCount
        self.episodeNumbers = Array(Set(episodeNumbers)).sorted()
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
        let addedEntries = entries
            .filter { !previousNumbers.contains($0.number) }
            .sorted { $0.number < $1.number }

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
