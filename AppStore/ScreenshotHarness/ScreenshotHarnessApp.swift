import AppKit
import SwiftUI

@main
struct ScreenshotHarnessApp: App {
    @NSApplicationDelegateAdaptor(HarnessDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Mic Pause") {
            Group {
                if CaptureOptions.current.surface == .settings {
                    SettingsView(model: appDelegate.model)
                } else {
                    MenuBarView(model: appDelegate.model)
                }
            }
            .preferredColorScheme(.dark)
            .environment(\.controlActiveState, .active)
            .frame(width: CaptureOptions.current.baseWidth, height: CaptureOptions.current.baseHeight, alignment: .top)
            .clipped()
            .scaleEffect(CaptureOptions.current.scale)
            .frame(
                width: CaptureOptions.current.width,
                height: CaptureOptions.current.height
            )
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class HarnessDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel(loginItemManager: LoginItemManager(enableOnFirstLaunch: false))

    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsWindowController.shared.configure(model: model)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if CaptureOptions.current.readme {
            DispatchQueue.main.async {
                for window in NSApp.windows where window.title == "Mic Pause" {
                    window.styleMask = [.borderless]
                    window.setContentSize(NSSize(width: CaptureOptions.current.width, height: CaptureOptions.current.height))
                    window.center()
                }
            }
        }
    }
}

private struct CaptureOptions {
    enum Surface: String {
        case dashboard
        case settings
    }

    let surface: Surface
    let readme: Bool
    // Focus README captures on the primary controls and keep the enlarged
    // window within a laptop display. The app views themselves are unchanged.
    var baseWidth: CGFloat { surface == .settings ? 620 : 420 }
    var baseHeight: CGFloat { readme ? (surface == .settings ? 500 : 510) : (surface == .settings ? 680 : 580) }
    var scale: CGFloat { readme ? 1.5 : 1 }
    var width: CGFloat { baseWidth * scale }
    var height: CGFloat { baseHeight * scale }

    static let current: CaptureOptions = {
        let arguments = ProcessInfo.processInfo.arguments
        let surface = value(after: "--surface", in: arguments)
            .flatMap(Surface.init(rawValue:)) ?? .dashboard
        return CaptureOptions(surface: surface, readme: arguments.contains("--readme"))
    }()

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
