import XCTest
@testable import EpisodeTracker

/// Tier-3 on-device diagnostics: the store-recovery breadcrumb that makes the new
/// layered recovery path observable without transmitting anything off the device.
final class StoreRecoveryDiagnosticsTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "StoreRecoveryTest-\(UUID().uuidString)")!
    }

    func testNoRecoveryRecordedByDefault() {
        let defaults = makeDefaults()
        XCTAssertNil(AppModelContainerFactory.lastStoreRecovery(userDefaults: defaults))
    }

    func testRecordAndReadRoundtrip() {
        let defaults = makeDefaults()
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        AppModelContainerFactory.recordStoreRecovery(
            .quarantinedAndReset,
            detail: "Cannot use staged migration with an unknown model version",
            date: date,
            userDefaults: defaults
        )

        let record = AppModelContainerFactory.lastStoreRecovery(userDefaults: defaults)
        XCTAssertEqual(record?.outcome, .quarantinedAndReset)
        XCTAssertEqual(record?.detail, "Cannot use staged migration with an unknown model version")
        XCTAssertEqual(record?.date.timeIntervalSince1970 ?? 0, date.timeIntervalSince1970, accuracy: 1)
    }

    func testDetailIsTruncatedToBound() {
        let defaults = makeDefaults()
        AppModelContainerFactory.recordStoreRecovery(
            .recoveredLightweight,
            detail: String(repeating: "x", count: 5000),
            userDefaults: defaults
        )
        let record = AppModelContainerFactory.lastStoreRecovery(userDefaults: defaults)
        XCTAssertEqual(record?.outcome, .recoveredLightweight)
        XCTAssertLessThanOrEqual(record?.detail.count ?? .max, 500)
    }

    func testQuarantineMovesStoreAsideAndKeepsACopy() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuarantineTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let storeURL = dir.appendingPathComponent("EpisodeTracker.store")
        FileManager.default.createFile(atPath: storeURL.path, contents: Data("corrupt".utf8))

        AppModelContainerFactory.quarantineUnreadableStore(storeURL: storeURL, fileManager: .default)

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: storeURL.path),
            "The unreadable store must be moved out of the active path"
        )
        let remaining = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(
            remaining.contains(where: { $0.contains("unreadable") }),
            "The quarantined copy must be preserved on disk for later salvage"
        )
    }
}
