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
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Runs whenever the preference actually changes, from any writer, so
    /// starting and stopping the monitor can never be skipped.
    @ObservationIgnored var onMonitoringEnabledChange: (@MainActor (Bool) -> Void)?

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

    var resumeDelay: ResumeDelay {
        didSet { defaults.set(resumeDelay.rawValue, forKey: Key.resumeDelay) }
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
        ])
        monitoringEnabled = defaults.bool(forKey: Key.monitoringEnabled)
        automaticResume = defaults.bool(forKey: Key.automaticResume)
        resumeDelay = ResumeDelay(rawValue: defaults.double(forKey: Key.resumeDelay)) ?? .twoSeconds
        ignoreAlwaysOnSystemListeners = defaults.bool(
            forKey: Key.ignoreAlwaysOnSystemListeners
        )
        ignoredCaptureIdentifiers = defaults.stringArray(
            forKey: Key.ignoredCaptureIdentifiers
        ) ?? []
    }
}
