import Foundation

enum RemoteCatalogFetchResult {
    case updated(data: Data, eTag: String?, lastModified: String?)
    case notModified
    case skipped
}

struct CatalogRemoteDataSource {
    func fetch(
        from source: ManagedCatalogSource,
        metadata: RemoteCatalogMetadata?
    ) async throws -> RemoteCatalogFetchResult {
        var request = URLRequest(url: source.url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData

        if let eTag = metadata?.eTag {
            request.setValue(eTag, forHTTPHeaderField: "If-None-Match")
        }
        if let lastModified = metadata?.lastModified {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return .skipped
        }

        switch httpResponse.statusCode {
        case 200:
            return .updated(
                data: data,
                eTag: httpResponse.value(forHTTPHeaderField: "ETag"),
                lastModified: httpResponse.value(forHTTPHeaderField: "Last-Modified")
            )
        case 304:
            return .notModified
        default:
            return .skipped
        }
    }
}
