import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let directory = URL(fileURLWithPath: "/Users/christopherdieckmann/Projects/EpisodeTracker/docs/icon-candidates/reference-style")
let cropSize: CGFloat = 760
let cropY: CGFloat = 64
let lightX: CGFloat = 64
let darkX: CGFloat = 950
let outputSize = 1024

func loadImage(_ url: URL) -> CGImage {
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        fatalError("Could not load \(url.path)")
    }
    return image
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create destination \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Could not write \(url.path)")
    }
}

func resizedCrop(from image: CGImage, rect: CGRect) -> CGImage {
    guard let cropped = image.cropping(to: rect) else {
        fatalError("Could not crop \(rect)")
    }

    let context = CGContext(
        data: nil,
        width: outputSize,
        height: outputSize,
        bitsPerComponent: 8,
        bytesPerRow: outputSize * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.interpolationQuality = .high
    context.draw(cropped, in: CGRect(x: 0, y: 0, width: outputSize, height: outputSize))
    guard let output = context.makeImage() else {
        fatalError("Could not create output")
    }
    return output
}

for variant in ["wave", "cassette", "headphones"] {
    let image = loadImage(directory.appendingPathComponent("\(variant)-sheet.png"))
    let light = resizedCrop(from: image, rect: CGRect(x: lightX, y: cropY, width: cropSize, height: cropSize))
    let dark = resizedCrop(from: image, rect: CGRect(x: darkX, y: cropY, width: cropSize, height: cropSize))
    writePNG(light, to: directory.appendingPathComponent("\(variant)-light-1024.png"))
    writePNG(dark, to: directory.appendingPathComponent("\(variant)-dark-1024.png"))
}
