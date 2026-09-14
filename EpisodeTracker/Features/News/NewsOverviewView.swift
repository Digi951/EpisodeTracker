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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Episode.episodeNumber) private var libraryEpisodes: [Episode]
    @Query(sort: \Universe.name) private var libraryUniverses: [Universe]

    /// Der tatsächlich zu speichernde Stand, inklusive der in dieser Sitzung
    /// gesetzten `seenAt`-Markierungen.
    @State private var document: NewsStoreDocument = NewsStoreDocument()
    /// Eingefrorene Momentaufnahme von `document` direkt nach dem Laden — die
    /// gerenderten Bereiche leiten sich aus DIESER ab, nicht aus `document`.
    /// Sonst würde eine Zeile, die 30+ Tage alt und ungesehen war, beim
    /// Scrollen verschwinden, sobald `onRowAppear` sie als gesehen markiert
    /// und sie dadurch die "ungesehen übersteht das Fenster"-Ausnahme verliert.
    @State private var displayDocument: NewsStoreDocument = NewsStoreDocument()
    @State private var showAllNeuErschienen = false
    @State private var previewedEvent: NewsEvent?
    @State private var selectedEpisode: Episode?
    @State private var hasScrolledToInitialFocus = false
    @State private var hasUnsavedSeenChanges = false

    private var newsStore: NewsStore { NewsStore() }

    private var sections: NewsOverviewOrganizer.Sections {
        NewsOverviewOrganizer.sections(from: displayDocument.events, showAllNeuErschienen: showAllNeuErschienen)
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
                // Erst scrollen, nachdem `displayDocument` geladen ist — beim
                // ersten (leeren) Default-Zustand trägt noch keine Zeile die
                // Sprungmarke, ein `scrollTo` in `.onAppear` würde ins Leere
                // laufen (Review-Fund #4). `displayDocument` wird danach nie
                // wieder verändert (siehe oben), der Flag ist hier nur eine
                // Absicherung gegen ein erneutes Feuern.
                .onChange(of: displayDocument) { _, _ in
                    guard !hasScrolledToInitialFocus else { return }
                    hasScrolledToInitialFocus = true
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
                let loaded = newsStore.load()
                document = loaded
                displayDocument = loaded
            }
            .onDisappear {
                // Erst beim Verlassen des Screens auf einmal speichern, statt
                // pro Zeile — die Gesehen-Markierungen selbst passieren in
                // `NewsEventRow.onAppear` und betreffen dann nur tatsächlich
                // gerenderte Zeilen (Review-Fund #2), nicht den ganzen Store.
                if hasUnsavedSeenChanges {
                    try? newsStore.save(document)
                }
            }
            .sheet(item: $previewedEvent) { event in
                NewsCatalogPreviewSheet(event: event)
            }
            .navigationDestination(item: $selectedEpisode) { episode in
                EpisodeDetailView(episode: episode)
            }
        }
    }

    /// Markiert ein Ereignis erst dann als gesehen, wenn seine Zeile
    /// tatsächlich gerendert wurde (`NewsEventRow.onAppear`) — nicht pauschal
    /// jedes ungesehene Ereignis im Store, sobald der Screen überhaupt
    /// geöffnet wird (Review-Fund #2). Rein in-memory; `onDisappear`
    /// speichert einmalig.
    private func markSeenOnRowAppear(_ event: NewsEvent) {
        let updated = document.markingSeen(eventID: event.id)
        guard updated != document else { return }
        document = updated
        hasUnsavedSeenChanges = true
    }

    @ViewBuilder
    private var neuErschienenSection: some View {
        Section {
            ForEach(sections.neuErschienen) { event in
                NewsEventRow(
                    event: event,
                    isBookmarkable: event.kind != .newCatalog,
                    isBookmarked: NewsBookmarkHandler.matchingEpisode(for: event, in: libraryEpisodes)?.isBookmarked ?? false,
                    onTap: { handleTap(on: event) },
                    onToggleBookmark: { toggleBookmark(on: event) },
                    onRowAppear: { markSeenOnRowAppear(event) }
                )
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
                    NewsEventRow(
                    event: event,
                    isBookmarkable: event.kind != .newCatalog,
                    isBookmarked: NewsBookmarkHandler.matchingEpisode(for: event, in: libraryEpisodes)?.isBookmarked ?? false,
                    onTap: { handleTap(on: event) },
                    onToggleBookmark: { toggleBookmark(on: event) },
                    onRowAppear: { markSeenOnRowAppear(event) }
                )
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
                    NewsEventRow(
                    event: event,
                    isBookmarkable: event.kind != .newCatalog,
                    isBookmarked: NewsBookmarkHandler.matchingEpisode(for: event, in: libraryEpisodes)?.isBookmarked ?? false,
                    onTap: { handleTap(on: event) },
                    onToggleBookmark: { toggleBookmark(on: event) },
                    onRowAppear: { markSeenOnRowAppear(event) }
                )
                }
            } header: {
                Text("Neue Reihen")
            }
            .id(NewsOverviewSection.neueReihen)
        }
    }

    private func toggleBookmark(on event: NewsEvent) {
        NewsBookmarkHandler.toggleBookmark(
            for: event,
            modelContext: modelContext,
            existingEpisodes: libraryEpisodes,
            existingUniverses: libraryUniverses
        )
        try? modelContext.save()
    }

    private func handleTap(on event: NewsEvent) {
        if let episode = NewsBookmarkHandler.matchingEpisode(for: event, in: libraryEpisodes) {
            selectedEpisode = episode
        } else {
            previewedEvent = event
        }
    }
}

/// Titel-Tap und Merken-Button sind zwei GLEICHRANGIGE `Button`s in einer
/// `HStack`, keine verschachtelten Buttons mit `.contentShape`-Klimmzügen —
/// SwiftUI vergibt jedem Geschwister-Button sein eigenes Tipp-Ziel, sodass
/// der Merken-Button nie die Zeilennavigation auslöst (Datenvertrag §4.D7).
private struct NewsEventRow: View {
    let event: NewsEvent
    let isBookmarkable: Bool
    let isBookmarked: Bool
    let onTap: () -> Void
    let onToggleBookmark: () -> Void
    /// Feuert, wenn SwiftUI diese Zeile tatsächlich rendert — das ist der
    /// Zeitpunkt, an dem das Ereignis als gesehen zählt (Review-Fund #2),
    /// nicht schon beim bloßen Öffnen des Screens.
    let onRowAppear: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .lineLimit(nil)
                    Text(event.universeName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Öffnet Details"))

            if isBookmarkable {
                Button(action: onToggleBookmark) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(isBookmarked ? .cyan : .secondary)
                        .imageScale(.large)
                        // Ausreichend großes Tipp-/VoiceOver-Ziel, unabhängig
                        // vom kleinen SF-Symbol selbst.
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(isBookmarked ? "Von Merkliste entfernen" : "Auf Merkliste setzen"))
            }
        }
        .onAppear(perform: onRowAppear)
    }
}

/// Schlanke Vorschau für Ereignisse ohne passende Bibliotheksfolge — bewusst
/// NICHT die vollständige "Reihenvorschau" aus Paket 6 (Datenvertrag §4.D6).
/// Zeigt die von D6 verlangten Felder Name/Reihe/Datum/Status; bei
/// `.newCatalog` sind Name und Reihe identisch (die Meldung betrifft die
/// Reihe selbst), daher entfällt dort die doppelte Zeile zugunsten eines
/// Links zu "Kataloge verwalten".
private struct NewsCatalogPreviewSheet: View {
    let event: NewsEvent

    @Environment(\.dismiss) private var dismiss

    private var statusText: String {
        switch event.kind {
        case .newEpisode: "Neu erschienen"
        case .upcoming: "Bald verfügbar"
        case .newCatalog: "Neue Reihe"
        case .dateChanged: "Termin geändert"
        case .unknown: ""
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(event.title)
                        .font(.headline)
                    if event.kind != .newCatalog {
                        Text(event.universeName)
                            .foregroundStyle(.secondary)
                    }
                    if let releaseDate = CalendarDayFormatter.date(from: event.revision), event.kind == .upcoming {
                        Text(releaseDate.formatted(date: .long, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                    Text(statusText)
                        .foregroundStyle(.secondary)
                }

                if event.kind == .newCatalog {
                    Section {
                        NavigationLink {
                            CatalogManagementView()
                        } label: {
                            Label("Kataloge verwalten", systemImage: "books.vertical")
                        }
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
