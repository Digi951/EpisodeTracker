import Foundation

struct StatisticsSnapshot {
    let listenedCount: Int
    let unlistenedCount: Int
    let averageRating: Double?
    let totalListens: Int
    let topRated: [Episode]
    let moodDistribution: [(Mood, Int)]

    init(episodes: [Episode]) {
        listenedCount = episodes.filter(\.isListened).count
        unlistenedCount = episodes.count - listenedCount

        let rated = episodes.compactMap(\.rating)
        averageRating = rated.isEmpty ? nil : Double(rated.reduce(0, +)) / Double(rated.count)
        totalListens = episodes.reduce(0) { $0 + $1.listenCount }

        topRated = episodes
            .filter { $0.rating != nil }
            .sorted {
                let leftRating = $0.rating ?? 0
                let rightRating = $1.rating ?? 0
                if leftRating != rightRating {
                    return leftRating > rightRating
                }

                let leftUniverse = AppLocalization.displayName(forUniverseName: $0.universe?.name)
                let rightUniverse = AppLocalization.displayName(forUniverseName: $1.universe?.name)
                if leftUniverse != rightUniverse {
                    return leftUniverse.localizedCompare(rightUniverse) == .orderedAscending
                }

                return $0.episodeNumber < $1.episodeNumber
            }
            .prefix(5)
            .map { $0 }

        var moodCounts: [String: (mood: Mood, count: Int)] = [:]
        for episode in episodes {
            var countedMoodKeys = Set<String>()
            for mood in episode.moods {
                let key = mood.normalizedName
                guard !key.isEmpty, countedMoodKeys.insert(key).inserted else { continue }

                if let existing = moodCounts[key] {
                    let representative = Mood.isPreferredAsCanonical(existing.mood, over: mood)
                        ? existing.mood
                        : mood
                    moodCounts[key] = (representative, existing.count + 1)
                } else {
                    moodCounts[key] = (mood, 1)
                }
            }
        }
        moodDistribution = moodCounts.values
            .sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                }

                return $0.mood.name.localizedCompare($1.mood.name) == .orderedAscending
            }
            .map { ($0.mood, $0.count) }
    }
}
