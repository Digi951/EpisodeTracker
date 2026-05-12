import Foundation

enum EpisodeStatusFilter: String, CaseIterable {
    case all = "Alle"
    case open = "Offen"
    case listened = "Gehört"
    case rated = "Bewertet"
    case noted = "Mit Notiz"
}

enum EpisodeGroupCollapseStore {
    static func decode(_ rawValue: String) -> [String: Set<String>] {
        guard !rawValue.isEmpty,
              let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data)
        else {
            return [:]
        }

        return decoded.mapValues(Set.init)
    }

    static func encode(_ state: [String: Set<String>]) -> String {
        let encoded = state.mapValues { Array($0).sorted() }
        guard let data = try? JSONEncoder().encode(encoded),
              let string = String(data: data, encoding: .utf8)
        else {
            return ""
        }

        return string
    }

    static func scopeKey(
        sortOrder: String,
        filterUniverseName: String?,
        statusFilter: EpisodeStatusFilter,
        isMultiUniverse: Bool
    ) -> String {
        let universeKey = filterUniverseName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "__all__"
        let universeMode = isMultiUniverse ? "multi" : "single"
        return [sortOrder, universeKey, statusFilter.rawValue, universeMode].joined(separator: "|")
    }
}

struct EpisodeListGroup: Identifiable {
    let id: String
    let title: String
    let episodes: [Episode]
    let progressTotalOverride: Int?

    var listenedCount: Int {
        episodes.filter(\.isListened).count
    }

    var progressTotal: Int {
        max(progressTotalOverride ?? episodes.count, listenedCount)
    }

    var openCount: Int {
        max(progressTotal - listenedCount, 0)
    }

    var progress: Double {
        guard progressTotal > 0 else { return 0 }
        return Double(listenedCount) / Double(progressTotal)
    }

    var progressText: String {
        progress.formatted(.percent.precision(.fractionLength(0)))
    }

    var summary: String {
        "\(listenedCount) von \(progressTotal) gehört · \(openCount) offen"
    }
}

enum EpisodeListOrganizer {
    static func filteredAndSortedEpisodes(
        episodes: [Episode],
        searchText: String,
        filterUniverse: Universe?,
        filterMood: Mood?,
        statusFilter: EpisodeStatusFilter,
        sortOrder: EpisodeListView.SortOrder
    ) -> [Episode] {
        var result = episodes

        if !searchText.isEmpty {
            result = result.filter { episode in
                episode.title.localizedCaseInsensitiveContains(searchText)
                || String(episode.episodeNumber).contains(searchText)
            }
        }

        if let filterUniverse {
            result = result.filter { $0.universe == filterUniverse }
        }

        if let filterMood {
            result = result.filter { episode in
                episode.moods.contains(where: { $0.matches(filterMood) })
            }
        }

        switch statusFilter {
        case .all:
            break
        case .open:
            result = result.filter { !$0.isListened }
        case .listened:
            result = result.filter(\.isListened)
        case .rated:
            result = result.filter { $0.rating != nil }
        case .noted:
            result = result.filter { episode in
                guard let note = episode.personalNote?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                    return false
                }
                return !note.isEmpty
            }
        }

        sort(&result, by: sortOrder)
        return result
    }

    static func groups(
        for episodes: [Episode],
        sortOrder: EpisodeListView.SortOrder,
        filterUniverse: Universe?,
        universeCount: Int,
        catalogTotalsByUniverse: [String: Int] = [:],
        preferCatalogTotals: Bool = true
    ) -> [EpisodeListGroup] {
        guard shouldGroup(episodes: episodes, sortOrder: sortOrder, filterUniverse: filterUniverse, universeCount: universeCount) else {
            return []
        }

        switch sortOrder {
        case .recentlyPlayed:
            return listenedStateGroups(for: episodes)
        case .number:
            if filterUniverse == nil && universeCount > 1 {
                return universeGroups(
                    for: episodes,
                    catalogTotalsByUniverse: catalogTotalsByUniverse,
                    preferCatalogTotals: preferCatalogTotals
                )
            }
            return numberRangeGroups(for: episodes)
        case .title:
            return titleGroups(for: episodes)
        case .rating:
            return ratingGroups(for: episodes)
        case .releaseYear:
            return releaseYearGroups(for: episodes)
        }
    }

    static func shouldGroup(
        episodes: [Episode],
        sortOrder: EpisodeListView.SortOrder,
        filterUniverse: Universe?,
        universeCount: Int
    ) -> Bool {
        guard !episodes.isEmpty else { return false }
        if sortOrder == .releaseYear || sortOrder == .rating {
            return episodes.count >= 10
        }
        if filterUniverse == nil && universeCount > 1 {
            return episodes.count >= 2
        }
        return episodes.count >= 12
    }

    private static func sort(_ episodes: inout [Episode], by sortOrder: EpisodeListView.SortOrder) {
        switch sortOrder {
        case .recentlyPlayed:
            episodes.sort {
                switch ($0.lastListenedAt, $1.lastListenedAt) {
                case let (left?, right?):
                    return left > right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return $0.episodeNumber < $1.episodeNumber
                }
            }
        case .number:
            episodes.sort { $0.episodeNumber < $1.episodeNumber }
        case .title:
            episodes.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .rating:
            episodes.sort {
                let leftRating = $0.rating ?? 0
                let rightRating = $1.rating ?? 0
                if leftRating != rightRating {
                    return leftRating > rightRating
                }
                return $0.episodeNumber < $1.episodeNumber
            }
        case .releaseYear:
            episodes.sort {
                if $0.releaseYear != $1.releaseYear {
                    return $0.releaseYear > $1.releaseYear
                }
                return $0.episodeNumber < $1.episodeNumber
            }
        }
    }

    private static func universeGroups(
        for episodes: [Episode],
        catalogTotalsByUniverse: [String: Int],
        preferCatalogTotals: Bool
    ) -> [EpisodeListGroup] {
        let grouped = Dictionary(grouping: episodes) { episode in
            episode.universe?.name ?? "Allgemein"
        }
        return grouped.keys.sorted().map { key in
            let totalOverride = preferCatalogTotals ? catalogTotalsByUniverse[key.lowercased()] : nil
            return EpisodeListGroup(
                id: "universe:\(key)",
                title: key,
                episodes: grouped[key] ?? [],
                progressTotalOverride: totalOverride
            )
        }
    }

    private static func numberRangeGroups(for episodes: [Episode]) -> [EpisodeListGroup] {
        let grouped = Dictionary(grouping: episodes) { episode in
            ((max(episode.episodeNumber, 1) - 1) / 25) * 25 + 1
        }
        return grouped.keys.sorted().map { start in
            let end = start + 24
            return EpisodeListGroup(
                id: "number:\(start)",
                title: "\(start)-\(end)",
                episodes: grouped[start] ?? [],
                progressTotalOverride: nil
            )
        }
    }

    private static func titleGroups(for episodes: [Episode]) -> [EpisodeListGroup] {
        let grouped = Dictionary(grouping: episodes) { episode in
            let trimmed = episode.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.first.map { String($0).uppercased() } ?? "#"
        }
        return grouped.keys.sorted().map { key in
            EpisodeListGroup(id: "title:\(key)", title: key, episodes: grouped[key] ?? [], progressTotalOverride: nil)
        }
    }

    private static func ratingGroups(for episodes: [Episode]) -> [EpisodeListGroup] {
        let grouped = Dictionary(grouping: episodes) { episode in
            episode.rating ?? 0
        }
        return grouped.keys.sorted(by: >).map { rating in
            let title = rating == 0 ? "Ohne Bewertung" : "\(rating) Sterne"
            return EpisodeListGroup(id: "rating:\(rating)", title: title, episodes: grouped[rating] ?? [], progressTotalOverride: nil)
        }
    }

    private static func releaseYearGroups(for episodes: [Episode]) -> [EpisodeListGroup] {
        let grouped = Dictionary(grouping: episodes) { episode in
            episode.releaseYear
        }
        return grouped.keys.sorted(by: >).map { year in
            EpisodeListGroup(id: "year:\(year)", title: String(year), episodes: grouped[year] ?? [], progressTotalOverride: nil)
        }
    }

    private static func listenedStateGroups(for episodes: [Episode]) -> [EpisodeListGroup] {
        let listened = episodes.filter(\.isListened)
        let open = episodes.filter { !$0.isListened }
        return [
            EpisodeListGroup(id: "recent:listened", title: "Gehört", episodes: listened, progressTotalOverride: nil),
            EpisodeListGroup(id: "recent:open", title: "Noch offen", episodes: open, progressTotalOverride: nil)
        ]
        .filter { !$0.episodes.isEmpty }
    }
}
