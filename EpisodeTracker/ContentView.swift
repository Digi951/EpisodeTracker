import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("libraryTitle") private var libraryTitle: String = "Meine Hörspiele"
    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.system.rawValue
    @AppStorage(AppAccentColor.storageKey) private var appAccentColorRawValue: String = AppAccentColor.defaultValue.rawValue

    private let splitLayoutWidthThreshold = SplitLayoutDecider.defaultWidthThreshold

    private var effectiveLibraryTitle: String {
        let trimmed = libraryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Meine Hörspiele" : trimmed
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    private var appAccentColor: AppAccentColor {
        AppAccentColor.resolved(from: appAccentColorRawValue)
    }

    var body: some View {
        GeometryReader { geometry in
            let usesSplitLayout = shouldUseSplitLayout(for: geometry.size.width)

            Group {
                if usesSplitLayout {
                    ContentPadTabs(libraryTitle: effectiveLibraryTitle)
                } else {
                    ContentPhoneTabs(libraryTitle: effectiveLibraryTitle)
                }
            }
        }
        .tint(appAccentColor.color)
        .preferredColorScheme(appearanceMode.colorScheme)
    }

    private func shouldUseSplitLayout(for width: CGFloat) -> Bool {
        SplitLayoutDecider.shouldUseSplitLayout(
            horizontalSizeClass: horizontalSizeClass,
            width: width,
            threshold: splitLayoutWidthThreshold
        )
    }

}

private struct ContentPhoneTabs: View {
    let libraryTitle: String

    var body: some View {
        TabView {
            PhoneEpisodesRoot(libraryTitle: libraryTitle)
                .tabItem {
                    Label("Folgen", systemImage: "list.number")
                }

            PhoneUpNextRoot()
                .tabItem {
                    Label("Als nächstes", systemImage: "play.circle")
                }

            StatisticsRootTab()
                .tabItem {
                    Label("Statistiken", systemImage: "chart.bar")
                }

            SettingsRootTab()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
        }
    }
}

private struct ContentPadTabs: View {
    let libraryTitle: String

    var body: some View {
        TabView {
            EpisodeSplitView(libraryTitle: libraryTitle)
                .tabItem {
                    Label("Folgen", systemImage: "list.number")
                }

            UpNextSplitView()
                .tabItem {
                    Label("Als nächstes", systemImage: "play.circle")
                }

            StatisticsRootTab()
                .tabItem {
                    Label("Statistiken", systemImage: "chart.bar")
                }

            SettingsRootTab()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
        }
    }
}

private struct PhoneEpisodesRoot: View {
    let libraryTitle: String

    var body: some View {
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
                .navigationDestination(for: SmartListNavigation.self) { destination in
                    switch destination {
                    case .detail(let smartList):
                        SmartListDetailView(smartList: smartList)
                    case .moodPicker:
                        MoodPickerView()
                    case .moodDetail(let mood):
                        SmartListDetailView(smartList: .randomByMood, mood: mood)
                    }
                }
                .navigationTitle(libraryTitle)
        }
    }
}

private struct PhoneUpNextRoot: View {
    var body: some View {
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
                        SmartListDetailView(smartList: .randomByMood, mood: mood)
                    }
                }
                .navigationTitle("Als nächstes")
        }
    }
}

private struct StatisticsRootTab: View {
    var body: some View {
        NavigationStack {
            StatisticsView()
        }
    }
}

private struct SettingsRootTab: View {
    var body: some View {
        NavigationStack {
            SettingsView()
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

    @AppStorage("prefersICloudSync") private var prefersICloudSync = false
    @Binding var selection: Episode?

    @State private var controls = EpisodeListControlsState()
    @State private var deleteState = EpisodeDeleteState()
    @State private var showingDeleteConfirmation = false
    @State private var showingAddEpisode = false
    @State private var selectionController = EpisodeSelectionController()
    @State private var isEditing = false

    private var librarySnapshot: SidebarLibrarySnapshot {
        SidebarLibrarySnapshot(episodes: episodes)
    }

    private var filteredEpisodes: [Episode] {
        EpisodeListOrganizer.filteredAndSortedEpisodes(
            episodes: episodes,
            searchText: controls.searchText,
            filterUniverse: controls.filterUniverse,
            filterMood: nil,
            statusFilter: controls.statusFilter,
            sortOrder: controls.sortOrder
        )
    }

    private var episodeGroups: [EpisodeListGroup] {
        EpisodeListOrganizer.groups(
            for: filteredEpisodes,
            sortOrder: controls.sortOrder,
            filterUniverse: controls.filterUniverse,
            universeCount: universes.count,
            catalogTotalsByUniverse: catalogTotalsByUniverse,
            preferCatalogTotals: prefersCatalogProgressTotals
        )
    }

    private var catalogTotalsByUniverse: [String: Int] {
        Dictionary(
            uniqueKeysWithValues: Dictionary(grouping: EpisodeCatalog.shared.allEntries) {
                AppLocalization.displayName(forUniverseName: $0.collectionName).lowercased()
            }.map { key, entries in
                let uniqueNumbers = Set(entries.map(\.number))
                return (key, uniqueNumbers.count)
            }
        )
    }

    private var anyEpisodeHasCover: Bool {
        episodes.contains { episode in
            episode.coverImageName?.isEmpty == false
        }
    }

    private var groupCollapseScopeKey: String {
        controls.collapseScopeKey(universeCount: universes.count)
    }

    private var collapsedGroupIDs: Set<String> {
        EpisodeGroupCollapseStore.collapsedIDs(
            from: collapsedGroupIDsRaw,
            scopeKey: groupCollapseScopeKey
        )
    }

    private var catalogUpdateBanner: CatalogUpdateBannerRecommendation? {
        guard !isEditing, controls.searchText.isEmpty, !controls.hasActiveFilter else { return nil }
        return EpisodeListOrganizer.catalogUpdateBannerRecommendation(
            newCatalogAvailability: EpisodeCatalog.shared.newCatalogAvailability,
            catalogEpisodeDeltas: EpisodeCatalog.shared.catalogEpisodeDeltas,
            activeCatalogIDs: ActiveCatalogStore().activeIDs
        ) ?? EpisodeCatalog.shared.removedCatalogBanner
    }

    var body: some View {
        Group {
            if isEditing {
                List(selection: $selectionController.selectedIDs) {
                    listContent
                }
                .environment(\.editMode, .constant(.active))
            } else {
                List(selection: $selection) {
                    listContent
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $controls.searchText, prompt: "Folge suchen...")
        .contentMargins(.top, horizontalSizeClass == .regular ? 6 : 0, for: .scrollContent)
        .navigationDestination(for: SmartListNavigation.self) { destination in
            switch destination {
            case .detail(let smartList):
                SmartListDetailView(smartList: smartList, iPadSelection: $selection)
            case .moodPicker:
                MoodPickerView()
            case .moodDetail(let mood):
                SmartListDetailView(
                    smartList: .randomByMood,
                    mood: mood,
                    iPadSelection: $selection
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !episodes.isEmpty {
                    Button(isEditing ? "Fertig" : "Ausw\u{00E4}hlen") {
                        isEditing.toggle()
                        if !isEditing {
                            selectionController.clear()
                        }
                    }
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if isEditing {
                    Button {
                        selectAllVisible()
                    } label: {
                        Text(selectionController.selectAllButtonTitle(visibleEpisodes: filteredEpisodes))
                    }
                } else {
                    EpisodeListSortFilterMenu(
                        controls: $controls,
                        universes: universes,
                        resetsMoodFilter: false
                    )
                    Button {
                        showingAddEpisode = true
                    } label: {
                        Label("Neue Folge", systemImage: "plus")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isEditing && !selectionController.isEmpty {
                Button(role: .destructive) {
                    requestDeleteSelected()
                } label: {
                    Text("\(selectionController.count) Folge\(selectionController.count == 1 ? "" : "n") l\u{00F6}schen")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showingAddEpisode) {
            NavigationStack {
                EpisodeEditView()
            }
        }
        .confirmationDialog(
            deleteState.title,
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("L\u{00F6}schen", role: .destructive) {
                confirmDeleteEpisodes()
                isEditing = false
            }
            Button("Abbrechen", role: .cancel) {
                deleteState.clear()
            }
        } message: {
            Text(deleteState.message(usesCloudSync: prefersICloudSync))
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

    @ViewBuilder
    private var listContent: some View {
        if showsLibrarySnapshot && !episodes.isEmpty {
            CompactLibrarySnapshotView(
                episodeCount: librarySnapshot.episodeCount,
                listenedCount: librarySnapshot.listenedCount,
                openCount: librarySnapshot.openCount,
                totalListens: librarySnapshot.totalListens
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 10, trailing: 10))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }

        CatalogUpdateBannerRow(recommendation: catalogUpdateBanner, style: .sidebar)
        if !controls.hasActiveFilter && controls.searchText.isEmpty {
            AccentColorAnnouncementBannerRow(style: .sidebar)
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
                            episodeRow(episode)
                        }
                        .onDelete { offsets in
                            requestDeleteEpisodes(group.episodes, at: offsets)
                        }
                        .deleteDisabled(isEditing)
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
                episodeRow(episode)
            }
            .onDelete { offsets in
                requestDeleteEpisodes(filteredEpisodes, at: offsets)
            }
            .deleteDisabled(isEditing)
        }
    }

    @ViewBuilder
    private func episodeRow(_ episode: Episode) -> some View {
        if isEditing {
            EpisodeRowView(episode: episode, anyEpisodeHasCover: anyEpisodeHasCover, isInSidebar: true)
                .tag(episode.persistentModelID)
        } else {
            NavigationLink(value: episode) {
                EpisodeRowView(episode: episode, anyEpisodeHasCover: anyEpisodeHasCover, isInSidebar: true)
            }
            .swipeActions(edge: .leading) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        episode.isListened.toggle()
                        if episode.isListened {
                            episode.listenCount += 1
                            episode.lastListenedAt = .now
                        }
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
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        episode.isListened = true
                        episode.listenCount += 1
                        episode.lastListenedAt = .now
                    }
                } label: {
                    Label("Hördurchgang zählen", systemImage: "plus")
                }
                .tint(.blue)

                Button(role: .destructive) {
                    requestDeleteEpisode(episode)
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
                .tint(.red)
            }
        }
    }

    private func requestDeleteEpisode(_ episode: Episode) {
        deleteState.request(episode)
        showingDeleteConfirmation = true
    }

    private func requestDeleteEpisodes(_ list: [Episode], at offsets: IndexSet) {
        deleteState.request(from: list, at: offsets)
        showingDeleteConfirmation = deleteState.isActive
    }

    private func confirmDeleteEpisodes() {
        for episode in deleteState.pendingEpisodes {
            if episode == selection {
                selection = nil
            }
        }
        EpisodeDeleteHelper.delete(deleteState.pendingEpisodes, from: modelContext)
        deleteState.clear()
        selectionController.clear()
    }

    private func selectAllVisible() {
        selectionController.toggleAllVisible(filteredEpisodes)
    }

    private func requestDeleteSelected() {
        let selected = selectionController.selectedEpisodes(from: filteredEpisodes)
        guard !selected.isEmpty else { return }
        deleteState.requestBatch(selected)
        showingDeleteConfirmation = true
    }

    private func isCollapsed(_ group: EpisodeListGroup) -> Bool {
        collapsedGroupIDs.contains(group.id)
    }

    private func toggleGroup(_ group: EpisodeListGroup) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            collapsedGroupIDsRaw = EpisodeGroupCollapseStore.toggle(
                groupID: group.id,
                in: collapsedGroupIDsRaw,
                scopeKey: groupCollapseScopeKey
            )
        }
    }
}

private struct SidebarLibrarySnapshot {
    let episodeCount: Int
    let listenedCount: Int
    let openCount: Int
    let totalListens: Int

    init(episodes: [Episode]) {
        episodeCount = episodes.count
        listenedCount = episodes.filter(\.isListened).count
        openCount = episodeCount - listenedCount
        totalListens = episodes.reduce(0) { $0 + $1.listenCount }
    }
}

private struct UpNextSplitView: View {
    @State private var selectedNavigation: SmartListNavigation?

    var body: some View {
        NavigationSplitView {
            UpNextView(iPadNavSelection: $selectedNavigation)
                .navigationTitle("Als nächstes")
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 360)
        } detail: {
            NavigationStack {
                if let selectedNavigation {
                    detailContent(for: selectedNavigation)
                        .navigationDestination(for: Episode.self) { episode in
                            EpisodeDetailView(episode: episode)
                        }
                        .navigationDestination(for: SmartListNavigation.self) { destination in
                            switch destination {
                            case .moodDetail(let mood):
                                SmartListDetailView(smartList: .randomByMood, mood: mood)
                                    .navigationDestination(for: Episode.self) { episode in
                                        EpisodeDetailView(episode: episode)
                                    }
                            default:
                                EmptyView()
                            }
                        }
                } else {
                    SplitSelectionPlaceholder(
                        title: "Liste auswählen",
                        systemImage: "list.bullet.rectangle",
                        message: "Wähle links eine Liste aus, um Vorschläge und Folgen zu sehen."
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func detailContent(for navigation: SmartListNavigation) -> some View {
        switch navigation {
        case .detail(let smartList):
            SmartListDetailView(smartList: smartList)
        case .moodPicker:
            MoodPickerView()
        case .moodDetail(let mood):
            SmartListDetailView(smartList: .randomByMood, mood: mood)
        }
    }
}

private struct CompactLibrarySnapshotView: View {
    let episodeCount: Int
    let listenedCount: Int
    let openCount: Int
    let totalListens: Int
    @AppStorage(AppAccentColor.storageKey) private var appAccentColorRawValue: String = AppAccentColor.defaultValue.rawValue
    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        guard episodeCount > 0 else { return 0 }
        return Double(listenedCount) / Double(episodeCount)
    }

    private var appAccentColor: AppAccentColor {
        AppAccentColor.resolved(from: appAccentColorRawValue)
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
        .overlay(appAccentColor.color.opacity(colorScheme == .dark ? 0.10 : 0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Hell"
        case .dark: "Dunkel"
        }
    }

    var iconName: String {
        switch self {
        case .system: "circle.righthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Episode.self, Mood.self, Universe.self], inMemory: true)
}
