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
            var episodeMoodsByKey: [String: Mood] = [:]
            for mood in episode.moods {
                let key = mood.normalizedName
                guard !key.isEmpty else { continue }

                if let existing = episodeMoodsByKey[key] {
                    episodeMoodsByKey[key] = Self.isPreferredDisplayMood(existing, over: mood)
                        ? existing
                        : mood
                } else {
                    episodeMoodsByKey[key] = mood
                }
            }

            for (key, mood) in episodeMoodsByKey {
                if let existing = moodCounts[key] {
                    let representative = Self.isPreferredDisplayMood(existing.mood, over: mood)
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

    private static func isPreferredDisplayMood(_ lhs: Mood, over rhs: Mood) -> Bool {
        let lhsHasCanonicalSyncKey = lhs.resolvedSyncKey == Mood.makeSyncKey(name: lhs.name)
        let rhsHasCanonicalSyncKey = rhs.resolvedSyncKey == Mood.makeSyncKey(name: rhs.name)
        if lhsHasCanonicalSyncKey != rhsHasCanonicalSyncKey {
            return lhsHasCanonicalSyncKey
        }

        let lhsHasIcon = lhs.iconName?.isEmpty == false
        let rhsHasIcon = rhs.iconName?.isEmpty == false
        if lhsHasIcon != rhsHasIcon {
            return lhsHasIcon
        }

        let lhsTrimmedName = lhs.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhsTrimmedName = rhs.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if lhs.name == lhsTrimmedName, rhs.name != rhsTrimmedName {
            return true
        }
        if lhs.name != lhsTrimmedName, rhs.name == rhsTrimmedName {
            return false
        }

        return lhsTrimmedName.localizedStandardCompare(rhsTrimmedName) == .orderedAscending
    }
}
