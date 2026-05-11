import SwiftUI
import SwiftData

struct SmartListDetailView: View {
    let smartList: SmartListDefinition
    var mood: Mood?
    var iPadSelection: Binding<Episode?>?

    @Query private var allEpisodes: [Episode]
    @State private var shuffledEpisodes: [Episode]?

    private var displayedEpisodes: [Episode] {
        if smartList.isRandomList {
            return shuffledEpisodes ?? []
        }
        return smartList.episodes(from: allEpisodes)
    }

    private var navigationTitle: String {
        if smartList == .zufaelligNachStimmung, let mood {
            return "\(mood.iconName ?? "") \(mood.name)"
        }
        return smartList.displayName
    }

    var body: some View {
        Group {
            if let iPadSelection {
                List(selection: iPadSelection) {
                    episodeContent
                }
            } else {
                List {
                    episodeContent
                }
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            if smartList.isRandomList {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        reshuffle()
                    } label: {
                        Label("Neu würfeln", systemImage: "dice")
                    }
                }
            }
        }
        .onAppear {
            if smartList.isRandomList && shuffledEpisodes == nil {
                reshuffle()
            }
        }
    }

    @ViewBuilder
    private var episodeContent: some View {
        if displayedEpisodes.isEmpty {
            ContentUnavailableView {
                Label(smartList.displayName, systemImage: "tray")
            } description: {
                Text(smartList == .zufaelligNachStimmung
                     ? "Keine offenen Folgen mit dieser Stimmung"
                     : smartList.emptyStateMessage)
            }
            .listRowSeparator(.hidden)
        } else {
            ForEach(displayedEpisodes) { episode in
                NavigationLink(value: episode) {
                    EpisodeRowView(episode: episode)
                }
            }
        }
    }

    private func reshuffle() {
        if smartList == .zufaelligNachStimmung, let mood {
            shuffledEpisodes = SmartListDefinition.episodesForMood(mood, from: allEpisodes)
        } else if smartList == .zufaellig {
            shuffledEpisodes = SmartListDefinition.randomEpisodes(from: allEpisodes)
        }
    }
}
