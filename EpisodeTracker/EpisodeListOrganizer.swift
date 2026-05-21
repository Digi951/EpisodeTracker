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
    case rated = "Bewertet"
    case noted = "Mit Notiz"
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
        pendingEpisodes.count == 1 ? "Folge löschen?" : "\(pendingEpisodes.count) Folgen löschen?"
    }

    func message(usesCloudSync: Bool) -> String {
        let syncHint = usesCloudSync
            ? "Die Folgen werden auf allen synchronisierten Geräten entfernt."
            : "Die Folgen werden nur auf diesem Gerät entfernt."
        let catalogHint = "Katalogeinträge bleiben erhalten und können erneut übernommen werden."

        if pendingEpisodes.count == 1, let episode = pendingEpisodes.first {
            return "„\(episode.title)“ wird dauerhaft gelöscht. \(syncHint) \(catalogHint)"
        }

        return "\(syncHint) \(catalogHint)"
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
        "\(listenedCount) von \(progressTotal) gehört · \(openCount) offen"
    }
}

struct CatalogUpdateBannerRecommendation: Equatable {
    let missingEpisodeCount: Int
    let universeCount: Int
    let firstUniverseName: String
    let firstEpisodeTitle: String
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
        titleText = missingEpisodeCount == 1 ? "1 neue Katalogfolge" : "\(missingEpisodeCount) neue Katalogfolgen"
        if universeCount == 1 {
            messageText = "\(firstUniverseName): \(firstEpisodeTitle) wartet auf deine Bibliothek."
            compactMessageText = "\(firstUniverseName): \(firstEpisodeTitle)"
        } else {
            messageText = "Aktive Kataloge haben neue Folgen, unter anderem \(firstEpisodeTitle) in \(firstUniverseName)."
            compactMessageText = "\(universeCount) Kataloge, u. a. \(firstUniverseName)"
        }
    }

    private init(
        title: String,
        message: String,
        compactMessage: String,
        missingEpisodeCount: Int,
        universeCount: Int,
        firstUniverseName: String,
        firstEpisodeTitle: String
    ) {
        self.missingEpisodeCount = missingEpisodeCount
        self.universeCount = universeCount
        self.firstUniverseName = firstUniverseName
        self.firstEpisodeTitle = firstEpisodeTitle
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

    static func newCatalogs(_ availability: NewCatalogAvailability) -> CatalogUpdateBannerRecommendation? {
        guard let firstName = availability.firstName else { return nil }
        let title = availability.count == 1
            ? "1 neuer Katalog verfügbar"
            : "\(availability.count) neue Kataloge verfügbar"
        let message = availability.count == 1
            ? "\(firstName) kann in den Katalogen aktiviert werden."
            : "\(firstName) und weitere Kataloge können aktiviert werden."
        return CatalogUpdateBannerRecommendation(
            title: title,
            message: message,
            compactMessage: availability.count == 1 ? firstName : "\(availability.count) neue Kataloge",
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
            ? "1 neue Katalogfolge in \(delta.name)"
            : "\(delta.addedCount) neue Katalogfolgen in \(delta.name)"
        let versionText: String
        if let previousVersion = delta.previousVersion, let currentVersion = delta.currentVersion {
            versionText = "Version \(previousVersion) -> \(currentVersion)"
        } else {
            versionText = "\(delta.previousEntryCount) -> \(delta.currentEntryCount) Folgen"
        }
        let message = delta.addedCount == 1
            ? "\(firstTitle) wurde ergänzt."
            : "\(firstTitle) und weitere neue Folgen wurden ergänzt."

        return CatalogUpdateBannerRecommendation(
            title: title,
            message: message,
            compactMessage: "\(versionText) - \(delta.currentEntryCount) Folgen",
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
            title: "\(totalAdded) neue Katalogfolgen in \(relevant.count) Katalogen",
            message: "Neue Folgen in \(catalogList(relevant.map(\.name))).",
            compactMessage: "\(relevant.count) Kataloge, u. a. \(top.name)",
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
            return "\(names[0]) und \(names[1])"
        case 3:
            return "\(names[0]), \(names[1]) und \(names[2])"
        default:
            return "\(names[0]), \(names[1]) und \(names.count - 2) weiteren Katalogen"
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

        switch sortOrder {
        case .recentlyPlayed:
            return listenedStateGroups(for: episodes)
        case .number:
            return numberRangeGroups(for: episodes)
        case .title:
            return titleGroups(for: episodes)
        case .rating:
            return ratingGroups(for: episodes)
        case .releaseYear:
            return releaseYearGroups(for: episodes)
        }
    }

    private static func applySearch(_ searchText: String, to episodes: [Episode]) -> [Episode] {
        guard !searchText.isEmpty else { return episodes }
        return episodes.filter { episode in
            episode.title.localizedCaseInsensitiveContains(searchText)
            || String(episode.episodeNumber).contains(searchText)
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
        case .rated:
            return episodes.filter { $0.rating != nil }
        case .noted:
            return episodes.filter { episode in
                guard let note = episode.personalNote?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                    return false
                }
                return !note.isEmpty
            }
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

    nonisolated private static func normalizedKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
