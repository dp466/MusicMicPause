import AppKit
import Observation
import SwiftUI

/// Owns the menu-bar item.
///
/// `MenuBarExtra` cannot distinguish a right-click from a left-click, and an
/// accessory app cannot reliably bring a SwiftUI `Settings` scene forward from
/// inside it. Managing `NSStatusItem` directly solves both: left-click opens the
/// panel, right-click opens a menu.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()

    private let idleImage = StatusItemController.templateImage(named: "MenuBarIcon")
    private let pausedImage = StatusItemController.templateImage(named: "MenuBarIconPaused")

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configureButton()
        configurePopover()
        observeState()
    }

    private static func templateImage(named name: String) -> NSImage? {
        guard let image = NSImage(named: name) else { return nil }
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }

        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        applyState()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        let hosting = NSHostingController(rootView: MenuBarView(model: model))
        hosting.preferredContentSize = MenuBarPanel.size
        popover.contentViewController = hosting

        // Must be set before the first show, or the popover anchors using its
        // default size and ends up hanging off the screen.
        popover.contentSize = MenuBarPanel.size
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true

        if isSecondary {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        // An accessory app is not frontmost, so the panel would open without
        // keyboard focus.
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func showMenu() {
        if popover.isShown {
            popover.performClose(nil)
        }

        let menu = NSMenu()

        let monitoring = NSMenuItem(
            title: model.monitoringEnabled ? "Pause Monitoring" : "Start Monitoring",
            action: #selector(toggleMonitoring),
            keyEquivalent: ""
        )
        monitoring.target = self
        menu.addItem(monitoring)

        menu.addItem(.separator())

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Mic Pause",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        // Attaching the menu makes the button draw its highlighted state and
        // positions the menu under the item; it is detached immediately after
        // so left-clicks keep opening the panel.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleMonitoring() {
        model.setMonitoringEnabled(!model.monitoringEnabled)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    /// Mirrors the coordinator's state onto the menu-bar item.
    private func applyState() {
        guard let button = statusItem.button else { return }

        let state = model.playbackCoordinator.state
        let isPaused = state == .pausedByUtility
        button.image = (isPaused ? pausedImage : idleImage) ?? idleImage
        button.setAccessibilityLabel("Mic Pause: \(state.label)")
    }

    /// Observation fires once per change, so tracking is re-armed each time.
    private func observeState() {
        withObservationTracking {
            _ = model.playbackCoordinator.state
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.applyState()
                self?.observeState()
            }
        }
    }
}
