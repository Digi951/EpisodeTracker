import Foundation

struct CatalogCacheStore {
    private struct StoredCatalogs: Codable {
        var collections: [StoredCatalogCollection]
    }

    private struct StoredCatalogCollection: Codable {
        let name: String
        let entries: [CatalogEntry]
    }

    private let customCatalogsURL: URL
    private let manifestURL: URL
    private let remoteCatalogDirectoryURL: URL

    init(fileManager: FileManager = .default) {
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directoryURL = appSupportURL.appendingPathComponent("EpisodeTracker", isDirectory: true)
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        customCatalogsURL = directoryURL.appendingPathComponent("CustomCatalogs.json")
        manifestURL = directoryURL.appendingPathComponent("CatalogManifest.json")

        remoteCatalogDirectoryURL = directoryURL.appendingPathComponent("RemoteCatalogs", isDirectory: true)
        try? fileManager.createDirectory(at: remoteCatalogDirectoryURL, withIntermediateDirectories: true)
    }

    func loadCustomEntries() -> [CatalogEntry] {
        guard let data = try? Data(contentsOf: customCatalogsURL),
              let decoded = try? JSONDecoder().decode(StoredCatalogs.self, from: data)
        else {
            return []
        }
        return decoded.collections.flatMap(\.entries)
    }

    func replaceCustomCatalog(collectionName: String, entries: [CatalogEntry]) throws {
        var stored = (try? readStoredCatalogs()) ?? StoredCatalogs(collections: [])
        let key = collectionName.lowercased()
        stored.collections.removeAll { $0.name.lowercased() == key }
        stored.collections.append(StoredCatalogCollection(name: collectionName, entries: entries))

        let data = try JSONEncoder().encode(stored)
        try data.write(to: customCatalogsURL, options: [.atomic])
    }

    func loadManifest() -> CatalogManifest? {
        guard let data = try? Data(contentsOf: manifestURL),
              let decoded = try? JSONDecoder().decode(CatalogManifest.self, from: data)
        else {
            return nil
        }
        return decoded
    }

    func saveManifest(_ manifest: CatalogManifest) throws {
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: manifestURL, options: [.atomic])
    }

    func loadRemoteCache(universeName: String) -> [CatalogEntry]? {
        let cacheURL = remoteCacheURL(for: universeName)
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([CatalogEntry].self, from: data)
        else {
            return nil
        }
        return decoded
    }

    func saveRemoteCache(entries: [CatalogEntry], universeName: String) throws {
        let data = try JSONEncoder().encode(entries)
        try data.write(to: remoteCacheURL(for: universeName), options: [.atomic])
    }

    func loadRemoteMetadata(universeName: String) -> RemoteCatalogMetadata? {
        let metadataURL = remoteMetadataURL(for: universeName)
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode(RemoteCatalogMetadata.self, from: data)
        else {
            return nil
        }
        return decoded
    }

    func saveRemoteMetadata(_ metadata: RemoteCatalogMetadata, universeName: String) throws {
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: remoteMetadataURL(for: universeName), options: [.atomic])
    }

    func loadBundledFallbackEntries() -> [CatalogEntry] {
        guard let url = Bundle.main.url(forResource: "EpisodeCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([CatalogEntry].self, from: data)
        else {
            return []
        }

        return decoded.map {
            CatalogEntry(
                number: $0.number,
                title: $0.title,
                releaseYear: $0.releaseYear,
                collectionName: CatalogSourceRegistry.bundledCollectionName
            )
        }
    }

    private func readStoredCatalogs() throws -> StoredCatalogs {
        let data = try Data(contentsOf: customCatalogsURL)
        return try JSONDecoder().decode(StoredCatalogs.self, from: data)
    }

    private func remoteCacheURL(for universeName: String) -> URL {
        remoteCatalogDirectoryURL.appendingPathComponent("\(sanitizedFileName(for: universeName)).cache.json")
    }

    private func remoteMetadataURL(for universeName: String) -> URL {
        remoteCatalogDirectoryURL.appendingPathComponent("\(sanitizedFileName(for: universeName)).meta.json")
    }

    private func sanitizedFileName(for value: String) -> String {
        let normalized = value
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        return normalized
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
