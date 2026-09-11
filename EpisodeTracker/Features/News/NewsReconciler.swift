import Foundation

/// Macht die drei bestehenden ephemeren Signalquellen (`CatalogEpisodeDelta`,
/// `NewCatalogAvailability`, `UpcomingRelease`) dauerhaft: eine reine,
/// idempotente Funktion je Schritt, aufgerufen vom Bootstrap gegen den
/// vorhandenen Cache (kein Netz-I/O) — Datenvertrag Paket 4 §4.
///
/// Terminänderungen (D4) laufen bewusst NICHT über den `.dateChanged`-Fall von
/// `NewsEventKind`: die Kind bleibt `.upcoming`, nur die `revision`
/// (Kalendertag) ändert sich, und die bestehende Zeile wird in place
/// aktualisiert statt dupliziert (Datenvertrag §4.D3/D4, Plan P4-C).
enum NewsReconciler {

    /// Baut die Ereignis-Kandidaten, die die drei Signalquellen jetzt gerade
    /// liefern würden — `discoveredAt`/`seenAt` sind hier nicht final, nur
    /// `id` und `revision` zählen für Baseline und Revisionsvergleich.
    /// Nur aktivierte Kataloge tragen bei, damit ein deaktivierter Katalog
    /// keine neuen Zeilen mehr erzeugt (Plan-Offener-Punkt, hier entschieden).
    private static func candidateEvents(
        deltas: [CatalogEpisodeDelta],
        availability: NewCatalogAvailability?,
        upcoming: [UpcomingRelease],
        namesByCatalogID: [String: String],
        activeCatalogIDs: Set<String>,
        now: Date
    ) -> [NewsEvent] {
        var events: [NewsEvent] = []

        for delta in deltas where activeCatalogIDs.contains(delta.catalogID) {
            let revision = String(delta.currentVersion ?? 0)
            for entry in delta.addedEntries {
                // Ohne Nummer UND ohne Slug hätte die Zeile keine stabile
                // Identität — `NewsEvent.id` würde auf "…-?" kollabieren und
                // eine zweite solche Zeile stumm verschlucken. `CatalogEntry`
                // selbst prüft das nicht (anders als `UpcomingRelease.init`),
                // deshalb hier verwerfen statt eine Kollision zu riskieren
                // (Review-Fund #6).
                guard entry.number != nil || entry.slug != nil else { continue }
                events.append(NewsEvent(
                    kind: .newEpisode,
                    universeName: delta.name,
                    catalogID: delta.catalogID,
                    episodeNumber: entry.number,
                    slug: entry.slug,
                    title: entry.title,
                    revision: revision,
                    discoveredAt: now
                ))
            }
        }

        for release in upcoming where activeCatalogIDs.contains(release.catalogID) {
            events.append(NewsEvent(
                kind: .upcoming,
                universeName: namesByCatalogID[release.catalogID] ?? release.catalogID,
                catalogID: release.catalogID,
                episodeNumber: release.number,
                slug: release.slug,
                title: release.title,
                revision: CalendarDayFormatter.string(from: release.releaseDate),
                discoveredAt: now
            ))
        }

        if let availability {
            for source in availability.sources {
                events.append(NewsEvent(
                    kind: .newCatalog,
                    universeName: source.name,
                    catalogID: source.id,
                    title: source.name,
                    // Keine eigene Versionierung in NewCatalogAvailability — die
                    // Quell-ID selbst ist die Revision, ein einmal entdeckter
                    // Katalog löst also nicht wiederholt aus.
                    revision: source.id,
                    discoveredAt: now
                ))
            }
        }

        return events
    }

    /// Läuft genau einmal (gegated über `hasEstablishedBaseline`, nicht nur
    /// über "Datei fehlt"): merkt sich die aktuellen Revisionen, erzeugt aber
    /// **keine** Ereignisse — sonst würde jede Alt-Installation beim ersten
    /// Start nach dem Update einen Benachrichtigungssturm auslösen
    /// (Datenvertrag §4.D2).
    static func establishBaselineIfNeeded(
        document: NewsStoreDocument,
        deltas: [CatalogEpisodeDelta],
        availability: NewCatalogAvailability?,
        upcoming: [UpcomingRelease],
        namesByCatalogID: [String: String],
        activeCatalogIDs: Set<String>,
        now: Date = Date()
    ) -> NewsStoreDocument {
        guard !document.hasEstablishedBaseline else { return document }

        var result = document
        let candidates = candidateEvents(
            deltas: deltas,
            availability: availability,
            upcoming: upcoming,
            namesByCatalogID: namesByCatalogID,
            activeCatalogIDs: activeCatalogIDs,
            now: now
        )
        for candidate in candidates {
            result.lastReconciledRevisions[candidate.id] = candidate.revision
        }
        result.hasEstablishedBaseline = true
        return result
    }

    /// Vergleicht jede Kandidaten-Revision gegen `lastReconciledRevisions`:
    /// unverändert → No-op (idempotent); neu → neue Zeile; ID schon bekannt,
    /// aber Revision anders (z. B. verschobener Termin) → bestehende Zeile
    /// in place aktualisiert und `seenAt` zurückgesetzt, keine Dublette
    /// (Datenvertrag §4.D3/D4).
    ///
    /// `upcoming_releases.json` wird automatisch erzeugt und garantiert keine
    /// eindeutigen Zeilen je Ereignis-Identität (Datenvertrag §4.D4) — trägt
    /// derselbe Lauf mehrere konfligierende Zeilen für dieselbe `id`, gewinnt
    /// die letzte in Dokumentreihenfolge (= Rezenz), weil `candidates` der
    /// Reihe nach verarbeitet wird und ein späterer Kandidat einen zuvor in
    /// diesem Lauf geschriebenen Eintrag erneut in place überschreibt.
    static func reconcile(
        document: NewsStoreDocument,
        deltas: [CatalogEpisodeDelta],
        availability: NewCatalogAvailability?,
        upcoming: [UpcomingRelease],
        namesByCatalogID: [String: String],
        activeCatalogIDs: Set<String>,
        now: Date = Date()
    ) -> NewsStoreDocument {
        // Baseline muss zuerst laufen — ohne sie wäre jede aktuell vorhandene
        // Zeile "neu" und würde sofort einen Sturm auslösen.
        guard document.hasEstablishedBaseline else { return document }

        var result = document
        let candidates = candidateEvents(
            deltas: deltas,
            availability: availability,
            upcoming: upcoming,
            namesByCatalogID: namesByCatalogID,
            activeCatalogIDs: activeCatalogIDs,
            now: now
        )

        for candidate in candidates {
            let previousRevision = result.lastReconciledRevisions[candidate.id]
            guard previousRevision != candidate.revision else { continue }

            if let existingIndex = result.events.firstIndex(where: { $0.id == candidate.id }) {
                var updated = candidate
                updated.seenAt = nil
                result.events[existingIndex] = updated
            } else {
                result.events.append(candidate)
            }
            result.lastReconciledRevisions[candidate.id] = candidate.revision
        }

        return result
    }

    /// Räumt gesehene Ereignisse 90 Tage nach `seenAt` auf; ungesehene
    /// überleben unbegrenzt, unabhängig vom Alter — sonst würde eine Zeile
    /// verschwinden, die der Nutzer nie zu Gesicht bekommen hat.
    /// `lastReconciledRevisions` bleibt bewusst unangetastet: eine aufgeräumte,
    /// aber unveränderte Zeile darf beim nächsten `reconcile` nicht erneut
    /// auftauchen (Datenvertrag §4.D5).
    static func pruneSeenEvents(
        document: NewsStoreDocument,
        now: Date = Date(),
        retention: TimeInterval = 90 * 24 * 60 * 60
    ) -> NewsStoreDocument {
        var result = document
        result.events.removeAll { event in
            guard let seenAt = event.seenAt else { return false }
            return now.timeIntervalSince(seenAt) >= retention
        }
        return result
    }

    /// Entfernt Ereignisse deaktivierter Kataloge aus dem Protokoll (Review-
    /// Fund #3): `candidateEvents` verhindert nur, dass ein deaktivierter
    /// Katalog NEUE Zeilen erzeugt — ohne diesen Schritt blieben bereits
    /// bestehende Zeilen (inklusive funktionierendem Merken-Button) unbegrenzt
    /// sichtbar, obwohl §3 "Deaktivieren stoppt … Neuigkeiten dieser Reihe"
    /// verlangt. `lastReconciledRevisions` bleibt unangetastet, damit eine
    /// spätere Reaktivierung mit unveränderter Revision nicht sofort erneut
    /// meldet.
    static func removeEventsForDeactivatedCatalogs(
        document: NewsStoreDocument,
        activeCatalogIDs: Set<String>
    ) -> NewsStoreDocument {
        var result = document
        result.events.removeAll { !activeCatalogIDs.contains($0.catalogID) }
        return result
    }
}
