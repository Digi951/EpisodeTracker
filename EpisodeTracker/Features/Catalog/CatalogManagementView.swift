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
    private let activeCatalogStore = ActiveCatalogStore()

    private var predefinedCatalogSources: [ManagedCatalogSource] {
        CatalogSourceRegistry.managedSources
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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
            Section {
                ForEach(predefinedCatalogSources, id: \.id) { source in
                    CatalogToggleRow(
                        source: source,
                        episodeCount: episodeCount(for: source.name),
                        isActive: activeCatalogIDs.contains(source.id),
                        onToggle: { newValue in
                            toggleCatalog(source, active: newValue)
                        }
                    )
                }
            } header: {
                Text("Verfügbare Kataloge")
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

    private var subtitle: String {
        let store = CatalogCacheStore()
        let titleCount = store.loadRemoteCatalogStatus(
            universeName: source.name, cacheKey: source.id
        ).cachedEntryCount

        if episodeCount > 0, let titleCount {
            return "\(episodeCount) Folgen · \(titleCount) Titel"
        } else if let titleCount {
            return "\(titleCount) Titel verfügbar"
        } else {
            return "Nicht geladen"
        }
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
