import XCTest
@testable import EpisodeTracker

final class NewsReconcilerTests: XCTestCase {

    private let catalogID = "die-drei-fragezeichen"
    private let universeName = "Die drei ???"
    private let now = Date(timeIntervalSince1970: 1_789_000_000)

    private func makeDelta(currentVersion: Int, addedNumbers: [Int]) -> CatalogEpisodeDelta {
        CatalogEpisodeDelta(
            catalogID: catalogID,
            name: universeName,
            previousVersion: currentVersion - 1,
            currentVersion: currentVersion,
            previousEntryCount: addedNumbers.count - 1,
            currentEntryCount: addedNumbers.count,
            addedEntries: addedNumbers.map {
                CatalogEntry(number: $0, title: "Folge \($0)", releaseYear: 2026, links: [:])
            }
        )
    }

    private func namesByCatalogID() -> [String: String] {
        [catalogID: universeName]
    }

    // MARK: Baseline

    func testBaselineCreatesNoEventsButRecordsRevisions() {
        let delta = makeDelta(currentVersion: 5, addedNumbers: [241])
        let document = NewsReconciler.establishBaselineIfNeeded(
            document: NewsStoreDocument(),
            deltas: [delta],
            availability: nil,
            upcoming: [],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [catalogID],
            now: now
        )

        XCTAssertTrue(document.hasEstablishedBaseline)
        XCTAssertEqual(document.events, [])
        XCTAssertEqual(document.lastReconciledRevisions.count, 1)
    }

    func testBaselineIsANoOpWhenAlreadyEstablished() {
        var document = NewsStoreDocument()
        document.hasEstablishedBaseline = true
        document.lastReconciledRevisions = ["existing": "1"]

        let result = NewsReconciler.establishBaselineIfNeeded(
            document: document,
            deltas: [makeDelta(currentVersion: 5, addedNumbers: [241])],
            availability: nil,
            upcoming: [],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [catalogID],
            now: now
        )

        XCTAssertEqual(result, document)
    }

    // MARK: Reconcile

    func testReconcileWithoutBaselineIsANoOp() {
        let document = NewsReconciler.reconcile(
            document: NewsStoreDocument(),
            deltas: [makeDelta(currentVersion: 5, addedNumbers: [241])],
            availability: nil,
            upcoming: [],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [catalogID],
            now: now
        )

        XCTAssertFalse(document.hasEstablishedBaseline)
        XCTAssertEqual(document.events, [])
    }

    func testReconcileIsIdempotentWhenRevisionUnchanged() {
        let delta = makeDelta(currentVersion: 5, addedNumbers: [241])
        var document = NewsReconciler.establishBaselineIfNeeded(
            document: NewsStoreDocument(),
            deltas: [],
            availability: nil,
            upcoming: [],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [catalogID],
            now: now
        )

        document = NewsReconciler.reconcile(
            document: document,
            deltas: [delta],
            availability: nil,
            upcoming: [],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [catalogID],
            now: now
        )
        XCTAssertEqual(document.events.count, 1)
        let discoveredAt = document.events[0].discoveredAt

        // Zweiter Lauf mit derselben Revision: keine Dublette, discoveredAt
        // bleibt unverändert.
        let rerun = NewsReconciler.reconcile(
            document: document,
            deltas: [delta],
            availability: nil,
            upcoming: [],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [catalogID],
            now: now.addingTimeInterval(3600)
        )

        XCTAssertEqual(rerun.events.count, 1)
        XCTAssertEqual(rerun.events[0].discoveredAt, discoveredAt)
    }

    func testNewDeltaProducesExactlyOneEventPerAddedEntry() {
        var document = NewsReconciler.establishBaselineIfNeeded(
            document: NewsStoreDocument(),
            deltas: [],
            availability: nil,
            upcoming: [],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [catalogID],
            now: now
        )

        let delta = makeDelta(currentVersion: 6, addedNumbers: [242, 243])
        document = NewsReconciler.reconcile(
            document: document,
            deltas: [delta],
            availability: nil,
            upcoming: [],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [catalogID],
            now: now
        )

        XCTAssertEqual(document.events.count, 2)
        XCTAssertTrue(document.events.allSatisfy { $0.kind == .newEpisode && $0.seenAt == nil })
    }

    func testDeactivatedCatalogDoesNotProduceEvents() {
        var document = NewsReconciler.establishBaselineIfNeeded(
            document: NewsStoreDocument(),
            deltas: [],
            availability: nil,
            upcoming: [],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [],
            now: now
        )

        document = NewsReconciler.reconcile(
            document: document,
            deltas: [makeDelta(currentVersion: 6, addedNumbers: [242])],
            availability: nil,
            upcoming: [],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [],
            now: now
        )

        XCTAssertEqual(document.events, [])
    }

    func testUpcomingReleaseDateChangeUpdatesInPlaceInsteadOfDuplicating() {
        let originalDate = Calendar.current.startOfDay(for: now)
        let release = UpcomingRelease(catalogID: catalogID, number: 244, title: "Die Spur", releaseDate: originalDate)

        var document = NewsReconciler.establishBaselineIfNeeded(
            document: NewsStoreDocument(),
            deltas: [],
            availability: nil,
            upcoming: [],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [catalogID],
            now: now
        )
        document = NewsReconciler.reconcile(
            document: document,
            deltas: [],
            availability: nil,
            upcoming: [release],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [catalogID],
            now: now
        )
        XCTAssertEqual(document.events.count, 1)
        document.events[0].seenAt = now // simulate the user having seen it

        let shiftedDate = Calendar.current.date(byAdding: .day, value: 7, to: originalDate)!
        let shiftedRelease = UpcomingRelease(catalogID: catalogID, number: 244, title: "Die Spur", releaseDate: shiftedDate)

        let result = NewsReconciler.reconcile(
            document: document,
            deltas: [],
            availability: nil,
            upcoming: [shiftedRelease],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [catalogID],
            now: now.addingTimeInterval(3600)
        )

        XCTAssertEqual(result.events.count, 1, "date change must update in place, not duplicate the row")
        XCTAssertEqual(result.events[0].kind, .upcoming)
        XCTAssertNil(result.events[0].seenAt, "a shifted date resets seenAt so it surfaces again")
    }

    func testWithdrawnUpcomingReleaseDoesNotAutoTransitionToReleased() {
        let release = UpcomingRelease(catalogID: catalogID, number: 245, title: "Der Bote", releaseDate: Calendar.current.startOfDay(for: now))

        var document = NewsReconciler.establishBaselineIfNeeded(
            document: NewsStoreDocument(),
            deltas: [],
            availability: nil,
            upcoming: [],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [catalogID],
            now: now
        )
        document = NewsReconciler.reconcile(
            document: document,
            deltas: [],
            availability: nil,
            upcoming: [release],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [catalogID],
            now: now
        )
        XCTAssertEqual(document.events.count, 1)

        // Die Zeile fällt aus dem Feed (Termin zurückgezogen) — reconcile
        // bekommt sie einfach nicht mehr als Kandidat.
        let result = NewsReconciler.reconcile(
            document: document,
            deltas: [],
            availability: nil,
            upcoming: [],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [catalogID],
            now: now.addingTimeInterval(3600)
        )

        XCTAssertEqual(result.events, document.events, "withdrawal must not delete or auto-release the existing row")
    }

    func testConflictingSimultaneousUpcomingLinesAreResolvedByLastLineWins() {
        // upcoming_releases.json ist automatisch erzeugt und garantiert keine
        // eindeutigen Zeilen (Datenvertrag §4.D4) — zwei Zeilen für dieselbe
        // Folge mit unterschiedlichem Termin im selben Lauf müssen zu genau
        // einer Zeile mit dem Termin der letzten Dokumentzeile führen.
        let earlierDate = Calendar.current.startOfDay(for: now)
        let laterDate = Calendar.current.date(byAdding: .day, value: 3, to: earlierDate)!
        let staleLine = UpcomingRelease(catalogID: catalogID, number: 246, title: "Alte Fassung", releaseDate: earlierDate)
        let freshLine = UpcomingRelease(catalogID: catalogID, number: 246, title: "Der Pakt", releaseDate: laterDate)

        var document = NewsReconciler.establishBaselineIfNeeded(
            document: NewsStoreDocument(),
            deltas: [],
            availability: nil,
            upcoming: [],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [catalogID],
            now: now
        )

        document = NewsReconciler.reconcile(
            document: document,
            deltas: [],
            availability: nil,
            upcoming: [staleLine, freshLine],
            namesByCatalogID: namesByCatalogID(),
            activeCatalogIDs: [catalogID],
            now: now
        )

        XCTAssertEqual(document.events.count, 1, "conflicting lines for the same event must collapse into one row")
        XCTAssertEqual(document.events[0].title, "Der Pakt")
        XCTAssertEqual(document.events[0].revision, CalendarDayFormatter.string(from: laterDate))
    }

    func testNewCatalogAvailabilityProducesOneEventPerSource() {
        var document = NewsReconciler.establishBaselineIfNeeded(
            document: NewsStoreDocument(),
            deltas: [],
            availability: nil,
            upcoming: [],
            namesByCatalogID: [:],
            activeCatalogIDs: [],
            now: now
        )

        let source = ManagedCatalogSource(id: "tkkg", name: "TKKG", url: URL(string: "https://example.com/tkkg.json")!)
        document = NewsReconciler.reconcile(
            document: document,
            deltas: [],
            availability: NewCatalogAvailability(sources: [source]),
            upcoming: [],
            namesByCatalogID: [:],
            activeCatalogIDs: [],
            now: now
        )

        XCTAssertEqual(document.events.count, 1)
        XCTAssertEqual(document.events[0].kind, .newCatalog)
        XCTAssertEqual(document.events[0].catalogID, "tkkg")
    }
}
