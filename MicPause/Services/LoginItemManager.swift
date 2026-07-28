import ServiceManagement

@MainActor
final class LoginItemManager: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var statusMessage: String?
    @Published private(set) var requiresApproval = false

    init() {
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
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
        switch SMAppService.mainApp.status {
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
}
