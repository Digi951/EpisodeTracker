import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputDirectory = URL(fileURLWithPath: "/Users/christopherdieckmann/Projects/EpisodeTracker/docs/icon-candidates")
let size = 1024

struct RGB {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat

    var color: CGColor {
        CGColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
    }
}

let spectrum: [RGB] = [
    RGB(r: 255, g: 136, b: 8, a: 1),
    RGB(r: 255, g: 66, b: 75, a: 1),
    RGB(r: 243, g: 55, b: 157, a: 1),
    RGB(r: 160, g: 73, b: 235, a: 1),
    RGB(r: 57, g: 109, b: 245, a: 1),
    RGB(r: 20, g: 210, b: 225, a: 1),
]

func interpolate(_ colors: [RGB], at t: CGFloat) -> RGB {
    let clamped = max(0, min(1, t))
    let position = clamped * CGFloat(colors.count - 1)
    let lower = Int(floor(position))
    let upper = min(colors.count - 1, lower + 1)
    let amount = position - CGFloat(lower)
    let a = colors[lower]
    let b = colors[upper]
    return RGB(
        r: a.r + (b.r - a.r) * amount,
        g: a.g + (b.g - a.g) * amount,
        b: a.b + (b.b - a.b) * amount,
        a: a.a + (b.a - a.a) * amount
    )
}

func drawBackground(context: CGContext, mode: String) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    switch mode {
    case "dark":
        context.setFillColor(RGB(r: 0, g: 11, b: 28, a: 1).color)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                RGB(r: 8, g: 28, b: 58, a: 1).color,
                RGB(r: 0, g: 12, b: 29, a: 1).color
            ] as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 260, y: 0),
            end: CGPoint(x: 760, y: 1024),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    default:
        context.setFillColor(RGB(r: 242, g: 245, b: 249, a: 1).color)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                RGB(r: 255, g: 255, b: 255, a: 1).color,
                RGB(r: 242, g: 245, b: 249, a: 1).color
            ] as CFArray,
            locations: [0, 1]
        )!
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 320, y: 0),
            end: CGPoint(x: 704, y: 1024),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }
}

func gradientForMode(_ mode: String) -> [CGColor] {
    if mode == "tinted" {
        return [
            RGB(r: 105, g: 111, b: 116, a: 1).color,
            RGB(r: 184, g: 188, b: 190, a: 1).color,
            RGB(r: 105, g: 111, b: 116, a: 1).color
        ]
    }
    return spectrum.map(\.color)
}

func drawStrokeGradient(context: CGContext, path: CGPath, width: CGFloat, mode: String, glow: Bool = false) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    context.saveGState()

    if glow {
        context.setShadow(offset: .zero, blur: 44, color: RGB(r: 248, g: 68, b: 164, a: 0.36).color)
    }

    context.addPath(path)
    context.setLineWidth(width)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.replacePathWithStrokedPath()
    context.clip()

    let colors = gradientForMode(mode)
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: nil)!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 196, y: 512),
        end: CGPoint(x: 828, y: 512),
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    context.restoreGState()
}

func drawRoundedGradientRect(context: CGContext, rect: CGRect, radius: CGFloat, color: RGB, shadow: Bool) {
    context.saveGState()
    if shadow {
        context.setShadow(offset: .zero, blur: 38, color: color.color.copy(alpha: 0.28))
    }
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip()

    let top = RGB(r: min(255, color.r + 42), g: min(255, color.g + 32), b: min(255, color.b + 34), a: color.a)
    let bottom = RGB(r: max(0, color.r - 18), g: max(0, color.g - 12), b: max(0, color.b - 6), a: color.a)
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [top.color, color.color, bottom.color] as CFArray,
        locations: [0, 0.5, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: rect.midX, y: rect.minY),
        end: CGPoint(x: rect.midX, y: rect.maxY),
        options: []
    )

    context.restoreGState()
}

func drawWave(context: CGContext, mode: String, centerY: CGFloat, scale: CGFloat) {
    let widths = [24, 29, 22, 32, 25, 30, 27, 35, 24, 29, 23, 33, 26, 35, 25].map { CGFloat($0) * scale }
    let gaps = [24, 18, 31, 20, 26, 21, 29, 18, 32, 22, 27, 20, 30, 24].map { CGFloat($0) * scale }
    let heights = [96, 158, 112, 276, 446, 206, 350, 594, 404, 532, 284, 364, 226, 426, 128].map { CGFloat($0) * scale }
    let verticalOffsets = [16, -13, 23, -7, 28, -22, 11, 0, 21, -15, 26, -10, 18, -25, -5].map { CGFloat($0) * scale }
    let count = heights.count
    let totalWidth = widths.reduce(0, +) + gaps.reduce(0, +)
    var x = (CGFloat(size) - totalWidth) / 2

    if mode == "dark" {
        context.saveGState()
        context.setBlendMode(.screen)
        context.setFillColor(RGB(r: 101, g: 42, b: 148, a: 0.22).color)
        context.fillEllipse(in: CGRect(x: 238, y: 282, width: 548, height: 452))
        context.restoreGState()
    }

    for index in 0..<count {
        let width = widths[index]
        let height = heights[index]
        let rect = CGRect(x: x, y: centerY + verticalOffsets[index] - height / 2, width: width, height: height)
        let t = CGFloat(index) / CGFloat(count - 1)
        let color: RGB

        if mode == "tinted" {
            let tone = 92 + 105 * (1 - abs(t - 0.5) * 1.5)
            color = RGB(r: tone, g: tone, b: tone, a: 1)
        } else {
            color = interpolate(spectrum, at: t)
        }

        drawRoundedGradientRect(context: context, rect: rect, radius: min(18 * scale, width / 2), color: color, shadow: mode == "dark")
        x += width
        if index < gaps.count {
            x += gaps[index]
        }
    }
}

func drawCassette(context: CGContext, mode: String) {
    if mode == "dark" {
        context.saveGState()
        context.setBlendMode(.screen)
        context.setFillColor(RGB(r: 118, g: 42, b: 152, a: 0.16).color)
        context.fillEllipse(in: CGRect(x: 190, y: 330, width: 644, height: 352))
        context.restoreGState()
    }

    let shell = CGMutablePath()
    shell.move(to: CGPoint(x: 208, y: 404))
    shell.addQuadCurve(to: CGPoint(x: 272, y: 340), control: CGPoint(x: 208, y: 340))
    shell.addLine(to: CGPoint(x: 752, y: 340))
    shell.addQuadCurve(to: CGPoint(x: 816, y: 404), control: CGPoint(x: 816, y: 340))
    shell.addLine(to: CGPoint(x: 816, y: 638))
    shell.addQuadCurve(to: CGPoint(x: 752, y: 702), control: CGPoint(x: 816, y: 702))
    shell.addLine(to: CGPoint(x: 272, y: 702))
    shell.addQuadCurve(to: CGPoint(x: 208, y: 638), control: CGPoint(x: 208, y: 702))
    shell.closeSubpath()
    drawStrokeGradient(context: context, path: shell, width: 36, mode: mode, glow: mode == "dark")

    let lowerWindow = CGMutablePath()
    lowerWindow.move(to: CGPoint(x: 340, y: 336))
    lowerWindow.addLine(to: CGPoint(x: 372, y: 416))
    lowerWindow.addQuadCurve(to: CGPoint(x: 418, y: 438), control: CGPoint(x: 384, y: 438))
    lowerWindow.addLine(to: CGPoint(x: 606, y: 438))
    lowerWindow.addQuadCurve(to: CGPoint(x: 652, y: 416), control: CGPoint(x: 640, y: 438))
    lowerWindow.addLine(to: CGPoint(x: 684, y: 336))
    drawStrokeGradient(context: context, path: lowerWindow, width: 34, mode: mode, glow: mode == "dark")

    let leftReel = CGMutablePath()
    leftReel.addEllipse(in: CGRect(x: 282, y: 438, width: 116, height: 116))
    drawStrokeGradient(context: context, path: leftReel, width: 34, mode: mode, glow: mode == "dark")

    let rightReel = CGMutablePath()
    rightReel.addEllipse(in: CGRect(x: 626, y: 438, width: 116, height: 116))
    drawStrokeGradient(context: context, path: rightReel, width: 34, mode: mode, glow: mode == "dark")

    drawWave(context: context, mode: mode, centerY: 506, scale: 0.44)
}

func drawHeadphones(context: CGContext, mode: String) {
    if mode == "dark" {
        context.saveGState()
        context.setBlendMode(.screen)
        context.setFillColor(RGB(r: 105, g: 42, b: 150, a: 0.16).color)
        context.fillEllipse(in: CGRect(x: 238, y: 276, width: 548, height: 420))
        context.restoreGState()
    }

    let arch = CGMutablePath()
    arch.move(to: CGPoint(x: 202, y: 470))
    arch.addCurve(to: CGPoint(x: 512, y: 724), control1: CGPoint(x: 202, y: 646), control2: CGPoint(x: 342, y: 724))
    arch.addCurve(to: CGPoint(x: 822, y: 470), control1: CGPoint(x: 682, y: 724), control2: CGPoint(x: 822, y: 646))
    drawStrokeGradient(context: context, path: arch, width: 42, mode: mode, glow: mode == "dark")

    let leftCupOuter = CGMutablePath()
    leftCupOuter.move(to: CGPoint(x: 198, y: 570))
    leftCupOuter.addLine(to: CGPoint(x: 198, y: 454))
    drawStrokeGradient(context: context, path: leftCupOuter, width: 78, mode: mode, glow: mode == "dark")

    let leftCupInner = CGMutablePath()
    leftCupInner.move(to: CGPoint(x: 270, y: 592))
    leftCupInner.addLine(to: CGPoint(x: 270, y: 402))
    drawStrokeGradient(context: context, path: leftCupInner, width: 72, mode: mode, glow: mode == "dark")

    let rightCupInner = CGMutablePath()
    rightCupInner.move(to: CGPoint(x: 754, y: 592))
    rightCupInner.addLine(to: CGPoint(x: 754, y: 402))
    drawStrokeGradient(context: context, path: rightCupInner, width: 72, mode: mode, glow: mode == "dark")

    let rightCupOuter = CGMutablePath()
    rightCupOuter.move(to: CGPoint(x: 826, y: 570))
    rightCupOuter.addLine(to: CGPoint(x: 826, y: 454))
    drawStrokeGradient(context: context, path: rightCupOuter, width: 78, mode: mode, glow: mode == "dark")

    drawWave(context: context, mode: mode, centerY: 610, scale: 0.56)
}

func drawIcon(variant: String, mode: String, filename: String) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    drawBackground(context: context, mode: mode)

    switch variant {
    case "cassette":
        drawCassette(context: context, mode: mode)
    case "headphones":
        drawHeadphones(context: context, mode: mode)
    default:
        drawWave(context: context, mode: mode, centerY: 512, scale: 1)
    }

    guard let image = context.makeImage() else {
        fatalError("Could not create image")
    }

    let destinationURL = outputDirectory.appendingPathComponent(filename)
    guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Could not write \(destinationURL.path)")
    }
}

func drawLabel(_ text: String, at point: CGPoint) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 30, weight: .semibold),
        .foregroundColor: NSColor(calibratedRed: 67 / 255, green: 76 / 255, blue: 92 / 255, alpha: 1),
        .kern: 0.8
    ]
    text.draw(at: point, withAttributes: attributes)
}

func drawContactSheet() {
    let canvasWidth = 1260
    let canvasHeight = 1480
    let thumbSize: CGFloat = 300
    let margin: CGFloat = 96
    let columnGap: CGFloat = 90
    let rowGap: CGFloat = 138
    let labelHeight: CGFloat = 48
    let context = CGContext(
        data: nil,
        width: canvasWidth,
        height: canvasHeight,
        bitsPerComponent: 8,
        bytesPerRow: canvasWidth * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    context.setFillColor(RGB(r: 246, g: 248, b: 251, a: 1).color)
    context.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))

    for (row, variant) in variants.enumerated() {
        let rowY = margin + CGFloat(row) * (thumbSize + rowGap)
        drawLabel(variant.uppercased(), at: CGPoint(x: margin, y: rowY - 50))

        for (column, mode) in modes.enumerated() {
            let x = margin + CGFloat(column) * (thumbSize + columnGap)
            let y = rowY
            let imageURL = outputDirectory.appendingPathComponent("AppIcon-\(variant)-\(mode)-1024.png")
            guard
                let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
                let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                continue
            }

            context.saveGState()
            context.setShadow(offset: CGSize(width: 0, height: 16), blur: 38, color: RGB(r: 26, g: 36, b: 56, a: 0.12).color)
            context.draw(image, in: CGRect(x: x, y: y + labelHeight, width: thumbSize, height: thumbSize))
            context.restoreGState()
            drawLabel(mode.capitalized, at: CGPoint(x: x, y: y + thumbSize + labelHeight + 16))
        }
    }

    guard let image = context.makeImage() else {
        fatalError("Could not create contact sheet")
    }
    let destinationURL = outputDirectory.appendingPathComponent("AppIcon-candidates-contact-sheet.png")
    guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create contact sheet destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Could not write contact sheet")
    }
}

let variants = ["wave", "cassette", "headphones"]
let modes = ["light", "dark", "tinted"]

for variant in variants {
    for mode in modes {
        drawIcon(variant: variant, mode: mode, filename: "AppIcon-\(variant)-\(mode)-1024.png")
    }
}

drawContactSheet()
