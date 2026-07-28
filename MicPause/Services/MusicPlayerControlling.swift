import Foundation

protocol MusicPlayerControlling: Sendable {
    func playerState() async throws -> MusicPlayerState
    func pause() async throws
    func play() async throws
    func automationPermissionStatus() async -> AutomationPermissionStatus
}
enum MusicPlayerError: LocalizedError, Equatable {
    case applicationUnavailable
    case automationDenied
    case automationWouldRequireConsent
    case scriptFailure(String)

    var errorDescription: String? {
        switch self {
        case .applicationUnavailable:
            "Apple Music is unavailable."
        case .automationDenied:
            "Apple Music automation is not allowed."
        case .automationWouldRequireConsent:
            "Apple Music automation permission has not been requested."
        case .scriptFailure(let message):
            "Apple Music could not be controlled: \(message)"
        }
    }
}
