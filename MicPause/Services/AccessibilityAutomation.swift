import AppKit
@preconcurrency import ApplicationServices
import Foundation
import Observation

enum MeetingMicrophoneAction: Equatable, Sendable {
    /// The control currently offers Mute, so the local microphone is on.
    case mute
    /// The control currently offers Unmute, so the local microphone is off.
    case unmute
}

struct AccessibilityControlDescriptor: Equatable, Sendable {
    let role: String
    let strings: [String]
    let isEnabled: Bool
    let canPress: Bool
}

enum AccessibilityControlClassifier {
    private static let excludedMicrophonePhrases = [
        "mute all", "unmute all", "all participants", "everyone",
        "participant", "attendee", "speaker", "incoming audio",
        "notification", "join audio",
    ]

    static func microphoneAction(
        for descriptor: AccessibilityControlDescriptor
    ) -> (action: MeetingMicrophoneAction, score: Int)? {
        guard descriptor.isEnabled,
              descriptor.canPress,
              supportedControlRoles.contains(descriptor.role) else { return nil }

        let values = descriptor.strings.map(normalize)
        let combined = values.joined(separator: " ")
        guard !excludedMicrophonePhrases.contains(where: combined.contains) else { return nil }

        for (index, value) in values.enumerated() {
            let scoreAdjustment = min(index, 8)

            if value.hasPrefix("microphone unmuted")
                || value.hasPrefix("microphone is on")
                || value.hasPrefix("mic on") {
                return (.mute, 116 - scoreAdjustment)
            }
            if value.hasPrefix("microphone muted")
                || value.hasPrefix("microphone is off")
                || value.hasPrefix("mic off") {
                return (.unmute, 116 - scoreAdjustment)
            }

            if value == "unmute"
                || value == "unmute audio"
                || value == "reactiver le son"
                || value == "retirer la sourdine"
                || startsWithAny(value, phrases: [
                    "unmute microphone", "unmute mic", "unmute my microphone",
                    "unmute my mic", "unmute my audio",
                    "turn microphone on", "turn mic on", "enable microphone",
                    "activer le microphone", "activer le micro",
                ]) {
                return (.unmute, 110 - scoreAdjustment)
            }

            if value == "mute"
                || value == "mute audio"
                || value == "couper le son"
                || value == "mettre en sourdine"
                || startsWithAny(value, phrases: [
                    "mute microphone", "mute mic", "mute my microphone",
                    "mute my mic", "mute my audio",
                    "turn microphone off", "turn mic off", "disable microphone",
                    "couper le microphone", "couper le micro",
                    "desactiver le microphone", "desactiver le micro",
                ]) {
                return (.mute, 110 - scoreAdjustment)
            }
        }

        // Some Electron apps expose only an internal identifier with no title.
        let compact = combined.replacingOccurrences(of: " ", with: "")
        if compact.contains("unmutemicrophone") || compact.contains("unmuteaudio") {
            return (.unmute, 75)
        }
        if compact.contains("mutemicrophone") || compact.contains("muteaudio") {
            return (.mute, 74)
        }
        return nil
    }

    static func indicatesActiveCall(
        _ descriptor: AccessibilityControlDescriptor
    ) -> Int? {
        guard descriptor.isEnabled,
              descriptor.canPress,
              supportedControlRoles.contains(descriptor.role) else { return nil }

        let values = descriptor.strings.map(normalize)
        for (index, value) in values.enumerated() {
            let scoreAdjustment = min(index, 8)
            if value == "hang up" || value.hasPrefix("hang up ")
                || value == "end call" || value.hasPrefix("end call ")
                || value == "leave call" || value.hasPrefix("leave call ")
                || value == "raccrocher" || value.hasPrefix("raccrocher ")
                || value.hasPrefix("terminer l appel")
                || value.hasPrefix("mettre fin a l appel")
                || value.hasPrefix("quitter l appel") {
                return 110 - scoreAdjustment
            }

            // Apple's macOS 27 Phone UI localizes its compact in-call button as
            // simply “End”. Restrict this to a pressable control in Phone or
            // FaceTime; callers never run this classifier against other apps.
            if value == "end" || value == "fin" {
                return 80 - scoreAdjustment
            }
        }

        // Do not use loose substring matching here: for example,
        // “Send Call to Voicemail” contains “endcall” once spaces are removed.
        // Phone detection must prefer a missed call over a false active call.
        return nil
    }

    static func isSupportedControlRole(_ role: String) -> Bool {
        supportedControlRoles.contains(role)
    }

    static func preferenceBonus(for role: String) -> Int {
        // An application menu command is typically the app's own local mute
        // action, while a meeting window can contain many participant controls.
        role == kAXMenuItemRole as String ? 20 : 0
    }

    private static let supportedControlRoles: Set<String> = [
        kAXButtonRole as String,
        kAXMenuButtonRole as String,
        kAXMenuItemRole as String,
        kAXCheckBoxRole as String,
        kAXRadioButtonRole as String,
    ]

    private static func startsWithAny(_ value: String, phrases: [String]) -> Bool {
        phrases.contains { value == $0 || value.hasPrefix($0 + " ") }
    }

    private static func normalize(_ value: String) -> String {
        let folded = value.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        ).lowercased()
        return folded
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
            .reduce(into: "") { result, character in
                if character == " ", result.last == " " { return }
                result.append(character)
            }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
@Observable
final class AccessibilityAutomation {
    private(set) var permissionStatus: AccessibilityPermissionStatus = .required

    init() {
        refreshPermission()
    }

    func refreshPermission() {
        permissionStatus = AXIsProcessTrusted() ? .granted : .required
    }

    /// Prompts asynchronously when needed. The returned status is the status at
    /// the time of the call; the UI refreshes it when it becomes active again.
    @discardableResult
    func requestPermission() -> AccessibilityPermissionStatus {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshPermission()
        return permissionStatus
    }

    func microphoneControl(
        for application: MeetingApplication
    ) -> (element: AXUIElement, action: MeetingMicrophoneAction)? {
        bestControl(in: application.bundleIdentifier) { descriptor in
            AccessibilityControlClassifier.microphoneAction(for: descriptor).map {
                ($0.score, $0.action)
            }
        }
    }

    func applicationHasActiveCall(_ application: MeetingApplication) -> Bool {
        bestControl(in: application.bundleIdentifier) { descriptor in
            AccessibilityControlClassifier.indicatesActiveCall(descriptor).map { ($0, true) }
        } != nil
    }

    @discardableResult
    func press(_ element: AXUIElement) -> Bool {
        AXUIElementPerformAction(element, kAXPressAction as CFString) == .success
    }

    func runningProcessIdentifier(for application: MeetingApplication) -> pid_t? {
        runningApplication(for: application.bundleIdentifier)?.processIdentifier
    }

    private func bestControl<Value: Equatable>(
        in bundleIdentifier: String,
        classifier: (AccessibilityControlDescriptor) -> (score: Int, value: Value)?
    ) -> (element: AXUIElement, action: Value)? {
        guard permissionStatus == .granted,
              let runningApplication = runningApplication(for: bundleIdentifier) else {
            return nil
        }

        let root = AXUIElementCreateApplication(runningApplication.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.25)

        var queue: [(element: AXUIElement, depth: Int)] = [(root, 0)]
        var cursor = 0
        var visited = Set<CFHashCode>()
        var best: (element: AXUIElement, action: Value, score: Int)?
        var bestIsAmbiguous = false

        // Teams' WebView meeting toolbar can sit 21 AX levels below the app
        // root. A shallow walk sees the window and menus but misses Mute mic.
        // Keep a node cap so a malformed or very large tree cannot stall the
        // microphone transition indefinitely.
        while cursor < queue.count, cursor < 2_400 {
            let node = queue[cursor]
            cursor += 1
            guard node.depth <= 28 else { continue }

            let identity = CFHash(node.element)
            guard visited.insert(identity).inserted else { continue }

            let descriptor = descriptor(for: node.element)
            if let match = classifier(descriptor) {
                let effectiveScore = match.score
                    + AccessibilityControlClassifier.preferenceBonus(for: descriptor.role)
                    - min(node.depth * 2, 24)

                if effectiveScore > (best?.score ?? Int.min) {
                    best = (node.element, match.value, effectiveScore)
                    bestIsAmbiguous = false
                } else if effectiveScore == best?.score,
                          match.value != best?.action {
                    // Conflicting equally plausible controls are safer to leave
                    // untouched than to guess which state is current.
                    bestIsAmbiguous = true
                }
            }

            for child in childElements(of: node.element, includeApplicationRoots: node.depth == 0) {
                queue.append((child, node.depth + 1))
            }
        }

        guard !bestIsAmbiguous else { return nil }
        return best.map { ($0.element, $0.action) }
    }

    private func runningApplication(for bundleIdentifier: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first { !$0.isTerminated }
    }

    private func descriptor(for element: AXUIElement) -> AccessibilityControlDescriptor {
        let role = stringValue(of: element, attribute: kAXRoleAttribute as CFString) ?? ""
        guard AccessibilityControlClassifier.isSupportedControlRole(role) else {
            // Every node still participates in the tree traversal. Avoid the
            // more expensive string and action queries for non-controls.
            return AccessibilityControlDescriptor(
                role: role,
                strings: [],
                isEnabled: true,
                canPress: false
            )
        }

        let strings = [
            kAXTitleAttribute,
            kAXDescriptionAttribute,
            kAXHelpAttribute,
            kAXValueAttribute,
            kAXIdentifierAttribute,
        ].compactMap { stringValue(of: element, attribute: $0 as CFString) }

        let isEnabled = booleanValue(
            of: element,
            attribute: kAXEnabledAttribute as CFString
        ) ?? true

        var actionNames: CFArray?
        let actionResult = AXUIElementCopyActionNames(element, &actionNames)
        let actions = actionResult == .success ? actionNames as? [String] : nil

        return AccessibilityControlDescriptor(
            role: role,
            strings: strings,
            isEnabled: isEnabled,
            canPress: actions?.contains(kAXPressAction as String) == true
        )
    }

    private func childElements(
        of element: AXUIElement,
        includeApplicationRoots: Bool
    ) -> [AXUIElement] {
        var attributes = [kAXChildrenAttribute as CFString]
        if includeApplicationRoots {
            attributes.append(kAXWindowsAttribute as CFString)
            attributes.append(kAXMenuBarAttribute as CFString)
        }

        return attributes.flatMap { attribute -> [AXUIElement] in
            guard let value = attributeValue(of: element, attribute: attribute) else { return [] }
            if let elements = value as? [AXUIElement] { return elements }
            if CFGetTypeID(value) == AXUIElementGetTypeID() {
                return [unsafeDowncast(value, to: AXUIElement.self)]
            }
            return []
        }
    }

    private func stringValue(of element: AXUIElement, attribute: CFString) -> String? {
        attributeValue(of: element, attribute: attribute) as? String
    }

    private func booleanValue(of element: AXUIElement, attribute: CFString) -> Bool? {
        (attributeValue(of: element, attribute: attribute) as? NSNumber)?.boolValue
    }

    private func attributeValue(of element: AXUIElement, attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value
    }
}

enum MeetingMuteResult: Equatable, Sendable {
    case mutedByUtility
    case alreadyMuted
    case unavailable(String)
}

enum MeetingUnmuteResult: Equatable, Sendable {
    case restored
    case alreadyUnmuted
    case notOwned
    case unavailable(String)
}

@MainActor
protocol MeetingMicrophoneControlling: AnyObject {
    var permissionStatus: AccessibilityPermissionStatus { get }
    var ownedApplications: Set<MeetingApplication> { get }
    func muteIfNeeded(_ application: MeetingApplication) -> MeetingMuteResult
    func restoreIfOwned(_ application: MeetingApplication) -> MeetingUnmuteResult
}

@MainActor
final class AccessibilityMeetingMicrophoneController: MeetingMicrophoneControlling {
    private let automation: AccessibilityAutomation
    private var ownedProcessIdentifiers: [MeetingApplication: pid_t] = [:]

    init(automation: AccessibilityAutomation) {
        self.automation = automation
    }

    var permissionStatus: AccessibilityPermissionStatus {
        automation.permissionStatus
    }

    var ownedApplications: Set<MeetingApplication> {
        Set(ownedProcessIdentifiers.keys)
    }

    func muteIfNeeded(_ application: MeetingApplication) -> MeetingMuteResult {
        guard permissionStatus == .granted else {
            return .unavailable("Accessibility permission is required")
        }
        guard let processIdentifier = automation.runningProcessIdentifier(for: application) else {
            return .unavailable("\(application.name) is not running")
        }
        guard let control = automation.microphoneControl(for: application) else {
            return .unavailable("Could not find \(application.name)’s microphone control")
        }

        switch control.action {
        case .unmute:
            // It was muted before Mic Pause arrived, so it is not ours to undo.
            ownedProcessIdentifiers.removeValue(forKey: application)
            return .alreadyMuted
        case .mute:
            guard automation.press(control.element) else {
                return .unavailable("\(application.name) rejected its mute control")
            }
            ownedProcessIdentifiers[application] = processIdentifier
            Log.meeting.info("Muted \(application.name, privacy: .public) for dictation")
            return .mutedByUtility
        }
    }

    func restoreIfOwned(_ application: MeetingApplication) -> MeetingUnmuteResult {
        guard let ownedPID = ownedProcessIdentifiers[application] else { return .notOwned }
        guard automation.runningProcessIdentifier(for: application) == ownedPID else {
            ownedProcessIdentifiers.removeValue(forKey: application)
            return .alreadyUnmuted
        }
        guard let control = automation.microphoneControl(for: application) else {
            return .unavailable("Could not find \(application.name)’s microphone control to restore it")
        }

        switch control.action {
        case .mute:
            // The person already unmuted manually. Never toggle it back.
            ownedProcessIdentifiers.removeValue(forKey: application)
            return .alreadyUnmuted
        case .unmute:
            guard automation.press(control.element) else {
                return .unavailable("\(application.name) rejected its unmute control")
            }
            ownedProcessIdentifiers.removeValue(forKey: application)
            Log.meeting.info("Restored \(application.name, privacy: .public) microphone")
            return .restored
        }
    }
}
