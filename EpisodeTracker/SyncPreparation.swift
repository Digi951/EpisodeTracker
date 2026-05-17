import Foundation
import os.log
import SwiftData

private let logger = Logger(subsystem: "com.Digi.EpisodeTracker", category: "SyncPreparation")

enum SyncPreparation {
    @MainActor
    static func prepare(context: ModelContext) {
        let allMoods = (try? context.fetch(FetchDescriptor<Mood>())) ?? []
        let allUniverses = (try? context.fetch(FetchDescriptor<Universe>())) ?? []
        let allEpisodes = (try? context.fetch(FetchDescriptor<Episode>())) ?? []

        var didChange = false

        didChange = repairEpisodeIDs(allEpisodes) || didChange
        didChange = repairMoodIDs(allMoods) || didChange
        didChange = repairUniverseIDs(allUniverses) || didChange
        didChange = repairMoods(allMoods, in: context) || didChange
        didChange = repairUniverses(allUniverses, in: context) || didChange
        didChange = deduplicateEpisodes(allEpisodes, in: context) || didChange

        let refreshedEpisodes = (try? context.fetch(FetchDescriptor<Episode>())) ?? allEpisodes
        didChange = refreshEpisodes(refreshedEpisodes) || didChange

        if didChange {
            do {
                try context.save()
                logger.info("SyncPreparation: saved repairs successfully")
            } catch {
                logger.error("SyncPreparation: save failed — \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private static func repairEpisodeIDs(_ episodes: [Episode]) -> Bool {
        var seenIDs = Set<UUID>()
        var didChange = false

        for episode in episodes where !seenIDs.insert(episode.id).inserted {
            episode.id = UUID()
            didChange = true
        }

        return didChange
    }

    @MainActor
    private static func repairMoodIDs(_ moods: [Mood]) -> Bool {
        var seenIDs = Set<UUID>()
        var didChange = false

        for mood in moods where !seenIDs.insert(mood.id).inserted {
            mood.id = UUID()
            didChange = true
        }

        return didChange
    }

    @MainActor
    private static func repairUniverseIDs(_ universes: [Universe]) -> Bool {
        var seenIDs = Set<UUID>()
        var didChange = false

        for universe in universes where !seenIDs.insert(universe.id).inserted {
            universe.id = UUID()
            didChange = true
        }

        return didChange
    }

    @MainActor
    private static func repairMoods(
        _ moods: [Mood],
        in context: ModelContext
    ) -> Bool {
        guard !moods.isEmpty else { return false }

        var didChange = false
        for mood in moods {
            let before = mood.resolvedSyncKey
            mood.ensureSyncKey()
            didChange = didChange || before != mood.resolvedSyncKey
        }

        let grouped = Dictionary(grouping: moods, by: moodDeduplicationKey)
        for duplicates in grouped.values where duplicates.count > 1 {
            let keeper = duplicates.sorted(by: preferMoodForDeduplication)[0]

            for duplicate in duplicates where duplicate.id != keeper.id {
                if (keeper.iconName == nil || keeper.iconName?.isEmpty == true),
                   let iconName = duplicate.iconName,
                   !iconName.isEmpty {
                    keeper.iconName = iconName
                    didChange = true
                }

                for episode in duplicate.episodes {
                    var mergedMoods: [Mood] = []
                    var seenKeys = Set<String>()
                    for mood in episode.moods {
                        let candidate = mood.id == duplicate.id ? keeper : mood
                        let key = candidate.resolvedSyncKey
                        if seenKeys.insert(key).inserted {
                            mergedMoods.append(candidate)
                        }
                    }
                    if episode.moods.count != mergedMoods.count || episode.moods.contains(where: { $0.id == duplicate.id }) {
                        episode.moods = mergedMoods
                        didChange = true
                    }
                }

                context.delete(duplicate)
                didChange = true
            }
        }

        return didChange
    }

    private static func moodDeduplicationKey(_ mood: Mood) -> String {
        let normalizedName = mood.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalizedName.isEmpty ? mood.resolvedSyncKey : "mood-name:\(normalizedName)"
    }

    private static func preferMoodForDeduplication(_ lhs: Mood, _ rhs: Mood) -> Bool {
        if lhs.episodes.count != rhs.episodes.count {
            return lhs.episodes.count > rhs.episodes.count
        }

        let lhsHasIcon = lhs.iconName?.isEmpty == false
        let rhsHasIcon = rhs.iconName?.isEmpty == false
        if lhsHasIcon != rhsHasIcon {
            return lhsHasIcon
        }

        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    @MainActor
    private static func repairUniverses(
        _ universes: [Universe],
        in context: ModelContext
    ) -> Bool {
        guard !universes.isEmpty else { return false }

        var didChange = false
        for universe in universes {
            let before = universe.resolvedSyncKey
            universe.ensureSyncKey()
            didChange = didChange || before != universe.resolvedSyncKey
        }

        let grouped = Dictionary(grouping: universes, by: universeDeduplicationKey)
        for duplicates in grouped.values where duplicates.count > 1 {
            let keeper = duplicates.sorted(by: preferUniverseForDeduplication)[0]

            for duplicate in duplicates where duplicate.id != keeper.id {
                for episode in duplicate.episodes {
                    episode.universe = keeper
                    episode.refreshSyncKeyIfPossible()
                    didChange = true
                }

                context.delete(duplicate)
                didChange = true
            }
        }

        return didChange
    }

    private static func universeDeduplicationKey(_ universe: Universe) -> String {
        let normalizedName = universe.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalizedName.isEmpty ? universe.resolvedSyncKey : "universe-name:\(normalizedName)"
    }

    private static func preferUniverseForDeduplication(_ lhs: Universe, _ rhs: Universe) -> Bool {
        if lhs.episodes.count != rhs.episodes.count {
            return lhs.episodes.count > rhs.episodes.count
        }

        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    /// Deduplicate episodes that share the same universe and episode number.
    /// Keeps the entry with the most user data (listened, rated, notes).
    @MainActor
    private static func deduplicateEpisodes(
        _ episodes: [Episode],
        in context: ModelContext
    ) -> Bool {
        guard !episodes.isEmpty else { return false }

        // Group by (universe syncKey, episodeNumber)
        struct EpisodeKey: Hashable {
            let universeSyncKey: String
            let episodeNumber: Int
        }

        var grouped: [EpisodeKey: [Episode]] = [:]
        for episode in episodes {
            let key = EpisodeKey(
                universeSyncKey: episode.universe?.resolvedSyncKey ?? "",
                episodeNumber: episode.episodeNumber
            )
            // Only group episodes that have a real universe (skip orphans with empty key)
            guard !key.universeSyncKey.isEmpty, key.episodeNumber > 0 else { continue }
            grouped[key, default: []].append(episode)
        }

        var didChange = false
        for (key, duplicates) in grouped where duplicates.count > 1 {
            // Sort: prefer listened > rated > has notes > has moods > earlier creation
            let sorted = duplicates.sorted { a, b in
                if a.isListened != b.isListened { return a.isListened }
                if (a.rating != nil) != (b.rating != nil) { return a.rating != nil }
                if let ra = a.rating, let rb = b.rating, ra != rb { return ra > rb }
                if a.listenCount != b.listenCount { return a.listenCount > b.listenCount }
                if (a.personalNote != nil) != (b.personalNote != nil) { return a.personalNote != nil }
                if a.moods.count != b.moods.count { return a.moods.count > b.moods.count }
                return false
            }

            let keeper = sorted[0]
            for duplicate in sorted.dropFirst() {
                // Merge any unique moods from the duplicate
                let keeperMoodKeys = Set(keeper.moods.map(\.resolvedSyncKey))
                for mood in duplicate.moods where !keeperMoodKeys.contains(mood.resolvedSyncKey) {
                    keeper.moods.append(mood)
                }

                // Merge personal notes (concatenate if both exist)
                if let duplicateNote = duplicate.personalNote, !duplicateNote.isEmpty {
                    if let keeperNote = keeper.personalNote, !keeperNote.isEmpty {
                        if keeperNote != duplicateNote {
                            keeper.personalNote = "\(keeperNote)\n\(duplicateNote)"
                        }
                    } else {
                        keeper.personalNote = duplicateNote
                    }
                }

                // Take higher rating if keeper has none
                if keeper.rating == nil {
                    keeper.rating = duplicate.rating
                }

                // Take higher listen count
                if duplicate.listenCount > keeper.listenCount {
                    keeper.listenCount = duplicate.listenCount
                }

                // Keep the most recent lastListenedAt
                if let duplicateDate = duplicate.lastListenedAt {
                    if let keeperDate = keeper.lastListenedAt {
                        if duplicateDate > keeperDate {
                            keeper.lastListenedAt = duplicateDate
                        }
                    } else {
                        keeper.lastListenedAt = duplicateDate
                    }
                }

                logger.info("Dedup: removing duplicate episode #\(key.episodeNumber) in '\(key.universeSyncKey)'")
                context.delete(duplicate)
                didChange = true
            }
        }

        return didChange
    }

    @MainActor
    private static func refreshEpisodes(_ episodes: [Episode]) -> Bool {
        var didChange = false

        for episode in episodes {
            let previousKey = episode.resolvedSyncKey
            episode.refreshSyncKeyIfPossible()
            didChange = didChange || previousKey != episode.resolvedSyncKey

            var deduplicatedMoods: [Mood] = []
            var seenMoodKeys = Set<String>()
            for mood in episode.moods {
                mood.ensureSyncKey()
                if seenMoodKeys.insert(mood.resolvedSyncKey).inserted {
                    deduplicatedMoods.append(mood)
                }
            }

            if deduplicatedMoods.count != episode.moods.count {
                episode.moods = deduplicatedMoods
                didChange = true
            }
        }

        return didChange
    }
}
