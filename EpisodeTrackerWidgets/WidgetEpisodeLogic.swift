import Foundation

enum WidgetEpisodeKind {
    case upNext
    case random
}

enum WidgetEpisodeLogic {
    static func episode(
        for kind: WidgetEpisodeKind,
        catalogID: String?,
        at date: Date,
        refreshToken: Int = 0,
        snapshot: WidgetLibrarySnapshot
    ) -> WidgetEpisodeSnapshot? {
        let filtered = episodes(in: snapshot, catalogID: catalogID)

        switch kind {
        case .upNext:
            return nextEpisode(from: filtered)
        case .random:
            return randomEpisode(from: filtered, catalogID: catalogID, at: date, refreshToken: refreshToken)
        }
    }

    static func selectedCatalogName(for catalogID: String?) -> String {
        guard let catalogID, !catalogID.isEmpty, catalogID != WidgetCatalogSelection.allValue else {
            return WidgetCatalogSelection.allTitle
        }
        return catalogID
    }

    private static func episodes(in snapshot: WidgetLibrarySnapshot, catalogID: String?) -> [WidgetEpisodeSnapshot] {
        guard let catalogID, !catalogID.isEmpty, catalogID != WidgetCatalogSelection.allValue else {
            return snapshot.episodes
        }

        return snapshot.episodes.filter {
            $0.universeName?.caseInsensitiveCompare(catalogID) == .orderedSame
        }
    }

    private static func nextEpisode(from episodes: [WidgetEpisodeSnapshot]) -> WidgetEpisodeSnapshot? {
        let grouped = Dictionary(grouping: episodes.filter { $0.universeName != nil }) {
            ($0.universeName ?? "").lowercased()
        }

        var candidates: [(episode: WidgetEpisodeSnapshot, lastActivity: Date)] = []

        for (_, allUniverseEpisodes) in grouped {
            // „Nächste Folge in der Reihe" gilt nur für reguläre, nummerierte Folgen.
            let universeEpisodes = allUniverseEpisodes.filter { !$0.isSpecial }
            let listened = universeEpisodes.filter(\.isListened)
            guard !listened.isEmpty else { continue }

            let maxListenedNumber = listened.map(\.episodeNumber).max() ?? 0
            let nextOpen = universeEpisodes
                .filter { !$0.isListened && $0.episodeNumber > maxListenedNumber }
                .min(by: { $0.episodeNumber < $1.episodeNumber })

            if let nextOpen {
                let lastActivity = listened.compactMap(\.lastListenedAt).max() ?? .distantPast
                candidates.append((nextOpen, lastActivity))
            }
        }

        return candidates
            .sorted(by: { $0.lastActivity > $1.lastActivity })
            .first?
            .episode
    }

    private static func randomEpisode(
        from episodes: [WidgetEpisodeSnapshot],
        catalogID: String?,
        at date: Date,
        refreshToken: Int
    ) -> WidgetEpisodeSnapshot? {
        guard !episodes.isEmpty else { return nil }

        let sorted = episodes.sorted {
            if ($0.universeName ?? "") != ($1.universeName ?? "") {
                return ($0.universeName ?? "").localizedCompare($1.universeName ?? "") == .orderedAscending
            }
            if $0.episodeNumber != $1.episodeNumber {
                return $0.episodeNumber < $1.episodeNumber
            }
            return $0.title.localizedCompare($1.title) == .orderedAscending
        }

        let hourSeed = Int(date.timeIntervalSince1970 / 3600)
        let scopeSeed = deterministicSeed(from: (catalogID ?? WidgetCatalogSelection.allValue) + "|random")
        let index = abs(hourSeed + scopeSeed + refreshToken) % sorted.count
        return sorted[index]
    }

    private static func deterministicSeed(from string: String) -> Int {
        string.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult &* 31 &+ Int(scalar.value)
        }
    }
}
