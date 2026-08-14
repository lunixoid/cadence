import AVFoundation
import Accelerate
import Foundation

struct SpectrumBand {
    var magnitude: Float  // 0..1, current smoothed level
    var peak: Float       // 0..1, peak-hold level
}

/// Audio-thread capture + off-thread FFT. The tap only copies a small mono window.
private final class SpectrumTapEngine: @unchecked Sendable {
    private let fftSize = 2048
    private let bandCount = 10
    private let bandEdges: [Float] = [22, 45, 89, 177, 354, 707, 1414, 2828, 5657, 11314, 22050]
    private let attackCoeff: Float = 0.30
    private let releaseCoeff: Float = 0.12

    private var fftSetup: FFTSetup?
    private var log2n: vDSP_Length = 0
    private var window: [Float]
    private var mono: [Float]
    /// Written only from the audio tap thread; never shared with FFT.
    private var tapScratch: [Float]
    private var realp: [Float]
    private var imagp: [Float]
    private var magnitudes: [Float]
    private var smoothed: [Float]
    private var workSmoothed: [Float]

    private struct CaptureState: Sendable {
        var samples: [Float]
        var copyLen = 0
        var pending = false
    }
    private let captureLock = OSAllocatedUnfairLock(initialState: CaptureState(samples: Array(repeating: 0, count: 2048)))

    private struct PublishState: Sendable {
        var pending = false
        var values: [Float] = Array(repeating: 0, count: 10)
    }
    private let publishLock = OSAllocatedUnfairLock(initialState: PublishState())

    init() {
        window = [Float](repeating: 0, count: fftSize)
        mono = [Float](repeating: 0, count: fftSize)
        tapScratch = [Float](repeating: 0, count: fftSize)
        realp = [Float](repeating: 0, count: fftSize / 2)
        imagp = [Float](repeating: 0, count: fftSize / 2)
        magnitudes = [Float](repeating: 0, count: fftSize / 2)
        smoothed = [Float](repeating: 0, count: bandCount)
        workSmoothed = [Float](repeating: 0, count: bandCount)
    }

    func start() {
        stop()
        let n = vDSP_Length(fftSize)
        log2n = vDSP_Length(log2(Double(n)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        vDSP_hann_window(&window, n, Int32(vDSP_HANN_NORM))
        for i in 0..<bandCount { smoothed[i] = 0 }
        captureLock.withLock { state in
            state.pending = false
            state.copyLen = 0
            for i in 0..<fftSize { state.samples[i] = 0 }
        }
        publishLock.withLock { state in
            state.pending = false
            for i in 0..<bandCount { state.values[i] = 0 }
        }
    }

    func stop() {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
            fftSetup = nil
        }
    }

    /// Audio-thread only: copy a tiny mono window. Skip if FFT has not consumed the last capture.
    func captureFromTap(buffer: AVAudioPCMBuffer) {
        let alreadyPending = captureLock.withLock { $0.pending }
        guard !alreadyPending else { return }

        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }
        let channelCount = Int(buffer.format.channelCount)
        let copyLen = min(frameCount, 256, fftSize)

        if channelCount == 1 {
            for i in 0..<copyLen { tapScratch[i] = channelData[0][i] }
        } else {
            let scale = 1.0 / Float(channelCount)
            for i in 0..<copyLen {
                var sum: Float = 0
                for ch in 0..<channelCount { sum += channelData[ch][i] }
                tapScratch[i] = sum * scale
            }
        }
        for i in copyLen..<min(copyLen + 1, fftSize) { tapScratch[i] = 0 }

        captureLock.withLock { state in
            state.copyLen = copyLen
            for i in 0..<copyLen { state.samples[i] = tapScratch[i] }
            state.pending = true
        }

    }

    /// Off audio thread: FFT + banding. Returns true if MainActor should publish.
    func processCaptured() -> Bool {
        guard fftSetup != nil else { return false }

        let hasCapture = captureLock.withLock { state -> Bool in
            guard state.pending else { return false }
            state.pending = false
            let n = min(state.copyLen, fftSize)
            for i in 0..<n { mono[i] = state.samples[i] }
            if n < fftSize {
                for i in n..<fftSize { mono[i] = 0 }
            }
            return true
        }
        guard hasCapture else { return false }

        guard let setup = fftSetup else { return false }

        vDSP_vmul(mono, 1, window, 1, &mono, 1, vDSP_Length(fftSize))

        realp.withUnsafeMutableBufferPointer { rPtr in
            imagp.withUnsafeMutableBufferPointer { iPtr in
                var sc = DSPSplitComplex(realp: rPtr.baseAddress!, imagp: iPtr.baseAddress!)
                mono.withUnsafeBytes { rawPtr in
                    let cPtr = rawPtr.bindMemory(to: DSPComplex.self)
                    vDSP_ctoz(cPtr.baseAddress!, 2, &sc, 1, vDSP_Length(fftSize / 2))
                }
                vDSP_fft_zrip(setup, &sc, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&sc, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        var normaliser = 1.0 / Float(fftSize)
        vDSP_vsmul(magnitudes, 1, &normaliser, &magnitudes, 1, vDSP_Length(fftSize / 2))

        // Assume 44.1k when processing off-thread without format; bands still usable for UI.
        let sampleRate: Float = 44100
        let binWidth = sampleRate / Float(fftSize)

        for band in 0..<bandCount {
            let loHz = bandEdges[band]
            let hiHz = bandEdges[band + 1]
            let loBin = max(1, Int(loHz / binWidth))
            let hiBin = min(fftSize / 2 - 1, Int(hiHz / binWidth))
            guard hiBin >= loBin else {
                workSmoothed[band] = smoothed[band]
                continue
            }

            var sum: Float = 0
            magnitudes.withUnsafeBufferPointer { ptr in
                vDSP_sve(ptr.baseAddress! + loBin, 1, &sum, vDSP_Length(hiBin - loBin + 1))
            }
            let avg = sum / Float(hiBin - loBin + 1)
            let dB = avg > 0 ? 20 * log10(avg) : -100
            let normalized = max(0, min(1, (dB + 60) / 60))
            let coeff = normalized > smoothed[band] ? attackCoeff : releaseCoeff
            workSmoothed[band] = smoothed[band] + coeff * (normalized - smoothed[band])
        }

        for i in 0..<bandCount { smoothed[i] = workSmoothed[i] }

        return publishLock.withLock { state in
            for i in 0..<bandCount { state.values[i] = workSmoothed[i] }
            let shouldKick = !state.pending
            state.pending = true
            return shouldKick
        }
    }

    func takePendingSmoothed() -> [Float]? {
        publishLock.withLock { state in
            guard state.pending else { return nil }
            state.pending = false
            return state.values
        }
    }
}

@Observable
@MainActor
final class SpectrumAnalyzer {
    private(set) var bands: [SpectrumBand] = Array(
        repeating: SpectrumBand(magnitude: 0, peak: 0), count: 10
    )

    private let peakHoldFrames = 45
    private let peakDecayRate: Float = 0.008

    private var peakValues: [Float] = Array(repeating: 0, count: 10)
    private var peakHoldCounters: [Int] = Array(repeating: 0, count: 10)

    private var tapNode: AVAudioNode?
    private let engine = SpectrumTapEngine()
    private var analysisTimer: Timer?
    private let analysisQueue = DispatchQueue(label: "dev.personal.cadence.spectrum", qos: .utility)


    func start(on node: AVAudioNode, format: AVAudioFormat) {
        stop()
        engine.start()
        tapNode = node

        let bufferSize = AVAudioFrameCount(256)
        node.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [engine] buffer, _ in
            engine.captureFromTap(buffer: buffer)
        }

        let timer = Timer(timeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.analysisQueue.async { [weak self] in
                guard let self else { return }
                guard self.engine.processCaptured() else { return }
                Task { @MainActor [weak self] in
                    self?.publishPending()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        analysisTimer = timer
        _ = format
    }

    func stop() {
        analysisTimer?.invalidate()
        analysisTimer = nil
        tapNode?.removeTap(onBus: 0)
        tapNode = nil
        engine.stop()
        peakValues = Array(repeating: 0, count: 10)
        peakHoldCounters = Array(repeating: 0, count: 10)
        bands = Array(repeating: SpectrumBand(magnitude: 0, peak: 0), count: 10)
    }

    private func publishPending() {
        guard let smoothed = engine.takePendingSmoothed() else { return }

        var newBands = [SpectrumBand](repeating: SpectrumBand(magnitude: 0, peak: 0), count: 10)
        for i in 0..<min(10, smoothed.count) {
            let mag = smoothed[i]
            var peak = peakValues[i]
            var holdCounter = peakHoldCounters[i]

            if mag >= peak {
                peak = mag
                holdCounter = peakHoldFrames
            } else if holdCounter > 0 {
                holdCounter -= 1
            } else {
                peak = max(mag, peak - peakDecayRate)
            }

            peakValues[i] = peak
            peakHoldCounters[i] = holdCounter
            newBands[i] = SpectrumBand(magnitude: mag, peak: peak)
        }
        bands = newBands
    }
}
