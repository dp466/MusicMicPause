import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let monitoringEnabled = "monitoringEnabled"
        static let automaticResume = "automaticResume"
        static let resumeDelay = "resumeDelay"
        static let ignoreAlwaysOnSystemListeners = "ignoreAlwaysOnSystemListeners"
        static let ignoredCaptureIdentifiers = "ignoredCaptureIdentifiers"
        static let meetingAssistEnabled = "meetingAssistEnabled"
        static let lowerMeetingAudio = "lowerMeetingAudio"
        static let reducedMeetingVolume = "reducedMeetingVolume"
        static let muteMeetingMicrophone = "muteMeetingMicrophone"
        static let detectPhoneCalls = "detectPhoneCalls"
        static let feedbackSoundsEnabled = "feedbackSoundsEnabled"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Runs whenever the preference actually changes, from any writer, so
    /// starting and stopping the monitor can never be skipped.
    @ObservationIgnored var onMonitoringEnabledChange: (@MainActor (Bool) -> Void)?
    @ObservationIgnored var onMeetingAssistChange: (@MainActor () -> Void)?
    @ObservationIgnored var onPhoneCallDetectionChange: (@MainActor (Bool) -> Void)?

    var monitoringEnabled: Bool {
        didSet {
            defaults.set(monitoringEnabled, forKey: Key.monitoringEnabled)
            guard monitoringEnabled != oldValue else { return }
            onMonitoringEnabledChange?(monitoringEnabled)
        }
    }

    var automaticResume: Bool {
        didSet { defaults.set(automaticResume, forKey: Key.automaticResume) }
    }

    var feedbackSoundsEnabled: Bool {
        didSet { defaults.set(feedbackSoundsEnabled, forKey: Key.feedbackSoundsEnabled) }
    }

    var resumeDelay: ResumeDelay {
        didSet {
            defaults.set(resumeDelay.rawValue, forKey: Key.resumeDelay)
            guard resumeDelay != oldValue else { return }
            onMeetingAssistChange?()
        }
    }

    /// Meeting Assist is opt-in because it controls other applications and may
    /// require Accessibility permission.
    var meetingAssistEnabled: Bool {
        didSet {
            defaults.set(meetingAssistEnabled, forKey: Key.meetingAssistEnabled)
            guard meetingAssistEnabled != oldValue else { return }
            onMeetingAssistChange?()
        }
    }

    var lowerMeetingAudio: Bool {
        didSet {
            defaults.set(lowerMeetingAudio, forKey: Key.lowerMeetingAudio)
            guard lowerMeetingAudio != oldValue else { return }
            onMeetingAssistChange?()
        }
    }

    var reducedMeetingVolume: Double {
        didSet {
            defaults.set(reducedMeetingVolume, forKey: Key.reducedMeetingVolume)
            guard reducedMeetingVolume != oldValue else { return }
            onMeetingAssistChange?()
        }
    }

    var muteMeetingMicrophone: Bool {
        didSet {
            defaults.set(muteMeetingMicrophone, forKey: Key.muteMeetingMicrophone)
            guard muteMeetingMicrophone != oldValue else { return }
            onMeetingAssistChange?()
        }
    }

    /// Uses Accessibility to recognize an enabled Hang Up control because the
    /// public native-macOS CallKit observer is unavailable.
    var detectPhoneCalls: Bool {
        didSet {
            defaults.set(detectPhoneCalls, forKey: Key.detectPhoneCalls)
            guard detectPhoneCalls != oldValue else { return }
            onPhoneCallDetectionChange?(detectPhoneCalls)
            onMeetingAssistChange?()
        }
    }

    /// Skips listeners such as Sound Recognition and Voice Control, which hold
    /// the microphone open continuously. Speech services are never skipped, so
    /// dictation and a triggered Siri still pause playback.
    var ignoreAlwaysOnSystemListeners: Bool {
        didSet {
            defaults.set(
                ignoreAlwaysOnSystemListeners,
                forKey: Key.ignoreAlwaysOnSystemListeners
            )
        }
    }

    /// Bundle identifiers, or executable names for daemons, whose microphone
    /// use should not pause playback.
    private(set) var ignoredCaptureIdentifiers: [String] {
        didSet {
            defaults.set(ignoredCaptureIdentifiers, forKey: Key.ignoredCaptureIdentifiers)
        }
    }

    func ignore(_ source: CaptureSource) {
        guard !ignoredCaptureIdentifiers.contains(source.identifier) else { return }
        ignoredCaptureIdentifiers.append(source.identifier)
    }

    func stopIgnoring(_ identifier: String) {
        ignoredCaptureIdentifiers.removeAll { $0 == identifier }
    }

    func ignores(_ source: CaptureSource) -> Bool {
        if ignoredCaptureIdentifiers.contains(source.identifier) { return true }
        return ignoreAlwaysOnSystemListeners && source.kind == .systemListener
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.monitoringEnabled: true,
            Key.automaticResume: true,
            Key.resumeDelay: ResumeDelay.twoSeconds.rawValue,
            Key.ignoreAlwaysOnSystemListeners: true,
            Key.meetingAssistEnabled: false,
            Key.lowerMeetingAudio: true,
            Key.reducedMeetingVolume: 0.25,
            Key.muteMeetingMicrophone: true,
            Key.detectPhoneCalls: true,
            Key.feedbackSoundsEnabled: false,
        ])
        monitoringEnabled = defaults.bool(forKey: Key.monitoringEnabled)
        automaticResume = defaults.bool(forKey: Key.automaticResume)
        resumeDelay = ResumeDelay(rawValue: defaults.double(forKey: Key.resumeDelay)) ?? .twoSeconds
        meetingAssistEnabled = defaults.bool(forKey: Key.meetingAssistEnabled)
        lowerMeetingAudio = defaults.bool(forKey: Key.lowerMeetingAudio)
        reducedMeetingVolume = min(
            max(defaults.double(forKey: Key.reducedMeetingVolume), 0.05),
            0.75
        )
        muteMeetingMicrophone = defaults.bool(forKey: Key.muteMeetingMicrophone)
        detectPhoneCalls = defaults.bool(forKey: Key.detectPhoneCalls)
        feedbackSoundsEnabled = defaults.bool(forKey: Key.feedbackSoundsEnabled)
        ignoreAlwaysOnSystemListeners = defaults.bool(
            forKey: Key.ignoreAlwaysOnSystemListeners
        )
        ignoredCaptureIdentifiers = defaults.stringArray(
            forKey: Key.ignoredCaptureIdentifiers
        ) ?? []
    }
}
