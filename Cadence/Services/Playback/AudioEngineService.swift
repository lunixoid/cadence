import AVFoundation
import Foundation

@MainActor
final class AudioEngineService {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
    private var progressTimer: Timer?
    private var currentFileURL: URL?

    private var pcmChunks: [AVAudioPCMBuffer] = []
    private var processingFormat: AVAudioFormat?
    private var chunkDurationFrames: AVAudioFrameCount = 0
    private var totalFrameCount: AVAudioFramePosition = 0
    private var segmentStartFrame: AVAudioFramePosition = 0
    private var segmentOffsetInFirstChunk: AVAudioFrameCount = 0
    private var scheduledUpToIndex = 0
    private var scheduleGeneration = 0

    private let prefetchChunkCount = 4
    private let eqFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    var onProgress: ((TimeInterval, TimeInterval) -> Void)?
    var onTrackFinished: (() -> Void)?

    var volume: Double {
        get { Double(engine.mainMixerNode.outputVolume) * 100 }
        set { engine.mainMixerNode.outputVolume = Float(newValue / 100) }
    }

    init() {
        engine.attach(playerNode)
        engine.attach(eqNode)

        for (i, freq) in eqFrequencies.enumerated() {
            let band = eqNode.bands[i]
            band.filterType = .parametric
            band.frequency = freq
            band.bandwidth = 1.0
            band.gain = 0
            band.bypass = false
        }

        volume = 72
    }

    func load(url: URL) async throws {
        stopInternal(resetProgress: true)
        currentFileURL = url

        let prepared = try await Task.detached(priority: .userInitiated) {
            try Self.prepareLoad(url: url)
        }.value

        try applyPreparedLoad(prepared)
    }

    func loadRemote(url: URL, trackID: UUID) async throws {
        let localURL = try await AudioCache.shared.localURL(for: url, trackID: trackID)
        try await load(url: localURL)
    }

    nonisolated static func ext(forContentType contentType: String) -> String? {
        let type = contentType.split(separator: ";").first.map(String.init) ?? contentType
        switch type.trimmingCharacters(in: .whitespaces) {
        case "audio/flac": return "flac"
        case "audio/mp4", "audio/m4a", "video/mp4": return "m4a"
        case "audio/mpeg", "audio/mp3": return "mp3"
        case "audio/aac": return "aac"
        case "audio/wav", "audio/x-wav": return "wav"
        case "audio/aiff", "audio/x-aiff": return "aiff"
        default: return nil
        }
    }

    func play() {
        guard !pcmChunks.isEmpty else { return }

        if !engine.isRunning {
            try? engine.start()
        }

        if playerNode.isPlaying {
            playerNode.stop()
            scheduleGeneration += 1
        }

        scheduleFromCurrentPosition()
        playerNode.play()
        startProgressTimer()
    }

    func pause() {
        playerNode.pause()
        stopProgressTimer()
    }

    func stop() {
        scheduleGeneration += 1
        playerNode.stop()
        stopProgressTimer()
        if engine.isRunning {
            engine.stop()
        }
        stopInternal(resetProgress: true)
    }

    func seek(to time: TimeInterval) {
        guard let format = processingFormat, !pcmChunks.isEmpty else { return }
        let sampleRate = format.sampleRate
        let frame = AVAudioFramePosition(time * sampleRate)
        segmentStartFrame = min(max(frame, 0), totalFrameCount)
        segmentOffsetInFirstChunk = AVAudioFrameCount(segmentStartFrame % Int64(chunkDurationFrames))
        scheduledUpToIndex = Int(segmentStartFrame / Int64(chunkDurationFrames))

        playerNode.stop()
        scheduleFromCurrentPosition()
        if engine.isRunning {
            playerNode.play()
            startProgressTimer()
        }
        emitProgress()
    }

    func currentTime() -> TimeInterval {
        guard let format = processingFormat else { return 0 }
        let sampleRate = format.sampleRate
        guard sampleRate > 0 else { return 0 }
        let nodeTime = playerNode.lastRenderTime
        let playerTime = playerNode.playerTime(forNodeTime: nodeTime ?? AVAudioTime(sampleTime: 0, atRate: sampleRate))
        let playedFrames = AVAudioFramePosition(playerTime?.sampleTime ?? 0)
        return Double(segmentStartFrame + playedFrames) / sampleRate
    }

    func duration() -> TimeInterval {
        guard let format = processingFormat else { return 0 }
        let sampleRate = format.sampleRate
        guard sampleRate > 0 else { return 0 }
        return Double(totalFrameCount) / sampleRate
    }

    var isPlaying: Bool {
        playerNode.isPlaying
    }

    func setBandGain(at index: Int, gain: Float) {
        guard index < eqNode.bands.count else { return }
        eqNode.bands[index].gain = gain
    }

    func setEQEnabled(_ enabled: Bool) {
        eqNode.bypass = !enabled
    }

    private struct PreparedAudioLoad: @unchecked Sendable {
        let chunks: [AVAudioPCMBuffer]
        let format: AVAudioFormat
        let totalFrameCount: AVAudioFramePosition
        let chunkDurationFrames: AVAudioFrameCount
    }

    private nonisolated static func prepareLoad(url: URL) throws -> PreparedAudioLoad {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let chunkDurationFrames = AVAudioFrameCount(format.sampleRate)
        let chunks = try decodeChunks(from: file, chunkFrames: chunkDurationFrames)
        return PreparedAudioLoad(
            chunks: chunks,
            format: format,
            totalFrameCount: file.length,
            chunkDurationFrames: chunkDurationFrames
        )
    }

    private func applyPreparedLoad(_ prepared: PreparedAudioLoad) throws {
        scheduleGeneration += 1
        playerNode.stop()
        stopProgressTimer()
        if engine.isRunning {
            engine.stop()
        }

        processingFormat = prepared.format
        totalFrameCount = prepared.totalFrameCount
        chunkDurationFrames = prepared.chunkDurationFrames
        pcmChunks = prepared.chunks
        segmentStartFrame = 0
        segmentOffsetInFirstChunk = 0
        scheduledUpToIndex = 0

        engine.disconnectNodeOutput(playerNode)
        engine.disconnectNodeOutput(eqNode)
        engine.connect(playerNode, to: eqNode, format: prepared.format)
        engine.connect(eqNode, to: engine.mainMixerNode, format: prepared.format)

        try engine.start()
    }

    private nonisolated static func decodeChunks(from file: AVAudioFile, chunkFrames: AVAudioFrameCount) throws -> [AVAudioPCMBuffer] {
        let format = file.processingFormat
        var chunks: [AVAudioPCMBuffer] = []
        file.framePosition = 0

        while file.framePosition < file.length {
            let remaining = AVAudioFrameCount(file.length - file.framePosition)
            let framesToRead = min(chunkFrames, remaining)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead) else {
                throw NSError(domain: "AudioEngine", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to allocate PCM buffer",
                ])
            }
            try file.read(into: buffer, frameCount: framesToRead)
            buffer.frameLength = framesToRead
            chunks.append(buffer)
        }

        return chunks
    }

    private func scheduleFromCurrentPosition() {
        scheduleGeneration += 1
        let generation = scheduleGeneration

        guard !pcmChunks.isEmpty else { return }

        let remainingFrames = totalFrameCount - segmentStartFrame
        guard remainingFrames > 0 else {
            onTrackFinished?()
            return
        }

        scheduledUpToIndex = min(scheduledUpToIndex, pcmChunks.count)
        scheduleInitialChunks(generation: generation)
    }

    private func scheduleInitialChunks(generation: Int) {
        var chunkIndex = scheduledUpToIndex
        var useOffset = segmentOffsetInFirstChunk > 0
        var scheduled = 0

        while scheduled < prefetchChunkCount, chunkIndex < pcmChunks.count {
            scheduleChunk(at: chunkIndex, generation: generation, useOffset: useOffset)
            useOffset = false
            chunkIndex += 1
            scheduled += 1
        }

        scheduledUpToIndex = chunkIndex
    }

    private func scheduleChunk(at chunkIndex: Int, generation: Int, useOffset: Bool) {
        let sourceChunk = pcmChunks[chunkIndex]
        let buffer: AVAudioPCMBuffer
        if useOffset {
            buffer = subBuffer(from: sourceChunk, startingAt: segmentOffsetInFirstChunk) ?? sourceChunk
        } else {
            buffer = sourceChunk
        }

        playerNode.scheduleBuffer(buffer, at: nil) { [weak self] in
            Task { @MainActor in
                guard let self, generation == self.scheduleGeneration else { return }

                if chunkIndex >= self.pcmChunks.count - 1 {
                    self.stopProgressTimer()
                    self.onTrackFinished?()
                    return
                }

                if self.scheduledUpToIndex < self.pcmChunks.count {
                    self.scheduleChunk(at: self.scheduledUpToIndex, generation: generation, useOffset: false)
                    self.scheduledUpToIndex += 1
                }
            }
        }
    }

    private func subBuffer(from chunk: AVAudioPCMBuffer, startingAt frameOffset: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        let remainingFrames = chunk.frameLength - frameOffset
        guard remainingFrames > 0,
              let partial = AVAudioPCMBuffer(pcmFormat: chunk.format, frameCapacity: remainingFrames)
        else { return nil }

        partial.frameLength = remainingFrames
        let channelCount = Int(chunk.format.channelCount)

        switch chunk.format.commonFormat {
        case .pcmFormatFloat32:
            guard let sourceChannels = chunk.floatChannelData,
                  let destinationChannels = partial.floatChannelData else { return nil }
            for channel in 0..<channelCount {
                memcpy(
                    destinationChannels[channel],
                    sourceChannels[channel].advanced(by: Int(frameOffset)),
                    Int(remainingFrames) * MemoryLayout<Float>.size
                )
            }
        case .pcmFormatInt16:
            guard let sourceChannels = chunk.int16ChannelData,
                  let destinationChannels = partial.int16ChannelData else { return nil }
            for channel in 0..<channelCount {
                memcpy(
                    destinationChannels[channel],
                    sourceChannels[channel].advanced(by: Int(frameOffset)),
                    Int(remainingFrames) * MemoryLayout<Int16>.size
                )
            }
        default:
            return nil
        }

        return partial
    }

    private func stopInternal(resetProgress: Bool) {
        scheduleGeneration += 1
        playerNode.stop()
        stopProgressTimer()
        pcmChunks.removeAll(keepingCapacity: false)
        processingFormat = nil
        totalFrameCount = 0
        chunkDurationFrames = 0
        scheduledUpToIndex = 0
        segmentOffsetInFirstChunk = 0
        if resetProgress {
            segmentStartFrame = 0
        }
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.emitProgress()
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func emitProgress() {
        onProgress?(currentTime(), duration())
    }
}
