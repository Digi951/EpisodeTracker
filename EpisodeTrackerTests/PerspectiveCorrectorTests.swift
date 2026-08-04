// EpisodeTrackerTests/PerspectiveCorrectorTests.swift
import XCTest
import UIKit
@testable import EpisodeTracker

final class PerspectiveCorrectorTests: XCTestCase {

    func testNormalizedReturnsUprightImageForRightOrientation() {
        let image = makeTestImage(width: 100, height: 60, orientation: .right)

        let normalized = image.normalized()

        XCTAssertEqual(normalized.imageOrientation, .up)
        XCTAssertEqual(normalized.size, CGSize(width: 60, height: 100))
    }

    func testImageRectCentersLandscapeImageInSquareView() {
        let rect = PerspectiveCorrector.imageRect(
            in: CGSize(width: 200, height: 200),
            imageSize: CGSize(width: 100, height: 50)
        )

        XCTAssertEqual(rect.width, 200, accuracy: 0.001)
        XCTAssertEqual(rect.height, 100, accuracy: 0.001)
        XCTAssertEqual(rect.minX, 0, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 50, accuracy: 0.001)
    }

    func testImageRectCentersPortraitImageInWideView() {
        let rect = PerspectiveCorrector.imageRect(
            in: CGSize(width: 400, height: 200),
            imageSize: CGSize(width: 50, height: 100)
        )

        XCTAssertEqual(rect.width, 100, accuracy: 0.001)
        XCTAssertEqual(rect.height, 200, accuracy: 0.001)
        XCTAssertEqual(rect.minX, 150, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 0, accuracy: 0.001)
    }

    func testDisplayToCIPixelTopLeftMapsToTopLeftInCISpace() {
        let imageRect = CGRect(x: 10, y: 20, width: 100, height: 200)
        let pixelSize = CGSize(width: 500, height: 1_000)

        let result = PerspectiveCorrector.displayToCIPixel(
            point: CGPoint(x: 10, y: 20),
            imageRect: imageRect,
            pixelSize: pixelSize
        )

        XCTAssertEqual(result.x, 0, accuracy: 0.001)
        XCTAssertEqual(result.y, 1_000, accuracy: 0.001)
    }

    func testDisplayToCIPixelBottomRightMapsToBottomRightInCISpace() {
        let imageRect = CGRect(x: 10, y: 20, width: 100, height: 200)
        let pixelSize = CGSize(width: 500, height: 1_000)

        let result = PerspectiveCorrector.displayToCIPixel(
            point: CGPoint(x: 110, y: 220),
            imageRect: imageRect,
            pixelSize: pixelSize
        )

        XCTAssertEqual(result.x, 500, accuracy: 0.001)
        XCTAssertEqual(result.y, 0, accuracy: 0.001)
    }

    func testDisplayToCIPixelsUsesNormalizedImageSizeForRotatedImages() {
        let image = makeTestImage(width: 100, height: 60, orientation: .right)
        let imageRect = CGRect(x: 0, y: 0, width: 60, height: 100)

        let result = PerspectiveCorrector.displayToCIPixels(points: [
            CGPoint(x: 60, y: 100)
        ], imageRect: imageRect, image: image)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].x, 60, accuracy: 0.001)
        XCTAssertEqual(result[0].y, 0, accuracy: 0.001)
    }

    func testBestDetectionCandidatePrefersLargerCenteredQuad() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let smallEdgeCandidate = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 24, y: 0),
            CGPoint(x: 24, y: 24),
            CGPoint(x: 0, y: 24)
        ]
        let largerCenteredCandidate = [
            CGPoint(x: 18, y: 18),
            CGPoint(x: 82, y: 18),
            CGPoint(x: 82, y: 82),
            CGPoint(x: 18, y: 82)
        ]

        let result = PerspectiveCorrector.bestDetectionCandidate(
            from: [smallEdgeCandidate, largerCenteredCandidate],
            in: rect
        )

        XCTAssertEqual(result, largerCenteredCandidate)
    }

    func testApplyReturnsOriginalImageWhenCornersCountIsInvalid() {
        let image = makeTestImage(width: 100, height: 100, orientation: .up)

        let result = PerspectiveCorrector.apply(to: image, corners: [
            CGPoint(x: 0, y: 100),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 100, y: 0)
        ])

        XCTAssertEqual(result.size, image.size)
        XCTAssertEqual(result.imageOrientation, image.imageOrientation)
    }

    func testApplyWithFullImageCornersReturnsRenderableImage() {
        let image = makeTestImage(width: 100, height: 100, orientation: .up)

        let result = PerspectiveCorrector.apply(to: image, corners: [
            CGPoint(x: 0, y: 100),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 0, y: 0)
        ])

        XCTAssertNotNil(result.cgImage)
        XCTAssertEqual(result.imageOrientation, .up)
    }

    func testRotatedByNinetyDegreesSwapsWidthAndHeight() {
        let image = makeTestImage(width: 100, height: 60, orientation: .up)

        let rotated = image.rotated(byDegrees: 90)

        XCTAssertEqual(rotated.size, CGSize(width: 60, height: 100))
    }

    func testRotatedByZeroDegreesReturnsSameImage() {
        let image = makeTestImage(width: 100, height: 60, orientation: .up)

        XCTAssertTrue(image.rotated(byDegrees: 0) === image)
    }

    private func makeTestImage(width: CGFloat, height: CGFloat, orientation: UIImage.Orientation) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        let cgImage = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }.cgImage!
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
}
