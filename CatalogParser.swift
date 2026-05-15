import Foundation

struct CatalogParser {
    struct CatalogDocument: Decodable {
        let collectionName: String?
        let version: Int?
        let lastUpdated: String?
        let entryCount: Int?
        let entries: [CatalogEntry]
    }

    func parseCatalogEntries(from data: Data, fallbackCollectionName: String) throws -> [CatalogEntry] {
        if let array = try? JSONDecoder().decode([CatalogEntry].self, from: data) {
            return array.map {
                CatalogEntry(
                    number: $0.number,
                    title: $0.title,
                    releaseYear: $0.releaseYear,
                    collectionName: $0.collectionName ?? fallbackCollectionName,
                    spotifyURL: $0.spotifyURL,
                    appleMusicURL: $0.appleMusicURL
                )
            }
        }

        let document = try JSONDecoder().decode(CatalogDocument.self, from: data)
        let collection = document.collectionName ?? fallbackCollectionName
        return document.entries.map {
            CatalogEntry(
                number: $0.number,
                title: $0.title,
                releaseYear: $0.releaseYear,
                collectionName: $0.collectionName ?? collection,
                spotifyURL: $0.spotifyURL,
                appleMusicURL: $0.appleMusicURL
            )
        }
    }

    func parseCatalogDocument(from data: Data) throws -> CatalogDocument {
        try JSONDecoder().decode(CatalogDocument.self, from: data)
    }

    func parseManifest(from data: Data) throws -> CatalogManifest {
        try JSONDecoder().decode(CatalogManifest.self, from: data)
    }
}
