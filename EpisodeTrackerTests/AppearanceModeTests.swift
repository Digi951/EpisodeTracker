import XCTest
@testable import EpisodeTracker

/// Paket 6, P6-C — beim FR-Sichtprüfungsdurchlauf gefunden: die drei
/// Darstellungsoptionen waren hartkodiertes Deutsch ohne xcstrings-Eintrag
/// (`docs/reviews/2026-09-11-paket6-sichtpruefung/befunde.md`).
final class AppearanceModeTests: XCTestCase {
    func testSystemTitleFallsBackToGermanDefault() {
        XCTAssertEqual(
            AppearanceMode.system.title,
            String(localized: "Appearance.Mode.System", defaultValue: "System")
        )
    }

    func testLightTitleFallsBackToGermanDefault() {
        XCTAssertEqual(
            AppearanceMode.light.title,
            String(localized: "Appearance.Mode.Light", defaultValue: "Hell")
        )
    }

    func testDarkTitleFallsBackToGermanDefault() {
        XCTAssertEqual(
            AppearanceMode.dark.title,
            String(localized: "Appearance.Mode.Dark", defaultValue: "Dunkel")
        )
    }
}
