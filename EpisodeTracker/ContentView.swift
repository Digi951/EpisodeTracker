import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("libraryTitle") private var libraryTitle: String = "Meine Hörspiele"
    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.system.rawValue

    private var effectiveLibraryTitle: String {
        let trimmed = libraryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Meine Hörspiele" : trimmed
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadBody
            } else {
                iPhoneBody
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
    }

    private var iPhoneBody: some View {
        TabView {
            NavigationStack {
                EpisodeListView()
                    .navigationDestination(for: Episode.self) { episode in
                        EpisodeDetailView(episode: episode)
                    }
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        switch destination {
                        case .episode(let episode):
                            EpisodeDetailView(episode: episode)
                        case .addEpisode:
                            EpisodeEditView()
                        }
                    }
                    .navigationTitle(effectiveLibraryTitle)
            }
            .tabItem {
                Label("Folgen", systemImage: "list.number")
            }

            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("Statistiken", systemImage: "chart.bar")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Einstellungen", systemImage: "gearshape")
            }
        }
    }

    private var iPadBody: some View {
        TabView {
            EpisodeSplitView(libraryTitle: effectiveLibraryTitle)
                .tabItem {
                    Label("Folgen", systemImage: "list.number")
                }

            NavigationStack {
                StatisticsView()
            }
            .tabItem {
                Label("Statistiken", systemImage: "chart.bar")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Einstellungen", systemImage: "gearshape")
            }
        }
    }
}

private struct EpisodeSplitView: View {
    let libraryTitle: String

    @State private var selectedEpisode: Episode?

    var body: some View {
        NavigationSplitView {
            iPadEpisodeList
        } detail: {
            NavigationStack {
                if let selectedEpisode {
                    EpisodeDetailView(episode: selectedEpisode)
                } else {
                    ContentUnavailableView {
                        Label("Folge auswählen", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("Wähle links eine Folge aus, um Details, Bewertung und Notizen zu sehen.")
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var iPadEpisodeList: some View {
        IPadEpisodeListView(selection: $selectedEpisode)
            .navigationTitle(libraryTitle)
    }
}

private struct IPadEpisodeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Episode.episodeNumber) private var episodes: [Episode]
    @Query(sort: \Universe.name) private var universes: [Universe]

    @Binding var selection: Episode?

    @State private var searchText = ""
    @State private var filterUniverse: Universe?
    @State private var sortOrder: EpisodeListView.SortOrder = .number
    @State private var pendingDeleteEpisodes: [Episode] = []
    @State private var showingDeleteConfirmation = false
    @State private var showingAddEpisode = false

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

        switch sortOrder {
        case .recentlyPlayed:
            result.sort {
                switch ($0.lastListenedAt, $1.lastListenedAt) {
                case let (left?, right?):
                    return left > right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return $0.episodeNumber < $1.episodeNumber
                }
            }
        case .number:
            result.sort { $0.episodeNumber < $1.episodeNumber }
        case .title:
            result.sort { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .rating:
            result.sort { ($0.rating ?? 0) > ($1.rating ?? 0) }
        }

        return result
    }

    private var hasActiveFilter: Bool {
        filterUniverse != nil
    }

    var body: some View {
        List(selection: $selection) {
            if filteredEpisodes.isEmpty {
                ContentUnavailableView {
                    Label(episodes.isEmpty ? "Noch keine Folgen" : "Nichts gefunden", systemImage: "magnifyingglass")
                } description: {
                    Text(episodes.isEmpty ? "Lege deine erste Folge an." : "Passe Suche oder Filter an.")
                }
                .listRowSeparator(.hidden)
            } else {
                ForEach(filteredEpisodes) { episode in
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
                            Label("Hördurchgang zählen", systemImage: "plus")
                        }
                        .tint(.blue)

                        Button(role: .destructive) {
                            requestDeleteEpisode(episode)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
                .onDelete { offsets in
                    requestDeleteEpisodes(filteredEpisodes, at: offsets)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Folge suchen…")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                sortAndFilterMenu
                Button {
                    showingAddEpisode = true
                } label: {
                    Label("Neue Folge", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddEpisode) {
            NavigationStack {
                EpisodeEditView()
            }
        }
        .confirmationDialog(
            deleteConfirmationTitle,
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                confirmDeleteEpisodes()
            }
            Button("Abbrechen", role: .cancel) {
                pendingDeleteEpisodes = []
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
        .onAppear {
            if selection == nil {
                selection = filteredEpisodes.first
            }
        }
        .onChange(of: filteredEpisodes) { _, episodes in
            guard let selection else {
                self.selection = episodes.first
                return
            }
            if !episodes.contains(selection) {
                self.selection = episodes.first
            }
        }
    }

    private var sortAndFilterMenu: some View {
        Menu {
            Button {
                sortOrder = .recentlyPlayed
            } label: {
                sortingLabel("Zuletzt gespielt", isSelected: sortOrder == .recentlyPlayed)
            }
            Button {
                sortOrder = .title
            } label: {
                sortingLabel("Titel A-Z", isSelected: sortOrder == .title)
            }
            Button {
                sortOrder = .number
            } label: {
                sortingLabel("Nummer", isSelected: sortOrder == .number)
            }
            Button {
                sortOrder = .rating
            } label: {
                sortingLabel("Bewertung", isSelected: sortOrder == .rating)
            }
            Menu("Katalog") {
                Button {
                    filterUniverse = nil
                } label: {
                    sortingLabel("Alle", isSelected: filterUniverse == nil)
                }
                ForEach(universes) { universe in
                    Button {
                        filterUniverse = universe
                    } label: {
                        sortingLabel(
                            universe.name,
                            isSelected: filterUniverse?.id == universe.id
                        )
                    }
                }
            }
            if hasActiveFilter {
                Button("Filter zurücksetzen", role: .destructive) {
                    filterUniverse = nil
                }
            }
        } label: {
            Label("Sortieren und filtern", systemImage: "arrow.up.arrow.down")
        }
    }

    private var deleteConfirmationTitle: String {
        pendingDeleteEpisodes.count == 1 ? "Folge löschen?" : "\(pendingDeleteEpisodes.count) Folgen löschen?"
    }

    private var deleteConfirmationMessage: String {
        guard pendingDeleteEpisodes.count == 1, let episode = pendingDeleteEpisodes.first else {
            return "Diese Aktion kann nicht rückgängig gemacht werden."
        }

        return "„\(episode.title)“ wird dauerhaft gelöscht. Diese Aktion kann nicht rückgängig gemacht werden."
    }

    private func requestDeleteEpisode(_ episode: Episode) {
        pendingDeleteEpisodes = [episode]
        showingDeleteConfirmation = true
    }

    private func requestDeleteEpisodes(_ list: [Episode], at offsets: IndexSet) {
        pendingDeleteEpisodes = offsets.map { list[$0] }
        showingDeleteConfirmation = !pendingDeleteEpisodes.isEmpty
    }

    private func confirmDeleteEpisodes() {
        for episode in pendingDeleteEpisodes {
            if episode == selection {
                selection = nil
            }
            modelContext.delete(episode)
        }
        pendingDeleteEpisodes = []
    }

    private func sortingLabel(_ text: String, isSelected: Bool) -> some View {
        HStack {
            Text(text)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }
}

enum AppearanceMode: String, CaseIterable {
    case light
    case dark
    case system

    var title: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .system: "System"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Episode.self, Mood.self, Universe.self], inMemory: true)
}
