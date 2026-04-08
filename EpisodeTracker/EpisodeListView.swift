import SwiftUI
import SwiftData

struct EpisodeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Episode.episodeNumber) private var episodes: [Episode]
    @Query(sort: \Mood.name) private var moods: [Mood]
    @Query(sort: \Universe.name) private var universes: [Universe]

    @State private var searchText = ""
    @State private var filterMood: Mood?
    @State private var filterUniverse: Universe?
    @State private var filterListened: ListenedFilter = .all
    @State private var sortOrder: SortOrder = .number

    enum ListenedFilter: String, CaseIterable {
        case all = "Alle"
        case listened = "Gehört"
        case unlistened = "Nicht gehört"
    }

    enum SortOrder: String, CaseIterable {
        case number = "Nummer"
        case title = "Titel"
        case rating = "Bewertung"
    }

    private struct EpisodeGroup: Identifiable {
        let title: String
        let episodes: [Episode]
        var id: String { title }
    }

    private var filteredEpisodes: [Episode] {
        var result = episodes

        if !searchText.isEmpty {
            result = result.filter { episode in
                episode.title.localizedCaseInsensitiveContains(searchText)
                || String(episode.episodeNumber).contains(searchText)
            }
        }

        if let filterUniverse {
            result = result.filter { $0.universe == filterUniverse }
        }

        switch filterListened {
        case .all: break
        case .listened: result = result.filter(\.isListened)
        case .unlistened: result = result.filter { !$0.isListened }
        }

        if let filterMood {
            result = result.filter { $0.moods.contains(filterMood) }
        }

        switch sortOrder {
        case .number:
            result.sort { $0.episodeNumber < $1.episodeNumber }
        case .title:
            result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .rating:
            result.sort { ($0.rating ?? 0) > ($1.rating ?? 0) }
        }

        return result
    }

    private var shouldShowUniverseSections: Bool {
        filterUniverse == nil && universes.count > 1
    }

    private var episodeGroups: [EpisodeGroup] {
        let grouped = Dictionary(grouping: filteredEpisodes) { episode in
            episode.universe?.name ?? "Allgemein"
        }
        return grouped.keys.sorted().map { key in
            EpisodeGroup(title: key, episodes: grouped[key] ?? [])
        }
    }

    private var hasActiveFilter: Bool {
        filterListened != .all || filterMood != nil || filterUniverse != nil
    }

    var body: some View {
        List {
            if !moods.isEmpty {
                MoodFilterBar(moods: moods, selection: $filterMood)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if shouldShowUniverseSections {
                ForEach(episodeGroups) { group in
                    Section(group.title) {
                        ForEach(group.episodes) { episode in
                            episodeRow(episode)
                        }
                        .onDelete { offsets in
                            deleteEpisodes(group.episodes, at: offsets)
                        }
                    }
                }
            } else {
                ForEach(filteredEpisodes) { episode in
                    episodeRow(episode)
                }
                .onDelete { offsets in
                    deleteEpisodes(filteredEpisodes, at: offsets)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Folge suchen…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: NavigationDestination.addEpisode) {
                    Label("Neue Folge", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Picker("Sortierung", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue)
                        }
                    }
                    Picker("Gehört-Status", selection: $filterListened) {
                        ForEach(ListenedFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue)
                        }
                    }
                    Menu("Katalog") {
                        Button("Alle") { filterUniverse = nil }
                        ForEach(universes) { universe in
                            Button {
                                filterUniverse = universe
                            } label: {
                                Text(universe.name)
                            }
                        }
                    }
                    if hasActiveFilter {
                        Button("Filter zurücksetzen", role: .destructive) {
                            filterListened = .all
                            filterMood = nil
                            filterUniverse = nil
                        }
                    }
                } label: {
                    Label("Filter", systemImage: hasActiveFilter
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
            }
        }
        .overlay {
            if filteredEpisodes.isEmpty {
                ContentUnavailableView {
                    Label("Keine Folgen", systemImage: "magnifyingglass")
                } description: {
                    if episodes.isEmpty {
                        Text("Füge deine erste Folge hinzu.")
                    } else {
                        Text("Ändere Filter oder Suchbegriff.")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func episodeRow(_ episode: Episode) -> some View {
        NavigationLink(value: episode) {
            EpisodeRowView(episode: episode)
        }
        .swipeActions(edge: .leading) {
            Button {
                episode.isListened.toggle()
                if episode.isListened {
                    episode.listenCount += 1
                    episode.lastListenedAt = .now
                }
            } label: {
                Label(
                    episode.isListened ? "Nicht gehört" : "Gehört",
                    systemImage: episode.isListened ? "ear.fill" : "ear"
                )
            }
            .tint(episode.isListened ? .gray : .green)
        }
        .swipeActions(edge: .trailing) {
            Button {
                episode.isListened = true
                episode.listenCount += 1
                episode.lastListenedAt = .now
            } label: {
                Label("Nochmal gehört", systemImage: "plus")
            }
            .tint(.blue)

            Button(role: .destructive) {
                modelContext.delete(episode)
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    private func deleteEpisodes(_ list: [Episode], at offsets: IndexSet) {
        for index in offsets {
            let episode = list[index]
            modelContext.delete(episode)
        }
    }
}

struct EpisodeRowView: View {
    let episode: Episode
    private var notePreview: String? {
        guard let note = episode.personalNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else {
            return nil
        }

        let separators = CharacterSet(charactersIn: ".!?\n")
        let first = note.components(separatedBy: separators).first?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (first?.isEmpty == false) ? first : note
    }

    var body: some View {
        HStack {
            Text("\(episode.episodeNumber)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(episode.title)
                    .font(.body)
                    .lineLimit(1)

                if let notePreview {
                    Text(notePreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    if let rating = episode.rating {
                        HStack(spacing: 1) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundStyle(star <= rating ? .yellow : .gray.opacity(0.3))
                            }
                        }
                    }
                    if !episode.moods.isEmpty {
                        Text(episode.moods.compactMap(\.iconName).joined())
                            .font(.caption)
                    }
                }
            }

            Spacer()

            if episode.isListened {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Mood Filter Bar

private struct MoodFilterBar: View {
    let moods: [Mood]
    @Binding var selection: Mood?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                MoodChip(label: "Alle", isSelected: selection == nil) {
                    selection = nil
                }
                ForEach(moods) { mood in
                    MoodChip(
                        label: [mood.iconName, mood.name]
                            .compactMap { $0 }
                            .joined(separator: " "),
                        isSelected: selection == mood
                    ) {
                        selection = mood
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }
}

private struct MoodChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary),
                    in: .capsule
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
