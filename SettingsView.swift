import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.appContainerSet) private var appContainerSet
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
    @State private var selectedAppIconName: String?
    @State private var appIconStatusMessage: String?
    @State private var appIconStatusIsError = false
    @State private var isChangingAppIcon = false

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
                containerSet: appContainerSet!,
                userDefaults: .standard
            )
        )
    }
#endif

    var body: some View {
        List {
            SettingsLibrarySection(
                libraryTitle: $libraryTitle,
                showsLibrarySnapshot: $showsLibrarySnapshot,
                prefersCatalogProgressTotals: $prefersCatalogProgressTotals
            )
            SettingsPersonalizationSection(
                appearanceModeRawValue: $appearanceModeRawValue,
                appAccentColorRawValue: $appAccentColorRawValue,
                selectedIconName: selectedAppIconName,
                statusMessage: appIconStatusMessage,
                statusIsError: appIconStatusIsError,
                isChangingIcon: isChangingAppIcon,
                onSelectIcon: changeAppIcon
            )
            SettingsManagementSection(
                activeCatalogCount: activeCatalogCount,
                managedCatalogCount: managedCatalogCount,
                moodCount: moods.count
            )
            SettingsCustomizationSection()
            SettingsStreamingSection(appAccentColorRawValue: $appAccentColorRawValue)
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

            if let storeRecovery = AppModelContainerFactory.lastStoreRecovery() {
                SettingsStoreRecoverySection(record: storeRecovery)
            }

#if DEBUG
            SettingsDemoSection()
#endif
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
            selectedAppIconName = currentAlternateAppIconName
        }
    }

    private var currentAlternateAppIconName: String? {
#if canImport(UIKit)
        UIApplication.shared.alternateIconName
#else
        nil
#endif
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
            containerSet: appContainerSet!,
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

    private func changeAppIcon(to icon: AppIconChoice) {
#if canImport(UIKit)
        guard UIApplication.shared.supportsAlternateIcons else {
            appIconStatusIsError = true
            appIconStatusMessage = "Dieses Gerät unterstützt keine alternativen App-Icons."
            return
        }

        guard selectedAppIconName != icon.alternateIconName else {
            return
        }

        isChangingAppIcon = true
        appIconStatusMessage = nil

        UIApplication.shared.setAlternateIconName(icon.alternateIconName) { error in
            Task { @MainActor in
                isChangingAppIcon = false

                if let error {
                    appIconStatusIsError = true
                    appIconStatusMessage = "Icon konnte nicht geändert werden: \(error.localizedDescription)"
                } else {
                    selectedAppIconName = icon.alternateIconName
                    appIconStatusIsError = false
                    appIconStatusMessage = "\(icon.title) ist jetzt aktiv."
                }
            }
        }
#else
        appIconStatusIsError = true
        appIconStatusMessage = "Alternative App-Icons sind auf dieser Plattform nicht verfügbar."
#endif
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
                kind: episode.kind,
                catalogSlug: episode.catalogSlug,
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
            schemaVersion: 2,
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
            let universeNameKey = episode.universe?.name.lowercased() ?? "allgemein"
            let identity: String
            if episode.isSpecial, let slug = episode.catalogSlug, !slug.isEmpty {
                identity = "special:\(slug)"
            } else {
                identity = String(episode.episodeNumber)
            }
            episodesByKey["\(universeNameKey)#\(identity)"] = episode
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

            let identity: String
            if episodeData.kind == .special, let slug = episodeData.catalogSlug, !slug.isEmpty {
                identity = "special:\(slug)"
            } else {
                identity = String(episodeData.episodeNumber)
            }
            let episodeKey = "\(universeKey)#\(identity)"

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
                existingEpisode.kind = episodeData.kind
                if let slug = episodeData.catalogSlug { existingEpisode.catalogSlug = slug }
                existingEpisode.refreshSyncKeyIfPossible()
            } else {
                let newEpisode = Episode(
                    episodeNumber: episodeData.episodeNumber,
                    title: episodeData.title,
                    releaseYear: episodeData.releaseYear,
                    kind: episodeData.kind,
                    catalogSlug: episodeData.catalogSlug,
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
    @Binding var showsLibrarySnapshot: Bool
    @Binding var prefersCatalogProgressTotals: Bool

    var body: some View {
        Section {
            TextField("Sammlungsname", text: $libraryTitle)
            Toggle("Hörstand anzeigen", isOn: $showsLibrarySnapshot)
            Toggle("Katalogfortschritt verwenden", isOn: $prefersCatalogProgressTotals)
        } header: {
            Text("Mediathek")
        } footer: {
            Text("Der Sammlungsname erscheint oben in deiner Folgenliste. Den Hörstand kannst du ausblenden, wenn du lieber direkt mit der Liste startest. Bei bekannten Katalogen kann der Fortschritt optional gegen den gesamten Katalog statt nur gegen deine Bibliothek berechnet werden.")
        }
    }
}

private struct SettingsPersonalizationSection: View {
    @Binding var appearanceModeRawValue: String
    @Binding var appAccentColorRawValue: String
    let selectedIconName: String?
    let statusMessage: String?
    let statusIsError: Bool
    let isChangingIcon: Bool
    let onSelectIcon: (AppIconChoice) -> Void

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    var body: some View {
        Section("Darstellung") {
            AccentColorPickerRow(selection: $appAccentColorRawValue)

            Picker("Erscheinungsbild", selection: $appearanceModeRawValue) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)

#if canImport(UIKit)
            if UIApplication.shared.supportsAlternateIcons {
                NavigationLink {
                    SettingsAppIconSelectionView(
                        selectedIconName: selectedIconName,
                        statusMessage: statusMessage,
                        statusIsError: statusIsError,
                        isChangingIcon: isChangingIcon,
                        onSelect: onSelectIcon
                    )
                } label: {
                    SettingsNavigationRow(
                        title: "App-Icon",
                        subtitle: AppIconChoice.resolved(from: selectedIconName).title,
                        systemImage: "app"
                    )
                }
            }
#endif
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

private enum AppIconChoice: String, CaseIterable, Identifiable {
    case standard
    case retro
    case cassette
    case headphones

    var id: String { rawValue }

    var alternateIconName: String? {
        switch self {
        case .standard:
            nil
        case .retro:
            "AppIconRetro"
        case .cassette:
            "AppIconCassette"
        case .headphones:
            "AppIconHeadphones"
        }
    }

    var title: String {
        switch self {
        case .standard:
            "Standard"
        case .retro:
            "Retro"
        case .cassette:
            "Kassette"
        case .headphones:
            "Kopfhörer"
        }
    }

    var subtitle: String {
        switch self {
        case .standard:
            "Audiowelle"
        case .retro:
            "Blaues Originalsymbol"
        case .cassette:
            "Retro mit Hörspielgefühl"
        case .headphones:
            "Direkt als Audio-App lesbar"
        }
    }

    var previewImageName: String {
        switch self {
        case .standard:
            "AppIconStandardPreview"
        case .retro:
            "AppIconRetroPreview"
        case .cassette:
            "AppIconCassettePreview"
        case .headphones:
            "AppIconHeadphonesPreview"
        }
    }

    static func resolved(from alternateIconName: String?) -> AppIconChoice {
        allCases.first { $0.alternateIconName == alternateIconName } ?? .standard
    }
}


private struct SettingsAppIconSelectionView: View {
    let selectedIconName: String?
    let statusMessage: String?
    let statusIsError: Bool
    let isChangingIcon: Bool
    let onSelect: (AppIconChoice) -> Void

    var body: some View {
        List {
            Section {
                ForEach(AppIconChoice.allCases) { icon in
                    Button {
                        onSelect(icon)
                    } label: {
                        SettingsAppIconRow(
                            icon: icon,
                            isSelected: selectedIconName == icon.alternateIconName
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isChangingIcon)
                }
            } footer: {
                Text("iOS zeigt beim Wechsel einen kurzen Systemhinweis. Die Änderung gilt direkt für den Home-Bildschirm.")
            }

            if let statusMessage {
                Section {
                    SettingsAppIconStatusRow(
                        message: statusMessage,
                        isError: statusIsError
                    )
                }
            }
        }
        .navigationTitle("App-Icon")
        .listStyle(.insetGrouped)
    }
}

private struct SettingsAppIconRow: View {
    let icon: AppIconChoice
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(icon.previewImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(icon.title)
                    .foregroundStyle(.primary)
                Text(icon.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                    .imageScale(.large)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SettingsAppIconStatusRow: View {
    let message: String
    let isError: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isError ? .red : .green)
                .frame(width: 18, alignment: .center)

            Text(message)
                .font(.footnote)
                .foregroundStyle(isError ? .red : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
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
                    title: String(localized: "Kataloge"),
                    subtitle: AppLocalization.format(
                        "Settings.Manage.CatalogsSubtitle",
                        defaultValue: "%lld von %lld Katalogen aktiv",
                        Int64(activeCatalogCount),
                        Int64(managedCatalogCount)
                    ),
                    systemImage: "books.vertical"
                )
            }

            NavigationLink {
                MoodManagementView()
            } label: {
                SettingsNavigationRow(
                    title: String(localized: "Stimmungen"),
                    subtitle: AppLocalization.format(
                        "Settings.Manage.MoodsSubtitle",
                        defaultValue: "%lld Stimmungen gespeichert",
                        Int64(moodCount)
                    ),
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
                    title: String(localized: "Backup exportieren"),
                    subtitle: AppLocalization.format(
                        "Settings.Backup.ExportSubtitle",
                        defaultValue: "%lld Folgen sichern",
                        Int64(episodeCount)
                    ),
                    systemImage: "square.and.arrow.up"
                )
            }

            Button(action: onImport) {
                SettingsActionRow(
                    title: String(localized: "Backup importieren"),
                    subtitle: String(localized: "Folgen, Kataloge und Stimmungen wiederherstellen"),
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
    @AppStorage("preferredStreamingService") private var preferredServiceRaw = StreamingMarketProfile.current.defaultService.rawValue

    private var appAccentColor: Color {
        AppAccentColor.resolved(from: appAccentColorRawValue).color
    }

    private var selectedService: Binding<StreamingService> {
        Binding(
            get: {
                let profile = StreamingMarketProfile.current
                guard let service = StreamingService(rawValue: preferredServiceRaw),
                      profile.services.contains(service)
                else {
                    return profile.defaultService
                }
                return service
            },
            set: { preferredServiceRaw = $0.rawValue }
        )
    }

    var body: some View {
        Section {
            SettingsMenuSelectionRow(
                title: String(localized: "Settings.Streaming.Service", defaultValue: "Streaming-Dienst"),
                valueSystemImage: selectedService.wrappedValue.iconName,
                value: selectedService.wrappedValue.displayName,
                accentColor: appAccentColor
            ) {
                ForEach(StreamingMarketProfile.current.services) { service in
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
                    .lineLimit(1)

                Spacer(minLength: 12)

                HStack(spacing: 4) {
                    Image(systemName: valueSystemImage)
                    Text(value)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(accentColor)
                .fixedSize(horizontal: true, vertical: false)
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

/// On-device diagnostics: only rendered when the persistent store had to be
/// recovered at launch. Lets the developer ask an affected user to read this out
/// of Settings instead of needing the device's crash logs. Nothing is transmitted.
private struct SettingsStoreRecoverySection: View {
    let record: AppModelContainerFactory.StoreRecoveryRecord

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.outcome.localizedTitle)
                    .font(.callout)
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !record.detail.isEmpty {
                Text(record.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        } header: {
            Text("Datenbank-Diagnose")
        } footer: {
            Text("Die Datenbank musste beim Start automatisch repariert werden. Diese Angabe hilft bei der Fehlersuche und verlässt das Gerät nicht.")
        }
    }
}

private struct SettingsCustomizationSection: View {
    var body: some View {
        Section("Anpassen") {
            NavigationLink {
                SavedFilterManagementView()
            } label: {
                Label(
                    String(localized: "Settings.SavedFilters.Label",
                           defaultValue: "Meine Listen"),
                    systemImage: "line.3.horizontal.decrease.circle.fill"
                )
            }
            NavigationLink {
                EpisodeEditSectionOrderView()
            } label: {
                Label(
                    String(localized: "Settings.EpisodeEditOrder.Label",
                           defaultValue: "Felder-Reihenfolge"),
                    systemImage: "list.number"
                )
            }
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

#if DEBUG
private struct SettingsDemoSection: View {
    @AppStorage(DemoDataProvider.userDefaultsKey) private var isDemoModeActive = false

    var body: some View {
        Section {
            Toggle("Demo-Modus", isOn: $isDemoModeActive)
        } header: {
            Text("Entwicklung")
        } footer: {
            Text("Demo-Modus füllt die App mit fiktiven Hörspieldaten. Tritt nach dem nächsten App-Start in Kraft. Echte Daten bleiben unberührt.")
        }
    }
}
#endif
