import SwiftData

struct EpisodeSelectionController {
    var selectedIDs: Set<PersistentIdentifier> = []

    var isEmpty: Bool {
        selectedIDs.isEmpty
    }

    var count: Int {
        selectedIDs.count
    }

    mutating func clear() {
        selectedIDs.removeAll()
    }

    mutating func toggleAllVisible(_ episodes: [Episode]) {
        let visibleIDs = Set(episodes.map(\.persistentModelID))
        if selectedIDs == visibleIDs {
            selectedIDs.removeAll()
        } else {
            selectedIDs = visibleIDs
        }
    }

    func selectedEpisodes(from episodes: [Episode]) -> [Episode] {
        episodes.filter { selectedIDs.contains($0.persistentModelID) }
    }

    func selectAllButtonTitle(visibleEpisodes: [Episode]) -> String {
        selectedIDs == Set(visibleEpisodes.map(\.persistentModelID)) ? "Keine" : "Alle"
    }
}
