import SwiftUI
import SwiftData

struct WidgetSyncObserverView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("libraryTitle") private var libraryTitle: String = "Meine Hörspiele"
    @Query(sort: \Episode.episodeNumber) private var episodes: [Episode]
    @Query(sort: \Universe.name) private var universes: [Universe]

    private var episodeSignature: String {
        episodes.map { episode in
            let universeName = episode.universe?.name ?? ""
            let rating = episode.rating.map(String.init) ?? ""
            let listenedAt = episode.lastListenedAt?.timeIntervalSince1970.description ?? ""
            return [
                episode.id.uuidString,
                String(episode.episodeNumber),
                episode.title,
                String(episode.releaseYear),
                universeName,
                episode.isListened ? "1" : "0",
                rating,
                listenedAt,
            ].joined(separator: "|")
        }
        .joined(separator: "\n")
    }

    private var universeSignature: String {
        universes.map(\.name).joined(separator: "\n")
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                refreshSnapshot()
            }
            .onChange(of: episodeSignature) { _, _ in
                refreshSnapshot()
            }
            .onChange(of: universeSignature) { _, _ in
                refreshSnapshot()
            }
            .onChange(of: libraryTitle) { _, _ in
                refreshSnapshot()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    refreshSnapshot()
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func refreshSnapshot() {
        WidgetSyncStore.writeSnapshot(
            libraryTitle: libraryTitle,
            universes: universes,
            episodes: episodes
        )
    }
}
