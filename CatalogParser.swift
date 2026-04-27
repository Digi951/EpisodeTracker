import Foundation

struct CatalogParser {
    private struct CollectionCatalogDocument: Decodable {
        let collectionName: String?
        let entries: [CatalogEntry]
    }

    func parseCatalogEntries(from data: Data, fallbackCollectionName: String) throws -> [CatalogEntry] {
        if let array = try? JSONDecoder().decode([CatalogEntry].self, from: data) {
            return array.map {
                CatalogEntry(
                    number: $0.number,
                    title: $0.title,
                    releaseYear: $0.releaseYear,
                    collectionName: $0.collectionName ?? fallbackCollectionName
                )
            }
        }

        let document = try JSONDecoder().decode(CollectionCatalogDocument.self, from: data)
        let collection = document.collectionName ?? fallbackCollectionName
        return document.entries.map {
            CatalogEntry(
                number: $0.number,
                title: $0.title,
                releaseYear: $0.releaseYear,
                collectionName: $0.collectionName ?? collection
            )
        }
    }

    func parseManifest(from data: Data) throws -> CatalogManifest {
        try JSONDecoder().decode(CatalogManifest.self, from: data)
    }
}
