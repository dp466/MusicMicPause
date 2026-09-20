import AppKit
import Carbon
import Foundation

private let musicBundleIdentifier = "com.apple.Music"

actor AppleMusicController: MusicPlayerControlling {
    private static let eventNotPermitted = OSStatus(-1743)
    private static let eventWouldRequireConsent = OSStatus(-1744)

    func playerState() async throws -> MusicPlayerState {
        // One main-actor hop for the whole operation. The installed and running
        // checks are cheap next to the Apple event, and hopping once instead of
        // three times keeps the round trip short.
        try await MainActor.run {
            guard MusicApplication.isInstalled else {
                throw MusicPlayerError.applicationUnavailable
            }
            guard MusicApplication.isRunning else {
                return .stopped
            }

            switch try MusicScript.playerState.execute().stringValue?.lowercased() {
            case "playing":
                return .playing
            case "paused":
                return .paused
            default:
                return .stopped
            }
        }
    }

    func pause() async throws {
        try await MainActor.run { _ = try MusicScript.pause.execute() }
    }

    func play() async throws {
        try await MainActor.run { _ = try MusicScript.play.execute() }
    }

    func requestAutomationPermission() async -> AutomationPermissionStatus {
        await permission(askUserIfNeeded: true)
    }

    func automationPermissionStatus() async -> AutomationPermissionStatus {
        await permission(askUserIfNeeded: false)
    }

    private func permission(askUserIfNeeded: Bool) async -> AutomationPermissionStatus {
        await MainActor.run {
            guard MusicApplication.isInstalled else {
                return .unavailable("Apple Music not found")
            }

            let target = NSAppleEventDescriptor(bundleIdentifier: musicBundleIdentifier)
            let status = AEDeterminePermissionToAutomateTarget(
                target.aeDesc,
                typeWildCard,
                typeWildCard,
                askUserIfNeeded
            )
            return Self.permissionStatus(for: status)
        }
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

    fileprivate static func error(from scriptError: NSDictionary) -> MusicPlayerError {
        switch (scriptError[NSAppleScript.errorNumber] as? NSNumber)?.int32Value {
        case Self.eventNotPermitted:
            .automationDenied
        case Self.eventWouldRequireConsent:
            .automationWouldRequireConsent
        default:
            .scriptFailure(
                scriptError[NSAppleScript.errorMessage] as? String ?? "Unknown scripting error"
            )
        }
    }
}

/// A lazily compiled, reusable script.
///
/// `NSAppleScript` recompiles its source the first time each instance runs, so
/// creating one per call — as the previous implementation did — paid for a
/// compile on every state poll. Holding one instance per command reduces steady
/// state to a single Apple event.
@MainActor
private final class MusicScript {
    static let playerState = MusicScript("return (player state as text)")
    static let pause = MusicScript("pause")
    static let play = MusicScript("play")

    private let source: String
    private var script: NSAppleScript?

    private init(_ command: String) {
        source = """
        tell application id "\(musicBundleIdentifier)"
            \(command)
        end tell
        """
    }

    func execute() throws -> NSAppleEventDescriptor {
        let script = try compiledScript()
        var scriptError: NSDictionary?
        let result = script.executeAndReturnError(&scriptError)
        guard let scriptError else { return result }
        throw AppleMusicController.error(from: scriptError)
    }

    private func compiledScript() throws -> NSAppleScript {
        if let script { return script }
        guard let created = NSAppleScript(source: source) else {
            throw MusicPlayerError.scriptFailure("The AppleScript could not be created.")
        }
        script = created
        return created
    }
}

@MainActor
private enum MusicApplication {
    /// Apple Music cannot be uninstalled mid-session in practice, so a positive
    /// answer is cached and the Launch Services lookup stops repeating.
    private static var confirmedInstalled = false
    private static var knownInstance: NSRunningApplication?

    static var isInstalled: Bool {
        if confirmedInstalled { return true }
        confirmedInstalled = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: musicBundleIdentifier
        ) != nil
        return confirmedInstalled
    }

    /// Holds on to the running instance and reads its `isTerminated` flag,
    /// which AppKit keeps current locally. Enumerating running applications
    /// costs several Launch Services round trips and used to run on every poll.
    ///
    /// The lookup still repeats whenever Music is *not* known to be running, so
    /// a stale cache can never make the app send an Apple event that would
    /// launch Music.
    static var isRunning: Bool {
        if let knownInstance, !knownInstance.isTerminated { return true }
        knownInstance = NSRunningApplication.runningApplications(
            withBundleIdentifier: musicBundleIdentifier
        ).first
        return knownInstance != nil
    }
}
