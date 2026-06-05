import AVFoundation
import Foundation
import os.log

private let logger = Logger(subsystem: "dev.personal.cadence", category: "AudioEngine")

@MainActor
final class AudioEngineService {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var progressTimer: Timer?
    private var currentFileURL: URL?
    private var segmentStartFrame: AVAudioFramePosition = 0
    private var scheduleGeneration = 0

    var onProgress: ((TimeInterval, TimeInterval) -> Void)?
    var onTrackFinished: (() -> Void)?

    var volume: Double {
        get { Double(engine.mainMixerNode.outputVolume) * 100 }
        set { engine.mainMixerNode.outputVolume = Float(newValue / 100) }
    }

    init() {
        engine.attach(playerNode)
        volume = 72
    }

    func load(url: URL) throws {
        stopInternal(resetProgress: true)
        currentFileURL = url

        let file = try AVAudioFile(forReading: url)
        audioFile = file
        segmentStartFrame = 0

        engine.disconnectNodeOutput(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: file.processingFormat)

        if !engine.isRunning {
            try engine.start()
        }
    }

    func play() {
        guard let file = audioFile else { return }

        if !engine.isRunning {
            try? engine.start()
        }

        if playerNode.isPlaying {
            return
        }

        scheduleFromCurrentPosition(file: file)
        playerNode.play()
        startProgressTimer()
    }

    func pause() {
        playerNode.pause()
        stopProgressTimer()
    }

    func stop() {
        stopInternal(resetProgress: true)
    }

    func seek(to time: TimeInterval) {
        guard let file = audioFile else { return }
        let sampleRate = file.processingFormat.sampleRate
        let frame = AVAudioFramePosition(time * sampleRate)
        segmentStartFrame = min(max(frame, 0), file.length)
        playerNode.stop()
        scheduleFromCurrentPosition(file: file)
        if engine.isRunning {
            playerNode.play()
        }
        emitProgress()
    }

    func currentTime() -> TimeInterval {
        guard let file = audioFile else { return 0 }
        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return 0 }
        let nodeTime = playerNode.lastRenderTime
        let playerTime = playerNode.playerTime(forNodeTime: nodeTime ?? AVAudioTime(sampleTime: 0, atRate: sampleRate))
        let playedFrames = AVAudioFramePosition(playerTime?.sampleTime ?? 0)
        return Double(segmentStartFrame + playedFrames) / sampleRate
    }

    func duration() -> TimeInterval {
        guard let file = audioFile else { return 0 }
        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return 0 }
        return Double(file.length) / sampleRate
    }

    var isPlaying: Bool {
        playerNode.isPlaying
    }

    private func scheduleFromCurrentPosition(file: AVAudioFile) {
        scheduleGeneration += 1
        let generation = scheduleGeneration
        let frameCount = file.length - segmentStartFrame
        guard frameCount > 0 else {
            onTrackFinished?()
            return
        }

        playerNode.scheduleSegment(
            file,
            startingFrame: segmentStartFrame,
            frameCount: AVAudioFrameCount(frameCount),
            at: nil
        ) { [weak self] in
            Task { @MainActor in
                guard let self, generation == self.scheduleGeneration else { return }
                self.stopProgressTimer()
                self.onTrackFinished?()
            }
        }
    }

    private func stopInternal(resetProgress: Bool) {
        scheduleGeneration += 1
        playerNode.stop()
        stopProgressTimer()
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
