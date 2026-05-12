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

    @State private var controls = EpisodeListControlsState()
    @State private var deleteState = EpisodeDeleteState()
    @State private var showingDeleteConfirmation = false

    private var filteredEpisodes: [Episode] {
        EpisodeListOrganizer.filteredAndSortedEpisodes(
            episodes: episodes,
            searchText: controls.searchText,
            filterUniverse: controls.filterUniverse,
            filterMood: controls.filterMood,
            statusFilter: controls.statusFilter,
            sortOrder: controls.sortOrder
        )
    }

    private var shouldShowUniverseSections: Bool {
        !episodeGroups.isEmpty
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
                ($0.collectionName ?? "Allgemein").lowercased()
            }.map { key, entries in
                let uniqueNumbers = Set(entries.map(\.number))
                return (key, uniqueNumbers.count)
            }
        )
    }

    private var availableMoodFilters: [Mood] {
        moods.filter { mood in
            episodes.contains { episode in
                episode.moods.contains { $0.matches(mood) }
            }
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
        List {
            if showsLibrarySnapshot && !episodes.isEmpty {
                LibrarySnapshotView(
                    episodeCount: episodes.count,
                    listenedCount: listenedCount,
                    openCount: openCount,
                    totalListens: totalListens
                )
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }

            if !availableMoodFilters.isEmpty || controls.filterMood != nil {
                MoodFilterBar(moods: availableMoodFilters, selection: $controls.filterMood)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            if episodes.isEmpty {
                EmptyLibraryOnboardingView()
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else if filteredEpisodes.isEmpty {
                ContentUnavailableView {
                    Label("Nichts gefunden", systemImage: "magnifyingglass")
                } description: {
                    Text("Passe Suche oder Filter an.")
                } actions: {
                    Button("Suche und Filter zurücksetzen") {
                        controls.searchText = ""
                        controls.resetFilters()
                    }
                }
                .padding(.vertical, 36)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else if shouldShowUniverseSections {
                ForEach(episodeGroups) { group in
                    Section {
                        if !isCollapsed(group) {
                            ForEach(group.episodes) { episode in
                                episodeRow(episode)
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
                    episodeRow(episode)
                }
                .onDelete { offsets in
                    requestDeleteEpisodes(filteredEpisodes, at: offsets)
                }
            }
        }
        .searchable(text: $controls.searchText, prompt: "Folge suchen…")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                EpisodeListSortFilterMenu(
                    controls: $controls,
                    universes: universes
                )
                NavigationLink(value: NavigationDestination.addEpisode) {
                    Label("Neue Folge", systemImage: "plus")
                }
            }
        }
        .confirmationDialog(
            deleteState.title,
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                confirmDeleteEpisodes()
            }
            Button("Abbrechen", role: .cancel) {
                deleteState.clear()
            }
        } message: {
            Text(deleteState.message)
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
            modelContext.delete(episode)
        }
        deleteState.clear()
    }

    private func isCollapsed(_ group: EpisodeListGroup) -> Bool {
        collapsedGroupIDs.contains(group.id)
    }

    private func toggleGroup(_ group: EpisodeListGroup) {
        collapsedGroupIDsRaw = EpisodeGroupCollapseStore.toggle(
            groupID: group.id,
            in: collapsedGroupIDsRaw,
            scopeKey: groupCollapseScopeKey
        )
    }
}

struct LibrarySnapshotView: View {
    let episodeCount: Int
    let listenedCount: Int
    let openCount: Int
    let totalListens: Int

    private var progress: Double {
        guard episodeCount > 0 else { return 0 }
        return Double(listenedCount) / Double(episodeCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dein Hörstand")
                        .font(.headline)
                    Text("\(listenedCount) von \(episodeCount) Folgen gehört")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tint)
            }

            ProgressView(value: progress)

            HStack(spacing: 12) {
                SnapshotMetric(value: "\(episodeCount)", label: "Folgen")
                Divider()
                SnapshotMetric(value: "\(openCount)", label: "Offen")
                Divider()
                SnapshotMetric(value: "\(totalListens)", label: "Hördurchgänge")
            }
            .frame(minHeight: 44)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SnapshotMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EmptyLibraryOnboardingView: View {
    var body: some View {
        ScrollView {
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

                NavigationLink(value: NavigationDestination.addEpisode) {
                    Label("Erste Folge anlegen", systemImage: "plus.circle.fill")
                        .font(.headline)
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
        }
        .scrollIndicators(.hidden)
        .background(.background)
    }
}

private struct OnboardingStepRow: View {
    let systemImage: String
    let title: String
    let detail: String

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
