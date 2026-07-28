import AppKit
import SwiftUI

@main
struct MicPauseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: appDelegate.model)
        } label: {
            Image(systemName: statusSymbolName)
            .accessibilityLabel("Mic Pause")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: appDelegate.model)
        }
    }

    private var statusSymbolName: String {
        switch appDelegate.model.playbackCoordinator.state {
        case .pausedByUtility:
            "pause.circle.fill"
        case .unavailable:
            "mic.slash"
        default:
            "mic"
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var terminationInProgress = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminationInProgress else { return .terminateLater }
        terminationInProgress = true

        Task {
            await model.prepareForTermination()
            sender.reply(toApplicationShouldTerminate: true)
        }

        return .terminateLater
    }
}
