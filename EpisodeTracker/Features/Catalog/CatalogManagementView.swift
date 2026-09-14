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
    @State private var selectedCatalogLanguages: Set<String> = []
    @State private var searchText = ""
    @State private var activationHandler = CatalogActivationHandler()
    private let activeCatalogStore = ActiveCatalogStore()
    private let languageFilterStore = CatalogLanguageFilterStore()

    /// Sources shown in the list: the language-filtered `visibleSources`, plus
    /// any active or bound source the filter would otherwise hide (§3).
    private var predefinedCatalogSources: [ManagedCatalogSource] {
        CatalogSourceRegistry.visibleSourcesIncludingAlwaysShown(
            visible: CatalogSourceRegistry.visibleSources,
            allKnown: CatalogSourceRegistry.allKnownSources,
            alwaysShownIDs: activeCatalogStore.activeIDs.union(boundCatalogIDs)
        )
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var boundCatalogIDs: Set<String> {
        Set(universes.compactMap(\.managedCatalogID))
    }

    /// Distinct catalog languages across the full registry, sorted. The language
    /// filter only appears once this holds more than one entry — with a
    /// single-language registry there is nothing to choose.
    private var availableCatalogLanguages: [String] {
        var seen = Set<String>()
        return CatalogSourceRegistry.allKnownSources
            .map(\.effectiveLanguage)
            .filter { seen.insert($0).inserted }
            .sorted()
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
        Set(universes.map { CatalogLibraryMatcher.normalizedCollectionKey($0.name) })
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
            if availableCatalogLanguages.count > 1 {
                Section {
                    ForEach(availableCatalogLanguages, id: \.self) { code in
                        Button {
                            toggleCatalogLanguage(code)
                        } label: {
                            HStack {
                                Text(languageDisplayName(code))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedCatalogLanguages.contains(code) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }

                    if CatalogSourceRegistry.visibleSources.isEmpty {
                        Button("Weitere Sprachen") {
                            expandCatalogLanguagesToAll()
                        }
                    }
                } header: {
                    Text("Sprache")
                }
            }

            if !activeSources.isEmpty {
                Section {
                    ForEach(activeSources, id: \.id) { source in
                        CatalogToggleRow(
                            source: source,
                            episodeCount: episodeCount(for: source.name),
                            isActive: true,
                            activationState: activationHandler.state(for: source.id),
                            onToggle: { newValue in toggleCatalog(source, active: newValue) },
                            onRetry: { activationHandler.retry(source: source) }
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
                        activationState: activationHandler.state(for: source.id),
                        onToggle: { newValue in toggleCatalog(source, active: newValue) },
                        onRetry: { activationHandler.retry(source: source) }
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
            selectedCatalogLanguages = languageFilterStore.selectedLanguages
        }
    }

    private func languageDisplayName(_ code: String) -> String {
        Locale.current.localizedString(forLanguageCode: code)?.localizedCapitalized
            ?? code.uppercased()
    }

    private func toggleCatalogLanguage(_ code: String) {
        if selectedCatalogLanguages.contains(code) {
            selectedCatalogLanguages.remove(code)
        } else {
            selectedCatalogLanguages.insert(code)
        }
        languageFilterStore.setSelected(selectedCatalogLanguages)
    }

    private func expandCatalogLanguagesToAll() {
        selectedCatalogLanguages = Set(availableCatalogLanguages)
        languageFilterStore.setSelected(selectedCatalogLanguages)
    }

    private func episodeCount(for universeName: String) -> Int {
        let key = CatalogLibraryMatcher.normalizedCollectionKey(universeName)
        return universes.first {
            CatalogLibraryMatcher.normalizedCollectionKey($0.name) == key
        }?.episodes.count ?? 0
    }

    private func toggleCatalog(_ source: ManagedCatalogSource, active: Bool) {
        activeCatalogStore.setActive(source.id, active: active)
        activeCatalogIDs = activeCatalogStore.activeIDs

        guard active else { return }

        // Bind (P3-B) and immediately pull the source's catalog (D6). A failed
        // fetch leaves the activation above in place.
        activationHandler.activate(
            source: source,
            modelContext: modelContext,
            existingUniverses: universes
        )
    }

    private func addCustomUniverse() {
        validationMessage = nil

        let trimmedName = newUniverseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationMessage = "Bitte gib einen Namen für den Katalog ein."
            return
        }

        if existingUniverseNameKeys.contains(CatalogLibraryMatcher.normalizedCollectionKey(trimmedName)) {
            validationMessage = "Dieser Katalog existiert bereits."
            return
        }

        modelContext.insert(Universe(name: trimmedName))
        newUniverseName = ""
    }

    private func deleteCustomUniverses(at offsets: IndexSet) {
        validationMessage = nil
        let predefinedKeys = Set(predefinedCatalogSources.map { CatalogLibraryMatcher.normalizedCollectionKey($0.name) })
        let customUniverses = universes.filter { universe in
            !predefinedKeys.contains(CatalogLibraryMatcher.normalizedCollectionKey(universe.name))
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
            AppDataBootstrapper.reconcileAfterCatalogRefresh(container: modelContext.container)
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
    var activationState: CatalogActivationHandler.State = .idle
    let onToggle: (Bool) -> Void
    var onRetry: () -> Void = {}

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

    /// VoiceOver-Hinweis für den Toggle (Paket 6, P6-B): der Reihenname allein
    /// verrät nicht, was ein Doppeltipp bewirkt. Der bestätigte
    /// "Aktivieren"/"Deaktivieren"-Wortlaut (Glossar, Paket 5 D4, statt
    /// "Abonnieren") ist damit erstmals als UI-Text vorhanden, nicht nur im
    /// Systemwert "An"/"Aus" des Toggles.
    static func activationAccessibilityHint(isActive: Bool) -> String {
        isActive
            ? String(localized: "Catalog.Toggle.DeactivateHint", defaultValue: "Deaktivieren")
            : String(localized: "Catalog.Toggle.ActivateHint", defaultValue: "Aktivieren")
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

                switch activationState {
                case .running:
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Katalog wird geladen …")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                case .failed(let message):
                    HStack(spacing: 8) {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Erneut versuchen", action: onRetry)
                            .font(.footnote.weight(.medium))
                            .buttonStyle(.borderless)
                    }
                case .idle:
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(episodeCount > 0 ? .secondary : .tertiary)
                }
            }
        }
        .accessibilityHint(CatalogToggleRow.activationAccessibilityHint(isActive: isActive))
    }
}
