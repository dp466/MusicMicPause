import Foundation
import Observation

@MainActor
@Observable
final class PlaybackCoordinator {
    typealias ResumePolicy = @MainActor () -> (automatically: Bool, delay: Duration)

    enum PlaybackChange: Equatable, Sendable {
        case paused
        case resumed
    }

    @ObservationIgnored var onPlaybackChange: (@MainActor (PlaybackChange) -> Void)?

    /// How often the coordinator re-reads Apple Music while it owns a pause.
    ///
    /// This only keeps the displayed state honest when playback is changed from
    /// somewhere else — the resume path re-reads the player before acting, so
    /// correctness never depends on this interval.
    private static let observationInterval = Duration.seconds(2)

    private(set) var state: MonitoringState = .disabled
    @ObservationIgnored private(set) var pausedByUs = false

    @ObservationIgnored private let player: any MusicPlayerControlling
    @ObservationIgnored private let resumePolicy: ResumePolicy
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void

    @ObservationIgnored private var monitoringEnabled = false
    @ObservationIgnored private var microphoneIsActive = false
    @ObservationIgnored private var transitionGeneration = 0
    @ObservationIgnored private var playerObservationTask: Task<Void, Never>?
    @ObservationIgnored private var cleanupTask: Task<Void, Never>?

    init(
        player: any MusicPlayerControlling,
        resumePolicy: @escaping ResumePolicy,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { duration in
            try await Task.sleep(for: duration)
        }
    ) {
        self.player = player
        self.resumePolicy = resumePolicy
        self.sleep = sleep
    }

    deinit {
        playerObservationTask?.cancel()
        cleanupTask?.cancel()
    }

    func setMonitoringEnabled(_ enabled: Bool) {
        guard monitoringEnabled != enabled else { return }

        monitoringEnabled = enabled
        transitionGeneration += 1
        cleanupTask?.cancel()
        cleanupTask = nil

        guard enabled else {
            microphoneIsActive = false
            stopPlayerObservation()
            state = .disabled

            guard pausedByUs else { return }
            let generation = transitionGeneration
            cleanupTask = Task { [weak self] in
                await self?.releaseOwnedPause(
                    for: generation,
                    expectedMonitoringEnabled: false
                )
            }
            return
        }

        if state == .disabled {
            state = .micInactive
        }
    }

    func handleMicrophoneStatus(_ status: MicrophoneStatus) async {
        guard monitoringEnabled else { return }

        switch status {
        case .unavailable(let reason):
            microphoneIsActive = false
            transitionGeneration += 1
            stopPlayerObservation()
            state = .unavailable(reason)

        case .active:
            guard !microphoneIsActive || state.isUnavailable else { return }

            microphoneIsActive = true
            transitionGeneration += 1
            cleanupTask?.cancel()
            cleanupTask = nil
            let generation = transitionGeneration

            if pausedByUs {
                state = .pausedByUtility
                startPlayerObservation()
                return
            }

            state = .micActive
            do {
                let currentState = try await player.playerState()
                guard isCurrentActiveTransition(generation) else { return }
                guard currentState == .playing else { return }

                try await player.pause()
                pausedByUs = true

                guard isCurrentActiveTransition(generation) else {
                    await compensateForStalePause()
                    return
                }

                state = .pausedByUtility
                startPlayerObservation()
                Log.playback.info("Paused Apple Music for a microphone activation cycle")
                onPlaybackChange?(.paused)
            } catch {
                guard isCurrentActiveTransition(generation) else { return }
                state = .unavailable(error.localizedDescription)
                Log.playback.error(
                    "Could not pause Apple Music: \(error.localizedDescription, privacy: .private)"
                )
            }

        case .inactive:
            guard microphoneIsActive || state.isUnavailable else { return }
            microphoneIsActive = false
            transitionGeneration += 1
            let generation = transitionGeneration
            stopPlayerObservation()
            state = .micInactive

            guard pausedByUs else { return }
            let policy = resumePolicy()
            guard policy.automatically else {
                pausedByUs = false
                return
            }

            do {
                try await sleep(policy.delay)
                guard isCurrentInactiveTransition(generation) else { return }
                guard resumePolicy().automatically else {
                    pausedByUs = false
                    return
                }

                let currentState = try await player.playerState()
                guard isCurrentInactiveTransition(generation) else { return }
                guard currentState == .paused else {
                    pausedByUs = false
                    return
                }

                try await player.play()
                guard isCurrentInactiveTransition(generation) else {
                    await compensateForStaleResume()
                    return
                }

                pausedByUs = false
                Log.playback.info("Resumed Apple Music after microphone became inactive")
                onPlaybackChange?(.resumed)
            } catch is CancellationError {
                return
            } catch {
                guard isCurrentInactiveTransition(generation) else { return }
                pausedByUs = false
                state = .unavailable(error.localizedDescription)
                Log.playback.error(
                    "Could not resume Apple Music: \(error.localizedDescription, privacy: .private)"
                )
            }
        }
    }

    func reconcilePlayerState() async {
        guard monitoringEnabled, microphoneIsActive, pausedByUs else { return }
        let generation = transitionGeneration

        do {
            let currentState = try await player.playerState()
            guard isCurrentActiveTransition(generation), pausedByUs else { return }

            if currentState == .playing {
                pausedByUs = false
                state = .micActive
                stopPlayerObservation()
                Log.playback.info(
                    "Detected a manual resume; leaving playback alone for this activation cycle"
                )
            }
        } catch {
            Log.playback.debug(
                "Player-state reconciliation failed: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    /// Restores playback when possible before the process exits.
    func shutdown() async {
        monitoringEnabled = false
        microphoneIsActive = false
        transitionGeneration += 1
        let generation = transitionGeneration
        stopPlayerObservation()
        state = .disabled

        cleanupTask?.cancel()
        cleanupTask = nil
        guard pausedByUs else { return }
        await releaseOwnedPause(
            for: generation,
            expectedMonitoringEnabled: false
        )
    }

    private func releaseOwnedPause(
        for generation: Int,
        expectedMonitoringEnabled: Bool
    ) async {
        do {
            let currentState = try await player.playerState()
            guard isCurrentTransition(
                generation,
                expectedMonitoringEnabled: expectedMonitoringEnabled
            ) else { return }

            guard currentState == .paused else {
                pausedByUs = false
                return
            }

            try await player.play()
            guard isCurrentTransition(
                generation,
                expectedMonitoringEnabled: expectedMonitoringEnabled
            ) else {
                await compensateForStaleResume()
                return
            }

            pausedByUs = false
            Log.playback.info("Restored Apple Music playback while stopping monitoring")
            onPlaybackChange?(.resumed)
        } catch {
            guard isCurrentTransition(
                generation,
                expectedMonitoringEnabled: expectedMonitoringEnabled
            ) else { return }
            Log.playback.error(
                "Could not restore Apple Music playback: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    private func compensateForStalePause() async {
        guard pausedByUs else { return }

        if monitoringEnabled, microphoneIsActive {
            state = .pausedByUtility
            startPlayerObservation()
            return
        }

        let generation = transitionGeneration
        await releaseOwnedPause(
            for: generation,
            expectedMonitoringEnabled: monitoringEnabled
        )
    }

    private func compensateForStaleResume() async {
        guard monitoringEnabled, microphoneIsActive, pausedByUs else { return }
        let generation = transitionGeneration

        do {
            guard try await player.playerState() == .playing,
                  isCurrentActiveTransition(generation),
                  pausedByUs else { return }
            try await player.pause()
            guard isCurrentActiveTransition(generation) else {
                await compensateForStalePause()
                return
            }
            state = .pausedByUtility
            startPlayerObservation()
            Log.playback.info("Re-paused Apple Music after a stale resume completed")
        } catch {
            guard isCurrentActiveTransition(generation) else { return }
            state = .unavailable(error.localizedDescription)
            Log.playback.error(
                "Could not compensate for a stale resume: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    private func isCurrentTransition(
        _ generation: Int,
        expectedMonitoringEnabled: Bool
    ) -> Bool {
        generation == transitionGeneration
            && monitoringEnabled == expectedMonitoringEnabled
    }

    private func isCurrentActiveTransition(_ generation: Int) -> Bool {
        generation == transitionGeneration
            && monitoringEnabled
            && microphoneIsActive
    }

    private func isCurrentInactiveTransition(_ generation: Int) -> Bool {
        generation == transitionGeneration
            && monitoringEnabled
            && !microphoneIsActive
            && pausedByUs
    }

    private func startPlayerObservation() {
        guard playerObservationTask == nil else { return }
        playerObservationTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(
                        for: Self.observationInterval,
                        tolerance: .milliseconds(400)
                    )
                } catch {
                    return
                }
                guard !Task.isCancelled, let self else { return }
                await self.reconcilePlayerState()
            }
        }
    }

    private func stopPlayerObservation() {
        playerObservationTask?.cancel()
        playerObservationTask = nil
    }
}

private extension MonitoringState {
    var isUnavailable: Bool {
        if case .unavailable = self { true } else { false }
    }
}
