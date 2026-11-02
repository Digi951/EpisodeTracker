import Foundation

/// Suche für „Neue Folge“: Nummer oder Titel tippen, Treffer antippen, fertig
/// (Design Review 2026-11, Befund 6). Sucht über alle aktiven Kataloge und
/// blendet Folgen aus, die schon in der Bibliothek stehen.
enum CatalogEpisodeSearch {
    struct Result: Equatable {
        let universeName: String
        let entry: CatalogEntry
    }

    /// Normalisierte Namen der aktiven Kataloge, passend zu `results(for:)`.
    @MainActor
    static func activeCollectionNames() -> Set<String> {
        let activeIDs = ActiveCatalogStore().activeIDs
        return Set(
            EpisodeCatalog.shared.managedSources
                .filter { activeIDs.contains($0.id) }
                .map { CatalogLibraryMatcher.normalizedCollectionKey($0.name) }
        )
    }

    nonisolated static func results(
        for query: String,
        entries: [CatalogEntry],
        activeCollectionNames: Set<String>,
        libraryEpisodes: [Episode],
        limit: Int = 30
    ) -> [Result] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let numberQuery = trimmed.allSatisfy(\.isNumber) ? Int(trimmed) : nil
        // Einzelne Buchstaben treffen fast jeden Titel; Nummern dagegen sind
        // schon ab einer Ziffer eindeutig.
        guard numberQuery != nil || trimmed.count >= 2 else { return [] }

        let existingNumbers = CatalogLibraryMatcher.existingNumbersByCollection(libraryEpisodes: libraryEpisodes)
        let existingSlugs = CatalogLibraryMatcher.existingSpecialSlugsByCollection(libraryEpisodes: libraryEpisodes)

        var seen = Set<String>()
        var numberMatches: [Result] = []
        var titleMatches: [Result] = []

        for entry in entries {
            guard let collectionName = entry.collectionName else { continue }
            let collectionKey = CatalogLibraryMatcher.normalizedCollectionKey(collectionName)
            guard activeCollectionNames.contains(collectionKey) else { continue }

            switch entry.kind {
            case .regular:
                guard let number = entry.number,
                      !existingNumbers[collectionKey, default: []].contains(number)
                else { continue }
            case .special:
                if let slug = entry.slug?.lowercased(),
                   existingSlugs[collectionKey, default: []].contains(slug) {
                    continue
                }
            }

            let isNumberMatch = entry.kind == .regular && entry.number == numberQuery && numberQuery != nil
            let isTitleMatch = entry.title.range(
                of: trimmed,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            ) != nil
            guard isNumberMatch || isTitleMatch else { continue }

            let identity = entry.number.map(String.init) ?? "special:\(entry.slug ?? entry.title)"
            guard seen.insert("\(collectionKey)#\(identity)").inserted else { continue }

            let result = Result(universeName: collectionName, entry: entry)
            if isNumberMatch {
                numberMatches.append(result)
            } else {
                titleMatches.append(result)
            }
        }

        let ordered = sorted(numberMatches) + sorted(titleMatches)
        return Array(ordered.prefix(limit))
    }

    private nonisolated static func sorted(_ results: [Result]) -> [Result] {
        results.sorted {
            if $0.universeName != $1.universeName {
                return $0.universeName.localizedStandardCompare($1.universeName) == .orderedAscending
            }
            return ($0.entry.number ?? Int.max) < ($1.entry.number ?? Int.max)
        }
    }
}
