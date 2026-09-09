import XCTest
@testable import EpisodeTracker

final class CatalogRefreshOutcomeTests: XCTestCase {
    private func result(
        _ name: String,
        _ status: CatalogRefreshOutcome.Status,
        success: Date? = nil
    ) -> CatalogRefreshOutcome.SourceResult {
        CatalogRefreshOutcome.SourceResult(
            id: name.lowercased(),
            name: name,
            status: status,
            lastAttemptAt: Date(timeIntervalSince1970: 1_000_000),
            lastSuccessAt: success
        )
    }

    func testStatusSuccessClassification() {
        XCTAssertTrue(CatalogRefreshOutcome.Status.updated.isSuccess)
        XCTAssertTrue(CatalogRefreshOutcome.Status.notModified.isSuccess)
        XCTAssertFalse(CatalogRefreshOutcome.Status.failed(.http(status: 500)).isSuccess)
    }

    func testAllSuccessHasNoFailure() {
        let outcome = CatalogRefreshOutcome(
            manifest: result("Katalogverzeichnis", .notModified),
            upcoming: result("Bald verfügbar", .updated),
            sources: [result("A", .updated), result("B", .notModified)]
        )
        XCTAssertTrue(outcome.hadAnySuccess)
        XCTAssertFalse(outcome.hadAnyFailure)
        XCTAssertTrue(outcome.failedNames.isEmpty)
        XCTAssertTrue(outcome.failedCatalogNames.isEmpty)
        XCTAssertFalse(outcome.manifestFailed)
    }

    func testPartialFailureReportsOnlyFailedCatalogs() {
        let outcome = CatalogRefreshOutcome(
            manifest: result("Katalogverzeichnis", .notModified),
            upcoming: result("Bald verfügbar", .failed(.http(status: 500))),
            sources: [
                result("A", .updated),
                result("B", .failed(.http(status: 503))),
                result("C", .notModified)
            ]
        )
        XCTAssertTrue(outcome.hadAnySuccess)
        XCTAssertTrue(outcome.hadAnyFailure)
        // failedNames enthält auch Bald-verfügbar; failedCatalogNames nicht.
        XCTAssertEqual(Set(outcome.failedNames), ["Bald verfügbar", "B"])
        XCTAssertEqual(outcome.failedCatalogNames, ["B"])
        XCTAssertEqual(outcome.attemptedCatalogCount, 3)
        XCTAssertFalse(outcome.manifestFailed)
    }

    func testManifestFailureIsReportedSeparately() {
        let outcome = CatalogRefreshOutcome(
            manifest: result("Katalogverzeichnis", .failed(.transport(code: -1009))),
            sources: [result("A", .notModified)]
        )
        XCTAssertTrue(outcome.manifestFailed)
        XCTAssertTrue(outcome.hadAnyFailure)
        XCTAssertTrue(outcome.failedCatalogNames.isEmpty)
    }

    func testThrottledRunHasEmptyOutcome() {
        let outcome = CatalogRefreshOutcome()
        XCTAssertFalse(outcome.hadAnySuccess)
        XCTAssertFalse(outcome.hadAnyFailure)
        XCTAssertEqual(outcome.attemptedCatalogCount, 0)
    }

    func testFetchErrorKindLabel() {
        XCTAssertEqual(CatalogFetchError.http(status: 404).kindLabel, "http:404")
        XCTAssertEqual(CatalogFetchError.transport(code: -1001).kindLabel, "transport:-1001")
        XCTAssertEqual(CatalogFetchError.notHTTP.kindLabel, "notHTTP")
        XCTAssertEqual(CatalogFetchError.decoding("boom").kindLabel, "decoding")
    }
}
