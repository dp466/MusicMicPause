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
    @ObservationIgnored let accessibilityAutomation: AccessibilityAutomation
    @ObservationIgnored let meetingAssistCoordinator: MeetingAssistCoordinator
    @ObservationIgnored let phoneCallMonitor: PhoneCallMonitor
    @ObservationIgnored private let feedbackSoundPlayer = FeedbackSoundPlayer()

    private(set) var automationPermission: AutomationPermissionStatus = .notDetermined
    private(set) var isRequestingAutomationPermission = false
    private(set) var automationPermissionMessage: String?

    @ObservationIgnored private var isTerminating = false
    @ObservationIgnored private var lastMicrophoneStatus: MicrophoneStatus = .unavailable(
        "Monitoring unavailable"
    )

    init(
        settings: AppSettings = AppSettings(),
        microphoneMonitor: MicrophoneMonitor = MicrophoneMonitor(),
        musicController: AppleMusicController = AppleMusicController(),
        loginItemManager: LoginItemManager = LoginItemManager(),
        accessibilityAutomation: AccessibilityAutomation = AccessibilityAutomation(),
        outputVolumeController: any OutputVolumeControlling = SystemOutputVolumeController()
    ) {
        self.settings = settings
        self.microphoneMonitor = microphoneMonitor
        self.musicController = musicController
        self.loginItemManager = loginItemManager
        self.accessibilityAutomation = accessibilityAutomation
        playbackCoordinator = PlaybackCoordinator(
            player: musicController,
            resumePolicy: {
                (settings.automaticResume, settings.resumeDelay.duration)
            }
        )
        let meetingMicrophoneController = AccessibilityMeetingMicrophoneController(
            automation: accessibilityAutomation
        )
        meetingAssistCoordinator = MeetingAssistCoordinator(
            volumeController: outputVolumeController,
            microphoneController: meetingMicrophoneController,
            policyProvider: {
                MeetingAssistPolicy(
                    enabled: settings.monitoringEnabled && settings.meetingAssistEnabled,
                    lowerAudio: settings.lowerMeetingAudio,
                    reducedVolume: Float(settings.reducedMeetingVolume),
                    muteMeetingMicrophone: settings.muteMeetingMicrophone,
                    releaseDelay: settings.resumeDelay.duration
                )
            }
        )
        phoneCallMonitor = PhoneCallMonitor(automation: accessibilityAutomation)

        playbackCoordinator.onPlaybackChange = { [weak self] change in
            self?.playFeedback(change == .paused ? .lowered : .restored)
        }

        meetingAssistCoordinator.onMicrophoneChange = { [weak self] change in
            self?.playFeedback(change == .muted ? .lowered : .restored)
        }

        microphoneMonitor.onStatusChange = { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.lastMicrophoneStatus = status
                await self.reconcilePlaybackActivity()
            }
        }

        microphoneMonitor.onCaptureSourcesChange = { [weak self] sources in
            self?.reconcileMeetingAssist(sources: sources)
        }

        microphoneMonitor.shouldIgnoreSource = { [weak self] source in
            self?.settings.ignores(source) ?? false
        }

        settings.onMonitoringEnabledChange = { [weak self] enabled in
            self?.applyMonitoringPreference(enabled)
        }

        settings.onMeetingAssistChange = { [weak self] in
            self?.meetingAssistCoordinator.settingsDidChange()
        }

        settings.onPhoneCallDetectionChange = { [weak self] enabled in
            guard let self else { return }
            self.phoneCallMonitor.setEnabled(self.settings.monitoringEnabled && enabled)
            self.reconcileMeetingAssist()
        }

        phoneCallMonitor.onActivityChange = { [weak self] _ in
            guard let self else { return }
            self.reconcileMeetingAssist()
            Task { @MainActor [weak self] in
                await self?.reconcilePlaybackActivity()
            }
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

    func requestAccessibilityPermission() {
        accessibilityAutomation.requestPermission()
        phoneCallMonitor.refreshNow()
        meetingAssistCoordinator.settingsDidChange()
    }

    func refreshAccessibilityPermission() {
        accessibilityAutomation.refreshPermission()
        phoneCallMonitor.refreshNow()
        meetingAssistCoordinator.settingsDidChange()
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
        refreshAccessibilityPermission()
        await playbackCoordinator.reconcilePlayerState()
        await refreshAutomationPermission()
    }

    func prepareForTermination() async {
        guard !isTerminating else { return }
        isTerminating = true
        meetingAssistCoordinator.shutdown()
        phoneCallMonitor.setEnabled(false)
        await playbackCoordinator.shutdown()
        microphoneMonitor.stop()
    }

    private func applyMonitoringPreference(_ enabled: Bool) {
        playbackCoordinator.setMonitoringEnabled(enabled)
        if enabled {
            microphoneMonitor.start()
            lastMicrophoneStatus = microphoneMonitor.status
            phoneCallMonitor.setEnabled(settings.detectPhoneCalls)
            reconcileMeetingAssist()
        } else {
            meetingAssistCoordinator.shutdown()
            phoneCallMonitor.setEnabled(false)
            microphoneMonitor.stop()
        }
    }

    private func retryPlaybackIfNeeded() async {
        guard settings.monitoringEnabled else { return }
        lastMicrophoneStatus = microphoneMonitor.status
        await reconcilePlaybackActivity()
    }

    private func reconcilePlaybackActivity() async {
        let combinedStatus: MicrophoneStatus = phoneCallMonitor.activeApplication == nil
            ? lastMicrophoneStatus
            : .active
        await playbackCoordinator.handleMicrophoneStatus(combinedStatus)
    }

    private func reconcileMeetingAssist(sources: [CaptureSource]? = nil) {
        let activePhoneMeetings = phoneCallMonitor.activeApplication.map { Set([$0]) } ?? []
        meetingAssistCoordinator.handleActivity(
            sources: sources ?? microphoneMonitor.captureSources,
            additionalMeetings: activePhoneMeetings
        )
    }

    private func playFeedback(_ cue: FeedbackCue) {
        guard settings.feedbackSoundsEnabled else { return }
        feedbackSoundPlayer.play(cue)
    }
}
