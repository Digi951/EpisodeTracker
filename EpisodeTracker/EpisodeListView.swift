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
    @State private var yearInReviewSelection: YearInReviewSelection?
    @AppStorage(CatalogUpdateBannerRow.dismissedFingerprintKey) private var dismissedCatalogBannerFingerprint = ""
    @AppStorage(YearInReviewBanner.dismissedYearKey) private var dismissedYearInReviewBannerYear = 0
    @AppStorage(SeasonalContext.accentsEnabledKey) private var seasonalAccentsEnabled = true

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

    /// Das Katalog-Banner, wie es tatsächlich erscheint: geschlossene zählen
    /// nicht, sonst halten sie Hörjahr-Banner und Ankündigung zurück.
    private var visibleCatalogUpdateBanner: CatalogUpdateBannerRecommendation? {
        catalogUpdateBanner.flatMap { $0.fingerprint == dismissedCatalogBannerFingerprint ? nil : $0 }
    }

    /// Badge am Neuigkeiten-Symbol: unabhängig vom `NewsOverviewView`, das seine
    /// eigenen Ereignisse erst beim Öffnen als gesehen markiert. Gleiche
    /// "irgendeine ungesehene Neuigkeit"-Regel wie in `UpNextView` — beide
    /// Einstiege öffnen dieselbe Ansicht, also auch dasselbe Badge-Kriterium.
    private var hasUnseenNews: Bool {
        NewsStore().load().events.contains { $0.seenAt == nil }
    }

    /// Jahr für das Hörjahr-Banner. Gleiche Regel wie die Feature-Ankündigung:
    /// nur ohne Katalog-Banner, Filter und Suche, damit nie zwei Banner
    /// übereinander stehen.
    private var yearInReviewBannerYear: Int? {
        guard EpisodeListOrganizer.shouldShowFeatureAnnouncement(
            hasCatalogBanner: visibleCatalogUpdateBanner != nil,
            hasActiveFilter: controls.hasActiveFilter,
            searchText: controls.searchText
        ) else { return nil }
        return YearInReviewBanner.pendingYear(
            episodes: episodes,
            dismissedYear: dismissedYearInReviewBannerYear,
            accentsEnabled: seasonalAccentsEnabled
        )
    }

    @ViewBuilder
    private var yearInReviewBannerRow: some View {
        if let year = yearInReviewBannerYear {
            YearInReviewBannerRow(
                year: year,
                style: .phone,
                onOpen: {
                    yearInReviewSelection = YearInReviewSelection(year: year)
                    dismissedYearInReviewBannerYear = year
                },
                onDismiss: {
                    withAnimation { dismissedYearInReviewBannerYear = year }
                }
            )
        }
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
                    yearInReviewBannerRow
                    featureAnnouncementRow
                    contentRows
                }
            }
        }
        .environment(\.episodeNumberColumn, EpisodeNumberColumn(episodes: filteredEpisodes))
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
                        // Glocke statt Sparkles: ✨ markiert in der Liste
                        // bereits Sonderfolgen.
                        Image(systemName: "bell")
                    }
                    .accessibilityLabel("Neuigkeiten")
                    // Das Overlay hängt außen am Button - innerhalb des label-Closures
                    // verschluckt die Toolbar es. Der Versatz ist knapp gehalten,
                    // damit der Punkt am Symbol klebt und nicht frei zwischen den
                    // Toolbar-Symbolen schwebt.
                    .overlay(alignment: .topTrailing) {
                        if hasUnseenNews {
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
                NewEpisodeView()
            }
        }
        .sheet(isPresented: $showingNewsOverview) {
            NewsOverviewView(initialFocus: .baldVerfuegbar)
        }
        .sheet(item: $yearInReviewSelection) { selection in
            YearInReviewView(episodes: episodes, year: selection.year)
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
                listenedCount: librarySnapshot.listenedCount
            )
            .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
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
        if yearInReviewBannerYear == nil, EpisodeListOrganizer.shouldShowFeatureAnnouncement(
            hasCatalogBanner: visibleCatalogUpdateBanner != nil,
            hasActiveFilter: controls.hasActiveFilter,
            searchText: controls.searchText
        ) {
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
                        episodeRow(episode, omitsSeriesPrefix: group.isUniverseGroup)
                    }
                    .onDelete { offsets in
                        requestDeleteEpisodes(group.episodes, at: offsets)
                    }
                    .deleteDisabled(isEditing)
                    // Spaltenbreite pro Reihe: Folge 127 einer Reihe schiebt
                    // die einstelligen Nummern der anderen nicht nach rechts.
                    .environment(\.episodeNumberColumn, EpisodeNumberColumn(episodes: group.episodes))
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
    private func episodeRow(_ episode: Episode, omitsSeriesPrefix: Bool = false) -> some View {
        if isEditing {
            EpisodeRowView(episode: episode, anyEpisodeHasCover: anyEpisodeHasCover, omitsSeriesPrefix: omitsSeriesPrefix)
                .tag(episode.persistentModelID)
        } else {
            NavigationLink(value: episode) {
                EpisodeRowView(episode: episode, anyEpisodeHasCover: anyEpisodeHasCover, omitsSeriesPrefix: omitsSeriesPrefix)
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

    @AppStorage(SeasonalContext.accentsEnabledKey) private var seasonalAccentsEnabled = true

    // Bewusst keine eigene ScrollView: diese View ist bereits eine Zeile in
    // der äußeren `List` (siehe `contentRows`) und nimmt damit automatisch
    // an deren Scrollen und an `.contentMargins(.bottom, ...)` teil. Eine
    // zweite, verschachtelte Scroll-Ebene ignoriert diesen Bottom-Inset und
    // lässt den Fußtext hinter der Tab-Bar verschwinden (Paket 6, P6-A;
    // Review vom 08.09.2026, `docs/reviews/2026-09-08/01-erststart.png`).
    var body: some View {
        let accent = SeasonalAccent.current(enabled: seasonalAccentsEnabled)

        VStack(spacing: 24) {
            Image(systemName: "headphones.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .overlay(alignment: .topTrailing) {
                    if let accent {
                        Image(systemName: accent.symbol)
                            .font(.system(size: 22))
                            .foregroundStyle(accent.tint)
                            .offset(x: 6, y: -4)
                            .accessibilityHidden(true)
                    }
                }

            VStack(spacing: 8) {
                Text("Dein HörspielLog ist bereit")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                if let accent {
                    Text(accent.emptyStateHint)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Text("Lege deine erste Folge an. Such sie in deinen Katalogen oder trag sie selbst ein.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                OnboardingStepRow(
                    systemImage: "magnifyingglass",
                    title: "Folge suchen",
                    detail: "Tippe die Nummer oder einen Teil des Titels."
                )
                OnboardingStepRow(
                    systemImage: "hand.tap",
                    title: "Treffer antippen",
                    detail: "Titel, Nummer und Jahr werden übernommen."
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
