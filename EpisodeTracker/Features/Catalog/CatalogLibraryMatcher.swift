// EpisodeTracker/Features/Catalog/CatalogLibraryMatcher.swift
import Foundation

/// Eine Quelle der Wahrheit für die Frage: Welche Katalogfolge hat der Nutzer
/// bereits in der Bibliothek? Konsolidiert Normalisierung und Missing-/Existing-
/// Berechnung, die zuvor in SmartListDefinition, CatalogTitleAutocomplete und
/// EpisodeCatalog dupliziert (und leicht abweichend) implementiert war.
enum CatalogLibraryMatcher {
    nonisolated static func normalizedCollectionKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    nonisolated static func existingNumbersByCollection(libraryEpisodes: [Episode]) -> [String: Set<Int>] {
        Dictionary(grouping: libraryEpisodes) {
            normalizedCollectionKey($0.universe?.name ?? "")
        }
        .mapValues { episodes in Set(episodes.map(\.episodeNumber)) }
    }

    nonisolated static func existingSpecialSlugsByCollection(libraryEpisodes: [Episode]) -> [String: Set<String>] {
        Dictionary(grouping: libraryEpisodes.filter { $0.isSpecial && ($0.catalogSlug?.isEmpty == false) }) {
            normalizedCollectionKey($0.universe?.name ?? "")
        }
        .mapValues { episodes in Set(episodes.compactMap { $0.catalogSlug?.lowercased() }) }
    }

    nonisolated static func missingEntries(
        catalogEntries: [CatalogEntry],
        libraryEpisodes: [Episode]
    ) -> [(universeName: String, entry: CatalogEntry)] {
        let trackedLibrary = libraryEpisodes.filter { $0.universe != nil }
        let libraryByCollection = existingNumbersByCollection(libraryEpisodes: trackedLibrary)
        let librarySlugsByCollection = existingSpecialSlugsByCollection(libraryEpisodes: trackedLibrary)
        let catalogByCollection = Dictionary(grouping: catalogEntries.filter { $0.collectionName != nil }) {
            normalizedCollectionKey($0.collectionName ?? "")
        }

        var results: [(universeName: String, entry: CatalogEntry)] = []

        for (collectionKey, catalogEpisodes) in catalogByCollection {
            let libraryNumbers = libraryByCollection[collectionKey] ?? []
            // Nur Sammlungen vorschlagen, denen der Nutzer bereits folgt. Sonderfolgen
            // tragen episodeNumber 0 bei, halten die Sammlung also ebenfalls „verfolgt".
            guard !libraryNumbers.isEmpty else { continue }

            let displayName = catalogEpisodes.first?.collectionName ?? collectionKey

            // Reguläre Folgen: Abgleich über (Sammlung, Nummer) — unverändertes Bestandsverhalten.
            var seenNumbers = Set<Int>()
            let uniqueRegular = catalogEpisodes.filter { entry in
                guard entry.kind == .regular, let number = entry.number else { return false }
                return seenNumbers.insert(number).inserted
            }
            let missingRegular = uniqueRegular.filter { entry in
                entry.number.map { !libraryNumbers.contains($0) } ?? false
            }
            for entry in missingRegular {
                results.append((displayName, entry))
            }

            // Sonderfolgen: Abgleich über (Sammlung, Slug).
            let librarySlugs = librarySlugsByCollection[collectionKey] ?? []
            var seenSlugs = Set<String>()
            let uniqueSpecial = catalogEpisodes.filter { entry in
                guard entry.kind == .special, let slug = entry.slug?.lowercased(), !slug.isEmpty else { return false }
                return seenSlugs.insert(slug).inserted
            }
            let missingSpecial = uniqueSpecial.filter { entry in
                guard let slug = entry.slug?.lowercased() else { return false }
                return !librarySlugs.contains(slug)
            }
            for entry in missingSpecial {
                results.append((displayName, entry))
            }
        }

        results.sort {
            if $0.universeName != $1.universeName {
                return $0.universeName.localizedCompare($1.universeName) == .orderedAscending
            }
            switch ($0.entry.kind, $1.entry.kind) {
            case (.regular, .special):
                return true
            case (.special, .regular):
                return false
            case (.regular, .regular):
                return ($0.entry.number ?? 0) < ($1.entry.number ?? 0)
            case (.special, .special):
                return $0.entry.title.localizedCompare($1.entry.title) == .orderedAscending
            }
        }
        return results
    }
}
