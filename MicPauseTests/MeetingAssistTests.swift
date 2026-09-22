import AppKit
import XCTest
@testable import MicPause

@MainActor
final class MeetingAssistTests: XCTestCase {
    func testClassifiesMeetingAndDictationHelpersByBundlePrefix() {
        let sources = [
            source("com.microsoft.teams2", name: "Teams"),
            source("com.openai.codex.helper.renderer", name: "ChatGPT Helper"),
        ]

        XCTAssertEqual(
            CaptureRoleClassifier.meetingApplications(in: sources),
            [MeetingApplication(bundleIdentifier: "com.microsoft.teams2", name: "Microsoft Teams")]
        )
        XCTAssertTrue(CaptureRoleClassifier.isDictationActive(in: sources))
        XCTAssertFalse(
            CaptureRoleClassifier.isDictationActive(
                in: [source("com.openai.codexx", name: "Unrelated")]
            )
        )
    }

    func testBuiltInDictationAndMacWhisperAreDictationSources() {
        XCTAssertTrue(
            CaptureRoleClassifier.isDictationActive(
                in: [source("com.apple.CoreSpeech", name: "Dictation", kind: .speechService)]
            )
        )
        XCTAssertTrue(
            CaptureRoleClassifier.isDictationActive(
                in: [source("com.goodsnooze.MacWhisper", name: "MacWhisper")]
            )
        )
    }

    func testMicrophoneControlClassifierDistinguishesMuteFromUnmute() {
        XCTAssertEqual(
            microphoneMatch("Mute microphone")?.action,
            .mute
        )
        XCTAssertEqual(
            microphoneMatch("Mute mic")?.action,
            .mute
        )
        XCTAssertEqual(
            microphoneMatch("Unmute microphone")?.action,
            .unmute
        )
        XCTAssertEqual(
            microphoneMatch("Unmute mic")?.action,
            .unmute
        )
        XCTAssertEqual(
            microphoneMatch("Couper le micro")?.action,
            .mute
        )
        XCTAssertEqual(
            microphoneMatch("Réactiver le son")?.action,
            .unmute
        )
    }

    func testMicrophoneControlClassifierRejectsParticipantAndDisabledControls() {
        XCTAssertNil(microphoneMatch("Mute all participants"))
        XCTAssertNil(microphoneMatch("Mute Alice"))
        XCTAssertNil(microphoneMatch("Unmute Bob"))
        XCTAssertNil(microphoneMatch("Couper le son de Alice"))
        XCTAssertNil(microphoneMatch("Réactiver le son de Bob"))
        XCTAssertNil(microphoneMatch("Mute", isEnabled: false))
    }

    func testActiveCallClassifierRequiresAnEnabledPressableCallControl() {
        XCTAssertNotNil(activeCallMatch("Hang Up"))
        XCTAssertNotNil(activeCallMatch("Raccrocher"))
        XCTAssertNotNil(activeCallMatch("End"))
        XCTAssertNil(activeCallMatch("Hang Up", isEnabled: false))
        XCTAssertNil(activeCallMatch("Send Call to Voicemail"))
        XCTAssertNil(activeCallMatch("Phone"))
    }

    func testOverlapDucksOutputAndMutesMeeting() {
        let volume = MockOutputVolumeController()
        let microphone = MockMeetingMicrophoneController()
        let policy = PolicyBox()
        let coordinator = makeCoordinator(volume: volume, microphone: microphone, policy: policy)

        coordinator.handleActivity(sources: meetingAndDictationSources)

        XCTAssertEqual(volume.duckLevels, [0.25])
        XCTAssertEqual(microphone.muteCalls, [teams])
        XCTAssertTrue(coordinator.isActive)
        guard case .active = coordinator.state else {
            return XCTFail("Expected Meeting Assist to be active")
        }
    }

    func testMeetingWithoutDictationDoesNothing() {
        let volume = MockOutputVolumeController()
        let microphone = MockMeetingMicrophoneController()
        let policy = PolicyBox()
        let coordinator = makeCoordinator(volume: volume, microphone: microphone, policy: policy)

        coordinator.handleActivity(sources: [source("com.microsoft.teams2", name: "Teams")])

        XCTAssertTrue(volume.duckLevels.isEmpty)
        XCTAssertTrue(microphone.muteCalls.isEmpty)
        XCTAssertEqual(coordinator.state, .ready)
    }

    func testEndingDictationRestoresOnlyOwnedChanges() async {
        let volume = MockOutputVolumeController()
        let microphone = MockMeetingMicrophoneController()
        let policy = PolicyBox()
        let coordinator = makeCoordinator(volume: volume, microphone: microphone, policy: policy)

        coordinator.handleActivity(sources: meetingAndDictationSources)
        coordinator.handleActivity(sources: [source("com.microsoft.teams2", name: "Teams")])
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(volume.restoreCount, 1)
        XCTAssertEqual(microphone.restoreCalls, [teams])
        XCTAssertFalse(coordinator.isActive)
        XCTAssertEqual(coordinator.state, .ready)
    }

    func testMeetingReleaseWaitsForConfiguredRecoveryDelay() async {
        let volume = MockOutputVolumeController()
        let microphone = MockMeetingMicrophoneController()
        let policy = PolicyBox()
        policy.value = MeetingAssistPolicy(
            enabled: true,
            lowerAudio: true,
            reducedVolume: 0.25,
            muteMeetingMicrophone: true,
            releaseDelay: .milliseconds(700)
        )
        let coordinator = makeCoordinator(volume: volume, microphone: microphone, policy: policy)

        coordinator.handleActivity(sources: meetingAndDictationSources)
        coordinator.handleActivity(sources: [source("com.microsoft.teams2", name: "Teams")])
        try? await Task.sleep(for: .milliseconds(200))

        XCTAssertTrue(coordinator.isActive)
        XCTAssertTrue(microphone.restoreCalls.isEmpty)
        XCTAssertEqual(volume.restoreCount, 0)

        try? await Task.sleep(for: .milliseconds(650))

        XCTAssertFalse(coordinator.isActive)
        XCTAssertEqual(microphone.restoreCalls, [teams])
        XCTAssertEqual(volume.restoreCount, 1)
    }

    func testDictationRestartCancelsPendingMeetingUnmute() async {
        let volume = MockOutputVolumeController()
        let microphone = MockMeetingMicrophoneController()
        let policy = PolicyBox()
        policy.value = MeetingAssistPolicy(
            enabled: true,
            lowerAudio: true,
            reducedVolume: 0.25,
            muteMeetingMicrophone: true,
            releaseDelay: .milliseconds(400)
        )
        let coordinator = makeCoordinator(volume: volume, microphone: microphone, policy: policy)

        coordinator.handleActivity(sources: meetingAndDictationSources)
        coordinator.handleActivity(sources: [source("com.microsoft.teams2", name: "Teams")])
        try? await Task.sleep(for: .milliseconds(150))
        coordinator.handleActivity(sources: meetingAndDictationSources)
        try? await Task.sleep(for: .milliseconds(400))

        XCTAssertTrue(coordinator.isActive)
        XCTAssertTrue(microphone.restoreCalls.isEmpty)
        XCTAssertEqual(volume.restoreCount, 0)
    }

    func testMicrophoneFeedbackOnlyFollowsOwnedMuteAndUnmute() async {
        let volume = MockOutputVolumeController()
        let microphone = MockMeetingMicrophoneController()
        let policy = PolicyBox()
        let coordinator = makeCoordinator(volume: volume, microphone: microphone, policy: policy)
        var changes: [MeetingAssistCoordinator.MicrophoneChange] = []
        coordinator.onMicrophoneChange = { changes.append($0) }

        coordinator.handleActivity(sources: meetingAndDictationSources)
        coordinator.handleActivity(sources: [source("com.microsoft.teams2", name: "Teams")])
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(changes, [.muted, .unmuted])

        microphone.alreadyMuted.insert(teams)
        coordinator.handleActivity(sources: meetingAndDictationSources)
        coordinator.handleActivity(sources: [])
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(changes, [.muted, .unmuted])
    }

    func testMutingMeetingCanRemoveItsCaptureProcessWithoutUndoingMute() async {
        let volume = MockOutputVolumeController()
        let microphone = MockMeetingMicrophoneController()
        let policy = PolicyBox()
        let coordinator = makeCoordinator(volume: volume, microphone: microphone, policy: policy)

        coordinator.handleActivity(sources: meetingAndDictationSources)
        coordinator.handleActivity(sources: [source("com.openai.codex", name: "ChatGPT")])
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertTrue(coordinator.isActive)
        XCTAssertEqual(microphone.ownedApplications, [teams])
        XCTAssertTrue(microphone.restoreCalls.isEmpty)
        XCTAssertEqual(volume.restoreCount, 0)

        coordinator.handleActivity(sources: [])
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertFalse(coordinator.isActive)
        XCTAssertEqual(microphone.restoreCalls, [teams])
        XCTAssertEqual(volume.restoreCount, 1)
    }

    func testAlreadyMutedMeetingIsNotOwnedOrUnmuted() async {
        let volume = MockOutputVolumeController()
        let microphone = MockMeetingMicrophoneController()
        microphone.alreadyMuted.insert(teams)
        let policy = PolicyBox()
        let coordinator = makeCoordinator(volume: volume, microphone: microphone, policy: policy)

        coordinator.handleActivity(sources: meetingAndDictationSources)
        coordinator.handleActivity(sources: [])
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertTrue(microphone.restoreCalls.isEmpty)
    }

    func testMissingAccessibilityStillDucksButReportsAttention() {
        let volume = MockOutputVolumeController()
        let microphone = MockMeetingMicrophoneController()
        microphone.permissionStatus = .required
        let policy = PolicyBox()
        let coordinator = makeCoordinator(volume: volume, microphone: microphone, policy: policy)

        coordinator.handleActivity(sources: meetingAndDictationSources)

        XCTAssertEqual(volume.duckLevels, [0.25])
        XCTAssertTrue(microphone.muteCalls.isEmpty)
        guard case .attention(let detail) = coordinator.state else {
            return XCTFail("Expected an Accessibility warning")
        }
        XCTAssertTrue(detail.contains("Accessibility"))
    }

    func testChangingReducedVolumeWhileActiveReappliesDuck() {
        let volume = MockOutputVolumeController()
        let microphone = MockMeetingMicrophoneController()
        let policy = PolicyBox()
        let coordinator = makeCoordinator(volume: volume, microphone: microphone, policy: policy)

        coordinator.handleActivity(sources: meetingAndDictationSources)
        policy.value = MeetingAssistPolicy(
            enabled: true,
            lowerAudio: true,
            reducedVolume: 0.10,
            muteMeetingMicrophone: true,
            releaseDelay: .milliseconds(350)
        )
        coordinator.settingsDidChange()

        XCTAssertEqual(volume.duckLevels, [0.25, 0.10])
        XCTAssertEqual(volume.restoreCount, 1)
        XCTAssertTrue(coordinator.isActive)
    }

    func testFeedbackSoundsContainPlayableLocalWaveAudio() {
        for cue in [FeedbackCue.lowered, .restored] {
            let data = FeedbackSoundPlayer.waveData(for: cue)
            XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "RIFF")
            XCTAssertGreaterThan(data.count, 44)
            XCTAssertNotNil(NSSound(data: data))
        }
    }

    private var teams: MeetingApplication {
        MeetingApplication(bundleIdentifier: "com.microsoft.teams2", name: "Microsoft Teams")
    }

    private var meetingAndDictationSources: [CaptureSource] {
        [
            source("com.microsoft.teams2", name: "Teams"),
            source("com.openai.codex", name: "ChatGPT"),
        ]
    }

    private func makeCoordinator(
        volume: MockOutputVolumeController,
        microphone: MockMeetingMicrophoneController,
        policy: PolicyBox
    ) -> MeetingAssistCoordinator {
        MeetingAssistCoordinator(
            volumeController: volume,
            microphoneController: microphone,
            policyProvider: { policy.value }
        )
    }

    private func source(
        _ identifier: String,
        name: String,
        kind: CaptureSource.Kind = .application
    ) -> CaptureSource {
        CaptureSource(identifier: identifier, name: name, kind: kind)
    }

    private func microphoneMatch(
        _ value: String,
        isEnabled: Bool = true
    ) -> (action: MeetingMicrophoneAction, score: Int)? {
        AccessibilityControlClassifier.microphoneAction(
            for: AccessibilityControlDescriptor(
                role: "AXButton",
                strings: [value],
                isEnabled: isEnabled,
                canPress: true
            )
        )
    }

    private func activeCallMatch(_ value: String, isEnabled: Bool = true) -> Int? {
        AccessibilityControlClassifier.indicatesActiveCall(
            AccessibilityControlDescriptor(
                role: "AXButton",
                strings: [value],
                isEnabled: isEnabled,
                canPress: true
            )
        )
    }
}

@MainActor
private final class PolicyBox {
    var value = MeetingAssistPolicy(
        enabled: true,
        lowerAudio: true,
        reducedVolume: 0.25,
        muteMeetingMicrophone: true,
        releaseDelay: .milliseconds(350)
    )
}

@MainActor
private final class MockOutputVolumeController: OutputVolumeControlling {
    private(set) var duckLevels: [Float] = []
    private(set) var restoreCount = 0
    private(set) var isDucked = false

    func duck(to level: Float) throws -> Bool {
        guard !isDucked else { return true }
        duckLevels.append(level)
        isDucked = true
        return true
    }

    func restore() throws {
        guard isDucked else { return }
        restoreCount += 1
        isDucked = false
    }
}

@MainActor
private final class MockMeetingMicrophoneController: MeetingMicrophoneControlling {
    var permissionStatus: AccessibilityPermissionStatus = .granted
    var alreadyMuted: Set<MeetingApplication> = []
    private(set) var ownedApplications: Set<MeetingApplication> = []
    private(set) var muteCalls: [MeetingApplication] = []
    private(set) var restoreCalls: [MeetingApplication] = []

    func muteIfNeeded(_ application: MeetingApplication) -> MeetingMuteResult {
        muteCalls.append(application)
        if alreadyMuted.contains(application) { return .alreadyMuted }
        ownedApplications.insert(application)
        return .mutedByUtility
    }

    func restoreIfOwned(_ application: MeetingApplication) -> MeetingUnmuteResult {
        guard ownedApplications.remove(application) != nil else { return .notOwned }
        restoreCalls.append(application)
        return .restored
    }
}
