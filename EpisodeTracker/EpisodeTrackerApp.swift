import SwiftUI
import SwiftData

@main
struct EpisodeTrackerApp: App {
    var sharedModelContainer: ModelContainer = AppModelContainerFactory.makeSharedContainer()

    private var usesCloudSync: Bool {
        UserDefaults.standard.string(forKey: AppModelContainerFactory.runtimeModeDebugTitleKey)
            == AppModelContainerMode.cloudPersistent(
                containerIdentifier: AppModelContainerFactory.cloudContainerIdentifier
            ).debugTitle
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task { @MainActor in
                    await AppDataBootstrapper.bootstrap(
                        container: sharedModelContainer,
                        usesCloudSync: usesCloudSync
                    )
                }
        }
        .defaultSize(width: 1180, height: 820)
        .modelContainer(sharedModelContainer)
    }
}
