import AppKit
import Foundation

enum FeedbackCue: Equatable, Sendable {
    case lowered
    case restored
}

/// Short, quiet tones generated in memory. They use the default output device
/// and contain no microphone audio or downloaded assets.
@MainActor
final class FeedbackSoundPlayer {
    private var loweredSound: NSSound?
    private var restoredSound: NSSound?

    func play(_ cue: FeedbackCue) {
        let sound: NSSound?
        switch cue {
        case .lowered:
            if loweredSound == nil {
                loweredSound = Self.makeSound(for: .lowered)
            }
            sound = loweredSound
        case .restored:
            if restoredSound == nil {
                restoredSound = Self.makeSound(for: .restored)
            }
            sound = restoredSound
        }

        guard let sound else { return }
        sound.stop()
        sound.currentTime = 0
        _ = sound.play()
    }

    private static func makeSound(for cue: FeedbackCue) -> NSSound? {
        guard let sound = NSSound(data: waveData(for: cue)) else { return nil }
        sound.volume = 0.24
        return sound
    }

    static func waveData(for cue: FeedbackCue) -> Data {
        let sampleRate = 22_050
        let duration = 0.12
        let sampleCount = Int(Double(sampleRate) * duration)
        let startFrequency = cue == .lowered ? 880.0 : 620.0
        let endFrequency = cue == .lowered ? 620.0 : 880.0

        var samples = Data(capacity: sampleCount * MemoryLayout<Int16>.size)
        for index in 0..<sampleCount {
            let progress = Double(index) / Double(sampleCount - 1)
            let time = Double(index) / Double(sampleRate)
            let sweep = endFrequency - startFrequency
            let phase = 2 * Double.pi * (
                startFrequency * time + sweep * time * time / (2 * duration)
            )
            let envelope = pow(sin(Double.pi * progress), 2)
            let value = Int16(
                (sin(phase) * envelope * 0.45 * Double(Int16.max)).rounded()
            )
            appendLittleEndian(UInt16(bitPattern: value), to: &samples)
        }

        var data = Data(capacity: 44 + samples.count)
        data.append(contentsOf: "RIFF".utf8)
        appendLittleEndian(UInt32(36 + samples.count), to: &data)
        data.append(contentsOf: "WAVEfmt ".utf8)
        appendLittleEndian(UInt32(16), to: &data) // PCM format chunk size
        appendLittleEndian(UInt16(1), to: &data)  // PCM
        appendLittleEndian(UInt16(1), to: &data)  // mono
        appendLittleEndian(UInt32(sampleRate), to: &data)
        appendLittleEndian(UInt32(sampleRate * 2), to: &data)
        appendLittleEndian(UInt16(2), to: &data)  // block alignment
        appendLittleEndian(UInt16(16), to: &data) // bits per sample
        data.append(contentsOf: "data".utf8)
        appendLittleEndian(UInt32(samples.count), to: &data)
        data.append(samples)
        return data
    }

    private static func appendLittleEndian<T: FixedWidthInteger>(
        _ value: T,
        to data: inout Data
    ) {
        var littleEndianValue = value.littleEndian
        withUnsafeBytes(of: &littleEndianValue) { data.append(contentsOf: $0) }
    }
}
