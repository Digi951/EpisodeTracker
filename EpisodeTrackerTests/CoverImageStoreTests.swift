import XCTest
@testable import EpisodeTracker

final class CoverImageStoreTests: XCTestCase {
    private var store: CoverImageStore!
    private var testDirectory: URL!

    override func setUp() {
        super.setUp()
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CoverImageStoreTest-\(UUID().uuidString)", isDirectory: true)
        store = CoverImageStore(baseDirectory: testDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testDirectory)
        super.tearDown()
    }

    func testSaveAndLoadRoundtrip() throws {
        let image = makeTestImage(width: 100, height: 100)
        try store.save(image, name: "roundtrip")

        XCTAssertTrue(store.exists(name: "roundtrip"))

        let loaded = store.load(name: "roundtrip")
        XCTAssertNotNil(loaded)
    }

    func testDeleteRemovesFile() throws {
        let image = makeTestImage(width: 100, height: 100)
        try store.save(image, name: "to-delete")
        XCTAssertTrue(store.exists(name: "to-delete"))

        try store.delete(name: "to-delete")
        XCTAssertFalse(store.exists(name: "to-delete"))
    }

    func testSaveOverwritesExistingFile() throws {
        let image1 = makeTestImage(width: 100, height: 100, color: .blue)
        try store.save(image1, name: "overwrite")

        let data1 = try Data(contentsOf: testDirectory.appendingPathComponent("overwrite.jpg"))

        let image2 = makeTestImage(width: 100, height: 100, color: .red)
        try store.save(image2, name: "overwrite")

        let data2 = try Data(contentsOf: testDirectory.appendingPathComponent("overwrite.jpg"))

        XCTAssertNotEqual(data1, data2)
    }

    func testDeleteNonexistentFileDoesNotThrow() throws {
        XCTAssertNoThrow(try store.delete(name: "nonexistent"))
    }

    func testLargeImageIsScaledDown() throws {
        let image = makeTestImage(width: 2000, height: 1000)
        try store.save(image, name: "large")

        let loaded = store.load(name: "large")
        XCTAssertNotNil(loaded)

        let size = loaded!.size
        XCTAssertLessThanOrEqual(size.width, 512)
        XCTAssertLessThanOrEqual(size.height, 512)
        XCTAssertEqual(size.width, 512, accuracy: 1)
    }

    func testPortraitImageIsScaledProportionally() throws {
        let image = makeTestImage(width: 800, height: 1600)
        try store.save(image, name: "portrait")

        let loaded = store.load(name: "portrait")
        XCTAssertNotNil(loaded)

        let size = loaded!.size
        XCTAssertEqual(size.height, 512, accuracy: 1)
        XCTAssertEqual(size.width, 256, accuracy: 1)
    }

    func testSmallImageIsNotUpscaled() throws {
        let image = makeTestImage(width: 200, height: 150)
        try store.save(image, name: "small")

        let loaded = store.load(name: "small")
        XCTAssertNotNil(loaded)

        let size = loaded!.size
        XCTAssertEqual(size.width, 200, accuracy: 1)
        XCTAssertEqual(size.height, 150, accuracy: 1)
    }

    private func makeTestImage(width: Int, height: Int, color: UIColor = .blue) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: format
        )
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
