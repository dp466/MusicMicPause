import AppKit
import SwiftUI

struct MicPauseBrandMark: View {
    let tint: Color

    var body: some View {
        MicPauseMark(weight: 1.05)
            .foregroundStyle(tint)
    }
}

struct MicPauseAmbientBackdrop: View {
    let tint: Color

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            // Radial gradients instead of blurred circles: the same soft glow
            // without the offscreen render pass a large blur radius forces on
            // every frame of the tint animation.
            RadialGradient(
                colors: [tint.opacity(0.20), tint.opacity(0)],
                center: UnitPoint(x: 0.86, y: 0.04),
                startRadius: 0,
                endRadius: 260
            )

            RadialGradient(
                colors: [Color.blue.opacity(0.11), Color.blue.opacity(0)],
                center: UnitPoint(x: 0.10, y: 0.98),
                startRadius: 0,
                endRadius: 240
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    @ViewBuilder
    func micPauseGlass(tint: Color? = nil) -> some View {
        if #available(macOS 26.0, *) {
            glassEffect(
                .regular.tint(tint?.opacity(0.08)),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
        } else {
            background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 0.5)
            }
        }
    }
}
