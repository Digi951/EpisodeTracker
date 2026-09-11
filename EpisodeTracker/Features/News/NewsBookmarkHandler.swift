import Foundation
import SwiftData

/// Merklisten-Aktion für eine Neuigkeiten-Zeile (Datenvertrag Paket 4 §4.D7).
/// Reine Zuordnungslogik plus ein einzelner SwiftData-Seiteneffekt — Muster
/// analog `CatalogActivationHandler`.
///
/// Matching folgt derselben Identität wie `CatalogLibraryMatcher`/
/// `BackupRestorer`: normalisierter Sammlungsname + Folgennummer (oder Slug
/// bei Sonderfolgen). Ein wiederholter Tipp findet also immer dieselbe Folge
/// wieder, statt eine zweite anzulegen.
///
/// Nur für `.newEpisode`/`.upcoming`-Ereignisse sinnvoll — `.newCatalog` hat
/// keine Folgen-Identität (kein `episodeNumber`/`slug`) und wird von der UI
/// nicht mit einem Merken-Button dargestellt.
enum NewsBookmarkHandler {

    /// Schaltet `isBookmarked` an der zu `event` passenden Bibliotheksfolge um:
    /// existiert sie bereits, wird nur das Flag umgeschaltet — Notiz, Bewertung
    /// und Hörstatus bleiben unberührt, und ein bereits vorhandener Eintrag
    /// wird beim Entmerken nie gelöscht. Existiert keine, wird eine neue,
    /// gemerkte Folge angelegt (`isListened: false`) und an die passende (bei
    /// Bedarf neu erzeugte) Sammlung gebunden.
    @discardableResult
    @MainActor
    static func toggleBookmark(
        for event: NewsEvent,
        modelContext: ModelContext,
        existingEpisodes: [Episode],
        existingUniverses: [Universe]
    ) -> Episode {
        if let existing = matchingEpisode(for: event, in: existingEpisodes) {
            existing.isBookmarked.toggle()
            existing.bookmarkedUpdatedAt = Date()
            return existing
        }

        let universe = matchingUniverse(for: event, in: existingUniverses) ?? {
            let created = Universe(name: event.universeName)
            modelContext.insert(created)
            return created
        }()

        let episode = Episode(
            episodeNumber: event.episodeNumber ?? 0,
            title: event.title,
            releaseYear: releaseYear(for: event),
            kind: event.episodeNumber == nil && event.slug != nil ? .special : .regular,
            catalogSlug: event.slug,
            isListened: false,
            isBookmarked: true,
            universe: universe
        )
        modelContext.insert(episode)
        return episode
    }

    /// Testbare Seam ohne SwiftData-Seiteneffekt: nur die Suche, kein Anlegen.
    static func matchingEpisode(for event: NewsEvent, in episodes: [Episode]) -> Episode? {
        let key = CatalogLibraryMatcher.normalizedCollectionKey(event.universeName)
        return episodes.first { episode in
            guard CatalogLibraryMatcher.normalizedCollectionKey(episode.universe?.name ?? "") == key else {
                return false
            }
            if let number = event.episodeNumber {
                return episode.episodeNumber == number
            }
            if let slug = event.slug {
                return episode.catalogSlug?.lowercased() == slug.lowercased()
            }
            return false
        }
    }

    private static func matchingUniverse(for event: NewsEvent, in universes: [Universe]) -> Universe? {
        let key = CatalogLibraryMatcher.normalizedCollectionKey(event.universeName)
        return universes.first { CatalogLibraryMatcher.normalizedCollectionKey($0.name) == key }
    }

    /// `NewsEvent` trägt kein eigenes `releaseYear` — bei `.upcoming` liefert
    /// die Revision (Kalendertag) ein echtes Jahr, sonst das Entdeckungsjahr
    /// als plausible Näherung, die der Nutzer jederzeit nachträglich anpassen
    /// kann.
    private static func releaseYear(for event: NewsEvent) -> Int {
        if let releaseDate = CalendarDayFormatter.date(from: event.revision) {
            return Calendar.current.component(.year, from: releaseDate)
        }
        return Calendar.current.component(.year, from: event.discoveredAt)
    }
}
