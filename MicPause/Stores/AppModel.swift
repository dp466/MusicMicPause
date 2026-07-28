import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let settings: AppSettings
    let microphoneMonitor: MicrophoneMonitor
    let playbackCoordinator: PlaybackCoordinator
    let musicController: AppleMusicController
    let loginItemManager: LoginItemManager

    @Published private(set) var automationPermission: AutomationPermissionStatus = .notDetermined
    @Published private(set) var isRequestingAutomationPermission = false
    @Published private(set) var automationPermissionMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private var isTerminating = false

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

        settings.$monitoringEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self else { return }
                playbackCoordinator.setMonitoringEnabled(enabled)
                if enabled {
                    microphoneMonitor.start()
                } else {
                    microphoneMonitor.stop()
                }
            }
            .store(in: &cancellables)

        forwardChanges(from: settings)
        forwardChanges(from: microphoneMonitor)
        forwardChanges(from: playbackCoordinator)
        forwardChanges(from: loginItemManager)

        Task { [weak self] in
            await self?.refreshAutomationPermission()
        }
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

    func prepareForTermination() async {
        guard !isTerminating else { return }
        isTerminating = true
        await playbackCoordinator.shutdown()
        microphoneMonitor.stop()
    }

    private func forwardChanges(from object: some ObservableObject) {
        object.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    private func retryPlaybackIfNeeded() async {
        guard settings.monitoringEnabled else { return }
        await playbackCoordinator.handleMicrophoneStatus(microphoneMonitor.status)
    }
}
