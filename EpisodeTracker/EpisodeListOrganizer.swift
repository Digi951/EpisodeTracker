import Foundation

enum EpisodeStatusFilter: String, CaseIterable {
    case all = "Alle"
    case open = "Offen"
    case listened = "Gehört"
    case rated = "Bewertet"
    case noted = "Mit Notiz"
}

struct EpisodeListGroup: Identifiable {
    let id: String
    let title: String
    let episodes: [Episode]

    var listenedCount: Int {
        episodes.filter(\.isListened).count
    }

    var openCount: Int {
        episodes.count - listenedCount
    }

    var summary: String {
        "\(episodes.count) Folgen · \(listenedCount) gehört · \(openCount) offen"
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
            result = result.filter { $0.moods.contains(filterMood) }
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
        universeCount: Int
    ) -> [EpisodeListGroup] {
        guard shouldGroup(episodes: episodes, sortOrder: sortOrder, filterUniverse: filterUniverse, universeCount: universeCount) else {
            return []
        }

        switch sortOrder {
        case .recentlyPlayed:
            return listenedStateGroups(for: episodes)
        case .number:
            if filterUniverse == nil && universeCount > 1 {
                return universeGroups(for: episodes)
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
            return episodes.count >= 10
        }
        return episodes.count >= 30
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

    private static func universeGroups(for episodes: [Episode]) -> [EpisodeListGroup] {
        let grouped = Dictionary(grouping: episodes) { episode in
            episode.universe?.name ?? "Allgemein"
        }
        return grouped.keys.sorted().map { key in
            EpisodeListGroup(id: "universe:\(key)", title: key, episodes: grouped[key] ?? [])
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
                episodes: grouped[start] ?? []
            )
        }
    }

    private static func titleGroups(for episodes: [Episode]) -> [EpisodeListGroup] {
        let grouped = Dictionary(grouping: episodes) { episode in
            let trimmed = episode.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.first.map { String($0).uppercased() } ?? "#"
        }
        return grouped.keys.sorted().map { key in
            EpisodeListGroup(id: "title:\(key)", title: key, episodes: grouped[key] ?? [])
        }
    }

    private static func ratingGroups(for episodes: [Episode]) -> [EpisodeListGroup] {
        let grouped = Dictionary(grouping: episodes) { episode in
            episode.rating ?? 0
        }
        return grouped.keys.sorted(by: >).map { rating in
            let title = rating == 0 ? "Ohne Bewertung" : "\(rating) Sterne"
            return EpisodeListGroup(id: "rating:\(rating)", title: title, episodes: grouped[rating] ?? [])
        }
    }

    private static func releaseYearGroups(for episodes: [Episode]) -> [EpisodeListGroup] {
        let grouped = Dictionary(grouping: episodes) { episode in
            episode.releaseYear
        }
        return grouped.keys.sorted(by: >).map { year in
            EpisodeListGroup(id: "year:\(year)", title: String(year), episodes: grouped[year] ?? [])
        }
    }

    private static func listenedStateGroups(for episodes: [Episode]) -> [EpisodeListGroup] {
        let listened = episodes.filter(\.isListened)
        let open = episodes.filter { !$0.isListened }
        return [
            EpisodeListGroup(id: "recent:listened", title: "Gehört", episodes: listened),
            EpisodeListGroup(id: "recent:open", title: "Noch offen", episodes: open)
        ]
        .filter { !$0.episodes.isEmpty }
    }
}
