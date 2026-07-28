import AppKit
import Carbon
import Foundation

actor AppleMusicController: MusicPlayerControlling {
    private static let bundleIdentifier = "com.apple.Music"
    private static let eventNotPermitted = OSStatus(-1743)
    private static let eventWouldRequireConsent = OSStatus(-1744)

    func playerState() async throws -> MusicPlayerState {
        guard await isInstalled else {
            throw MusicPlayerError.applicationUnavailable
        }

        guard await isRunning else {
            return .stopped
        }

        let value = try await executeString(
            """
            tell application id "\(Self.bundleIdentifier)"
                return (player state as text)
            end tell
            """
        )?.lowercased()

        switch value {
        case "playing":
            return .playing
        case "paused":
            return .paused
        default:
            return .stopped
        }
    }

    func pause() async throws {
        try await executeCommand(
            """
            tell application id "\(Self.bundleIdentifier)"
                pause
            end tell
            """
        )
    }

    func play() async throws {
        try await executeCommand(
            """
            tell application id "\(Self.bundleIdentifier)"
                play
            end tell
            """
        )
    }

    func requestAutomationPermission() async -> AutomationPermissionStatus {
        guard await isInstalled else {
            return .unavailable("Apple Music not found")
        }

        return await MainActor.run {
            Self.determineAutomationPermission(askUserIfNeeded: true)
        }
    }

    func automationPermissionStatus() async -> AutomationPermissionStatus {
        guard await isInstalled else {
            return .unavailable("Apple Music not found")
        }

        return await MainActor.run {
            Self.determineAutomationPermission(askUserIfNeeded: false)
        }
    }

    @MainActor
    private static func determineAutomationPermission(
        askUserIfNeeded: Bool
    ) -> AutomationPermissionStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: Self.bundleIdentifier)
        let status = AEDeterminePermissionToAutomateTarget(
            target.aeDesc,
            typeWildCard,
            typeWildCard,
            askUserIfNeeded
        )
        return permissionStatus(for: status)
    }

    static func permissionStatus(for status: OSStatus) -> AutomationPermissionStatus {
        switch status {
        case noErr:
            .granted
        case Self.eventNotPermitted:
            .denied
        case Self.eventWouldRequireConsent:
            .notDetermined
        default:
            .unavailable("Status \(status)")
        }
    }

    private var isInstalled: Bool {
        get async {
            await MainActor.run {
                NSWorkspace.shared.urlForApplication(
                    withBundleIdentifier: Self.bundleIdentifier
                ) != nil
            }
        }
    }

    private var isRunning: Bool {
        get async {
            await MainActor.run {
                !NSRunningApplication.runningApplications(
                    withBundleIdentifier: Self.bundleIdentifier
                ).isEmpty
            }
        }
    }

    private func executeString(_ source: String) async throws -> String? {
        try await MainActor.run {
            try Self.executeOnMainActor(source).stringValue
        }
    }

    private func executeCommand(_ source: String) async throws {
        try await MainActor.run {
            _ = try Self.executeOnMainActor(source)
        }
    }

    @MainActor
    private static func executeOnMainActor(_ source: String) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            throw MusicPlayerError.scriptFailure("The AppleScript could not be created.")
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard let error else {
            return result
        }

        let number = (error[NSAppleScript.errorNumber] as? NSNumber)?.int32Value
        switch number {
        case Self.eventNotPermitted:
            throw MusicPlayerError.automationDenied
        case Self.eventWouldRequireConsent:
            throw MusicPlayerError.automationWouldRequireConsent
        default:
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown scripting error"
            throw MusicPlayerError.scriptFailure(message)
        }
    }
}
