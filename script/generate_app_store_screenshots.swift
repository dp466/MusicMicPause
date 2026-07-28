#!/usr/bin/env swift

import AppKit
import Foundation

private let canvasSize = NSSize(width: 2560, height: 1600)
private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let sourceDirectory = root.appendingPathComponent("AppStore/Screenshots/Source")
private let outputDirectory = root.appendingPathComponent("AppStore/Screenshots/Final")

private struct ScreenshotDefinition {
    let filename: String
    let eyebrow: String
    let headline: String
    let detail: String
    let badges: [String]
    let sourceName: String
    let windowFrame: NSRect
    let sourceCrop: NSRect?
}

private let screenshots = [
    ScreenshotDefinition(
        filename: "01-Automatic-Pause.jpg",
        eyebrow: "EFFORTLESS AUTOMATION",
        headline: "Music pauses\nwhen your mic\nturns on.",
        detail: "Stay focused on the conversation—not your playback controls.",
        badges: ["APPLE MUSIC", "MENU BAR"],
        sourceName: "Dashboard-Window.jpg",
        windowFrame: NSRect(x: 1590, y: 155, width: 790, height: 1151),
        sourceCrop: nil
    ),
    ScreenshotDefinition(
        filename: "02-Playback-Your-Way.jpg",
        eyebrow: "MADE FOR YOUR WORKFLOW",
        headline: "Playback,\nexactly your way.",
        detail: "Choose automatic resume and the delay that feels natural.",
        badges: ["RESUME DELAY", "LAUNCH AT LOGIN"],
        sourceName: "Settings-Window.jpg",
        windowFrame: NSRect(x: 1270, y: 280, width: 1160, height: 964),
        sourceCrop: NSRect(x: 0, y: 197, width: 620, height: 515)
    ),
    ScreenshotDefinition(
        filename: "03-Private-By-Design.jpg",
        eyebrow: "PRIVATE BY DESIGN",
        headline: "Listens for\nactivity.\nNever audio.",
        detail: "No recording, analytics, accounts, advertising, or network access.",
        badges: ["NO RECORDING", "NO TRACKING"],
        sourceName: "Settings-Privacy-Window.jpg",
        windowFrame: NSRect(x: 1375, y: 155, width: 1060, height: 1218),
        sourceCrop: nil
    ),
]

private func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

private let mint = color(35, 231, 211)
private let foreground = color(244, 250, 249)
private let secondary = color(190, 207, 204)

private func drawText(
    _ string: String,
    in rect: NSRect,
    font: NSFont,
    color: NSColor,
    lineHeight: CGFloat? = nil,
    tracking: CGFloat = 0
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byWordWrapping
    if let lineHeight {
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
    }

    let attributed = NSAttributedString(
        string: string,
        attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
            .kern: tracking,
        ]
    )
    attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

private func drawBackground() {
    let canvas = NSRect(origin: .zero, size: canvasSize)
    NSGradient(
        colors: [
            color(11, 25, 27),
            color(15, 48, 44),
            color(17, 35, 39),
        ],
        atLocations: [0, 0.55, 1],
        colorSpace: .deviceRGB
    )?.draw(in: canvas, angle: -18)

    color(36, 228, 206, 0.08).setFill()
    NSBezierPath(ovalIn: NSRect(x: 1670, y: 940, width: 1040, height: 900)).fill()

    color(83, 125, 255, 0.07).setFill()
    NSBezierPath(ovalIn: NSRect(x: 1120, y: -430, width: 1160, height: 990)).fill()

    color(255, 255, 255, 0.035).setStroke()
    let line = NSBezierPath()
    line.move(to: NSPoint(x: 145, y: 113))
    line.line(to: NSPoint(x: 2415, y: 113))
    line.lineWidth = 1
    line.stroke()
}

private func drawBrand() {
    let iconURL = root.appendingPathComponent("AppStore/AppIconSource.png")
    if let icon = NSImage(contentsOf: iconURL) {
        let frame = NSRect(x: 150, y: 1350, width: 94, height: 94)
        icon.draw(in: frame, from: .zero, operation: .sourceOver, fraction: 1)
    }

    drawText(
        "MIC PAUSE",
        in: NSRect(x: 270, y: 1372, width: 470, height: 48),
        font: .systemFont(ofSize: 34, weight: .bold),
        color: foreground,
        tracking: 3.4
    )
}

private func drawBadges(_ labels: [String]) {
    var x: CGFloat = 150
    for label in labels {
        let width = CGFloat(label.count) * 16 + 54
        let frame = NSRect(x: x, y: 155, width: width, height: 54)
        color(255, 255, 255, 0.075).setFill()
        NSBezierPath(roundedRect: frame, xRadius: 27, yRadius: 27).fill()
        color(255, 255, 255, 0.10).setStroke()
        let border = NSBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), xRadius: 27, yRadius: 27)
        border.lineWidth = 1
        border.stroke()
        drawText(
            label,
            in: NSRect(x: frame.minX + 27, y: frame.minY + 15, width: frame.width - 54, height: 27),
            font: .systemFont(ofSize: 19, weight: .semibold),
            color: secondary,
            tracking: 1.4
        )
        x = frame.maxX + 18
    }
}

private func drawWindow(
    image: NSImage,
    frame: NSRect,
    crop: NSRect?
) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0, 0, 0, 0.58)
    shadow.shadowBlurRadius = 68
    shadow.shadowOffset = NSSize(width: 0, height: -28)
    shadow.set()
    color(2, 8, 9, 0.92).setFill()
    NSBezierPath(roundedRect: frame, xRadius: 34, yRadius: 34).fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: frame, xRadius: 34, yRadius: 34).addClip()
    let sourceRect = crop ?? NSRect(origin: .zero, size: image.size)
    image.draw(
        in: frame,
        from: sourceRect,
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()

    color(255, 255, 255, 0.16).setStroke()
    let border = NSBezierPath(
        roundedRect: frame.insetBy(dx: 0.5, dy: 0.5),
        xRadius: 34,
        yRadius: 34
    )
    border.lineWidth = 1
    border.stroke()
}

private func render(_ definition: ScreenshotDefinition) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width),
        pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "MicPauseScreenshots", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.shouldAntialias = true

    drawBackground()
    drawBrand()
    drawText(
        definition.eyebrow,
        in: NSRect(x: 150, y: 1235, width: 980, height: 42),
        font: .systemFont(ofSize: 25, weight: .semibold),
        color: mint,
        tracking: 3
    )
    drawText(
        definition.headline,
        in: NSRect(x: 145, y: 590, width: 1170, height: 610),
        font: .systemFont(ofSize: 104, weight: .bold),
        color: foreground,
        lineHeight: 111
    )
    drawText(
        definition.detail,
        in: NSRect(x: 150, y: 330, width: 1030, height: 175),
        font: .systemFont(ofSize: 39, weight: .regular),
        color: secondary,
        lineHeight: 52
    )
    drawBadges(definition.badges)

    let sourceURL = sourceDirectory.appendingPathComponent(definition.sourceName)
    guard let sourceImage = NSImage(contentsOf: sourceURL) else {
        throw NSError(
            domain: "MicPauseScreenshots",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Missing source image: \(sourceURL.path)"]
        )
    }
    drawWindow(image: sourceImage, frame: definition.windowFrame, crop: definition.sourceCrop)

    NSGraphicsContext.restoreGraphicsState()

    guard let jpeg = bitmap.representation(
        using: .jpeg,
        properties: [.compressionFactor: 0.96]
    ) else {
        throw NSError(domain: "MicPauseScreenshots", code: 3)
    }
    try jpeg.write(to: outputDirectory.appendingPathComponent(definition.filename), options: .atomic)
}

try FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)

for screenshot in screenshots {
    try render(screenshot)
    print("Created AppStore/Screenshots/Final/\(screenshot.filename)")
}
