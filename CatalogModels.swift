import Foundation

struct CatalogEntry: Codable {
    let number: Int
    let title: String
    let releaseYear: Int
    let collectionName: String?
}

struct ManagedCatalogSource {
    let name: String
    let url: URL
}

struct RemoteCatalogMetadata: Codable {
    var eTag: String?
    var lastModified: String?
    var lastCheckedAt: Date?
}

enum CatalogSourceRegistry {
    static let bundledCollectionName = "Die drei ???"

    static let managedSources: [ManagedCatalogSource] = [
        ManagedCatalogSource(
            name: "Die drei ???",
            url: URL(string: "https://raw.githubusercontent.com/Digi951/Episodes-The_three_questionmarks/main/Episodes.json")!
        ),
        ManagedCatalogSource(
            name: "Die drei ??? Kids",
            url: URL(string: "https://raw.githubusercontent.com/Digi951/Episodes-The_three_questionmarks_kids/main/Episodes.json")!
        ),
        ManagedCatalogSource(
            name: "Bibi Blocksberg",
            url: URL(string: "https://raw.githubusercontent.com/Digi951/Episodes-Bibi_Blocksberg/main/Episodes.json")!
        ),
        ManagedCatalogSource(
            name: "Die drei !!!",
            url: URL(string: "https://raw.githubusercontent.com/Digi951/Episodes-The_tree_exclamationmarks/main/Episodes.json")!
        )
    ]
}
