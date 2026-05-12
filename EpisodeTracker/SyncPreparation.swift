import Foundation
import SwiftData

enum SyncPreparation {
    @MainActor
    static func prepare(context: ModelContext) {
        let allMoods = (try? context.fetch(FetchDescriptor<Mood>())) ?? []
        let allUniverses = (try? context.fetch(FetchDescriptor<Universe>())) ?? []
        let allEpisodes = (try? context.fetch(FetchDescriptor<Episode>())) ?? []

        var didChange = false

        didChange = repairMoods(allMoods, in: context) || didChange
        didChange = repairUniverses(allUniverses, in: context) || didChange

        let refreshedEpisodes = (try? context.fetch(FetchDescriptor<Episode>())) ?? allEpisodes
        didChange = refreshEpisodes(refreshedEpisodes) || didChange

        if didChange {
            try? context.save()
        }
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

        let grouped = Dictionary(grouping: moods, by: \.resolvedSyncKey)
        for duplicates in grouped.values where duplicates.count > 1 {
            let keeper = duplicates[0]

            for duplicate in duplicates.dropFirst() {
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

        let grouped = Dictionary(grouping: universes, by: \.resolvedSyncKey)
        for duplicates in grouped.values where duplicates.count > 1 {
            let keeper = duplicates[0]

            for duplicate in duplicates.dropFirst() {
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
