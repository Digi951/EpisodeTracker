import Foundation

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
        []
    }

    static func topRatedEpisodes(from episodes: [Episode]) -> [Episode] {
        []
    }

    static func randomEpisodes(from episodes: [Episode], count: Int = 10) -> [Episode] {
        []
    }

    static func episodesForMood(_ mood: Mood, from episodes: [Episode], count: Int = 10) -> [Episode] {
        []
    }

    static func availableMoods(from episodes: [Episode], allMoods: [Mood]) -> [(mood: Mood, count: Int)] {
        []
    }

    // MARK: - Teaser

    static func teaserText(for episode: Episode) -> String {
        let universeName = episode.universe?.name ?? "Allgemein"
        return "\(universeName): Folge \(episode.episodeNumber) — \(episode.title)"
    }
}
