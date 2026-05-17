import Foundation
import SwiftData

enum AppDataBootstrapper {
    static let schemaVersionKey = "schemaVersion"
    static let currentSchemaVersion = 3

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
            return
        }

        let snapshot = LocalLibrarySnapshot.capture(context: localContainer.mainContext)
        _ = try? SyncMigrationCoordinator.migrate(
            snapshot: snapshot,
            into: cloudContainer.mainContext,
            userDefaults: userDefaults
        )
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
        if let first = (try? context.fetch(descriptor))?.first {
            return first
        }

        let newUniverse = Universe(name: "Allgemein")
        context.insert(newUniverse)
        return newUniverse
    }
}
