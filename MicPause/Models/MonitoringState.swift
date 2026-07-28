import Foundation

enum MonitoringState: Equatable, Sendable {
    case disabled
    case micInactive
    case micActive
    case pausedByUtility
    case unavailable(String)

    var label: String {
        switch self {
        case .disabled:
            "Disabled"
        case .micInactive:
            "Microphone inactive"
        case .micActive:
            "Microphone active"
        case .pausedByUtility:
            "Music paused"
        case .unavailable(let reason):
            reason
        }
    }
}
enum MicrophoneStatus: Equatable, Sendable {
    case inactive
    case active
    case unavailable(String)
}

enum MusicPlayerState: Equatable, Sendable {
    case playing
    case paused
    case stopped
}

enum AutomationPermissionStatus: Equatable, Sendable {
    case granted
    case denied
    case notDetermined
    case unavailable(String)

    var label: String {
        switch self {
        case .granted:
            "Allowed"
        case .denied:
            "Not allowed"
        case .notDetermined:
            "Not requested"
        case .unavailable(let reason):
            reason
        }
    }
}
