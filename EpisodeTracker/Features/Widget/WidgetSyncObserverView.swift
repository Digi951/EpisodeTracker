import SwiftUI
import SwiftData

/// Dünner Query-Adapter: hält die SwiftData-Queries für Live-Reaktivität
/// und reicht Änderungen an den Coordinator durch. Keine Snapshot-Logik hier.
struct WidgetSyncObserverView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("libraryTitle") private var libraryTitle: String = "Meine Hörspiele"
    @Query(sort: \Episode.episodeNumber) private var episodes: [Episode]
    @Query(sort: \Universe.name) private var universes: [Universe]

    let coordinator: WidgetSnapshotCoordinator

    private var signature: String {
        WidgetSnapshotCoordinator.signature(
            libraryTitle: libraryTitle,
            universes: universes,
            episodes: episodes
        )
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task { refresh() }
            .onChange(of: signature) { _, _ in refresh() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { refresh() }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func refresh() {
        coordinator.refresh(libraryTitle: libraryTitle, universes: universes, episodes: episodes)
    }
}
