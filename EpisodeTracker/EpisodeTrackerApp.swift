import SwiftUI
import SwiftData

@main
struct EpisodeTrackerApp: App {
    var sharedModelContainer: ModelContainer = AppModelContainerFactory.makeSharedContainer()
    private let containerMode = AppModelContainerFactory.resolveMode()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { @MainActor in
                    await AppDataBootstrapper.bootstrap(
                        container: sharedModelContainer,
                        usesCloudSync: containerMode.usesCloudSync
                    )
                }
        }
        .defaultSize(width: 1180, height: 820)
        .modelContainer(sharedModelContainer)
    }
}
