import XCTest
import SwiftData
@testable import EpisodeTracker

@MainActor
final class BackupBindingRoundTripTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Episode.self, Mood.self, Universe.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    // MARK: - Writer

    func testExportEmitsBindingStyleAndSchemaVersion3() throws {
        let context = try makeContext()
        let bound = Universe(name: "TKKG")
        bound.managedCatalogID = "tkkg"
        bound.style = .anthology
        let plain = Universe(name: "Meine Sammlung")
        context.insert(bound)
        context.insert(plain)

        let controller = BackupExportImportController()
        controller.export(universes: [bound, plain], moods: [], episodes: [])

        let data = try XCTUnwrap(controller.exportDocument?.data)
        let payload = try JSONDecoder.backupDecoder.decode(BackupPayload.self, from: data)

        XCTAssertEqual(payload.schemaVersion, 3)
        let byName = Dictionary(uniqueKeysWithValues: (payload.collections ?? []).map { ($0.name, $0) })
        XCTAssertEqual(byName["TKKG"]?.managedCatalogID, "tkkg")
        XCTAssertEqual(byName["TKKG"]?.style, CatalogStyle.anthology.rawValue)
        XCTAssertNil(byName["Meine Sammlung"]?.managedCatalogID)
        XCTAssertEqual(byName["Meine Sammlung"]?.style, CatalogStyle.numbered.rawValue)
    }

    // MARK: - Encoder round trip

    func testCollectionRoundTripsThroughTheBackupCoder() throws {
        let payload = BackupPayload(
            exportedAt: .now,
            schemaVersion: 3,
            collections: [
                BackupCollection(name: "TKKG", managedCatalogID: "tkkg", style: CatalogStyle.anthology.rawValue),
                BackupCollection(name: "Handarbeit"),
            ],
            moods: [],
            episodes: []
        )

        let data = try JSONEncoder.backupEncoder.encode(payload)
        let decoded = try JSONDecoder.backupDecoder.decode(BackupPayload.self, from: data)

        let byName = Dictionary(uniqueKeysWithValues: (decoded.collections ?? []).map { ($0.name, $0) })
        XCTAssertEqual(byName["TKKG"]?.managedCatalogID, "tkkg")
        XCTAssertEqual(byName["TKKG"]?.style, "anthology")
        XCTAssertNil(byName["Handarbeit"]?.managedCatalogID)
        XCTAssertNil(byName["Handarbeit"]?.style)
    }

    // MARK: - Restore into an empty library

    func testImportCreatesBoundStyledCollection() throws {
        let context = try makeContext()
        let payload = BackupPayload(
            exportedAt: .now,
            schemaVersion: 3,
            collections: [BackupCollection(name: "TKKG", managedCatalogID: "tkkg", style: "anthology")],
            moods: [],
            episodes: []
        )

        BackupRestorer.apply(payload, existingUniverses: [], existingMoods: [], existingEpisodes: [], context: context)

        let universe = try XCTUnwrap(try context.fetch(FetchDescriptor<Universe>()).first)
        XCTAssertEqual(universe.managedCatalogID, "tkkg")
        XCTAssertEqual(universe.style, .anthology)
    }

    // MARK: - Restore onto an existing collection

    func testImportAdoptsBindingOnAnUnboundExistingCollection() throws {
        let context = try makeContext()
        let existing = Universe(name: "TKKG")
        context.insert(existing)

        let payload = BackupPayload(
            exportedAt: .now,
            schemaVersion: 3,
            collections: [BackupCollection(name: " tkkg ", managedCatalogID: "tkkg", style: "anthology")],
            moods: [],
            episodes: []
        )

        BackupRestorer.apply(payload, existingUniverses: [existing], existingMoods: [], existingEpisodes: [], context: context)

        XCTAssertEqual(existing.managedCatalogID, "tkkg", "an unbound name match adopts the backup binding")
        XCTAssertEqual(existing.style, .numbered, "the style of an existing collection is left untouched")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Universe>()).count, 1)
    }

    func testImportNeverClobbersADifferentLocalBinding() throws {
        let context = try makeContext()
        let existing = Universe(name: "TKKG")
        existing.managedCatalogID = "local-source"
        context.insert(existing)

        let payload = BackupPayload(
            exportedAt: .now,
            schemaVersion: 3,
            collections: [BackupCollection(name: "TKKG", managedCatalogID: "backup-source", style: nil)],
            moods: [],
            episodes: []
        )

        BackupRestorer.apply(payload, existingUniverses: [existing], existingMoods: [], existingEpisodes: [], context: context)

        XCTAssertEqual(existing.managedCatalogID, "local-source", "local binding X stays X, backup binding Y is ignored")
    }

    // MARK: - Older backups

    func testSchemaVersion1BackupImportsWithoutTheNewFields() throws {
        let json = """
        {"exportedAt":"2024-01-01T00:00:00Z","schemaVersion":1,"collections":[{"name":"TKKG"}],"moods":[],"episodes":[]}
        """.data(using: .utf8)!

        let payload = try JSONDecoder.backupDecoder.decode(BackupPayload.self, from: json)
        XCTAssertEqual(payload.collections?.first?.name, "TKKG")
        XCTAssertNil(payload.collections?.first?.managedCatalogID)
        XCTAssertNil(payload.collections?.first?.style)

        let context = try makeContext()
        BackupRestorer.apply(payload, existingUniverses: [], existingMoods: [], existingEpisodes: [], context: context)

        let universe = try XCTUnwrap(try context.fetch(FetchDescriptor<Universe>()).first)
        XCTAssertNil(universe.managedCatalogID)
        XCTAssertEqual(universe.style, .numbered)
    }

    func testSchemaVersion2BackupWithBareCollectionsStillImports() throws {
        let json = """
        {"exportedAt":"2024-01-01T00:00:00Z","schemaVersion":2,"collections":[{"name":"Bibi Blocksberg"}],"moods":[],"episodes":[{"episodeNumber":1,"kind":"regular","title":"Hexerei","releaseYear":1980,"isListened":false,"listenCount":0,"collectionName":"Bibi Blocksberg","moodNames":[]}]}
        """.data(using: .utf8)!

        let payload = try JSONDecoder.backupDecoder.decode(BackupPayload.self, from: json)
        let context = try makeContext()
        BackupRestorer.apply(payload, existingUniverses: [], existingMoods: [], existingEpisodes: [], context: context)

        let universe = try XCTUnwrap(try context.fetch(FetchDescriptor<Universe>()).first)
        XCTAssertEqual(universe.name, "Bibi Blocksberg")
        XCTAssertNil(universe.managedCatalogID)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Episode>()).count, 1)
    }
}
