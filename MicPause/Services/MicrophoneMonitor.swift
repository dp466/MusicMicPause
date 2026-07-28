import Combine
import CoreAudio
import Foundation

@MainActor
final class MicrophoneMonitor: ObservableObject, @unchecked Sendable {
    @Published private(set) var deviceName = "No input device"
    @Published private(set) var status: MicrophoneStatus = .unavailable("Monitoring unavailable")

    var onStatusChange: (@MainActor (MicrophoneStatus) -> Void)?

    private let listenerQueue = DispatchQueue(label: "com.dparadis.MicPause.core-audio")
    private let debounceDuration: Duration
    private var defaultDeviceListener: AudioObjectPropertyListenerBlock?
    private var runningListener: AudioObjectPropertyListenerBlock?
    private var currentDeviceID = AudioObjectID(kAudioObjectUnknown)
    private var runningAddress: AudioObjectPropertyAddress?
    private var debounceTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var started = false

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
        refreshTask?.cancel()
        refreshTask = nil
        removeDeviceListener()
        removeDefaultDeviceListener()
        publish(.unavailable("Monitoring disabled"))
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
            deviceName = (try? Self.deviceName(for: deviceID)) ?? "Unknown microphone"
            runningAddress = Self.runningStateAddress

            installRunningListener()
            scheduleRunningStateRead()
            Log.microphone.info("Monitoring the current default input device")
        } catch {
            currentDeviceID = AudioObjectID(kAudioObjectUnknown)
            deviceName = "No input device"
            publish(.unavailable(error.localizedDescription))
            Log.microphone.error(
                "Could not bind the default input device: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    private func startPeriodicRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
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

            scheduleRunningStateRead()
        } catch {
            publish(.unavailable(error.localizedDescription))
        }
    }

    private func installRunningListener() {
        guard currentDeviceID != kAudioObjectUnknown, var address = runningAddress else { return }
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
        guard currentDeviceID != kAudioObjectUnknown,
              var address = runningAddress,
              let runningListener else {
            currentDeviceID = AudioObjectID(kAudioObjectUnknown)
            runningAddress = nil
            return
        }

        AudioObjectRemovePropertyListenerBlock(
            currentDeviceID,
            &address,
            listenerQueue,
            runningListener
        )
        self.runningListener = nil
        currentDeviceID = AudioObjectID(kAudioObjectUnknown)
        runningAddress = nil
    }

    private func scheduleRunningStateRead() {
        guard started else { return }
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: debounceDuration)
                guard !Task.isCancelled else { return }
                try readAndPublishRunningState()
            } catch is CancellationError {
                return
            } catch {
                publish(.unavailable(error.localizedDescription))
            }
        }
    }

    private func readAndPublishRunningState() throws {
        guard currentDeviceID != kAudioObjectUnknown, let runningAddress else {
            throw CoreAudioMonitorError.noDefaultInput
        }
        let running: UInt32 = try Self.readProperty(
            objectID: currentDeviceID,
            address: runningAddress
        )
        publish(running == 0 ? .inactive : .active)
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

    private static var defaultInputAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    static var runningStateAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

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
