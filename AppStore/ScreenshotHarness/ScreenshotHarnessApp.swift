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
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class HarnessDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct CaptureOptions {
    enum Surface: String {
        case dashboard
        case settings
    }

    let surface: Surface

    static let current: CaptureOptions = {
        let arguments = ProcessInfo.processInfo.arguments
        let surface = value(after: "--surface", in: arguments)
            .flatMap(Surface.init(rawValue:)) ?? .dashboard
        return CaptureOptions(surface: surface)
    }()

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}
