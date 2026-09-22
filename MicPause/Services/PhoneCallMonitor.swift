import Foundation
import Observation

/// Best-effort fallback for calls whose audio is owned by Apple's private
/// Continuity/telephony services and therefore does not appear in Core Audio's
/// public capture-process list.
///
/// Native macOS CallKit does not expose the system call observer. With explicit
/// Accessibility permission, an enabled Hang Up control is the narrowest public
/// signal that Phone or FaceTime is actually in a call; merely running either
/// application is deliberately not enough.
@MainActor
@Observable
final class PhoneCallMonitor {
    private(set) var state: PhoneCallDetectionState = .disabled
    private(set) var activeApplication: MeetingApplication?

    @ObservationIgnored var onActivityChange: (@MainActor (MeetingApplication?) -> Void)?

    @ObservationIgnored private let automation: AccessibilityAutomation
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var enabled = false

    init(automation: AccessibilityAutomation) {
        self.automation = automation
    }

    deinit {
        pollTask?.cancel()
    }

    func setEnabled(_ enabled: Bool) {
        guard self.enabled != enabled else {
            if enabled { refreshNow() }
            return
        }

        self.enabled = enabled
        if enabled {
            refreshNow()
            startPolling()
        } else {
            pollTask?.cancel()
            pollTask = nil
            publish(application: nil, state: .disabled)
        }
    }

    func refreshNow() {
        guard enabled else { return }
        automation.refreshPermission()
        guard automation.permissionStatus == .granted else {
            publish(application: nil, state: .permissionRequired)
            return
        }

        let applications: [MeetingApplication] = [.phone, .faceTime]
        if let active = applications.first(where: automation.applicationHasActiveCall) {
            publish(application: active, state: .active(active.name))
        } else {
            publish(application: nil, state: .idle)
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(
                        for: .milliseconds(750),
                        tolerance: .milliseconds(150)
                    )
                } catch {
                    return
                }
                guard let self, self.enabled, !Task.isCancelled else { return }
                self.refreshNow()
            }
        }
    }

    private func publish(
        application: MeetingApplication?,
        state newState: PhoneCallDetectionState
    ) {
        let applicationChanged = application != activeApplication
        activeApplication = application
        state = newState
        if applicationChanged {
            onActivityChange?(application)
        }
    }
}
