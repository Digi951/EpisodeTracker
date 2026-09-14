import SwiftUI
import SwiftData

struct EpisodeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Episode.episodeNumber) private var episodes: [Episode]
    @Query(sort: \Mood.name) private var moods: [Mood]
    @Query(sort: \Universe.name) private var universes: [Universe]
    @AppStorage("showsLibrarySnapshot") private var showsLibrarySnapshot = true
    @AppStorage("collapsedEpisodeGroupIDs") private var collapsedGroupIDsRaw = ""
    @AppStorage("prefersCatalogProgressTotals") private var prefersCatalogProgressTotals = true
    @AppStorage("prefersICloudSync") private var prefersICloudSync = false

    @State private var controls = EpisodeListControlsState()
    @State private var deleteState = EpisodeDeleteState()
    @State private var showingDeleteConfirmation = false
    @State private var selectionController = EpisodeSelectionController()
    @State private var isEditing = false
    @State private var showingAddEpisode = false
    @State private var showingSaveFilterAlert = false
    @State private var saveFilterName = ""
    @State private var showingNewsOverview = false

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

    private var shouldShowUniverseSections: Bool {
        !episodeGroups.isEmpty
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

    private var availableMoodFilters: [Mood] {
        EpisodeListOrganizer.availableMoodFilters(episodes: episodes, moods: moods)
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

    /// Badge am Kalender-Symbol: unabhängig vom `NewsOverviewView`, das seine
    /// eigenen Ereignisse erst beim Öffnen als gesehen markiert.
    private var hasUnseenUpcomingNews: Bool {
        NewsStore().load().events.contains { $0.kind == .upcoming && $0.seenAt == nil }
    }

    var body: some View {
        Group {
            if isEditing {
                List(selection: $selectionController.selectedIDs) {
                    librarySnapshotRow
                    moodFilterRow
                    CatalogUpdateBannerRow(recommendation: catalogUpdateBanner, style: .phone)
                    contentRows
                }
                .environment(\.editMode, .constant(.active))
            } else {
                List {
                    librarySnapshotRow
                    moodFilterRow
                    CatalogUpdateBannerRow(recommendation: catalogUpdateBanner, style: .phone)
                    featureAnnouncementRow
                    contentRows
                }
            }
        }
        .searchable(text: $controls.searchText, prompt: "Folge suchen...")
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
            if isEditing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        selectAllVisible()
                    } label: {
                        Text(selectionController.selectAllButtonTitle(visibleEpisodes: filteredEpisodes))
                    }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewsOverview = true
                    } label: {
                        // Eingebautes Symbol-Badge statt eines eigenen Overlays: das
                        // sitzt immer am Glyph, egal wie groß der Button-Rahmen ist,
                        // und skaliert mit Dynamic Type mit.
                        Image(systemName: "sparkles")
                    }
                    .accessibilityLabel("Bald verf\u{00FC}gbar")
                    // Das Overlay hängt außen am Button - innerhalb des label-Closures
                    // verschluckt die Toolbar es. Der Versatz ist knapp gehalten,
                    // damit der Punkt am Symbol klebt und nicht frei zwischen den
                    // Toolbar-Symbolen schwebt.
                    .overlay(alignment: .topTrailing) {
                        if hasUnseenUpcomingNews {
                            Circle()
                                .fill(.red)
                                .frame(width: 7, height: 7)
                                .offset(x: -6, y: 6)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EpisodeListSortFilterMenu(
                        controls: $controls,
                        universes: availableUniverseFilters,
                        onSaveFilter: {
                            saveFilterName = ""
                            showingSaveFilterAlert = true
                        }
                    )
                }
            }
        }
        .contentMargins(.bottom, isEditing ? 0 : 80, for: .scrollContent)
        .safeAreaInset(edge: .bottom) {
            bottomActionInset
        }
        .overlay(alignment: .bottomTrailing) {
            if EpisodeListOrganizer.shouldShowFloatingAddButton(isEditing: isEditing, isLibraryEmpty: episodes.isEmpty) {
                FloatingAddButton {
                    showingAddEpisode = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingAddEpisode) {
            NavigationStack {
                EpisodeEditView()
            }
        }
        .sheet(isPresented: $showingNewsOverview) {
            NewsOverviewView(initialFocus: .baldVerfuegbar)
        }
        .task {
            await EpisodeCatalog.shared.refreshUpcomingReleasesIfNeeded()
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
    }

    @ViewBuilder
    private var bottomActionInset: some View {
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

    @ViewBuilder
    private var librarySnapshotRow: some View {
        if showsLibrarySnapshot && !episodes.isEmpty {
            LibrarySnapshotView(
                episodeCount: librarySnapshot.episodeCount,
                listenedCount: librarySnapshot.listenedCount,
                openCount: librarySnapshot.openCount,
                totalListens: librarySnapshot.totalListens
            )
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
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

    @ViewBuilder
    private var featureAnnouncementRow: some View {
        if !controls.hasActiveFilter && controls.searchText.isEmpty {
            FeatureAnnouncementBannerRow(style: .phone, libraryIsEmpty: episodes.isEmpty)
        }
    }

    @ViewBuilder
    private var contentRows: some View {
        if episodes.isEmpty {
            EmptyLibraryOnboardingView(onAddFirstEpisode: { showingAddEpisode = true })
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        } else if filteredEpisodes.isEmpty {
            EmptyFilteredEpisodesView {
                controls.searchText = ""
                controls.resetFilters()
            }
            .padding(.vertical, 36)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } else if shouldShowUniverseSections {
            groupedEpisodeRows
        } else {
            flatEpisodeRows
        }
    }

    @ViewBuilder
    private var groupedEpisodeRows: some View {
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
    }

    @ViewBuilder
    private var flatEpisodeRows: some View {
        ForEach(filteredEpisodes) { episode in
            episodeRow(episode)
        }
        .onDelete { offsets in
            requestDeleteEpisodes(filteredEpisodes, at: offsets)
        }
        .deleteDisabled(isEditing)
    }

    @ViewBuilder
    private func episodeRow(_ episode: Episode) -> some View {
        if isEditing {
            EpisodeRowView(episode: episode, anyEpisodeHasCover: anyEpisodeHasCover)
                .tag(episode.persistentModelID)
        } else {
            NavigationLink(value: episode) {
                EpisodeRowView(episode: episode, anyEpisodeHasCover: anyEpisodeHasCover)
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

private struct EmptyFilteredEpisodesView: View {
    let onReset: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Nichts gefunden", systemImage: "magnifyingglass")
        } description: {
            Text("Passe Suche oder Filter an.")
        } actions: {
            Button("Suche und Filter zurücksetzen", action: onReset)
        }
    }
}

private struct EmptyLibraryOnboardingView: View {
    let onAddFirstEpisode: () -> Void

    // Bewusst keine eigene ScrollView: diese View ist bereits eine Zeile in
    // der äußeren `List` (siehe `contentRows`) und nimmt damit automatisch
    // an deren Scrollen und an `.contentMargins(.bottom, ...)` teil. Eine
    // zweite, verschachtelte Scroll-Ebene ignoriert diesen Bottom-Inset und
    // lässt den Fußtext hinter der Tab-Bar verschwinden (Paket 6, P6-A;
    // Review vom 08.09.2026, `docs/reviews/2026-09-08/01-erststart.png`).
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "headphones.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("Dein HörspielLog ist bereit")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("Lege deine erste Folge an. Wenn sie im Katalog steht, wird der Titel automatisch vorgeschlagen.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                OnboardingStepRow(
                    systemImage: "books.vertical",
                    title: "Katalog wählen",
                    detail: "Wähle die Reihe, zu der deine Folge gehört."
                )
                OnboardingStepRow(
                    systemImage: "number",
                    title: "Folgennummer eingeben",
                    detail: "Passende Titel erscheinen als Vorschlag."
                )
                OnboardingStepRow(
                    systemImage: "checkmark.circle",
                    title: "Gehört markieren",
                    detail: "Bewertung und Notiz kannst du direkt ergänzen."
                )
            }
            .padding(.vertical, 4)

            Button(action: onAddFirstEpisode) {
                // Text unabhängig vom Icon zentrieren: ein Label als Block zu
                // zentrieren (z. B. via .frame(maxWidth: .infinity) auf dem
                // Label) zentriert Icon+Text zusammen, wodurch der Text durch
                // das linke Icon optisch nach rechts verschoben wirkt. Der
                // ZStack zentriert nur den Text; das Icon liegt unabhängig
                // davon links.
                ZStack {
                    Text("Erste Folge anlegen")
                        .font(.headline)
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.headline)
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Kataloge, Stimmungen und Darstellung kannst du später in den Einstellungen anpassen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 48)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(.background)
    }
}

private struct OnboardingStepRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
