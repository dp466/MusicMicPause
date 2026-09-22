import Foundation

struct MeetingApplication: Equatable, Hashable, Identifiable, Sendable {
    let bundleIdentifier: String
    let name: String

    var id: String { bundleIdentifier }

    static let phone = MeetingApplication(
        bundleIdentifier: "com.apple.mobilephone",
        name: "Phone"
    )

    static let faceTime = MeetingApplication(
        bundleIdentifier: "com.apple.FaceTime",
        name: "FaceTime"
    )
}

struct MeetingAssistPolicy: Equatable, Sendable {
    let enabled: Bool
    let lowerAudio: Bool
    let reducedVolume: Float
    let muteMeetingMicrophone: Bool
    let releaseDelay: Duration
}

enum CaptureRoleClassifier {
    private struct MeetingRule {
        let sourcePrefix: String
        let application: MeetingApplication
    }

    private static let meetingRules = [
        MeetingRule(
            sourcePrefix: "com.microsoft.teams2",
            application: MeetingApplication(
                bundleIdentifier: "com.microsoft.teams2",
                name: "Microsoft Teams"
            )
        ),
        MeetingRule(
            sourcePrefix: "com.microsoft.teams",
            application: MeetingApplication(
                bundleIdentifier: "com.microsoft.teams",
                name: "Microsoft Teams"
            )
        ),
        MeetingRule(
            sourcePrefix: "us.zoom.xos",
            application: MeetingApplication(
                bundleIdentifier: "us.zoom.xos",
                name: "Zoom"
            )
        ),
        MeetingRule(
            sourcePrefix: "com.apple.facetime",
            application: .faceTime
        ),
    ]

    private static let dictationPrefixes = [
        "com.openai.codex",
        "com.openai.chat",
        "com.goodsnooze.macwhisper",
    ]

    static func meetingApplications(in sources: [CaptureSource]) -> Set<MeetingApplication> {
        Set(sources.compactMap(meetingApplication(for:)))
    }

    static func isDictationActive(in sources: [CaptureSource]) -> Bool {
        sources.contains(where: isDictationSource)
    }

    static func meetingApplication(for source: CaptureSource) -> MeetingApplication? {
        let identifier = source.identifier.lowercased()
        return meetingRules.first {
            identifierMatches(identifier, prefix: $0.sourcePrefix)
        }?.application
    }

    static func isDictationSource(_ source: CaptureSource) -> Bool {
        if source.kind == .speechService { return true }
        let identifier = source.identifier.lowercased()
        return dictationPrefixes.contains {
            identifierMatches(identifier, prefix: $0)
        }
    }

    private static func identifierMatches(_ identifier: String, prefix: String) -> Bool {
        identifier == prefix || identifier.hasPrefix(prefix + ".")
    }
}

enum AccessibilityPermissionStatus: Equatable, Sendable {
    case granted
    case required

    var label: String {
        switch self {
        case .granted:
            "Allowed"
        case .required:
            "Permission required"
        }
    }
}

enum PhoneCallDetectionState: Equatable, Sendable {
    case disabled
    case permissionRequired
    case idle
    case active(String)
    case unavailable(String)

    var label: String {
        switch self {
        case .disabled:
            "Off"
        case .permissionRequired:
            "Accessibility required"
        case .idle:
            "No active call found"
        case .active(let appName):
            "Active in \(appName)"
        case .unavailable(let reason):
            reason
        }
    }
}

enum MeetingAssistState: Equatable, Sendable {
    case disabled
    case ready
    case active(String)
    case attention(String)

    var label: String {
        switch self {
        case .disabled:
            "Off"
        case .ready:
            "Ready"
        case .active(let detail), .attention(let detail):
            detail
        }
    }
}
