import AppKit
import SwiftUI

/// Owns the settings window.
///
/// SwiftUI's `Settings` scene never produced a window in this app: the action
/// was accepted by a responder but nothing appeared, which is a known dead end
/// for `LSUIElement` apps driven from a status item. Hosting the view in a
/// window the app controls makes opening it deterministic.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var model: AppModel?
    private var window: NSWindow?

    func configure(model: AppModel) {
        self.model = model
    }

    func show() {
        guard let model else {
            Log.app.error("Settings requested before the model was ready")
            return
        }

        let window = window ?? makeWindow(model: model)
        self.window = window

        // Accessory apps are never frontmost on their own, so ordering the
        // window front without activating would leave it behind everything.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)

        Task { await model.refreshVisibleState() }
    }

    private func makeWindow(model: AppModel) -> NSWindow {
        let window = NSWindow(
            contentViewController: NSHostingController(
                rootView: SettingsView(model: model)
            )
        )
        window.title = "Mic Pause Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }
}
