import XCTest
import SwiftData
@testable import EpisodeTracker

/// Paket 5, P5-D — beweist, dass die bestehende Anthologie-/Katalog-Pipeline
/// (Datenvertrag Paket 1, Import-Regel Paket 2b, Aktivierung Paket 3,
/// Neuigkeiten Paket 4) unverändert mit echten französischen Anthologie-
/// Daten funktioniert. **Keine echten Werke** — die zwei Einträge sind das
/// bestehende Fixture `Fixtures/CatalogContract/catalog_v2_anthology.json`
/// (Paket 1, "Contract Test Anthologie"), das bereits erfundene, klar als
/// Test gekennzeichnete FR-Titel trägt.
///
/// **Bewusst nicht wiederholt** (schon vorhanden, keine Dublette):
/// - Reiner Decode-Vertrag dieses Fixtures → `CatalogDataContractTests.
///   testV2AnthologyEntriesHaveSlugNoNumberAndAreSpecial`.
/// - `links.source`/"Originalquelle öffnen"-Auflösung mit `radiofrance.fr`-
///   URLs → `StreamingLinkResolverTests` (bereits FR-Domains als Testdaten).
///
/// **Neu hier:** Anthologie-Normalisierung, Aktivierung/Bindung und
/// Neuigkeiten-Erzeugung mit dieser FR-Daten End-to-End, plus ein
/// dokumentierter Fund zur Slug-Synthese bei französischen Akzentzeichen.
@MainActor
final class CatalogFRAnthologyPipelineTests: XCTestCase {

    // MARK: - Fixture

    private func fixtureEntries() throws -> [CatalogEntry] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/CatalogContract/catalog_v2_anthology.json")
        let data = try Data(contentsOf: url)
        let doc = try JSONDecoder().decode(CatalogParser.CatalogDocument.self, from: data)
        return doc.entries
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    private let fixtureCollectionName = "Contract Test Anthologie"

    // MARK: - 1. Anthologie-Regel beim Import (Paket 2b) hält für bereits kuratierte Slugs

    func testNormalizerLeavesCuratedFRSlugsUntouched() throws {
        let entries = try fixtureEntries()

        let normalized = CatalogStyleNormalizer.normalize(
            entries,
            style: .anthology,
            collectionName: fixtureCollectionName
        )

        XCTAssertEqual(normalized.count, entries.count)
        for entry in normalized {
            XCTAssertEqual(entry.kind, .special)
        }
        XCTAssertEqual(normalized.map(\.slug), ["la-premiere-enquete", "le-mystere-du-phare"])
    }

    /// **Fund, nicht behoben:** `SpecialEpisodeSlug.make` (eingefroren, siehe
    /// Kommentar dort) transliteriert deutsche Umlaute (ä/ö/ü/ß) nach ASCII,
    /// aber keine französischen Akzentzeichen — ein Titel ohne kuratierten
    /// Slug behält é/è/ê wörtlich im synthetisierten Slug. Funktional
    /// unproblematisch (Slugs sind interne IDs, kein Dateiname/URL-Pfad,
    /// Swift-Strings/JSON handhaben Unicode klaglos), aber inkonsistent zur
    /// deutschen Transliteration. Dieser Test dokumentiert das bewusst als
    /// bekanntes Verhalten, statt es unbemerkt zu lassen — der eingefrorene
    /// Vertrag wird hier NICHT geändert.
    func testSlugSynthesisPassesFrenchAccentsThroughUnchanged() {
        let entryWithoutSlug = CatalogEntry(
            number: nil,
            kind: .regular,
            slug: nil,
            title: "Le Secret de la Tour Éiffel",
            releaseYear: 2026,
            collectionName: fixtureCollectionName,
            links: [:]
        )

        let normalized = CatalogStyleNormalizer.normalize(
            [entryWithoutSlug],
            style: .anthology,
            collectionName: fixtureCollectionName
        )

        XCTAssertEqual(normalized.count, 1)
        XCTAssertEqual(normalized[0].kind, .special)
        XCTAssertEqual(
            normalized[0].slug,
            "le-secret-de-la-tour-éiffel-2026",
            "documents the current pass-through behaviour for French accents — not a claim that this is ideal"
        )
    }

    // MARK: - 2. Aktivierung/Bindung (Paket 3) funktioniert wie bei jedem anderen Katalog

    func testActivatingTheFRAnthologySourceBindsAnAnthologyUniverse() async throws {
        let spy = SpyRefresherStub()
        let source = ManagedCatalogSource(
            id: "fr-anthologie-fixture",
            name: fixtureCollectionName,
            language: "fr",
            style: "anthology",
            url: URL(string: "https://example.com/fr-anthologie-fixture.json")!
        )
        spy.outcome = CatalogRefreshOutcome(sources: [
            .init(id: source.id, name: source.name, status: .updated, lastAttemptAt: .now, lastSuccessAt: .now)
        ])
        let handler = CatalogActivationHandler(refresher: spy)
        let context = try makeContext()

        handler.activate(source: source, modelContext: context, existingUniverses: [])
        await handler.refreshTasks[source.id]?.value

        let universes = try context.fetch(FetchDescriptor<Universe>())
        XCTAssertEqual(universes.count, 1)
        XCTAssertEqual(universes.first?.name, fixtureCollectionName)
        XCTAssertEqual(universes.first?.managedCatalogID, source.id)
        XCTAssertEqual(universes.first?.style, .anthology)
        XCTAssertEqual(handler.state(for: source.id), .idle)
    }

    private final class SpyRefresherStub: ManagedCatalogRefreshing {
        var outcome = CatalogRefreshOutcome()
        func refreshManagedCatalog(universeName: String, force: Bool) async -> CatalogRefreshOutcome {
            outcome
        }
    }

    // MARK: - 3. Ein Delta gegen die FR-Fixture erzeugt Neuigkeiten mit Slug-Identität (Paket 4)

    func testDeltaAgainstFRFixtureProducesOneNewsEventPerEntryWithSlugIdentity() throws {
        let entries = try fixtureEntries()
        let delta = CatalogEpisodeDelta(
            catalogID: "fr-anthologie-fixture",
            name: fixtureCollectionName,
            previousVersion: 0,
            currentVersion: 1,
            previousEntryCount: 0,
            currentEntryCount: entries.count,
            addedEntries: entries
        )

        var document = NewsReconciler.establishBaselineIfNeeded(
            document: NewsStoreDocument(),
            deltas: [],
            availability: nil,
            upcoming: [],
            namesByCatalogID: [delta.catalogID: delta.name],
            activeCatalogIDs: [delta.catalogID]
        )
        document = NewsReconciler.reconcile(
            document: document,
            deltas: [delta],
            availability: nil,
            upcoming: [],
            namesByCatalogID: [delta.catalogID: delta.name],
            activeCatalogIDs: [delta.catalogID]
        )

        XCTAssertEqual(document.events.count, entries.count)
        XCTAssertTrue(document.events.allSatisfy { $0.kind == .newEpisode && $0.episodeNumber == nil && $0.slug != nil })
        XCTAssertEqual(Set(document.events.map(\.slug)), Set(entries.map(\.slug)))
    }
}
