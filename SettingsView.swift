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
    @State private var backup = BackupExportImportController()
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
            // Gliederung nach Design Review 2026-11, Befund 7: fünf Abschnitte
            // statt neun, iCloud-Sync nicht mehr ganz unten.
            SettingsLibrarySection(
                libraryTitle: $libraryTitle,
                activeCatalogCount: activeCatalogCount,
                managedCatalogCount: managedCatalogCount,
                moodCount: moods.count,
                appAccentColorRawValue: $appAccentColorRawValue
            )
            SettingsPersonalizationSection(
                appearanceModeRawValue: $appearanceModeRawValue,
                appAccentColorRawValue: $appAccentColorRawValue,
                showsLibrarySnapshot: $showsLibrarySnapshot,
                selectedIconName: selectedAppIconName,
                statusMessage: appIconStatusMessage,
                statusIsError: appIconStatusIsError,
                isChangingIcon: isChangingAppIcon,
                onSelectIcon: changeAppIcon
            )
            SettingsDataSyncSection(
                prefersICloudSync: $prefersICloudSync,
                runningWithICloudSync: appContainerSet?.runtimeMode.usesCloudSync ?? false,
                episodeCount: episodes.count,
                backupStatusMessage: backup.statusMessage,
                backupStatusIsError: backup.statusIsError,
                onExport: { backup.export(universes: universes, moods: moods, episodes: episodes) },
                onImport: { backup.showingImporter = true }
            )
            SettingsAdvancedSection(
                prefersCatalogProgressTotals: $prefersCatalogProgressTotals,
                onReset: { showingResetConfirmation = true }
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
        // Auf dem iPhone die Standard-Einrückung von `insetGrouped` behalten:
        // mit 0 liefen die Abschnitte randlos, anders als jeder andere Screen.
        .contentMargins(.horizontal, horizontalSizeClass == .regular ? 104 : nil, for: .scrollContent)
        .contentMargins(.top, horizontalSizeClass == .regular ? 12 : 0, for: .scrollContent)
        .fileExporter(
            isPresented: $backup.showingExporter,
            document: backup.exportDocument,
            contentType: .json,
            defaultFilename: backup.backupFileName
        ) { result in
            backup.handleExportResult(result)
        }
        .fileImporter(
            isPresented: $backup.showingImporter,
            allowedContentTypes: [.json]
        ) { result in
            backup.handleImportPick(result)
        }
        .confirmationDialog(
            "Backup importieren?",
            isPresented: Binding(
                get: { backup.pendingImportURL != nil },
                set: { isPresented in
                    if !isPresented {
                        backup.cancelImport()
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Import starten") {
                backup.confirmImport(
                    existingUniverses: universes,
                    existingMoods: moods,
                    existingEpisodes: episodes,
                    context: modelContext
                )
            }
            Button("Abbrechen", role: .cancel) {
                backup.cancelImport()
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

}

private struct SettingsLibrarySection: View {
    @Binding var libraryTitle: String
    let activeCatalogCount: Int
    let managedCatalogCount: Int
    let moodCount: Int
    @Binding var appAccentColorRawValue: String

    var body: some View {
        Section {
            // Beschriftet statt eines nackten Textfelds, das wie statischer
            // Text aussah (Design Review 2026-11, Befund 7).
            // HStack statt LabeledContent: Mit der Icon-Kachel brach der Wert
            // sonst in eine zweite Zeile um.
            HStack(spacing: 12) {
                SettingsIconLabel(
                    String(localized: "Settings.Library.Name", defaultValue: "Name der Bibliothek"),
                    systemImage: "character.cursor.ibeam"
                )
                .lineLimit(1)
                .layoutPriority(1)
                TextField(String(localized: "Settings.Library.Name", defaultValue: "Name der Bibliothek"), text: $libraryTitle)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }

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

            NavigationLink {
                SavedFilterManagementView()
            } label: {
                SettingsIconLabel(
                    String(localized: "Settings.SavedFilters.Label", defaultValue: "Meine Listen"),
                    systemImage: "line.3.horizontal.decrease"
                )
            }

            SettingsStreamingRow(appAccentColorRawValue: $appAccentColorRawValue)
        } header: {
            Text(String(localized: "Settings.Library.Header", defaultValue: "Bibliothek"))
        } footer: {
            Text("In der Folgendetailansicht kannst du verfügbare Kataloglinks direkt im gewählten Dienst öffnen.")
        }
    }
}

private struct SettingsPersonalizationSection: View {
    @Binding var appearanceModeRawValue: String
    @Binding var appAccentColorRawValue: String
    @Binding var showsLibrarySnapshot: Bool
    let selectedIconName: String?
    let statusMessage: String?
    let statusIsError: Bool
    let isChangingIcon: Bool
    let onSelectIcon: (AppIconChoice) -> Void
    @AppStorage(SeasonalContext.accentsEnabledKey) private var seasonalAccentsEnabled = true

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    var body: some View {
        Section {
            AccentColorPickerRow(selection: $appAccentColorRawValue)

            Picker(selection: $appearanceModeRawValue) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            } label: {
                SettingsIconLabel("Erscheinungsbild", systemImage: "circle.lefthalf.filled")
            }
            // Menü statt Segmenten: so steht die Beschriftung
            // „Erscheinungsbild“ sichtbar in der Zeile.
            .pickerStyle(.menu)

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
                        systemImage: "apps.iphone"
                    )
                }
            }
#endif

            Toggle(isOn: $showsLibrarySnapshot) {
                SettingsIconLabel("Hörstand anzeigen", systemImage: "chart.bar.fill")
            }

            Toggle(isOn: $seasonalAccentsEnabled) {
                SettingsIconLabel("Saisonale Akzente", systemImage: "snowflake")
            }
        } header: {
            Text("Darstellung")
        } footer: {
            Text("Im Dezember zeigt „Als nächstes“ deine Weihnachtsfolgen.")
        }
    }
}

private struct AccentColorPickerRow: View {
    @Binding var selection: String

    var body: some View {
        // Farbkreise unter dem Text statt unter der Kachel: deshalb im
        // Titel-Teil des Labels, nicht als eigene Zeile darunter.
        Label {
            VStack(alignment: .leading, spacing: 10) {
                Text("Akzentfarbe")

                HStack(spacing: 10) {
                    ForEach(AppAccentColor.allCases) { accentColor in
                        Button {
                            selection = accentColor.rawValue
                        } label: {
                            Circle()
                                .fill(accentColor.color)
                                .frame(width: 26, height: 26)
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
        } icon: {
            SettingsIconTile(systemImage: "paintpalette.fill")
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

private struct SettingsDataSyncSection: View {
    @Binding var prefersICloudSync: Bool
    /// Läuft die App gerade mit CloudKit? Weicht der Schalter davon ab, wirkt
    /// die Änderung erst nach einem Neustart — das steht dann direkt unter dem
    /// Schalter statt nur im Footer (Design Review 2026-11, Befund 7).
    let runningWithICloudSync: Bool
    let episodeCount: Int
    let backupStatusMessage: String?
    let backupStatusIsError: Bool
    let onExport: () -> Void
    let onImport: () -> Void

    var body: some View {
        Section {
            Toggle(isOn: $prefersICloudSync) {
                SettingsIconLabel("iCloud-Sync", systemImage: "icloud.fill")
            }

            if prefersICloudSync != runningWithICloudSync {
                Label {
                    Text(prefersICloudSync
                        ? String(localized: "Settings.Sync.RestartToEnable", defaultValue: "Schließe die App und öffne sie neu, damit iCloud-Sync startet.")
                        : String(localized: "Settings.Sync.RestartToDisable", defaultValue: "Schließe die App und öffne sie neu, damit iCloud-Sync endet.")
                    )
                    .font(.footnote)
                } icon: {
                    Image(systemName: "arrow.clockwise")
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.orange)
            }

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
            .buttonStyle(.plain)

            Button(action: onImport) {
                SettingsActionRow(
                    title: String(localized: "Backup importieren"),
                    subtitle: String(localized: "Folgen, Kataloge und Stimmungen wiederherstellen"),
                    systemImage: "square.and.arrow.down"
                )
            }
            // Zeilen wie die übrigen Einträge, nicht als blaue Links.
            .buttonStyle(.plain)

            if let backupStatusMessage {
                Text(backupStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(backupStatusIsError ? .red : .secondary)
            }
        } header: {
            Text(String(localized: "Settings.DataSync.Header", defaultValue: "Daten & Sync"))
        } footer: {
            Text("Backups bleiben lokal als JSON-Datei und enthalten deine Folgen, Kataloge, Stimmungen und Notizen.")
        }
    }
}

private struct SettingsAdvancedSection: View {
    @Binding var prefersCatalogProgressTotals: Bool
    let onReset: () -> Void

    var body: some View {
        Section {
            Toggle(isOn: $prefersCatalogProgressTotals) {
                SettingsNavigationRow(
                    title: String(localized: "Katalogfortschritt verwenden"),
                    subtitle: String(
                        localized: "Settings.Advanced.CatalogProgressSubtitle",
                        defaultValue: "Fortschritt gegen den ganzen Katalog statt nur gegen deine Bibliothek"
                    ),
                    systemImage: "chart.pie.fill"
                )
            }

            NavigationLink {
                EpisodeEditSectionOrderView()
            } label: {
                SettingsIconLabel(
                    String(localized: "Settings.EpisodeEditOrder.Label", defaultValue: "Felder-Reihenfolge"),
                    systemImage: "arrow.up.arrow.down"
                )
            }

            Button(role: .destructive, action: onReset) {
                // Rote Kachel zum roten Text, statt Akzent-Icon neben rotem Text.
                SettingsIconLabel("Darstellung zurücksetzen", systemImage: "arrow.counterclockwise", tileColor: .red)
            }
        } header: {
            Text(String(localized: "Settings.Advanced.Header", defaultValue: "Erweitert"))
        }
    }
}

private struct SettingsStreamingRow: View {
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
        SettingsMenuSelectionRow(
            title: String(localized: "Settings.Streaming.Service", defaultValue: "Streaming-Dienst"),
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
    }
}

private struct SettingsMenuSelectionRow<MenuContent: View>: View {
    let title: String
    let value: String
    let accentColor: Color
    @ViewBuilder let menuContent: () -> MenuContent

    var body: some View {
        Menu {
            menuContent()
        } label: {
            HStack {
                SettingsIconLabel(title, systemImage: "play.fill")
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 12)

                // Ohne Dienst-Symbol: Die Kachel links zeigt schon eins.
                HStack(spacing: 4) {
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
            SettingsIconTile(systemImage: systemImage)
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
            SettingsIconTile(systemImage: systemImage)
        }
    }
}

/// Einheitliche, getönte Icon-Kachel (Design Review 2026-11, Befund 7):
/// Symbol in der Akzentfarbe auf heller Fläche, wie Banner und
/// Initialen-Kacheln der App. Volle Farbflächen waren in jeder Zeile zu laut.
private struct SettingsIconTile: View {
    let systemImage: String
    var color: Color? = nil

    var body: some View {
        let style = color.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.tint)
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(style)
            .frame(width: 26, height: 26)
            .background(style.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct SettingsIconLabel: View {
    let title: Text
    let systemImage: String
    var tileColor: Color? = nil

    /// Literale werden wie bei `Text("…")` über den String-Katalog übersetzt.
    init(_ title: LocalizedStringKey, systemImage: String, tileColor: Color? = nil) {
        self.title = Text(title)
        self.systemImage = systemImage
        self.tileColor = tileColor
    }

    /// Bereits übersetzte Strings, etwa aus `String(localized:)`.
    @_disfavoredOverload
    init(_ title: String, systemImage: String, tileColor: Color? = nil) {
        self.title = Text(verbatim: title)
        self.systemImage = systemImage
        self.tileColor = tileColor
    }

    var body: some View {
        Label {
            title
        } icon: {
            SettingsIconTile(systemImage: systemImage, color: tileColor)
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
