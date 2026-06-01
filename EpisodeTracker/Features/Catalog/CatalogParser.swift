import Foundation

struct CatalogParser {
    struct CatalogDocument: Decodable {
        let collectionName: String?
        let version: Int?
        let lastUpdated: String?
        let entryCount: Int?
        let entries: [CatalogEntry]
    }

    struct NormalizedCatalogDocument {
        let collectionName: String
        let version: Int?
        let lastUpdated: String?
        let entryCount: Int
        let entries: [CatalogEntry]
    }

    func parseCatalogEntries(from data: Data, fallbackCollectionName: String) throws -> [CatalogEntry] {
        if let array = try? JSONDecoder().decode([CatalogEntry].self, from: data) {
            return array.map {
                CatalogEntry(
                    number: $0.number,
                    kind: $0.kind,
                    slug: $0.slug,
                    title: $0.title,
                    releaseYear: $0.releaseYear,
                    collectionName: $0.collectionName ?? fallbackCollectionName,
                    spotifyURL: $0.spotifyURL,
                    appleMusicURL: $0.appleMusicURL,
                    deezerURL: $0.deezerURL,
                    audibleURL: $0.audibleURL
                )
            }
        }

        let document = try JSONDecoder().decode(CatalogDocument.self, from: data)
        let collection = document.collectionName ?? fallbackCollectionName
        return document.entries.map {
            CatalogEntry(
                number: $0.number,
                kind: $0.kind,
                slug: $0.slug,
                title: $0.title,
                releaseYear: $0.releaseYear,
                collectionName: $0.collectionName ?? collection,
                spotifyURL: $0.spotifyURL,
                appleMusicURL: $0.appleMusicURL,
                deezerURL: $0.deezerURL,
                audibleURL: $0.audibleURL
            )
        }
    }

    func parseCatalogDocument(from data: Data) throws -> CatalogDocument {
        try JSONDecoder().decode(CatalogDocument.self, from: data)
    }

    func parseNormalizedCatalogDocument(from data: Data, fallbackCollectionName: String) throws -> NormalizedCatalogDocument {
        if let array = try? JSONDecoder().decode([CatalogEntry].self, from: data) {
            let entries = array.map {
                CatalogEntry(
                    number: $0.number,
                    kind: $0.kind,
                    slug: $0.slug,
                    title: $0.title,
                    releaseYear: $0.releaseYear,
                    collectionName: $0.collectionName ?? fallbackCollectionName,
                    spotifyURL: $0.spotifyURL,
                    appleMusicURL: $0.appleMusicURL,
                    deezerURL: $0.deezerURL,
                    audibleURL: $0.audibleURL
                )
            }
            return NormalizedCatalogDocument(
                collectionName: fallbackCollectionName,
                version: nil,
                lastUpdated: nil,
                entryCount: entries.count,
                entries: entries
            )
        }

        let document = try JSONDecoder().decode(CatalogDocument.self, from: data)
        let collection = document.collectionName ?? fallbackCollectionName
        let entries = document.entries.map {
            CatalogEntry(
                number: $0.number,
                kind: $0.kind,
                slug: $0.slug,
                title: $0.title,
                releaseYear: $0.releaseYear,
                collectionName: $0.collectionName ?? collection,
                spotifyURL: $0.spotifyURL,
                appleMusicURL: $0.appleMusicURL,
                deezerURL: $0.deezerURL,
                audibleURL: $0.audibleURL
            )
        }
        return NormalizedCatalogDocument(
            collectionName: collection,
            version: document.version,
            lastUpdated: document.lastUpdated,
            entryCount: document.entryCount ?? entries.count,
            entries: entries
        )
    }

    func parseManifest(from data: Data) throws -> CatalogManifest {
        try JSONDecoder().decode(CatalogManifest.self, from: data)
    }
}
