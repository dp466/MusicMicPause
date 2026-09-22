import AppKit
import CoreAudio
import Darwin
import Foundation

/// A process Core Audio reports as capturing microphone input.
struct CaptureSource: Equatable, Identifiable, Sendable {
    enum Kind: Equatable, Sendable {
        /// A launchable app: a conference call, a recorder, a browser.
        case application
        /// Dictation or Siri. A background process, but it only captures when
        /// the person actually invoked it, so it must still pause playback.
        case speechService
        /// A background listener such as Sound Recognition or Voice Control,
        /// which can hold the microphone open indefinitely.
        case systemListener
    }

    /// Bundle identifier where Core Audio reports one, executable name
    /// otherwise. This is what the ignore list matches on.
    let identifier: String
    let name: String
    let kind: Kind

    var id: String { identifier }
}

/// Reads which processes are capturing microphone input.
///
/// Core Audio's device-level "is running somewhere" flag cannot say *who* is
/// listening, so on its own it cannot tell an always-on system listener apart
/// from a conference call. macOS 14 added the process object list, which can.
enum AudioCaptureInspector {
    /// Speech services are deliberately never treated as background listeners:
    /// when these capture, dictation or Siri is really running.
    private static let speechIdentifiers: Set<String> = [
        "com.apple.corespeech",
        "com.apple.corespeechd",
        "corespeechd",
        "com.apple.assistantd",
        "assistantd",
        "com.apple.sirinservice",
        "com.apple.siri",
    ]

    /// Only positively identified always-on listeners are ignored by default.
    private static let backgroundIdentifiers: Set<String> = [
        "com.apple.soundanalysisd", "soundanalysisd",
        "com.apple.universalaccessd", "universalaccessd",
    ]

    static func kind(for identifier: String) -> CaptureSource.Kind {
        let key = identifier.lowercased()
        if speechIdentifiers.contains(key) { return .speechService }
        if backgroundIdentifiers.contains(key) { return .systemListener }
        // Helpers and XPC services need not be launchable applications. Failure
        // to resolve an app is not evidence of an always-on listener.
        return .application
    }

    private static let friendlyNames: [String: String] = [
        "com.apple.corespeech": "Dictation & Siri",
        "com.apple.assistantd": "Siri",
        "com.apple.soundanalysisd": "Sound Recognition",
        "com.apple.universalaccessd": "Voice Control",
        "com.apple.avconferenced": "FaceTime & Continuity",
        "com.apple.mobilephone": "Phone",
        "com.microsoft.teams2": "Microsoft Teams",
        "us.zoom.xos": "Zoom",
        "com.openai.codex": "ChatGPT",
        "com.openai.chat": "ChatGPT",
        "com.goodsnooze.macwhisper": "MacWhisper",
    ]

    static func capturingSources() -> [CaptureSource] {
        var seen = Set<String>()
        return processObjects()
            .filter(isRunningInput)
            .compactMap(source(for:))
            // One row per identifier; an app can own several audio processes.
            .filter { seen.insert($0.identifier).inserted }
    }

    static func source(for object: AudioObjectID) -> CaptureSource? {
        let identifier = bundleIdentifier(for: object).flatMap { $0.isEmpty ? nil : $0 }
            ?? executableName(for: object)
        guard let identifier else { return nil }

        let key = identifier.lowercased()
        let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
        return CaptureSource(
            identifier: identifier,
            name: friendlyNames[key]
                ?? appURL.map { FileManager.default.displayName(atPath: $0.path) }
                ?? identifier,
            kind: kind(for: identifier)
        )
    }

    static func processObjects() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let system = AudioObjectID(kAudioObjectSystemObject)

        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr,
              size > 0 else { return [] }

        var objects = [AudioObjectID](
            repeating: AudioObjectID(kAudioObjectUnknown),
            count: Int(size) / MemoryLayout<AudioObjectID>.size
        )
        guard AudioObjectGetPropertyData(
            system, &address, 0, nil, &size, &objects
        ) == noErr else { return [] }

        return objects
    }

    static func isRunningInput(_ object: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningInput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(
            object, &address, 0, nil, &size, &running
        ) == noErr else { return false }
        return running != 0
    }

    private static func bundleIdentifier(for object: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyBundleID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let result = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0)
        }
        return result == noErr ? value as String : nil
    }

    private static func executableName(for object: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid: pid_t = -1
        var size = UInt32(MemoryLayout<pid_t>.size)
        guard AudioObjectGetPropertyData(
            object, &address, 0, nil, &size, &pid
        ) == noErr, pid > 0 else { return nil }

        var name = [CChar](repeating: 0, count: 256)
        guard proc_name(pid, &name, UInt32(name.count)) > 0 else { return nil }
        let executable = String(
            decoding: name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
            as: UTF8.self
        )
        return executable.isEmpty ? nil : executable
    }
}
