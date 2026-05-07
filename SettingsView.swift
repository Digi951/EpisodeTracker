import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("libraryTitle") private var libraryTitle: String = "Meine Hörspiele"
    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.system.rawValue
    @AppStorage("showsLibrarySnapshot") private var showsLibrarySnapshot = true
    @AppStorage(FreemiumAccess.unlockStorageKey) private var isPlusUnlocked = false
    @Query(sort: \Universe.name) private var universes: [Universe]
    @Query(sort: \Mood.name) private var moods: [Mood]
    @Query(sort: \Episode.episodeNumber) private var episodes: [Episode]

    @State private var backupStatusMessage: String?
    @State private var backupStatusIsError = false
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument: JSONBackupDocument?
    @State private var pendingImportURL: URL?

    var body: some View {
        List {
            Section {
                TextField("Sammlungsname", text: $libraryTitle)
                Picker("Darstellung", selection: $appearanceModeRawValue) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                Toggle("Hörstand anzeigen", isOn: $showsLibrarySnapshot)
            } header: {
                Text("Mediathek")
            } footer: {
                Text("Der Sammlungsname erscheint oben in deiner Folgenliste. Den Hörstand kannst du ausblenden, wenn du lieber direkt mit der Liste startest.")
            }

            Section {
                LabeledContent("Aktueller Plan", value: FreemiumAccess.planName(isPlusUnlocked: isPlusUnlocked))
                LabeledContent(
                    "Free-Kontingent",
                    value: FreemiumAccess.freePlanUsageText(
                        currentEpisodeCount: episodes.count,
                        isPlusUnlocked: isPlusUnlocked
                    )
                )
            } header: {
                Text("Plan")
            } footer: {
                Text("Freemium ist technisch vorbereitet. Aktuell werden keine Funktionen gesperrt; die echte Freischaltung kann später über StoreKit angeschlossen werden.")
            }

            Section("Verwalten") {
                NavigationLink {
                    CatalogManagementView()
                } label: {
                    SettingsNavigationRow(
                        title: "Kataloge",
                        subtitle: "\(universes.count) Kataloge aktiv",
                        systemImage: "books.vertical"
                    )
                }

                NavigationLink {
                    MoodManagementView()
                } label: {
                    SettingsNavigationRow(
                        title: "Stimmungen",
                        subtitle: "\(moods.count) Stimmungen gespeichert",
                        systemImage: "tag"
                    )
                }
            }

            Section {
                Button {
                    exportBackup()
                } label: {
                    SettingsActionRow(
                        title: "Backup exportieren",
                        subtitle: "\(episodes.count) Folgen sichern",
                        systemImage: "square.and.arrow.up"
                    )
                }

                Button {
                    showingImporter = true
                } label: {
                    SettingsActionRow(
                        title: "Backup importieren",
                        subtitle: "Folgen, Kataloge und Stimmungen wiederherstellen",
                        systemImage: "square.and.arrow.down"
                    )
                }

                if let backupStatusMessage {
                    Text(backupStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(backupStatusIsError ? .red : .secondary)
                }
            } header: {
                Text("Daten")
            } footer: {
                Text("Backups bleiben lokal als JSON-Datei und enthalten deine Folgen, Kataloge, Stimmungen und Notizen.")
            }

            Section("Zurücksetzen") {
                Button(role: .destructive) {
                    libraryTitle = "Meine Hörspiele"
                    appearanceModeRawValue = AppearanceMode.system.rawValue
                    showsLibrarySnapshot = true
                } label: {
                    Label("Darstellung zurücksetzen", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle("Einstellungen")
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: backupFileName
        ) { result in
            switch result {
            case .success:
                backupStatusIsError = false
                backupStatusMessage = "Backup wurde exportiert."
            case .failure(let error):
                backupStatusIsError = true
                backupStatusMessage = "Export fehlgeschlagen: \(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json]
        ) { result in
            switch result {
            case .success(let url):
                pendingImportURL = url
            case .failure(let error):
                backupStatusIsError = true
                backupStatusMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
            }
        }
        .confirmationDialog(
            "Backup importieren?",
            isPresented: Binding(
                get: { pendingImportURL != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingImportURL = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Import starten") {
                if let pendingImportURL {
                    importBackup(from: pendingImportURL)
                }
                self.pendingImportURL = nil
            }
            Button("Abbrechen", role: .cancel) {
                pendingImportURL = nil
            }
        } message: {
            Text("Bestehende Folgen mit gleicher Nummer werden aktualisiert, neue ergänzt.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") {
                    dismissKeyboard()
                }
            }
        }
    }

    private var backupFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "HoerspielTracker-Backup-\(formatter.string(from: .now))"
    }

    private func exportBackup() {
        do {
            let payload = makeBackupPayload()
            let data = try JSONEncoder.backupEncoder.encode(payload)
            exportDocument = JSONBackupDocument(data: data)
            showingExporter = true
            backupStatusMessage = nil
        } catch {
            backupStatusIsError = true
            backupStatusMessage = "Export fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func importBackup(from url: URL) {
        do {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let payload = try JSONDecoder.backupDecoder.decode(BackupPayload.self, from: data)
            applyBackup(payload)

            backupStatusIsError = false
            backupStatusMessage = "Backup importiert: \(payload.episodes.count) Folgen, \(payload.moods.count) Stimmungen."
        } catch {
            backupStatusIsError = true
            backupStatusMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func makeBackupPayload() -> BackupPayload {
        let universesData = universes.map { universe in
            BackupCollection(name: universe.name)
        }
        let moodsData = moods.map { mood in
            BackupMood(name: mood.name, iconName: mood.iconName)
        }
        let episodesData = episodes.map { episode in
            BackupEpisode(
                episodeNumber: episode.episodeNumber,
                title: episode.title,
                releaseYear: episode.releaseYear,
                personalNote: episode.personalNote,
                isListened: episode.isListened,
                rating: episode.rating,
                listenCount: episode.listenCount,
                lastListenedAt: episode.lastListenedAt,
                collectionName: episode.universe?.name,
                moodNames: episode.moods.map(\.name)
            )
        }
        return BackupPayload(
            exportedAt: .now,
            schemaVersion: 1,
            collections: universesData,
            moods: moodsData,
            episodes: episodesData
        )
    }

    private func applyBackup(_ payload: BackupPayload) {
        var universesByKey = Dictionary(uniqueKeysWithValues: universes.map { ($0.name.lowercased(), $0) })
        for universeData in payload.collections ?? [] {
            let key = universeData.name.lowercased()
            if universesByKey[key] == nil {
                let newUniverse = Universe(name: universeData.name)
                modelContext.insert(newUniverse)
                universesByKey[key] = newUniverse
            }
        }

        var moodsByKey = Dictionary(uniqueKeysWithValues: moods.map { ($0.name.lowercased(), $0) })

        for moodData in payload.moods {
            let key = moodData.name.lowercased()
            if let existing = moodsByKey[key] {
                existing.iconName = moodData.iconName
            } else {
                let newMood = Mood(name: moodData.name, iconName: moodData.iconName)
                modelContext.insert(newMood)
                moodsByKey[key] = newMood
            }
        }

        var episodesByKey: [String: Episode] = [:]
        for episode in episodes {
            let key = "\(episode.universe?.name.lowercased() ?? "allgemein")#\(episode.episodeNumber)"
            episodesByKey[key] = episode
        }

        for episodeData in payload.episodes {
            let assignedMoods = episodeData.moodNames.compactMap { moodsByKey[$0.lowercased()] }
            let universeKey = (episodeData.collectionName ?? "Allgemein").lowercased()
            let assignedUniverse: Universe
            if let existingUniverse = universesByKey[universeKey] {
                assignedUniverse = existingUniverse
            } else {
                let newUniverse = Universe(name: episodeData.collectionName ?? "Allgemein")
                modelContext.insert(newUniverse)
                universesByKey[universeKey] = newUniverse
                assignedUniverse = newUniverse
            }

            let episodeKey = "\(universeKey)#\(episodeData.episodeNumber)"

            if let existingEpisode = episodesByKey[episodeKey] {
                existingEpisode.title = episodeData.title
                existingEpisode.releaseYear = episodeData.releaseYear
                existingEpisode.personalNote = episodeData.personalNote
                existingEpisode.isListened = episodeData.isListened
                existingEpisode.rating = episodeData.rating
                existingEpisode.listenCount = episodeData.listenCount
                existingEpisode.lastListenedAt = episodeData.lastListenedAt
                existingEpisode.universe = assignedUniverse
                existingEpisode.moods = assignedMoods
            } else {
                let newEpisode = Episode(
                    episodeNumber: episodeData.episodeNumber,
                    title: episodeData.title,
                    releaseYear: episodeData.releaseYear,
                    personalNote: episodeData.personalNote,
                    isListened: episodeData.isListened,
                    rating: episodeData.rating,
                    listenCount: episodeData.listenCount,
                    lastListenedAt: episodeData.lastListenedAt,
                    universe: assignedUniverse,
                    moods: assignedMoods
                )
                modelContext.insert(newEpisode)
                episodesByKey[episodeKey] = newEpisode
            }
        }
    }
}

private struct SettingsNavigationRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
        }
    }
}

private struct SettingsActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
        }
    }
}

private struct CatalogManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Universe.name) private var universes: [Universe]

    @State private var selectedManagedCatalogName: String = CatalogSourceRegistry.managedSources.first?.name ?? ""
    @State private var newUniverseName: String = ""
    @State private var validationMessage: String?
    @State private var catalogStatusMessage: String?
    @State private var catalogStatusIsError = false
    @State private var catalogStatuses: [String: CatalogCacheStatus] = [:]

    private var predefinedCatalogSources: [ManagedCatalogSource] {
        CatalogSourceRegistry.managedSources
    }

    private var predefinedUniverseNames: [String] {
        predefinedCatalogSources.map(\.name)
    }

    private var existingUniverseNameKeys: Set<String> {
        Set(universes.map { $0.name.lowercased() })
    }

    var body: some View {
        List {
            Section {
                ForEach(universes) { universe in
                    HStack {
                        Text(universe.name)
                        Spacer()
                        Text("\(universe.episodes.count) Folgen")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: deleteUniverses)

                if let validationMessage {
                    Text(validationMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Aktive Kataloge")
            } footer: {
                Text("Nur leere Kataloge können gelöscht werden.")
            }

            Section("Eigener Katalog") {
                HStack {
                    TextField("Name des Katalogs", text: $newUniverseName)
                    Button("Hinzufügen") {
                        addCustomUniverse()
                    }
                    .disabled(newUniverseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section {
                ForEach(predefinedCatalogSources, id: \.id) { source in
                    let universeName = source.name
                    let isAdded = existingUniverseNameKeys.contains(universeName.lowercased())
                    Button {
                        addPredefinedUniverse(named: universeName)
                    } label: {
                        CatalogSourceStatusRow(
                            name: universeName,
                            isAdded: isAdded,
                            status: catalogStatuses[universeName]
                        )
                    }
                    .disabled(isAdded)
                }
            } header: {
                Text("Vordefinierte Kataloge")
            } footer: {
                Text("Vordefinierte Kataloge liefern Titelvorschläge, sobald du eine passende Folgennummer eingibst.")
            }

            Section("Katalog-Updates") {
                Picker("Vordefinierter Katalog", selection: $selectedManagedCatalogName) {
                    ForEach(predefinedUniverseNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }

                Button {
                    refreshManagedCatalog(named: selectedManagedCatalogName)
                } label: {
                    Label("Ausgewählten Katalog aktualisieren", systemImage: "arrow.clockwise")
                }

                Button {
                    refreshAllManagedCatalogs()
                } label: {
                    Label("Alle Kataloge aktualisieren", systemImage: "arrow.triangle.2.circlepath")
                }

                if let catalogStatusMessage {
                    Text(catalogStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(catalogStatusIsError ? .red : .secondary)
                }
            }
        }
        .navigationTitle("Kataloge")
        .onAppear {
            if selectedManagedCatalogName.isEmpty {
                selectedManagedCatalogName = predefinedUniverseNames.first ?? ""
            }
            reloadCatalogStatuses()
        }
    }

    private func addPredefinedUniverse(named universeName: String) {
        let key = universeName.lowercased()
        guard !existingUniverseNameKeys.contains(key) else { return }
        modelContext.insert(Universe(name: universeName))
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

    private func deleteUniverses(at offsets: IndexSet) {
        validationMessage = nil

        for index in offsets {
            let universe = universes[index]
            if universe.episodes.isEmpty {
                modelContext.delete(universe)
            } else {
                validationMessage = "Nur leere Kataloge können gelöscht werden."
            }
        }
    }

    private func refreshManagedCatalog(named universeName: String) {
        Task {
            await EpisodeCatalog.shared.refreshManagedCatalog(universeName: universeName, force: true)
            await MainActor.run {
                reloadCatalogStatuses()
                catalogStatusIsError = false
                catalogStatusMessage = "Katalog aktualisiert für \(universeName)."
            }
        }
    }

    private func refreshAllManagedCatalogs() {
        Task {
            await EpisodeCatalog.shared.refreshManagedCatalogsIfNeeded(force: true)
            await MainActor.run {
                reloadCatalogStatuses()
                catalogStatusIsError = false
                catalogStatusMessage = "Alle vordefinierten Kataloge wurden aktualisiert."
            }
        }
    }

    private func reloadCatalogStatuses() {
        let store = CatalogCacheStore()
        catalogStatuses = Dictionary(
            uniqueKeysWithValues: predefinedUniverseNames.map { universeName in
                (universeName, store.loadRemoteCatalogStatus(universeName: universeName))
            }
        )
    }
}

private struct CatalogSourceStatusRow: View {
    let name: String
    let isAdded: Bool
    let status: CatalogCacheStatus?

    private var cacheText: String {
        guard let status, let cachedEntryCount = status.cachedEntryCount else {
            return "Noch kein Offline-Cache"
        }

        return "\(cachedEntryCount) Titel im Offline-Cache"
    }

    private var checkedText: String? {
        guard let lastCheckedAt = status?.lastCheckedAt else { return nil }
        return "Zuletzt geprüft: \(lastCheckedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .foregroundStyle(.primary)
                Text(cacheText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let checkedText {
                    Text(checkedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isAdded {
                Label("Aktiv", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.tint)
            }
        }
    }
}

private struct MoodManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Mood.name) private var moods: [Mood]

    @State private var newMoodName: String = ""
    @State private var newMoodIcon: String = ""
    @State private var validationMessage: String?

    private var suggestedMoods: [(name: String, icon: String)] {
        Mood.defaultSuggestions.filter { suggestion in
            !moods.contains { $0.name.caseInsensitiveCompare(suggestion.name) == .orderedSame }
        }
    }

    var body: some View {
        List {
            Section("Neue Stimmung") {
                HStack {
                    TextField("Name", text: $newMoodName)
                    TextField("Symbol", text: $newMoodIcon)
                        .frame(width: 56)
                        .multilineTextAlignment(.center)
                    Button("Hinzufügen") {
                        addMood(name: newMoodName, icon: newMoodIcon)
                    }
                    .disabled(newMoodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let validationMessage {
                    Text(validationMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if !suggestedMoods.isEmpty {
                Section("Standard-Vorschläge") {
                    ForEach(suggestedMoods, id: \.name) { suggestion in
                        Button {
                            addMood(name: suggestion.name, icon: suggestion.icon)
                        } label: {
                            HStack {
                                Text("\(suggestion.icon) \(suggestion.name)")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }

            Section {
                if moods.isEmpty {
                    ContentUnavailableView {
                        Label("Noch keine Stimmungen", systemImage: "tag")
                    } description: {
                        Text("Lege eigene Stimmungen an oder übernimm Standard-Vorschläge.")
                    }
                } else {
                    ForEach(moods) { mood in
                        HStack {
                            Text("\(mood.iconName ?? "") \(mood.name)")
                            Spacer()
                            if !mood.episodes.isEmpty {
                                Text("\(mood.episodes.count) Folgen")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteMoods)
                }
            } header: {
                Text("Vorhandene Stimmungen")
            } footer: {
                Text("Nur ungenutzte Stimmungen können gelöscht werden.")
            }
        }
        .navigationTitle("Stimmungen")
    }

    private func addMood(name: String, icon: String) {
        validationMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationMessage = "Bitte gib einen Namen ein."
            return
        }

        if moods.contains(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            validationMessage = "Diese Stimmung existiert bereits."
            return
        }

        let trimmedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        let mood = Mood(
            name: trimmedName,
            iconName: trimmedIcon.isEmpty ? nil : String(trimmedIcon.prefix(2))
        )
        modelContext.insert(mood)

        newMoodName = ""
        newMoodIcon = ""
    }

    private func deleteMoods(at offsets: IndexSet) {
        validationMessage = nil

        for index in offsets {
            let mood = moods[index]
            if mood.episodes.isEmpty {
                modelContext.delete(mood)
            } else {
                validationMessage = "Nur ungenutzte Stimmungen können gelöscht werden."
            }
        }
    }
}

private struct JSONBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct BackupPayload: Codable {
    let exportedAt: Date
    let schemaVersion: Int
    let collections: [BackupCollection]?
    let moods: [BackupMood]
    let episodes: [BackupEpisode]
}

private struct BackupCollection: Codable {
    let name: String
}

private struct BackupMood: Codable {
    let name: String
    let iconName: String?
}

private struct BackupEpisode: Codable {
    let episodeNumber: Int
    let title: String
    let releaseYear: Int
    let personalNote: String?
    let isListened: Bool
    let rating: Int?
    let listenCount: Int
    let lastListenedAt: Date?
    let collectionName: String?
    let moodNames: [String]
}

private extension JSONEncoder {
    static let backupEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

private extension JSONDecoder {
    static let backupDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
