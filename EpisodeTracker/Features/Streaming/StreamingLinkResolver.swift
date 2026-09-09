import Foundation

struct StreamingLinkResolver {
    let service: StreamingService
    let catalog: EpisodeCatalog

    func resolve(for episode: Episode) -> (url: URL, label: String, systemImage: String)? {
        if let directURL = service.directURL(from: episode.streamingURL) {
            let label = AppLocalization.format(
                "Streaming.OpenInService",
                defaultValue: "In %@ öffnen",
                service.displayName(for: episode.streamingURL)
            )
            return (directURL, label, service.iconName)
        }

        let entry = catalogEntry(for: episode)

        if let entry, let catalogURL = service.catalogURL(from: entry) {
            let label = AppLocalization.format(
                "Streaming.OpenInService",
                defaultValue: "In %@ öffnen",
                service.displayName(for: catalogURL.absoluteString)
            )
            return (catalogURL, label, service.iconName)
        }

        // Kein passender Streaming-Dienst, aber der Katalog nennt eine generische
        // Quelle (Sender-Mediathek, Studio-Seite …).
        if let entry, let sourceURL = entry.sourceURL {
            let label = AppLocalization.format(
                "Streaming.OpenOriginalSource",
                defaultValue: "Originalquelle öffnen"
            )
            return (sourceURL, label, "arrow.up.forward.square")
        }

        return nil
    }

    /// Sonderfolgen (Anthologie) haben keine belastbare Nummer — zuerst über den
    /// Slug suchen, dann auf die reguläre Nummernsuche zurückfallen.
    private func catalogEntry(for episode: Episode) -> CatalogEntry? {
        if let slug = episode.catalogSlug,
           !slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let bySlug = catalog.entry(forSlug: slug, in: episode.universe?.name) {
            return bySlug
        }
        return catalog.entry(for: episode.episodeNumber, in: episode.universe?.name)
    }
}
