import SwiftUI
import SwiftData

struct SavedFilterDetailView: View {
    let filter: SavedFilter
    @Query private var allEpisodes: [Episode]
    @Query(sort: \Mood.name) private var allMoods: [Mood]
    @Query(sort: \Universe.name) private var allUniverses: [Universe]

    private var filteredEpisodes: [Episode] {
        let matchedMood = filter.moodName.flatMap { name in
            allMoods.first { $0.name == name }
        }
        let matchedUniverse = filter.universeName.flatMap { name in
            allUniverses.first { $0.name == name }
        }
        return EpisodeListOrganizer.filteredAndSortedEpisodes(
            episodes: allEpisodes,
            searchText: "",
            filterUniverse: matchedUniverse,
            filterMood: matchedMood,
            statusFilter: filter.resolvedStatusFilter,
            sortOrder: filter.resolvedSortOrder
        )
    }

    private var anyEpisodeHasCover: Bool {
        filteredEpisodes.contains { $0.coverImageName?.isEmpty == false }
    }

    var body: some View {
        List {
            ForEach(filteredEpisodes) { episode in
                NavigationLink(value: episode) {
                    EpisodeRowView(episode: episode, anyEpisodeHasCover: anyEpisodeHasCover)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(filter.name)
        .overlay {
            if filteredEpisodes.isEmpty {
                ContentUnavailableView(
                    String(localized: "SavedFilter.Empty.Title", defaultValue: "Keine Folgen"),
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text(
                        String(localized: "SavedFilter.Empty.Message",
                               defaultValue: "Keine Folgen entsprechen den gespeicherten Filterkriterien.")
                    )
                )
            }
        }
    }
}
