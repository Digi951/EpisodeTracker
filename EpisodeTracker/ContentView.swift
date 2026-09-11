import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("libraryTitle") private var libraryTitle: String = "Meine Hörspiele"
    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.system.rawValue
    @AppStorage(AppAccentColor.storageKey) private var appAccentColorRawValue: String = AppAccentColor.defaultValue.rawValue

    private let splitLayoutWidthThreshold = SplitLayoutDecider.defaultWidthThreshold

    private var effectiveLibraryTitle: String {
        let trimmed = libraryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Meine Hörspiele" : trimmed
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    private var appAccentColor: AppAccentColor {
        AppAccentColor.resolved(from: appAccentColorRawValue)
    }

    var body: some View {
        GeometryReader { geometry in
            let usesSplitLayout = shouldUseSplitLayout(for: geometry.size.width)

            Group {
                if usesSplitLayout {
                    ContentPadTabs(libraryTitle: effectiveLibraryTitle)
                } else {
                    ContentPhoneTabs(libraryTitle: effectiveLibraryTitle)
                }
            }
        }
        .tint(appAccentColor.color)
        .preferredColorScheme(appearanceMode.colorScheme)
    }

    private func shouldUseSplitLayout(for width: CGFloat) -> Bool {
        SplitLayoutDecider.shouldUseSplitLayout(
            horizontalSizeClass: horizontalSizeClass,
            width: width,
            threshold: splitLayoutWidthThreshold
        )
    }

}

private struct ContentPhoneTabs: View {
    let libraryTitle: String

    var body: some View {
        TabView {
            PhoneEpisodesRoot(libraryTitle: libraryTitle)
                .tabItem {
                    Label("Folgen", systemImage: "list.number")
                }

            PhoneUpNextRoot()
                .tabItem {
                    Label("Als nächstes", systemImage: "play.circle")
                }

            StatisticsRootTab()
                .tabItem {
                    Label("Statistiken", systemImage: "chart.bar")
                }

            SettingsRootTab()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
        }
    }
}

private struct ContentPadTabs: View {
    let libraryTitle: String

    var body: some View {
        TabView {
            EpisodeSplitView(libraryTitle: libraryTitle)
                .tabItem {
                    Label("Folgen", systemImage: "list.number")
                }

            UpNextSplitView()
                .tabItem {
                    Label("Als nächstes", systemImage: "play.circle")
                }

            StatisticsRootTab()
                .tabItem {
                    Label("Statistiken", systemImage: "chart.bar")
                }

            SettingsRootTab()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape")
                }
        }
    }
}

private struct PhoneEpisodesRoot: View {
    let libraryTitle: String

    var body: some View {
        NavigationStack {
            EpisodeListView()
                .navigationDestination(for: Episode.self) { episode in
                    EpisodeDetailView(episode: episode)
                }
                .navigationDestination(for: NavigationDestination.self) { destination in
                    switch destination {
                    case .episode(let episode):
                        EpisodeDetailView(episode: episode)
                    case .addEpisode:
                        EpisodeEditView()
                    }
                }
                .navigationDestination(for: SmartListNavigation.self) { destination in
                    switch destination {
                    case .detail(let smartList):
                        SmartListDetailView(smartList: smartList)
                    case .moodPicker:
                        MoodPickerView()
                    case .moodDetail(let mood):
                        SmartListDetailView(smartList: .randomByMood, mood: mood)
                    case .savedFilter(let filter):
                        SavedFilterDetailView(filter: filter)
                    }
                }
                .navigationTitle(libraryTitle)
        }
    }
}

private struct PhoneUpNextRoot: View {
    var body: some View {
        NavigationStack {
            UpNextView()
                .navigationDestination(for: Episode.self) { episode in
                    EpisodeDetailView(episode: episode)
                }
                .navigationDestination(for: SmartListNavigation.self) { destination in
                    switch destination {
                    case .detail(let smartList):
                        SmartListDetailView(smartList: smartList)
                    case .moodPicker:
                        MoodPickerView()
                    case .moodDetail(let mood):
                        SmartListDetailView(smartList: .randomByMood, mood: mood)
                    case .savedFilter(let filter):
                        SavedFilterDetailView(filter: filter)
                    }
                }
                .navigationTitle("Als nächstes")
        }
    }
}

private struct StatisticsRootTab: View {
    var body: some View {
        NavigationStack {
            StatisticsView()
        }
    }
}

private struct SettingsRootTab: View {
    var body: some View {
        NavigationStack {
            SettingsView()
        }
    }
}


private struct UpNextSplitView: View {
    @State private var selectedNavigation: SmartListNavigation?

    var body: some View {
        NavigationSplitView {
            UpNextView(iPadNavSelection: $selectedNavigation)
                .navigationTitle(String(localized: "Als nächstes", defaultValue: "Als nächstes"))
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 360)
        } detail: {
            NavigationStack {
                if let selectedNavigation {
                    detailContent(for: selectedNavigation)
                        .navigationDestination(for: Episode.self) { episode in
                            EpisodeDetailView(episode: episode)
                        }
                        .navigationDestination(for: SmartListNavigation.self) { destination in
                            switch destination {
                            case .moodDetail(let mood):
                                SmartListDetailView(smartList: .randomByMood, mood: mood)
                                    .navigationDestination(for: Episode.self) { episode in
                                        EpisodeDetailView(episode: episode)
                                    }
                            default:
                                EmptyView()
                            }
                        }
                } else {
                    SplitSelectionPlaceholder(
                        title: String(localized: "UpNext.EmptySelection.Title", defaultValue: "Liste auswählen"),
                        systemImage: "list.bullet.rectangle",
                        message: String(
                            localized: "UpNext.EmptySelection.Message",
                            defaultValue: "Wähle links eine Liste aus, um Vorschläge und Folgen zu sehen."
                        )
                    )
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func detailContent(for navigation: SmartListNavigation) -> some View {
        switch navigation {
        case .detail(let smartList):
            SmartListDetailView(smartList: smartList)
        case .moodPicker:
            MoodPickerView()
        case .moodDetail(let mood):
            SmartListDetailView(smartList: .randomByMood, mood: mood)
        case .savedFilter(let filter):
            SavedFilterDetailView(filter: filter)
        }
    }
}


struct SplitSelectionPlaceholder: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity, minHeight: 320, alignment: .center)
        .padding(.horizontal, 32)
    }
}

enum SplitLayoutDecider {
    static let defaultWidthThreshold: CGFloat = 780

    static func shouldUseSplitLayout(
        horizontalSizeClass: UserInterfaceSizeClass?,
        width: CGFloat,
        threshold: CGFloat = defaultWidthThreshold
    ) -> Bool {
        horizontalSizeClass == .regular || width >= threshold
    }
}

enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    // Paket 6, P6-C: beim FR-Sichtprüfungsdurchlauf gefunden — die drei
    // Optionen waren hartkodiertes Deutsch ohne xcstrings-Eintrag und blieben
    // in EN/FR-App-Sprache unübersetzt. Trivialer, risikofreier Fund direkt
    // im selben Commit behoben (Plan §"P6-C").
    var title: String {
        switch self {
        case .system: String(localized: "Appearance.Mode.System", defaultValue: "System")
        case .light: String(localized: "Appearance.Mode.Light", defaultValue: "Hell")
        case .dark: String(localized: "Appearance.Mode.Dark", defaultValue: "Dunkel")
        }
    }

    var iconName: String {
        switch self {
        case .system: "circle.righthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Episode.self, Mood.self, Universe.self], inMemory: true)
}
