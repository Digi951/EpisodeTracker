import SwiftUI
import SwiftData

@main
struct EpisodeTrackerApp: App {
    private let containerSet: AppModelContainerSet
    @StateObject private var containerAccess: AppContainerAccess
    @State private var syncCoordinator: SyncCoordinator
    @Environment(\.scenePhase) private var scenePhase

    private var usesCloudSync: Bool {
        containerSet.runtimeMode.usesCloudSync
    }

    init() {
        let containerSet = AppModelContainerFactory.makeSharedContainerSet()
        self.containerSet = containerSet
        _containerAccess = StateObject(wrappedValue: AppContainerAccess(containerSet: containerSet))
        _syncCoordinator = State(wrappedValue: SyncCoordinator(
            container: containerSet.primary,
            isEnabled: containerSet.runtimeMode.usesCloudSync
        ))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                WidgetSyncObserverView()
            }
            .task { @MainActor in
                await AppDataBootstrapper.bootstrap(
                    containerSet: containerSet
                )
                syncCoordinator.handleBootstrapComplete()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    syncCoordinator.handleSceneActivation()
                }
            }
            .environmentObject(containerAccess)
        }
        .defaultSize(width: 1180, height: 820)
        .modelContainer(containerSet.primary)
    }
}
