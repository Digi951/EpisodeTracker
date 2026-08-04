import Foundation

enum EpisodeSortOrder: String, CaseIterable {
    case recentlyPlayed = "Zuletzt gespielt"
    case number = "Nummer"
    case title = "Titel A-Z"
    case rating = "Bewertung"
    case releaseYear = "Erscheinungsjahr"

    var localizationKey: String {
        switch self {
        case .recentlyPlayed: "EpisodeSortOrder.RecentlyPlayed"
        case .number: "EpisodeSortOrder.Number"
        case .title: "EpisodeSortOrder.Title"
        case .rating: "EpisodeSortOrder.Rating"
        case .releaseYear: "EpisodeSortOrder.ReleaseYear"
        }
    }

    var displayName: String {
        switch self {
        case .recentlyPlayed:
            String(localized: "EpisodeSortOrder.RecentlyPlayed", defaultValue: "Zuletzt gespielt")
        case .number:
            String(localized: "EpisodeSortOrder.Number", defaultValue: "Nummer")
        case .title:
            String(localized: "EpisodeSortOrder.Title", defaultValue: "Titel A-Z")
        case .rating:
            String(localized: "EpisodeSortOrder.Rating", defaultValue: "Bewertung")
        case .releaseYear:
            String(localized: "EpisodeSortOrder.ReleaseYear", defaultValue: "Erscheinungsjahr")
        }
    }
}

enum EpisodeStatusFilter: String, CaseIterable {
    case all = "Alle"
    case open = "Offen"
    case listened = "Gehört"
    case favorites = "Favoriten"
    case rated = "Bewertet"
    case noted = "Mit Notiz"
    case specials = "Sonderfolgen"

    var localizationKey: String {
        switch self {
        case .all: "EpisodeStatusFilter.All"
        case .open: "EpisodeStatusFilter.Open"
        case .listened: "EpisodeStatusFilter.Listened"
        case .favorites: "EpisodeStatusFilter.Favorites"
        case .rated: "EpisodeStatusFilter.Rated"
        case .noted: "EpisodeStatusFilter.Noted"
        case .specials: "EpisodeStatusFilter.Specials"
        }
    }

    var displayName: String {
        switch self {
        case .all:
            String(localized: "EpisodeStatusFilter.All", defaultValue: "Alle")
        case .open:
            String(localized: "EpisodeStatusFilter.Open", defaultValue: "Offen")
        case .listened:
            String(localized: "EpisodeStatusFilter.Listened", defaultValue: "Gehört")
        case .favorites:
            String(localized: "EpisodeStatusFilter.Favorites", defaultValue: "Favoriten")
        case .rated:
            String(localized: "EpisodeStatusFilter.Rated", defaultValue: "Bewertet")
        case .noted:
            String(localized: "EpisodeStatusFilter.Noted", defaultValue: "Mit Notiz")
        case .specials:
            String(localized: "EpisodeStatusFilter.Specials", defaultValue: "Sonderfolgen")
        }
    }
}

struct EpisodeListControlsState {
    var searchText = ""
    var filterMood: Mood?
    var filterUniverse: Universe?
    var statusFilter: EpisodeStatusFilter = .all
    var sortOrder: EpisodeSortOrder = .number

    var hasActiveFilter: Bool {
        filterMood != nil || filterUniverse != nil || statusFilter != .all
    }

    func collapseScopeKey(universeCount: Int) -> String {
        EpisodeGroupCollapseStore.scopeKey(
            sortOrder: sortOrder.rawValue,
            filterUniverseName: filterUniverse?.name,
            statusFilter: statusFilter,
            isMultiUniverse: filterUniverse == nil && universeCount > 1
        )
    }

    mutating func resetFilters(resetMood: Bool = true) {
        if resetMood {
            filterMood = nil
        }
        filterUniverse = nil
        statusFilter = .all
    }
}

struct EpisodeDeleteState {
    var pendingEpisodes: [Episode] = []

    var title: String {
        pendingEpisodes.count == 1
            ? String(localized: "EpisodeDelete.Title.One", defaultValue: "Folge löschen?")
            : AppLocalization.format(
                "EpisodeDelete.Title.Many",
                defaultValue: "%lld Folgen löschen?",
                Int64(pendingEpisodes.count)
            )
    }

    func message(usesCloudSync: Bool) -> String {
        let syncHint = usesCloudSync
            ? String(
                localized: "EpisodeDelete.Message.SyncHint.Cloud",
                defaultValue: "Die Folgen werden auf allen synchronisierten Geräten entfernt."
            )
            : String(
                localized: "EpisodeDelete.Message.SyncHint.Local",
                defaultValue: "Die Folgen werden nur auf diesem Gerät entfernt."
            )
        let catalogHint = String(
            localized: "EpisodeDelete.Message.CatalogHint",
            defaultValue: "Katalogeinträge bleiben erhalten und können erneut übernommen werden."
        )

        if pendingEpisodes.count == 1, let episode = pendingEpisodes.first {
            return AppLocalization.format(
                "EpisodeDelete.Message.One",
                defaultValue: "„%@“ wird dauerhaft gelöscht. %@ %@",
                episode.title,
                syncHint,
                catalogHint
            )
        }

        return AppLocalization.format(
            "EpisodeDelete.Message.Many",
            defaultValue: "%@ %@",
            syncHint,
            catalogHint
        )
    }

    mutating func request(_ episode: Episode) {
        pendingEpisodes = [episode]
    }

    mutating func request(from episodes: [Episode], at offsets: IndexSet) {
        pendingEpisodes = offsets.map { episodes[$0] }
    }

    mutating func requestBatch(_ episodes: [Episode]) {
        pendingEpisodes = episodes
    }

    mutating func clear() {
        pendingEpisodes = []
    }

    var isActive: Bool {
        !pendingEpisodes.isEmpty
    }
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

    static func collapsedIDs(
        from rawValue: String,
        scopeKey: String
    ) -> Set<String> {
        decode(rawValue)[scopeKey] ?? []
    }

    static func toggle(
        groupID: String,
        in rawValue: String,
        scopeKey: String
    ) -> String {
        var state = decode(rawValue)
        var ids = state[scopeKey] ?? []
        if ids.contains(groupID) {
            ids.remove(groupID)
        } else {
            ids.insert(groupID)
        }
        state[scopeKey] = ids
        return encode(state)
    }
}

