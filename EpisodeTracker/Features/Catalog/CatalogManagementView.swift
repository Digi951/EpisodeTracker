import SwiftUI
import SwiftData

struct CatalogManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Universe.name) private var universes: [Universe]

    @State private var newUniverseName: String = ""
    @State private var validationMessage: String?
    @State private var catalogStatusMessage: String?
    @State private var catalogStatusIsError = false
    @State private var isRefreshingCatalogs = false
    @State private var activeCatalogIDs: Set<String> = []
    @State private var searchText = ""
    private let activeCatalogStore = ActiveCatalogStore()

    private var predefinedCatalogSources: [ManagedCatalogSource] {
        CatalogSourceRegistry.managedSources
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var filteredSources: [ManagedCatalogSource] {
        guard !searchText.isEmpty else { return predefinedCatalogSources }
        return predefinedCatalogSources.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var activeSources: [ManagedCatalogSource] {
        filteredSources.filter { activeCatalogIDs.contains($0.id) }
    }

    private var inactiveSources: [ManagedCatalogSource] {
        filteredSources.filter { !activeCatalogIDs.contains($0.id) }
    }

    private var existingUniverseNameKeys: Set<String> {
        Set(universes.map { $0.name.lowercased() })
    }

    private var lastGlobalRefreshText: String? {
        let store = CatalogCacheStore()
        let dates = predefinedCatalogSources.compactMap { source -> Date? in
            store.loadRemoteCatalogStatus(universeName: source.name, cacheKey: source.id).lastCheckedAt
        }
        guard let latest = dates.max() else { return nil }
        return "Zuletzt aktualisiert: \(latest.formatted(date: .abbreviated, time: .shortened))"
    }

    var body: some View {
        List {
            if !activeSources.isEmpty {
                Section {
                    ForEach(activeSources, id: \.id) { source in
                        CatalogToggleRow(
                            source: source,
                            episodeCount: episodeCount(for: source.name),
                            isActive: true,
                            onToggle: { newValue in toggleCatalog(source, active: newValue) }
                        )
                    }
                } header: {
                    Text(CatalogToggleRow.activeCountLabel(
                        active: activeSources.count,
                        total: predefinedCatalogSources.count
                    ))
                }
            }

            Section {
                ForEach(inactiveSources, id: \.id) { source in
                    CatalogToggleRow(
                        source: source,
                        episodeCount: episodeCount(for: source.name),
                        isActive: false,
                        onToggle: { newValue in toggleCatalog(source, active: newValue) }
                    )
                }
            } header: {
                Text(activeSources.isEmpty
                     ? CatalogToggleRow.activeCountLabel(active: 0, total: predefinedCatalogSources.count)
                     : "Verfügbar")
            } footer: {
                Text("Aktivierte Kataloge werden automatisch aktualisiert und liefern Titelvorschläge beim Hinzufügen neuer Folgen.")
            }

            Section {
                ForEach(universes.filter { universe in
                    !predefinedCatalogSources.contains { $0.name.caseInsensitiveCompare(universe.name) == .orderedSame }
                }) { universe in
                    HStack {
                        Text(universe.name)
                        Spacer()
                        Text("\(universe.episodes.count) Folgen")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: deleteCustomUniverses)

                HStack {
                    TextField("Neuer Katalog", text: $newUniverseName)
                    Button("Hinzufügen") {
                        addCustomUniverse()
                    }
                    .disabled(newUniverseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Eigene Kataloge")
            } footer: {
                Text("Nur leere Kataloge können gelöscht werden.")
            }

            Section {
                Button {
                    refreshAllManagedCatalogs()
                } label: {
                    Label {
                        Text(isRefreshingCatalogs ? "Aktualisiere…" : "Alle aktualisieren")
                    } icon: {
                        if isRefreshingCatalogs {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                }
                .disabled(isRefreshingCatalogs)

                if let catalogStatusMessage {
                    Text(catalogStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(catalogStatusIsError ? .red : .secondary)
                }

                if let refreshError = EpisodeCatalog.shared.lastRefreshError, catalogStatusMessage == nil {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(refreshError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Erneut versuchen") {
                            refreshAllManagedCatalogs()
                        }
                        .font(.footnote.weight(.medium))
                        .disabled(isRefreshingCatalogs)
                    }
                }
            } footer: {
                if let lastGlobalRefreshText {
                    Text(lastGlobalRefreshText)
                }
            }
        }
        .navigationTitle("Kataloge")
        .searchable(text: $searchText, prompt: "Katalog suchen")
        .onAppear {
            activeCatalogIDs = activeCatalogStore.activeIDs
        }
    }

    private func episodeCount(for universeName: String) -> Int {
        universes.first(where: {
            $0.name.caseInsensitiveCompare(universeName) == .orderedSame
        })?.episodes.count ?? 0
    }

    private func toggleCatalog(_ source: ManagedCatalogSource, active: Bool) {
        activeCatalogStore.setActive(source.id, active: active)
        activeCatalogIDs = activeCatalogStore.activeIDs

        if active {
            let key = source.name.lowercased()
            if !existingUniverseNameKeys.contains(key) {
                modelContext.insert(Universe(name: source.name))
            }
        }
    }

    private func addCustomUniverse() {
        validationMessage = nil

        let trimmedName = newUniverseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationMessage = "Bitte gib einen Namen für den Katalog ein."
            return
        }

        if universes.contains(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            validationMessage = "Dieser Katalog existiert bereits."
            return
        }

        modelContext.insert(Universe(name: trimmedName))
        newUniverseName = ""
    }

    private func deleteCustomUniverses(at offsets: IndexSet) {
        validationMessage = nil
        let customUniverses = universes.filter { universe in
            !predefinedCatalogSources.contains { $0.name.caseInsensitiveCompare(universe.name) == .orderedSame }
        }

        for index in offsets {
            let universe = customUniverses[index]
            if universe.episodes.isEmpty {
                modelContext.delete(universe)
            } else {
                validationMessage = "Nur leere Kataloge können gelöscht werden."
            }
        }
    }

    private func refreshAllManagedCatalogs() {
        isRefreshingCatalogs = true
        catalogStatusMessage = nil
        Task {
            await EpisodeCatalog.shared.refreshManagedCatalogsIfNeeded(force: true)
            await MainActor.run {
                isRefreshingCatalogs = false
                if let error = EpisodeCatalog.shared.lastRefreshError {
                    catalogStatusIsError = true
                    catalogStatusMessage = error
                } else {
                    catalogStatusIsError = false
                    catalogStatusMessage = "Aktive Kataloge wurden aktualisiert."
                }
            }
        }
    }
}

struct CatalogToggleRow: View {
    let source: ManagedCatalogSource
    let episodeCount: Int
    let isActive: Bool
    let onToggle: (Bool) -> Void

    static func catalogSubtitle(episodeCount: Int, titleCount: Int?) -> String {
        guard let titleCount else { return "Nicht geladen" }
        if episodeCount == 1 {
            return "1 Folge · \(titleCount) Titel"
        } else if episodeCount > 1 {
            return "\(episodeCount) Folgen · \(titleCount) Titel"
        } else {
            return "\(titleCount) Titel"
        }
    }

    static func activeCountLabel(active: Int, total: Int) -> String {
        "\(active) von \(total) aktiv"
    }

    private var subtitle: String {
        let store = CatalogCacheStore()
        let titleCount = store.loadRemoteCatalogStatus(
            universeName: source.name, cacheKey: source.id
        ).cachedEntryCount
        return CatalogToggleRow.catalogSubtitle(episodeCount: episodeCount, titleCount: titleCount)
    }

    var body: some View {
        Toggle(isOn: Binding(
            get: { isActive },
            set: { onToggle($0) }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(episodeCount > 0 ? .secondary : .tertiary)
            }
        }
    }
}
