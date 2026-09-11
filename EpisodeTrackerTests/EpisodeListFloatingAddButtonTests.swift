import XCTest
@testable import EpisodeTracker

/// Paket 6, P6-A — der schwebende Hinzufügen-Button darf sich nicht mit der
/// primären "Erste Folge anlegen"-Aktion des Empty-States überlagern (Review
/// vom 08.09.2026, `docs/reviews/2026-09-08/01-erststart.png`).
final class EpisodeListFloatingAddButtonTests: XCTestCase {
    func testHiddenWhenLibraryIsEmpty() {
        XCTAssertFalse(
            EpisodeListOrganizer.shouldShowFloatingAddButton(isEditing: false, isLibraryEmpty: true),
            "the empty-state onboarding already offers a primary add action"
        )
    }

    func testVisibleWhenLibraryHasEpisodesAndNotEditing() {
        XCTAssertTrue(
            EpisodeListOrganizer.shouldShowFloatingAddButton(isEditing: false, isLibraryEmpty: false)
        )
    }

    func testHiddenWhileEditingRegardlessOfLibraryState() {
        XCTAssertFalse(EpisodeListOrganizer.shouldShowFloatingAddButton(isEditing: true, isLibraryEmpty: false))
        XCTAssertFalse(EpisodeListOrganizer.shouldShowFloatingAddButton(isEditing: true, isLibraryEmpty: true))
    }
}
