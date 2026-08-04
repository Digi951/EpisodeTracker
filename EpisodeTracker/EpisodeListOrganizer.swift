import Foundation

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

/// Kennzahlen für die Bibliotheks-Übersichtskarte. Wird von der iPhone-Liste
/// (`LibrarySnapshotView`) und der iPad-Sidebar (`CompactLibrarySnapshotView`)
/// geteilt; die beiden Views unterscheiden sich nur im Layout.
struct EpisodeLibrarySnapshot {
    let episodeCount: Int
    let listenedCount: Int
    let openCount: Int
    let totalListens: Int

    init(episodes: [Episode]) {
        episodeCount = episodes.count
        listenedCount = episodes.filter(\.isListened).count
        openCount = episodeCount - listenedCount
        totalListens = episodes.reduce(0) { $0 + $1.listenCount }
    }
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

            let activeNewSources = newCatalogAvailability.sources.filter {
                activeIDs.contains(normalizedKey($0.id))
            }
            if let recommendation = CatalogUpdateBannerRecommendation.newActiveCatalogs(
                NewCatalogAvailability(sources: activeNewSources)
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

    // MARK: - Abgeleiteter Bibliothekszustand
    //
    // Diese Funktionen sind die eine Quelle der Wahrheit für iPhone-Liste
    // (`EpisodeListView`) und iPad-Sidebar (`IPadEpisodeListView`). Vorher hatte
    // jede View ihre eigene Kopie, die auseinandergelaufen ist — siehe
    // `catalogTotalsByUniverse`.

    static func filteredAndSortedEpisodes(
        episodes: [Episode],
        controls: EpisodeListControlsState
    ) -> [Episode] {
        filteredAndSortedEpisodes(
            episodes: episodes,
            searchText: controls.searchText,
            filterUniverse: controls.filterUniverse,
            filterMood: controls.filterMood,
            statusFilter: controls.statusFilter,
            sortOrder: controls.sortOrder
        )
    }

    static func groups(
        for episodes: [Episode],
        controls: EpisodeListControlsState,
        universeCount: Int,
        catalogTotalsByUniverse: [String: Int],
        preferCatalogTotals: Bool
    ) -> [EpisodeListGroup] {
        groups(
            for: episodes,
            sortOrder: controls.sortOrder,
            filterUniverse: controls.filterUniverse,
            universeCount: universeCount,
            catalogTotalsByUniverse: catalogTotalsByUniverse,
            preferCatalogTotals: preferCatalogTotals
        )
    }

    /// Anzahl bekannter Katalogfolgen je Sammlung, Basis für den Fortschrittsbalken.
    ///
    /// Sonderfolgen haben bewusst keine Nummer (`CatalogEntry.number` ist `Int?`)
    /// und gehören nicht ins Nummernband — `compactMap` hält sie draußen. Die
    /// frühere iPad-Kopie benutzte hier `map` und erzeugte damit ein `Set<Int?>`,
    /// in dem alle Sonderfolgen zu einem `nil` kollabierten und den Gesamtwert
    /// jeder Sammlung mit Sonderfolgen um genau 1 zu hoch machten.
    static func catalogTotalsByUniverse(entries: [CatalogEntry]) -> [String: Int] {
        Dictionary(
            uniqueKeysWithValues: Dictionary(grouping: entries) {
                AppLocalization.displayName(forUniverseName: $0.collectionName).lowercased()
            }.map { key, entries in
                (key, Set(entries.compactMap(\.number)).count)
            }
        )
    }

    /// Sammlungen, die unter den übrigen aktiven Filtern noch Treffer liefern.
    /// Der Sammlungsfilter selbst bleibt dabei außen vor, damit die aktuell
    /// gewählte Sammlung nicht aus ihrer eigenen Auswahlliste verschwindet.
    static func availableUniverseFilters(
        episodes: [Episode],
        universes: [Universe],
        controls: EpisodeListControlsState
    ) -> [Universe] {
        let filterContextEpisodes = filteredAndSortedEpisodes(
            episodes: episodes,
            searchText: controls.searchText,
            filterUniverse: nil,
            filterMood: controls.filterMood,
            statusFilter: controls.statusFilter,
            sortOrder: controls.sortOrder
        )
        let visibleUniverseIDs = Set(filterContextEpisodes.compactMap { $0.universe?.id })
        return universes.filter { visibleUniverseIDs.contains($0.id) }
    }

    static func availableMoodFilters(episodes: [Episode], moods: [Mood]) -> [Mood] {
        moods.filter { mood in
            episodes.contains { episode in
                episode.moods.contains { $0.matches(mood) }
            }
        }
    }

    static func anyEpisodeHasCover(episodes: [Episode]) -> Bool {
        episodes.contains { $0.coverImageName?.isEmpty == false }
    }

    // MARK: - Filtern, Sortieren, Gruppieren

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
            let isSingleUniverse = filterUniverse != nil || universeCount <= 1
            return isSingleUniverse ? [] : titleGroups(for: episodes)
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
            return episodes.filter(\.showsSpecialBadge)
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
        // Gruppe bleibt erhalten (filter ist ordnungserhaltend). In einem
        // Anthologie-Katalog gibt es keine Ausnahme-Sonderfolgen, die einen
        // eigenen Platz am Ende verdienen — dort bleibt die Sortierung unverändert.
        let specials = episodes.filter(\.showsSpecialBadge)
        if !specials.isEmpty {
            episodes = episodes.filter { !$0.showsSpecialBadge } + specials
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
        let regulars = episodes.filter { !$0.showsSpecialBadge }
        let specials = episodes.filter(\.showsSpecialBadge)

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
                episodes: specials.sorted { specialSort($0, $1) },
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
