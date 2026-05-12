import SwiftUI
import SwiftData

@main
struct EpisodeTrackerApp: App {
    var sharedModelContainer: ModelContainer = AppModelContainerFactory.makeSharedContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { @MainActor in
                    await AppDataBootstrapper.bootstrap(container: sharedModelContainer)
                }
        }
        .defaultSize(width: 1180, height: 820)
        .modelContainer(sharedModelContainer)
    }
}
