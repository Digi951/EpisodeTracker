import Foundation

/// Suche für „Neue Folge“: Nummer oder Titel tippen, Treffer antippen, fertig
/// (Design Review 2026-11, Befund 6). Sucht über alle aktiven Kataloge und
/// blendet Folgen aus, die schon in der Bibliothek stehen.
enum CatalogEpisodeSearch {
    struct Result: Equatable {
        let universeName: String
        let entry: CatalogEntry

        /// Eindeutig pro Reihe: Nummer bei regulären Folgen, Slug (oder Titel)
        /// bei Sonderfolgen. Für Duplikat-Abgleich und als Zeilen-ID.
        nonisolated var identity: String {
            let key = CatalogLibraryMatcher.normalizedCollectionKey(universeName)
            switch entry.kind {
            case .regular:
                return "\(key)#\(entry.number.map(String.init) ?? entry.title.lowercased())"
            case .special:
                return "\(key)#special:\(entry.slug?.lowercased() ?? entry.title.lowercased())"
            }
        }
    }

    /// Normalisierte Namen der aktiven Kataloge, passend zu `results(for:)`.
    /// Liest die gecachte Quellenliste, nicht das Manifest von der Platte: wird
    /// aus View-Bodies aufgerufen.
    @MainActor
    static func activeCollectionNames() -> Set<String> {
        let activeIDs = ActiveCatalogStore().activeIDs
        return Set(
            CatalogSourceRegistry.allKnownSources
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

        var numberMatches: [Result] = []
        var titleMatches: [Result] = []

        for result in missingEntries(
            entries: entries,
            activeCollectionNames: activeCollectionNames,
            libraryEpisodes: libraryEpisodes
        ) {
            let entry = result.entry
            let isNumberMatch = entry.kind == .regular && entry.number == numberQuery && numberQuery != nil
            let isTitleMatch = entry.title.range(
                of: trimmed,
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            ) != nil
            if isNumberMatch {
                numberMatches.append(result)
            } else if isTitleMatch {
                titleMatches.append(result)
            }
        }

        let ordered = sorted(numberMatches) + sorted(titleMatches)
        return Array(ordered.prefix(limit))
    }

    /// Katalogfolgen aus aktiven Katalogen, die noch nicht in der Bibliothek
    /// stehen, ohne Duplikate. Gemeinsame Grundlage für die Suche und die
    /// Saison-Liste, damit beide dieselbe Regel für „fehlt noch“ anwenden.
    nonisolated static func missingEntries(
        entries: [CatalogEntry],
        activeCollectionNames: Set<String>,
        libraryEpisodes: [Episode]
    ) -> [Result] {
        let existingNumbers = CatalogLibraryMatcher.existingRegularNumbersByCollection(libraryEpisodes: libraryEpisodes)
        let existingSlugs = CatalogLibraryMatcher.existingSpecialSlugsByCollection(libraryEpisodes: libraryEpisodes)
        let existingSpecialTitles = CatalogLibraryMatcher.existingUnsluggedSpecialTitlesByCollection(libraryEpisodes: libraryEpisodes)

        var seen = Set<String>()
        return entries.compactMap { entry in
            guard let collectionName = entry.collectionName else { return nil }
            let collectionKey = CatalogLibraryMatcher.normalizedCollectionKey(collectionName)
            guard activeCollectionNames.contains(collectionKey) else { return nil }

            switch entry.kind {
            case .regular:
                guard let number = entry.number,
                      !existingNumbers[collectionKey, default: []].contains(number)
                else { return nil }
            case .special:
                if let slug = entry.slug?.lowercased(), !slug.isEmpty {
                    if existingSlugs[collectionKey, default: []].contains(slug) { return nil }
                } else if existingSpecialTitles[collectionKey, default: []].contains(entry.title.lowercased()) {
                    return nil
                }
            }

            let result = Result(universeName: collectionName, entry: entry)
            guard seen.insert(result.identity).inserted else { return nil }
            return result
        }
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
