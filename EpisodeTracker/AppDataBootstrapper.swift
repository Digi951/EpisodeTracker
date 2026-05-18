import Foundation
import os.log
import SwiftData

private let bootstrapLogger = Logger(
    subsystem: "com.Digi.EpisodeTracker",
    category: "AppDataBootstrapper"
)

enum AppDataBootstrapper {
    static let schemaVersionKey = "schemaVersion"
    static let currentSchemaVersion = 3
    static let automaticCloudMigrationStatusKey = "syncMigration.automaticStatus"

    @MainActor
    static func bootstrap(
        containerSet: AppModelContainerSet,
        userDefaults: UserDefaults = .standard
    ) async {
        let lastSchemaVersion = userDefaults.integer(forKey: schemaVersionKey)

        if let localContainer = containerSet.localPersistent {
            prepareContainer(
                localContainer,
                usesCloudSync: false,
                lastSchemaVersion: lastSchemaVersion
            )
        }

        let shouldPreparePrimary: Bool
        if let localContainer = containerSet.localPersistent {
            shouldPreparePrimary = containerSet.primary !== localContainer
        } else {
            shouldPreparePrimary = true
        }

        if shouldPreparePrimary {
            prepareContainer(
                containerSet.primary,
                usesCloudSync: containerSet.runtimeMode.usesCloudSync,
                lastSchemaVersion: lastSchemaVersion
            )
        }

        if containerSet.runtimeMode.usesCloudSync {
            attemptAutomaticCloudMigrationIfNeeded(
                containerSet: containerSet,
                userDefaults: userDefaults
            )

            prepareSyncDataIfNeeded(container: containerSet.primary)
            repairCloudSyncReadinessIfNeeded(container: containerSet.primary)
        }

        await EpisodeCatalog.shared.refreshManagedCatalogsIfNeeded()
        ensureBundledCollectionExists(container: containerSet.primary)
        prepareSyncDataIfNeeded(container: containerSet.primary)

        if containerSet.runtimeMode.usesCloudSync {
            repairCloudSyncReadinessIfNeeded(container: containerSet.primary)
        }

        userDefaults.set(currentSchemaVersion, forKey: schemaVersionKey)
        AppModelContainerFactory.removePreMigrationBackup()
    }

    @MainActor
    static func bootstrap(
        container: ModelContainer,
        usesCloudSync: Bool,
        userDefaults: UserDefaults = .standard
    ) async {
        let lastSchemaVersion = userDefaults.integer(forKey: schemaVersionKey)
        prepareContainer(
            container,
            usesCloudSync: usesCloudSync,
            lastSchemaVersion: lastSchemaVersion
        )

        await EpisodeCatalog.shared.refreshManagedCatalogsIfNeeded()
        ensureBundledCollectionExists(container: container)
        prepareSyncDataIfNeeded(container: container)

        if usesCloudSync {
            repairCloudSyncReadinessIfNeeded(container: container)
        }

        userDefaults.set(currentSchemaVersion, forKey: schemaVersionKey)
        AppModelContainerFactory.removePreMigrationBackup()
    }

    @MainActor
    private static func prepareContainer(
        _ container: ModelContainer,
        usesCloudSync: Bool,
        lastSchemaVersion: Int
    ) {
        seedMoodsIfNeeded(container: container)
        seedCollectionsIfNeeded(container: container)
        ensureBundledCollectionExists(container: container)
        assignMissingCollectionsIfNeeded(container: container)
        prepareSyncDataIfNeeded(container: container)

        if usesCloudSync {
            repairCloudSyncReadinessIfNeeded(container: container)
        }

        if lastSchemaVersion < 2 {
            repairPostMigrationIfNeeded(container: container)
        }
    }

    @MainActor
    private static func attemptAutomaticCloudMigrationIfNeeded(
        containerSet: AppModelContainerSet,
        userDefaults: UserDefaults
    ) {
        let readiness = SyncMigrationReadinessEvaluator.evaluate(
            containerSet: containerSet,
            userDefaults: userDefaults
        )

        guard readiness.canAttemptMigration,
              let localContainer = containerSet.localPersistent,
              let cloudContainer = containerSet.cloudPersistent
        else {
            if readiness.hasCompletedMigration {
                userDefaults.set("Automatische Cloud-Migration bereits abgeschlossen.", forKey: automaticCloudMigrationStatusKey)
            } else if !readiness.hasCloudPersistentContainer {
                userDefaults.set("Automatische Cloud-Migration übersprungen: Cloud-Ziel ist nicht verfügbar.", forKey: automaticCloudMigrationStatusKey)
            } else if !readiness.hasLocalPersistentContainer {
                userDefaults.set("Automatische Cloud-Migration übersprungen: lokaler Container ist nicht verfügbar.", forKey: automaticCloudMigrationStatusKey)
            } else if !readiness.hasLocalData {
                userDefaults.set("Automatische Cloud-Migration übersprungen: keine lokalen Daten gefunden.", forKey: automaticCloudMigrationStatusKey)
            } else if !readiness.localValidationIssues.isEmpty {
                userDefaults.set("Automatische Cloud-Migration übersprungen: \(readiness.localValidationIssues.count) Validierungshinweise im lokalen Bestand.", forKey: automaticCloudMigrationStatusKey)
            } else {
                userDefaults.set("Automatische Cloud-Migration übersprungen.", forKey: automaticCloudMigrationStatusKey)
            }

            bootstrapLogger.info(
                "Automatic cloud migration skipped: completed=\(readiness.hasCompletedMigration, privacy: .public), localContainer=\(readiness.hasLocalPersistentContainer, privacy: .public), cloudContainer=\(readiness.hasCloudPersistentContainer, privacy: .public), hasLocalData=\(readiness.hasLocalData, privacy: .public), issues=\(readiness.localValidationIssues.count, privacy: .public)"
            )
            return
        }

        let snapshot = LocalLibrarySnapshot.capture(context: localContainer.mainContext)
        do {
            let report = try SyncMigrationCoordinator.migrate(
                snapshot: snapshot,
                into: cloudContainer.mainContext,
                userDefaults: userDefaults
            )

            if report.validationIssues.isEmpty {
                userDefaults.set(
                    "Automatische Cloud-Migration erfolgreich: \(report.migratedEpisodeCount) Folgen, \(report.migratedUniverseCount) Sammlungen, \(report.migratedMoodCount) Stimmungen.",
                    forKey: automaticCloudMigrationStatusKey
                )
            } else {
                userDefaults.set(
                    "Automatische Cloud-Migration beendet mit \(report.validationIssues.count) Validierungshinweisen.",
                    forKey: automaticCloudMigrationStatusKey
                )
            }

            bootstrapLogger.info(
                "Automatic cloud migration finished: episodes=\(report.migratedEpisodeCount, privacy: .public), universes=\(report.migratedUniverseCount, privacy: .public), moods=\(report.migratedMoodCount, privacy: .public), issues=\(report.validationIssues.count, privacy: .public), markedCompleted=\(report.markedCompleted, privacy: .public)"
            )
        } catch {
            let message = "Automatische Cloud-Migration fehlgeschlagen: \(error.localizedDescription)"
            userDefaults.set(message, forKey: automaticCloudMigrationStatusKey)
            bootstrapLogger.error("\(message, privacy: .public)")
        }
    }

    @MainActor
    static func repairPostMigrationIfNeeded(container: ModelContainer) {
        let context = container.mainContext
        let episodes = (try? context.fetch(FetchDescriptor<Episode>())) ?? []

        var didChange = false
        for episode in episodes where episode.id == UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
            episode.id = UUID()
            didChange = true
        }
        if didChange {
            try? context.save()
        }
    }

    @MainActor
    static func seedMoodsIfNeeded(container: ModelContainer) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Mood>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for suggestion in Mood.defaultSuggestions {
            context.insert(Mood(name: suggestion.name, iconName: suggestion.icon))
        }
    }

    @MainActor
    static func seedCollectionsIfNeeded(container: ModelContainer) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Universe>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        context.insert(Universe(name: "Allgemein"))
        for universeName in CatalogSourceRegistry.managedSources.map(\.name) {
            context.insert(Universe(name: universeName))
        }
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

    @MainActor
    static func assignMissingCollectionsIfNeeded(container: ModelContainer) {
        let context = container.mainContext
        guard let defaultUniverse = ensureDefaultUniverse(in: context) else { return }

        let descriptor = FetchDescriptor<Episode>()
        guard let allEpisodes = try? context.fetch(descriptor) else { return }

        var didChange = false
        for episode in allEpisodes where episode.universe == nil {
            episode.universe = defaultUniverse
            didChange = true
        }

        if didChange {
            try? context.save()
        }
    }

    @MainActor
    static func prepareSyncDataIfNeeded(container: ModelContainer) {
        SyncPreparation.prepare(context: container.mainContext)
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
