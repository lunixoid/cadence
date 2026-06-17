import AVFoundation
import Foundation
import XCTest

/// Creates a silent Float32 stereo WAV at a temp path.
/// Caller must delete the file when done.
func makeSilentWAV(duration: TimeInterval = 0.5, sampleRate: Double = 44100.0) throws -> URL {
    let frameCount = AVAudioFrameCount(duration * sampleRate)
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("wav")

    let settings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: sampleRate,
        AVNumberOfChannelsKey: 2,
        AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsFloatKey: true,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
    ]

    let file = try AVAudioFile(forWriting: tempURL, settings: settings)
    let chunkSize = AVAudioFrameCount(sampleRate)
    var remaining = frameCount
    while remaining > 0 {
        let toWrite = min(remaining, chunkSize)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: toWrite)!
        buffer.frameLength = toWrite
        try file.write(from: buffer)
        remaining -= toWrite
    }
    return tempURL
}
