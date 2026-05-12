import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("libraryTitle") private var libraryTitle: String = "Meine Hörspiele"
    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.system.rawValue

    private let splitLayoutWidthThreshold = SplitLayoutDecider.defaultWidthThreshold

    private var effectiveLibraryTitle: String {
        let trimmed = libraryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Meine Hörspiele" : trimmed
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    var body: some View {
        GeometryReader { geometry in
            let usesSplitLayout = shouldUseSplitLayout(for: geometry.size.width)

            Group {
                if usesSplitLayout {
                    iPadBody
                } else {
                    iPhoneBody
                }
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
    }

    private func shouldUseSplitLayout(for width: CGFloat) -> Bool {
        SplitLayoutDecider.shouldUseSplitLayout(
            horizontalSizeClass: horizontalSizeClass,
            width: width,
            threshold: splitLayoutWidthThreshold
        )
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
                UpNextView()
                    .navigationDestination(for: Episode.self) { episode in
                        EpisodeDetailView(episode: episode)
                    }
                    .navigationDestination(for: SmartListNavigation.self) { destination in
                        switch destination {
                        case .detail(let smartList):
                            SmartListDetailView(smartList: smartList)
                        case .moodPicker:
                            MoodPickerView()
                        case .moodDetail(let mood):
                            SmartListDetailView(smartList: .zufaelligNachStimmung, mood: mood)
                        }
                    }
                    .navigationTitle("Als nächstes")
            }
            .tabItem {
                Label("Als nächstes", systemImage: "play.circle")
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

            UpNextSplitView()
                .tabItem {
                    Label("Als nächstes", systemImage: "play.circle")
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
                    SplitSelectionPlaceholder(
                        title: "Folge auswählen",
                        systemImage: "list.bullet.rectangle",
                        message: "Wähle links eine Folge aus, um Details, Bewertung und Notizen zu sehen."
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var iPadEpisodeList: some View {
        IPadEpisodeListView(selection: $selectedEpisode)
            .navigationTitle(libraryTitle)
            .navigationSplitViewColumnWidth(min: 320, ideal: 340, max: 380)
    }
}

private struct IPadEpisodeListView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @AppStorage("showsLibrarySnapshot") private var showsLibrarySnapshot = true
    @AppStorage("collapsedEpisodeGroupIDs") private var collapsedGroupIDsRaw = ""
    @AppStorage("prefersCatalogProgressTotals") private var prefersCatalogProgressTotals = true
    @Query(sort: \Episode.episodeNumber) private var episodes: [Episode]
    @Query(sort: \Universe.name) private var universes: [Universe]

    @Binding var selection: Episode?

    @State private var searchText = ""
    @State private var filterUniverse: Universe?
    @State private var statusFilter: EpisodeStatusFilter = .all
    @State private var sortOrder: EpisodeListView.SortOrder = .number
    @State private var pendingDeleteEpisodes: [Episode] = []
    @State private var showingDeleteConfirmation = false
    @State private var showingAddEpisode = false

    private var filteredEpisodes: [Episode] {
        EpisodeListOrganizer.filteredAndSortedEpisodes(
            episodes: episodes,
            searchText: searchText,
            filterUniverse: filterUniverse,
            filterMood: nil,
            statusFilter: statusFilter,
            sortOrder: sortOrder
        )
    }

    private var episodeGroups: [EpisodeListGroup] {
        EpisodeListOrganizer.groups(
            for: filteredEpisodes,
            sortOrder: sortOrder,
            filterUniverse: filterUniverse,
            universeCount: universes.count,
            catalogTotalsByUniverse: catalogTotalsByUniverse,
            preferCatalogTotals: prefersCatalogProgressTotals
        )
    }

    private var catalogTotalsByUniverse: [String: Int] {
        Dictionary(
            uniqueKeysWithValues: Dictionary(grouping: EpisodeCatalog.shared.allEntries) {
                ($0.collectionName ?? "Allgemein").lowercased()
            }.map { key, entries in
                let uniqueNumbers = Set(entries.map(\.number))
                return (key, uniqueNumbers.count)
            }
        )
    }

    private var hasActiveFilter: Bool {
        filterUniverse != nil || statusFilter != .all
    }

    private var groupCollapseScopeKey: String {
        EpisodeGroupCollapseStore.scopeKey(
            sortOrder: sortOrder.rawValue,
            filterUniverseName: filterUniverse?.name,
            statusFilter: statusFilter,
            isMultiUniverse: filterUniverse == nil && universes.count > 1
        )
    }

    private var collapsedGroupState: [String: Set<String>] {
        EpisodeGroupCollapseStore.decode(collapsedGroupIDsRaw)
    }

    private var collapsedGroupIDs: Set<String> {
        collapsedGroupState[groupCollapseScopeKey] ?? []
    }

    private var listenedCount: Int {
        episodes.filter(\.isListened).count
    }

    private var openCount: Int {
        episodes.count - listenedCount
    }

    private var totalListens: Int {
        episodes.reduce(0) { $0 + $1.listenCount }
    }

    var body: some View {
        List(selection: $selection) {
            if showsLibrarySnapshot && !episodes.isEmpty {
                CompactLibrarySnapshotView(
                    episodeCount: episodes.count,
                    listenedCount: listenedCount,
                    openCount: openCount,
                    totalListens: totalListens
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 10, trailing: 10))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if filteredEpisodes.isEmpty {
                ContentUnavailableView {
                    Label(episodes.isEmpty ? "Noch keine Folgen" : "Nichts gefunden", systemImage: "magnifyingglass")
                } description: {
                    Text(episodes.isEmpty ? "Lege deine erste Folge an." : "Passe Suche oder Filter an.")
                }
                .listRowInsets(EdgeInsets(top: 18, leading: 10, bottom: 12, trailing: 10))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else if !episodeGroups.isEmpty {
                ForEach(episodeGroups) { group in
                    Section {
                        if !isCollapsed(group) {
                            ForEach(group.episodes) { episode in
                                episodeNavigationLink(episode)
                            }
                            .onDelete { offsets in
                                requestDeleteEpisodes(group.episodes, at: offsets)
                            }
                        }
                    } header: {
                        EpisodeGroupHeader(
                            group: group,
                            isCollapsed: isCollapsed(group)
                        ) {
                            toggleGroup(group)
                        }
                    }
                }
            } else {
                ForEach(filteredEpisodes) { episode in
                    episodeNavigationLink(episode)
                }
                .onDelete { offsets in
                    requestDeleteEpisodes(filteredEpisodes, at: offsets)
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "Folge suchen…")
        .contentMargins(.top, horizontalSizeClass == .regular ? 6 : 0, for: .scrollContent)
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
            Button {
                sortOrder = .releaseYear
            } label: {
                sortingLabel("Erscheinungsjahr", isSelected: sortOrder == .releaseYear)
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
            Menu("Status") {
                ForEach(EpisodeStatusFilter.allCases, id: \.self) { filter in
                    Button {
                        statusFilter = filter
                    } label: {
                        sortingLabel(filter.rawValue, isSelected: statusFilter == filter)
                    }
                }
            }
            if hasActiveFilter {
                Button("Filter zurücksetzen", role: .destructive) {
                    filterUniverse = nil
                    statusFilter = .all
                }
            }
        } label: {
            Label("Sortieren und filtern", systemImage: "arrow.up.arrow.down")
        }
    }

    private func episodeNavigationLink(_ episode: Episode) -> some View {
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
                    episode.isListened ? "Nochmal" : "Gehört",
                    systemImage: episode.isListened ? "arrow.counterclockwise" : "ear"
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

    private func isCollapsed(_ group: EpisodeListGroup) -> Bool {
        collapsedGroupIDs.contains(group.id)
    }

    private func toggleGroup(_ group: EpisodeListGroup) {
        var state = collapsedGroupState
        var ids = state[groupCollapseScopeKey] ?? []
        if ids.contains(group.id) {
            ids.remove(group.id)
        } else {
            ids.insert(group.id)
        }
        state[groupCollapseScopeKey] = ids
        collapsedGroupIDsRaw = EpisodeGroupCollapseStore.encode(state)
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

private struct UpNextSplitView: View {
    @State private var selectedEpisode: Episode?

    var body: some View {
        NavigationSplitView {
            NavigationStack {
                UpNextView()
                    .navigationDestination(for: SmartListNavigation.self) { destination in
                        switch destination {
                        case .detail(let smartList):
                            SmartListDetailView(
                                smartList: smartList,
                                iPadSelection: $selectedEpisode
                            )
                        case .moodPicker:
                            MoodPickerView()
                        case .moodDetail(let mood):
                            SmartListDetailView(
                                smartList: .zufaelligNachStimmung,
                                mood: mood,
                                iPadSelection: $selectedEpisode
                            )
                        }
                    }
                    .navigationTitle("Als nächstes")
            }
            .navigationSplitViewColumnWidth(min: 320, ideal: 340, max: 380)
        } detail: {
            NavigationStack {
                if let selectedEpisode {
                    EpisodeDetailView(episode: selectedEpisode)
                } else {
                    SplitSelectionPlaceholder(
                        title: "Folge auswählen",
                        systemImage: "list.bullet.rectangle",
                        message: "Wähle links eine Liste oder Folge aus, um Details, Bewertung und Notizen zu sehen."
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private struct CompactLibrarySnapshotView: View {
    let episodeCount: Int
    let listenedCount: Int
    let openCount: Int
    let totalListens: Int

    private var progress: Double {
        guard episodeCount > 0 else { return 0 }
        return Double(listenedCount) / Double(episodeCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Hörstand")
                    .font(.headline)
                Spacer()
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
            }

            ProgressView(value: progress)

            HStack(spacing: 10) {
                CompactSidebarMetric(value: "\(episodeCount)", label: "Folgen")
                CompactSidebarMetric(value: "\(openCount)", label: "Offen")
                CompactSidebarMetric(value: "\(totalListens)", label: "Hörgänge")
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CompactSidebarMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SplitSelectionPlaceholder: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity, minHeight: 320, alignment: .center)
        .padding(.horizontal, 32)
    }
}

enum SplitLayoutDecider {
    static let defaultWidthThreshold: CGFloat = 780

    static func shouldUseSplitLayout(
        horizontalSizeClass: UserInterfaceSizeClass?,
        width: CGFloat,
        threshold: CGFloat = defaultWidthThreshold
    ) -> Bool {
        horizontalSizeClass == .regular || width >= threshold
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
