import Foundation

struct CatalogEntry: Codable {
    let number: Int
    let title: String
    let releaseYear: Int
    let collectionName: String?
}

struct CatalogManifest: Codable {
    let schemaVersion: Int
    let updatedAt: String?
    let catalogs: [ManagedCatalogSource]
}

struct ManagedCatalogSource: Codable {
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

enum CatalogSourceRegistry {
    static let bundledCollectionName = "Die drei ???"
    static let manifestURL = URL(string: "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/manifest.json")!
    static let manifestMetadataKey = "__catalog_manifest__"

    static var managedSources: [ManagedCatalogSource] {
        CatalogCacheStore().loadManifest()?.catalogs ?? fallbackManagedSources
    }

    static let fallbackManagedSources: [ManagedCatalogSource] = [
        ManagedCatalogSource(
            id: "die-drei-fragezeichen",
            name: "Die drei ???",
            url: URL(string: "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/The_three_questionmarks.json")!
        ),
        ManagedCatalogSource(
            id: "die-drei-fragezeichen-kids",
            name: "Die drei ??? Kids",
            url: URL(string: "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/The_three_questionmarks_kids.json")!
        ),
        ManagedCatalogSource(
            id: "bibi-blocksberg",
            name: "Bibi Blocksberg",
            url: URL(string: "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/Bibi_Blocksberg.json")!
        ),
        ManagedCatalogSource(
            id: "die-drei-ausrufezeichen",
            name: "Die drei !!!",
            url: URL(string: "https://raw.githubusercontent.com/Digi951/hoerspiel-kataloge/main/catalogs/The_tree_exclamationmarks.json")!
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
