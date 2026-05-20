import Foundation
import os.log
import SwiftData

private let logger = Logger(subsystem: "com.Digi.EpisodeTracker", category: "EntityDeduplicator")

enum EntityDeduplicator {

    // MARK: - ID Repair

    @MainActor
    static func repairEpisodeIDs(
        _ episodes: [Episode],
        summary: inout SyncPreparation.ChangeSummary
    ) -> Bool {
        var seenIDs = Set<UUID>()
        var didChange = false

        for episode in episodes where !seenIDs.insert(episode.id).inserted {
            episode.id = UUID()
            didChange = true
            summary.repairedEpisodeIDs += 1
        }

        return didChange
    }

    @MainActor
    static func repairMoodIDs(
        _ moods: [Mood],
        summary: inout SyncPreparation.ChangeSummary
    ) -> Bool {
        var seenIDs = Set<UUID>()
        var didChange = false

        for mood in moods where !seenIDs.insert(mood.id).inserted {
            mood.id = UUID()
            didChange = true
            summary.repairedMoodIDs += 1
        }

        return didChange
    }

    @MainActor
    static func repairUniverseIDs(
        _ universes: [Universe],
        summary: inout SyncPreparation.ChangeSummary
    ) -> Bool {
        var seenIDs = Set<UUID>()
        var didChange = false

        for universe in universes where !seenIDs.insert(universe.id).inserted {
            universe.id = UUID()
            didChange = true
            summary.repairedUniverseIDs += 1
        }

        return didChange
    }

    // MARK: - Mood Deduplication

    @MainActor
    static func deduplicateMoods(
        _ moods: [Mood],
        in context: ModelContext,
        summary: inout SyncPreparation.ChangeSummary
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
                summary.mergedMoods += 1
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

    // MARK: - Universe Deduplication

    @MainActor
    static func deduplicateUniverses(
        _ universes: [Universe],
        in context: ModelContext,
        summary: inout SyncPreparation.ChangeSummary
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
                summary.mergedUniverses += 1
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

    // MARK: - Episode Deduplication

    @MainActor
    static func deduplicateEpisodes(
        _ episodes: [Episode],
        in context: ModelContext,
        summary: inout SyncPreparation.ChangeSummary,
        coverStore providedCoverStore: CoverImageStore? = nil
    ) -> Bool {
        guard !episodes.isEmpty else { return false }
        let coverStore = providedCoverStore ?? CoverImageStore()

        struct EpisodeKey: Hashable {
            let universeKey: String
            let episodeNumber: Int
        }

        var grouped: [EpisodeKey: [Episode]] = [:]
        for episode in episodes {
            guard let universeKey = episode.universeDeduplicationUniverseKey,
                  episode.episodeNumber > 0 else { continue }

            let key = EpisodeKey(
                universeKey: universeKey,
                episodeNumber: episode.episodeNumber
            )
            grouped[key, default: []].append(episode)
        }

        var didChange = false
        for (key, duplicates) in grouped where duplicates.count > 1 {
            let sorted = duplicates.sorted { a, b in
                let aHasCover = hasExistingCover(a, in: coverStore)
                let bHasCover = hasExistingCover(b, in: coverStore)
                if aHasCover != bHasCover { return aHasCover }
                if a.isListened != b.isListened { return a.isListened }
                if (a.rating != nil) != (b.rating != nil) { return a.rating != nil }
                if let ra = a.rating, let rb = b.rating, ra != rb { return ra > rb }
                if a.listenCount != b.listenCount { return a.listenCount > b.listenCount }
                if (a.personalNote != nil) != (b.personalNote != nil) { return a.personalNote != nil }
                return false
            }

            let keeper = sorted[0]
            for duplicate in sorted.dropFirst() {
                if duplicate.isListened && !keeper.isListened {
                    keeper.isListened = true
                }

                if let duplicateNote = duplicate.personalNote, !duplicateNote.isEmpty {
                    if let keeperNote = keeper.personalNote, !keeperNote.isEmpty {
                        if keeperNote != duplicateNote {
                            keeper.personalNote = "\(keeperNote)\n\(duplicateNote)"
                        }
                    } else {
                        keeper.personalNote = duplicateNote
                    }
                }

                if keeper.rating == nil {
                    keeper.rating = duplicate.rating
                }

                if duplicate.listenCount > keeper.listenCount {
                    keeper.listenCount = duplicate.listenCount
                }

                if let duplicateDate = duplicate.lastListenedAt {
                    if let keeperDate = keeper.lastListenedAt {
                        if duplicateDate > keeperDate {
                            keeper.lastListenedAt = duplicateDate
                        }
                    } else {
                        keeper.lastListenedAt = duplicateDate
                    }
                }

                if !hasExistingCover(keeper, in: coverStore) {
                    if let duplicateCover = duplicate.coverImageName,
                       !duplicateCover.isEmpty,
                       coverStore.exists(name: duplicateCover) {
                        keeper.coverImageName = duplicateCover
                    }
                }

                if keeper.streamingURL == nil || keeper.streamingURL?.isEmpty == true {
                    if let duplicateURL = duplicate.streamingURL, !duplicateURL.isEmpty {
                        keeper.streamingURL = duplicateURL
                    }
                }

                logger.info("Dedup: removing duplicate episode #\(key.episodeNumber) in '\(key.universeKey)'")
                context.delete(duplicate)
                didChange = true
                summary.deduplicatedEpisodes += 1
            }
        }

        return didChange
    }

    private static func hasExistingCover(_ episode: Episode, in store: CoverImageStore) -> Bool {
        guard let coverName = episode.coverImageName, !coverName.isEmpty else {
            return false
        }

        return store.exists(name: coverName)
    }

    // MARK: - Sync Key Refresh

    @MainActor
    static func refreshEpisodes(
        _ episodes: [Episode],
        summary: inout SyncPreparation.ChangeSummary
    ) -> Bool {
        var didChange = false

        for episode in episodes {
            let previousKey = episode.resolvedSyncKey
            episode.refreshSyncKeyIfPossible()
            if previousKey != episode.resolvedSyncKey {
                didChange = true
                summary.refreshedEpisodeSyncKeys += 1
            }

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
                summary.deduplicatedEpisodeMoods += 1
            }
        }

        return didChange
    }
}

extension Episode {
    var universeDeduplicationUniverseKey: String? {
        guard let universe else { return nil }

        let normalizedName = universe.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if !normalizedName.isEmpty {
            return "universe-name:\(normalizedName)"
        }

        let syncKey = universe.resolvedSyncKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return syncKey.isEmpty ? nil : "universe-sync:\(syncKey)"
    }
}
