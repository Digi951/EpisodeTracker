// EpisodeTrackerTests/EpisodeEditCoverHandlerTests.swift
import XCTest
import UIKit
@testable import EpisodeTracker

@MainActor
final class EpisodeEditCoverHandlerTests: XCTestCase {
    func testDefaultChangeIsKeep() {
        let handler = EpisodeEditCoverHandler()
        XCTAssertEqual(handler.coverChange, .keep)
    }

    func testSelectingImageProducesReplaceChange() {
        let handler = EpisodeEditCoverHandler()
        let image = UIImage(systemName: "star")!

        handler.applyPickedImage(image)

        XCTAssertEqual(handler.coverChange, .replace(image))
        XCTAssertFalse(handler.removeCover)
        XCTAssertTrue(handler.hasNewImage)
    }

    func testRequestingRemovalProducesRemoveChange() {
        let handler = EpisodeEditCoverHandler()
        handler.applyPickedImage(UIImage(systemName: "star")!)

        handler.requestRemoval()

        XCTAssertEqual(handler.coverChange, .remove)
        XCTAssertNil(handler.coverImage)
        XCTAssertFalse(handler.hasNewImage)
    }

    func testHasVisibleCoverIsFalseWhenRemovalRequested() {
        let handler = EpisodeEditCoverHandler()
        handler.requestRemoval()
        XCTAssertFalse(handler.hasVisibleCover(for: nil))
    }

    func testHasVisibleCoverIsTrueWithNewImage() {
        let handler = EpisodeEditCoverHandler()
        handler.applyPickedImage(UIImage(systemName: "star")!)
        XCTAssertTrue(handler.hasVisibleCover(for: nil))
    }

    func testRequestEditOpensEditorWithCurrentImageWhenPending() {
        let handler = EpisodeEditCoverHandler()
        let image = UIImage(systemName: "star")!
        handler.applyPickedImage(image)

        handler.requestEdit(for: nil)

        XCTAssertTrue(handler.imageToEdit?.image === image)
    }

    func testRequestEditDoesNothingWithoutAVisibleCover() {
        let handler = EpisodeEditCoverHandler()

        handler.requestEdit(for: nil)

        XCTAssertNil(handler.imageToEdit)
    }

    func testConfirmingEditedImageReplacesCoverImage() {
        let handler = EpisodeEditCoverHandler()
        let original = UIImage(systemName: "star")!
        let edited = UIImage(systemName: "star.fill")!
        handler.applyPickedImage(original)
        handler.requestEdit(for: nil)

        handler.applyPickedImage(edited)

        XCTAssertEqual(handler.coverChange, .replace(edited))
    }
}
