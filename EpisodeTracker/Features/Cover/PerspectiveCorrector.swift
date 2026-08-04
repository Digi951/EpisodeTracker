// EpisodeTracker/Features/Cover/PerspectiveCorrector.swift
import CoreImage
import UIKit

enum PerspectiveCorrector {

    nonisolated static func imageRect(in viewSize: CGSize, imageSize: CGSize) -> CGRect {
        guard viewSize.width > 0,
              viewSize.height > 0,
              imageSize.width > 0,
              imageSize.height > 0 else {
            return .zero
        }

        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale

        return CGRect(
            x: (viewSize.width - width) / 2,
            y: (viewSize.height - height) / 2,
            width: width,
            height: height
        )
    }

    nonisolated static func displayToCIPixel(point: CGPoint, imageRect: CGRect, pixelSize: CGSize) -> CGPoint {
        guard imageRect.width > 0, imageRect.height > 0 else { return .zero }

        let normalizedX = (point.x - imageRect.minX) / imageRect.width
        let normalizedY = (point.y - imageRect.minY) / imageRect.height

        return CGPoint(
            x: normalizedX * pixelSize.width,
            y: (1 - normalizedY) * pixelSize.height
        )
    }

    nonisolated static func displayToCIPixels(points: [CGPoint], imageRect: CGRect, image: UIImage) -> [CGPoint] {
        let normalizedImage = image.normalized()
        let pixelSize = CGSize(
            width: normalizedImage.size.width * normalizedImage.scale,
            height: normalizedImage.size.height * normalizedImage.scale
        )

        return points.map {
            displayToCIPixel(point: $0, imageRect: imageRect, pixelSize: pixelSize)
        }
    }

    nonisolated static func bestDetectionCandidate(from candidates: [[CGPoint]], in rect: CGRect) -> [CGPoint]? {
        guard rect.width > 0, rect.height > 0 else { return nil }

        return candidates
            .filter { isUsableDetectionQuad($0, in: rect) }
            .max { detectionScore(for: $0, in: rect) < detectionScore(for: $1, in: rect) }
    }

    nonisolated static func apply(to image: UIImage, corners: [CGPoint]) -> UIImage {
        guard corners.count == 4 else { return image }

        let normalizedImage = image.normalized()
        guard let cgImage = normalizedImage.cgImage else { return image }

        let inputImage = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: "CIPerspectiveCorrection")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(cgPoint: corners[0]), forKey: "inputTopLeft")
        filter?.setValue(CIVector(cgPoint: corners[1]), forKey: "inputTopRight")
        filter?.setValue(CIVector(cgPoint: corners[2]), forKey: "inputBottomRight")
        filter?.setValue(CIVector(cgPoint: corners[3]), forKey: "inputBottomLeft")

        guard let outputImage = filter?.outputImage else { return image }

        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let outputCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return image
        }

        return UIImage(cgImage: outputCGImage, scale: normalizedImage.scale, orientation: .up)
    }

    private nonisolated static func isUsableDetectionQuad(_ points: [CGPoint], in rect: CGRect) -> Bool {
        guard points.count == 4 else { return false }

        let areaRatio = polygonArea(points) / max(rect.width * rect.height, 1)
        return areaRatio >= 0.08
    }

    private nonisolated static func detectionScore(for points: [CGPoint], in rect: CGRect) -> CGFloat {
        let areaRatio = min(polygonArea(points) / max(rect.width * rect.height, 1), 1)
        let bounds = points.reduce(CGRect.null) { partialResult, point in
            partialResult.union(CGRect(origin: point, size: .zero))
        }
        let centerDistance = hypot(bounds.midX - rect.midX, bounds.midY - rect.midY)
        let maxDistance = max(hypot(rect.width / 2, rect.height / 2), 1)
        let centerScore = 1 - min(centerDistance / maxDistance, 1)

        return areaRatio * 0.75 + centerScore * 0.25
    }

    private nonisolated static func polygonArea(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 2 else { return 0 }

        return abs(zip(points, points.dropFirst() + [points[0]]).reduce(CGFloat.zero) { area, pair in
            area + pair.0.x * pair.1.y - pair.1.x * pair.0.y
        }) / 2
    }
}

extension UIImage {
    nonisolated func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
