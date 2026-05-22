import XCTest
import Observation
@testable import EpisodeTracker

@MainActor
final class EpisodeCatalogTests: XCTestCase {

    // MARK: - Helpers

    private func makeTempCacheStore() -> CatalogCacheStore {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EpisodeCatalogTests-\(UUID().uuidString)")
        return CatalogCacheStore(directoryURL: tempDir)
    }

    private func makeSource(id: String = "test", name: String = "Test Katalog") -> ManagedCatalogSource {
        ManagedCatalogSource(
            id: id,
            name: name,
            url: URL(string: "https://example.com/\(id).json")!
        )
    }

    // MARK: - Initialisation

    func testNewCatalogAvailabilityIsNilWhenCacheIsEmpty() {
        let catalog = EpisodeCatalog(cacheStore: makeTempCacheStore())
        XCTAssertNil(catalog.newCatalogAvailability)
    }

    func testNewCatalogAvailabilityIsLoadedFromCacheOnInit() throws {
        let store = makeTempCacheStore()
        let source = makeSource(name: "Die Playmos")
        try store.saveNewCatalogAvailability(NewCatalogAvailability(sources: [source]))

        let catalog = EpisodeCatalog(cacheStore: store)

        XCTAssertEqual(catalog.newCatalogAvailability?.sources.first?.name, "Die Playmos")
    }

    // MARK: - Observable behaviour

    func testNewCatalogAvailabilityObservationFiresWhenSet() {
        let catalog = EpisodeCatalog(cacheStore: makeTempCacheStore())

        var observationFired = false
        withObservationTracking {
            _ = catalog.newCatalogAvailability
        } onChange: {
            observationFired = true
        }

        catalog.updateNewCatalogAvailability(NewCatalogAvailability(sources: [makeSource()]))

        XCTAssertTrue(
            observationFired,
            "newCatalogAvailability must be a stored @Observable property so SwiftUI re-renders the banner"
        )
        XCTAssertNotNil(catalog.newCatalogAvailability)
    }

    func testNewCatalogAvailabilityObservationFiresWhenCleared() throws {
        let store = makeTempCacheStore()
        try store.saveNewCatalogAvailability(NewCatalogAvailability(sources: [makeSource()]))
        let catalog = EpisodeCatalog(cacheStore: store)

        XCTAssertNotNil(catalog.newCatalogAvailability)

        var observationFired = false
        withObservationTracking {
            _ = catalog.newCatalogAvailability
        } onChange: {
            observationFired = true
        }

        catalog.updateNewCatalogAvailability(nil)

        XCTAssertTrue(
            observationFired,
            "Clearing newCatalogAvailability must trigger observation so the banner disappears"
        )
        XCTAssertNil(catalog.newCatalogAvailability)
    }
}
