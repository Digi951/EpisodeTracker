import SwiftUI
import SwiftData

/// Einstieg für „Neue Folge“: erst suchen, dann das vorausgefüllte Formular.
/// Ohne aktiven Katalog gibt es nichts zu suchen, dann direkt das Formular.
struct NewEpisodeView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Episode.episodeNumber) private var allEpisodes: [Episode]
    @AppStorage(AppAccentColor.storageKey) private var appAccentColorRawValue: String = AppAccentColor.defaultValue.rawValue

    @State private var query = ""
    @State private var selection: Selection?
    @FocusState private var isSearchFieldFocused: Bool

    /// Ziel des Formulars; `entry == nil` ist „Ohne Katalog anlegen“.
    private struct Selection: Identifiable, Hashable {
        let id = UUID()
        let entry: CatalogEntry?
        let universeName: String?

        static func == (lhs: Selection, rhs: Selection) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    private var activeCollectionNames: Set<String> {
        CatalogEpisodeSearch.activeCollectionNames()
    }

    private var results: [CatalogEpisodeSearch.Result] {
        CatalogEpisodeSearch.results(
            for: query,
            entries: EpisodeCatalog.shared.allEntries,
            activeCollectionNames: activeCollectionNames,
            libraryEpisodes: allEpisodes
        )
    }

    var body: some View {
        if activeCollectionNames.isEmpty {
            EpisodeEditView()
        } else {
            searchList
        }
    }

    private var searchList: some View {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentResults = results

        return List {
            if trimmedQuery.isEmpty {
                Section {
                    Label {
                        Text(String(
                            localized: "NewEpisode.Search.Hint",
                            defaultValue: "Tippe eine Folgennummer oder einen Teil des Titels."
                        ))
                    } icon: {
                        Image(systemName: "magnifyingglass")
                    }
                    .foregroundStyle(.secondary)
                }
            } else if currentResults.isEmpty {
                Section {
                    Text(String(
                        localized: "NewEpisode.Search.NoResults",
                        defaultValue: "Keine passende Folge in deinen Katalogen, oder sie steht schon in deiner Bibliothek."
                    ))
                    .foregroundStyle(.secondary)
                }
            } else {
                Section(String(localized: "NewEpisode.Search.ResultsHeader", defaultValue: "Aus deinen Katalogen")) {
                    ForEach(currentResults, id: \.identity) { result in
                        Button {
                            selection = Selection(entry: result.entry, universeName: result.universeName)
                        } label: {
                            resultRow(result)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                Button {
                    selection = Selection(entry: nil, universeName: nil)
                } label: {
                    Label(
                        String(localized: "NewEpisode.Search.Manual", defaultValue: "Ohne Katalog anlegen"),
                        systemImage: "square.and.pencil"
                    )
                }
            } footer: {
                Text(String(
                    localized: "NewEpisode.Search.ManualFooter",
                    defaultValue: "Für Folgen, die in keinem Katalog stehen."
                ))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Neue Folge")
        .navigationBarTitleDisplayMode(.inline)
        // Eigenes Suchfeld statt `.searchable`: Dessen Suche wird erst nach
        // dem Einblenden des Sheets aktiv, dann verschwanden „Abbrechen“ und
        // Titel sichtbar wieder. So bleibt die Leiste stehen, nur die
        // Tastatur fährt hoch.
        .safeAreaInset(edge: .top, spacing: 0) {
            searchField
        }
        .onAppear { isSearchFieldFocused = true }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
        }
        .navigationDestination(item: $selection) { selection in
            EpisodeEditView(
                prefillEntry: selection.entry,
                prefillUniverseName: selection.universeName,
                onSaved: { dismiss() }
            )
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                String(localized: "NewEpisode.Search.Prompt", defaultValue: "Nummer oder Titel"),
                text: $query
            )
            .focused($isSearchFieldFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Suche löschen"))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    private func resultRow(_ result: CatalogEpisodeSearch.Result) -> some View {
        let accent = AppAccentColor.resolved(from: appAccentColorRawValue).color
        return HStack(spacing: 12) {
            Group {
                if result.entry.kind == .special {
                    Image(systemName: "sparkles")
                        .foregroundStyle(accent)
                } else {
                    Text(result.entry.number.map(String.init) ?? "–")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .font(.headline)
            .frame(width: 40, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.entry.title)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text("\(AppLocalization.displayName(forUniverseName: result.universeName)) · \(String(result.entry.releaseYear))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
