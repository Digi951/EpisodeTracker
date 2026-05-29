import SwiftUI
import SwiftData
import WidgetKit

@main
struct EpisodeTrackerApp: App {
    private let containerSet: AppModelContainerSet
    @StateObject private var containerAccess: AppContainerAccess
    @State private var syncCoordinator: SyncCoordinator
    @State private var widgetSnapshotCoordinator = WidgetSnapshotCoordinator()
    @AppStorage(AppAccentColor.storageKey) private var appAccentColorRawValue = AppAccentColor.defaultValue.rawValue
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
                WidgetSyncObserverView(coordinator: widgetSnapshotCoordinator)
            }
            .task { @MainActor in
                AppAccentColor.mirrorToAppGroup(rawValue: appAccentColorRawValue)
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
            .onChange(of: appAccentColorRawValue) { _, newValue in
                AppAccentColor.mirrorToAppGroup(rawValue: newValue)
                WidgetCenter.shared.reloadAllTimelines()
            }
            .environmentObject(containerAccess)
        }
        .defaultSize(width: 1180, height: 820)
        .modelContainer(containerSet.primary)
    }
}
