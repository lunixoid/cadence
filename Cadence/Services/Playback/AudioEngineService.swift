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
    private var playerTimeBase: AVAudioFramePosition = 0
    private var pendingGaplessAdvance: (callbackDuration: TimeInterval, oldTrackEndTime: TimeInterval, newTotalFrameCount: AVAudioFramePosition)?
    private var scheduledUpToIndex = 0
    private var scheduleGeneration = 0
    private var isProgressiveLoad = false
    private var isPaused = false
    /// Paused because in-flight buffers ran dry while waiting for progressive bytes.
    private var pausedForBuffering = false
    /// Consecutive progress ticks where currentTime exceeded duration (BUG3 watchdog).
    private var pastDurationTickCount = 0
    /// Last valid playback position before engine restart invalidates `lastRenderTime` (BUG16).
    private var lastKnownPlaybackTime: TimeInterval = 0
    /// Full app gain; loudness is controlled by the OS / system volume.
    private let userVolume: Float = 1.0

    private let maxBuffersInFlight = 8
    private let prefetchAheadCount = 10
    private let fadeSteps = 6
    private let fadeDuration: UInt64 = 15_000_000 // 15ms total
    private let pastDurationGrace: TimeInterval = 0.35
    private let pastDurationTicksToFinish = 3
    private let eqFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    let spectrumAnalyzer = SpectrumAnalyzer()

    var onProgress: ((TimeInterval, TimeInterval) -> Void)?
    var onTrackFinished: (() -> Void)?
    var onBuffering: ((Bool) -> Void)?
    var onDidStartPlayingBySystem: (() -> Void)?
    var onDidPauseBySystem: (() -> Void)?
    var onGaplessAdvance: ((TimeInterval) -> Void)?

    #if os(iOS)
    private var isInterrupted = false
    private var wasPlayingBeforeInterruption = false
    #endif

    init() {
        #if os(iOS)
        Self.configureAudioSession()
        installInterruptionObserver()
        installRouteChangeObserver()
        #endif

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

        engine.mainMixerNode.outputVolume = userVolume

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

    #if os(iOS)
    private static func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            engineLogger.error("AVAudioSession setup failed: \(error.localizedDescription)")
        }
    }

    private static func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            engineLogger.error("AVAudioSession activate failed: \(error.localizedDescription)")
        }
    }

    private func installInterruptionObserver() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleAudioSessionInterruption(notification)
            }
        }
    }

    private func installRouteChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleAudioSessionRouteChange(notification)
            }
        }
    }

    private func handleAudioSessionRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt else {
            return
        }
        guard AudioRouteInterruptionPolicy.shouldPauseForRouteChange(reasonRawValue: reasonValue) else {
            return
        }
        pauseBySystem()
    }

    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            isInterrupted = true
            wasPlayingBeforeInterruption = playerNode.isPlaying
            guard wasPlayingBeforeInterruption else { return }
            pauseBySystem()
        case .ended:
            isInterrupted = false
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            let shouldResume = options.contains(.shouldResume)
            Self.activateAudioSession()
            guard AudioRouteInterruptionPolicy.shouldResumeAfterInterruption(
                wasPlayingBeforeInterruption: wasPlayingBeforeInterruption,
                shouldResume: shouldResume
            ) else {
                wasPlayingBeforeInterruption = false
                return
            }
            wasPlayingBeforeInterruption = false
            play()
            onDidStartPlayingBySystem?()
        @unknown default:
            break
        }
    }
    #endif

    /// Immediate pause for route loss / call interruption — no fade (config change may follow within ~15 ms).
    private func pauseBySystem() {
        lastKnownPlaybackTime = max(lastKnownPlaybackTime, currentTime())
        playerNode.pause()
        stopProgressTimer()
        isPaused = true
        onDidPauseBySystem?()
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

        #if os(iOS)
        if !isInterrupted {
            Self.activateAudioSession()
        }
        #endif

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
        let playedFrames = AVAudioFramePosition(playerTime?.sampleTime ?? 0) - playerTimeBase
        return Double(segmentStartFrame + playedFrames) / sampleRate
    }

    func duration() -> TimeInterval {
        guard let format = processingFormat, format.sampleRate > 0 else {
            return knownDuration ?? 0
        }
        let frameDuration = totalFrameCount > 0
            ? Double(totalFrameCount) / format.sampleRate
            : 0
        // Prefer the longer of metadata vs discovered frames so UI duration never
        // under-reports while audio is still playing (avoids false BUG3 / watchdog).
        if let knownDuration, knownDuration > 0 {
            return max(knownDuration, frameDuration)
        }
        return frameDuration
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
        #if os(iOS)
        let interrupted = isInterrupted
        #else
        let interrupted = false
        #endif
        let shouldPlay = AudioRouteInterruptionPolicy.shouldPlayAfterConfigurationChange(
            isPlayerPlaying: playerNode.isPlaying,
            isPaused: isPaused,
            isInterrupted: interrupted
        )
        let resumeTime = max(currentTime(), lastKnownPlaybackTime)

        #if os(iOS)
        if !isInterrupted {
            Self.activateAudioSession()
        }
        #endif
        do {
            try engine.start()
            spectrumAnalyzer.start(on: engine.mainMixerNode, format: format)
            rescheduleBuffers(at: resumeTime, format: format, shouldPlay: shouldPlay)
            if shouldPlay {
                onDidStartPlayingBySystem?()
            }
        } catch {
            engineLogger.error("Engine restart after configuration change failed: \(error.localizedDescription)")
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
        rescheduleBuffers(at: time, format: format, shouldPlay: !isPaused)
    }

    /// Re-schedule buffers from the current playback position without always resuming play (BUG16).
    private func rescheduleBuffersAtCurrentTime(shouldPlay: Bool) {
        guard let format = processingFormat else { return }
        rescheduleBuffers(at: currentTime(), format: format, shouldPlay: shouldPlay)
    }

    private func rescheduleBuffers(at time: TimeInterval, format: AVAudioFormat, shouldPlay: Bool) {
        commitPendingGaplessAdvance()
        if shouldPlay && playerNode.isPlaying {
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
        engineLogger.info("Seek → \(String(format: "%.2f", time))s (chunk=\(seekChunk), offset=\(seekOffset), play=\(shouldPlay))")

        if shouldPlay {
            isPaused = false
        }
        playerTimeBase = 0
        decodePipeline?.reset()
        playerNode.stop()
        scheduleFromCurrentPosition()
        if shouldPlay, engine.isRunning, segmentStartFrame < playbackEndFrame() {
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
                            self.pauseForBufferingIfStarved()
                            let ok = await self.awaitMoreBytes(fromIndex: index, generation: generation)
                            self.onBuffering?(false)
                            guard ok else {
                                self.finishTrackIfNeeded(generation: generation, reason: "awaitMoreBytes failed")
                                return
                            }
                            let newAvailable = self.availableChunkCount()
                            if newAvailable <= available { break }
                            available = newAvailable
                        } else {
                            break
                        }
                    }

                    self.decodePipeline?.prefetch(from: index, to: min(available, index + self.prefetchAheadCount))

                    guard let pipeline = self.decodePipeline else {
                        self.finishTrackIfNeeded(generation: generation, reason: "decodePipeline nil")
                        return
                    }
                    let sourceChunk: AVAudioPCMBuffer
                    do {
                        sourceChunk = try await pipeline.buffer(for: index)
                    } catch {
                        engineLogger.error("Decode error at chunk \(index): \(error.localizedDescription)")
                        if self.isProgressiveLoad {
                            self.onBuffering?(true)
                            self.pauseForBufferingIfStarved()
                            let ok = await self.awaitMoreBytes(fromIndex: index, generation: generation)
                            self.onBuffering?(false)
                            guard ok else {
                                self.finishTrackIfNeeded(generation: generation, reason: "decode retry await failed")
                                return
                            }
                            continue
                        } else {
                            break
                        }
                    }
                    guard !Task.isCancelled, generation == self.scheduleGeneration else { return }

                    let buffer: AVAudioPCMBuffer
                    if index == firstIndex, self.segmentOffsetInFirstChunk > 0 {
                        let sliced = self.subBuffer(from: sourceChunk, startingAt: self.segmentOffsetInFirstChunk)
                        buffer = sliced ?? sourceChunk
                    } else {
                        buffer = sourceChunk
                    }

                    tracker.increment()
                    self.scheduledUpToIndex = index + 1

                    self.playerNode.scheduleBuffer(buffer, at: nil, completionCallbackType: .dataConsumed) { _ in
                        let remaining = tracker.decrementAndSignal()
                        if remaining == 0, tracker.isFinished {
                            Task { @MainActor [weak self] in
                                guard let self, generation == self.scheduleGeneration else { return }
                                self.fireTrackFinished(generation: generation, reason: "last buffer consumed")
                            }
                        }
                    }

                    self.resumeAfterBufferingIfNeeded()
                    index += 1
                }

                // Inner loop exited: all chunks of current source scheduled
                guard generation == self.scheduleGeneration, !Task.isCancelled else { return }

                // Gapless: continue with next track if prepared
                if let nextSource = self.nextChunkSource, let nextPipeline = self.nextDecodePipeline {
                    engineLogger.info("Gapless: transitioning to next track")
                    let sampleRate = self.processingFormat?.sampleRate ?? nextSource.format.sampleRate
                    let nextDuration = Double(nextSource.totalFrameCount) / nextSource.format.sampleRate
                    let oldTrackEndTime = sampleRate > 0
                        ? Double(self.totalFrameCount) / sampleRate
                        : nextDuration

                    self.pendingGaplessAdvance = (
                        callbackDuration: nextDuration,
                        oldTrackEndTime: oldTrackEndTime,
                        newTotalFrameCount: nextSource.totalFrameCount
                    )
                    self.playerTimeBase -= self.segmentStartFrame
                    self.knownDuration = nil
                    self.pastDurationTickCount = 0

                    self.chunkSource = nextSource
                    self.decodePipeline = nextPipeline
                    self.chunkDurationFrames = nextSource.chunkDurationFrames
                    self.segmentStartFrame = 0
                    self.segmentOffsetInFirstChunk = 0
                    self.scheduledUpToIndex = 0
                    self.isProgressiveLoad = false
                    self.nextChunkSource = nil
                    self.nextDecodePipeline = nil

                    index = 0
                    firstIndex = 0
                    continue trackLoop
                }

                // No gapless source — mark finished
                engineLogger.info("Scheduler: all chunks scheduled gen=\(generation)")
                self.finishTrackIfNeeded(generation: generation, reason: "all chunks scheduled")
                break trackLoop
            }
        }
    }

    /// Marks the track finished. If no buffers remain in flight, fires `onTrackFinished` immediately;
    /// otherwise the last `dataConsumed` callback will fire it.
    private func finishTrackIfNeeded(generation: Int, reason: String) {
        guard generation == scheduleGeneration else { return }
        bufferTracker.markFinished()
        pastDurationTickCount = 0
        if bufferTracker.count == 0 {
            fireTrackFinished(generation: generation, reason: reason)
        }
    }

    private func fireTrackFinished(generation: Int, reason: String) {
        guard generation == scheduleGeneration else { return }
        stopProgressTimer()
        pausedForBuffering = false
        pastDurationTickCount = 0
        engineLogger.info("Track finished (\(reason), gen=\(generation))")
        onTrackFinished?()
    }

    private func pauseForBufferingIfStarved() {
        guard !isPaused, !pausedForBuffering else { return }
        guard bufferTracker.count == 0, playerNode.isPlaying else { return }
        playerNode.pause()
        pausedForBuffering = true
        engineLogger.info("Paused for buffering (underrun prevention)")
    }

    private func resumeAfterBufferingIfNeeded() {
        guard pausedForBuffering, !isPaused else { return }
        pausedForBuffering = false
        if !playerNode.isPlaying {
            playerNode.play()
            Task { await fadeIn() }
        }
        engineLogger.info("Resumed after buffering")
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

        if isComplete, let finalURL = try? await asset.waitUntilComplete() {
            guard scheduleGeneration == capturedGeneration, !Task.isCancelled else { return }
            source.updateFileURL(finalURL)
            try await Task.detached {
                try source.refreshFromDisk(isDownloadComplete: true)
            }.value
            guard scheduleGeneration == capturedGeneration, !Task.isCancelled else { return }
            currentFileURL = finalURL
            isProgressiveLoad = false
            totalFrameCount = source.totalFrameCount
            knownDuration = nil
        } else {
            try await Task.detached {
                try source.refreshFromDisk(isDownloadComplete: isComplete)
            }.value
            guard scheduleGeneration == capturedGeneration, !Task.isCancelled else { return }
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
        playerTimeBase = 0
        pendingGaplessAdvance = nil
        pausedForBuffering = false
        pastDurationTickCount = 0
        lastKnownPlaybackTime = 0
        if resetProgress {
            segmentStartFrame = 0
        }
    }

    private func startProgressTimer() {
        stopProgressTimer()
        pastDurationTickCount = 0
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
        if let pending = pendingGaplessAdvance, currentTime() >= pending.oldTrackEndTime {
            commitPendingGaplessAdvance()
            pastDurationTickCount = 0
        }

        let current = currentTime()
        let total = duration()

        if pendingGaplessAdvance == nil, total > 0, current >= total + pastDurationGrace {
            pastDurationTickCount += 1
            if pastDurationTickCount >= pastDurationTicksToFinish {
                engineLogger.info("Progress watchdog: current=\(String(format: "%.2f", current)) duration=\(String(format: "%.2f", total))")
                finishTrackIfNeeded(generation: scheduleGeneration, reason: "progress watchdog")
                return
            }
        } else {
            pastDurationTickCount = 0
        }

        lastKnownPlaybackTime = max(lastKnownPlaybackTime, current)
        onProgress?(current, total)
    }

    private func commitPendingGaplessAdvance() {
        guard let pending = pendingGaplessAdvance else { return }
        if let nodeTime = playerNode.lastRenderTime,
           let pTime = playerNode.playerTime(forNodeTime: nodeTime) {
            playerTimeBase = AVAudioFramePosition(pTime.sampleTime)
        }
        totalFrameCount = pending.newTotalFrameCount
        knownDuration = nil
        pendingGaplessAdvance = nil
        pastDurationTickCount = 0
        onGaplessAdvance?(pending.callbackDuration)
    }
}

// MARK: - Buffer flight tracker

/// Thread-safe tracker for in-flight audio buffers. Called from the audio render
/// thread (scheduleBuffer completion) without hopping through MainActor.
private final class BufferFlightTracker: @unchecked Sendable {
    private struct State: @unchecked Sendable {
        var count = 0
        var finished = false
        var waiter: CheckedContinuation<Void, Never>?
    }

    private let lock = OSAllocatedUnfairLock(initialState: State())

    var count: Int {
        lock.withLock { $0.count }
    }

    var isFinished: Bool {
        lock.withLock { $0.finished }
    }

    func increment() {
        lock.withLock { $0.count += 1 }
    }

    /// Returns remaining count after decrement. Wakes the scheduler if it's waiting.
    @discardableResult
    func decrementAndSignal() -> Int {
        let (remaining, waiter): (Int, CheckedContinuation<Void, Never>?) = lock.withLock { state in
            state.count = max(0, state.count - 1)
            let remaining = state.count
            let waiter = state.waiter
            state.waiter = nil
            return (remaining, waiter)
        }
        waiter?.resume()
        return remaining
    }

    func markFinished() {
        lock.withLock { $0.finished = true }
    }

    func reset() {
        let waiter = lock.withLock { state -> CheckedContinuation<Void, Never>? in
            state.count = 0
            state.finished = false
            let waiter = state.waiter
            state.waiter = nil
            return waiter
        }
        waiter?.resume()
    }

    func waitForConsumption() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.withLock { $0.waiter = continuation }
        }
    }
}

// MARK: - Decode pipeline

private final class ChunkDecodePipeline: @unchecked Sendable {
    private struct State: @unchecked Sendable {
        var ready: [Int: AVAudioPCMBuffer] = [:]
        var inFlight: Set<Int> = []
        var waiters: [Int: [CheckedContinuation<AVAudioPCMBuffer, Error>]] = [:]
    }

    private let source: LazyChunkSource
    private let lock = OSAllocatedUnfairLock(initialState: State())
    /// Serialize decodes so MP3 reads stay contiguous (avoid seek-per-chunk artifacts).
    private let decodeQueue = DispatchQueue(label: "dev.personal.cadence.chunk-decode")

    init(source: LazyChunkSource) {
        self.source = source
    }

    func reset() {
        let pending = lock.withLock { state -> [Int: [CheckedContinuation<AVAudioPCMBuffer, Error>]] in
            state.ready.removeAll(keepingCapacity: true)
            state.inFlight.removeAll()
            let pending = state.waiters
            state.waiters.removeAll()
            return pending
        }

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
        if let cached = lock.withLock({ $0.ready[index] }) {
            return cached
        }

        startDecodeIfNeeded(index: index)

        return try await withCheckedThrowingContinuation { continuation in
            let cached: AVAudioPCMBuffer? = lock.withLock { state in
                if let cached = state.ready[index] {
                    return cached
                }
                state.waiters[index, default: []].append(continuation)
                return nil
            }
            if let cached {
                continuation.resume(returning: cached)
            }
        }
    }

    private func startDecodeIfNeeded(index: Int) {
        let shouldStart = lock.withLock { state -> Bool in
            if state.ready[index] != nil || state.inFlight.contains(index) {
                return false
            }
            state.inFlight.insert(index)
            return true
        }
        guard shouldStart else { return }

        engineLogger.debug("Chunk \(index) decode started")

        decodeQueue.async { [source] in
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
        let continuations: [CheckedContinuation<AVAudioPCMBuffer, Error>] = lock.withLock { state in
            state.inFlight.remove(index)
            switch result {
            case .success(let buffer):
                state.ready[index] = buffer
            case .failure:
                break
            }
            return state.waiters.removeValue(forKey: index) ?? []
        }

        switch result {
        case .success(let buffer):
            for continuation in continuations {
                continuation.resume(returning: buffer)
            }
        case .failure(let error):
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

    private struct State: @unchecked Sendable {
        var fileURL: URL
        var audioFile: AVAudioFile?
        var chunkCache: [Int: AVAudioPCMBuffer] = [:]
        var downloadedBytes: Int64 = 0
        var expectedTotalBytes: Int64?
        /// Next chunk index that can be read without seeking (MP3 decoder continuity).
        var nextSequentialIndex: Int?
    }

    private let lock: OSAllocatedUnfairLock<State>
    private let maxCachedChunks = 16
    private let isProgressive: Bool

    init(url: URL, isProgressive: Bool) throws {
        self.isProgressive = isProgressive
        let audioFile = try AVAudioFile(forReading: url)
        self.format = audioFile.processingFormat
        self.chunkDurationFrames = Self.packetAlignedChunkFrames(format: format)
        self.totalFrameCount = audioFile.length
        self.lock = OSAllocatedUnfairLock(initialState: State(fileURL: url, audioFile: audioFile))
    }


    /// Apple's MP3 decoder emits a silent granule (1152 samples) when the bitstream
    /// has a mid-file frame gap. EQ then rings on that zero → audible "quack".
    /// Other decoders (ffmpeg) conceal; we linearly interpolate the hole instead.
    private static func concealSilentGranules(
        buffer: AVAudioPCMBuffer,
        startFrame: AVAudioFramePosition,
        fileLength: AVAudioFramePosition
    ) -> Int {
        guard let channels = buffer.floatChannelData else { return 0 }
        let count = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard count > 2, channelCount > 0 else { return 0 }

        let ch0 = channels[0]
        var concealed = 0
        var i = 0
        while i < count {
            if abs(ch0[i]) < 1e-7 {
                let runStart = i
                i += 1
                while i < count, abs(ch0[i]) < 1e-7 { i += 1 }
                let run = i - runStart
                let absoluteStart = startFrame + AVAudioFramePosition(runStart)
                let absoluteEnd = absoluteStart + AVAudioFramePosition(run)
                let isPadding = absoluteStart < 1200 || absoluteEnd + 1200 > fileLength
                let isGranule = run >= 576 && run <= 2304
                guard isGranule, !isPadding else { continue }

                for channel in 0..<channelCount {
                    let data = channels[channel]
                    let left = runStart > 0 ? data[runStart - 1] : 0
                    let right = i < count ? data[i] : left
                    let denom = Float(run + 1)
                    for k in 0..<run {
                        let t = Float(k + 1) / denom
                        data[runStart + k] = left + (right - left) * t
                    }
                }
                concealed += 1
            } else {
                i += 1
            }
        }
        return concealed
    }

    /// 1s-ish chunks that land on codec packet boundaries (MP3 1152, AAC 1024).
    /// Unaligned 44100-frame reads split granules and click even on sequential decode.
    private static func packetAlignedChunkFrames(format: AVAudioFormat) -> AVAudioFrameCount {
        let sampleRate = max(1, Int(format.sampleRate.rounded()))
        let packetFrames = Int(format.streamDescription.pointee.mFramesPerPacket)
        guard packetFrames > 1 else {
            return AVAudioFrameCount(sampleRate)
        }
        let packets = max(1, sampleRate / packetFrames)
        return AVAudioFrameCount(packets * packetFrames)
    }

    func updateDownloadProgress(downloaded: Int64, total: Int64?) {
        lock.withLock { state in
            state.downloadedBytes = downloaded
            if let total { state.expectedTotalBytes = total }
        }
    }

    private func computeSafeLimit(
        fileLength: AVAudioFramePosition,
        isDownloadComplete: Bool,
        downloadedBytes: Int64,
        expectedTotalBytes: Int64?
    ) -> AVAudioFramePosition {
        if !isProgressive || isDownloadComplete { return fileLength }
        if let total = expectedTotalBytes, total > 0, fileLength > 0 {
            let ratio = min(1.0, Double(downloadedBytes) / Double(total))
            let estimated = AVAudioFramePosition(Double(fileLength) * ratio)
            return max(0, estimated - ProgressivePlayback.safetyMarginFrames)
        }
        return max(0, fileLength - ProgressivePlayback.safetyMarginFrames)
    }

    func updateFileURL(_ url: URL) {
        lock.withLock { state in
            state.fileURL = url
            state.audioFile = nil
            state.nextSequentialIndex = nil
        }
    }

    func refreshFromDisk(isDownloadComplete: Bool) throws {
        try lock.withLock { state in
            state.audioFile = try AVAudioFile(forReading: state.fileURL)
            guard let audioFile = state.audioFile else { throw Error.allocationFailed }
            totalFrameCount = audioFile.length
            state.nextSequentialIndex = nil

            let safeFrames = computeSafeLimit(
                fileLength: totalFrameCount,
                isDownloadComplete: isDownloadComplete,
                downloadedBytes: state.downloadedBytes,
                expectedTotalBytes: state.expectedTotalBytes
            )
            guard chunkDurationFrames > 0 else { return }
            let safeChunkLimit = Int(safeFrames / AVAudioFramePosition(chunkDurationFrames))

            state.chunkCache = state.chunkCache.filter { key, _ in
                key < max(0, safeChunkLimit - 1)
            }
        }
    }

    func safeReadableFrameCount(isDownloadComplete: Bool) -> AVAudioFramePosition {
        lock.withLock { state in
            computeSafeLimit(
                fileLength: totalFrameCount,
                isDownloadComplete: isDownloadComplete,
                downloadedBytes: state.downloadedBytes,
                expectedTotalBytes: state.expectedTotalBytes
            )
        }
    }

    func decodeChunk(at index: Int) throws -> AVAudioPCMBuffer {
        try lock.withLock { state in
            if let cached = state.chunkCache[index] {
                engineLogger.debug("Chunk \(index) cache hit")
                return cached
            }

            if state.audioFile == nil {
                state.audioFile = try AVAudioFile(forReading: state.fileURL)
                state.nextSequentialIndex = nil
            }
            guard let file = state.audioFile else {
                throw Error.allocationFailed
            }

            let startFrame = AVAudioFramePosition(index) * AVAudioFramePosition(chunkDurationFrames)
            let safeLimit = computeSafeLimit(
                fileLength: file.length,
                isDownloadComplete: !isProgressive,
                downloadedBytes: state.downloadedBytes,
                expectedTotalBytes: state.expectedTotalBytes
            )
            if startFrame >= safeLimit {
                throw Error.readBeyondBoundary
            }

            let posBefore = file.framePosition
            let canContinue =
                state.nextSequentialIndex == index
                && posBefore == startFrame
            if !canContinue {
                file.framePosition = startFrame
            }

            let remaining = AVAudioFrameCount(min(
                AVAudioFramePosition(chunkDurationFrames),
                safeLimit - startFrame
            ))
            guard remaining > 0 else {
                throw Error.readBeyondBoundary
            }

            engineLogger.debug("Chunk \(index) decoding frames \(startFrame)–\(startFrame + Int64(remaining)) seek=\(!canContinue)")

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: remaining) else {
                throw Error.allocationFailed
            }

            do {
                try file.read(into: buffer, frameCount: remaining)
                _ = Self.concealSilentGranules(
                    buffer: buffer,
                    startFrame: startFrame,
                    fileLength: file.length
                )
            } catch {
                state.nextSequentialIndex = nil
                if isProgressive {
                    throw Error.readBeyondBoundary
                }
                throw error
            }

            state.nextSequentialIndex = index + 1
            state.chunkCache[index] = buffer
            if state.chunkCache.count > maxCachedChunks {
                let keysToRemove = state.chunkCache.keys.sorted().prefix(state.chunkCache.count - maxCachedChunks)
                for key in keysToRemove {
                    engineLogger.debug("Cache evict: chunk \(key)")
                    state.chunkCache.removeValue(forKey: key)
                }
            }

            return buffer
        }
    }
}
