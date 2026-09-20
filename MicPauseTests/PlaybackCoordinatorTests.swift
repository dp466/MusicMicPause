import XCTest
import CoreAudio
import Observation
@testable import MicPause

@MainActor
final class PlaybackCoordinatorTests: XCTestCase {
    func testMicrophoneRunningStateUsesGlobalDeviceScope() {
        let address = MicrophoneMonitor.runningStateAddress

        XCTAssertEqual(address.mSelector, kAudioDevicePropertyDeviceIsRunningSomewhere)
        XCTAssertEqual(address.mScope, kAudioObjectPropertyScopeGlobal)
        XCTAssertEqual(address.mElement, kAudioObjectPropertyElementMain)
    }

    func testAutomationPermissionStatusMapping() {
        XCTAssertEqual(AppleMusicController.permissionStatus(for: noErr), .granted)
        XCTAssertEqual(AppleMusicController.permissionStatus(for: -1743), .denied)
        XCTAssertEqual(AppleMusicController.permissionStatus(for: -1744), .notDetermined)
        XCTAssertEqual(
            AppleMusicController.permissionStatus(for: -600),
            .unavailable("Status -600")
        )
    }

    func testPlayingMusicPausesAndResumes() async throws {
        let player = MockMusicPlayer(state: .playing)
        let coordinator = makeCoordinator(player: player)

        coordinator.setMonitoringEnabled(true)
        await coordinator.handleMicrophoneStatus(.active)
        XCTAssertEqual(coordinator.state, .pausedByUtility)
        XCTAssertTrue(coordinator.pausedByUs)

        await coordinator.handleMicrophoneStatus(.inactive)
        let snapshot = await player.snapshot()
        XCTAssertEqual(snapshot.pauseCount, 1)
        XCTAssertEqual(snapshot.playCount, 1)
        XCTAssertEqual(snapshot.state, .playing)
        XCTAssertFalse(coordinator.pausedByUs)
    }

    func testAlreadyPausedMusicRemainsPaused() async {
        let player = MockMusicPlayer(state: .paused)
        let coordinator = makeCoordinator(player: player)

        coordinator.setMonitoringEnabled(true)
        await coordinator.handleMicrophoneStatus(.active)
        await coordinator.handleMicrophoneStatus(.inactive)

        let snapshot = await player.snapshot()
        XCTAssertEqual(snapshot.pauseCount, 0)
        XCTAssertEqual(snapshot.playCount, 0)
        XCTAssertEqual(snapshot.state, .paused)
    }

    func testManualResumeDuringActiveCycleIsLeftAlone() async {
        let player = MockMusicPlayer(state: .playing)
        let coordinator = makeCoordinator(player: player)

        coordinator.setMonitoringEnabled(true)
        await coordinator.handleMicrophoneStatus(.active)
        await player.setState(.playing)
        await coordinator.reconcilePlayerState()
        await coordinator.handleMicrophoneStatus(.inactive)

        let snapshot = await player.snapshot()
        XCTAssertEqual(snapshot.pauseCount, 1)
        XCTAssertEqual(snapshot.playCount, 0)
        XCTAssertFalse(coordinator.pausedByUs)
    }

    func testManualResumeThenPauseIsNotResumedAtMicEnd() async {
        let player = MockMusicPlayer(state: .playing)
        let coordinator = makeCoordinator(player: player)

        coordinator.setMonitoringEnabled(true)
        await coordinator.handleMicrophoneStatus(.active)
        await player.setState(.playing)
        await coordinator.reconcilePlayerState()
        await player.setState(.paused)
        await coordinator.handleMicrophoneStatus(.inactive)

        let snapshot = await player.snapshot()
        XCTAssertEqual(snapshot.playCount, 0)
        XCTAssertEqual(snapshot.state, .paused)
    }

    func testInputDeviceChangeWhileActiveDoesNotDoublePause() async {
        let player = MockMusicPlayer(state: .playing)
        let coordinator = makeCoordinator(player: player)

        coordinator.setMonitoringEnabled(true)
        await coordinator.handleMicrophoneStatus(.active)
        await coordinator.handleMicrophoneStatus(.unavailable("Changing microphone"))
        await coordinator.handleMicrophoneStatus(.active)
        await coordinator.handleMicrophoneStatus(.inactive)

        let snapshot = await player.snapshot()
        XCTAssertEqual(snapshot.pauseCount, 1)
        XCTAssertEqual(snapshot.playCount, 1)
    }

    func testRepeatedNotificationsAreIdempotent() async {
        let player = MockMusicPlayer(state: .playing)
        let coordinator = makeCoordinator(player: player)

        coordinator.setMonitoringEnabled(true)
        await coordinator.handleMicrophoneStatus(.active)
        await coordinator.handleMicrophoneStatus(.active)
        await coordinator.handleMicrophoneStatus(.active)
        await coordinator.handleMicrophoneStatus(.inactive)
        await coordinator.handleMicrophoneStatus(.inactive)

        let snapshot = await player.snapshot()
        XCTAssertEqual(snapshot.pauseCount, 1)
        XCTAssertEqual(snapshot.playCount, 1)
    }

    func testUnavailablePlayerProducesUnavailableState() async {
        let player = MockMusicPlayer(state: .playing)
        await player.setError(.automationDenied)
        let coordinator = makeCoordinator(player: player)

        coordinator.setMonitoringEnabled(true)
        await coordinator.handleMicrophoneStatus(.active)

        XCTAssertEqual(
            coordinator.state,
            .unavailable(MusicPlayerError.automationDenied.localizedDescription)
        )
        let snapshot = await player.snapshot()
        XCTAssertEqual(snapshot.pauseCount, 0)
    }

    func testActiveMicrophoneRetriesAfterAutomationBecomesAvailable() async {
        let player = MockMusicPlayer(state: .playing)
        await player.setError(.automationDenied)
        let coordinator = makeCoordinator(player: player)

        coordinator.setMonitoringEnabled(true)
        await coordinator.handleMicrophoneStatus(.active)
        await player.setError(nil)
        await coordinator.handleMicrophoneStatus(.active)

        let snapshot = await player.snapshot()
        XCTAssertEqual(snapshot.pauseCount, 1)
        XCTAssertEqual(snapshot.state, .paused)
        XCTAssertEqual(coordinator.state, .pausedByUtility)
    }

    func testDisablingMonitoringRestoresOwnedPause() async {
        let player = MockMusicPlayer(state: .playing)
        let coordinator = makeCoordinator(player: player)

        coordinator.setMonitoringEnabled(true)
        await coordinator.handleMicrophoneStatus(.active)
        coordinator.setMonitoringEnabled(false)

        await waitUntil {
            await player.snapshot().playCount == 1
        }
        let snapshot = await player.snapshot()
        XCTAssertEqual(snapshot.pauseCount, 1)
        XCTAssertEqual(snapshot.playCount, 1)
        XCTAssertEqual(snapshot.state, .playing)
        XCTAssertEqual(coordinator.state, .disabled)
        XCTAssertFalse(coordinator.pausedByUs)
    }

    func testDisablingMonitoringDoesNotResumeUserPause() async {
        let player = MockMusicPlayer(state: .paused)
        let coordinator = makeCoordinator(player: player)

        coordinator.setMonitoringEnabled(true)
        await coordinator.handleMicrophoneStatus(.active)
        coordinator.setMonitoringEnabled(false)
        await Task.yield()

        let snapshot = await player.snapshot()
        XCTAssertEqual(snapshot.pauseCount, 0)
        XCTAssertEqual(snapshot.playCount, 0)
        XCTAssertEqual(snapshot.state, .paused)
    }

    func testShutdownRestoresOwnedPause() async {
        let player = MockMusicPlayer(state: .playing)
        let coordinator = makeCoordinator(player: player)

        coordinator.setMonitoringEnabled(true)
        await coordinator.handleMicrophoneStatus(.active)
        await coordinator.shutdown()

        let snapshot = await player.snapshot()
        XCTAssertEqual(snapshot.pauseCount, 1)
        XCTAssertEqual(snapshot.playCount, 1)
        XCTAssertEqual(snapshot.state, .playing)
        XCTAssertFalse(coordinator.pausedByUs)
    }

    func testInactiveTransitionCannotResumeAfterMicrophoneReactivates() async {
        let player = ControlledMusicPlayer(state: .playing)
        let coordinator = PlaybackCoordinator(
            player: player,
            resumePolicy: { (true, .zero) },
            sleep: { _ in }
        )

        coordinator.setMonitoringEnabled(true)
        await coordinator.handleMicrophoneStatus(.active)
        await player.blockNext(.playerState)

        async let inactive: Void = coordinator.handleMicrophoneStatus(.inactive)
        await player.waitUntilStarted(.playerState)
        await coordinator.handleMicrophoneStatus(.active)
        await player.unblock(.playerState)
        await inactive

        let snapshot = await player.snapshot()
        XCTAssertEqual(snapshot.pauseCount, 1)
        XCTAssertEqual(snapshot.playCount, 0)
        XCTAssertEqual(snapshot.state, .paused)
        XCTAssertEqual(coordinator.state, .pausedByUtility)
        XCTAssertTrue(coordinator.pausedByUs)
    }

    func testPauseCompletingAfterMicrophoneStopsIsCompensated() async {
        let player = ControlledMusicPlayer(state: .playing)
        let coordinator = PlaybackCoordinator(
            player: player,
            resumePolicy: { (true, .zero) },
            sleep: { _ in }
        )

        coordinator.setMonitoringEnabled(true)
        await player.blockNext(.pause)

        async let active: Void = coordinator.handleMicrophoneStatus(.active)
        await player.waitUntilStarted(.pause)
        await coordinator.handleMicrophoneStatus(.inactive)
        await player.unblock(.pause)
        await active

        let snapshot = await player.snapshot()
        XCTAssertEqual(snapshot.pauseCount, 1)
        XCTAssertEqual(snapshot.playCount, 1)
        XCTAssertEqual(snapshot.state, .playing)
        XCTAssertFalse(coordinator.pausedByUs)
    }

    func testResumeCompletingAfterMicrophoneReactivatesIsCompensated() async {
        let player = ControlledMusicPlayer(state: .playing)
        let coordinator = PlaybackCoordinator(
            player: player,
            resumePolicy: { (true, .zero) },
            sleep: { _ in }
        )

        coordinator.setMonitoringEnabled(true)
        await coordinator.handleMicrophoneStatus(.active)
        await player.blockNext(.play)

        async let inactive: Void = coordinator.handleMicrophoneStatus(.inactive)
        await player.waitUntilStarted(.play)
        await coordinator.handleMicrophoneStatus(.active)
        await player.unblock(.play)
        await inactive

        let snapshot = await player.snapshot()
        XCTAssertEqual(snapshot.pauseCount, 2)
        XCTAssertEqual(snapshot.playCount, 1)
        XCTAssertEqual(snapshot.state, .paused)
        XCTAssertEqual(coordinator.state, .pausedByUtility)
        XCTAssertTrue(coordinator.pausedByUs)
    }

    /// Every other test stubs `sleep` out, so this one runs the real clock to
    /// prove the configured resume delay is actually waited out.
    func testResumeWaitsForTheConfiguredDelay() async {
        let player = MockMusicPlayer(state: .playing)
        let coordinator = PlaybackCoordinator(
            player: player,
            resumePolicy: { (true, .milliseconds(500)) }
        )

        coordinator.setMonitoringEnabled(true)
        await coordinator.handleMicrophoneStatus(.active)
        let paused = await player.snapshot()
        XCTAssertEqual(paused.pauseCount, 1)
        XCTAssertEqual(paused.playCount, 0)

        let start = ContinuousClock.now
        await coordinator.handleMicrophoneStatus(.inactive)
        let elapsed = ContinuousClock.now - start
        let resumed = await player.snapshot()

        XCTAssertEqual(resumed.playCount, 1)
        XCTAssertGreaterThan(elapsed, .milliseconds(400))
    }

    /// SwiftUI redraws off `state` through the Observation framework, so a
    /// missing notification would silently freeze the interface.
    func testStateChangeNotifiesObservers() async {
        let player = MockMusicPlayer(state: .playing)
        let coordinator = makeCoordinator(player: player)
        let notified = expectation(description: "state observation fired")

        withObservationTracking {
            _ = coordinator.state
        } onChange: {
            notified.fulfill()
        }

        coordinator.setMonitoringEnabled(true)

        await fulfillment(of: [notified], timeout: 1)
    }

    private func makeCoordinator(player: MockMusicPlayer) -> PlaybackCoordinator {
        PlaybackCoordinator(
            player: player,
            resumePolicy: { (true, .zero) },
            sleep: { _ in }
        )
    }

    private func waitUntil(
        attempts: Int = 100,
        condition: @escaping @Sendable () async -> Bool
    ) async {
        for _ in 0..<attempts {
            if await condition() { return }
            await Task.yield()
        }
        XCTFail("Condition was not satisfied")
    }
}

private actor MockMusicPlayer: MusicPlayerControlling {
    struct Snapshot: Sendable {
        let state: MusicPlayerState
        let pauseCount: Int
        let playCount: Int
    }

    private var state: MusicPlayerState
    private var error: MusicPlayerError?
    private var pauseCount = 0
    private var playCount = 0

    init(state: MusicPlayerState) {
        self.state = state
    }

    func playerState() throws -> MusicPlayerState {
        if let error { throw error }
        return state
    }

    func pause() throws {
        if let error { throw error }
        pauseCount += 1
        state = .paused
    }

    func play() throws {
        if let error { throw error }
        playCount += 1
        state = .playing
    }

    func automationPermissionStatus() -> AutomationPermissionStatus {
        error == nil ? .granted : .denied
    }

    func setState(_ state: MusicPlayerState) {
        self.state = state
    }

    func setError(_ error: MusicPlayerError?) {
        self.error = error
    }

    func snapshot() -> Snapshot {
        Snapshot(state: state, pauseCount: pauseCount, playCount: playCount)
    }
}

private actor ControlledMusicPlayer: MusicPlayerControlling {
    enum Operation: Hashable, Sendable {
        case playerState
        case pause
        case play
    }

    struct Snapshot: Sendable {
        let state: MusicPlayerState
        let pauseCount: Int
        let playCount: Int
    }

    private var state: MusicPlayerState
    private var pauseCount = 0
    private var playCount = 0
    private var blockedOperations = Set<Operation>()
    private var startedOperations = Set<Operation>()
    private var operationContinuations: [Operation: CheckedContinuation<Void, Never>] = [:]
    private var startContinuations: [Operation: [CheckedContinuation<Void, Never>]] = [:]

    init(state: MusicPlayerState) {
        self.state = state
    }

    func playerState() async -> MusicPlayerState {
        await suspendIfNeeded(.playerState)
        return state
    }

    func pause() async {
        await suspendIfNeeded(.pause)
        pauseCount += 1
        state = .paused
    }

    func play() async {
        await suspendIfNeeded(.play)
        playCount += 1
        state = .playing
    }

    func automationPermissionStatus() -> AutomationPermissionStatus {
        .granted
    }

    func blockNext(_ operation: Operation) {
        blockedOperations.insert(operation)
        startedOperations.remove(operation)
    }

    func waitUntilStarted(_ operation: Operation) async {
        if startedOperations.contains(operation) { return }
        await withCheckedContinuation { continuation in
            startContinuations[operation, default: []].append(continuation)
        }
    }

    func unblock(_ operation: Operation) {
        operationContinuations.removeValue(forKey: operation)?.resume()
    }

    func snapshot() -> Snapshot {
        Snapshot(state: state, pauseCount: pauseCount, playCount: playCount)
    }

    private func suspendIfNeeded(_ operation: Operation) async {
        guard blockedOperations.remove(operation) != nil else { return }
        startedOperations.insert(operation)
        let waiters = startContinuations.removeValue(forKey: operation) ?? []
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            operationContinuations[operation] = continuation
        }
    }
}
