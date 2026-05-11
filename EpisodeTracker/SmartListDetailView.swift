import SwiftUI
import SwiftData

struct SmartListDetailView: View {
    let smartList: SmartListDefinition
    var mood: Mood?
    var iPadSelection: Binding<Episode?>?

    @Query private var allEpisodes: [Episode]
    @State private var shuffledEpisodes: [Episode]?
    @State private var episodeFilter: EpisodeFilter = .unlistened
    @State private var catalogAddItem: CatalogAddItem?

    private var displayedEpisodes: [Episode] {
        if smartList.isRandomList {
            return shuffledEpisodes ?? []
        }
        return smartList.episodes(from: allEpisodes)
    }

    private var catalogSuggestions: [(universeName: String, entry: CatalogEntry)] {
        SmartListDefinition.nextFromCatalog(
            catalogEntries: EpisodeCatalog.shared.allEntries,
            libraryEpisodes: allEpisodes
        )
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
        if catalogSuggestions.isEmpty {
            ContentUnavailableView {
                Label(smartList.displayName, systemImage: "tray")
            } description: {
                Text(smartList.emptyStateMessage)
            }
            .listRowSeparator(.hidden)
        } else {
            ForEach(Array(catalogSuggestions.enumerated()), id: \.offset) { _, suggestion in
                CatalogEntryRow(
                    universeName: suggestion.universeName,
                    entry: suggestion.entry
                ) {
                    catalogAddItem = CatalogAddItem(entry: suggestion.entry, universeName: suggestion.universeName)
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
            "Keine offenen Folgen mit dieser Stimmung"
        } else {
            smartList.emptyStateMessage
        }
    }

    private func reshuffle() {
        if smartList == .zufaelligNachStimmung, let mood {
            shuffledEpisodes = SmartListDefinition.episodesForMood(mood, from: allEpisodes, filter: episodeFilter)
        } else if smartList == .zufaellig {
            shuffledEpisodes = SmartListDefinition.randomEpisodes(from: allEpisodes, filter: episodeFilter)
        }
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
