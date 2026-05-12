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
    @State private var shuffledEpisodes: [Episode]?
    @State private var episodeFilter: EpisodeFilter = .all
    @State private var catalogAddItem: CatalogAddItem?
    @State private var catalogYearFilter: Int?

    private var displayedEpisodes: [Episode] {
        if smartList.isRandomList {
            return shuffledEpisodes ?? []
        }
        return smartList.episodes(from: allEpisodes)
    }

    private var catalogSuggestions: [(universeName: String, entry: CatalogEntry)] {
        let all = SmartListDefinition.nextFromCatalog(
            catalogEntries: EpisodeCatalog.shared.allEntries,
            libraryEpisodes: allEpisodes
        )
        if let year = catalogYearFilter {
            return all.filter { $0.entry.releaseYear == year }
        }
        return all
    }

    private var availableCatalogYears: [Int] {
        let allSuggestions = SmartListDefinition.nextFromCatalog(
            catalogEntries: EpisodeCatalog.shared.allEntries,
            libraryEpisodes: allEpisodes
        )
        let years = Set(allSuggestions.map(\.entry.releaseYear)).filter { $0 > 0 }
        return years.sorted()
    }

    private var catalogGroups: [CatalogSuggestionGroup] {
        let grouped = Dictionary(grouping: catalogSuggestions, by: \.universeName)
        return grouped.keys.sorted().map { universeName in
            CatalogSuggestionGroup(
                universeName: universeName,
                suggestions: grouped[universeName] ?? []
            )
        }
    }

    private var navigationTitle: String {
        if smartList == .zufaelligNachStimmung, let mood {
            return "\(mood.iconName ?? "") \(mood.name)"
        }
        return smartList.displayName
    }

    var body: some View {
        Group {
            if let iPadSelection {
                List(selection: iPadSelection) {
                    listContent
                }
            } else {
                List {
                    listContent
                }
            }
        }
        .navigationTitle(navigationTitle)
        .listStyle(.insetGrouped)
        .contentMargins(.horizontal, horizontalSizeClass == .regular ? 32 : 0, for: .scrollContent)
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
        .sheet(item: $catalogAddItem) { item in
            NavigationStack {
                EpisodeEditView(
                    prefillEntry: item.entry,
                    prefillUniverseName: item.universeName
                )
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if smartList.isRandomList {
            Section {
                Picker("Filter", selection: $episodeFilter) {
                    ForEach(EpisodeFilter.allCases) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }

        if smartList.needsCatalog {
            catalogContent
        } else {
            episodeContent
        }
    }

    @ViewBuilder
    private var catalogContent: some View {
        if !availableCatalogYears.isEmpty {
            Section {
                Picker("Jahr", selection: $catalogYearFilter) {
                    Text("Alle Jahre").tag(Optional<Int>.none)
                    ForEach(availableCatalogYears, id: \.self) { year in
                        Text(String(year)).tag(Optional(year))
                    }
                }
            }
        }

        if catalogSuggestions.isEmpty {
            ContentUnavailableView {
                Label(smartList.displayName, systemImage: "tray")
            } description: {
                Text(catalogYearFilter != nil
                     ? "Keine fehlenden Folgen aus \(String(catalogYearFilter!))"
                     : smartList.emptyStateMessage)
            }
            .listRowSeparator(.hidden)
        } else {
            Section {
                CatalogBulkImportCard(
                    suggestionCount: catalogSuggestions.count,
                    universeCount: catalogGroups.count
                ) {
                    addCatalogSuggestions(catalogSuggestions)
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            ForEach(catalogGroups) { group in
                Section {
                    ForEach(Array(group.suggestions.enumerated()), id: \.offset) { _, suggestion in
                        CatalogEntryRow(
                            universeName: suggestion.universeName,
                            entry: suggestion.entry
                        ) {
                            catalogAddItem = CatalogAddItem(entry: suggestion.entry, universeName: suggestion.universeName)
                        }
                    }
                } header: {
                    CatalogGroupHeader(
                        title: group.universeName,
                        count: group.suggestions.count
                    ) {
                        addCatalogSuggestions(group.suggestions)
                    }
                } footer: {
                    if group.suggestions.count > 1 {
                        Text("Die Vorschläge werden direkt im Katalog „\(group.universeName)“ angelegt.")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var episodeContent: some View {
        if displayedEpisodes.isEmpty {
            ContentUnavailableView {
                Label(smartList.displayName, systemImage: "tray")
            } description: {
                Text(emptyMessage)
            }
            .listRowSeparator(.hidden)
        } else {
            ForEach(displayedEpisodes) { episode in
                NavigationLink(value: episode) {
                    EpisodeRowView(episode: episode)
                }
            }
        }
    }

    private var emptyMessage: String {
        if smartList.isRandomList {
            switch episodeFilter {
            case .unlistened: "Keine ungehörten Folgen"
            case .listened: "Keine gehörten Folgen"
            case .all: "Keine Folgen vorhanden"
            }
        } else if smartList == .zufaelligNachStimmung {
            "Keine Folgen mit dieser Stimmung"
        } else {
            smartList.emptyStateMessage
        }
    }

    private func addCatalogSuggestions(_ suggestions: [(universeName: String, entry: CatalogEntry)]) {
        for suggestion in suggestions {
            let universe = universes.first {
                $0.name.caseInsensitiveCompare(suggestion.universeName) == .orderedSame
            }
            let episode = Episode(
                episodeNumber: suggestion.entry.number,
                title: suggestion.entry.title,
                releaseYear: suggestion.entry.releaseYear,
                universe: universe
            )
            modelContext.insert(episode)
        }

        try? modelContext.save()
    }

    private func reshuffle() {
        if smartList == .zufaelligNachStimmung, let mood {
            shuffledEpisodes = SmartListDefinition.episodesForMood(mood, from: allEpisodes, filter: episodeFilter)
        } else if smartList == .zufaellig {
            shuffledEpisodes = SmartListDefinition.randomEpisodes(from: allEpisodes, filter: episodeFilter)
        }
    }
}

private struct CatalogSuggestionGroup: Identifiable {
    let universeName: String
    let suggestions: [(universeName: String, entry: CatalogEntry)]

    var id: String { universeName }
}

private struct CatalogBulkImportCard: View {
    let suggestionCount: Int
    let universeCount: Int
    let action: () -> Void

    private var detailText: String {
        if universeCount == 1 {
            return "\(suggestionCount) fehlende Folgen in 1 Katalog"
        }
        return "\(suggestionCount) fehlende Folgen in \(universeCount) Katalogen"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Katalog übernehmen")
                    .font(.headline)
                Spacer()
                Text("\(suggestionCount)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.tint)
            }

            Text(detailText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(action: action) {
                Label("Alle sichtbaren Vorschläge übernehmen", systemImage: "plus.rectangle.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct CatalogGroupHeader: View {
    let title: String
    let count: Int
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(count == 1 ? "1 fehlende Folge" : "\(count) fehlende Folgen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: action) {
                Label("Alle", systemImage: "plus")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderless)
            .font(.subheadline.weight(.semibold))
        }
        .textCase(nil)
    }
}

private struct CatalogEntryRow: View {
    let universeName: String
    let entry: CatalogEntry
    var onAdd: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(universeName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text("\(entry.number)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
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
