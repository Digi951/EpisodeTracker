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

    // MARK: - markingSeen (Review-Fund #2)

    func testMarkingSeenSetsSeenAtOnlyForTheMatchingUnseenEvent() {
        let now = Date(timeIntervalSince1970: 1_789_000_000)
        let target = NewsEvent(
            kind: .newEpisode, universeName: "Die drei ???", catalogID: "die-drei-fragezeichen",
            episodeNumber: 241, title: "Meister des Lichts", revision: "241", discoveredAt: now
        )
        let other = NewsEvent(
            kind: .newCatalog, universeName: "TKKG", catalogID: "tkkg",
            title: "TKKG", revision: "tkkg", discoveredAt: now
        )
        var document = NewsStoreDocument()
        document.events = [target, other]

        let result = document.markingSeen(eventID: target.id, now: now)

        XCTAssertEqual(result.events.first { $0.id == target.id }?.seenAt, now)
        XCTAssertNil(result.events.first { $0.id == other.id }?.seenAt, "unrelated events must stay untouched")
    }

    func testMarkingSeenIsANoOpWhenAlreadySeen() {
        let now = Date(timeIntervalSince1970: 1_789_000_000)
        let alreadySeenAt = now.addingTimeInterval(-3600)
        let event = NewsEvent(
            kind: .newEpisode, universeName: "Die drei ???", catalogID: "die-drei-fragezeichen",
            episodeNumber: 241, title: "Meister des Lichts", revision: "241", discoveredAt: now, seenAt: alreadySeenAt
        )
        var document = NewsStoreDocument()
        document.events = [event]

        let result = document.markingSeen(eventID: event.id, now: now)

        XCTAssertEqual(result, document, "must not overwrite an existing seenAt or otherwise change the document")
    }

    func testMarkingSeenIsANoOpForAnUnknownEventID() {
        var document = NewsStoreDocument()
        document.events = []

        let result = document.markingSeen(eventID: "does-not-exist")

        XCTAssertEqual(result, document)
    }

    // MARK: - Cache (Review-Fund #7)

    func testLoadIsCachedPerDirectoryURLAcrossInstances() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NewsStoreTests-\(UUID().uuidString)")
        let storeA = NewsStore(directoryURL: tempDir)

        var document = NewsStoreDocument()
        document.hasEstablishedBaseline = true
        try storeA.save(document)

        // Datei extern beschädigen, ohne über `NewsStore.save` zu gehen —
        // eine zweite Instanz für dasselbe Verzeichnis muss trotzdem den
        // zwischengespeicherten, gültigen Stand liefern statt erneut von der
        // (jetzt kaputten) Datei zu lesen.
        let storeFile = tempDir.appendingPathComponent("NewsEvents.json")
        try Data("not valid json { [".utf8).write(to: storeFile)

        let storeB = NewsStore(directoryURL: tempDir)
        XCTAssertEqual(storeB.load(), document)
    }

    func testLoadDoesNotLeakBetweenDifferentDirectoryURLs() throws {
        let storeA = makeStore()
        var documentA = NewsStoreDocument()
        documentA.lastReconciledRevisions = ["marker": "a"]
        try storeA.save(documentA)

        let storeB = makeStore()

        XCTAssertEqual(storeB.load(), NewsStoreDocument(), "a store for a different directory must never see storeA's cached document")
    }
}
