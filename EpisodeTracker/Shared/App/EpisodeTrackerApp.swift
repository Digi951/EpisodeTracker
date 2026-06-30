import SwiftUI
import SwiftData
import WidgetKit

@main
struct EpisodeTrackerApp: App {
    private let containerSet: AppModelContainerSet
    @State private var syncCoordinator: SyncCoordinator
    @State private var widgetSnapshotCoordinator = WidgetSnapshotCoordinator()
    @State private var savedFilterStore = SavedFilterStore()
    @AppStorage(AppAccentColor.storageKey) private var appAccentColorRawValue = AppAccentColor.defaultValue.rawValue
    @Environment(\.scenePhase) private var scenePhase

    private var usesCloudSync: Bool {
        containerSet.runtimeMode.usesCloudSync
    }

    init() {
#if DEBUG
        if UserDefaults.standard.bool(forKey: DemoDataProvider.userDefaultsKey) {
            let demoSet = DemoDataProvider.makeContainerSet()
            self.containerSet = demoSet
            _syncCoordinator = State(wrappedValue: SyncCoordinator(
                container: demoSet.primary,
                isEnabled: false
            ))
            return
        }
#endif
        let containerSet = AppModelContainerFactory.makeSharedContainerSet()
        self.containerSet = containerSet
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
            .environment(\.appContainerSet, containerSet)
            .environment(savedFilterStore)
        }
        .defaultSize(width: 1180, height: 820)
        .modelContainer(containerSet.primary)
    }
}

private struct AppContainerSetKey: EnvironmentKey {
    static let defaultValue: AppModelContainerSet? = nil
}

extension EnvironmentValues {
    var appContainerSet: AppModelContainerSet? {
        get { self[AppContainerSetKey.self] }
        set { self[AppContainerSetKey.self] = newValue }
    }
}
