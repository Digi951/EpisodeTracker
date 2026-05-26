import Foundation

struct StreamingLinkResolver {
    let service: StreamingService
    let catalog: EpisodeCatalog

    func resolve(for episode: Episode) -> (url: URL, label: String)? {
        if let directURL = service.directURL(from: episode.streamingURL) {
            let label = AppLocalization.format(
                "Streaming.OpenInService",
                defaultValue: "In %@ öffnen",
                service.displayName(for: episode.streamingURL)
            )
            return (directURL, label)
        }

        let catalogEntry = catalog.entry(
            for: episode.episodeNumber,
            in: episode.universe?.name
        )

        if let entry = catalogEntry, let catalogURL = service.catalogURL(from: entry) {
            let label = AppLocalization.format(
                "Streaming.OpenInService",
                defaultValue: "In %@ öffnen",
                service.displayName(for: catalogURL.absoluteString)
            )
            return (catalogURL, label)
        }

        return nil
    }
}
