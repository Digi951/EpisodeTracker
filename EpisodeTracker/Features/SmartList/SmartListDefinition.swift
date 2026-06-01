import Foundation

enum EpisodeFilter: String, CaseIterable, Identifiable {
    case unlistened
    case listened
    case favorites
    case all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unlistened: String(localized: "EpisodeFilter.Unlistened", defaultValue: "Ungehört")
        case .listened: String(localized: "EpisodeFilter.Listened", defaultValue: "Gehört")
        case .favorites: String(localized: "EpisodeFilter.Favorites", defaultValue: "Favoriten")
        case .all: String(localized: "EpisodeFilter.All", defaultValue: "Alle")
        }
    }

    var iconName: String? {
        switch self {
        case .favorites: "heart.fill"
        default: nil
        }
    }

    func apply(to episodes: [Episode]) -> [Episode] {
        switch self {
        case .unlistened: episodes.filter { !$0.isListened }
        case .listened: episodes.filter(\.isListened)
        case .favorites: episodes.filter(\.isFavorite)
        case .all: episodes
        }
    }
}

enum SmartListDefinition: String, CaseIterable, Identifiable, Hashable {
    case laterListen
    case favorites
    case continueListening
    case nextFromCatalog
    case longPaused
    case skipped
    case topRated
    case random
    case randomByMood

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .laterListen: "bookmark.fill"
        case .favorites: "heart.fill"
        case .continueListening: "play.circle.fill"
        case .nextFromCatalog: "text.badge.plus"
        case .longPaused: "clock.arrow.circlepath"
        case .skipped: "arrow.right.to.line"
        case .topRated: "star.fill"
        case .random: "dice.fill"
        case .randomByMood: "theatermasks.fill"
        }
    }

    var accentColor: String {
        switch self {
        case .laterListen: "cyan"
        case .favorites: "red"
        case .continueListening: "blue"
        case .nextFromCatalog: "green"
        case .longPaused: "orange"
        case .skipped: "red"
        case .topRated: "yellow"
        case .random: "purple"
        case .randomByMood: "pink"
        }
    }

    var displayName: String {
        switch self {
        case .laterListen: String(localized: "SmartList.LaterListen.Title", defaultValue: "Später hören")
        case .favorites: String(localized: "SmartList.Favorites.Title", defaultValue: "Favoriten")
        case .continueListening: String(localized: "SmartList.ContinueListening.Title", defaultValue: "Fortsetzen")
        case .nextFromCatalog: String(localized: "SmartList.NextFromCatalog.Title", defaultValue: "Nächste aus dem Katalog")
        case .longPaused: String(localized: "SmartList.LongPaused.Title", defaultValue: "Lange nicht gehört")
        case .skipped: String(localized: "SmartList.Skipped.Title", defaultValue: "Übersprungen")
        case .topRated: String(localized: "SmartList.TopRated.Title", defaultValue: "Top bewertet")
        case .random: String(localized: "SmartList.Random.Title", defaultValue: "Zufällig")
        case .randomByMood: String(localized: "SmartList.RandomByMood.Title", defaultValue: "Zufällig nach Stimmung")
        }
    }

    var emptyStateMessage: String {
        switch self {
        case .laterListen: String(localized: "SmartList.LaterListen.Empty", defaultValue: "Keine Folgen auf der Merkliste")
        case .favorites: String(localized: "SmartList.Favorites.Empty", defaultValue: "Noch keine Favoriten markiert")
        case .continueListening: String(localized: "SmartList.ContinueListening.Empty", defaultValue: "Du bist überall auf dem neuesten Stand")
        case .nextFromCatalog: String(localized: "SmartList.NextFromCatalog.Empty", defaultValue: "Keine weiteren Katalog-Folgen verfügbar")
        case .longPaused: String(localized: "SmartList.LongPaused.Empty", defaultValue: "Keine lang pausierten Serien")
        case .skipped: String(localized: "SmartList.Skipped.Empty", defaultValue: "Keine übersprungenen Folgen")
        case .topRated: String(localized: "SmartList.TopRated.Empty", defaultValue: "Keine bewerteten ungehörten Folgen")
        case .random: String(localized: "SmartList.Random.Empty", defaultValue: "Alles gehört!")
        case .randomByMood: String(localized: "SmartList.RandomByMood.Empty", defaultValue: "Keine Stimmungen in deiner Bibliothek")
        }
    }

    var infoText: String {
        switch self {
        case .laterListen:
            String(localized: "SmartList.LaterListen.Info", defaultValue: "Folgen, die du mit dem Lesezeichen markiert hast und noch nicht gehört wurden. Sobald du eine Folge als gehört markierst, wird das Lesezeichen automatisch entfernt.")
        case .favorites:
            String(localized: "SmartList.Favorites.Info", defaultValue: "Alle Folgen, die du als Favorit markiert hast — egal ob gehört oder nicht. Deine persönliche Bestenliste.")
        case .continueListening:
            String(localized: "SmartList.ContinueListening.Info", defaultValue: "Zeigt pro Serie die nächste ungehörte Folge nach der höchsten gehörten. Sortiert nach letzter Aktivität.")
        case .nextFromCatalog:
            String(localized: "SmartList.NextFromCatalog.Info", defaultValue: "Pro Serie die nächste Folge aus dem Katalog, die du noch nicht in deiner Bibliothek hast. Ideal um neue Folgen zu entdecken.")
        case .longPaused:
            String(localized: "SmartList.LongPaused.Info", defaultValue: "Serien, bei denen du seit über 30 Tagen keine Folge mehr gehört hast und noch offene Folgen übrig sind.")
        case .skipped:
            String(localized: "SmartList.Skipped.Info", defaultValue: "Folgen mit niedrigerer Nummer als eine bereits gehörte — also Lücken in deiner Hörhistorie.")
        case .topRated:
            String(localized: "SmartList.TopRated.Info", defaultValue: "Ungehörte Folgen, die bereits eine Bewertung haben. Sortiert nach Sternzahl.")
        case .random:
            String(localized: "SmartList.Random.Info", defaultValue: "Zufällige Auswahl aus deiner Bibliothek. Wähle oben, ob du aus ungehörten, gehörten oder allen Folgen würfeln möchtest.")
        case .randomByMood:
            String(localized: "SmartList.RandomByMood.Info", defaultValue: "Wähle eine Stimmung und erhalte eine zufällige Auswahl passender Folgen. Danach kannst du auf ungehörte, gehörte oder alle Folgen eingrenzen.")
        }
    }

    var isRandomList: Bool {
        self == .random || self == .randomByMood
    }

    static let longPauseDays: Int = 30

    // MARK: - Query Dispatch

    var needsCatalog: Bool {
        self == .nextFromCatalog
    }

    func episodes(from allEpisodes: [Episode], referenceDate: Date = .now) -> [Episode] {
        switch self {
        case .laterListen:
            return Self.laterListenEpisodes(from: allEpisodes)
        case .favorites:
            return Self.favoriteEpisodes(from: allEpisodes)
        case .continueListening:
            return Self.continuationEpisodes(from: allEpisodes)
        case .nextFromCatalog:
            return []
        case .longPaused:
            return Self.longPauseEpisodes(from: allEpisodes, referenceDate: referenceDate)
        case .skipped:
            return Self.skippedEpisodes(from: allEpisodes)
        case .topRated:
            return Self.topRatedEpisodes(from: allEpisodes)
        case .random:
            return Self.randomEpisodes(from: allEpisodes)
        case .randomByMood:
            return []
        }
    }

    // MARK: - Query Logic

    private static func visible(_ episodes: [Episode]) -> [Episode] {
        episodes.filter { !$0.isHidden }
    }

    static func favoriteEpisodes(from episodes: [Episode]) -> [Episode] {
        visible(episodes)
            .filter(\.isFavorite)
            .sorted {
                let name0 = $0.universe?.name ?? ""
                let name1 = $1.universe?.name ?? ""
                if name0 != name1 {
                    return name0.localizedCompare(name1) == .orderedAscending
                }
                return $0.episodeNumber < $1.episodeNumber
            }
    }

    static func laterListenEpisodes(from episodes: [Episode]) -> [Episode] {
        visible(episodes)
            .filter { $0.isBookmarked && !$0.isListened }
            .sorted {
                let name0 = $0.universe?.name ?? ""
                let name1 = $1.universe?.name ?? ""
                if name0 != name1 {
                    return name0.localizedCompare(name1) == .orderedAscending
                }
                return $0.episodeNumber < $1.episodeNumber
            }
    }

    static func continuationEpisodes(from episodes: [Episode]) -> [Episode] {
        // Nummern-basierte Reihenfolge: nur reguläre Folgen.
        let withUniverse = visible(episodes).filter { $0.universe != nil && !$0.isSpecial }
        let grouped = Dictionary(grouping: withUniverse) { $0.universe! }

        var results: [(episode: Episode, lastActivity: Date)] = []

        for (_, universeEpisodes) in grouped {
            let listened = universeEpisodes.filter(\.isListened)
            guard !listened.isEmpty else { continue }

            let maxListenedNumber = listened.map(\.episodeNumber).max()!

            let nextUnlistened = universeEpisodes
                .filter { $0.episodeNumber > maxListenedNumber && !$0.isListened }
                .min(by: { $0.episodeNumber < $1.episodeNumber })

            if let next = nextUnlistened {
                let lastActivity = listened.compactMap(\.lastListenedAt).max() ?? .distantPast
                results.append((next, lastActivity))
            }
        }

        results.sort { $0.lastActivity > $1.lastActivity }
        return results.map(\.episode)
    }

    static func skippedEpisodes(from episodes: [Episode]) -> [Episode] {
        // Nummern-basierte Reihenfolge: nur reguläre Folgen.
        let withUniverse = visible(episodes).filter { $0.universe != nil && !$0.isSpecial }
        let grouped = Dictionary(grouping: withUniverse) { $0.universe! }

        var results: [(universeName: String, episode: Episode)] = []

        for (_, universeEpisodes) in grouped {
            let listened = universeEpisodes.filter(\.isListened)
            guard !listened.isEmpty else { continue }

            let maxListenedNumber = listened.map(\.episodeNumber).max()!

            let skipped = universeEpisodes.filter {
                $0.episodeNumber < maxListenedNumber && !$0.isListened
            }

            for episode in skipped {
                let name = episode.universe?.name ?? ""
                results.append((name, episode))
            }
        }

        results.sort {
            if $0.universeName != $1.universeName {
                return $0.universeName.localizedCompare($1.universeName) == .orderedAscending
            }
            return $0.episode.episodeNumber < $1.episode.episodeNumber
        }

        return results.map(\.episode)
    }

    static func longPauseEpisodes(from episodes: [Episode], referenceDate: Date = .now) -> [Episode] {
        // Nummern-basierte Reihenfolge: nur reguläre Folgen.
        let withUniverse = visible(episodes).filter { $0.universe != nil && !$0.isSpecial }
        let grouped = Dictionary(grouping: withUniverse) { $0.universe! }

        guard let thresholdDate = Calendar.current.date(
            byAdding: .day, value: -longPauseDays, to: referenceDate
        ) else {
            return []
        }

        var results: [(episode: Episode, lastActivity: Date)] = []

        for (_, universeEpisodes) in grouped {
            let listened = universeEpisodes.filter(\.isListened)
            guard !listened.isEmpty else { continue }

            let hasUnlistened = universeEpisodes.contains { !$0.isListened }
            guard hasUnlistened else { continue }

            let lastActivity = listened.compactMap(\.lastListenedAt).max() ?? .distantPast
            guard lastActivity < thresholdDate else { continue }

            let maxListenedNumber = listened.map(\.episodeNumber).max()!
            let nextUnlistened = universeEpisodes
                .filter { $0.episodeNumber > maxListenedNumber && !$0.isListened }
                .min(by: { $0.episodeNumber < $1.episodeNumber })

            if let next = nextUnlistened {
                results.append((next, lastActivity))
            }
        }

        results.sort { $0.lastActivity < $1.lastActivity }
        return results.map(\.episode)
    }

    static func topRatedEpisodes(from episodes: [Episode]) -> [Episode] {
        visible(episodes)
            .filter { !$0.isListened && $0.rating != nil }
            .sorted {
                let r0 = $0.rating ?? 0
                let r1 = $1.rating ?? 0
                if r0 != r1 {
                    return r0 > r1
                }
                return $0.episodeNumber < $1.episodeNumber
            }
    }

    static func randomEpisodes(from episodes: [Episode], filter: EpisodeFilter = .unlistened, count: Int = 10, maxPerUniverse: Int = 3) -> [Episode] {
        let filtered = filter.apply(to: visible(episodes))
        let grouped = Dictionary(grouping: filtered) { $0.universe?.name ?? "" }
        var picked: [Episode] = []
        for (_, group) in grouped {
            picked.append(contentsOf: group.shuffled().prefix(maxPerUniverse))
        }
        return Array(picked.shuffled().prefix(count))
    }

    static func episodesForMood(_ mood: Mood, from episodes: [Episode], filter: EpisodeFilter = .unlistened, count: Int = 10) -> [Episode] {
        let filtered = filter.apply(to: visible(episodes))
        let matching = filtered.filter { episode in
            episode.moods.contains(where: { $0.matches(mood) })
        }
        return Array(matching.shuffled().prefix(count))
    }

    static func availableMoods(from episodes: [Episode], filter: EpisodeFilter = .unlistened, allMoods: [Mood]) -> [(mood: Mood, count: Int)] {
        let filtered = filter.apply(to: visible(episodes))
        var results: [(mood: Mood, count: Int)] = []

        for mood in canonicalMoods(from: allMoods) {
            let count = filtered.filter { episode in
                episode.moods.contains(where: { $0.matches(mood) })
            }.count
            if count > 0 {
                results.append((mood, count))
            }
        }

        results.sort { $0.mood.name.localizedCompare($1.mood.name) == .orderedAscending }
        return results
    }

    private static func canonicalMoods(from moods: [Mood]) -> [Mood] {
        Dictionary(grouping: moods) { $0.normalizedName }
            .values
            .compactMap { duplicates in
                duplicates.sorted { Mood.isPreferredAsCanonical($0, over: $1) }.first
            }
    }

    // MARK: - Catalog Queries

    static func nextFromCatalog(catalogEntries: [CatalogEntry], libraryEpisodes: [Episode], perUniverse: Int = 3) -> [(universeName: String, entry: CatalogEntry)] {
        missingCatalogEntries(catalogEntries: catalogEntries, libraryEpisodes: libraryEpisodes)
            .groupedAndLimited(perUniverse: perUniverse)
    }

    static func missingCatalogEntries(catalogEntries: [CatalogEntry], libraryEpisodes: [Episode]) -> [(universeName: String, entry: CatalogEntry)] {
        CatalogLibraryMatcher.missingEntries(catalogEntries: catalogEntries, libraryEpisodes: libraryEpisodes)
    }

    static func catalogTeaserText(for entry: CatalogEntry) -> String {
        let universeName = AppLocalization.displayName(forUniverseName: entry.collectionName)
        return AppLocalization.format(
            "SmartList.CatalogTeaser",
            defaultValue: "%@: Folge %d - %@",
            universeName,
            entry.number ?? 0,
            entry.title
        )
    }

    // MARK: - Teaser

    static func teaserText(for episode: Episode) -> String {
        let universeName = AppLocalization.displayName(forUniverseName: episode.universe?.name)
        return AppLocalization.format(
            "SmartList.EpisodeTeaser",
            defaultValue: "%@: Folge %d - %@",
            universeName,
            episode.episodeNumber,
            episode.title
        )
    }
}

private extension Array where Element == (universeName: String, entry: CatalogEntry) {
    func groupedAndLimited(perUniverse: Int) -> [(universeName: String, entry: CatalogEntry)] {
        guard perUniverse > 0 else { return [] }

        let grouped = Dictionary(grouping: self, by: \.universeName)
        var results: [(universeName: String, entry: CatalogEntry)] = []

        for universeName in grouped.keys.sorted(by: { $0.localizedCompare($1) == .orderedAscending }) {
            let entries = (grouped[universeName] ?? [])
                .sorted(by: { ($0.entry.number ?? 0) < ($1.entry.number ?? 0) })
                .prefix(perUniverse)
            results.append(contentsOf: entries)
        }

        return results
    }
}
