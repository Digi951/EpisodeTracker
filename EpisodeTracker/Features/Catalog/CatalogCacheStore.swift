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
    private let catalogEpisodeDeltasURL: URL
    private let newCatalogAvailabilityURL: URL
    private let remoteCatalogDirectoryURL: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory unavailable")
        }
        let directoryURL = appSupportURL.appendingPathComponent("EpisodeTracker", isDirectory: true)
        self.init(directoryURL: directoryURL, fileManager: fileManager)
    }

    init(directoryURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        customCatalogsURL = directoryURL.appendingPathComponent("CustomCatalogs.json")
        manifestURL = directoryURL.appendingPathComponent("CatalogManifest.json")
        catalogEpisodeDeltasURL = directoryURL.appendingPathComponent("CatalogEpisodeDeltas.json")
        newCatalogAvailabilityURL = directoryURL.appendingPathComponent("NewCatalogAvailability.json")

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

    func loadRemoteCache(universeName: String, cacheKey: String? = nil) -> [CatalogEntry]? {
        let cacheURL = remoteCacheURL(for: cacheStorageKey(universeName: universeName, cacheKey: cacheKey))
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([CatalogEntry].self, from: data)
        else {
            return nil
        }
        return decoded
    }

    func saveRemoteCache(entries: [CatalogEntry], universeName: String, cacheKey: String? = nil) throws {
        let data = try JSONEncoder().encode(entries)
        try data.write(to: remoteCacheURL(for: cacheStorageKey(universeName: universeName, cacheKey: cacheKey)), options: [.atomic])
    }

    func loadCatalogSnapshot(universeName: String, cacheKey: String? = nil) -> CatalogSnapshot? {
        let snapshotURL = remoteSnapshotURL(for: cacheStorageKey(universeName: universeName, cacheKey: cacheKey))
        guard let data = try? Data(contentsOf: snapshotURL),
              let decoded = try? JSONDecoder().decode(CatalogSnapshot.self, from: data)
        else {
            return nil
        }
        return decoded
    }

    func saveCatalogSnapshot(_ snapshot: CatalogSnapshot, universeName: String, cacheKey: String? = nil) throws {
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: remoteSnapshotURL(for: cacheStorageKey(universeName: universeName, cacheKey: cacheKey)), options: [.atomic])
    }

    func loadCatalogEpisodeDeltas() -> [CatalogEpisodeDelta] {
        guard let data = try? Data(contentsOf: catalogEpisodeDeltasURL),
              let decoded = try? JSONDecoder().decode([CatalogEpisodeDelta].self, from: data)
        else {
            return []
        }
        return decoded
    }

    func saveCatalogEpisodeDelta(_ delta: CatalogEpisodeDelta) throws {
        var deltas = loadCatalogEpisodeDeltas()
        deltas.removeAll { $0.catalogID == delta.catalogID }
        deltas.append(delta)
        try saveCatalogEpisodeDeltas(deltas)
    }

    func clearCatalogEpisodeDelta(catalogID: String) throws {
        var deltas = loadCatalogEpisodeDeltas()
        deltas.removeAll { $0.catalogID == catalogID }
        try saveCatalogEpisodeDeltas(deltas)
    }

    func loadNewCatalogAvailability() -> NewCatalogAvailability? {
        guard let data = try? Data(contentsOf: newCatalogAvailabilityURL),
              let decoded = try? JSONDecoder().decode(NewCatalogAvailability.self, from: data)
        else {
            return nil
        }
        return decoded.sources.isEmpty ? nil : decoded
    }

    func saveNewCatalogAvailability(_ availability: NewCatalogAvailability) throws {
        let data = try JSONEncoder().encode(availability)
        try data.write(to: newCatalogAvailabilityURL, options: [.atomic])
    }

    func clearNewCatalogAvailability() throws {
        try? fileManager.removeItem(at: newCatalogAvailabilityURL)
    }

    func loadRemoteMetadata(universeName: String, cacheKey: String? = nil) -> RemoteCatalogMetadata? {
        let metadataURL = remoteMetadataURL(for: cacheStorageKey(universeName: universeName, cacheKey: cacheKey))
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode(RemoteCatalogMetadata.self, from: data)
        else {
            return nil
        }
        return decoded
    }

    func saveRemoteMetadata(_ metadata: RemoteCatalogMetadata, universeName: String, cacheKey: String? = nil) throws {
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: remoteMetadataURL(for: cacheStorageKey(universeName: universeName, cacheKey: cacheKey)), options: [.atomic])
    }

    func loadRemoteCatalogStatus(universeName: String, cacheKey: String? = nil) -> CatalogCacheStatus {
        CatalogCacheStatus(
            cachedEntryCount: loadRemoteCache(universeName: universeName, cacheKey: cacheKey)?.count,
            lastCheckedAt: loadRemoteMetadata(universeName: universeName, cacheKey: cacheKey)?.lastCheckedAt
        )
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

    private func remoteSnapshotURL(for universeName: String) -> URL {
        remoteCatalogDirectoryURL.appendingPathComponent("\(sanitizedFileName(for: universeName)).snapshot.json")
    }

    private func saveCatalogEpisodeDeltas(_ deltas: [CatalogEpisodeDelta]) throws {
        let data = try JSONEncoder().encode(deltas)
        try data.write(to: catalogEpisodeDeltasURL, options: [.atomic])
    }

    private func cacheStorageKey(universeName: String, cacheKey: String?) -> String {
        let trimmedKey = cacheKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedKey.isEmpty ? universeName : trimmedKey
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
