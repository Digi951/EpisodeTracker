import XCTest
import SwiftData
@testable import EpisodeTracker

/// Paket 5, P5-E — automatisierter Teil von Datenvertrag §4.E
/// ("Sprache wechseln"): beweist, dass Katalogsprache und UI-Sprache
/// unabhängig sind, indem ein DE-nummerierter und ein FR-Anthologie-Katalog
/// **gleichzeitig** in derselben Bibliothek existieren und sich gegenseitig
/// nicht beeinflussen — IDs, Bindungen, Merkliste und Hörstatus bleiben pro
/// Katalog stabil, unabhängig davon, welche UI-Sprache gerade aktiv ist.
///
/// Kein echter Laufzeit-Sprachwechsel: `AppLocalization`/`String(localized:)`
/// lesen nirgends Katalogdaten, und keine Identitäts-/Matching-Funktion
/// (`Episode.makeSyncKey`, `CatalogLibraryMatcher`, `NewsBookmarkHandler`,
/// `NewsReconciler`) konsultiert `Locale`/`Bundle.main.preferredLocalizations`
/// — ein `Bundle`-Sprachwechsel im Testprozess würde also nichts prüfen, was
/// diese Tests nicht bereits auf der Datenebene beweisen (Plan-Entscheidung
/// aus den "Offenen Punkten").
///
/// **Nicht automatisierbar** (siehe P5-F "Offene Fäden"): VoiceOver, große
/// Schrift, iPhone/iPad-Sichtprüfung aller drei UI-Sprachen — braucht ein
/// echtes Gerät.
@MainActor
final class LanguageSwitchStabilityTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private func makeMixedLibrary(context: ModelContext) -> (deUniverse: Universe, deEpisode: Episode, frUniverse: Universe, frEpisode: Episode) {
        let deUniverse = Universe(name: "Die drei ???")
        deUniverse.managedCatalogID = "die-drei-fragezeichen"
        deUniverse.styleRaw = CatalogStyle.numbered.rawValue
        context.insert(deUniverse)

        let deEpisode = Episode(episodeNumber: 241, title: "Meister des Lichts", releaseYear: 2026, universe: deUniverse)
        context.insert(deEpisode)

        let frUniverse = Universe(name: "Contract Test Anthologie")
        frUniverse.managedCatalogID = "fr-anthologie-fixture"
        frUniverse.styleRaw = CatalogStyle.anthology.rawValue
        context.insert(frUniverse)

        let frEpisode = Episode(
            episodeNumber: 0,
            title: "La première enquête",
            releaseYear: 2022,
            kind: .special,
            catalogSlug: "la-premiere-enquete",
            universe: frUniverse
        )
        context.insert(frEpisode)

        return (deUniverse, deEpisode, frUniverse, frEpisode)
    }

    // MARK: 1. Stabile, unterscheidbare IDs unabhängig von Sprache/Stil

    func testMixedLanguageLibraryKeepsDistinctStableSyncKeys() throws {
        let context = try makeContext()
        let (_, deEpisode, _, frEpisode) = makeMixedLibrary(context: context)

        let deSyncKey = deEpisode.resolvedSyncKey
        let frSyncKey = frEpisode.resolvedSyncKey

        XCTAssertNotEqual(deSyncKey, frSyncKey)
        XCTAssertTrue(deSyncKey.contains("241"), "numbered episodes stay identified by number regardless of any other catalog's language")
        XCTAssertTrue(frSyncKey.contains("la-premiere-enquete"), "anthology episodes stay identified by slug regardless of any other catalog's language")

        // Erneuter Aufruf (simuliert einen UI-Sprachwechsel zwischen zwei
        // Aufrufen, ohne dass sich an den Daten etwas ändert) liefert exakt
        // denselben Schlüssel — die Berechnung hat keinen Sprach-/Locale-Input.
        XCTAssertEqual(deEpisode.resolvedSyncKey, deSyncKey)
        XCTAssertEqual(frEpisode.resolvedSyncKey, frSyncKey)
    }

    // MARK: 2. Merkliste/Hörstatus bleiben pro Katalog isoliert

    func testBookmarkingTheFREpisodeDoesNotAffectTheDEEpisode() throws {
        let context = try makeContext()
        let (_, deEpisode, _, frEpisode) = makeMixedLibrary(context: context)
        XCTAssertFalse(deEpisode.isBookmarked)
        XCTAssertFalse(frEpisode.isBookmarked)

        let event = NewsEvent(
            kind: .newEpisode,
            universeName: "Contract Test Anthologie",
            catalogID: "fr-anthologie-fixture",
            slug: "la-premiere-enquete",
            title: "La première enquête",
            revision: "1",
            discoveredAt: .now
        )
        NewsBookmarkHandler.toggleBookmark(
            for: event,
            modelContext: context,
            existingEpisodes: [deEpisode, frEpisode],
            existingUniverses: []
        )

        XCTAssertTrue(frEpisode.isBookmarked)
        XCTAssertFalse(deEpisode.isBookmarked, "bookmarking a French anthology episode must never touch an unrelated German numbered episode")
        XCTAssertFalse(deEpisode.isListened)
    }

    func testMarkingTheDEEpisodeListenedDoesNotAffectTheFREpisode() throws {
        let context = try makeContext()
        let (_, deEpisode, _, frEpisode) = makeMixedLibrary(context: context)

        deEpisode.isListened = true
        deEpisode.listenCount = 1

        XCTAssertTrue(deEpisode.isListened)
        XCTAssertFalse(frEpisode.isListened, "listen status on a German catalog episode must never leak to an unrelated French anthology episode")
        XCTAssertEqual(frEpisode.listenCount, 0)
        XCTAssertFalse(frEpisode.isBookmarked)
    }

    // MARK: 3. Neuigkeiten-Isolation über Katalogsprachen hinweg (Paket 4)

    func testDeactivatingTheFRCatalogRemovesOnlyItsNewsAndLeavesTheDECatalogNewsUntouched() {
        let deEvent = NewsEvent(
            kind: .newEpisode, universeName: "Die drei ???", catalogID: "die-drei-fragezeichen",
            episodeNumber: 242, title: "Der Fluch des Rubins", revision: "6", discoveredAt: .now
        )
        let frEvent = NewsEvent(
            kind: .newEpisode, universeName: "Contract Test Anthologie", catalogID: "fr-anthologie-fixture",
            slug: "le-mystere-du-phare", title: "Le mystère du phare", revision: "1", discoveredAt: .now
        )
        var document = NewsStoreDocument()
        document.events = [deEvent, frEvent]

        // Nur der FR-Katalog wird deaktiviert — der DE-Katalog bleibt aktiv.
        let result = NewsReconciler.removeEventsForDeactivatedCatalogs(
            document: document,
            activeCatalogIDs: ["die-drei-fragezeichen"]
        )

        XCTAssertEqual(result.events, [deEvent])
    }
}
