import Foundation

enum EpisodeSortOrder: String, CaseIterable {
    case recentlyPlayed = "Zuletzt gespielt"
    case number = "Nummer"
    case title = "Titel A-Z"
    case rating = "Bewertung"
    case releaseYear = "Erscheinungsjahr"
}

enum EpisodeStatusFilter: String, CaseIterable {
    case all = "Alle"
    case open = "Offen"
    case listened = "Gehört"
    case favorites = "Favoriten"
    case rated = "Bewertet"
    case noted = "Mit Notiz"
    case specials = "Sonderfolgen"
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
        AppLocalization.format(
            "EpisodeList.GroupSummary",
            defaultValue: "%lld von %lld gehört · %lld offen",
            Int64(listenedCount),
            Int64(progressTotal),
            Int64(openCount)
        )
    }
}

struct CatalogUpdateBannerRecommendation: Equatable {
    let missingEpisodeCount: Int
    let universeCount: Int
    let firstUniverseName: String
    let firstEpisodeTitle: String
    let iconName: String
    let iconColorName: String
    private let titleText: String
    private let messageText: String
    private let compactMessageText: String

    init(
        missingEpisodeCount: Int,
        universeCount: Int,
        firstUniverseName: String,
        firstEpisodeTitle: String
    ) {
        self.missingEpisodeCount = missingEpisodeCount
        self.universeCount = universeCount
        self.firstUniverseName = firstUniverseName
        self.firstEpisodeTitle = firstEpisodeTitle
        self.iconName = "text.badge.plus"
        self.iconColorName = "green"
        titleText = missingEpisodeCount == 1
            ? String(localized: "CatalogUpdate.NewEpisodes.Title.One", defaultValue: "1 neue Katalogfolge")
            : AppLocalization.format(
                "CatalogUpdate.NewEpisodes.Title.Many",
                defaultValue: "%lld neue Katalogfolgen",
                Int64(missingEpisodeCount)
            )
        if universeCount == 1 {
            messageText = AppLocalization.format(
                "CatalogUpdate.NewEpisodes.Message.OneUniverse",
                defaultValue: "%@: %@ wartet auf deine Bibliothek.",
                firstUniverseName,
                firstEpisodeTitle
            )
            compactMessageText = "\(firstUniverseName): \(firstEpisodeTitle)"
        } else {
            messageText = AppLocalization.format(
                "CatalogUpdate.NewEpisodes.Message.MultipleUniverses",
                defaultValue: "Aktive Kataloge haben neue Folgen, unter anderem %@ in %@.",
                firstEpisodeTitle,
                firstUniverseName
            )
            compactMessageText = AppLocalization.format(
                "CatalogUpdate.NewEpisodes.Compact.MultipleUniverses",
                defaultValue: "%lld Kataloge, u. a. %@",
                Int64(universeCount),
                firstUniverseName
            )
        }
    }

    private init(
        title: String,
        message: String,
        compactMessage: String,
        missingEpisodeCount: Int,
        universeCount: Int,
        firstUniverseName: String,
        firstEpisodeTitle: String,
        iconName: String = "text.badge.plus",
        iconColorName: String = "green"
    ) {
        self.missingEpisodeCount = missingEpisodeCount
        self.universeCount = universeCount
        self.firstUniverseName = firstUniverseName
        self.firstEpisodeTitle = firstEpisodeTitle
        self.iconName = iconName
        self.iconColorName = iconColorName
        titleText = title
        messageText = message
        compactMessageText = compactMessage
    }

    var title: String {
        titleText
    }

    var message: String {
        messageText
    }

    var compactMessage: String {
        compactMessageText
    }

    var fingerprint: String {
        "\(titleText)|\(universeCount)|\(missingEpisodeCount)|\(firstUniverseName)|\(firstEpisodeTitle)"
    }

    static func removedCatalogs(_ names: [String]) -> CatalogUpdateBannerRecommendation? {
        guard !names.isEmpty else { return nil }
        let title = names.count == 1
            ? String(localized: "CatalogUpdate.Removed.Title.One", defaultValue: "Katalog nicht mehr verfügbar")
            : AppLocalization.format(
                "CatalogUpdate.Removed.Title.Many",
                defaultValue: "%lld Kataloge nicht mehr verfügbar",
                Int64(names.count)
            )
        let message = names.count == 1
            ? AppLocalization.format(
                "CatalogUpdate.Removed.Message.One",
                defaultValue: "%@ wird nicht mehr unterstützt und wurde aus deinen aktiven Katalogen entfernt.",
                names[0]
            )
            : AppLocalization.format(
                "CatalogUpdate.Removed.Message.Many",
                defaultValue: "%@ werden nicht mehr unterstützt und wurden aus deinen aktiven Katalogen entfernt.",
                catalogList(names)
            )
        return CatalogUpdateBannerRecommendation(
            title: title,
            message: message,
            compactMessage: names.count == 1
                ? names[0]
                : AppLocalization.format(
                    "CatalogUpdate.Removed.Compact.Many",
                    defaultValue: "%lld Kataloge entfernt",
                    Int64(names.count)
                ),
            missingEpisodeCount: 0,
            universeCount: names.count,
            firstUniverseName: names[0],
            firstEpisodeTitle: names[0],
            iconName: "text.badge.minus",
            iconColorName: "orange"
        )
    }

    static func newCatalogs(_ availability: NewCatalogAvailability) -> CatalogUpdateBannerRecommendation? {
        guard let firstName = availability.firstName else { return nil }
        let title = availability.count == 1
            ? String(localized: "CatalogUpdate.NewCatalogs.Title.One", defaultValue: "1 neuer Katalog verfügbar")
            : AppLocalization.format(
                "CatalogUpdate.NewCatalogs.Title.Many",
                defaultValue: "%lld neue Kataloge verfügbar",
                Int64(availability.count)
            )
        let message = availability.count == 1
            ? AppLocalization.format(
                "CatalogUpdate.NewCatalogs.Message.One",
                defaultValue: "%@ kann in den Katalogen aktiviert werden.",
                firstName
            )
            : AppLocalization.format(
                "CatalogUpdate.NewCatalogs.Message.Many",
                defaultValue: "%@ und weitere Kataloge können aktiviert werden.",
                firstName
            )
        return CatalogUpdateBannerRecommendation(
            title: title,
            message: message,
            compactMessage: availability.count == 1
                ? firstName
                : AppLocalization.format(
                    "CatalogUpdate.NewCatalogs.Compact.Many",
                    defaultValue: "%lld neue Kataloge",
                    Int64(availability.count)
                ),
            missingEpisodeCount: 0,
            universeCount: availability.count,
            firstUniverseName: firstName,
            firstEpisodeTitle: firstName
        )
    }

    static func episodeDelta(_ delta: CatalogEpisodeDelta) -> CatalogUpdateBannerRecommendation? {
        guard delta.addedCount > 0,
              let firstTitle = delta.firstAddedTitle
        else {
            return nil
        }

        let title = delta.addedCount == 1
            ? AppLocalization.format(
                "CatalogUpdate.Delta.Title.One",
                defaultValue: "1 neue Katalogfolge in %@",
                delta.name
            )
            : AppLocalization.format(
                "CatalogUpdate.Delta.Title.Many",
                defaultValue: "%lld neue Katalogfolgen in %@",
                Int64(delta.addedCount),
                delta.name
            )
        let versionText: String
        if let previousVersion = delta.previousVersion, let currentVersion = delta.currentVersion {
            versionText = AppLocalization.format(
                "CatalogUpdate.Delta.Version",
                defaultValue: "Version %@ -> %@",
                String(previousVersion),
                String(currentVersion)
            )
        } else {
            versionText = AppLocalization.format(
                "CatalogUpdate.Delta.EpisodeCountChange",
                defaultValue: "%lld -> %lld Folgen",
                Int64(delta.previousEntryCount),
                Int64(delta.currentEntryCount)
            )
        }
        let message = delta.addedCount == 1
            ? AppLocalization.format(
                "CatalogUpdate.Delta.Message.One",
                defaultValue: "%@ wurde ergänzt.",
                firstTitle
            )
            : AppLocalization.format(
                "CatalogUpdate.Delta.Message.Many",
                defaultValue: "%@ und weitere neue Folgen wurden ergänzt.",
                firstTitle
            )

        return CatalogUpdateBannerRecommendation(
            title: title,
            message: message,
            compactMessage: AppLocalization.format(
                "CatalogUpdate.Delta.Compact",
                defaultValue: "%@ - %lld Folgen",
                versionText,
                Int64(delta.currentEntryCount)
            ),
            missingEpisodeCount: delta.addedCount,
            universeCount: 1,
            firstUniverseName: delta.name,
            firstEpisodeTitle: firstTitle
        )
    }

    /// Folds every pending catalog delta into a single banner so that no
    /// catalog's update is shadowed by a larger one. A single delta keeps the
    /// detailed per-catalog wording.
    static func aggregatedEpisodeDeltas(_ deltas: [CatalogEpisodeDelta]) -> CatalogUpdateBannerRecommendation? {
        let relevant = deltas
            .filter { $0.addedCount > 0 }
            .sorted {
                if $0.addedCount != $1.addedCount {
                    return $0.addedCount > $1.addedCount
                }
                return $0.name.localizedCompare($1.name) == .orderedAscending
            }

        guard let top = relevant.first else { return nil }
        guard relevant.count > 1, let firstTitle = top.firstAddedTitle else {
            return episodeDelta(top)
        }

        let totalAdded = relevant.reduce(0) { $0 + $1.addedCount }
        return CatalogUpdateBannerRecommendation(
            title: AppLocalization.format(
                "CatalogUpdate.Aggregated.Title",
                defaultValue: "%lld neue Katalogfolgen in %lld Katalogen",
                Int64(totalAdded),
                Int64(relevant.count)
            ),
            message: AppLocalization.format(
                "CatalogUpdate.Aggregated.Message",
                defaultValue: "Neue Folgen in %@.",
                catalogList(relevant.map(\.name))
            ),
            compactMessage: AppLocalization.format(
                "CatalogUpdate.NewEpisodes.Compact.MultipleUniverses",
                defaultValue: "%lld Kataloge, u. a. %@",
                Int64(relevant.count),
                top.name
            ),
            missingEpisodeCount: totalAdded,
            universeCount: relevant.count,
            firstUniverseName: top.name,
            firstEpisodeTitle: firstTitle
        )
    }

    private static func catalogList(_ names: [String]) -> String {
        switch names.count {
        case 0:
            return ""
        case 1:
            return names[0]
        case 2:
            return AppLocalization.format(
                "CatalogUpdate.List.Two",
                defaultValue: "%@ und %@",
                names[0],
                names[1]
            )
        case 3:
            return AppLocalization.format(
                "CatalogUpdate.List.Three",
                defaultValue: "%@, %@ und %@",
                names[0],
                names[1],
                names[2]
            )
        default:
            return AppLocalization.format(
                "CatalogUpdate.List.Many",
                defaultValue: "%@, %@ und %lld weiteren Katalogen",
                names[0],
                names[1],
                Int64(names.count - 2)
            )
        }
    }

    #if DEBUG
    static let previewNewCatalogs = CatalogUpdateBannerRecommendation.newCatalogs(
        NewCatalogAvailability(sources: [
            ManagedCatalogSource(id: "bibi", name: "Bibi und Tina", url: URL(string: "https://example.com")!),
            ManagedCatalogSource(id: "tkkg", name: "TKKG", url: URL(string: "https://example.com")!)
        ])
    )

    static let previewNewEpisodes = CatalogUpdateBannerRecommendation(
        missingEpisodeCount: 5,
        universeCount: 1,
        firstUniverseName: "Die drei ???",
        firstEpisodeTitle: "und der Super-Papagei"
    )
    #endif
}

enum EpisodeListOrganizer {
    static func catalogUpdateBannerRecommendation(
        newCatalogAvailability: NewCatalogAvailability?,
        catalogEpisodeDeltas: [CatalogEpisodeDelta],
        activeCatalogIDs: Set<String>
    ) -> CatalogUpdateBannerRecommendation? {
        let activeIDs = Set(activeCatalogIDs.map(normalizedKey))

        if let newCatalogAvailability {
            let inactiveNewSources = newCatalogAvailability.sources.filter {
                !activeIDs.contains(normalizedKey($0.id))
            }
            if let recommendation = CatalogUpdateBannerRecommendation.newCatalogs(
                NewCatalogAvailability(sources: inactiveNewSources)
            ) {
                return recommendation
            }
        }

        let activeDeltas = catalogEpisodeDeltas
            .filter { activeIDs.contains(normalizedKey($0.catalogID)) }

        return CatalogUpdateBannerRecommendation.aggregatedEpisodeDeltas(activeDeltas)
    }

    static func catalogUpdateBannerRecommendation(
        catalogEntries: [CatalogEntry],
        libraryEpisodes: [Episode],
        activeCatalogIDs: Set<String>,
        managedSources: [ManagedCatalogSource]
    ) -> CatalogUpdateBannerRecommendation? {
        guard !libraryEpisodes.isEmpty, !activeCatalogIDs.isEmpty else { return nil }

        let activeNames = Set(
            managedSources
                .filter { activeCatalogIDs.contains($0.id) }
                .map { normalizedKey($0.name) }
        )
        guard !activeNames.isEmpty else { return nil }

        let activeEntries = catalogEntries.filter { entry in
            guard let collectionName = entry.collectionName else { return false }
            return activeNames.contains(normalizedKey(collectionName))
        }
        let missingEntries = SmartListDefinition.missingCatalogEntries(
            catalogEntries: activeEntries,
            libraryEpisodes: libraryEpisodes
        )
        guard let first = missingEntries.first else { return nil }

        let universeCount = Set(missingEntries.map { normalizedKey($0.universeName) }).count
        return CatalogUpdateBannerRecommendation(
            missingEpisodeCount: missingEntries.count,
            universeCount: universeCount,
            firstUniverseName: first.universeName,
            firstEpisodeTitle: first.entry.title
        )
    }

    static func filteredAndSortedEpisodes(
        episodes: [Episode],
        searchText: String,
        filterUniverse: Universe?,
        filterMood: Mood?,
        statusFilter: EpisodeStatusFilter,
        sortOrder: EpisodeSortOrder
    ) -> [Episode] {
        var result = episodes
        result = applySearch(searchText, to: result)
        result = applyUniverseFilter(filterUniverse, to: result)
        result = applyMoodFilter(filterMood, to: result)
        result = applyStatusFilter(statusFilter, to: result)
        sort(&result, by: sortOrder)
        return result
    }

    static func groups(
        for episodes: [Episode],
        sortOrder: EpisodeSortOrder,
        filterUniverse: Universe?,
        universeCount: Int,
        catalogTotalsByUniverse: [String: Int] = [:],
        preferCatalogTotals: Bool = true
    ) -> [EpisodeListGroup] {
        guard shouldGroup(episodes: episodes, sortOrder: sortOrder, filterUniverse: filterUniverse, universeCount: universeCount) else {
            return []
        }

        // Multi-Universe-Gruppierung: Sonderfolgen landen natürlich bei ihrem Universe.
        if let multiUniverseGroups = multiUniverseNumberGroupsIfNeeded(
            for: episodes,
            sortOrder: sortOrder,
            filterUniverse: filterUniverse,
            universeCount: universeCount,
            catalogTotalsByUniverse: catalogTotalsByUniverse,
            preferCatalogTotals: preferCatalogTotals
        ) {
            return multiUniverseGroups
        }

        // Single-Universe-Gruppierung: Nummernbänder brauchen Spezialbehandlung
        // (Sonderfolge Nr. 0 gehört nicht ins Band „1-25"), alle anderen Sortierungen
        // (Titel, Rating, Jahr, Gehört/Offen) gruppieren Sonderfolgen natürlich mit.
        switch sortOrder {
        case .recentlyPlayed:
            return listenedStateGroups(for: episodes)
        case .number:
            return numberRangeGroupsWithSpecials(for: episodes)
        case .title:
            return titleGroups(for: episodes)
        case .rating:
            return ratingGroups(for: episodes)
        case .releaseYear:
            return releaseYearGroups(for: episodes)
        }
    }

    private static func specialSort(_ a: Episode, _ b: Episode) -> Bool {
        if a.episodeNumber > 0, b.episodeNumber > 0, a.episodeNumber != b.episodeNumber {
            return a.episodeNumber < b.episodeNumber
        }
        if a.releaseYear != b.releaseYear {
            return a.releaseYear < b.releaseYear
        }
        return a.title.localizedCompare(b.title) == .orderedAscending
    }

    private static func applySearch(_ searchText: String, to episodes: [Episode]) -> [Episode] {
        guard !searchText.isEmpty else { return episodes }
        return episodes.filter { episode in
            episode.title.localizedCaseInsensitiveContains(searchText)
            || (!episode.isSpecial && String(episode.episodeNumber).contains(searchText))
        }
    }

    private static func applyUniverseFilter(_ universe: Universe?, to episodes: [Episode]) -> [Episode] {
        guard let universe else { return episodes }
        return episodes.filter { $0.universe == universe }
    }

    private static func applyMoodFilter(_ mood: Mood?, to episodes: [Episode]) -> [Episode] {
        guard let mood else { return episodes }
        return episodes.filter { episode in
            episode.moods.contains(where: { $0.matches(mood) })
        }
    }

    private static func applyStatusFilter(_ statusFilter: EpisodeStatusFilter, to episodes: [Episode]) -> [Episode] {
        switch statusFilter {
        case .all:
            return episodes
        case .open:
            return episodes.filter { !$0.isListened }
        case .listened:
            return episodes.filter(\.isListened)
        case .favorites:
            return episodes.filter(\.isFavorite)
        case .rated:
            return episodes.filter { $0.rating != nil }
        case .noted:
            return episodes.filter { episode in
                guard let note = episode.personalNote?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                    return false
                }
                return !note.isEmpty
            }
        case .specials:
            return episodes.filter(\.isSpecial)
        }
    }

    static func shouldGroup(
        episodes: [Episode],
        sortOrder: EpisodeSortOrder,
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

    private static func sort(_ episodes: inout [Episode], by sortOrder: EpisodeSortOrder) {
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

        // Sonderfolgen ans Ende verschieben, Reihenfolge innerhalb der jeweiligen
        // Gruppe bleibt erhalten (filter ist ordnungserhaltend).
        let specials = episodes.filter(\.isSpecial)
        if !specials.isEmpty {
            episodes = episodes.filter { !$0.isSpecial } + specials
        }
    }

    private static func multiUniverseNumberGroupsIfNeeded(
        for episodes: [Episode],
        sortOrder: EpisodeSortOrder,
        filterUniverse: Universe?,
        universeCount: Int,
        catalogTotalsByUniverse: [String: Int],
        preferCatalogTotals: Bool
    ) -> [EpisodeListGroup]? {
        guard sortOrder == .number, filterUniverse == nil, universeCount > 1 else {
            return nil
        }

        return universeGroups(
            for: episodes,
            catalogTotalsByUniverse: catalogTotalsByUniverse,
            preferCatalogTotals: preferCatalogTotals
        )
    }

    private static func universeGroups(
        for episodes: [Episode],
        catalogTotalsByUniverse: [String: Int],
        preferCatalogTotals: Bool
    ) -> [EpisodeListGroup] {
        let grouped = Dictionary(grouping: episodes) { episode in
            AppLocalization.displayName(forUniverseName: episode.universe?.name)
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

    /// Nummernbänder nur für reguläre Folgen; Sonderfolgen bekommen eine eigene
    /// Sektion am Ende (in der Single-Universe-Ansicht). In der Multi-Universe-
    /// Ansicht landen Sonderfolgen direkt bei ihrem Universe (via universeGroups).
    private static func numberRangeGroupsWithSpecials(for episodes: [Episode]) -> [EpisodeListGroup] {
        let regulars = episodes.filter { !$0.isSpecial }
        let specials = episodes.filter(\.isSpecial)

        let grouped = Dictionary(grouping: regulars) { episode in
            ((max(episode.episodeNumber, 1) - 1) / 25) * 25 + 1
        }
        var groups = grouped.keys.sorted().map { start in
            let end = start + 24
            return EpisodeListGroup(
                id: "number:\(start)",
                title: "\(start)-\(end)",
                episodes: grouped[start] ?? [],
                progressTotalOverride: nil
            )
        }

        if !specials.isEmpty {
            groups.append(EpisodeListGroup(
                id: "special",
                title: String(localized: "EpisodeList.SpecialSection", defaultValue: "Sonderfolgen"),
                episodes: specials.sorted(by: specialSort),
                progressTotalOverride: nil
            ))
        }

        return groups
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

    nonisolated private static func normalizedKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
