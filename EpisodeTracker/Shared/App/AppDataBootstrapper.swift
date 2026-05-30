import Foundation
import os.log
import SwiftData

private let bootstrapLogger = Logger(
    subsystem: "com.Digi.EpisodeTracker",
    category: "AppDataBootstrapper"
)

enum AppDataBootstrapper {
    static let schemaVersionKey = "schemaVersion"
    static let currentSchemaVersion = 6
    static let automaticCloudMigrationStatusKey = "syncMigration.automaticStatus"

    @discardableResult
    @MainActor
    static func bootstrap(
        containerSet: AppModelContainerSet,
        userDefaults: UserDefaults = .standard
    ) async -> BootstrapReport {
        var report = BootstrapReport()
        let lastSchemaVersion = userDefaults.integer(forKey: schemaVersionKey)

        let libraryIsEmpty = ((try? containerSet.primary.mainContext.fetchCount(FetchDescriptor<Episode>())) ?? 0) == 0
        suppressFeatureAnnouncementsIfFreshInstall(
            lastSchemaVersion: lastSchemaVersion,
            libraryIsEmpty: libraryIsEmpty,
            userDefaults: userDefaults
        )

        // Pre-Migration: prepare local container and run sync repair before migration
        if let localContainer = containerSet.localPersistent {
            report = prepareContainer(
                localContainer,
                usesCloudSync: false,
                lastSchemaVersion: lastSchemaVersion
            )
            let preMigrationSummary = SyncPreparation.prepare(context: localContainer.mainContext)
            if preMigrationSummary.hasChanges {
                bootstrapLogger.info("Bootstrap: pre-migration sync repair applied (\(preMigrationSummary.logDescription, privacy: .public))")
            }
        }

        let shouldPreparePrimary: Bool
        if let localContainer = containerSet.localPersistent {
            shouldPreparePrimary = containerSet.primary !== localContainer
        } else {
            shouldPreparePrimary = true
        }

        if shouldPreparePrimary {
            report = prepareContainer(
                containerSet.primary,
                usesCloudSync: containerSet.runtimeMode.usesCloudSync,
                lastSchemaVersion: lastSchemaVersion
            )
        }

        if containerSet.runtimeMode.usesCloudSync {
            attemptAutomaticCloudMigrationIfNeeded(
                containerSet: containerSet,
                userDefaults: userDefaults,
                lastSchemaVersion: lastSchemaVersion,
                report: &report
            )

            repairCloudSyncReadinessIfNeeded(container: containerSet.primary)
        }

        // Post-Migration: run sync repair on the primary container
        let postMigrationSummary = SyncPreparation.prepare(context: containerSet.primary.mainContext)
        report.syncPreparationSummary = postMigrationSummary
        if postMigrationSummary.hasChanges {
            bootstrapLogger.info("Bootstrap: post-migration sync repair applied (\(postMigrationSummary.logDescription, privacy: .public))")
        }

        await EpisodeCatalog.shared.refreshManagedCatalogsIfNeeded()
        ensureBundledCollectionExists(container: containerSet.primary)
        report.removedOrphanCovers = cleanupOrphanedCovers(container: containerSet.primary)

        userDefaults.set(currentSchemaVersion, forKey: schemaVersionKey)
        AppModelContainerFactory.removePreMigrationBackup()

        bootstrapLogger.info("Bootstrap complete: \(report.logDescription, privacy: .public)")
        return report
    }

    @discardableResult
    @MainActor
    static func bootstrap(
        container: ModelContainer,
        usesCloudSync: Bool,
        userDefaults: UserDefaults = .standard
    ) async -> BootstrapReport {
        let lastSchemaVersion = userDefaults.integer(forKey: schemaVersionKey)
        var report = prepareContainer(
            container,
            usesCloudSync: usesCloudSync,
            lastSchemaVersion: lastSchemaVersion
        )

        let syncSummary = SyncPreparation.prepare(context: container.mainContext)
        report.syncPreparationSummary = syncSummary

        await EpisodeCatalog.shared.refreshManagedCatalogsIfNeeded()
        ensureBundledCollectionExists(container: container)

        userDefaults.set(currentSchemaVersion, forKey: schemaVersionKey)
        AppModelContainerFactory.removePreMigrationBackup()

        bootstrapLogger.info("Bootstrap completed: \(report.logDescription, privacy: .public)")
        return report
    }

    /// Pre-dismisses feature-announcement banners on a genuine fresh install so that
    /// "new feature" banners only reach users who actually updated from an older
    /// version. A fresh install is recognised by the absence of a recorded schema
    /// version combined with an empty library — this deliberately still shows the
    /// announcement to pre-versioning upgraders, who carry data.
    static func suppressFeatureAnnouncementsIfFreshInstall(
        lastSchemaVersion: Int,
        libraryIsEmpty: Bool,
        userDefaults: UserDefaults
    ) {
        guard lastSchemaVersion == 0, libraryIsEmpty else { return }
        FeatureAnnouncement.markSeen(in: userDefaults)
    }

    @MainActor
    private static func prepareContainer(
        _ container: ModelContainer,
        usesCloudSync: Bool,
        lastSchemaVersion: Int
    ) -> BootstrapReport {
        var report = BootstrapReport()

        report.seededMoods = seedMoodsIfNeeded(container: container)
        report.seededCollections = seedCollectionsIfNeeded(container: container)
        ensureBundledCollectionExists(container: container)
        report.assignedOrphanEpisodes = assignMissingCollectionsIfNeeded(container: container)

        if usesCloudSync {
            repairCloudSyncReadinessIfNeeded(container: container)
        }

        if lastSchemaVersion < 2 {
            report.repairedPostMigrationIDs = repairPostMigrationIfNeeded(container: container)
        }

        return report
    }

    @MainActor
    private static func attemptAutomaticCloudMigrationIfNeeded(
        containerSet: AppModelContainerSet,
        userDefaults: UserDefaults,
        lastSchemaVersion: Int,
        report: inout BootstrapReport
    ) {
        let readiness = SyncMigrationReadinessEvaluator.evaluate(
            containerSet: containerSet,
            userDefaults: userDefaults
        )

        guard readiness.canAttemptMigration,
              let localContainer = containerSet.localPersistent,
              let cloudContainer = containerSet.cloudPersistent
        else {
            if attemptCompletedMigrationRepairIfNeeded(
                readiness: readiness,
                containerSet: containerSet,
                userDefaults: userDefaults,
                lastSchemaVersion: lastSchemaVersion,
                report: &report
            ) {
                return
            }

            let statusMessage: String
            if readiness.hasCompletedMigration {
                statusMessage = "Automatische Cloud-Migration bereits abgeschlossen."
            } else if !readiness.hasCloudPersistentContainer {
                statusMessage = "Automatische Cloud-Migration übersprungen: Cloud-Ziel ist nicht verfügbar."
            } else if !readiness.hasLocalPersistentContainer {
                statusMessage = "Automatische Cloud-Migration übersprungen: lokaler Container ist nicht verfügbar."
            } else if !readiness.hasLocalData {
                statusMessage = "Automatische Cloud-Migration übersprungen: keine lokalen Daten gefunden."
            } else if !readiness.localValidationIssues.isEmpty {
                statusMessage = "Automatische Cloud-Migration übersprungen: \(readiness.localValidationIssues.count) Validierungshinweise im lokalen Bestand."
            } else {
                statusMessage = "Automatische Cloud-Migration übersprungen."
            }

            userDefaults.set(statusMessage, forKey: automaticCloudMigrationStatusKey)
            report.cloudMigrationStatus = statusMessage

            bootstrapLogger.info(
                "Automatic cloud migration skipped: completed=\(readiness.hasCompletedMigration, privacy: .public), localContainer=\(readiness.hasLocalPersistentContainer, privacy: .public), cloudContainer=\(readiness.hasCloudPersistentContainer, privacy: .public), hasLocalData=\(readiness.hasLocalData, privacy: .public), issues=\(readiness.localValidationIssues.count, privacy: .public)"
            )
            return
        }

        let snapshot = LocalLibrarySnapshot.capture(context: localContainer.mainContext)
        do {
            let migrationReport = try SyncMigrationCoordinator.migrate(
                snapshot: snapshot,
                into: cloudContainer.mainContext,
                userDefaults: userDefaults
            )

            let statusMessage: String
            if migrationReport.validationIssues.isEmpty {
                statusMessage = "Automatische Cloud-Migration erfolgreich: \(migrationReport.migratedEpisodeCount) Folgen, \(migrationReport.migratedUniverseCount) Sammlungen, \(migrationReport.migratedMoodCount) Stimmungen."
            } else {
                statusMessage = "Automatische Cloud-Migration beendet mit \(migrationReport.validationIssues.count) Validierungshinweisen."
            }

            userDefaults.set(statusMessage, forKey: automaticCloudMigrationStatusKey)
            report.cloudMigrationStatus = statusMessage

            bootstrapLogger.info(
                "Automatic cloud migration finished: episodes=\(migrationReport.migratedEpisodeCount, privacy: .public), universes=\(migrationReport.migratedUniverseCount, privacy: .public), moods=\(migrationReport.migratedMoodCount, privacy: .public), issues=\(migrationReport.validationIssues.count, privacy: .public), markedCompleted=\(migrationReport.markedCompleted, privacy: .public)"
            )
        } catch {
            let statusMessage = "Automatische Cloud-Migration fehlgeschlagen: \(error.localizedDescription)"
            userDefaults.set(statusMessage, forKey: automaticCloudMigrationStatusKey)
            report.cloudMigrationStatus = statusMessage
            bootstrapLogger.error("\(statusMessage, privacy: .public)")
        }
    }

    @MainActor
    private static func attemptCompletedMigrationRepairIfNeeded(
        readiness: SyncMigrationReadiness,
        containerSet: AppModelContainerSet,
        userDefaults: UserDefaults,
        lastSchemaVersion: Int,
        report: inout BootstrapReport
    ) -> Bool {
        guard readiness.hasCompletedMigration,
              lastSchemaVersion < currentSchemaVersion,
              !SyncMigrationStateStore.hasCompletedLocalToCloudRepair(userDefaults: userDefaults),
              readiness.hasLocalPersistentContainer,
              readiness.hasCloudPersistentContainer,
              readiness.hasLocalData,
              readiness.localValidationIssues.isEmpty,
              let localContainer = containerSet.localPersistent,
              let cloudContainer = containerSet.cloudPersistent else {
            return false
        }

        let localSnapshot = LocalLibrarySnapshot.capture(context: localContainer.mainContext)

        do {
            let repairedCovers = try SyncMigrationCompletedRepairer.repairMissingLocalCovers(
                snapshot: localSnapshot,
                into: cloudContainer.mainContext
            )
            SyncMigrationStateStore.markLocalToCloudRepairCompleted(userDefaults: userDefaults)

            let statusMessage: String
            if repairedCovers > 0 {
                statusMessage = "Automatische Cloud-Migration repariert: \(repairedCovers) Cover ergänzt."
            } else {
                statusMessage = "Automatische Cloud-Migration bereits abgeschlossen; Reparaturprüfung ohne Änderungen."
            }

            userDefaults.set(statusMessage, forKey: automaticCloudMigrationStatusKey)
            report.cloudMigrationStatus = statusMessage

            bootstrapLogger.info(
                "Automatic cloud migration repair finished: repairedCovers=\(repairedCovers, privacy: .public)"
            )
        } catch {
            let statusMessage = "Automatische Cloud-Migration Reparatur fehlgeschlagen: \(error.localizedDescription)"
            userDefaults.set(statusMessage, forKey: automaticCloudMigrationStatusKey)
            report.cloudMigrationStatus = statusMessage
            bootstrapLogger.error("\(statusMessage, privacy: .public)")
        }

        return true
    }

    @discardableResult
    @MainActor
    static func repairPostMigrationIfNeeded(container: ModelContainer) -> Int {
        let context = container.mainContext
        let episodes = (try? context.fetch(FetchDescriptor<Episode>())) ?? []

        var repairedCount = 0
        for episode in episodes where episode.id == UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
            episode.id = UUID()
            repairedCount += 1
        }
        if repairedCount > 0 {
            try? context.save()
        }
        return repairedCount
    }

    @discardableResult
    @MainActor
    static func seedMoodsIfNeeded(container: ModelContainer) -> Bool {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Mood>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return false }

        for suggestion in Mood.defaultSuggestions {
            context.insert(Mood(name: suggestion.name, iconName: suggestion.icon))
        }
        return true
    }

    @discardableResult
    @MainActor
    static func seedCollectionsIfNeeded(container: ModelContainer) -> Bool {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Universe>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return false }

        context.insert(Universe(name: "Allgemein"))
        for universeName in CatalogSourceRegistry.managedSources.map(\.name) {
            context.insert(Universe(name: universeName))
        }
        return true
    }

    @MainActor
    static func ensureBundledCollectionExists(container: ModelContainer) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Universe>()
        let allUniverses = (try? context.fetch(descriptor)) ?? []
        let existingNameKeys = Set(allUniverses.map { $0.name.lowercased() })
        for universeName in CatalogSourceRegistry.managedSources.map(\.name)
            where !existingNameKeys.contains(universeName.lowercased()) {
            context.insert(Universe(name: universeName))
        }
    }

    @discardableResult
    @MainActor
    static func assignMissingCollectionsIfNeeded(container: ModelContainer) -> Int {
        let context = container.mainContext
        guard let defaultUniverse = ensureDefaultUniverse(in: context) else { return 0 }

        let descriptor = FetchDescriptor<Episode>()
        guard let allEpisodes = try? context.fetch(descriptor) else { return 0 }

        var assignedCount = 0
        for episode in allEpisodes where episode.universe == nil {
            episode.universe = defaultUniverse
            assignedCount += 1
        }

        if assignedCount > 0 {
            try? context.save()
        }
        return assignedCount
    }

    @MainActor
    static func repairCloudSyncReadinessIfNeeded(container: ModelContainer) {
        let context = container.mainContext
        let episodes = (try? context.fetch(FetchDescriptor<Episode>())) ?? []

        var didChange = false
        for episode in episodes {
            let before = episode.resolvedSyncKey
            episode.refreshSyncKeyIfPossible()
            didChange = didChange || before != episode.resolvedSyncKey
        }

        if didChange {
            try? context.save()
        }
    }

    @discardableResult
    @MainActor
    static func cleanupOrphanedCovers(container: ModelContainer) -> Int {
        let context = container.mainContext
        let episodes = (try? context.fetch(FetchDescriptor<Episode>())) ?? []
        let knownCoverNames = Set(
            episodes.compactMap { $0.coverImageName }
                .filter { !$0.isEmpty }
        )

        let store = CoverImageStore()
        let removed = store.removeOrphanedFiles(knownCoverNames: knownCoverNames)
        if removed > 0 {
            bootstrapLogger.info("Bootstrap: removed \(removed, privacy: .public) orphaned cover file(s)")
        }
        return removed
    }

    @MainActor
    static func ensureDefaultUniverse(in context: ModelContext) -> Universe? {
        let descriptor = FetchDescriptor<Universe>(
            sortBy: [SortDescriptor(\.name)]
        )
        let universes = (try? context.fetch(descriptor)) ?? []
        if let existingDefault = universes.first(where: {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare("Allgemein") == .orderedSame
        }) {
            return existingDefault
        }

        let newUniverse = Universe(name: "Allgemein")
        context.insert(newUniverse)
        return newUniverse
    }
}
