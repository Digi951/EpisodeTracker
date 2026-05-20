import Foundation
import os.log
import SwiftData

private let syncMigrationLogger = Logger(
    subsystem: "com.Digi.EpisodeTracker",
    category: "SyncMigration"
)

struct LocalLibrarySnapshot: Equatable {
    struct UniverseRecord: Equatable {
        let syncKey: String
        let name: String
    }

    struct MoodRecord: Equatable {
        let syncKey: String
        let name: String
        let iconName: String?
    }

    struct EpisodeRecord: Equatable {
        let syncKey: String
        let episodeNumber: Int
        let title: String
        let releaseYear: Int
        let personalNote: String?
        let isListened: Bool
        let rating: Int?
        let listenCount: Int
        let lastListenedAt: Date?
        let coverImageName: String?
        let coverUpdatedAt: Date?
        let moodsUpdatedAt: Date?
        let universeSyncKey: String?
        let moodSyncKeys: [String]

        init(
            syncKey: String,
            episodeNumber: Int,
            title: String,
            releaseYear: Int,
            personalNote: String?,
            isListened: Bool,
            rating: Int?,
            listenCount: Int,
            lastListenedAt: Date?,
            coverImageName: String? = nil,
            coverUpdatedAt: Date? = nil,
            moodsUpdatedAt: Date? = nil,
            universeSyncKey: String?,
            moodSyncKeys: [String]
        ) {
            self.syncKey = syncKey
            self.episodeNumber = episodeNumber
            self.title = title
            self.releaseYear = releaseYear
            self.personalNote = personalNote
            self.isListened = isListened
            self.rating = rating
            self.listenCount = listenCount
            self.lastListenedAt = lastListenedAt
            self.coverImageName = coverImageName
            self.coverUpdatedAt = coverUpdatedAt
            self.moodsUpdatedAt = moodsUpdatedAt
            self.universeSyncKey = universeSyncKey
            self.moodSyncKeys = moodSyncKeys
        }
    }

    let universes: [UniverseRecord]
    let moods: [MoodRecord]
    let episodes: [EpisodeRecord]
}

extension LocalLibrarySnapshot {
    @MainActor
    static func capture(context: ModelContext) -> LocalLibrarySnapshot {
        let universes = ((try? context.fetch(FetchDescriptor<Universe>())) ?? [])
            .map { universe in
                UniverseRecord(
                    syncKey: universe.resolvedSyncKey,
                    name: universe.name
                )
            }
            .sorted { $0.syncKey < $1.syncKey }

        let moods = ((try? context.fetch(FetchDescriptor<Mood>())) ?? [])
            .map { mood in
                MoodRecord(
                    syncKey: mood.resolvedSyncKey,
                    name: mood.name,
                    iconName: mood.iconName
                )
            }
            .sorted { $0.syncKey < $1.syncKey }

        let episodes = ((try? context.fetch(FetchDescriptor<Episode>())) ?? [])
            .map { episode in
                EpisodeRecord(
                    syncKey: episode.resolvedSyncKey,
                    episodeNumber: episode.episodeNumber,
                    title: episode.title,
                    releaseYear: episode.releaseYear,
                    personalNote: episode.personalNote,
                    isListened: episode.isListened,
                    rating: episode.rating,
                    listenCount: episode.listenCount,
                    lastListenedAt: episode.lastListenedAt,
                    coverImageName: episode.coverImageName,
                    coverUpdatedAt: episode.coverUpdatedAt,
                    moodsUpdatedAt: episode.moodsUpdatedAt,
                    universeSyncKey: episode.universe?.resolvedSyncKey,
                    moodSyncKeys: episode.moods.map(\.resolvedSyncKey).sorted()
                )
            }
            .sorted { $0.syncKey < $1.syncKey }

        return LocalLibrarySnapshot(
            universes: universes,
            moods: moods,
            episodes: episodes
        )
    }

    static func record(from episode: Episode) -> EpisodeRecord {
        EpisodeRecord(
            syncKey: episode.resolvedSyncKey,
            episodeNumber: episode.episodeNumber,
            title: episode.title,
            releaseYear: episode.releaseYear,
            personalNote: episode.personalNote,
            isListened: episode.isListened,
            rating: episode.rating,
            listenCount: episode.listenCount,
            lastListenedAt: episode.lastListenedAt,
            coverImageName: episode.coverImageName,
            coverUpdatedAt: episode.coverUpdatedAt,
            moodsUpdatedAt: episode.moodsUpdatedAt,
            universeSyncKey: episode.universe?.resolvedSyncKey,
            moodSyncKeys: episode.moods.map(\.resolvedSyncKey).sorted()
        )
    }
}

enum SyncMigrationIssue: Equatable, Hashable {
    case duplicateUniverseSyncKey(String)
    case duplicateMoodSyncKey(String)
    case duplicateEpisodeSyncKey(String)
    case missingUniverseReference(episodeSyncKey: String, universeSyncKey: String)
    case missingMoodReference(episodeSyncKey: String, moodSyncKey: String)
}

enum SyncMigrationValidator {
    static func validate(snapshot: LocalLibrarySnapshot) -> [SyncMigrationIssue] {
        var issues: [SyncMigrationIssue] = []

        issues.append(contentsOf: duplicateIssues(in: snapshot.universes.map(\.syncKey), makeIssue: SyncMigrationIssue.duplicateUniverseSyncKey))
        issues.append(contentsOf: duplicateIssues(in: snapshot.moods.map(\.syncKey), makeIssue: SyncMigrationIssue.duplicateMoodSyncKey))
        issues.append(contentsOf: duplicateIssues(in: snapshot.episodes.map(\.syncKey), makeIssue: SyncMigrationIssue.duplicateEpisodeSyncKey))

        let knownUniverseKeys = Set(snapshot.universes.map(\.syncKey))
        let knownMoodKeys = Set(snapshot.moods.map(\.syncKey))

        for episode in snapshot.episodes {
            if let universeSyncKey = episode.universeSyncKey,
               !knownUniverseKeys.contains(universeSyncKey) {
                issues.append(
                    .missingUniverseReference(
                        episodeSyncKey: episode.syncKey,
                        universeSyncKey: universeSyncKey
                    )
                )
            }

            for moodSyncKey in episode.moodSyncKeys where !knownMoodKeys.contains(moodSyncKey) {
                issues.append(
                    .missingMoodReference(
                        episodeSyncKey: episode.syncKey,
                        moodSyncKey: moodSyncKey
                    )
                )
            }
        }

        return issues
    }

    private static func duplicateIssues(
        in keys: [String],
        makeIssue: (String) -> SyncMigrationIssue
    ) -> [SyncMigrationIssue] {
        var seen = Set<String>()
        var duplicates = Set<String>()

        for key in keys where !seen.insert(key).inserted {
            duplicates.insert(key)
        }

        return duplicates.sorted().map(makeIssue)
    }
}

enum SyncMigrationEpisodeMerger {
    static func merge(
        local: LocalLibrarySnapshot.EpisodeRecord,
        cloud: LocalLibrarySnapshot.EpisodeRecord
    ) -> LocalLibrarySnapshot.EpisodeRecord {
        let mergedNote = mergedNote(local: local.personalNote, cloud: cloud.personalNote)
        let mergedLastListenedAt = maxDate(local.lastListenedAt, cloud.lastListenedAt)
        let mergedCover = mergedCover(local: local, cloud: cloud)
        let mergedMoods = mergedMoods(local: local, cloud: cloud)

        return LocalLibrarySnapshot.EpisodeRecord(
            syncKey: local.syncKey,
            episodeNumber: local.episodeNumber,
            title: preferredText(local.title, fallback: cloud.title),
            releaseYear: max(local.releaseYear, cloud.releaseYear),
            personalNote: mergedNote,
            isListened: local.isListened || cloud.isListened,
            rating: local.rating ?? cloud.rating,
            listenCount: max(local.listenCount, cloud.listenCount),
            lastListenedAt: mergedLastListenedAt,
            coverImageName: mergedCover.name,
            coverUpdatedAt: mergedCover.updatedAt,
            moodsUpdatedAt: mergedMoods.updatedAt,
            universeSyncKey: local.universeSyncKey ?? cloud.universeSyncKey,
            moodSyncKeys: mergedMoods.keys
        )
    }

    private static func preferredText(_ preferred: String, fallback: String) -> String {
        let trimmedPreferred = preferred.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPreferred.isEmpty {
            return preferred
        }

        return fallback
    }

    private static func mergedNote(local: String?, cloud: String?) -> String? {
        let localTrimmed = local?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cloudTrimmed = cloud?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if localTrimmed.isEmpty { return cloud }
        if cloudTrimmed.isEmpty { return local }

        return localTrimmed.count >= cloudTrimmed.count ? local : cloud
    }

    private static func preferredOptionalText(_ preferred: String?, fallback: String?) -> String? {
        let trimmedPreferred = preferred?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedPreferred.isEmpty {
            return preferred
        }

        return fallback
    }

    private static func mergedCover(
        local: LocalLibrarySnapshot.EpisodeRecord,
        cloud: LocalLibrarySnapshot.EpisodeRecord
    ) -> (name: String?, updatedAt: Date?) {
        if preferCloud(localUpdatedAt: local.coverUpdatedAt, cloudUpdatedAt: cloud.coverUpdatedAt) {
            return (cloud.coverImageName, cloud.coverUpdatedAt)
        }

        if local.coverUpdatedAt != nil {
            return (local.coverImageName, local.coverUpdatedAt)
        }

        let localTrimmed = local.coverImageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !localTrimmed.isEmpty {
            return (local.coverImageName, nil)
        }

        return (cloud.coverImageName, cloud.coverUpdatedAt)
    }

    private static func mergedMoods(
        local: LocalLibrarySnapshot.EpisodeRecord,
        cloud: LocalLibrarySnapshot.EpisodeRecord
    ) -> (keys: [String], updatedAt: Date?) {
        if preferCloud(localUpdatedAt: local.moodsUpdatedAt, cloudUpdatedAt: cloud.moodsUpdatedAt) {
            return (cloud.moodSyncKeys, cloud.moodsUpdatedAt)
        }

        return (local.moodSyncKeys, local.moodsUpdatedAt)
    }

    private static func preferCloud(localUpdatedAt: Date?, cloudUpdatedAt: Date?) -> Bool {
        switch (localUpdatedAt, cloudUpdatedAt) {
        case let (local?, cloud?):
            return cloud > local
        case (nil, _?):
            return false
        case (_?, nil), (nil, nil):
            return false
        }
    }

    private static func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (left?, right?):
            return max(left, right)
        case let (left?, nil):
            return left
        case let (nil, right?):
            return right
        case (nil, nil):
            return nil
        }
    }
}

enum SyncMigrationStateStore {
    static let completedMigrationMarkerKey = "syncMigration.completedLocalToCloud"
    static let completedMigrationRepairVersionKey = "syncMigration.completedLocalToCloudRepairVersion"
    static let currentRepairVersion = 1

    static func hasCompletedLocalToCloudMigration(
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        userDefaults.bool(forKey: completedMigrationMarkerKey)
    }

    static func markLocalToCloudMigrationCompleted(
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(true, forKey: completedMigrationMarkerKey)
    }

    static func hasCompletedLocalToCloudRepair(
        userDefaults: UserDefaults = .standard
    ) -> Bool {
        userDefaults.integer(forKey: completedMigrationRepairVersionKey) >= currentRepairVersion
    }

    static func markLocalToCloudRepairCompleted(
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(currentRepairVersion, forKey: completedMigrationRepairVersionKey)
    }
}

enum SyncMigrationCompletedRepairer {
    @MainActor
    static func repairMissingLocalCovers(
        snapshot: LocalLibrarySnapshot,
        into context: ModelContext
    ) throws -> Int {
        guard SyncMigrationValidator.validate(snapshot: snapshot).isEmpty else {
            return 0
        }

        let cloudEpisodes = (try? context.fetch(FetchDescriptor<Episode>())) ?? []
        let cloudEpisodesBySyncKey = Dictionary(
            uniqueKeysWithValues: cloudEpisodes.map { ($0.resolvedSyncKey, $0) }
        )

        var repairedCovers = 0
        for localEpisode in snapshot.episodes {
            guard let localCoverName = localEpisode.coverImageName?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !localCoverName.isEmpty,
                  let cloudEpisode = cloudEpisodesBySyncKey[localEpisode.syncKey] else {
                continue
            }

            let cloudCoverName = cloudEpisode.coverImageName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard cloudCoverName.isEmpty else { continue }

            cloudEpisode.coverImageName = localEpisode.coverImageName
            cloudEpisode.coverUpdatedAt = localEpisode.coverUpdatedAt
            repairedCovers += 1
        }

        if repairedCovers > 0 {
            try context.save()
        }

        return repairedCovers
    }
}

struct SyncMigrationReport: Equatable {
    let migratedUniverseCount: Int
    let migratedMoodCount: Int
    let migratedEpisodeCount: Int
    let validationIssues: [SyncMigrationIssue]
    let markedCompleted: Bool
}

struct SyncMigrationReadiness: Equatable {
    let hasCompletedMigration: Bool
    let hasLocalPersistentContainer: Bool
    let hasCloudPersistentContainer: Bool
    let localEpisodeCount: Int
    let localUniverseCount: Int
    let localMoodCount: Int
    let localValidationIssues: [SyncMigrationIssue]

    var hasLocalData: Bool {
        localEpisodeCount > 0 || localUniverseCount > 0 || localMoodCount > 0
    }

    var canAttemptMigration: Bool {
        !hasCompletedMigration
            && hasLocalPersistentContainer
            && hasCloudPersistentContainer
            && hasLocalData
            && localValidationIssues.isEmpty
    }
}

enum SyncMigrationReadinessEvaluator {
    @MainActor
    static func evaluate(
        containerSet: AppModelContainerSet,
        userDefaults: UserDefaults = .standard
    ) -> SyncMigrationReadiness {
        let localSnapshot: LocalLibrarySnapshot
        if let localContainer = containerSet.localPersistent {
            localSnapshot = LocalLibrarySnapshot.capture(context: localContainer.mainContext)
        } else {
            localSnapshot = LocalLibrarySnapshot(universes: [], moods: [], episodes: [])
        }

        let readiness = SyncMigrationReadiness(
            hasCompletedMigration: SyncMigrationStateStore.hasCompletedLocalToCloudMigration(userDefaults: userDefaults),
            hasLocalPersistentContainer: containerSet.localPersistent != nil,
            hasCloudPersistentContainer: containerSet.cloudPersistent != nil,
            localEpisodeCount: localSnapshot.episodes.count,
            localUniverseCount: localSnapshot.universes.count,
            localMoodCount: localSnapshot.moods.count,
            localValidationIssues: SyncMigrationValidator.validate(snapshot: localSnapshot)
        )

        syncMigrationLogger.info(
            "Readiness evaluated: completed=\(readiness.hasCompletedMigration, privacy: .public), localContainer=\(readiness.hasLocalPersistentContainer, privacy: .public), cloudContainer=\(readiness.hasCloudPersistentContainer, privacy: .public), episodes=\(readiness.localEpisodeCount, privacy: .public), universes=\(readiness.localUniverseCount, privacy: .public), moods=\(readiness.localMoodCount, privacy: .public), issues=\(readiness.localValidationIssues.count, privacy: .public), canAttempt=\(readiness.canAttemptMigration, privacy: .public)"
        )

        return readiness
    }
}

enum SyncMigrationCoordinator {
    @MainActor
    static func migrate(
        snapshot: LocalLibrarySnapshot,
        into context: ModelContext,
        userDefaults: UserDefaults = .standard
    ) throws -> SyncMigrationReport {
        let sourceValidationIssues = SyncMigrationValidator.validate(snapshot: snapshot)

        syncMigrationLogger.info(
            "Migration started: episodes=\(snapshot.episodes.count, privacy: .public), universes=\(snapshot.universes.count, privacy: .public), moods=\(snapshot.moods.count, privacy: .public), sourceIssues=\(sourceValidationIssues.count, privacy: .public)"
        )

        var universesBySyncKey = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Universe>())) ?? []).map {
                ($0.resolvedSyncKey, $0)
            }
        )
        var moodsBySyncKey = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Mood>())) ?? []).map {
                ($0.resolvedSyncKey, $0)
            }
        )
        var episodesBySyncKey = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Episode>())) ?? []).map {
                ($0.resolvedSyncKey, $0)
            }
        )

        for universeRecord in snapshot.universes {
            if let existing = universesBySyncKey[universeRecord.syncKey] {
                if existing.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    existing.name = universeRecord.name
                }
            } else {
                let universe = Universe(name: universeRecord.name, syncKey: universeRecord.syncKey)
                context.insert(universe)
                universesBySyncKey[universeRecord.syncKey] = universe
            }
        }

        for moodRecord in snapshot.moods {
            if let existing = moodsBySyncKey[moodRecord.syncKey] {
                if (existing.iconName == nil || existing.iconName?.isEmpty == true),
                   let iconName = moodRecord.iconName,
                   !iconName.isEmpty {
                    existing.iconName = iconName
                }
            } else {
                let mood = Mood(name: moodRecord.name, iconName: moodRecord.iconName, syncKey: moodRecord.syncKey)
                context.insert(mood)
                moodsBySyncKey[moodRecord.syncKey] = mood
            }
        }

        for episodeRecord in snapshot.episodes {
            if let existing = episodesBySyncKey[episodeRecord.syncKey] {
                let mergedRecord = SyncMigrationEpisodeMerger.merge(
                    local: episodeRecord,
                    cloud: LocalLibrarySnapshot.record(from: existing)
                )
                apply(mergedRecord, to: existing, universesBySyncKey: universesBySyncKey, moodsBySyncKey: moodsBySyncKey)
            } else {
                let episode = Episode(
                    episodeNumber: episodeRecord.episodeNumber,
                    title: episodeRecord.title,
                    releaseYear: episodeRecord.releaseYear,
                    syncKey: episodeRecord.syncKey
                )
                apply(episodeRecord, to: episode, universesBySyncKey: universesBySyncKey, moodsBySyncKey: moodsBySyncKey)
                context.insert(episode)
                episodesBySyncKey[episodeRecord.syncKey] = episode
            }
        }

        try context.save()

        let migratedSnapshot = LocalLibrarySnapshot.capture(context: context)
        let migratedValidationIssues = SyncMigrationValidator.validate(snapshot: migratedSnapshot)
        let validationIssues = deduplicatedIssues(
            sourceValidationIssues + migratedValidationIssues
        )
        let markedCompleted = sourceValidationIssues.isEmpty && migratedValidationIssues.isEmpty

        syncMigrationLogger.info(
            "Migration finished: migratedEpisodes=\(migratedSnapshot.episodes.count, privacy: .public), migratedUniverses=\(migratedSnapshot.universes.count, privacy: .public), migratedMoods=\(migratedSnapshot.moods.count, privacy: .public), migratedIssues=\(migratedValidationIssues.count, privacy: .public), combinedIssues=\(validationIssues.count, privacy: .public), markedCompleted=\(markedCompleted, privacy: .public)"
        )

        if markedCompleted {
            SyncMigrationStateStore.markLocalToCloudMigrationCompleted(userDefaults: userDefaults)
            syncMigrationLogger.info("Migration completion marker updated")
        } else {
            syncMigrationLogger.info("Migration completion marker left unchanged")
        }

        return SyncMigrationReport(
            migratedUniverseCount: migratedSnapshot.universes.count,
            migratedMoodCount: migratedSnapshot.moods.count,
            migratedEpisodeCount: migratedSnapshot.episodes.count,
            validationIssues: validationIssues,
            markedCompleted: markedCompleted
        )
    }

    private static func deduplicatedIssues(
        _ issues: [SyncMigrationIssue]
    ) -> [SyncMigrationIssue] {
        var seen = Set<SyncMigrationIssue>()
        var deduplicated: [SyncMigrationIssue] = []

        for issue in issues where seen.insert(issue).inserted {
            deduplicated.append(issue)
        }

        return deduplicated
    }

    @MainActor
    private static func apply(
        _ record: LocalLibrarySnapshot.EpisodeRecord,
        to episode: Episode,
        universesBySyncKey: [String: Universe],
        moodsBySyncKey: [String: Mood]
    ) {
        episode.syncKey = record.syncKey
        episode.episodeNumber = record.episodeNumber
        episode.title = record.title
        episode.releaseYear = record.releaseYear
        episode.personalNote = record.personalNote
        episode.isListened = record.isListened
        episode.rating = record.rating
        episode.listenCount = record.listenCount
        episode.lastListenedAt = record.lastListenedAt
        episode.coverImageName = record.coverImageName
        episode.coverUpdatedAt = record.coverUpdatedAt
        episode.moodsUpdatedAt = record.moodsUpdatedAt
        episode.universe = record.universeSyncKey.flatMap { universesBySyncKey[$0] }
        episode.moods = record.moodSyncKeys.compactMap { moodsBySyncKey[$0] }
        episode.refreshSyncKeyIfPossible()
    }
}
