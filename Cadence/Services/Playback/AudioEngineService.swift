import AVFoundation
import Foundation

@MainActor
final class AudioEngineService {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
    private var progressTimer: Timer?
    private var currentFileURL: URL?

    private var chunkSource: LazyChunkSource?
    private var decodePipeline: ChunkDecodePipeline?
    private var progressiveAsset: ProgressiveAudioAsset?
    private var knownDuration: TimeInterval?
    private var progressiveMonitorTask: Task<Void, Never>?

    // Serial scheduler
    private var schedulerTask: Task<Void, Never>?
    private var bufferConsumedContinuation: CheckedContinuation<Void, Never>?
    private var buffersInFlight = 0
    private var schedulerFinishedAllChunks = false

    private var processingFormat: AVAudioFormat?
    private var chunkDurationFrames: AVAudioFrameCount = 0
    private var totalFrameCount: AVAudioFramePosition = 0
    private var segmentStartFrame: AVAudioFramePosition = 0
    private var segmentOffsetInFirstChunk: AVAudioFrameCount = 0
    private var scheduledUpToIndex = 0
    private var scheduleGeneration = 0
    private var isProgressiveLoad = false

    private let maxBuffersInFlight = 8
    private let prefetchAheadCount = 10
    private let eqFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    var onProgress: ((TimeInterval, TimeInterval) -> Void)?
    var onTrackFinished: (() -> Void)?
    var onBuffering: ((Bool) -> Void)?

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
            playerNode.stop()
        }

        scheduleFromCurrentPosition()
        playerNode.play()
        startProgressTimer()
        if isProgressiveLoad, progressiveMonitorTask == nil {
            startProgressiveMonitoring()
        }
    }

    func pause() {
        playerNode.pause()
        stopProgressTimer()
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

        engine.disconnectNodeOutput(playerNode)
        engine.disconnectNodeOutput(eqNode)
        engine.connect(playerNode, to: eqNode, format: source.format)
        engine.connect(eqNode, to: engine.mainMixerNode, format: source.format)

        try engine.start()
    }

    private func applySeek(to time: TimeInterval, format: AVAudioFormat) {
        let sampleRate = format.sampleRate
        let frame = AVAudioFramePosition(time * sampleRate)
        segmentStartFrame = min(max(frame, 0), playbackEndFrame())
        segmentOffsetInFirstChunk = AVAudioFrameCount(segmentStartFrame % Int64(chunkDurationFrames))
        scheduledUpToIndex = Int(segmentStartFrame / Int64(chunkDurationFrames))

        decodePipeline?.reset()
        playerNode.stop()
        scheduleFromCurrentPosition()
        if engine.isRunning {
            playerNode.play()
            startProgressTimer()
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
            onTrackFinished?()
            return
        }

        startScheduler(generation: generation)
    }

    /// Single serial loop that feeds buffers to AVAudioPlayerNode in strict index order.
    /// Parallel decode is handled by ChunkDecodePipeline.prefetch; this loop only awaits
    /// each index sequentially so scheduleBuffer is always called 0,1,2,3…
    private func startScheduler(generation: Int) {
        schedulerTask = Task { [weak self] in
            guard let self else { return }

            var index = self.scheduledUpToIndex
            let firstIndex = index  // seek offset applies only to the first chunk

            while !Task.isCancelled, generation == self.scheduleGeneration {

                // ── Backpressure: cap buffered data ──────────────────────────────
                if self.buffersInFlight >= self.maxBuffersInFlight {
                    await self.waitForBufferConsumed()
                    guard !Task.isCancelled, generation == self.scheduleGeneration else { return }
                }

                // ── Wait for enough downloaded data for this chunk ───────────────
                var available = self.availableChunkCount()
                if index >= available {
                    if self.isProgressiveLoad {
                        self.onBuffering?(true)
                        let ok = await self.awaitMoreBytes(fromIndex: index, generation: generation)
                        self.onBuffering?(false)
                        guard ok else { return }
                        available = self.availableChunkCount()
                    } else {
                        break  // non-progressive: all chunks consumed
                    }
                }

                // ── Kick off parallel decode ahead, then await THIS index ────────
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
                        continue  // retry same index
                    } else {
                        break
                    }
                }
                guard !Task.isCancelled, generation == self.scheduleGeneration else { return }

                // ── Apply seek offset to the first chunk only ────────────────────
                let buffer: AVAudioPCMBuffer
                if index == firstIndex, self.segmentOffsetInFirstChunk > 0 {
                    buffer = self.subBuffer(from: sourceChunk, startingAt: self.segmentOffsetInFirstChunk) ?? sourceChunk
                } else {
                    buffer = sourceChunk
                }

                // ── Schedule IN ORDER ────────────────────────────────────────────
                self.buffersInFlight += 1
                self.scheduledUpToIndex = index + 1

                self.playerNode.scheduleBuffer(buffer, at: nil, completionCallbackType: .dataConsumed) { [weak self] _ in
                    Task { @MainActor in
                        guard let self, generation == self.scheduleGeneration else { return }
                        self.buffersInFlight -= 1
                        self.signalBufferConsumed()
                        if self.buffersInFlight == 0, self.schedulerFinishedAllChunks {
                            self.stopProgressTimer()
                            self.onTrackFinished?()
                        }
                    }
                }

                index += 1
            }

            // Loop exited naturally: all chunks scheduled (or non-progressive EOF)
            guard generation == self.scheduleGeneration, !Task.isCancelled else { return }
            self.schedulerFinishedAllChunks = true
            if self.buffersInFlight == 0 {
                self.stopProgressTimer()
                self.onTrackFinished?()
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

    private func waitForBufferConsumed() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            bufferConsumedContinuation = continuation
        }
    }

    private func signalBufferConsumed() {
        let c = bufferConsumedContinuation
        bufferConsumedContinuation = nil
        c?.resume()
    }

    private func cancelScheduler() {
        schedulerTask?.cancel()
        schedulerTask = nil
        let c = bufferConsumedContinuation
        bufferConsumedContinuation = nil
        c?.resume()
        buffersInFlight = 0
        schedulerFinishedAllChunks = false
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
        if let knownDuration, let format = processingFormat, format.sampleRate > 0 {
            return AVAudioFramePosition(knownDuration * format.sampleRate)
        }
        return totalFrameCount
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
        default:
            return nil
        }

        return partial
    }

    private func stopInternal(resetProgress: Bool) {
        cancelScheduler()
        scheduleGeneration += 1
        playerNode.stop()
        stopProgressTimer()
        progressiveMonitorTask?.cancel()
        progressiveMonitorTask = nil
        chunkSource = nil
        decodePipeline = nil
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
                chunkCache.removeValue(forKey: key)
            }
        }
        lock.unlock()
        return buffer
    }
}
