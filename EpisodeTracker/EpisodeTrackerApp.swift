import SwiftUI
import SwiftData

@main
struct EpisodeTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Episode.self,
            Mood.self,
            Universe.self,
        ])

        let environment = ProcessInfo.processInfo.environment
        let isPreviewProcess =
            environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"

        if isPreviewProcess {
            return EpisodeTrackerApp.makeInMemoryContainer(schema: schema)
        }

        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeDirectoryURL = appSupportURL.appendingPathComponent("EpisodeTracker", isDirectory: true)
        let storeURL = storeDirectoryURL.appendingPathComponent("EpisodeTracker.store")

        try? fileManager.createDirectory(at: storeDirectoryURL, withIntermediateDirectories: true)

        let configuration = ModelConfiguration("Default", schema: schema, url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create persistent ModelContainer at \(storeURL.path): \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { @MainActor in
                    seedMoodsIfNeeded(container: sharedModelContainer)
                    seedCollectionsIfNeeded(container: sharedModelContainer)
                    ensureBundledCollectionExists(container: sharedModelContainer)
                    assignMissingCollectionsIfNeeded(container: sharedModelContainer)
                    await EpisodeCatalog.shared.refreshManagedCatalogsIfNeeded()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    @MainActor
    private func seedMoodsIfNeeded(container: ModelContainer) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Mood>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for suggestion in Mood.defaultSuggestions {
            context.insert(Mood(name: suggestion.name, iconName: suggestion.icon))
        }
    }

    @MainActor
    private func seedCollectionsIfNeeded(container: ModelContainer) {
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
    private func ensureBundledCollectionExists(container: ModelContainer) {
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
    private func assignMissingCollectionsIfNeeded(container: ModelContainer) {
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
    private func ensureDefaultUniverse(in context: ModelContext) -> Universe? {
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

    private static func makeInMemoryContainer(schema: Schema) -> ModelContainer {
        let inMemoryConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [inMemoryConfiguration])
        } catch {
            fatalError("Could not create in-memory ModelContainer: \(error)")
        }
    }
}
