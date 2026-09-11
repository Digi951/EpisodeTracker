import Foundation

/// Reine Aufbereitung des `NewsStore`-Ereignisprotokolls für die drei
/// Neuigkeiten-Bereiche (Datenvertrag Paket 4 §4.D5/D6). Kein SwiftData-,
/// kein Netzwerkzugriff — nur Sortierung/Gruppierung, deshalb ohne
/// UI-Abhängigkeiten testbar.
enum NewsOverviewOrganizer {

    /// Eine Terminzeile für "Bald verfügbar": `date == nil` bündelt Zeilen
    /// ohne verlässliches Datum in die "Termin offen"-Gruppe (Datenvertrag
    /// §4.D4 — heute in der Praxis immer leer, da der reale Feed stets ein
    /// `releaseDate` trägt; der Code-Pfad existiert für den Tag, an dem sich
    /// das ändert).
    struct DateGroup: Identifiable, Equatable {
        let date: Date?
        let events: [NewsEvent]

        var id: String {
            date.map(CalendarDayFormatter.string(from:)) ?? "termin-offen"
        }
    }

    struct Sections {
        /// "Neu erschienen": letzte 30 Tage plus alle noch ungesehenen
        /// Ereignisse, unabhängig vom Alter (Datenvertrag §4.D5).
        let neuErschienen: [NewsEvent]
        /// `true`, wenn `showAllNeuErschienen == false` UND es tatsächlich
        /// ältere, bereits gesehene Ereignisse außerhalb des Fensters gibt —
        /// steuert, ob die UI "Ältere anzeigen" überhaupt anbietet.
        let hasHiddenOlderNeuErschienen: Bool
        let baldVerfuegbar: [DateGroup]
        let neueReihen: [NewsEvent]
    }

    static func sections(
        from events: [NewsEvent],
        now: Date = Date(),
        showAllNeuErschienen: Bool = false,
        recentWindow: TimeInterval = 30 * 24 * 60 * 60
    ) -> Sections {
        let newEpisodes = events
            .filter { $0.kind == .newEpisode }
            .sorted { $0.discoveredAt > $1.discoveredAt }

        let recentCutoff = now.addingTimeInterval(-recentWindow)
        let isWithinDefaultWindow: (NewsEvent) -> Bool = { event in
            event.seenAt == nil || event.discoveredAt >= recentCutoff
        }

        let hasHiddenOlder = !showAllNeuErschienen && newEpisodes.contains { !isWithinDefaultWindow($0) }
        let visibleNewEpisodes = showAllNeuErschienen
            ? newEpisodes
            : newEpisodes.filter(isWithinDefaultWindow)

        let upcoming = events.filter { $0.kind == .upcoming }
        let dateGroups = Dictionary(grouping: upcoming) { event -> Date? in
            CalendarDayFormatter.date(from: event.revision)
        }
        .map { date, groupEvents in
            DateGroup(
                date: date,
                events: groupEvents.sorted { lhs, rhs in
                    let lhsNumber = lhs.episodeNumber ?? .max
                    let rhsNumber = rhs.episodeNumber ?? .max
                    if lhsNumber != rhsNumber { return lhsNumber < rhsNumber }
                    return lhs.title.localizedCompare(rhs.title) == .orderedAscending
                }
            )
        }
        .sorted { lhs, rhs in
            switch (lhs.date, rhs.date) {
            case let (lhsDate?, rhsDate?):
                return lhsDate < rhsDate
            case (nil, _?):
                return false // Termin offen sortiert ans Ende
            case (_?, nil):
                return true
            case (nil, nil):
                return false
            }
        }

        let newCatalogs = events
            .filter { $0.kind == .newCatalog }
            .sorted { $0.discoveredAt > $1.discoveredAt }

        return Sections(
            neuErschienen: visibleNewEpisodes,
            hasHiddenOlderNeuErschienen: hasHiddenOlder,
            baldVerfuegbar: dateGroups,
            neueReihen: newCatalogs
        )
    }
}
