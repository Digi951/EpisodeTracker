import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var containerAccess: AppContainerAccess
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @AppStorage("libraryTitle") private var libraryTitle: String = "Meine Hörspiele"
    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.system.rawValue
    @AppStorage(AppAccentColor.storageKey) private var appAccentColorRawValue: String = AppAccentColor.defaultValue.rawValue
    @AppStorage("showsLibrarySnapshot") private var showsLibrarySnapshot = true
    @AppStorage("prefersCatalogProgressTotals") private var prefersCatalogProgressTotals = true
    @AppStorage(AppModelContainerFactory.cloudSyncPreferenceKey) private var prefersICloudSync = false
    @AppStorage(AppModelContainerFactory.runtimeModeDebugTitleKey) private var runtimeModeDebugTitle = "Unbekannt"
    @AppStorage(AppModelContainerFactory.cloudStartupErrorKey) private var cloudStartupError = ""
    @AppStorage(AppDataBootstrapper.automaticCloudMigrationStatusKey) private var automaticCloudMigrationStatus = ""
    @AppStorage(SyncMigrationStateStore.completedMigrationMarkerKey) private var hasCompletedSyncMigration = false
    @Query(sort: \Universe.name) private var universes: [Universe]
    @Query(sort: \Mood.name) private var moods: [Mood]
    @Query(sort: \Episode.episodeNumber) private var episodes: [Episode]

    @State private var activeCatalogIDs = ActiveCatalogStore().activeIDs
    @State private var backupStatusMessage: String?
    @State private var backupStatusIsError = false
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportDocument: JSONBackupDocument?
    @State private var pendingImportURL: URL?
    @State private var showingResetConfirmation = false
    @State private var syncMigrationStatusMessage: String?
    @State private var syncMigrationStatusIsError = false

    private var containerMode: AppModelContainerMode {
        AppModelContainerFactory.resolveMode()
    }

    private var cloudGuardEnabled: Bool {
        AppModelContainerFactory.isCloudSyncGuardEnabled()
    }

    private var showsInternalSyncControls: Bool {
        AppModelContainerFactory.showsInternalSyncControls()
    }

#if DEBUG
    private var syncDiagnosticsContext: SettingsSyncDiagnosticsContext {
        SettingsSyncDiagnosticsContext(
            requestedModeTitle: containerMode.debugTitle,
            runtimeModeDebugTitle: runtimeModeDebugTitle,
            cloudGuardEnabled: cloudGuardEnabled,
            cloudContainerIdentifier: AppModelContainerFactory.cloudContainerIdentifier,
            cloudStartupError: cloudStartupError,
            automaticCloudMigrationStatus: automaticCloudMigrationStatus,
            migrationReadiness: SyncMigrationReadinessEvaluator.evaluate(
                containerSet: containerAccess.containerSet,
                userDefaults: .standard
            )
        )
    }
#endif

    var body: some View {
        List {
            SettingsLibrarySection(
                libraryTitle: $libraryTitle,
                appearanceModeRawValue: $appearanceModeRawValue,
                appAccentColorRawValue: $appAccentColorRawValue,
                showsLibrarySnapshot: $showsLibrarySnapshot,
                prefersCatalogProgressTotals: $prefersCatalogProgressTotals
            )
            SettingsStreamingSection(appAccentColorRawValue: $appAccentColorRawValue)
            SettingsManagementSection(
                activeCatalogCount: activeCatalogCount,
                managedCatalogCount: managedCatalogCount,
                moodCount: moods.count
            )
            SettingsBackupSection(
                episodeCount: episodes.count,
                backupStatusMessage: backupStatusMessage,
                backupStatusIsError: backupStatusIsError,
                onExport: exportBackup,
                onImport: { showingImporter = true }
            )

            SettingsResetSection(
                onReset: { showingResetConfirmation = true }
            )

            SettingsSyncSection(
                prefersICloudSync: $prefersICloudSync
            )

#if DEBUG
            if showsInternalSyncControls {
                SettingsSyncDiagnosticsSection(
                    diagnostics: syncDiagnosticsContext,
                    migrationStatusMessage: syncMigrationStatusMessage,
                    migrationStatusIsError: syncMigrationStatusIsError,
                    onRunMigration: runInternalSyncMigration
                )
            }
#endif

            SettingsAboutSection()
        }
        .navigationTitle("Einstellungen")
        .tint(AppAccentColor.resolved(from: appAccentColorRawValue).color)
        .listStyle(.insetGrouped)
        .contentMargins(.horizontal, horizontalSizeClass == .regular ? 104 : 0, for: .scrollContent)
        .contentMargins(.top, horizontalSizeClass == .regular ? 12 : 0, for: .scrollContent)
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
        .confirmationDialog(
            "Darstellung zurücksetzen?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Zurücksetzen", role: .destructive) {
                resetDisplaySettings()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Zurückgesetzt werden Sammlungsname, Darstellung, sichtbarer Hörstand und die Katalogfortschritts-Anzeige.")
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") {
                    dismissKeyboard()
                }
            }
        }
        .onAppear {
            activeCatalogIDs = ActiveCatalogStore().activeIDs
        }
    }

    private var managedCatalogCount: Int {
        CatalogSourceRegistry.managedSources.count
    }

    private var activeCatalogCount: Int {
        CatalogSourceRegistry.managedSources.filter { activeCatalogIDs.contains($0.id) }.count
    }

#if DEBUG
    @MainActor
    private func runInternalSyncMigration() {
        let result = SettingsSyncDiagnosticsRunner.runMigration(
            containerSet: containerAccess.containerSet,
            userDefaults: UserDefaults.standard
        )
        syncMigrationStatusIsError = result.isError
        syncMigrationStatusMessage = result.message
    }
#endif

    private var backupFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "HoerspielLog-Backup-\(formatter.string(from: .now))"
    }

    private func resetDisplaySettings() {
        libraryTitle = "Meine Hörspiele"
        appearanceModeRawValue = AppearanceMode.system.rawValue
        appAccentColorRawValue = AppAccentColor.defaultValue.rawValue
        showsLibrarySnapshot = true
        prefersCatalogProgressTotals = true
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

private struct SettingsLibrarySection: View {
    @Binding var libraryTitle: String
    @Binding var appearanceModeRawValue: String
    @Binding var appAccentColorRawValue: String
    @Binding var showsLibrarySnapshot: Bool
    @Binding var prefersCatalogProgressTotals: Bool

    private var appAccentColor: Color {
        AppAccentColor.resolved(from: appAccentColorRawValue).color
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    var body: some View {
        Section {
            TextField("Sammlungsname", text: $libraryTitle)
            SettingsMenuSelectionRow(
                title: "Design",
                valueSystemImage: appearanceMode.iconName,
                value: appearanceMode.title,
                accentColor: appAccentColor
            ) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Button {
                        appearanceModeRawValue = mode.rawValue
                    } label: {
                        Label(mode.title, systemImage: mode.iconName)
                    }
                }
            }
            AccentColorPickerRow(selection: $appAccentColorRawValue)
            Toggle("Hörstand anzeigen", isOn: $showsLibrarySnapshot)
            Toggle("Katalogfortschritt verwenden", isOn: $prefersCatalogProgressTotals)
        } header: {
            Text("Mediathek")
        } footer: {
            Text("Der Sammlungsname erscheint oben in deiner Folgenliste. Den Hörstand kannst du ausblenden, wenn du lieber direkt mit der Liste startest. Bei bekannten Katalogen kann der Fortschritt optional gegen den gesamten Katalog statt nur gegen deine Bibliothek berechnet werden.")
        }
    }
}

private struct AccentColorPickerRow: View {
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Akzentfarbe")

            HStack(spacing: 14) {
                ForEach(AppAccentColor.allCases) { accentColor in
                    Button {
                        selection = accentColor.rawValue
                    } label: {
                        Circle()
                            .fill(accentColor.color)
                            .frame(width: 30, height: 30)
                            .overlay {
                                if selection == accentColor.rawValue {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .overlay(
                                Circle()
                                    .stroke(selection == accentColor.rawValue ? Color.primary : Color.secondary.opacity(0.22), lineWidth: selection == accentColor.rawValue ? 2 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accentColor.title)
                    .accessibilityAddTraits(selection == accentColor.rawValue ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SettingsManagementSection: View {
    let activeCatalogCount: Int
    let managedCatalogCount: Int
    let moodCount: Int

    var body: some View {
        Section("Verwalten") {
            NavigationLink {
                CatalogManagementView()
            } label: {
                SettingsNavigationRow(
                    title: "Kataloge",
                    subtitle: "\(activeCatalogCount) von \(managedCatalogCount) Katalogen aktiv",
                    systemImage: "books.vertical"
                )
            }

            NavigationLink {
                MoodManagementView()
            } label: {
                SettingsNavigationRow(
                    title: "Stimmungen",
                    subtitle: "\(moodCount) Stimmungen gespeichert",
                    systemImage: "tag"
                )
            }
        }
    }
}

private struct SettingsBackupSection: View {
    let episodeCount: Int
    let backupStatusMessage: String?
    let backupStatusIsError: Bool
    let onExport: () -> Void
    let onImport: () -> Void

    var body: some View {
        Section {
            Button(action: onExport) {
                SettingsActionRow(
                    title: "Backup exportieren",
                    subtitle: "\(episodeCount) Folgen sichern",
                    systemImage: "square.and.arrow.up"
                )
            }

            Button(action: onImport) {
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
    }
}

private struct SettingsResetSection: View {
    let onReset: () -> Void

    var body: some View {
        Section("Zurücksetzen") {
            Button(role: .destructive, action: onReset) {
                Label("Darstellung zurücksetzen", systemImage: "arrow.counterclockwise")
            }
        }
    }
}

private struct SettingsStreamingSection: View {
    @Binding var appAccentColorRawValue: String
    @AppStorage("preferredStreamingService") private var preferredServiceRaw = StreamingService.spotify.rawValue

    private var appAccentColor: Color {
        AppAccentColor.resolved(from: appAccentColorRawValue).color
    }

    private var selectedService: Binding<StreamingService> {
        Binding(
            get: { StreamingService(rawValue: preferredServiceRaw) ?? .spotify },
            set: { preferredServiceRaw = $0.rawValue }
        )
    }

    var body: some View {
        Section {
            SettingsMenuSelectionRow(
                title: "Streaming-Dienst",
                valueSystemImage: selectedService.wrappedValue.iconName,
                value: selectedService.wrappedValue.displayName,
                accentColor: appAccentColor
            ) {
                ForEach(StreamingService.allCases) { service in
                    Button {
                        selectedService.wrappedValue = service
                    } label: {
                        Label(service.displayName, systemImage: service.iconName)
                    }
                }
            }
        } header: {
            Text("Streaming")
        } footer: {
            Text("In der Folgendetailansicht kannst du verfügbare Kataloglinks direkt im gewählten Dienst öffnen.")
        }
    }
}

private struct SettingsMenuSelectionRow<MenuContent: View>: View {
    let title: String
    let valueSystemImage: String
    let value: String
    let accentColor: Color
    @ViewBuilder let menuContent: () -> MenuContent

    var body: some View {
        Menu {
            menuContent()
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                HStack(spacing: 4) {
                    Image(systemName: valueSystemImage)
                    Text(value)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(accentColor)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsSyncSection: View {
    @Binding var prefersICloudSync: Bool

    var body: some View {
        Section {
            Toggle("iCloud-Sync", isOn: $prefersICloudSync)
        } header: {
            Text("Sync")
        } footer: {
            Text("Cloud-Sync wird erst nach dem nächsten App-Start aktiv.")
        }
    }
}

private struct SettingsAboutSection: View {
    var body: some View {
        Section {
            SettingsValueRow(label: "Version", value: Bundle.main.appVersionDisplay)
        } header: {
            Text("Über")
        }
    }
}

#if DEBUG
private struct SettingsSyncDiagnosticsContext {
    let requestedModeTitle: String
    let runtimeModeDebugTitle: String
    let cloudGuardEnabled: Bool
    let cloudContainerIdentifier: String
    let cloudStartupError: String
    let automaticCloudMigrationStatus: String
    let migrationReadiness: SyncMigrationReadiness
}

private enum SettingsSyncDiagnosticsRunner {
    struct Result {
        let isError: Bool
        let message: String
    }

    @MainActor
    static func runMigration(
        containerSet: AppModelContainerSet,
        userDefaults: UserDefaults
    ) -> Result {
        guard let localContainer = containerSet.localPersistent,
              let cloudContainer = containerSet.cloudPersistent else {
            return Result(
                isError: true,
                message: "Migration ist nur moeglich, wenn lokaler und Cloud-Container verfuegbar sind."
            )
        }

        let readiness = SyncMigrationReadinessEvaluator.evaluate(
            containerSet: containerSet,
            userDefaults: userDefaults
        )
        guard readiness.canAttemptMigration else {
            return Result(
                isError: true,
                message: "Migration ist derzeit nicht freigegeben."
            )
        }

        let snapshot = LocalLibrarySnapshot.capture(context: localContainer.mainContext)

        do {
            let report = try SyncMigrationCoordinator.migrate(
                snapshot: snapshot,
                into: cloudContainer.mainContext,
                userDefaults: userDefaults
            )
            if report.validationIssues.isEmpty {
                return Result(
                    isError: false,
                    message: "Migration abgeschlossen: \(report.migratedEpisodeCount) Folgen, \(report.migratedUniverseCount) Sammlungen, \(report.migratedMoodCount) Stimmungen."
                )
            }

            return Result(
                isError: true,
                message: "Migration beendet mit \(report.validationIssues.count) Validierungshinweisen."
            )
        } catch {
            return Result(
                isError: true,
                message: "Migration fehlgeschlagen: \(error.localizedDescription)"
            )
        }
    }
}

private struct SettingsSyncDiagnosticsSection: View {
    let diagnostics: SettingsSyncDiagnosticsContext
    let migrationStatusMessage: String?
    let migrationStatusIsError: Bool
    let onRunMigration: () -> Void

    var body: some View {
        Section {
            SettingsValueRow(label: "Angeforderter Modus", value: diagnostics.requestedModeTitle)
            SettingsValueRow(label: "Aktiver Modus", value: diagnostics.runtimeModeDebugTitle)
            SettingsValueRow(label: "Interner Schutzschalter", value: diagnostics.cloudGuardEnabled ? "Aktiv" : "Aus")
            SettingsValueRow(label: "Container", value: diagnostics.cloudContainerIdentifier)
            SettingsValueRow(label: "Migration abgeschlossen", value: diagnostics.migrationReadiness.hasCompletedMigration ? "Ja" : "Nein")
            SettingsValueRow(label: "Lokale Daten", value: "\(diagnostics.migrationReadiness.localEpisodeCount) Folgen, \(diagnostics.migrationReadiness.localUniverseCount) Sammlungen, \(diagnostics.migrationReadiness.localMoodCount) Stimmungen")
            SettingsValueRow(label: "Cloud-Ziel aktiv", value: diagnostics.migrationReadiness.hasCloudPersistentContainer ? "Ja" : "Nein")
            SettingsValueRow(label: "Migration moeglich", value: diagnostics.migrationReadiness.canAttemptMigration ? "Ja" : "Nein")
            if !diagnostics.migrationReadiness.localValidationIssues.isEmpty {
                Text("Validierung: \(diagnostics.migrationReadiness.localValidationIssues.count) Hinweis(e)")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            if diagnostics.migrationReadiness.canAttemptMigration {
                Button("Lokale Daten intern in Cloud uebernehmen", action: onRunMigration)
            }
            if let migrationStatusMessage {
                Text(migrationStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(migrationStatusIsError ? .red : .secondary)
            }
            if !diagnostics.automaticCloudMigrationStatus.isEmpty {
                Text(diagnostics.automaticCloudMigrationStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if !diagnostics.cloudStartupError.isEmpty {
                Text(diagnostics.cloudStartupError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        } header: {
            Text("Interne Sync-Optionen")
        } footer: {
            Text("Nur fuer Entwicklung und Tests: Cloud-Sync wird erst nach dem naechsten App-Start aktiv, wenn Anforderung und Schutzschalter gleichzeitig gesetzt sind.")
        }
    }
}
#endif

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

private struct SettingsValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
            Spacer()
            Text(value)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private extension Bundle {
    var appVersionDisplay: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
