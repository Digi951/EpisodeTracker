import XCTest
@testable import EpisodeTracker

final class SavedFilterTests: XCTestCase {

    func testSavedFilterEncodesAndDecodesAllFields() throws {
        let id = UUID()
        let filter = SavedFilter(
            id: id,
            name: "Ungeh. Krimis",
            statusFilter: .open,
            universeName: "Die drei ???",
            moodName: "Gruselig",
            sortOrder: .rating
        )

        let data = try JSONEncoder().encode(filter)
        let decoded = try JSONDecoder().decode(SavedFilter.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.name, "Ungeh. Krimis")
        XCTAssertEqual(decoded.resolvedStatusFilter, .open)
        XCTAssertEqual(decoded.universeName, "Die drei ???")
        XCTAssertEqual(decoded.moodName, "Gruselig")
        XCTAssertEqual(decoded.resolvedSortOrder, .rating)
    }

    func testSavedFilterSummaryUsesDisplayValues() {
        let filter = SavedFilter(
            name: "Highlights",
            statusFilter: .open,
            universeName: "Die drei ???",
            moodName: "Gruselig",
            sortOrder: .rating
        )

        XCTAssertEqual(
            filter.summaryText,
            "\(EpisodeStatusFilter.open.displayName) · Die drei ??? · Gruselig · \(EpisodeSortOrder.rating.displayName)"
        )
    }

    func testSavedFilterSummaryFallsBackToAllEpisodes() {
        let filter = SavedFilter(name: "Alle")

        XCTAssertEqual(
            filter.summaryText,
            String(localized: "SavedFilter.Summary.AllEpisodes", defaultValue: "Alle Folgen")
        )
    }

    func testSavedFilterDisplayKeysAreLocalizedInGermanAndEnglish() throws {
        let stringCatalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("EpisodeTracker/Localizable.xcstrings")
        let data = try Data(contentsOf: stringCatalogURL)
        let catalog = try JSONDecoder().decode(StringCatalog.self, from: data)
        let expectedKeys = EpisodeStatusFilter.allCases.map(\.displayLocalizationKey)
            + EpisodeSortOrder.allCases.map(\.displayLocalizationKey)
            + ["SavedFilter.Summary.AllEpisodes"]

        for key in expectedKeys {
            let languages = try XCTUnwrap(catalog.strings[key]?.localizations, "Missing localization key: \(key)")
            XCTAssertNotNil(languages["de"]?.stringUnit.value, "Missing German localization for \(key)")
            XCTAssertNotNil(languages["en"]?.stringUnit.value, "Missing English localization for \(key)")
        }
    }

    func testInvalidStatusFilterRawValueFallsBackToAll() throws {
        let data = """
        {"id":"00000000-0000-0000-0000-000000000001","name":"Test",
         "statusFilterRaw":"unknownStatus","universeName":null,
         "moodName":null,"sortOrderRaw":"Nummer"}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SavedFilter.self, from: data)

        XCTAssertEqual(decoded.resolvedStatusFilter, .all)
    }

    func testInvalidSortOrderRawValueFallsBackToNumber() throws {
        let data = """
        {"id":"00000000-0000-0000-0000-000000000002","name":"Test",
         "statusFilterRaw":"Alle","universeName":null,
         "moodName":null,"sortOrderRaw":"unknownSort"}
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SavedFilter.self, from: data)

        XCTAssertEqual(decoded.resolvedSortOrder, .number)
    }

    func testSavedFilterStoreAddUpdateDelete() {
        let defaults = UserDefaults(suiteName: "test-saved-filter-\(UUID().uuidString)")!
        let store = SavedFilterStore(defaults: defaults)

        let filter = SavedFilter(name: "Test", statusFilter: .open)
        store.add(filter)
        XCTAssertEqual(store.filters.count, 1)

        var updated = filter
        updated.name = "Geändert"
        store.update(updated)
        XCTAssertEqual(store.filters.first?.name, "Geändert")

        store.delete(updated)
        XCTAssertTrue(store.filters.isEmpty)
    }

    func testSavedFilterStorePersistsAcrossInstances() {
        let suiteName = "test-saved-filter-persist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let store1 = SavedFilterStore(defaults: defaults)
        let filter = SavedFilter(name: "Persistiert", statusFilter: .listened)
        store1.add(filter)

        let store2 = SavedFilterStore(defaults: defaults)
        XCTAssertEqual(store2.filters.count, 1)
        XCTAssertEqual(store2.filters.first?.name, "Persistiert")
        XCTAssertEqual(store2.filters.first?.resolvedStatusFilter, .listened)
    }
}

private struct StringCatalog: Decodable {
    let strings: [String: StringCatalogEntry]
}

private struct StringCatalogEntry: Decodable {
    let localizations: [String: StringCatalogLocalization]?
}

private struct StringCatalogLocalization: Decodable {
    let stringUnit: StringCatalogStringUnit
}

private struct StringCatalogStringUnit: Decodable {
    let value: String
}
