import SwiftUI
import SwiftData

@main
struct EpisodeTrackerApp: App {
    private let containerSet: AppModelContainerSet
    @StateObject private var containerAccess: AppContainerAccess

    private var usesCloudSync: Bool {
        containerSet.runtimeMode.usesCloudSync
    }

    init() {
        let containerSet = AppModelContainerFactory.makeSharedContainerSet()
        self.containerSet = containerSet
        _containerAccess = StateObject(wrappedValue: AppContainerAccess(containerSet: containerSet))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                WidgetSyncObserverView()
                CloudSyncRepairObserverView(isEnabled: usesCloudSync)
            }
            .task { @MainActor in
                await AppDataBootstrapper.bootstrap(
                    containerSet: containerSet
                )
            }
            .environmentObject(containerAccess)
        }
        .defaultSize(width: 1180, height: 820)
        .modelContainer(containerSet.primary)
    }
}
