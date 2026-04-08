import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("libraryTitle") private var libraryTitle: String = "Meine Hörspiele"
    @AppStorage("appearanceMode") private var appearanceModeRawValue: String = AppearanceMode.system.rawValue

    private var effectiveLibraryTitle: String {
        let trimmed = libraryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Meine Hörspiele" : trimmed
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    var body: some View {
        TabView {
            Tab("Folgen", systemImage: "list.number") {
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
                        .navigationTitle(effectiveLibraryTitle)
                }
            }

            Tab("Statistiken", systemImage: "chart.bar") {
                NavigationStack {
                    StatisticsView()
                }
            }

            Tab("Einstellungen", systemImage: "gearshape") {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
    }
}

enum AppearanceMode: String, CaseIterable {
    case light
    case dark
    case system

    var title: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .system: "System"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Episode.self, Mood.self, Universe.self], inMemory: true)
}
