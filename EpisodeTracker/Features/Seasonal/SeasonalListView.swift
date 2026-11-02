import SwiftUI
import SwiftData

/// Saison-Liste in „Als nächstes“, zum Beispiel „Weihnachtsfolgen“ im Dezember.
struct SeasonalListView: View {
    let season: CatalogSeason
    var iPadSelection: Binding<Episode?>? = nil

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var episodes: [Episode]
    @State private var catalogAddItem: AddItem?

    private struct AddItem: Identifiable {
        let id = UUID()
        let result: CatalogEpisodeSearch.Result
    }

    private var content: SeasonalEpisodes {
        SeasonalEpisodes.make(
            season: season,
            entries: EpisodeCatalog.shared.allEntries,
            activeCollectionNames: CatalogEpisodeSearch.activeCollectionNames(),
            libraryEpisodes: episodes
        )
    }

    var body: some View {
        let content = content
        let anyEpisodeHasCover = content.libraryEpisodes.contains { $0.coverImageName?.isEmpty == false }

        List {
            Section {
                Text(String(
                    localized: "Seasonal.Christmas.Intro",
                    defaultValue: "Adventskalender und Weihnachtsspecials aus deinen Katalogen."
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if content.isEmpty {
                Section {
                    Text(String(
                        localized: "Seasonal.Christmas.Empty",
                        defaultValue: "In deinen aktiven Katalogen sind keine Weihnachtsfolgen markiert."
                    ))
                    .foregroundStyle(.secondary)
                }
            }

            if !content.libraryEpisodes.isEmpty {
                Section(String(localized: "Seasonal.Section.Library", defaultValue: "In deiner Bibliothek")) {
                    ForEach(content.libraryEpisodes) { episode in
                        if let iPadSelection {
                            Button {
                                iPadSelection.wrappedValue = episode
                            } label: {
                                EpisodeRowView(episode: episode, anyEpisodeHasCover: anyEpisodeHasCover)
                            }
                        } else {
                            NavigationLink(value: episode) {
                                EpisodeRowView(episode: episode, anyEpisodeHasCover: anyEpisodeHasCover)
                            }
                        }
                    }
                }
            }

            if !content.catalogEntries.isEmpty {
                Section(String(localized: "Seasonal.Section.Catalog", defaultValue: "Noch nicht in deiner Bibliothek")) {
                    ForEach(content.catalogEntries, id: \.rowID) { result in
                        CatalogEntryRow(
                            universeName: AppLocalization.displayName(forUniverseName: result.universeName),
                            entry: result.entry,
                            onAdd: { catalogAddItem = AddItem(result: result) }
                        )
                    }
                }
            }
        }
        .navigationTitle(season.listTitle)
        .listStyle(.insetGrouped)
        .contentMargins(.horizontal, horizontalSizeClass == .regular ? 32 : 0, for: .scrollContent)
        .sheet(item: $catalogAddItem) { item in
            NavigationStack {
                EpisodeEditView(
                    prefillEntry: item.result.entry,
                    prefillUniverseName: item.result.universeName
                )
            }
        }
    }
}

private extension CatalogEpisodeSearch.Result {
    var rowID: String {
        let key = CatalogLibraryMatcher.normalizedCollectionKey(universeName)
        return "\(key)#\(entry.number.map(String.init) ?? "special:\(entry.slug ?? entry.title)")"
    }
}
