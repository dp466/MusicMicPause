import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let monitoringEnabled = "monitoringEnabled"
        static let automaticResume = "automaticResume"
        static let resumeDelay = "resumeDelay"
    }

    private let defaults: UserDefaults

    @Published var monitoringEnabled: Bool {
        didSet { defaults.set(monitoringEnabled, forKey: Key.monitoringEnabled) }
    }

    @Published var automaticResume: Bool {
        didSet { defaults.set(automaticResume, forKey: Key.automaticResume) }
    }

    @Published var resumeDelay: ResumeDelay {
        didSet { defaults.set(resumeDelay.rawValue, forKey: Key.resumeDelay) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.monitoringEnabled: true,
            Key.automaticResume: true,
            Key.resumeDelay: ResumeDelay.twoSeconds.rawValue,
        ])
        monitoringEnabled = defaults.bool(forKey: Key.monitoringEnabled)
        automaticResume = defaults.bool(forKey: Key.automaticResume)
        resumeDelay = ResumeDelay(rawValue: defaults.double(forKey: Key.resumeDelay)) ?? .twoSeconds
    }
}
