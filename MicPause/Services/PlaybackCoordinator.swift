import Combine
import Foundation

@MainActor
final class PlaybackCoordinator: ObservableObject {
    typealias ResumePolicy = @MainActor () -> (automatically: Bool, delay: Duration)

    /// Prevents an audio client from forming a feedback loop with Music.
    ///
    /// Some clients stop their input stream when Music pauses, then reopen it
    /// after Music resumes. A normal short resume delay lets that cycle repeat
    /// forever. Once capture reappears shortly after an automatic resume, wait
    /// for one continuous quiet period before trying playback again.
    static let rapidReactivationWindow = Duration.seconds(45)
    static let rapidReactivationQuietPeriod = Duration.seconds(45)

    @Published private(set) var state: MonitoringState = .disabled
    private(set) var pausedByUs = false

    private let player: any MusicPlayerControlling
    private let resumePolicy: ResumePolicy
    private let sleep: @Sendable (Duration) async throws -> Void

    private var monitoringEnabled = false
    private var microphoneIsActive = false
    private var transitionGeneration = 0
    private var playerObservationTask: Task<Void, Never>?
    private var cleanupTask: Task<Void, Never>?
    private var lastAutomaticResumeAt: ContinuousClock.Instant?
    private var rapidReactivationDetected = false

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

            if let lastAutomaticResumeAt,
               lastAutomaticResumeAt.duration(to: .now) <= Self.rapidReactivationWindow {
                if !rapidReactivationDetected {
                    Log.playback.notice(
                        "Microphone reactivated soon after playback resumed; waiting for a stable quiet period"
                    )
                }
                rapidReactivationDetected = true
            } else if !pausedByUs {
                // A later, unrelated activation starts a fresh cycle.
                rapidReactivationDetected = false
            }

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

            let resumeDelay = rapidReactivationDetected
                ? max(policy.delay, Self.rapidReactivationQuietPeriod)
                : policy.delay

            do {
                try await sleep(resumeDelay)
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
                lastAutomaticResumeAt = .now
                Log.playback.info("Resumed Apple Music after microphone became inactive")
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
        playerObservationTask?.cancel()
        playerObservationTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(750))
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
