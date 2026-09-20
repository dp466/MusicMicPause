import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    @ObservationIgnored let settings: AppSettings
    @ObservationIgnored let microphoneMonitor: MicrophoneMonitor
    @ObservationIgnored let playbackCoordinator: PlaybackCoordinator
    @ObservationIgnored let musicController: AppleMusicController
    @ObservationIgnored let loginItemManager: LoginItemManager

    private(set) var automationPermission: AutomationPermissionStatus = .notDetermined
    private(set) var isRequestingAutomationPermission = false
    private(set) var automationPermissionMessage: String?

    @ObservationIgnored private var isTerminating = false

    init(
        settings: AppSettings = AppSettings(),
        microphoneMonitor: MicrophoneMonitor = MicrophoneMonitor(),
        musicController: AppleMusicController = AppleMusicController(),
        loginItemManager: LoginItemManager = LoginItemManager()
    ) {
        self.settings = settings
        self.microphoneMonitor = microphoneMonitor
        self.musicController = musicController
        self.loginItemManager = loginItemManager
        playbackCoordinator = PlaybackCoordinator(
            player: musicController,
            resumePolicy: {
                (settings.automaticResume, settings.resumeDelay.duration)
            }
        )

        microphoneMonitor.onStatusChange = { [weak self] status in
            Task { @MainActor [weak self] in
                await self?.playbackCoordinator.handleMicrophoneStatus(status)
            }
        }

        microphoneMonitor.shouldIgnoreSource = { [weak self] source in
            self?.settings.ignores(source) ?? false
        }

        settings.onMonitoringEnabledChange = { [weak self] enabled in
            self?.applyMonitoringPreference(enabled)
        }

        applyMonitoringPreference(settings.monitoringEnabled)

        Task { [weak self] in
            await self?.refreshAutomationPermission()
        }
    }

    var monitoringEnabled: Bool { settings.monitoringEnabled }

    func ignoreCaptureSource(_ source: CaptureSource) {
        settings.ignore(source)
        microphoneMonitor.reevaluate()
    }

    func stopIgnoringCaptureSource(_ identifier: String) {
        settings.stopIgnoring(identifier)
        microphoneMonitor.reevaluate()
    }

    func setIgnoreAlwaysOnSystemListeners(_ ignore: Bool) {
        settings.ignoreAlwaysOnSystemListeners = ignore
        microphoneMonitor.reevaluate()
    }

    func setMonitoringEnabled(_ enabled: Bool) {
        settings.monitoringEnabled = enabled
    }

    func requestAutomationPermission() async {
        guard !isRequestingAutomationPermission else { return }
        isRequestingAutomationPermission = true
        defer { isRequestingAutomationPermission = false }

        automationPermission = await musicController.requestAutomationPermission()
        switch automationPermission {
        case .granted:
            automationPermissionMessage = "Mic Pause can control Apple Music."
            await retryPlaybackIfNeeded()
        case .denied:
            automationPermissionMessage = "Permission was previously denied. Enable Mic Pause in System Settings → Privacy & Security → Automation."
        case .notDetermined:
            automationPermissionMessage = "macOS did not complete the permission request. Make sure Apple Music is installed, then try again."
        case .unavailable(let reason):
            automationPermissionMessage = reason
        }
        Log.app.info("Automation permission request result: \(self.automationPermission.label, privacy: .public)")
    }

    func refreshAutomationPermission() async {
        automationPermission = await musicController.automationPermissionStatus()
        if automationPermission == .granted {
            await retryPlaybackIfNeeded()
        }
    }

    /// Brings everything a visible window shows back up to date in one call.
    func refreshVisibleState() async {
        loginItemManager.refresh()
        await playbackCoordinator.reconcilePlayerState()
        await refreshAutomationPermission()
    }

    func prepareForTermination() async {
        guard !isTerminating else { return }
        isTerminating = true
        await playbackCoordinator.shutdown()
        microphoneMonitor.stop()
    }

    private func applyMonitoringPreference(_ enabled: Bool) {
        playbackCoordinator.setMonitoringEnabled(enabled)
        if enabled {
            microphoneMonitor.start()
        } else {
            microphoneMonitor.stop()
        }
    }

    private func retryPlaybackIfNeeded() async {
        guard settings.monitoringEnabled else { return }
        await playbackCoordinator.handleMicrophoneStatus(microphoneMonitor.status)
    }
}
