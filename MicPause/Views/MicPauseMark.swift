import SwiftUI

/// The Mic Pause mark: a microphone whose capsule is cut away by two pause
/// bars.
///
/// Every surface that carries the brand draws these two shapes — the in-app
/// header, the menu-bar template image, and the app icon — so the mark stays
/// identical at 16 pt and at 1024 pt. `weight` thickens the thin elements for
/// small renditions without changing the silhouette.
struct MicPauseMark: View {
    var weight: CGFloat = 1

    var body: some View {
        ZStack {
            MicPauseMarkCapsule(weight: weight)
                .fill(style: FillStyle(eoFill: true))
            MicPauseMarkStand(weight: weight)
                .fill()
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The microphone capsule with the two pause bars punched out of it.
///
/// Fill this with `FillStyle(eoFill: true)` so the bars read as cutouts.
struct MicPauseMarkCapsule: Shape {
    var weight: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        let grid = MarkGrid(rect: rect)
        var path = Path()
        path.addCapsule(grid.rect(MarkGeometry.capsule))

        let barWidth = MarkGeometry.barWidth * weight
        let span = barWidth * 2 + MarkGeometry.barGap
        for index in 0..<2 {
            let originX = 0.5 - span / 2 + CGFloat(index) * (barWidth + MarkGeometry.barGap)
            let bar = grid.rect(
                CGRect(
                    x: originX,
                    y: MarkGeometry.barCenter - MarkGeometry.barHeight / 2,
                    width: barWidth,
                    height: MarkGeometry.barHeight
                )
            )
            // Softened rectangles rather than pills: full rounding turns the
            // pair into a pair of eyes above the cradle.
            let radius = bar.width * MarkGeometry.barCornerFraction
            path.addRoundedRect(
                in: bar,
                cornerSize: CGSize(width: radius, height: radius),
                style: .continuous
            )
        }
        return path
    }
}

/// The cradle, stem, and base the capsule sits in.
struct MicPauseMarkStand: Shape {
    var weight: CGFloat = 1

    func path(in rect: CGRect) -> Path {
        let grid = MarkGrid(rect: rect)
        let thickness = MarkGeometry.stroke * weight
        var path = Path()

        var cradle = Path()
        cradle.addArc(
            center: grid.point(MarkGeometry.cradleCenter),
            radius: grid.length(MarkGeometry.cradleRadius),
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addPath(
            cradle.strokedPath(
                StrokeStyle(lineWidth: grid.length(thickness), lineCap: .round)
            )
        )

        path.addCapsule(
            grid.rect(
                CGRect(
                    x: 0.5 - thickness / 2,
                    y: MarkGeometry.stemTop,
                    width: thickness,
                    height: MarkGeometry.stemBottom - MarkGeometry.stemTop
                )
            )
        )

        path.addCapsule(
            grid.rect(
                CGRect(
                    x: MarkGeometry.baseInset,
                    y: MarkGeometry.baseCenter - thickness / 2,
                    width: 1 - MarkGeometry.baseInset * 2,
                    height: thickness
                )
            )
        )

        return path
    }
}

/// Normalized mark geometry, expressed in a 1 × 1 square whose origin is the
/// top-left corner.
private enum MarkGeometry {
    static let capsule = CGRect(x: 0.320, y: 0.060, width: 0.360, height: 0.510)
    static let barWidth: CGFloat = 0.078
    static let barHeight: CGFloat = 0.290
    static let barGap: CGFloat = 0.050
    static let barCenter: CGFloat = 0.315
    static let barCornerFraction: CGFloat = 0.30
    static let stroke: CGFloat = 0.088
    static let cradleCenter = CGPoint(x: 0.500, y: 0.445)
    static let cradleRadius: CGFloat = 0.258
    static let stemTop: CGFloat = 0.690
    static let stemBottom: CGFloat = 0.890
    static let baseInset: CGFloat = 0.325
    static let baseCenter: CGFloat = 0.900
}

/// Maps the normalized mark geometry onto the largest centered square of a
/// drawing rectangle.
private struct MarkGrid {
    private let side: CGFloat
    private let origin: CGPoint

    init(rect: CGRect) {
        side = min(rect.width, rect.height)
        origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
    }

    func length(_ value: CGFloat) -> CGFloat { value * side }

    func point(_ point: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + point.x * side, y: origin.y + point.y * side)
    }

    func rect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: origin.x + rect.minX * side,
            y: origin.y + rect.minY * side,
            width: rect.width * side,
            height: rect.height * side
        )
    }
}

private extension Path {
    /// Adds a rectangle rounded by half of its shorter side.
    mutating func addCapsule(_ rect: CGRect) {
        let radius = min(rect.width, rect.height) / 2
        addRoundedRect(
            in: rect,
            cornerSize: CGSize(width: radius, height: radius),
            style: .circular
        )
    }
}
