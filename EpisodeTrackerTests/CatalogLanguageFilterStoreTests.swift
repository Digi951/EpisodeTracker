import XCTest
@testable import EpisodeTracker

final class CatalogLanguageFilterStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "CatalogLanguageFilter-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Implicit default

    func testDefaultsToAppLanguageWhenNothingStored() {
        let store = CatalogLanguageFilterStore(userDefaults: defaults)

        XCTAssertFalse(store.hasExplicitSelection)
        XCTAssertNil(store.explicitSelection)
        XCTAssertEqual(store.selectedLanguages, [ManagedCatalogSource.deviceLanguage])
    }

    // MARK: - Explicit selection

    func testExplicitSelectionPersistsAcrossStoreInstances() {
        CatalogLanguageFilterStore(userDefaults: defaults).setSelected(["de", "fr"])

        let reopened = CatalogLanguageFilterStore(userDefaults: defaults)
        XCTAssertTrue(reopened.hasExplicitSelection)
        XCTAssertEqual(reopened.selectedLanguages, ["de", "fr"])
    }

    func testExplicitEmptySelectionIsRetainedAndNotTreatedAsUnset() {
        CatalogLanguageFilterStore(userDefaults: defaults).setSelected([])

        let store = CatalogLanguageFilterStore(userDefaults: defaults)
        XCTAssertTrue(store.hasExplicitSelection, "an explicit empty choice is still a choice")
        XCTAssertEqual(store.explicitSelection, [])
        XCTAssertEqual(store.selectedLanguages, [], "empty stays empty — the UI offers \"Weitere Sprachen\"")
    }

    func testStoredSelectionIsReturnedVerbatimRegardlessOfAppLanguage() {
        // A selection that deliberately excludes the current app language must
        // survive untouched — the store never re-injects the device language
        // once an explicit choice exists.
        let foreign = ["fr", "nl"].filter { $0 != ManagedCatalogSource.deviceLanguage }
        CatalogLanguageFilterStore(userDefaults: defaults).setSelected(Set(foreign))

        let store = CatalogLanguageFilterStore(userDefaults: defaults)
        XCTAssertEqual(store.selectedLanguages, Set(foreign))
        XCTAssertFalse(store.selectedLanguages.contains(ManagedCatalogSource.deviceLanguage))
    }

    func testLanguageCodesAreNormalisedToLowercase() {
        CatalogLanguageFilterStore(userDefaults: defaults).setSelected(["DE", "Fr"])

        XCTAssertEqual(
            CatalogLanguageFilterStore(userDefaults: defaults).selectedLanguages,
            ["de", "fr"]
        )
    }

    // MARK: - Clearing

    func testClearSelectionRevertsToImplicitDefault() {
        let store = CatalogLanguageFilterStore(userDefaults: defaults)
        store.setSelected(["fr"])
        XCTAssertTrue(store.hasExplicitSelection)

        store.clearSelection()

        XCTAssertFalse(store.hasExplicitSelection)
        XCTAssertEqual(store.selectedLanguages, [ManagedCatalogSource.deviceLanguage])
    }
}
