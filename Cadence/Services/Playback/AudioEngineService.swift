import AVFoundation
import Foundation
import os.log

private let engineLogger = Logger(subsystem: "dev.personal.cadence", category: "AudioEngine")

@MainActor
final class AudioEngineService {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
    private let limiterNode: AVAudioUnitEffect = {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        return AVAudioUnitEffect(audioComponentDescription: desc)
    }()
    private var progressTimer: Timer?
    private var currentFileURL: URL?

    private var chunkSource: LazyChunkSource?
    private var decodePipeline: ChunkDecodePipeline?
    private var progressiveAsset: ProgressiveAudioAsset?
    private var knownDuration: TimeInterval?
    private var progressiveMonitorTask: Task<Void, Never>?

    // Serial scheduler
    private var schedulerTask: Task<Void, Never>?
    private let bufferTracker = BufferFlightTracker()

    // Gapless next-track
    private var nextChunkSource: LazyChunkSource?
    private var nextDecodePipeline: ChunkDecodePipeline?

    private var processingFormat: AVAudioFormat?
    private var chunkDurationFrames: AVAudioFrameCount = 0
    private var totalFrameCount: AVAudioFramePosition = 0
    private var segmentStartFrame: AVAudioFramePosition = 0
    private var segmentOffsetInFirstChunk: AVAudioFrameCount = 0
    private var scheduledUpToIndex = 0
    private var scheduleGeneration = 0
    private var isProgressiveLoad = false
    private var isPaused = false
    private var userVolume: Float = 0.72

    private let maxBuffersInFlight = 8
    private let prefetchAheadCount = 10
    private let fadeSteps = 6
    private let fadeDuration: UInt64 = 15_000_000 // 15ms total
    private let eqFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    let spectrumAnalyzer = SpectrumAnalyzer()

    var onProgress: ((TimeInterval, TimeInterval) -> Void)?
    var onTrackFinished: (() -> Void)?
    var onBuffering: ((Bool) -> Void)?
    var onDidStartPlayingBySystem: (() -> Void)?
    var onGaplessAdvance: ((TimeInterval) -> Void)?

    var volume: Double {
        get { Double(userVolume) * 100 }
        set {
            userVolume = Float(newValue / 100)
            engine.mainMixerNode.outputVolume = userVolume
        }
    }

    init() {
        engine.attach(playerNode)
        engine.attach(eqNode)
        engine.attach(limiterNode)

        for (i, freq) in eqFrequencies.enumerated() {
            let band = eqNode.bands[i]
            band.filterType = .parametric
            band.frequency = freq
            band.bandwidth = 1.0
            band.gain = 0
            band.bypass = false
        }

        let limiterAU = limiterNode.audioUnit
        AudioUnitSetParameter(limiterAU, kLimiterParam_AttackTime, kAudioUnitScope_Global, 0, 0.002, 0)
        AudioUnitSetParameter(limiterAU, kLimiterParam_DecayTime, kAudioUnitScope_Global, 0, 0.020, 0)
        AudioUnitSetParameter(limiterAU, kLimiterParam_PreGain, kAudioUnitScope_Global, 0, 0, 0)

        volume = 72

        NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleEngineConfigurationChange()
            }
        }
    }

    func load(url: URL) async throws {
        stopInternal(resetProgress: true)
        currentFileURL = url
        isProgressiveLoad = false
        progressiveAsset = nil

        let source = try await Task.detached(priority: .userInitiated) {
            try LazyChunkSource(url: url, isProgressive: false)
        }.value

        try applyChunkSource(source)
    }

    func loadProgressive(asset: ProgressiveAudioAsset, expectedDuration: TimeInterval?) async throws {
        stopInternal(resetProgress: true)
        isProgressiveLoad = true
        progressiveAsset = asset
        knownDuration = expectedDuration
        currentFileURL = asset.partialURL

        try await asset.waitUntilBuffered()
        let downloaded = await asset.bytesDownloaded()
        let total = await asset.expectedBytes()
        let source = try await Task.detached(priority: .userInitiated) {
            try LazyChunkSource(url: asset.partialURL, isProgressive: true)
        }.value
        source.updateDownloadProgress(downloaded: downloaded, total: total)

        try applyChunkSource(source)
    }

    func loadRemote(url: URL, trackID: UUID) async throws {
        let localURL = try await AudioCache.shared.localURL(for: url, trackID: trackID)
        try await load(url: localURL)
    }

    /// Pre-decode the next track for gapless transition. Returns true if the format
    /// is compatible and the source was accepted; false means the caller should
    /// fall back to a normal load when the current track finishes.
    func prepareNextTrack(url: URL) async throws -> Bool {
        let source = try await Task.detached(priority: .userInitiated) {
            try LazyChunkSource(url: url, isProgressive: false)
        }.value

        guard let currentFormat = processingFormat,
              source.format.sampleRate == currentFormat.sampleRate,
              source.format.channelCount == currentFormat.channelCount else {
            nextChunkSource = nil
            nextDecodePipeline = nil
            return false
        }

        nextChunkSource = source
        nextDecodePipeline = ChunkDecodePipeline(source: source)
        return true
    }

    func cancelPreparedNext() {
        nextChunkSource = nil
        nextDecodePipeline = nil
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
        guard chunkSource != nil else { return }

        if !engine.isRunning {
            try? engine.start()
        }

        if playerNode.isPlaying {
            return  // Already playing — no-op
        }

        if !isPaused {
            scheduleFromCurrentPosition()  // first play or after stop
        }
        // If paused: buffers already queued on playerNode, just resume

        isPaused = false
        engine.mainMixerNode.outputVolume = 0
        playerNode.play()
        startProgressTimer()
        if isProgressiveLoad, progressiveMonitorTask == nil {
            startProgressiveMonitoring()
        }
        Task { await fadeIn() }
    }

    func pause() {
        Task {
            await fadeOut()
            playerNode.pause()
            stopProgressTimer()
            isPaused = true
        }
    }

    func stop() {
        if engine.isRunning {
            engine.stop()
        }
        stopInternal(resetProgress: true)
    }

    func seek(to time: TimeInterval) {
        guard let format = processingFormat, chunkSource != nil else { return }
        applySeek(to: time, format: format)
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
        if let knownDuration, knownDuration > 0 {
            return knownDuration
        }
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

    /// Pre-amp (overall gain) compensation. Boosting bands without lowering the
    /// global gain pushes the signal past 0 dBFS and clips → audible rattle.
    /// We set this to the negative of the largest positive band boost so there is
    /// always enough headroom for a clean signal.
    func setGlobalGain(_ gain: Float) {
        eqNode.globalGain = max(-24, min(24, gain))
    }

    // MARK: - Volume fade

    private func fadeIn() async {
        let target = userVolume
        let stepDelay = fadeDuration / UInt64(fadeSteps)
        for i in 1...fadeSteps {
            engine.mainMixerNode.outputVolume = target * Float(i) / Float(fadeSteps)
            try? await Task.sleep(nanoseconds: stepDelay)
        }
        engine.mainMixerNode.outputVolume = target
    }

    private func fadeOut() async {
        let current = engine.mainMixerNode.outputVolume
        let stepDelay = fadeDuration / UInt64(fadeSteps)
        for i in 1...fadeSteps {
            engine.mainMixerNode.outputVolume = current * Float(fadeSteps - i) / Float(fadeSteps)
            try? await Task.sleep(nanoseconds: stepDelay)
        }
        engine.mainMixerNode.outputVolume = 0
    }

    // MARK: - Engine configuration change

    private func handleEngineConfigurationChange() {
        guard let format = processingFormat, chunkSource != nil, schedulerTask != nil else { return }
        let resumeTime = currentTime()
        // Don't touch the graph — modifying nodes fires another AVAudioEngineConfigurationChange,
        // causing an infinite restart loop. The engine preserves player→eq→mixer connections;
        // restarting without reconnecting works for the common case (same-sample-rate device switch).
        do {
            try engine.start()
            spectrumAnalyzer.start(on: engine.mainMixerNode, format: format)
            applySeek(to: resumeTime, format: format)
            onDidStartPlayingBySystem?()
        } catch {
            // Engine can't restart with new hardware config — stay silent
        }
    }

    // MARK: - Internal setup

    private func applyChunkSource(_ source: LazyChunkSource) throws {
        cancelScheduler()
        scheduleGeneration += 1
        playerNode.stop()
        stopProgressTimer()
        if engine.isRunning {
            engine.stop()
        }

        chunkSource = source
        decodePipeline = ChunkDecodePipeline(source: source)
        processingFormat = source.format
        totalFrameCount = source.totalFrameCount
        chunkDurationFrames = source.chunkDurationFrames
        segmentStartFrame = 0
        segmentOffsetInFirstChunk = 0
        scheduledUpToIndex = 0

        let totalChunks = chunkDurationFrames > 0
            ? Int((totalFrameCount + Int64(chunkDurationFrames) - 1) / Int64(chunkDurationFrames))
            : 0
        engineLogger.info("Loaded: \(totalChunks) chunks, \(Int(source.format.sampleRate))Hz, progressive=\(self.isProgressiveLoad)")

        engine.disconnectNodeOutput(playerNode)
        engine.disconnectNodeOutput(eqNode)
        engine.disconnectNodeOutput(limiterNode)
        engine.connect(playerNode, to: eqNode, format: source.format)
        engine.connect(eqNode, to: limiterNode, format: source.format)
        engine.connect(limiterNode, to: engine.mainMixerNode, format: source.format)

        try engine.start()
        spectrumAnalyzer.start(on: engine.mainMixerNode, format: source.format)
    }

    private func applySeek(to time: TimeInterval, format: AVAudioFormat) {
        let wasPlaying = playerNode.isPlaying
        if wasPlaying {
            engine.mainMixerNode.outputVolume = 0
        }

        let sampleRate = format.sampleRate
        let frame = AVAudioFramePosition(time * sampleRate)
        let endFrame = playbackEndFrame()
        segmentStartFrame = min(max(frame, 0), max(endFrame - 1, 0))
        segmentOffsetInFirstChunk = AVAudioFrameCount(segmentStartFrame % Int64(chunkDurationFrames))
        scheduledUpToIndex = Int(segmentStartFrame / Int64(chunkDurationFrames))

        let seekChunk = scheduledUpToIndex
        let seekOffset = segmentOffsetInFirstChunk
        engineLogger.info("Seek → \(String(format: "%.2f", time))s (chunk=\(seekChunk), offset=\(seekOffset))")

        isPaused = false
        decodePipeline?.reset()
        playerNode.stop()
        scheduleFromCurrentPosition()
        if engine.isRunning, segmentStartFrame < playbackEndFrame() {
            playerNode.play()
            startProgressTimer()
            Task { await fadeIn() }
        }
        emitProgress()
    }

    // MARK: - Serial scheduler

    private func scheduleFromCurrentPosition() {
        cancelScheduler()
        scheduleGeneration += 1
        let generation = scheduleGeneration

        guard chunkSource != nil else { return }

        let remainingFrames = playbackEndFrame() - segmentStartFrame
        guard remainingFrames > 0 else {
            stopProgressTimer()
            engineLogger.info("Track finished (no frames remaining)")
            onTrackFinished?()
            return
        }

        startScheduler(generation: generation)
    }

    /// Single serial loop that feeds buffers to AVAudioPlayerNode in strict index order.
    /// Parallel decode is handled by ChunkDecodePipeline.prefetch; this loop only awaits
    /// each index sequentially so scheduleBuffer is always called 0,1,2,3…
    private func startScheduler(generation: Int) {
        let tracker = bufferTracker
        schedulerTask = Task { [weak self] in
            guard let self else { return }

            engineLogger.info("Scheduler started gen=\(generation)")
            var index = self.scheduledUpToIndex
            var firstIndex = index

            // Outer loop: one iteration per track (current + gapless continuations)
            trackLoop: while !Task.isCancelled, generation == self.scheduleGeneration {

                // Inner loop: schedule all chunks of the current source
                while !Task.isCancelled, generation == self.scheduleGeneration {

                    if tracker.count >= self.maxBuffersInFlight {
                        await tracker.waitForConsumption()
                        guard !Task.isCancelled, generation == self.scheduleGeneration else { return }
                    }

                    var available = self.availableChunkCount()
                    if index >= available {
                        if self.isProgressiveLoad {
                            self.onBuffering?(true)
                            let ok = await self.awaitMoreBytes(fromIndex: index, generation: generation)
                            self.onBuffering?(false)
                            guard ok else { return }
                            let newAvailable = self.availableChunkCount()
                            if newAvailable <= available { break }
                            available = newAvailable
                        } else {
                            break
                        }
                    }

                    self.decodePipeline?.prefetch(from: index, to: min(available, index + self.prefetchAheadCount))

                    guard let pipeline = self.decodePipeline else { return }
                    let sourceChunk: AVAudioPCMBuffer
                    do {
                        sourceChunk = try await pipeline.buffer(for: index)
                    } catch {
                        if self.isProgressiveLoad {
                            self.onBuffering?(true)
                            let ok = await self.awaitMoreBytes(fromIndex: index, generation: generation)
                            self.onBuffering?(false)
                            guard ok else { return }
                            continue
                        } else {
                            break
                        }
                    }
                    guard !Task.isCancelled, generation == self.scheduleGeneration else { return }

                    let buffer: AVAudioPCMBuffer
                    if index == firstIndex, self.segmentOffsetInFirstChunk > 0 {
                        buffer = self.subBuffer(from: sourceChunk, startingAt: self.segmentOffsetInFirstChunk) ?? sourceChunk
                    } else {
                        buffer = sourceChunk
                    }

                    let scheduledIndex = index
                    tracker.increment()
                    self.scheduledUpToIndex = index + 1

                    self.playerNode.scheduleBuffer(buffer, at: nil, completionCallbackType: .dataConsumed) { [weak self] _ in
                        let remaining = tracker.decrementAndSignal()
                        if remaining == 0, tracker.isFinished {
                            Task { @MainActor [weak self] in
                                guard let self, generation == self.scheduleGeneration else { return }
                                self.stopProgressTimer()
                                engineLogger.info("Track finished (gen=\(generation))")
                                self.onTrackFinished?()
                            }
                        }
                    }

                    index += 1
                }

                // Inner loop exited: all chunks of current source scheduled
                guard generation == self.scheduleGeneration, !Task.isCancelled else { return }

                // Gapless: continue with next track if prepared
                if let nextSource = self.nextChunkSource, let nextPipeline = self.nextDecodePipeline {
                    engineLogger.info("Gapless: transitioning to next track")
                    let nextDuration = Double(nextSource.totalFrameCount) / nextSource.format.sampleRate

                    self.chunkSource = nextSource
                    self.decodePipeline = nextPipeline
                    self.totalFrameCount = nextSource.totalFrameCount
                    self.chunkDurationFrames = nextSource.chunkDurationFrames
                    self.segmentStartFrame = 0
                    self.segmentOffsetInFirstChunk = 0
                    self.scheduledUpToIndex = 0
                    self.isProgressiveLoad = false
                    self.nextChunkSource = nil
                    self.nextDecodePipeline = nil

                    self.onGaplessAdvance?(nextDuration)

                    index = 0
                    firstIndex = 0
                    continue trackLoop
                }

                // No gapless source — mark finished
                tracker.markFinished()
                engineLogger.info("Scheduler: all chunks scheduled gen=\(generation)")
                if tracker.count == 0 {
                    self.stopProgressTimer()
                    engineLogger.info("Track finished (gen=\(generation))")
                    self.onTrackFinished?()
                }
                break trackLoop
            }
        }
    }

    /// Waits for more bytes to arrive so that chunk at `index` becomes readable.
    private func awaitMoreBytes(fromIndex index: Int, generation: Int) async -> Bool {
        guard let asset = progressiveAsset else { return false }
        var lastDownloaded = await asset.bytesDownloaded()

        while !Task.isCancelled, generation == scheduleGeneration {
            if await asset.isComplete() {
                try? await refreshProgressiveSourceIfNeeded()
                return generation == scheduleGeneration && !Task.isCancelled
            }

            let targetBytes = lastDownloaded + ProgressivePlayback.continueWaitByteIncrement
            try? await asset.waitUntilBytes(targetBytes)
            guard !Task.isCancelled, generation == scheduleGeneration else { return false }
            lastDownloaded = await asset.bytesDownloaded()
            try? await refreshProgressiveSourceIfNeeded()
            guard !Task.isCancelled, generation == scheduleGeneration else { return false }

            if availableChunkCount() > index {
                return true
            }
        }
        return false
    }

    private func cancelScheduler() {
        schedulerTask?.cancel()
        schedulerTask = nil
        bufferTracker.reset()
    }

    // MARK: - Progressive support

    private func estimatedBytesForFrame(_ frame: AVAudioFramePosition) async -> Int64 {
        guard let asset = progressiveAsset else {
            return ProgressivePlayback.initialBufferBytes
        }

        if await asset.isComplete() {
            return await asset.bytesDownloaded()
        }

        if let expected = await asset.expectedBytes(), totalFrameCount > 0 {
            let ratio = Double(frame) / Double(totalFrameCount)
            let estimated = Int64(Double(expected) * ratio * 1.15)
            return max(estimated, ProgressivePlayback.initialBufferBytes)
        }

        let downloaded = await asset.bytesDownloaded()
        if totalFrameCount > 0, downloaded > 0 {
            let ratio = Double(frame) / Double(totalFrameCount)
            return max(Int64(Double(downloaded) * ratio * 1.2), ProgressivePlayback.initialBufferBytes)
        }

        return max(downloaded, ProgressivePlayback.initialBufferBytes)
    }

    private func playbackEndFrame() -> AVAudioFramePosition {
        if isProgressiveLoad {
            return totalFrameCount
        }
        if totalFrameCount > 0 {
            return totalFrameCount
        }
        if let knownDuration, let format = processingFormat, format.sampleRate > 0 {
            return AVAudioFramePosition(knownDuration * format.sampleRate)
        }
        return 0
    }

    private func refreshProgressiveSourceIfNeeded() async throws {
        let capturedGeneration = scheduleGeneration
        guard let asset = progressiveAsset, let source = chunkSource else { return }
        let downloaded = await asset.bytesDownloaded()
        let total = await asset.expectedBytes()
        let isComplete = await asset.isComplete()

        guard scheduleGeneration == capturedGeneration, !Task.isCancelled else { return }

        source.updateDownloadProgress(downloaded: downloaded, total: total)

        try await Task.detached {
            try source.refreshFromDisk(isDownloadComplete: isComplete)
        }.value

        guard scheduleGeneration == capturedGeneration, !Task.isCancelled else { return }

        if isComplete, let finalURL = try? await asset.waitUntilComplete() {
            currentFileURL = finalURL
            isProgressiveLoad = false
            totalFrameCount = source.totalFrameCount
        } else {
            totalFrameCount = source.totalFrameCount
        }
    }

    private func startProgressiveMonitoring() {
        progressiveMonitorTask?.cancel()
        progressiveMonitorTask = Task { [weak self] in
            guard let self else { return }
            var lastDownloaded: Int64 = 0

            while !Task.isCancelled {
                guard let asset = self.progressiveAsset else { return }
                let downloaded = await asset.bytesDownloaded()
                if downloaded > lastDownloaded {
                    lastDownloaded = downloaded
                    do {
                        try await self.refreshProgressiveSourceIfNeeded()
                    } catch {
                        continue
                    }
                }

                if await asset.isComplete() {
                    try? await self.refreshProgressiveSourceIfNeeded()
                    return
                }

                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    // MARK: - Helpers

    private func availableChunkCount() -> Int {
        guard let source = chunkSource else { return 0 }
        let safeFrames = source.safeReadableFrameCount(isDownloadComplete: !isProgressiveLoad)
        guard chunkDurationFrames > 0 else { return 0 }
        return Int((safeFrames + AVAudioFramePosition(chunkDurationFrames) - 1) / AVAudioFramePosition(chunkDurationFrames))
    }

    private func lastChunkIndex() -> Int {
        guard chunkDurationFrames > 0 else { return 0 }
        let endFrame = playbackEndFrame()
        return max(0, Int((endFrame + AVAudioFramePosition(chunkDurationFrames) - 1) / AVAudioFramePosition(chunkDurationFrames)) - 1)
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
        case .pcmFormatInt32:
            guard let sourceChannels = chunk.int32ChannelData,
                  let destinationChannels = partial.int32ChannelData else { return nil }
            for channel in 0..<channelCount {
                memcpy(
                    destinationChannels[channel],
                    sourceChannels[channel].advanced(by: Int(frameOffset)),
                    Int(remainingFrames) * MemoryLayout<Int32>.size
                )
            }
        default:
            // pcmFormatFloat64 and other formats: AVAudioPCMBuffer has no typed channel
            // accessor for them, so fall back to the full chunk (seek offset is lost).
            return nil
        }

        return partial
    }

    private func stopInternal(resetProgress: Bool) {
        engine.mainMixerNode.outputVolume = 0
        spectrumAnalyzer.stop()
        isPaused = false
        cancelScheduler()
        scheduleGeneration += 1
        playerNode.stop()
        stopProgressTimer()
        progressiveMonitorTask?.cancel()
        progressiveMonitorTask = nil
        chunkSource = nil
        decodePipeline = nil
        nextChunkSource = nil
        nextDecodePipeline = nil
        progressiveAsset = nil
        knownDuration = nil
        isProgressiveLoad = false
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

// MARK: - Buffer flight tracker

/// Thread-safe tracker for in-flight audio buffers. Called from the audio render
/// thread (scheduleBuffer completion) without hopping through MainActor.
private final class BufferFlightTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0
    private var _finished = false
    private var waiter: CheckedContinuation<Void, Never>?

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }

    var isFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _finished
    }

    func increment() {
        lock.lock()
        _count += 1
        lock.unlock()
    }

    /// Returns remaining count after decrement. Wakes the scheduler if it's waiting.
    @discardableResult
    func decrementAndSignal() -> Int {
        lock.lock()
        _count = max(0, _count - 1)
        let remaining = _count
        let w = waiter
        waiter = nil
        lock.unlock()
        w?.resume()
        return remaining
    }

    func markFinished() {
        lock.lock()
        _finished = true
        lock.unlock()
    }

    func reset() {
        lock.lock()
        _count = 0
        _finished = false
        let w = waiter
        waiter = nil
        lock.unlock()
        w?.resume()
    }

    func waitForConsumption() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            waiter = continuation
            lock.unlock()
        }
    }
}

// MARK: - Decode pipeline

private final class ChunkDecodePipeline: @unchecked Sendable {
    private let source: LazyChunkSource
    private let lock = NSLock()
    private var ready: [Int: AVAudioPCMBuffer] = [:]
    private var inFlight: Set<Int> = []
    private var waiters: [Int: [CheckedContinuation<AVAudioPCMBuffer, Error>]] = [:]

    init(source: LazyChunkSource) {
        self.source = source
    }

    func reset() {
        lock.lock()
        ready.removeAll(keepingCapacity: true)
        inFlight.removeAll()
        let pending = waiters
        waiters.removeAll()
        lock.unlock()

        for continuations in pending.values {
            for continuation in continuations {
                continuation.resume(throwing: CancellationError())
            }
        }
    }

    func prefetch(from startIndex: Int, to endIndex: Int) {
        guard endIndex > startIndex else { return }
        for index in startIndex..<endIndex {
            startDecodeIfNeeded(index: index)
        }
    }

    func buffer(for index: Int) async throws -> AVAudioPCMBuffer {
        lock.lock()
        if let cached = ready[index] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        startDecodeIfNeeded(index: index)

        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let cached = ready[index] {
                lock.unlock()
                continuation.resume(returning: cached)
                return
            }
            waiters[index, default: []].append(continuation)
            lock.unlock()
        }
    }

    private func startDecodeIfNeeded(index: Int) {
        lock.lock()
        if ready[index] != nil || inFlight.contains(index) {
            lock.unlock()
            return
        }
        inFlight.insert(index)
        lock.unlock()

        engineLogger.debug("Chunk \(index) decode started")

        Task.detached(priority: .userInitiated) { [source] in
            do {
                let buffer = try source.decodeChunk(at: index)
                self.completeDecode(index: index, result: .success(buffer))
            } catch {
                self.completeDecode(index: index, result: .failure(error))
            }
        }
    }

    private func completeDecode(index: Int, result: Result<AVAudioPCMBuffer, Error>) {
        engineLogger.debug("Chunk \(index) decode complete")
        lock.lock()
        inFlight.remove(index)

        switch result {
        case .success(let buffer):
            ready[index] = buffer
            let continuations = waiters.removeValue(forKey: index) ?? []
            lock.unlock()
            for continuation in continuations {
                continuation.resume(returning: buffer)
            }
        case .failure(let error):
            let continuations = waiters.removeValue(forKey: index) ?? []
            lock.unlock()
            for continuation in continuations {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Lazy chunk decoder

private final class LazyChunkSource: @unchecked Sendable {
    enum Error: Swift.Error {
        case readBeyondBoundary
        case allocationFailed
    }

    let format: AVAudioFormat
    private(set) var totalFrameCount: AVAudioFramePosition
    let chunkDurationFrames: AVAudioFrameCount

    private let lock = NSLock()
    private var fileURL: URL
    private var audioFile: AVAudioFile?
    private var chunkCache: [Int: AVAudioPCMBuffer] = [:]
    private let maxCachedChunks = 16
    private let isProgressive: Bool
    private var downloadedBytes: Int64 = 0
    private var expectedTotalBytes: Int64?

    init(url: URL, isProgressive: Bool) throws {
        self.fileURL = url
        self.isProgressive = isProgressive
        self.audioFile = try AVAudioFile(forReading: url)
        guard let audioFile else { throw Error.allocationFailed }
        self.format = audioFile.processingFormat
        self.chunkDurationFrames = AVAudioFrameCount(format.sampleRate)
        self.totalFrameCount = audioFile.length
    }

    func updateDownloadProgress(downloaded: Int64, total: Int64?) {
        lock.lock()
        defer { lock.unlock() }
        downloadedBytes = downloaded
        if let total { expectedTotalBytes = total }
    }

    // Must be called while holding lock.
    private func computeSafeLimit(fileLength: AVAudioFramePosition, isDownloadComplete: Bool) -> AVAudioFramePosition {
        if !isProgressive || isDownloadComplete { return fileLength }
        if let total = expectedTotalBytes, total > 0, fileLength > 0 {
            let ratio = min(1.0, Double(downloadedBytes) / Double(total))
            let estimated = AVAudioFramePosition(Double(fileLength) * ratio)
            return max(0, estimated - ProgressivePlayback.safetyMarginFrames)
        }
        return max(0, fileLength - ProgressivePlayback.safetyMarginFrames)
    }

    func refreshFromDisk(isDownloadComplete: Bool) throws {
        lock.lock()
        defer { lock.unlock() }

        audioFile = try AVAudioFile(forReading: fileURL)
        guard let audioFile else { throw Error.allocationFailed }
        totalFrameCount = audioFile.length

        let safeFrames = computeSafeLimit(fileLength: totalFrameCount, isDownloadComplete: isDownloadComplete)
        guard chunkDurationFrames > 0 else { return }
        let safeChunkLimit = Int(safeFrames / AVAudioFramePosition(chunkDurationFrames))

        chunkCache = chunkCache.filter { key, _ in
            key < max(0, safeChunkLimit - 1)
        }
    }

    func safeReadableFrameCount(isDownloadComplete: Bool) -> AVAudioFramePosition {
        lock.lock()
        defer { lock.unlock() }
        return computeSafeLimit(fileLength: totalFrameCount, isDownloadComplete: isDownloadComplete)
    }

    func decodeChunk(at index: Int) throws -> AVAudioPCMBuffer {
        lock.lock()
        if let cached = chunkCache[index] {
            engineLogger.debug("Chunk \(index) cache hit")
            lock.unlock()
            return cached
        }

        if audioFile == nil {
            do {
                audioFile = try AVAudioFile(forReading: fileURL)
            } catch {
                lock.unlock()
                throw error
            }
        }
        guard let file = audioFile else {
            lock.unlock()
            throw Error.allocationFailed
        }

        let startFrame = AVAudioFramePosition(index) * AVAudioFramePosition(chunkDurationFrames)
        let safeLimit = computeSafeLimit(fileLength: file.length, isDownloadComplete: !isProgressive)
        if startFrame >= safeLimit {
            lock.unlock()
            throw Error.readBeyondBoundary
        }

        file.framePosition = startFrame
        let remaining = AVAudioFrameCount(min(
            AVAudioFramePosition(chunkDurationFrames),
            safeLimit - startFrame
        ))
        guard remaining > 0 else {
            lock.unlock()
            throw Error.readBeyondBoundary
        }

        engineLogger.debug("Chunk \(index) decoding frames \(startFrame)–\(startFrame + Int64(remaining))")

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: remaining) else {
            lock.unlock()
            throw Error.allocationFailed
        }

        do {
            try file.read(into: buffer, frameCount: remaining)
            buffer.frameLength = remaining
        } catch {
            lock.unlock()
            if isProgressive {
                throw Error.readBeyondBoundary
            }
            throw error
        }

        chunkCache[index] = buffer
        if chunkCache.count > maxCachedChunks {
            let keysToRemove = chunkCache.keys.sorted().prefix(chunkCache.count - maxCachedChunks)
            for key in keysToRemove {
                engineLogger.debug("Cache evict: chunk \(key)")
                chunkCache.removeValue(forKey: key)
            }
        }
        lock.unlock()
        return buffer
    }
}
