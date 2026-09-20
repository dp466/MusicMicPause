import CoreAudio
import Foundation
import Observation

@MainActor
@Observable
final class MicrophoneMonitor {
    private(set) var deviceName = "No input device"
    private(set) var status: MicrophoneStatus = .unavailable("Monitoring unavailable")

    /// Everything Core Audio reports as capturing, ignored or not, so the
    /// settings window can offer them.
    private(set) var captureSources: [CaptureSource] = []

    @ObservationIgnored var onStatusChange: (@MainActor (MicrophoneStatus) -> Void)?

    /// Decides whether a capturing process should pause playback.
    @ObservationIgnored var shouldIgnoreSource: (@MainActor (CaptureSource) -> Bool)?

    @ObservationIgnored private let listenerQueue = DispatchQueue(
        label: "com.dparadis.MicPause.core-audio"
    )
    @ObservationIgnored private let debounceDuration: Duration
    @ObservationIgnored private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
    @ObservationIgnored private var runningListener: AudioObjectPropertyListenerBlock?
    @ObservationIgnored private var currentDeviceID = AudioObjectID(kAudioObjectUnknown)
    @ObservationIgnored private var isBoundToDevice = false
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var started = false

    init(debounceDuration: Duration = .milliseconds(250)) {
        self.debounceDuration = debounceDuration
    }

    func start() {
        guard !started else { return }
        started = true
        installDefaultDeviceListener()
        rebindDefaultInputDevice()
        startPeriodicRefresh()
    }

    func stop() {
        guard started else { return }
        started = false
        debounceTask?.cancel()
        debounceTask = nil
        refreshTask?.cancel()
        refreshTask = nil
        removeDeviceListener()
        removeDefaultDeviceListener()
        publish(.unavailable("Monitoring disabled"))
    }

    /// Re-evaluates immediately, for when the ignore rules change underneath.
    func reevaluate() {
        guard started else { return }
        debounceTask?.cancel()
        debounceTask = nil
        do {
            try readAndPublishRunningState()
        } catch {
            publish(.unavailable(error.localizedDescription))
        }
    }

    private func installDefaultDeviceListener() {
        var address = Self.defaultInputAddress
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.rebindDefaultInputDevice()
            }
        }

        let result = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            listenerQueue,
            block
        )

        guard result == noErr else {
            publish(.unavailable("Could not observe input-device changes"))
            Log.microphone.error("Default-device listener failed with OSStatus \(result)")
            return
        }
        defaultDeviceListener = block
    }

    private func removeDefaultDeviceListener() {
        guard let defaultDeviceListener else { return }
        var address = Self.defaultInputAddress
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            listenerQueue,
            defaultDeviceListener
        )
        self.defaultDeviceListener = nil
    }

    private func rebindDefaultInputDevice() {
        guard started else { return }
        debounceTask?.cancel()
        debounceTask = nil
        removeDeviceListener()

        do {
            let deviceID: AudioObjectID = try Self.readProperty(
                objectID: AudioObjectID(kAudioObjectSystemObject),
                address: Self.defaultInputAddress
            )
            guard deviceID != kAudioObjectUnknown else {
                throw CoreAudioMonitorError.noDefaultInput
            }

            currentDeviceID = deviceID
            isBoundToDevice = true
            deviceName = (try? Self.deviceName(for: deviceID)) ?? "Unknown microphone"

            installRunningListener()
            scheduleRunningStateRead()
            Log.microphone.info("Monitoring the current default input device")
        } catch {
            currentDeviceID = AudioObjectID(kAudioObjectUnknown)
            isBoundToDevice = false
            deviceName = "No input device"
            publish(.unavailable(error.localizedDescription))
            Log.microphone.error(
                "Could not bind the default input device: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    /// A safety net for the rare case where Core Audio does not deliver a
    /// property notification. Each tick also refreshes the system-wide capture process list.
    private func startPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    // Tolerance lets the system coalesce this wake-up with
                    // others instead of firing its own precise timer.
                    try await Task.sleep(for: .seconds(1), tolerance: .milliseconds(250))
                } catch {
                    return
                }

                guard !Task.isCancelled, let self, self.started else { return }
                self.refreshBindingAndRunningState()
            }
        }
    }

    private func refreshBindingAndRunningState() {
        do {
            let defaultDeviceID: AudioObjectID = try Self.readProperty(
                objectID: AudioObjectID(kAudioObjectSystemObject),
                address: Self.defaultInputAddress
            )

            guard defaultDeviceID == currentDeviceID else {
                rebindDefaultInputDevice()
                return
            }

            // The poll is already coarse, so it reads directly rather than
            // spawning another debounce task every second. Bursts arriving
            // through the property listener stay debounced.
            guard debounceTask == nil else { return }
            try readAndPublishRunningState()
        } catch {
            publish(.unavailable(error.localizedDescription))
        }
    }

    private func installRunningListener() {
        guard isBoundToDevice else { return }
        var address = Self.runningStateAddress
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.scheduleRunningStateRead()
            }
        }

        let result = AudioObjectAddPropertyListenerBlock(
            currentDeviceID,
            &address,
            listenerQueue,
            block
        )

        guard result == noErr else {
            publish(.unavailable("Microphone activity is unavailable"))
            Log.microphone.error("Running-state listener failed with OSStatus \(result)")
            return
        }
        runningListener = block
    }

    private func removeDeviceListener() {
        defer {
            currentDeviceID = AudioObjectID(kAudioObjectUnknown)
            isBoundToDevice = false
        }
        guard isBoundToDevice, let runningListener else { return }

        var address = Self.runningStateAddress
        AudioObjectRemovePropertyListenerBlock(
            currentDeviceID,
            &address,
            listenerQueue,
            runningListener
        )
        self.runningListener = nil
    }

    private func scheduleRunningStateRead() {
        guard started else { return }

        // Leading edge: a microphone going hot has to reach the menu bar right
        // away, so the first notification of a burst is read immediately rather
        // than behind the debounce. Only a reading that already names the
        // capturing processes may act this early — an unresolved one would
        // pause playback the ignore rules exclude and then undo it a fraction
        // of a second later.
        if debounceTask == nil, (try? readRunningState()) == .active {
            publish(.active)
        }

        // Trailing edge: the settled state of the burst still decides. This is
        // what turns the microphone back off, resolves a late process list, and
        // reports a read failure.
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self else { return }
            defer { if !Task.isCancelled { debounceTask = nil } }
            do {
                try await Task.sleep(for: debounceDuration)
                try readAndPublishRunningState()
            } catch is CancellationError {
                return
            } catch {
                publish(.unavailable(error.localizedDescription))
            }
        }
    }

    /// What a single reading of the running state concluded.
    private enum RunningStateReading: Equatable {
        case active
        case inactive
        /// Something is capturing, but Core Audio has not named the processes
        /// yet, so the ignore rules cannot be applied to it.
        case unresolved
    }

    private func readRunningState() throws -> RunningStateReading {
        guard isBoundToDevice else {
            throw CoreAudioMonitorError.noDefaultInput
        }
        let running: UInt32 = try Self.readProperty(
            objectID: currentDeviceID,
            address: Self.runningStateAddress
        )

        // Process capture is system-wide: an app can select a microphone other
        // than the default. The default-device flag is only a fallback when
        // Core Audio cannot attribute capture to a process.
        let sources = AudioCaptureInspector.capturingSources()
        if sources != captureSources {
            captureSources = sources
        }
        guard !sources.isEmpty else {
            return running != 0 ? .unresolved : .inactive
        }

        Log.microphone.debug(
            "Capturing: \(sources.map(\.identifier).joined(separator: ", "), privacy: .private)"
        )
        return sources.contains { !(shouldIgnoreSource?($0) ?? false) }
            ? .active
            : .inactive
    }

    private func readAndPublishRunningState() throws {
        switch try readRunningState() {
        case .active:
            publish(.active)
        case .inactive:
            publish(.inactive)
        case .unresolved:
            // Core Audio would not name the processes; fall back to trusting
            // the device flag rather than missing a real call.
            publish(.active)
        }
    }

    private func publish(_ newStatus: MicrophoneStatus) {
        guard status != newStatus else { return }
        status = newStatus
        switch newStatus {
        case .inactive:
            Log.microphone.info("Microphone activity changed to inactive")
        case .active:
            Log.microphone.info("Microphone activity changed to active")
        case .unavailable(let reason):
            Log.microphone.error(
                "Microphone monitoring unavailable: \(reason, privacy: .private)"
            )
        }
        onStatusChange?(newStatus)
    }

    private static let defaultInputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    static let runningStateAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    private static func deviceName(for deviceID: AudioObjectID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let result = withUnsafeMutablePointer(to: &name) {
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, $0)
        }
        guard result == noErr else {
            throw CoreAudioMonitorError.osStatus(result)
        }
        return name as String
    }

    private static func readProperty<T: FixedWidthInteger>(
        objectID: AudioObjectID,
        address: AudioObjectPropertyAddress
    ) throws -> T {
        var mutableAddress = address
        var value: T = 0
        var size = UInt32(MemoryLayout<T>.size)
        let result = AudioObjectGetPropertyData(
            objectID,
            &mutableAddress,
            0,
            nil,
            &size,
            &value
        )
        guard result == noErr else {
            throw CoreAudioMonitorError.osStatus(result)
        }
        return value
    }
}

private enum CoreAudioMonitorError: LocalizedError {
    case noDefaultInput
    case osStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .noDefaultInput:
            "No default microphone is available"
        case .osStatus(let status):
            "Core Audio error \(status)"
        }
    }
}
