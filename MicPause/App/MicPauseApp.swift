import AppKit

/// An AppKit entry point rather than a SwiftUI `App`.
///
/// Everything this app puts on screen — the status item, its panel, the
/// settings window — is presented from AppKit so that right-clicking the menu
/// bar item and opening settings both work; the SwiftUI scene types offered no
/// hook for either.
@main
enum MicPauseMain {
    @MainActor private static var delegate: AppDelegate?

    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        Self.delegate = delegate
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var statusItemController: StatusItemController?
    private var terminationInProgress = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsWindowController.shared.configure(model: model)
        statusItemController = StatusItemController(model: model)
    }

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
