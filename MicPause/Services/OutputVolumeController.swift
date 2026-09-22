import CoreAudio
import Foundation

@MainActor
protocol OutputVolumeControlling: AnyObject {
    var isDucked: Bool { get }

    /// Lowers, but never raises, the current default output volume.
    /// Returns true only when at least one volume control changed.
    @discardableResult
    func duck(to level: Float) throws -> Bool

    /// Restores only controls that still equal the value Mic Pause applied.
    /// A manual volume adjustment transfers ownership back to the person.
    func restore() throws
}

@MainActor
final class SystemOutputVolumeController: OutputVolumeControlling {
    private struct Change {
        let address: AudioObjectPropertyAddress
        let originalValue: Float32
        let appliedValue: Float32
    }

    private struct OwnedDuck {
        let deviceID: AudioObjectID
        let changes: [Change]
    }

    private var ownedDuck: OwnedDuck?

    var isDucked: Bool { ownedDuck != nil }

    @discardableResult
    func duck(to level: Float) throws -> Bool {
        if ownedDuck != nil { return true }

        let target = Float32(min(max(level, 0), 1))
        let deviceID = try defaultOutputDevice()
        let addresses = writableVolumeAddresses(for: deviceID)
        guard !addresses.isEmpty else {
            throw OutputVolumeError.volumeControlUnavailable
        }

        var changes: [Change] = []
        do {
            for address in addresses {
                let original = try readVolume(deviceID: deviceID, address: address)
                let applied = min(original, target)
                guard applied < original - Self.comparisonTolerance else { continue }
                try writeVolume(applied, deviceID: deviceID, address: address)
                changes.append(
                    Change(
                        address: address,
                        originalValue: original,
                        appliedValue: applied
                    )
                )
            }
        } catch {
            // Best effort rollback if a multi-channel device rejected one of
            // the writes after earlier channels had already changed.
            for change in changes {
                try? writeVolume(
                    change.originalValue,
                    deviceID: deviceID,
                    address: change.address
                )
            }
            throw error
        }

        guard !changes.isEmpty else { return false }
        ownedDuck = OwnedDuck(deviceID: deviceID, changes: changes)
        Log.meeting.info("Lowered system output volume for dictation")
        return true
    }

    func restore() throws {
        guard let ownedDuck else { return }
        defer { self.ownedDuck = nil }

        var firstError: Error?
        for change in ownedDuck.changes {
            do {
                let current = try readVolume(
                    deviceID: ownedDuck.deviceID,
                    address: change.address
                )
                // Do not overwrite a volume change made while dictation was
                // active. Mic Pause owns only the exact value it applied.
                guard abs(current - change.appliedValue) <= Self.comparisonTolerance else {
                    continue
                }
                try writeVolume(
                    change.originalValue,
                    deviceID: ownedDuck.deviceID,
                    address: change.address
                )
            } catch {
                firstError = firstError ?? error
            }
        }

        if let firstError { throw firstError }
        Log.meeting.info("Restored system output volume after dictation")
    }

    private func defaultOutputDevice() throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard result == noErr, deviceID != kAudioObjectUnknown else {
            throw OutputVolumeError.noDefaultOutput
        }
        return deviceID
    }

    private func writableVolumeAddresses(
        for deviceID: AudioObjectID
    ) -> [AudioObjectPropertyAddress] {
        let main = volumeAddress(element: kAudioObjectPropertyElementMain)
        if isWritable(main, on: deviceID) { return [main] }

        // Devices without a main control commonly expose one scalar per output
        // channel. Thirty-two is intentionally bounded; consumer interfaces
        // and virtual meeting devices use far fewer channels.
        return (1...32).compactMap { channel in
            let address = volumeAddress(element: AudioObjectPropertyElement(channel))
            return isWritable(address, on: deviceID) ? address : nil
        }
    }

    private func volumeAddress(
        element: AudioObjectPropertyElement
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }

    private func isWritable(
        _ immutableAddress: AudioObjectPropertyAddress,
        on deviceID: AudioObjectID
    ) -> Bool {
        var address = immutableAddress
        guard AudioObjectHasProperty(deviceID, &address) else { return false }
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr
            && settable.boolValue
    }

    private func readVolume(
        deviceID: AudioObjectID,
        address immutableAddress: AudioObjectPropertyAddress
    ) throws -> Float32 {
        var address = immutableAddress
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let result = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            &value
        )
        guard result == noErr else { throw OutputVolumeError.osStatus(result) }
        return value
    }

    private func writeVolume(
        _ value: Float32,
        deviceID: AudioObjectID,
        address immutableAddress: AudioObjectPropertyAddress
    ) throws {
        var address = immutableAddress
        var mutableValue = value
        let size = UInt32(MemoryLayout<Float32>.size)
        let result = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            size,
            &mutableValue
        )
        guard result == noErr else { throw OutputVolumeError.osStatus(result) }
    }

    private static let comparisonTolerance: Float32 = 0.015
}

private enum OutputVolumeError: LocalizedError {
    case noDefaultOutput
    case volumeControlUnavailable
    case osStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .noDefaultOutput:
            "No default audio output is available"
        case .volumeControlUnavailable:
            "The current output device does not expose software volume control"
        case .osStatus(let status):
            "Core Audio volume error \(status)"
        }
    }
}
