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
}
