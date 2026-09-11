import XCTest
@testable import EpisodeTracker

final class NewsStoreTests: XCTestCase {

    private func makeStore() -> NewsStore {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NewsStoreTests-\(UUID().uuidString)")
        return NewsStore(directoryURL: tempDir)
    }

    func testLoadReturnsEmptyFreshDocumentWhenNothingStored() {
        let store = makeStore()
        let document = store.load()

        XCTAssertEqual(document.schemaVersion, NewsStoreDocument.currentSchemaVersion)
        XCTAssertFalse(document.hasEstablishedBaseline)
        XCTAssertEqual(document.events, [])
        XCTAssertEqual(document.lastReconciledRevisions, [:])
    }

    func testSaveAndLoadRoundTripsIncludingUnseenEvent() throws {
        let store = makeStore()
        let event = NewsEvent(
            kind: .newEpisode,
            universeName: "Die drei ???",
            catalogID: "die-drei-fragezeichen",
            episodeNumber: 241,
            title: "Meister des Lichts",
            revision: "241",
            discoveredAt: Date(timeIntervalSince1970: 1_789_000_000),
            seenAt: nil
        )
        var document = NewsStoreDocument()
        document.hasEstablishedBaseline = true
        document.events = [event]
        document.lastReconciledRevisions = [event.id: "241"]

        try store.save(document)

        let loaded = store.load()
        XCTAssertEqual(loaded, document)
        XCTAssertNil(loaded.events.first?.seenAt)
    }

    func testLoadOfCorruptFileReturnsFreshDocumentAndNeverThrows() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NewsStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storeFile = tempDir.appendingPathComponent("NewsEvents.json")
        try Data("not valid json { [".utf8).write(to: storeFile)

        let store = NewsStore(directoryURL: tempDir)
        let document = store.load()

        XCTAssertEqual(document, NewsStoreDocument())
    }

    func testSequentialSavesAreAtomicAndLastWriteWins() throws {
        let store = makeStore()

        for index in 0..<5 {
            var document = NewsStoreDocument()
            document.hasEstablishedBaseline = true
            document.lastReconciledRevisions = ["run": String(index)]
            try store.save(document)
        }

        XCTAssertEqual(store.load().lastReconciledRevisions["run"], "4")
    }
}
