import AppKit
import SwiftUI

struct MicPauseBrandMark: View {
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)

            ZStack {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .offset(x: size * 0.18, y: -size * 0.16)
                    .opacity(0.62)

                Image(systemName: "mic.fill")
                    .font(.system(size: size * 0.56, weight: .semibold))
                    .offset(x: -size * 0.08, y: size * 0.06)
            }
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(tint)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

struct MicPauseAmbientBackdrop: View {
    let tint: Color

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: 190, y: -250)

            Circle()
                .fill(Color.blue.opacity(0.09))
                .frame(width: 260, height: 260)
                .blur(radius: 95)
                .offset(x: -210, y: 280)
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
