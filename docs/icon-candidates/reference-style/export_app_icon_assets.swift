import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let sourceDirectory = URL(fileURLWithPath: "/Users/christopherdieckmann/Projects/EpisodeTracker/docs/icon-candidates/reference-style")
let assetDirectory = URL(fileURLWithPath: "/Users/christopherdieckmann/Projects/EpisodeTracker/EpisodeTracker/Assets.xcassets")
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

func makeContext() -> (CGContext, UnsafeMutableRawPointer) {
    let bytesPerRow = outputSize * 4
    let data = UnsafeMutableRawPointer.allocate(byteCount: bytesPerRow * outputSize, alignment: 16)
    data.initializeMemory(as: UInt8.self, repeating: 0, count: bytesPerRow * outputSize)
    let context = CGContext(
        data: data,
        width: outputSize,
        height: outputSize,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return (context, data)
}

func flattenedIcon(named sourceName: String, background: (UInt8, UInt8, UInt8), darkBase: Bool = false) -> CGImage {
    let source = loadImage(sourceDirectory.appendingPathComponent(sourceName))
    let (context, data) = makeContext()
    defer { data.deallocate() }

    context.interpolationQuality = .high
    context.draw(source, in: CGRect(x: 0, y: 0, width: outputSize, height: outputSize))

    let pixels = data.bindMemory(to: UInt8.self, capacity: outputSize * outputSize * 4)
    for index in stride(from: 0, to: outputSize * outputSize * 4, by: 4) {
        let r = Double(pixels[index])
        let g = Double(pixels[index + 1])
        let b = Double(pixels[index + 2])
        let maxComponent = max(r, g, b)
        let minComponent = min(r, g, b)
        let saturation = maxComponent == 0 ? 0 : (maxComponent - minComponent) / maxComponent
        let brightness = maxComponent / 255

        let isNeutralLight = saturation < 0.14 && brightness > 0.42
        let isNearBlack = darkBase && brightness < 0.09 && saturation < 0.34

        if isNeutralLight || isNearBlack {
            pixels[index] = background.0
            pixels[index + 1] = background.1
            pixels[index + 2] = background.2
            pixels[index + 3] = 255
        }
    }

    guard let output = context.makeImage() else {
        fatalError("Could not flatten \(sourceName)")
    }
    return output
}

func makeRetroIcon() -> CGImage {
    let (context, data) = makeContext()
    defer { data.deallocate() }

    context.setFillColor(CGColor(red: 42 / 255, green: 158 / 255, blue: 229 / 255, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: outputSize, height: outputSize))

    let background = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: 42 / 255, green: 190 / 255, blue: 232 / 255, alpha: 1),
            CGColor(red: 43 / 255, green: 127 / 255, blue: 236 / 255, alpha: 1),
            CGColor(red: 34 / 255, green: 94 / 255, blue: 209 / 255, alpha: 1)
        ] as CFArray,
        locations: [0, 0.56, 1]
    )!
    context.drawLinearGradient(
        background,
        start: CGPoint(x: 230, y: 0),
        end: CGPoint(x: 790, y: 1024),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    context.saveGState()
    context.setBlendMode(.screen)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
    context.fillEllipse(in: CGRect(x: 92, y: 92, width: 620, height: 620))
    context.setFillColor(CGColor(red: 0.2, green: 0.62, blue: 1, alpha: 0.20))
    context.fillEllipse(in: CGRect(x: 522, y: 486, width: 430, height: 430))
    context.restoreGState()

    let mark = CGMutablePath()
    mark.move(to: CGPoint(x: 323, y: 607))
    mark.addCurve(to: CGPoint(x: 512, y: 422), control1: CGPoint(x: 332, y: 480), control2: CGPoint(x: 413, y: 422))
    mark.addCurve(to: CGPoint(x: 701, y: 607), control1: CGPoint(x: 611, y: 422), control2: CGPoint(x: 692, y: 480))
    context.addPath(mark)
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.setLineWidth(74)
    context.setLineCap(.round)
    context.strokePath()

    func drawCup(x: CGFloat) {
        let cup = CGRect(x: x, y: 344, width: 120, height: 254)
        context.addPath(CGPath(roundedRect: cup, cornerWidth: 30, cornerHeight: 30, transform: nil))
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fillPath()
    }

    drawCup(x: 256)
    drawCup(x: 648)

    guard let output = context.makeImage() else {
        fatalError("Could not create retro icon")
    }
    return output
}

func export(_ image: CGImage, to relativePath: String) {
    writePNG(image, to: assetDirectory.appendingPathComponent(relativePath))
}

let lightBackground: (UInt8, UInt8, UInt8) = (247, 248, 250)
let darkBackground: (UInt8, UInt8, UInt8) = (0, 12, 30)

let waveLight = flattenedIcon(named: "wave-light-1024.png", background: lightBackground)
let waveDark = flattenedIcon(named: "wave-dark-1024.png", background: darkBackground, darkBase: true)
let cassetteLight = flattenedIcon(named: "cassette-light-1024.png", background: lightBackground)
let cassetteDark = flattenedIcon(named: "cassette-dark-1024.png", background: darkBackground, darkBase: true)
let headphonesLight = flattenedIcon(named: "headphones-light-1024.png", background: lightBackground)
let headphonesDark = flattenedIcon(named: "headphones-dark-1024.png", background: darkBackground, darkBase: true)
let retroPreview = loadImage(assetDirectory.appendingPathComponent("AppIconRetro.appiconset/AppIconRetro-Light-1024.png"))

export(waveLight, to: "AppIcon.appiconset/AppIcon-Light-1024.png")
export(waveDark, to: "AppIcon.appiconset/AppIcon-Dark-1024.png")
export(waveLight, to: "AppIcon.appiconset/AppIcon-Tinted-1024.png")

export(cassetteLight, to: "AppIconCassette.appiconset/AppIconCassette-Light-1024.png")
export(cassetteDark, to: "AppIconCassette.appiconset/AppIconCassette-Dark-1024.png")
export(cassetteLight, to: "AppIconCassette.appiconset/AppIconCassette-Tinted-1024.png")

export(headphonesLight, to: "AppIconHeadphones.appiconset/AppIconHeadphones-Light-1024.png")
export(headphonesDark, to: "AppIconHeadphones.appiconset/AppIconHeadphones-Dark-1024.png")
export(headphonesLight, to: "AppIconHeadphones.appiconset/AppIconHeadphones-Tinted-1024.png")

export(waveLight, to: "AppIconStandardPreview.imageset/AppIconStandardPreview.png")
export(waveDark, to: "AppIconStandardPreview.imageset/AppIconStandardPreview-Dark.png")
export(retroPreview, to: "AppIconRetroPreview.imageset/AppIconRetroPreview.png")
export(loadImage(assetDirectory.appendingPathComponent("AppIconRetro.appiconset/AppIconRetro-Dark-1024.png")), to: "AppIconRetroPreview.imageset/AppIconRetroPreview-Dark.png")
export(cassetteLight, to: "AppIconCassettePreview.imageset/AppIconCassettePreview.png")
export(cassetteDark, to: "AppIconCassettePreview.imageset/AppIconCassettePreview-Dark.png")
export(headphonesLight, to: "AppIconHeadphonesPreview.imageset/AppIconHeadphonesPreview.png")
export(headphonesDark, to: "AppIconHeadphonesPreview.imageset/AppIconHeadphonesPreview-Dark.png")
