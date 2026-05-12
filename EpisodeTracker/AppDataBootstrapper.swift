import Foundation
import SwiftData

enum AppDataBootstrapper {
    @MainActor
    static func bootstrap(
        container: ModelContainer,
        usesCloudSync: Bool
    ) async {
        seedMoodsIfNeeded(container: container)
        seedCollectionsIfNeeded(container: container)
        ensureBundledCollectionExists(container: container)
        assignMissingCollectionsIfNeeded(container: container)
        prepareSyncDataIfNeeded(container: container)

        if usesCloudSync {
            repairCloudSyncReadinessIfNeeded(container: container)
        }

        await EpisodeCatalog.shared.refreshManagedCatalogsIfNeeded()
        ensureBundledCollectionExists(container: container)
        prepareSyncDataIfNeeded(container: container)

        if usesCloudSync {
            repairCloudSyncReadinessIfNeeded(container: container)
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
