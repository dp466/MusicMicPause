// Renders every Mic Pause icon rendition from the shared mark geometry in
// MicPause/Views/MicPauseMark.swift, so the app icon, the menu-bar template,
// and the in-app brand mark can never drift apart.
//
//   ./script/generate_app_icon.sh
//
// Colors follow the app's own palette: the mint the interface uses while
// monitoring, falling to the deep blue of the ambient backdrop.

import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct IconGenerator {
    @MainActor
    static func main() {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let appIconSet = root.appending(
            path: "MicPause/Assets.xcassets/AppIcon.appiconset"
        )
        let menuBarSet = root.appending(
            path: "MicPause/Assets.xcassets/MenuBarIcon.imageset"
        )
        let menuBarPausedSet = root.appending(
            path: "MicPause/Assets.xcassets/MenuBarIconPaused.imageset"
        )

        guard FileManager.default.fileExists(atPath: appIconSet.path) else {
            FileHandle.standardError.write(
                Data("Run this from the repository root.\n".utf8)
            )
            exit(2)
        }

        for rendition in AppIconRendition.all {
            write(
                AppIconView(pixels: CGFloat(rendition.pixels)),
                pixels: rendition.pixels,
                to: appIconSet.appending(path: rendition.filename)
            )
        }

        for scale in 1...2 {
            let points = MenuBarIconView.canvas
            let suffix = scale == 1 ? "" : "@2x"
            write(
                MenuBarIconView(),
                points: points,
                pixels: Int(points) * scale,
                to: menuBarSet.appending(
                    path: "MenuBarIconTemplate\(suffix).png"
                )
            )
            write(
                MenuBarIconView(paused: true),
                points: points,
                pixels: Int(points) * scale,
                to: menuBarPausedSet.appending(
                    path: "MenuBarIconPausedTemplate\(suffix).png"
                )
            )
        }

        var extras = [root.appending(path: "AppStore/AppIconSource.png")]

        // The site reuses the app icon as its favicon and header mark.
        let websitePublic = root.appending(path: "website/public")
        if FileManager.default.fileExists(atPath: websitePublic.path) {
            extras.append(websitePublic.appending(path: "app-icon.png"))
        }

        for url in extras {
            write(AppIconView(pixels: 1024), pixels: 1024, to: url)
        }

        write(
            MenuBarIconView(),
            points: MenuBarIconView.canvas,
            pixels: 1024,
            to: root.appending(path: "AppStore/MenuBarIconSource.png")
        )

        print("Wrote \(AppIconRendition.all.count + extras.count + 5) icon renditions.")
    }

    /// Renders `content` laid out at `points` and supersampled down to
    /// `pixels`, which keeps the small renditions from going ragged.
    @MainActor
    private static func write(
        _ content: some View,
        points: CGFloat? = nil,
        pixels: Int,
        to url: URL
    ) {
        let side = points ?? CGFloat(pixels)
        let renderer = ImageRenderer(
            content: content.frame(width: side, height: side)
        )
        renderer.scale = max(1, CGFloat(pixels) * 4 / side)
        renderer.isOpaque = false

        guard let rendered = renderer.cgImage,
              let scaled = resize(rendered, to: pixels),
              let destination = CGImageDestinationCreateWithURL(
                  url as CFURL,
                  UTType.png.identifier as CFString,
                  1,
                  nil
              ) else {
            FileHandle.standardError.write(
                Data("Could not render \(url.lastPathComponent)\n".utf8)
            )
            exit(1)
        }

        CGImageDestinationAddImage(destination, scaled, nil)
        CGImageDestinationFinalize(destination)
    }

    private static func resize(_ image: CGImage, to pixels: Int) -> CGImage? {
        guard image.width != pixels else { return image }
        guard let context = CGContext(
            data: nil,
            width: pixels,
            height: pixels,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: pixels, height: pixels)
        )
        return context.makeImage()
    }
}

private struct AppIconRendition {
    let filename: String
    let pixels: Int

    static let all: [AppIconRendition] = [16, 32, 128, 256, 512].flatMap { points in
        [
            AppIconRendition(filename: "AppIcon-\(points).png", pixels: points),
            AppIconRendition(filename: "AppIcon-\(points)@2x.png", pixels: points * 2),
        ]
    }
}

/// The Dock and Finder icon: the mark on the app's mint-to-deep-blue gradient,
/// on the standard macOS 824-in-1024 rounded square.
private struct AppIconView: View {
    /// Drives the small-size adjustments — below 64 px the thin elements need
    /// help to survive.
    let pixels: CGFloat

    private var isSmall: Bool { pixels < 64 }
    private var tile: CGFloat { pixels * 824 / 1024 }
    private var markScale: CGFloat { isSmall ? 0.72 : 0.64 }
    private var markWeight: CGFloat { isSmall ? 1.3 : 1 }

    var body: some View {
        ZStack {
            shape
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Palette.mintLight, location: 0),
                            .init(color: Palette.teal, location: 0.48),
                            .init(color: Palette.deepBlue, location: 1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    // Light from above, the way every macOS icon is lit.
                    RadialGradient(
                        colors: [.white.opacity(0.26), .white.opacity(0)],
                        center: UnitPoint(x: 0.5, y: -0.06),
                        startRadius: 0,
                        endRadius: tile * 0.62
                    )
                    .clipShape(shape)
                }
                .overlay {
                    RadialGradient(
                        colors: [.black.opacity(0.22), .black.opacity(0)],
                        center: UnitPoint(x: 0.5, y: 1.05),
                        startRadius: 0,
                        endRadius: tile * 0.68
                    )
                    .clipShape(shape)
                }
                .overlay {
                    // The glass rim the interface uses on its cards.
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: max(0.5, tile * 0.008)
                    )
                }
                .frame(width: tile, height: tile)
                .shadow(
                    color: .black.opacity(0.24),
                    radius: tile * 0.03,
                    y: tile * 0.02
                )

            MicPauseMark(weight: markWeight)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, Palette.markShade],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: tile * markScale, height: tile * markScale)
                .shadow(
                    color: Palette.deepBlue.opacity(isSmall ? 0 : 0.3),
                    radius: tile * 0.02,
                    y: tile * 0.012
                )
        }
        .frame(width: pixels, height: pixels)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: tile * 0.225, style: .continuous)
    }
}

/// The menu-bar image. Solid black plus alpha; macOS tints the template itself.
///
/// The paused rendition inverts the mark into a solid tile. Menu-bar templates
/// are monochrome, so the "we are holding your music" signal has to come from
/// the silhouette rather than from color — and an inverted tile still reads at
/// a glance on a light or a dark menu bar.
private struct MenuBarIconView: View {
    /// The layout size of every menu-bar rendition, in points.
    static let canvas: CGFloat = 18

    var paused = false

    /// Leaves the tile a hair short of the canvas so it never touches the
    /// menu-bar item's edges.
    private static let tileInset: CGFloat = 0.5
    private static let tile = canvas - tileInset * 2
    /// Margin between the tile and the knocked-out mark.
    private static let markInset: CGFloat = 1.5
    /// Knocked-out strokes need more body than positive ones to survive the
    /// 1x rendition.
    private static let pausedWeight: CGFloat = 1.35

    var body: some View {
        if paused {
            RoundedRectangle(
                cornerRadius: Self.tile * 0.225,
                style: .continuous
            )
            .fill(.black)
            .overlay {
                MicPauseMark(weight: Self.pausedWeight)
                    .padding(Self.markInset)
                    .blendMode(.destinationOut)
            }
            .compositingGroup()
            .padding(Self.tileInset)
        } else {
            MicPauseMark(weight: 1.25)
                .foregroundStyle(.black)
                .padding(0.5)
        }
    }
}

private enum Palette {
    static let mintLight = Color(red: 0.40, green: 0.94, blue: 0.85)
    static let teal = Color(red: 0.02, green: 0.68, blue: 0.68)
    static let deepBlue = Color(red: 0.05, green: 0.25, blue: 0.47)
    static let markShade = Color(red: 0.90, green: 0.99, blue: 0.98)
}
