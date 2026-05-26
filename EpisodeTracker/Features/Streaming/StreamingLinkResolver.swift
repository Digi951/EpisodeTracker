import Foundation

struct StreamingLinkResolver {
    let service: StreamingService
    let catalog: EpisodeCatalog

    func resolve(for episode: Episode) -> (url: URL, label: String)? {
        if let directURL = service.directURL(from: episode.streamingURL) {
            let label = "In \(service.displayName(for: episode.streamingURL)) öffnen"
            return (directURL, label)
        }

        let catalogEntry = catalog.entry(
            for: episode.episodeNumber,
            in: episode.universe?.name
        )

        if let entry = catalogEntry, let catalogURL = service.catalogURL(from: entry) {
            let label = "In \(service.displayName(for: catalogURL.absoluteString)) öffnen"
            return (catalogURL, label)
        }

        return nil
    }
}
