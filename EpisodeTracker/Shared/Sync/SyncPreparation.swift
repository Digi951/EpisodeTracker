import Foundation
import os.log
import SwiftData

private let logger = Logger(subsystem: "com.Digi.EpisodeTracker", category: "SyncPreparation")

enum SyncPreparation {
    @discardableResult
    @MainActor
    static func prepare(context: ModelContext) -> ChangeSummary {
        let allMoods = (try? context.fetch(FetchDescriptor<Mood>())) ?? []
        let allUniverses = (try? context.fetch(FetchDescriptor<Universe>())) ?? []
        let allEpisodes = (try? context.fetch(FetchDescriptor<Episode>())) ?? []

        logger.info(
            "SyncPreparation: start with episodes=\(allEpisodes.count), universes=\(allUniverses.count), moods=\(allMoods.count)"
        )

        var didChange = false
        var changeSummary = ChangeSummary()

        didChange = EntityDeduplicator.repairEpisodeIDs(allEpisodes, summary: &changeSummary) || didChange
        didChange = EntityDeduplicator.repairMoodIDs(allMoods, summary: &changeSummary) || didChange
        didChange = EntityDeduplicator.repairUniverseIDs(allUniverses, summary: &changeSummary) || didChange
        didChange = EntityDeduplicator.deduplicateMoods(allMoods, in: context, summary: &changeSummary) || didChange
        didChange = EntityDeduplicator.deduplicateUniverses(allUniverses, in: context, summary: &changeSummary) || didChange
        didChange = EntityDeduplicator.deduplicateEpisodes(allEpisodes, in: context, summary: &changeSummary) || didChange

        let refreshedEpisodes = (try? context.fetch(FetchDescriptor<Episode>())) ?? allEpisodes
        didChange = EntityDeduplicator.refreshEpisodes(refreshedEpisodes, summary: &changeSummary) || didChange

        if didChange {
            do {
                try context.save()
                logger.info("SyncPreparation: saved repairs successfully (\(changeSummary.logDescription, privacy: .public))")
            } catch {
                logger.error("SyncPreparation: save failed — \(error.localizedDescription)")
            }
        } else {
            logger.info("SyncPreparation: no repairs required")
        }

        return changeSummary
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
    }
}
