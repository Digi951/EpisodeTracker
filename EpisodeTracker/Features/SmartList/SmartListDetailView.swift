import SwiftUI
import SwiftData

struct SmartListDetailView: View {
    let smartList: SmartListDefinition
    var mood: Mood?
    var iPadSelection: Binding<Episode?>?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Query private var allEpisodes: [Episode]
    @Query(sort: \Universe.name) private var universes: [Universe]
    @AppStorage("collapsedCatalogSuggestionGroupIDs") private var collapsedCatalogGroupIDsRaw = ""
    @State private var shuffledEpisodes: [Episode]?
    @State private var episodeFilter: EpisodeFilter = .all
    @State private var catalogAddItem: CatalogAddItem?
    @State private var catalogYearFilter: Int?
    @State private var pendingCatalogBulkImport: CatalogBulkImportRequest?

    private var displayedEpisodes: [Episode] {
        if smartList.isRandomList {
            return shuffledEpisodes ?? []
        }
        return smartList.episodes(from: allEpisodes)
    }

    private var catalogSuggestions: [(universeName: String, entry: CatalogEntry)] {
        let all = allMissingCatalogSuggestions
        if let year = catalogYearFilter {
            return all.filter { $0.entry.releaseYear == year }
        }
        return all
    }

    private var allMissingCatalogSuggestions: [(universeName: String, entry: CatalogEntry)] {
        SmartListDefinition.missingCatalogEntries(
            catalogEntries: EpisodeCatalog.shared.allEntries,
            libraryEpisodes: allEpisodes
        )
    }

    private var availableCatalogYears: [Int] {
        let years = Set(allMissingCatalogSuggestions.map(\.entry.releaseYear)).filter { $0 > 0 }
        return years.sorted()
    }

    private var anyEpisodeHasCover: Bool {
        allEpisodes.contains { episode in
            episode.coverImageName?.isEmpty == false
        }
    }

    private var catalogGroups: [CatalogSuggestionGroup] {
        let grouped = Dictionary(grouping: catalogSuggestions, by: \.universeName)
        let allMissingGrouped = Dictionary(grouping: allMissingCatalogSuggestions, by: \.universeName)
        return grouped.keys.sorted().map { universeName in
            CatalogSuggestionGroup(
                universeName: universeName,
                suggestions: grouped[universeName] ?? [],
                allMissingSuggestions: allMissingGrouped[universeName] ?? []
            )
        }
    }

    private var navigationTitle: String {
        if smartList == .randomByMood, let mood {
            return "\(mood.iconName ?? "") \(mood.name)"
        }
        return smartList.displayName
    }

    private var collapsedCatalogGroupIDs: Set<String> {
        Set(
            collapsedCatalogGroupIDsRaw
                .split(separator: "\n")
                .map(String.init)
                .filter { !$0.isEmpty }
        )
    }

    var body: some View {
        List {
            listContent
        }
        .navigationTitle(navigationTitle)
        .listStyle(.insetGrouped)
        .contentMargins(.horizontal, horizontalSizeClass == .regular ? 32 : 0, for: .scrollContent)
        .contentMargins(.top, horizontalSizeClass == .regular ? 12 : 0, for: .scrollContent)
        .toolbar {
            if smartList.isRandomList {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        reshuffle()
                    } label: {
                        Label("Neu würfeln", systemImage: "dice")
                    }
                }
            }
        }
        .onAppear {
            if smartList.isRandomList && shuffledEpisodes == nil {
                reshuffle()
            }
        }
        .onChange(of: episodeFilter) { _, _ in
            reshuffle()
        }
        .onChange(of: availableCatalogYears) { _, years in
            if let year = catalogYearFilter, !years.contains(year) {
                catalogYearFilter = nil
            }
        }
        .sheet(item: $catalogAddItem) { item in
            NavigationStack {
                EpisodeEditView(
                    prefillEntry: item.entry,
                    prefillUniverseName: item.universeName
                )
            }
        }
        .confirmationDialog(
            catalogBulkImportConfirmationTitle,
            isPresented: isShowingCatalogBulkImportConfirmation,
            titleVisibility: .visible,
            actions: catalogBulkImportConfirmationActions,
            message: catalogBulkImportConfirmationMessage
        )
    }

    @ViewBuilder
    private var listContent: some View {
        if smartList.isRandomList {
            SmartListFilterSection(episodeFilter: $episodeFilter)
        }

        if smartList.needsCatalog {
            SmartListCatalogContent(
                availableCatalogYears: availableCatalogYears,
                catalogYearFilter: $catalogYearFilter,
                catalogSuggestions: catalogSuggestions,
                catalogGroups: catalogGroups,
                smartListDisplayName: smartList.displayName,
                emptyStateMessage: smartList.emptyStateMessage,
                isCatalogGroupCollapsed: isCatalogGroupCollapsed,
                onToggleCatalogGroup: toggleCatalogGroup,
                onAddCatalogSuggestion: { suggestion in
                    catalogAddItem = CatalogAddItem(entry: suggestion.entry, universeName: suggestion.universeName)
                },
                onAddCatalogSuggestions: addCatalogSuggestions,
                onConfirmCatalogSuggestions: { universeName, suggestions in
                    pendingCatalogBulkImport = CatalogBulkImportRequest(
                        universeName: universeName,
                        suggestions: suggestions
                    )
                }
            )
        } else if smartList.isRandomList {
            SmartListGroupedEpisodeContent(
                displayedEpisodes: displayedEpisodes,
                smartListDisplayName: smartList.displayName,
                emptyMessage: emptyMessage,
                anyEpisodeHasCover: anyEpisodeHasCover,
                iPadSelection: iPadSelection
            )
        } else {
            SmartListEpisodeContent(
                displayedEpisodes: displayedEpisodes,
                smartListDisplayName: smartList.displayName,
                emptyMessage: emptyMessage,
                anyEpisodeHasCover: anyEpisodeHasCover,
                iPadSelection: iPadSelection
            )
        }
    }

    private var emptyMessage: String {
        if smartList.isRandomList {
            switch episodeFilter {
            case .unlistened: String(localized: "SmartList.Empty.NoUnlistened", defaultValue: "Keine ungehörten Folgen")
            case .listened: String(localized: "SmartList.Empty.NoListened", defaultValue: "Keine gehörten Folgen")
            case .favorites: String(localized: "SmartList.Favorites.Empty", defaultValue: "Noch keine Favoriten markiert")
            case .all: String(localized: "SmartList.Empty.NoEpisodes", defaultValue: "Keine Folgen vorhanden")
            }
        } else if smartList == .randomByMood {
            String(localized: "SmartList.Empty.NoMoodEpisodes", defaultValue: "Keine Folgen mit dieser Stimmung")
        } else {
            smartList.emptyStateMessage
        }
    }

    private func addCatalogSuggestions(_ suggestions: [(universeName: String, entry: CatalogEntry)]) {
        var existingKeys = Set(allEpisodes.map { episodeKey(universeName: $0.universe?.name, number: $0.episodeNumber) })
        var insertedKeys = Set<String>()

        for suggestion in suggestions {
            // SmartList suggestions are number-based; special episodes are handled
            // through the dedicated special catalog/reconciliation path, not here.
            guard let number = suggestion.entry.number else { continue }
            let key = episodeKey(universeName: suggestion.universeName, number: number)
            guard !existingKeys.contains(key),
                  insertedKeys.insert(key).inserted
            else {
                continue
            }

            let universe = universes.first {
                $0.name.caseInsensitiveCompare(suggestion.universeName) == .orderedSame
            }
            let episode = Episode(
                episodeNumber: number,
                title: suggestion.entry.title,
                releaseYear: suggestion.entry.releaseYear,
                universe: universe
            )
            modelContext.insert(episode)
            existingKeys.insert(key)
        }

        try? modelContext.save()
    }

    private func episodeKey(universeName: String?, number: Int) -> String {
        "\(universeName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "")|\(number)"
    }

    private func reshuffle() {
        if smartList == .randomByMood, let mood {
            shuffledEpisodes = SmartListDefinition.episodesForMood(mood, from: allEpisodes, filter: episodeFilter)
        } else if smartList == .random {
            shuffledEpisodes = SmartListDefinition.randomEpisodes(from: allEpisodes, filter: episodeFilter)
        }
    }

    private func isCatalogGroupCollapsed(_ group: CatalogSuggestionGroup) -> Bool {
        collapsedCatalogGroupIDs.contains(group.id)
    }

    private func toggleCatalogGroup(_ group: CatalogSuggestionGroup) {
        var ids = collapsedCatalogGroupIDs
        if ids.contains(group.id) {
            ids.remove(group.id)
        } else {
            ids.insert(group.id)
        }
        collapsedCatalogGroupIDsRaw = ids.sorted().joined(separator: "\n")
    }

    private var isShowingCatalogBulkImportConfirmation: Binding<Bool> {
        Binding {
            pendingCatalogBulkImport != nil
        } set: { isPresented in
            if !isPresented {
                pendingCatalogBulkImport = nil
            }
        }
    }

    private var catalogBulkImportConfirmationTitle: String {
        pendingCatalogBulkImport?.title ?? String(localized: "CatalogImport.ConfirmFallbackTitle", defaultValue: "Folgen übernehmen?")
    }

    @ViewBuilder
    private func catalogBulkImportConfirmationActions() -> some View {
        if let request = pendingCatalogBulkImport {
            Button(request.confirmationButtonTitle) {
                addCatalogSuggestions(request.suggestions)
                pendingCatalogBulkImport = nil
            }
        }

        Button("Abbrechen", role: .cancel) {
            pendingCatalogBulkImport = nil
        }
    }

    @ViewBuilder
    private func catalogBulkImportConfirmationMessage() -> some View {
        if let request = pendingCatalogBulkImport {
            Text(request.message)
        }
    }
}

private struct SmartListFilterSection: View {
    @Binding var episodeFilter: EpisodeFilter

    var body: some View {
        Section {
            Picker("Filter", selection: $episodeFilter) {
                ForEach(EpisodeFilter.allCases) { filter in
                    if let iconName = filter.iconName {
                        Label(filter.displayName, systemImage: iconName).tag(filter)
                    } else {
                        Text(filter.displayName).tag(filter)
                    }
                }
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }
}

private struct SmartListCatalogContent: View {
    let availableCatalogYears: [Int]
    @Binding var catalogYearFilter: Int?
    let catalogSuggestions: [(universeName: String, entry: CatalogEntry)]
    let catalogGroups: [CatalogSuggestionGroup]
    let smartListDisplayName: String
    let emptyStateMessage: String
    let isCatalogGroupCollapsed: (CatalogSuggestionGroup) -> Bool
    let onToggleCatalogGroup: (CatalogSuggestionGroup) -> Void
    let onAddCatalogSuggestion: ((universeName: String, entry: CatalogEntry)) -> Void
    let onAddCatalogSuggestions: ([(universeName: String, entry: CatalogEntry)]) -> Void
    let onConfirmCatalogSuggestions: (String, [(universeName: String, entry: CatalogEntry)]) -> Void

    var body: some View {
        catalogYearFilterSection

        if catalogSuggestions.isEmpty {
            SmartListEmptyState(
                title: smartListDisplayName,
                message: emptyCatalogMessage
            )
        } else {
            Section {
                CatalogBulkImportCard(
                    suggestionCount: catalogSuggestions.count,
                    universeCount: catalogGroups.count
                ) {
                    onAddCatalogSuggestions(catalogSuggestions)
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            ForEach(catalogGroups) { group in
                Section {
                    if !isCatalogGroupCollapsed(group) {
                        ForEach(Array(group.suggestions.enumerated()), id: \.offset) { _, suggestion in
                            CatalogEntryRow(
                                universeName: suggestion.universeName,
                                entry: suggestion.entry
                            ) {
                                onAddCatalogSuggestion(suggestion)
                            }
                        }
                    }
                } header: {
                    CatalogGroupHeader(
                        title: group.universeName,
                        count: group.suggestions.count,
                        isCollapsed: isCatalogGroupCollapsed(group),
                        onImportVisible: {
                            onConfirmCatalogSuggestions(group.universeName, group.suggestions)
                        }
                    ) {
                        onToggleCatalogGroup(group)
                    }
                } footer: {
                    if !isCatalogGroupCollapsed(group) {
                        CatalogGroupFooter(
                            universeName: group.universeName,
                            visibleCount: group.suggestions.count,
                            totalMissingCount: group.allMissingSuggestions.count,
                            action: {
                                onAddCatalogSuggestions(group.allMissingSuggestions)
                            }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var catalogYearFilterSection: some View {
        if !availableCatalogYears.isEmpty {
            Section {
                Picker("Erscheinungsjahr", selection: $catalogYearFilter) {
                    Text("Alle Jahre").tag(Optional<Int>.none)
                    ForEach(availableCatalogYears, id: \.self) { year in
                        Text(String(year)).tag(Optional(year))
                    }
                }
            } header: {
                Text("Filtern")
            } footer: {
                Text("Zeigt nur fehlende Folgen aus dem ausgewählten Erscheinungsjahr. Mit „Alle Jahre“ siehst du wieder alle offenen Katalogvorschläge.")
            }
        }
    }

    private var emptyCatalogMessage: String {
        if let catalogYearFilter {
            return AppLocalization.format("CatalogImport.NoMissingForYear", defaultValue: "Keine fehlenden Folgen aus %d", catalogYearFilter)
        }
        return emptyStateMessage
    }
}

private struct SmartListEpisodeContent: View {
    let displayedEpisodes: [Episode]
    let smartListDisplayName: String
    let emptyMessage: String
    let anyEpisodeHasCover: Bool
    var iPadSelection: Binding<Episode?>?

    var body: some View {
        if displayedEpisodes.isEmpty {
            SmartListEmptyState(
                title: smartListDisplayName,
                message: emptyMessage
            )
        } else {
            ForEach(displayedEpisodes) { episode in
                if let iPadSelection {
                    Button {
                        iPadSelection.wrappedValue = episode
                    } label: {
                        EpisodeRowView(episode: episode, anyEpisodeHasCover: anyEpisodeHasCover)
                    }
                    .listRowBackground(
                        iPadSelection.wrappedValue == episode
                            ? Color.accentColor.opacity(0.12)
                            : nil
                    )
                } else {
                    NavigationLink(value: episode) {
                        EpisodeRowView(episode: episode, anyEpisodeHasCover: anyEpisodeHasCover)
                    }
                }
            }
        }
    }
}

private struct SmartListGroupedEpisodeContent: View {
    let displayedEpisodes: [Episode]
    let smartListDisplayName: String
    let emptyMessage: String
    let anyEpisodeHasCover: Bool
    var iPadSelection: Binding<Episode?>?

    private var groupedEpisodes: [(universeName: String, episodes: [Episode])] {
        let grouped = Dictionary(grouping: displayedEpisodes) {
            AppLocalization.displayName(forUniverseName: $0.universe?.name)
        }
        return grouped.keys.sorted().map { name in
            (universeName: name, episodes: grouped[name]!.sorted { $0.episodeNumber < $1.episodeNumber })
        }
    }

    var body: some View {
        if displayedEpisodes.isEmpty {
            SmartListEmptyState(
                title: smartListDisplayName,
                message: emptyMessage
            )
        } else {
            ForEach(groupedEpisodes, id: \.universeName) { group in
                Section {
                    ForEach(group.episodes) { episode in
                        if let iPadSelection {
                            Button {
                                iPadSelection.wrappedValue = episode
                            } label: {
                                EpisodeRowView(episode: episode, anyEpisodeHasCover: anyEpisodeHasCover)
                            }
                            .listRowBackground(
                                iPadSelection.wrappedValue == episode
                                    ? Color.accentColor.opacity(0.12)
                                    : nil
                            )
                        } else {
                            NavigationLink(value: episode) {
                                EpisodeRowView(episode: episode, anyEpisodeHasCover: anyEpisodeHasCover)
                            }
                        }
                    }
                } header: {
                    Text(group.universeName)
                }
            }
        }
    }
}

private struct SmartListEmptyState: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "tray")
        } description: {
            Text(message)
        }
        .listRowSeparator(.hidden)
    }
}

private struct CatalogSuggestionGroup: Identifiable {
    let universeName: String
    let suggestions: [(universeName: String, entry: CatalogEntry)]
    let allMissingSuggestions: [(universeName: String, entry: CatalogEntry)]

    var id: String { universeName }
}

private struct CatalogBulkImportCard: View {
    let suggestionCount: Int
    let universeCount: Int
    let action: () -> Void

    private var buttonTitle: String {
        suggestionCount == 1
            ? String(localized: "CatalogImport.ImportVisibleOne", defaultValue: "Die sichtbare Folge übernehmen")
            : AppLocalization.format("CatalogImport.ImportVisibleMany", defaultValue: "Alle %d sichtbaren Folgen übernehmen", suggestionCount)
    }

    private var detailText: String {
        if universeCount == 1 {
            return AppLocalization.format("CatalogImport.MissingInOneCatalog", defaultValue: "%d fehlende Folgen in 1 Katalog", suggestionCount)
        }
        return AppLocalization.format("CatalogImport.MissingInManyCatalogs", defaultValue: "%d fehlende Folgen in %d Katalogen", suggestionCount, universeCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(detailText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(action: action) {
                Text(buttonTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Text("Übernimmt nur die aktuell sichtbaren Vorschläge aus dieser Liste.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct CatalogGroupFooter: View {
    let universeName: String
    let visibleCount: Int
    let totalMissingCount: Int
    let action: () -> Void

    private var hiddenCount: Int {
        max(0, totalMissingCount - visibleCount)
    }

    private var buttonTitle: String {
        if totalMissingCount == 1 {
            return String(localized: "CatalogImport.ImportAllFromCatalogOne", defaultValue: "Die fehlende Folge aus dem Katalog übernehmen")
        }
        return AppLocalization.format("CatalogImport.ImportAllFromCatalogMany", defaultValue: "Alle %d fehlenden Folgen aus dem Katalog übernehmen", totalMissingCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.format("CatalogImport.FooterMessage", defaultValue: "Die Vorschläge werden direkt im Katalog \"%@\" angelegt.", universeName))

            if hiddenCount > 0 {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

private struct CatalogGroupHeader: View {
    let title: String
    let count: Int
    let isCollapsed: Bool
    let onImportVisible: () -> Void
    let action: () -> Void

    private var detailText: String {
        count == 1
            ? String(localized: "CatalogImport.VisibleMissingOne", defaultValue: "1 sichtbare fehlende Folge")
            : AppLocalization.format("CatalogImport.VisibleMissingMany", defaultValue: "%d sichtbare fehlende Folgen", count)
    }

    private var importLabel: String {
        count == 1
            ? AppLocalization.format("CatalogImport.AccessibilityImportOneFromCatalog", defaultValue: "Die sichtbare Folge aus %@ übernehmen", title)
            : AppLocalization.format("CatalogImport.AccessibilityImportManyFromCatalog", defaultValue: "Alle %d sichtbaren Folgen aus %@ übernehmen", count, title)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: action) {
                HStack(alignment: .top, spacing: 10) {
                    CatalogGroupDisclosureChevron(isCollapsed: isCollapsed)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(detailText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onImportVisible) {
                Text("+\(count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.tint.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(importLabel)
            .disabled(count == 0)
        }
        .padding(.vertical, 2)
        .textCase(nil)
    }
}

private struct CatalogGroupDisclosureChevron: View {
    let isCollapsed: Bool
    @State private var rotation = 0.0

    private var targetRotation: Double {
        isCollapsed ? 0 : 90
    }

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: 12, height: 20, alignment: .center)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                rotation = targetRotation
            }
            .onChange(of: isCollapsed) { _, _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    rotation = targetRotation
                }
            }
    }
}

private struct CatalogEntryRow: View {
    let universeName: String
    let entry: CatalogEntry
    var onAdd: () -> Void

    @AppStorage(AppAccentColor.storageKey) private var appAccentColorRawValue: String = AppAccentColor.defaultValue.rawValue
    private var appAccentColor: AppAccentColor { AppAccentColor.resolved(from: appAccentColorRawValue) }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(universeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Group {
                        if entry.kind == .special {
                            Image(systemName: "sparkles")
                        } else {
                            Text(entry.number.map(String.init) ?? "–")
                                .monospacedDigit()
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(entry.kind == .special ? appAccentColor.color : .secondary)
                    .frame(minWidth: 28, alignment: .trailing)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                            .font(.body)

                        if entry.releaseYear > 0 {
                            Text(String(entry.releaseYear))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Spacer()

            Button {
                onAdd()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.tint)
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

private struct CatalogAddItem: Identifiable {
    let id = UUID()
    let entry: CatalogEntry
    let universeName: String
}

private struct CatalogBulkImportRequest: Identifiable {
    let id = UUID()
    let universeName: String
    let suggestions: [(universeName: String, entry: CatalogEntry)]

    var title: String {
        AppLocalization.format("CatalogImport.ConfirmTitle", defaultValue: "Folgen aus %@ übernehmen?", universeName)
    }

    var confirmationButtonTitle: String {
        suggestions.count == 1
            ? String(localized: "CatalogImport.ConfirmButtonOne", defaultValue: "1 Folge übernehmen")
            : AppLocalization.format("CatalogImport.ConfirmButtonMany", defaultValue: "%d Folgen übernehmen", suggestions.count)
    }

    var message: String {
        suggestions.count == 1
            ? AppLocalization.format("CatalogImport.ConfirmMessageOne", defaultValue: "Diese sichtbare fehlende Folge wird im Katalog \"%@\" angelegt.", universeName)
            : AppLocalization.format("CatalogImport.ConfirmMessageMany", defaultValue: "Alle %d aktuell sichtbaren fehlenden Folgen werden im Katalog \"%@\" angelegt.", suggestions.count, universeName)
    }
}
