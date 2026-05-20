import Foundation
import os.log
import SwiftData

private let logger = Logger(subsystem: "com.Digi.EpisodeTracker", category: "SyncPreparation")

enum SyncPreparation {
    @discardableResult
    @MainActor
    static func prepare(context: ModelContext) -> ChangeSummary {
        var changeSummary = ChangeSummary()

        let didChange = runDedup(context: context, summary: &changeSummary)

        if didChange {
            do {
                try context.save()
                logger.info("SyncPreparation: saved repairs (\(changeSummary.logDescription, privacy: .public))")
            } catch {
                logger.error("SyncPreparation: save failed — \(error.localizedDescription)")
            }

            let remainingDuplicates = verifyNoDuplicates(context: context)
            if remainingDuplicates {
                logger.warning("SyncPreparation: duplicates remain after first pass, retrying")
                var retrySummary = ChangeSummary()
                let retryChanged = runDedup(context: context, summary: &retrySummary)
                if retryChanged {
                    do {
                        try context.save()
                        logger.info("SyncPreparation: retry saved (\(retrySummary.logDescription, privacy: .public))")
                        changeSummary.merge(retrySummary)
                    } catch {
                        logger.error("SyncPreparation: retry save failed — \(error.localizedDescription)")
                    }
                }
            }
        } else {
            logger.info("SyncPreparation: no repairs required")
        }

        return changeSummary
    }

    @MainActor
    private static func runDedup(context: ModelContext, summary: inout ChangeSummary) -> Bool {
        let allMoods = (try? context.fetch(FetchDescriptor<Mood>())) ?? []
        let allUniverses = (try? context.fetch(FetchDescriptor<Universe>())) ?? []
        let allEpisodes = (try? context.fetch(FetchDescriptor<Episode>())) ?? []

        logger.info(
            "SyncPreparation: start with episodes=\(allEpisodes.count), universes=\(allUniverses.count), moods=\(allMoods.count)"
        )

        var didChange = false

        didChange = EntityDeduplicator.repairEpisodeIDs(allEpisodes, summary: &summary) || didChange
        didChange = EntityDeduplicator.repairMoodIDs(allMoods, summary: &summary) || didChange
        didChange = EntityDeduplicator.repairUniverseIDs(allUniverses, summary: &summary) || didChange
        didChange = EntityDeduplicator.deduplicateMoods(allMoods, in: context, summary: &summary) || didChange
        didChange = EntityDeduplicator.deduplicateUniverses(allUniverses, in: context, summary: &summary) || didChange
        didChange = EntityDeduplicator.deduplicateEpisodes(allEpisodes, in: context, summary: &summary) || didChange

        let refreshedEpisodes = (try? context.fetch(FetchDescriptor<Episode>())) ?? allEpisodes
        didChange = EntityDeduplicator.refreshEpisodes(refreshedEpisodes, summary: &summary) || didChange

        return didChange
    }

    @MainActor
    private static func verifyNoDuplicates(context: ModelContext) -> Bool {
        let moods = (try? context.fetch(FetchDescriptor<Mood>())) ?? []
        let universes = (try? context.fetch(FetchDescriptor<Universe>())) ?? []
        let episodes = (try? context.fetch(FetchDescriptor<Episode>())) ?? []

        let moodNames = moods.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let universeNames = universes.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        let hasDuplicateMoods = Set(moodNames).count < moodNames.count
        let hasDuplicateUniverses = Set(universeNames).count < universeNames.count

        var hasDuplicateEpisodes = false
        var episodeKeys = Set<String>()
        for episode in episodes {
            guard let universeKey = episode.universeDeduplicationUniverseKey,
                  episode.episodeNumber > 0 else { continue }
            let key = "\(universeKey)#\(episode.episodeNumber)"
            if !episodeKeys.insert(key).inserted {
                hasDuplicateEpisodes = true
                break
            }
        }

        if hasDuplicateMoods {
            logger.warning("SyncPreparation: \(moodNames.count - Set(moodNames).count) duplicate mood(s) remain")
        }
        if hasDuplicateUniverses {
            logger.warning("SyncPreparation: \(universeNames.count - Set(universeNames).count) duplicate universe(s) remain")
        }
        if hasDuplicateEpisodes {
            logger.warning("SyncPreparation: duplicate episode(s) remain")
        }

        return hasDuplicateMoods || hasDuplicateUniverses || hasDuplicateEpisodes
    }

    struct ChangeSummary: Sendable {
        var repairedEpisodeIDs = 0
        var repairedMoodIDs = 0
        var repairedUniverseIDs = 0
        var mergedMoods = 0
        var mergedUniverses = 0
        var deduplicatedEpisodes = 0
        var refreshedEpisodeSyncKeys = 0
        var deduplicatedEpisodeMoods = 0

        var hasChanges: Bool {
            repairedEpisodeIDs > 0 ||
            repairedMoodIDs > 0 ||
            repairedUniverseIDs > 0 ||
            mergedMoods > 0 ||
            mergedUniverses > 0 ||
            deduplicatedEpisodes > 0 ||
            refreshedEpisodeSyncKeys > 0 ||
            deduplicatedEpisodeMoods > 0
        }

        var logDescription: String {
            "episodeIDs=\(repairedEpisodeIDs), moodIDs=\(repairedMoodIDs), universeIDs=\(repairedUniverseIDs), mergedMoods=\(mergedMoods), mergedUniverses=\(mergedUniverses), deduplicatedEpisodes=\(deduplicatedEpisodes), refreshedEpisodeSyncKeys=\(refreshedEpisodeSyncKeys), deduplicatedEpisodeMoods=\(deduplicatedEpisodeMoods)"
        }

        mutating func merge(_ other: ChangeSummary) {
            repairedEpisodeIDs += other.repairedEpisodeIDs
            repairedMoodIDs += other.repairedMoodIDs
            repairedUniverseIDs += other.repairedUniverseIDs
            mergedMoods += other.mergedMoods
            mergedUniverses += other.mergedUniverses
            deduplicatedEpisodes += other.deduplicatedEpisodes
            refreshedEpisodeSyncKeys += other.refreshedEpisodeSyncKeys
            deduplicatedEpisodeMoods += other.deduplicatedEpisodeMoods
        }
    }
}
