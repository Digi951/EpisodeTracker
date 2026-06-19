import SwiftUI

struct SavedFilterManagementView: View {
    @Environment(SavedFilterStore.self) private var savedFilterStore
    @State private var renameFilter: SavedFilter?
    @State private var renameText = ""

    var body: some View {
        List {
            if savedFilterStore.filters.isEmpty {
                ContentUnavailableView(
                    String(localized: "SavedFilter.Management.Empty.Title",
                           defaultValue: "Keine gespeicherten Listen"),
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text(
                        String(localized: "SavedFilter.Management.Empty.Message",
                               defaultValue: "Speichere einen aktiven Filter aus der Bibliothek als Liste.")
                    )
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(savedFilterStore.filters) { filter in
                    filterRow(filter)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        savedFilterStore.delete(savedFilterStore.filters[index])
                    }
                }
            }
        }
        .navigationTitle(
            String(localized: "SavedFilter.Management.Title", defaultValue: "Meine Listen")
        )
        .alert(
            String(localized: "SavedFilter.Rename.Title", defaultValue: "Liste umbenennen"),
            isPresented: Binding(
                get: { renameFilter != nil },
                set: { if !$0 { renameFilter = nil } }
            )
        ) {
            TextField(
                String(localized: "SavedFilter.Rename.Placeholder", defaultValue: "Name"),
                text: $renameText
            )
            Button(String(localized: "SavedFilter.Rename.Save", defaultValue: "Speichern")) {
                if var filter = renameFilter,
                   !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    filter.name = renameText.trimmingCharacters(in: .whitespaces)
                    savedFilterStore.update(filter)
                }
                renameFilter = nil
            }
            Button(
                String(localized: "General.Cancel", defaultValue: "Abbrechen"),
                role: .cancel
            ) { renameFilter = nil }
        }
    }

    private func filterRow(_ filter: SavedFilter) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(filter.name)
                Text(filterSummary(filter))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                renameFilter = filter
                renameText = filter.name
            } label: {
                Image(systemName: "pencil")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
    }

    private func filterSummary(_ filter: SavedFilter) -> String {
        var parts: [String] = []
        if filter.resolvedStatusFilter != .all {
            parts.append(filter.resolvedStatusFilter.rawValue)
        }
        if let name = filter.universeName { parts.append(name) }
        if let name = filter.moodName { parts.append(name) }
        if filter.resolvedSortOrder != .number {
            parts.append(filter.resolvedSortOrder.rawValue)
        }
        return parts.isEmpty
            ? String(localized: "SavedFilter.Summary.AllEpisodes", defaultValue: "Alle Folgen")
            : parts.joined(separator: " · ")
    }
}
