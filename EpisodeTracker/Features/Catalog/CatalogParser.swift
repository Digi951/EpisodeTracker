import Foundation

struct CatalogParser {
    struct CatalogDocument: Decodable {
        let collectionName: String?
        let version: Int?
        let lastUpdated: String?
        let entryCount: Int?
        /// Datenvertrag §5.2: `1` = Legacy-Flach-URLs, `2` = `links` +
        /// Provenienzfelder. Fehlt ⇒ wie `1` behandeln. Reiner Intent-Marker
        /// für Generator/Validator — der Decoder erkennt das Format ohnehin
        /// automatisch, es hängt kein Verhalten daran.
        let catalogFormat: Int?
        let entries: [CatalogEntry]
    }

    struct NormalizedCatalogDocument {
        let collectionName: String
        let version: Int?
        let lastUpdated: String?
        let entryCount: Int
        let catalogFormat: Int?
        let entries: [CatalogEntry]
    }

    func parseCatalogEntries(from data: Data, fallbackCollectionName: String) throws -> [CatalogEntry] {
        if let array = try? JSONDecoder().decode([CatalogEntry].self, from: data) {
            return array.map { $0.withCollectionName($0.collectionName ?? fallbackCollectionName) }
        }

        let document = try JSONDecoder().decode(CatalogDocument.self, from: data)
        let collection = document.collectionName ?? fallbackCollectionName
        return document.entries.map { $0.withCollectionName($0.collectionName ?? collection) }
    }

    func parseCatalogDocument(from data: Data) throws -> CatalogDocument {
        try JSONDecoder().decode(CatalogDocument.self, from: data)
    }

    func parseNormalizedCatalogDocument(from data: Data, fallbackCollectionName: String) throws -> NormalizedCatalogDocument {
        if let array = try? JSONDecoder().decode([CatalogEntry].self, from: data) {
            let entries = array.map { $0.withCollectionName($0.collectionName ?? fallbackCollectionName) }
            return NormalizedCatalogDocument(
                collectionName: fallbackCollectionName,
                version: nil,
                lastUpdated: nil,
                entryCount: entries.count,
                catalogFormat: nil,
                entries: entries
            )
        }

        let document = try JSONDecoder().decode(CatalogDocument.self, from: data)
        let collection = document.collectionName ?? fallbackCollectionName
        let entries = document.entries.map { $0.withCollectionName($0.collectionName ?? collection) }
        return NormalizedCatalogDocument(
            collectionName: collection,
            version: document.version,
            lastUpdated: document.lastUpdated,
            entryCount: document.entryCount ?? entries.count,
            catalogFormat: document.catalogFormat,
            entries: entries
        )
    }

    func parseManifest(from data: Data) throws -> CatalogManifest {
        try JSONDecoder().decode(CatalogManifest.self, from: data)
    }
}
