import SwiftData
import SwiftUI

/// Welcher der drei Bereiche beim Öffnen zuerst sichtbar sein soll. Der
/// Kalender-Einstieg (P4-G) öffnet mit `.baldVerfuegbar`, der "Neuigkeiten"-
/// Eintrag in "Als nächstes" mit `.neuErschienen` (Datenvertrag §4.D6).
enum NewsOverviewSection: Hashable {
    case neuErschienen
    case baldVerfuegbar
    case neueReihen
}

/// Ersetzt `UpcomingReleasesSheet` als Zielbildschirm: drei Bereiche über dem
/// dauerhaften `NewsStore`-Protokoll statt nur der ephemeren Terminliste.
/// Bewusst schlank gehalten — die volle "Reihenvorschau" bleibt Paket 6
/// (Datenvertrag §4.D6/D8).
struct NewsOverviewView: View {
    var initialFocus: NewsOverviewSection = .neuErschienen

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Episode.episodeNumber) private var libraryEpisodes: [Episode]

    @State private var document: NewsStoreDocument = NewsStoreDocument()
    @State private var showAllNeuErschienen = false
    @State private var previewedEvent: NewsEvent?
    @State private var selectedEpisode: Episode?

    private var newsStore: NewsStore { NewsStore() }

    private var sections: NewsOverviewOrganizer.Sections {
        NewsOverviewOrganizer.sections(from: document.events, showAllNeuErschienen: showAllNeuErschienen)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    neuErschienenSection
                    baldVerfuegbarSection
                    neueReihenSection

                    if sections.neuErschienen.isEmpty && sections.baldVerfuegbar.isEmpty && sections.neueReihen.isEmpty {
                        ContentUnavailableView(
                            "Keine Neuigkeiten",
                            systemImage: "sparkles",
                            description: Text("Für deine aktivierten Kataloge liegen zurzeit keine Neuigkeiten vor.")
                        )
                    }
                }
                .onAppear {
                    proxy.scrollTo(initialFocus, anchor: .top)
                }
            }
            .navigationTitle("Neuigkeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .task {
                loadAndMarkSeen()
            }
            .sheet(item: $previewedEvent) { event in
                NewsCatalogPreviewSheet(event: event)
            }
            .navigationDestination(item: $selectedEpisode) { episode in
                EpisodeDetailView(episode: episode)
            }
        }
    }

    @ViewBuilder
    private var neuErschienenSection: some View {
        Section {
            ForEach(sections.neuErschienen) { event in
                NewsEventRow(event: event, onTap: { handleTap(on: event) })
            }
            if sections.hasHiddenOlderNeuErschienen {
                Button("Ältere anzeigen") {
                    showAllNeuErschienen = true
                }
            }
        } header: {
            Text("Neu erschienen")
        }
        .id(NewsOverviewSection.neuErschienen)
    }

    @ViewBuilder
    private var baldVerfuegbarSection: some View {
        ForEach(Array(sections.baldVerfuegbar.enumerated()), id: \.element.id) { index, group in
            Section {
                ForEach(group.events) { event in
                    NewsEventRow(event: event, onTap: { handleTap(on: event) })
                }
            } header: {
                // Nur die erste Gruppe trägt die Scroll-Sprungmarke — sonst
                // hätten mehrere Header dieselbe explizite Identität.
                if index == 0 {
                    Text(group.date.map { $0.formatted(date: .long, time: .omitted) } ?? "Termin offen")
                        .id(NewsOverviewSection.baldVerfuegbar)
                } else {
                    Text(group.date.map { $0.formatted(date: .long, time: .omitted) } ?? "Termin offen")
                }
            }
        }
    }

    @ViewBuilder
    private var neueReihenSection: some View {
        if !sections.neueReihen.isEmpty {
            Section {
                ForEach(sections.neueReihen) { event in
                    NewsEventRow(event: event, onTap: { handleTap(on: event) })
                }
            } header: {
                Text("Neue Reihen")
            }
            .id(NewsOverviewSection.neueReihen)
        }
    }

    private func handleTap(on event: NewsEvent) {
        if let episode = matchingLibraryEpisode(for: event) {
            selectedEpisode = episode
        } else {
            previewedEvent = event
        }
    }

    private func matchingLibraryEpisode(for event: NewsEvent) -> Episode? {
        let normalizedUniverse = CatalogLibraryMatcher.normalizedCollectionKey(event.universeName)
        return libraryEpisodes.first { episode in
            guard CatalogLibraryMatcher.normalizedCollectionKey(episode.universe?.name ?? "") == normalizedUniverse else {
                return false
            }
            if let episodeNumber = event.episodeNumber {
                return episode.episodeNumber == episodeNumber
            }
            if let slug = event.slug {
                return episode.catalogSlug?.lowercased() == slug.lowercased()
            }
            return false
        }
    }

    private func loadAndMarkSeen() {
        var loaded = newsStore.load()
        let now = Date()
        var didMarkAnySeen = false
        for index in loaded.events.indices where loaded.events[index].seenAt == nil {
            loaded.events[index].seenAt = now
            didMarkAnySeen = true
        }
        document = loaded
        if didMarkAnySeen {
            try? newsStore.save(loaded)
        }
    }
}

private struct NewsEventRow: View {
    let event: NewsEvent
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .lineLimit(nil)
                Text(event.universeName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Öffnet Details"))
    }
}

/// Schlanke Vorschau für Ereignisse ohne passende Bibliotheksfolge — bewusst
/// NICHT die vollständige "Reihenvorschau" aus Paket 6 (Datenvertrag §4.D6).
private struct NewsCatalogPreviewSheet: View {
    let event: NewsEvent

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(event.title)
                        .font(.headline)
                    Text(event.universeName)
                        .foregroundStyle(.secondary)
                    if let releaseDate = CalendarDayFormatter.date(from: event.revision), event.kind == .upcoming {
                        Text(releaseDate.formatted(date: .long, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Vorschau")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
