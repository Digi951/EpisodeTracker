import XCTest
@testable import EpisodeTracker

final class EpisodeEditSectionOrderTests: XCTestCase {

    func testDefaultOrderContainsAllSections() {
        let order = EpisodeEditSectionOrder.sections(from: "")
        XCTAssertEqual(Set(order), Set(EpisodeEditSection.allCases))
        XCTAssertEqual(order.count, EpisodeEditSection.allCases.count)
    }

    func testSavedOrderIsRespected() {
        let order = EpisodeEditSectionOrder.sections(from: "moods,cover,status,streaming,note")
        XCTAssertEqual(order, [.moods, .cover, .status, .streaming, .note])
    }

    func testUnknownRawValuesAreDropped() {
        let order = EpisodeEditSectionOrder.sections(from: "cover,unknown,status")
        XCTAssertFalse(order.contains(where: { $0.rawValue == "unknown" }))
        XCTAssertTrue(order.contains(.cover))
        XCTAssertTrue(order.contains(.status))
    }

    func testNewSectionsAppendedAtEndWhenMissingFromSaved() {
        // cover, status und note sind gespeichert — moods und streaming fehlen
        let order = EpisodeEditSectionOrder.sections(from: "cover,status,note")
        XCTAssertEqual(order.prefix(3), [.cover, .status, .note])
        XCTAssertTrue(order.contains(.moods))
        XCTAssertTrue(order.contains(.streaming))
    }

    func testEncodeAndDecodeRoundtrip() {
        let original: [EpisodeEditSection] = [.moods, .streaming, .cover, .note, .status]
        let encoded = EpisodeEditSectionOrder.encode(original)
        let decoded = EpisodeEditSectionOrder.sections(from: encoded)
        XCTAssertEqual(decoded, original)
    }
}
