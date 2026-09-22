import Foundation
import Observation

@MainActor
@Observable
final class MeetingAssistCoordinator {
    typealias PolicyProvider = @MainActor () -> MeetingAssistPolicy

    enum MicrophoneChange: Equatable, Sendable {
        case muted
        case unmuted
    }

    @ObservationIgnored var onMicrophoneChange: (@MainActor (MicrophoneChange) -> Void)?

    private(set) var state: MeetingAssistState = .disabled
    private(set) var isActive = false

    @ObservationIgnored private let volumeController: any OutputVolumeControlling
    @ObservationIgnored private let microphoneController: any MeetingMicrophoneControlling
    @ObservationIgnored private let policyProvider: PolicyProvider

    @ObservationIgnored private var latestSources: [CaptureSource] = []
    @ObservationIgnored private var additionalMeetings: Set<MeetingApplication> = []
    @ObservationIgnored private var handledMeetings: Set<MeetingApplication> = []
    @ObservationIgnored private var appliedReducedVolume: Float?
    @ObservationIgnored private var sessionGeneration = 0
    @ObservationIgnored private var releaseTask: Task<Void, Never>?

    init(
        volumeController: any OutputVolumeControlling,
        microphoneController: any MeetingMicrophoneControlling,
        policyProvider: @escaping PolicyProvider
    ) {
        self.volumeController = volumeController
        self.microphoneController = microphoneController
        self.policyProvider = policyProvider
    }

    deinit {
        releaseTask?.cancel()
    }

    func handleActivity(
        sources: [CaptureSource],
        additionalMeetings: Set<MeetingApplication> = []
    ) {
        latestSources = sources
        self.additionalMeetings = additionalMeetings
        reevaluate()
    }

    func settingsDidChange() {
        reevaluate()
    }

    func shutdown() {
        releaseTask?.cancel()
        releaseTask = nil
        sessionGeneration += 1
        let errors = releaseOwnedChanges()
        isActive = false
        handledMeetings.removeAll()
        state = errors.isEmpty ? .disabled : .attention(errors.joined(separator: " "))
    }

    private func reevaluate() {
        let policy = policyProvider()
        guard policy.enabled else {
            releaseTask?.cancel()
            releaseTask = nil
            sessionGeneration += 1
            let errors = releaseOwnedChanges()
            isActive = false
            handledMeetings.removeAll()
            state = errors.isEmpty ? .disabled : .attention(errors.joined(separator: " "))
            return
        }

        let meetings = currentMeetings()
        let dictationActive = CaptureRoleClassifier.isDictationActive(in: latestSources)

        guard dictationActive, !meetings.isEmpty else {
            scheduleReleaseIfNeeded()
            if !isActive { state = .ready }
            return
        }

        releaseTask?.cancel()
        releaseTask = nil
        sessionGeneration += 1
        isActive = true

        var messages: [String] = []

        if policy.lowerAudio {
            do {
                if volumeController.isDucked,
                   let appliedReducedVolume,
                   abs(appliedReducedVolume - policy.reducedVolume) > 0.001 {
                    // A slider change during dictation should take effect now,
                    // without losing the original pre-dictation value.
                    try volumeController.restore()
                    self.appliedReducedVolume = nil
                }
                _ = try volumeController.duck(to: policy.reducedVolume)
                appliedReducedVolume = volumeController.isDucked
                    ? policy.reducedVolume
                    : nil
            } catch {
                messages.append("Sound was not lowered: \(error.localizedDescription).")
            }
        } else if volumeController.isDucked {
            do {
                try volumeController.restore()
                appliedReducedVolume = nil
            } catch {
                messages.append("Could not restore sound: \(error.localizedDescription).")
            }
        }

        if policy.muteMeetingMicrophone {
            if microphoneController.permissionStatus != .granted {
                messages.append("Accessibility permission is required to mute the meeting microphone.")
            } else {
                for application in meetings.subtracting(handledMeetings) {
                    switch microphoneController.muteIfNeeded(application) {
                    case .mutedByUtility:
                        handledMeetings.insert(application)
                        onMicrophoneChange?(.muted)
                    case .alreadyMuted:
                        handledMeetings.insert(application)
                    case .unavailable(let reason):
                        messages.append(reason + ".")
                    }
                }
            }
        } else {
            for application in microphoneController.ownedApplications {
                switch microphoneController.restoreIfOwned(application) {
                case .restored:
                    onMicrophoneChange?(.unmuted)
                case .unavailable(let reason):
                    messages.append(reason + ".")
                case .alreadyUnmuted, .notOwned:
                    break
                }
            }
            handledMeetings.removeAll()
        }

        let names = meetings.map(\.name).sorted().joined(separator: ", ")
        if messages.isEmpty {
            state = .active("Dictation assist active — \(names)")
        } else {
            state = .attention(messages.joined(separator: " "))
        }
    }

    private func scheduleReleaseIfNeeded() {
        guard isActive else { return }
        let delay = policyProvider().releaseDelay
        sessionGeneration += 1
        let generation = sessionGeneration
        releaseTask?.cancel()
        releaseTask = Task { [weak self] in
            do {
                // Use the same recovery delay chosen for Apple Music. A new
                // dictation source cancels this pending unmute and volume restore.
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard let self,
                  !Task.isCancelled,
                  generation == self.sessionGeneration else { return }

            let policy = self.policyProvider()
            let meetings = self.currentMeetings()
            guard !policy.enabled
                    || !CaptureRoleClassifier.isDictationActive(in: self.latestSources)
                    || meetings.isEmpty else {
                self.reevaluate()
                return
            }

            let errors = self.releaseOwnedChanges()
            self.isActive = false
            self.handledMeetings.removeAll()
            self.state = errors.isEmpty
                ? (policy.enabled ? .ready : .disabled)
                : .attention(errors.joined(separator: " "))
            self.releaseTask = nil
        }
    }

    private func currentMeetings() -> Set<MeetingApplication> {
        // Teams and other clients may close their Core Audio input as soon as
        // Mic Pause presses Mute. Keep an owned meeting in this dictation cycle
        // until dictation ends, or the user turns Meeting Assist off, so a
        // disappearing capture process cannot immediately undo the mute.
        CaptureRoleClassifier.meetingApplications(in: latestSources)
            .union(additionalMeetings)
            .union(microphoneController.ownedApplications)
    }

    private func releaseOwnedChanges() -> [String] {
        var errors: [String] = []

        for application in microphoneController.ownedApplications {
            switch microphoneController.restoreIfOwned(application) {
            case .restored:
                onMicrophoneChange?(.unmuted)
            case .unavailable(let reason):
                errors.append(reason + ". Please unmute it manually.")
            case .alreadyUnmuted, .notOwned:
                break
            }
        }

        do {
            try volumeController.restore()
            appliedReducedVolume = nil
        } catch {
            errors.append("Could not restore sound: \(error.localizedDescription).")
        }
        return errors
    }
}
