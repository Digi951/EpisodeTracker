import Foundation

enum RemoteCatalogFetchResult {
    case updated(data: Data, eTag: String?, lastModified: String?)
    case notModified
    case failed(CatalogFetchError)
}

/// Ein fehlgeschlagener Abruf bekommt einen eigenen Fall, statt wie bisher als
/// `.skipped` mit `.notModified` zusammenzufallen: der Aufrufer muss einen
/// 404/500/Timeout von einem echten „nichts geändert" unterscheiden können, um
/// den 6-h-Cooldown nicht nach einem Fehlschlag zu starten (siehe
/// docs/plans/v1.18-paket-2+2b-plan.md, Commit B).
enum CatalogFetchError: Error, Equatable, Sendable {
    /// HTTP-Antwort mit einem anderen Status als 200/304 (z. B. 404, 429, 500).
    case http(status: Int)
    /// Transportfehler vor einer HTTP-Antwort; `code` ist `URLError.Code.rawValue`
    /// (Timeout, offline, DNS …).
    case transport(code: Int)
    /// Antwort war keine `HTTPURLResponse`.
    case notHTTP
    /// Nutzlast kam an, ließ sich aber nicht parsen. Wird vom Aufrufer gesetzt,
    /// nicht vom Data-Source — der parst nicht.
    case decoding(String)
}

protocol CatalogFetching: Sendable {
    func fetch(from url: URL, metadata: RemoteCatalogMetadata?) async -> RemoteCatalogFetchResult
    func fetch(from source: ManagedCatalogSource, metadata: RemoteCatalogMetadata?) async -> RemoteCatalogFetchResult
}

struct CatalogRemoteDataSource: CatalogFetching {
    nonisolated init() {}

    func fetch(
        from url: URL,
        metadata: RemoteCatalogMetadata?
    ) async -> RemoteCatalogFetchResult {
        var request = URLRequest(url: url)
        return await fetch(request: &request, metadata: metadata)
    }

    func fetch(
        from source: ManagedCatalogSource,
        metadata: RemoteCatalogMetadata?
    ) async -> RemoteCatalogFetchResult {
        var request = URLRequest(url: source.url)
        return await fetch(request: &request, metadata: metadata)
    }

    private func fetch(
        request: inout URLRequest,
        metadata: RemoteCatalogMetadata?
    ) async -> RemoteCatalogFetchResult {
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData

        if let eTag = metadata?.eTag {
            request.setValue(eTag, forHTTPHeaderField: "If-None-Match")
        }
        if let lastModified = metadata?.lastModified {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            return .failed(.transport(code: urlError.code.rawValue))
        } catch {
            // z. B. CancellationError bei abgebrochenem Task — kein URLError, aber
            // ebenso ein Transportabbruch vor einer HTTP-Antwort.
            return .failed(.transport(code: URLError.Code.unknown.rawValue))
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return .failed(.notHTTP)
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
            return .failed(.http(status: httpResponse.statusCode))
        }
    }
}
