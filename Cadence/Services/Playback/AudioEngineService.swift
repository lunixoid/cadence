import AVFoundation
import Foundation
import os.log

private let logger = Logger(subsystem: "dev.personal.cadence", category: "AudioEngine")

@MainActor
final class AudioEngineService {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eqNode = AVAudioUnitEQ(numberOfBands: 10)
    private var audioFile: AVAudioFile?
    private var progressTimer: Timer?
    private var currentFileURL: URL?
    private var segmentStartFrame: AVAudioFramePosition = 0
    private var scheduleGeneration = 0

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

    func load(url: URL) throws {
        stopInternal(resetProgress: true)
        currentFileURL = url

        let file = try AVAudioFile(forReading: url)
        audioFile = file
        segmentStartFrame = 0

        engine.disconnectNodeOutput(playerNode)
        engine.disconnectNodeOutput(eqNode)
        engine.connect(playerNode, to: eqNode, format: file.processingFormat)
        engine.connect(eqNode, to: engine.mainMixerNode, format: file.processingFormat)

        if !engine.isRunning {
            try engine.start()
        }
    }

    func loadRemote(url: URL) async throws {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        let (localURL, response) = try await URLSession.shared.download(for: request)
        let ext = (response as? HTTPURLResponse)
            .flatMap { $0.value(forHTTPHeaderField: "Content-Type") }
            .flatMap { Self.ext(forContentType: $0) }
            ?? "mp3"
        let destURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try FileManager.default.moveItem(at: localURL, to: destURL)
        try load(url: destURL)
    }

    static func ext(forContentType contentType: String) -> String? {
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

    func setBandGain(at index: Int, gain: Float) {
        guard index < eqNode.bands.count else { return }
        eqNode.bands[index].gain = gain
    }

    func setEQEnabled(_ enabled: Bool) {
        eqNode.bypass = !enabled
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
