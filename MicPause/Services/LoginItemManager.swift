import Foundation
import Observation
import ServiceManagement

@MainActor
protocol LoginItemServicing {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

@MainActor
struct MainAppLoginItemService: LoginItemServicing {
    var status: SMAppService.Status { SMAppService.mainApp.status }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

@MainActor
@Observable
final class LoginItemManager {
    private enum Key {
        static let didConfigureLaunchAtLogin = "didConfigureLaunchAtLogin"
        static let registeredBundlePath = "registeredLoginItemBundlePath"
    }

    static var shouldEnableOnFirstLaunch: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }

    private(set) var isEnabled = false
    private(set) var statusMessage: String?
    private(set) var requiresApproval = false

    @ObservationIgnored private let service: any LoginItemServicing
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let bundlePath: String

    init(
        service: any LoginItemServicing = MainAppLoginItemService(),
        defaults: UserDefaults = .standard,
        bundleURL: URL = Bundle.main.bundleURL,
        enableOnFirstLaunch: Bool = LoginItemManager.shouldEnableOnFirstLaunch
    ) {
        self.service = service
        self.defaults = defaults
        bundlePath = bundleURL.standardizedFileURL.path
        refresh()

        if enableOnFirstLaunch && !defaults.bool(forKey: Key.didConfigureLaunchAtLogin) {
            setEnabled(true)
        } else if isEnabled || requiresApproval {
            repairRegistrationIfAppMoved()
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status != .notRegistered {
                    try service.unregister()
                }
            }
            defaults.set(true, forKey: Key.didConfigureLaunchAtLogin)
            if enabled {
                defaults.set(bundlePath, forKey: Key.registeredBundlePath)
            } else {
                defaults.removeObject(forKey: Key.registeredBundlePath)
            }
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
            Log.app.error(
                "Could not update launch at login: \(error.localizedDescription, privacy: .private)"
            )
        }
        refresh()
    }

    func refresh() {
        switch service.status {
        case .enabled:
            isEnabled = true
            requiresApproval = false
            statusMessage = nil
        case .requiresApproval:
            isEnabled = false
            requiresApproval = true
            statusMessage = "Allow Mic Pause in System Settings → General → Login Items."
        case .notRegistered, .notFound:
            isEnabled = false
            requiresApproval = false
        @unknown default:
            isEnabled = false
            requiresApproval = false
        }
    }

    private func repairRegistrationIfAppMoved() {
        guard defaults.string(forKey: Key.registeredBundlePath) != bundlePath else { return }

        do {
            try service.unregister()
            try service.register()
            defaults.set(true, forKey: Key.didConfigureLaunchAtLogin)
            defaults.set(bundlePath, forKey: Key.registeredBundlePath)
            statusMessage = nil
            Log.app.info("Repaired launch-at-login registration after the app moved")
        } catch {
            statusMessage = error.localizedDescription
            Log.app.error(
                "Could not repair launch at login: \(error.localizedDescription, privacy: .private)"
            )
        }
        refresh()
    }
}
