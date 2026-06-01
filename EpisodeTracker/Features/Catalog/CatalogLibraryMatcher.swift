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

    nonisolated static func missingEntries(
        catalogEntries: [CatalogEntry],
        libraryEpisodes: [Episode]
    ) -> [(universeName: String, entry: CatalogEntry)] {
        let libraryByCollection = existingNumbersByCollection(
            libraryEpisodes: libraryEpisodes.filter { $0.universe != nil }
        )
        let catalogByCollection = Dictionary(grouping: catalogEntries.filter { $0.collectionName != nil }) {
            normalizedCollectionKey($0.collectionName ?? "")
        }

        var results: [(universeName: String, entry: CatalogEntry)] = []

        for (collectionKey, catalogEpisodes) in catalogByCollection {
            let libraryNumbers = libraryByCollection[collectionKey] ?? []
            guard !libraryNumbers.isEmpty else { continue }

            let displayName = catalogEpisodes.first?.collectionName ?? collectionKey

            var seenNumbers = Set<Int>()
            let uniqueEpisodes = catalogEpisodes.filter { entry in
                guard let number = entry.number else { return false }
                return seenNumbers.insert(number).inserted
            }

            let missing = uniqueEpisodes
                .filter { entry in entry.number.map { !libraryNumbers.contains($0) } ?? false }
                .sorted { ($0.number ?? 0) < ($1.number ?? 0) }

            for entry in missing {
                results.append((displayName, entry))
            }
        }

        results.sort {
            if $0.universeName != $1.universeName {
                return $0.universeName.localizedCompare($1.universeName) == .orderedAscending
            }
            return ($0.entry.number ?? 0) < ($1.entry.number ?? 0)
        }
        return results
    }
}
