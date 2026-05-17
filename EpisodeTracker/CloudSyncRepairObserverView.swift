import SwiftData
import SwiftUI

struct CloudSyncRepairObserverView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Episode.episodeNumber) private var episodes: [Episode]
    @Query(sort: \Mood.name) private var moods: [Mood]
    @Query(sort: \Universe.name) private var universes: [Universe]

    @State private var isRepairing = false
    @State private var pendingRepairTask: Task<Void, Never>?

    let isEnabled: Bool

    private var syncRepairSignature: String {
        let moodSignature = moods
            .map { mood in
                [
                    mood.id.uuidString,
                    mood.name,
                    mood.iconName ?? "",
                    mood.resolvedSyncKey,
                    String(mood.episodes.count),
                ].joined(separator: "|")
            }
            .joined(separator: "\n")

        let universeSignature = universes
            .map { universe in
                [
                    universe.id.uuidString,
                    universe.name,
                    universe.resolvedSyncKey,
                    String(universe.episodes.count),
                ].joined(separator: "|")
            }
            .joined(separator: "\n")

        let episodeSignature = episodes
            .map { episode in
                [
                    episode.id.uuidString,
                    episode.resolvedSyncKey,
                    episode.universe?.resolvedSyncKey ?? "",
                    episode.moods.map(\.resolvedSyncKey).sorted().joined(separator: ","),
                ].joined(separator: "|")
            }
            .joined(separator: "\n")

        return [moodSignature, universeSignature, episodeSignature].joined(separator: "\n\n")
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                scheduleRepair()
            }
            .onChange(of: syncRepairSignature) { _, _ in
                scheduleRepair()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    scheduleRepair()
                }
            }
            .onDisappear {
                pendingRepairTask?.cancel()
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    @MainActor
    private func scheduleRepair() {
        guard isEnabled else { return }

        pendingRepairTask?.cancel()
        pendingRepairTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            repairIfNeeded()
        }
    }

    @MainActor
    private func repairIfNeeded() {
        guard !isRepairing else { return }

        isRepairing = true
        SyncPreparation.prepare(context: modelContext)
        isRepairing = false
    }
}
