import Foundation

enum SpecialEpisodeReconciler {
    /// Adoptiert für manuell angelegte Sonderfolgen den kuratierten Katalog-Slug,
    /// wenn (Sammlung, normalisierter Titel, Jahr) eindeutig übereinstimmen. Dadurch
    /// kollabieren manuelle und kuratierte Variante auf denselben syncKey und der
    /// bestehende slug-basierte Dedup führt sie geräteübergreifend zusammen.
    static func reconcile(libraryEpisodes: [Episode], catalogEntries: [CatalogEntry]) {
        let specials = catalogEntries.filter { $0.kind == .special && ($0.slug?.isEmpty == false) }
        guard !specials.isEmpty else { return }

        for episode in libraryEpisodes where episode.isSpecial {
            let titleKey = CatalogLibraryMatcher.normalizedCollectionKey(episode.title)
            let collectionKey = CatalogLibraryMatcher.normalizedCollectionKey(episode.universe?.name ?? "")
            let candidates = specials.filter {
                CatalogLibraryMatcher.normalizedCollectionKey($0.title) == titleKey
                && CatalogLibraryMatcher.normalizedCollectionKey($0.collectionName ?? "") == collectionKey
                && $0.releaseYear == episode.releaseYear
            }

            guard candidates.count == 1, let match = candidates.first, let slug = match.slug else { continue }
            guard episode.catalogSlug != slug else { continue }

            episode.catalogSlug = slug
            if episode.streamingURL == nil {
                episode.streamingURL = match.spotifyURL ?? match.appleMusicURL
            }
            episode.specialUpdatedAt = .now
            episode.refreshSyncKeyIfPossible()
        }
    }
}
