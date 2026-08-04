import SwiftUI
import SwiftData

struct EpisodeSplitView: View {
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
                        title: String(localized: "SplitSelection.Episode.Title", defaultValue: "Folge auswählen"),
                        systemImage: "list.bullet.rectangle",
                        message: String(
                            localized: "SplitSelection.Episode.Message",
                            defaultValue: "Wähle links eine Folge aus, um Details, Bewertung und Notizen zu sehen."
                        )
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var iPadEpisodeList: some View {
        IPadEpisodeListView(libraryTitle: libraryTitle, selection: $selectedEpisode)
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
    @Query(sort: \Mood.name) private var moods: [Mood]

    @AppStorage("prefersICloudSync") private var prefersICloudSync = false
    let libraryTitle: String
    @Binding var selection: Episode?

    @State private var controls = EpisodeListControlsState()
    @State private var deleteState = EpisodeDeleteState()
    @State private var showingDeleteConfirmation = false
    @State private var showingAddEpisode = false
    @State private var selectionController = EpisodeSelectionController()
    @State private var isEditing = false
    @State private var showingSaveFilterAlert = false
    @State private var saveFilterName = ""

    private var librarySnapshot: EpisodeLibrarySnapshot {
        EpisodeLibrarySnapshot(episodes: episodes)
    }

    private var filteredEpisodes: [Episode] {
        EpisodeListOrganizer.filteredAndSortedEpisodes(episodes: episodes, controls: controls)
    }

    private var availableUniverseFilters: [Universe] {
        EpisodeListOrganizer.availableUniverseFilters(
            episodes: episodes,
            universes: universes,
            controls: controls
        )
    }

    private var availableMoodFilters: [Mood] {
        EpisodeListOrganizer.availableMoodFilters(episodes: episodes, moods: moods)
    }

    private var episodeGroups: [EpisodeListGroup] {
        EpisodeListOrganizer.groups(
            for: filteredEpisodes,
            controls: controls,
            universeCount: universes.count,
            catalogTotalsByUniverse: catalogTotalsByUniverse,
            preferCatalogTotals: prefersCatalogProgressTotals
        )
    }

    private var catalogTotalsByUniverse: [String: Int] {
        EpisodeListOrganizer.catalogTotalsByUniverse(entries: EpisodeCatalog.shared.allEntries)
    }

    private var anyEpisodeHasCover: Bool {
        EpisodeListOrganizer.anyEpisodeHasCover(episodes: episodes)
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
            case .savedFilter(let filter):
                SavedFilterDetailView(filter: filter)
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
                        universes: availableUniverseFilters,
                        resetsMoodFilter: false,
                        onSaveFilter: {
                            saveFilterName = ""
                            showingSaveFilterAlert = true
                        }
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
        .saveFilterAlert(
            isPresented: $showingSaveFilterAlert,
            filterName: $saveFilterName,
            controls: controls
        )
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
        iPadLibraryHeader

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

        moodFilterRow

        CatalogUpdateBannerRow(recommendation: catalogUpdateBanner, style: .sidebar)
        if !controls.hasActiveFilter && controls.searchText.isEmpty {
            FeatureAnnouncementBannerRow(style: .sidebar, libraryIsEmpty: episodes.isEmpty)
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
    private var moodFilterRow: some View {
        if !availableMoodFilters.isEmpty || controls.filterMood != nil {
            MoodFilterBar(moods: availableMoodFilters, selection: $controls.filterMood)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
    }

    private var iPadLibraryHeader: some View {
        Text(libraryTitle)
            .font(.title2.weight(.bold))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 6, trailing: 12))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
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
                        episode.isListened = true
                        episode.listenCount += 1
                        episode.lastListenedAt = .now
                        episode.listenStatusUpdatedAt = .now
                        if episode.isBookmarked {
                            episode.isBookmarked = false
                            episode.bookmarkedUpdatedAt = .now
                        }
                    }
                } label: {
                    Label("Durchgang +1", systemImage: "plus")
                }
                .tint(.green)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        episode.isListened.toggle()
                        if episode.isListened {
                            episode.listenCount += 1
                            episode.lastListenedAt = .now
                            if episode.isBookmarked {
                                episode.isBookmarked = false
                                episode.bookmarkedUpdatedAt = .now
                            }
                        }
                        episode.listenStatusUpdatedAt = .now
                    }
                } label: {
                    Label(
                        episode.isListened ? "Nochmal" : "Gehört",
                        systemImage: episode.isListened ? "arrow.counterclockwise" : "ear"
                    )
                }
                .tint(.blue)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    requestDeleteEpisode(episode)
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
                .tint(.red)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        episode.isHidden.toggle()
                        episode.hiddenUpdatedAt = .now
                    }
                } label: {
                    Label(
                        episode.isHidden ? "Einblenden" : "Ausblenden",
                        systemImage: episode.isHidden ? "eye" : "eye.slash"
                    )
                }
                .tint(.orange)
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
