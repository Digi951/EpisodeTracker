import Foundation

enum EpisodeFilter: String, CaseIterable, Identifiable {
    case unlistened
    case listened
    case all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .unlistened: "Ungehört"
        case .listened: "Gehört"
        case .all: "Alle"
        }
    }

    func apply(to episodes: [Episode]) -> [Episode] {
        switch self {
        case .unlistened: episodes.filter { !$0.isListened }
        case .listened: episodes.filter(\.isListened)
        case .all: episodes
        }
    }
}

enum SmartListDefinition: String, CaseIterable, Identifiable, Hashable {
    case fortsetzen
    case langeNichtGehoert
    case uebersprungen
    case topBewertet
    case zufaellig
    case zufaelligNachStimmung

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .fortsetzen: "▶️"
        case .langeNichtGehoert: "⏸️"
        case .uebersprungen: "⏭️"
        case .topBewertet: "⭐"
        case .zufaellig: "🎲"
        case .zufaelligNachStimmung: "😱"
        }
    }

    var displayName: String {
        switch self {
        case .fortsetzen: "Fortsetzen"
        case .langeNichtGehoert: "Lange nicht gehört"
        case .uebersprungen: "Übersprungen"
        case .topBewertet: "Top bewertet"
        case .zufaellig: "Zufällig"
        case .zufaelligNachStimmung: "Zufällig nach Stimmung"
        }
    }

    var emptyStateMessage: String {
        switch self {
        case .fortsetzen: "Du bist überall auf dem neuesten Stand"
        case .langeNichtGehoert: "Keine lang pausierten Serien"
        case .uebersprungen: "Keine übersprungenen Folgen"
        case .topBewertet: "Keine bewerteten ungehörten Folgen"
        case .zufaellig: "Alles gehört!"
        case .zufaelligNachStimmung: "Keine Stimmungen mit offenen Folgen"
        }
    }

    var infoText: String {
        switch self {
        case .fortsetzen:
            "Zeigt pro Serie die nächste ungehörte Folge nach der höchsten gehörten. Sortiert nach letzter Aktivität."
        case .langeNichtGehoert:
            "Serien, bei denen du seit über 30 Tagen keine Folge mehr gehört hast und noch offene Folgen übrig sind."
        case .uebersprungen:
            "Folgen mit niedrigerer Nummer als eine bereits gehörte — also Lücken in deiner Hörhistorie."
        case .topBewertet:
            "Ungehörte Folgen, die bereits eine Bewertung haben. Sortiert nach Sternzahl."
        case .zufaellig:
            "Zufällige Auswahl aus deiner Bibliothek. Wähle oben, ob du aus ungehörten, gehörten oder allen Folgen würfeln möchtest."
        case .zufaelligNachStimmung:
            "Wähle eine Stimmung und erhalte eine zufällige Auswahl passender Folgen."
        }
    }

    var isRandomList: Bool {
        self == .zufaellig || self == .zufaelligNachStimmung
    }

    static let longPauseDays: Int = 30

    // MARK: - Query Dispatch

    func episodes(from allEpisodes: [Episode], referenceDate: Date = .now) -> [Episode] {
        switch self {
        case .fortsetzen:
            return Self.continuationEpisodes(from: allEpisodes)
        case .langeNichtGehoert:
            return Self.longPauseEpisodes(from: allEpisodes, referenceDate: referenceDate)
        case .uebersprungen:
            return Self.skippedEpisodes(from: allEpisodes)
        case .topBewertet:
            return Self.topRatedEpisodes(from: allEpisodes)
        case .zufaellig:
            return Self.randomEpisodes(from: allEpisodes)
        case .zufaelligNachStimmung:
            return []
        }
    }

    // MARK: - Query Logic (stubs — implemented in Tasks 2-4)

    static func continuationEpisodes(from episodes: [Episode]) -> [Episode] {
        let withUniverse = episodes.filter { $0.universe != nil }
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
        let withUniverse = episodes.filter { $0.universe != nil }
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
        let withUniverse = episodes.filter { $0.universe != nil }
        let grouped = Dictionary(grouping: withUniverse) { $0.universe! }

        let thresholdDate = Calendar.current.date(
            byAdding: .day, value: -longPauseDays, to: referenceDate
        )!

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
        episodes
            .filter { !$0.isListened && $0.rating != nil }
            .sorted {
                if $0.rating! != $1.rating! {
                    return $0.rating! > $1.rating!
                }
                return $0.episodeNumber < $1.episodeNumber
            }
    }

    static func randomEpisodes(from episodes: [Episode], filter: EpisodeFilter = .unlistened, count: Int = 10) -> [Episode] {
        let filtered = filter.apply(to: episodes)
        return Array(filtered.shuffled().prefix(count))
    }

    static func episodesForMood(_ mood: Mood, from episodes: [Episode], filter: EpisodeFilter = .unlistened, count: Int = 10) -> [Episode] {
        let filtered = filter.apply(to: episodes)
        let matching = filtered.filter { $0.moods.contains(where: { $0 === mood }) }
        return Array(matching.shuffled().prefix(count))
    }

    static func availableMoods(from episodes: [Episode], filter: EpisodeFilter = .unlistened, allMoods: [Mood]) -> [(mood: Mood, count: Int)] {
        let filtered = filter.apply(to: episodes)
        var results: [(mood: Mood, count: Int)] = []

        for mood in allMoods {
            let count = filtered.filter { $0.moods.contains(where: { $0 === mood }) }.count
            if count > 0 {
                results.append((mood, count))
            }
        }

        results.sort { $0.mood.name.localizedCompare($1.mood.name) == .orderedAscending }
        return results
    }

    // MARK: - Teaser

    static func teaserText(for episode: Episode) -> String {
        let universeName = episode.universe?.name ?? "Allgemein"
        return "\(universeName): Folge \(episode.episodeNumber) — \(episode.title)"
    }
}
