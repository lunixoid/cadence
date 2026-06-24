import AVFoundation
import Accelerate
import Foundation

struct SpectrumBand {
    var magnitude: Float  // 0..1, current smoothed level
    var peak: Float       // 0..1, peak-hold level
}

@Observable
@MainActor
final class SpectrumAnalyzer {
    private(set) var bands: [SpectrumBand] = Array(
        repeating: SpectrumBand(magnitude: 0, peak: 0), count: 10
    )

    // EQ band center frequencies (Hz)
    private let centerFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    // Geometric mean bin edges between adjacent centers, plus low/high bounds
    private let bandEdges: [Float] = [22, 45, 89, 177, 354, 707, 1414, 2828, 5657, 11314, 22050]

    private let fftSize = 2048
    private var fftSetup: FFTSetup?
    private var window: [Float] = []
    private var log2n: vDSP_Length = 0

    // Smoothed magnitudes (carry-over between buffers)
    private var smoothed: [Float] = Array(repeating: 0, count: 10)
    // Peak hold counters (frames)
    private var peakValues: [Float] = Array(repeating: 0, count: 10)
    private var peakHoldCounters: [Int] = Array(repeating: 0, count: 10)
    private let peakHoldFrames = 45
    private let peakDecayRate: Float = 0.008

    private let attackCoeff: Float = 0.30
    private let releaseCoeff: Float = 0.12

    private var tapNode: AVAudioNode?
    private var tapFormat: AVAudioFormat?

    func start(on node: AVAudioNode, format: AVAudioFormat) {
        stop()

        let n = vDSP_Length(fftSize)
        log2n = vDSP_Length(log2(Double(n)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, n, Int32(vDSP_HANN_NORM))

        tapNode = node
        tapFormat = format

        // Tap the output bus of the node. bufferSize is a hint — AVAudioEngine may deliver
        // more or fewer frames per callback, so we handle arbitrary sizes below.
        let bufferSize = AVAudioFrameCount(fftSize)
        node.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }
    }

    func stop() {
        tapNode?.removeTap(onBus: 0)
        tapNode = nil
        tapFormat = nil
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
            fftSetup = nil
        }
        // Reset smoothed levels
        smoothed = Array(repeating: 0, count: 10)
        peakValues = Array(repeating: 0, count: 10)
        peakHoldCounters = Array(repeating: 0, count: 10)
        Task { @MainActor [weak self] in
            self?.bands = Array(repeating: SpectrumBand(magnitude: 0, peak: 0), count: 10)
        }
    }

    // Called from AVAudioEngine tap thread (not MainActor).
    private func process(buffer: AVAudioPCMBuffer) {
        guard let setup = fftSetup,
              let channelData = buffer.floatChannelData else { return }

        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        // Mix down to mono by averaging channels
        let channelCount = Int(buffer.format.channelCount)
        var mono = [Float](repeating: 0, count: fftSize)
        let copyLen = min(frameCount, fftSize)

        if channelCount == 1 {
            for i in 0..<copyLen { mono[i] = channelData[0][i] }
        } else {
            // Average all channels
            for ch in 0..<channelCount {
                for i in 0..<copyLen { mono[i] += channelData[ch][i] }
            }
            var scale = 1.0 / Float(channelCount)
            vDSP_vsmul(mono, 1, &scale, &mono, 1, vDSP_Length(copyLen))
        }

        // Apply Hann window
        vDSP_vmul(mono, 1, window, 1, &mono, 1, vDSP_Length(fftSize))

        // Pack into split-complex format for vDSP FFT
        var realp = [Float](repeating: 0, count: fftSize / 2)
        var imagp = [Float](repeating: 0, count: fftSize / 2)

        realp.withUnsafeMutableBufferPointer { rPtr in
            imagp.withUnsafeMutableBufferPointer { iPtr in
                var sc = DSPSplitComplex(realp: rPtr.baseAddress!, imagp: iPtr.baseAddress!)
                mono.withUnsafeBytes { rawPtr in
                    let cPtr = rawPtr.bindMemory(to: DSPComplex.self)
                    vDSP_ctoz(cPtr.baseAddress!, 2, &sc, 1, vDSP_Length(fftSize / 2))
                }
                vDSP_fft_zrip(setup, &sc, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }

        // Compute magnitudes (linear scale)
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        realp.withUnsafeMutableBufferPointer { rPtr in
            imagp.withUnsafeMutableBufferPointer { iPtr in
                var sc = DSPSplitComplex(realp: rPtr.baseAddress!, imagp: iPtr.baseAddress!)
                vDSP_zvabs(&sc, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Normalise by FFT size
        var normaliser = 1.0 / Float(fftSize)
        vDSP_vsmul(magnitudes, 1, &normaliser, &magnitudes, 1, vDSP_Length(fftSize / 2))

        // Map FFT bins → 10 EQ bands
        let sampleRate = buffer.format.sampleRate > 0 ? Float(buffer.format.sampleRate) : 44100
        let binWidth = sampleRate / Float(fftSize)

        var newSmoothed = [Float](repeating: 0, count: 10)
        for band in 0..<10 {
            let loHz = bandEdges[band]
            let hiHz = bandEdges[band + 1]
            let loBin = max(1, Int(loHz / binWidth))
            let hiBin = min(fftSize / 2 - 1, Int(hiHz / binWidth))

            guard hiBin >= loBin else { continue }

            var sum: Float = 0
            magnitudes.withUnsafeBufferPointer { ptr in
                vDSP_sve(ptr.baseAddress! + loBin, 1, &sum, vDSP_Length(hiBin - loBin + 1))
            }
            let avg = sum / Float(hiBin - loBin + 1)

            // Convert to dB, clamp, normalise to 0..1 in range -60..0 dB
            let dB = avg > 0 ? 20 * log10(avg) : -100
            let normalized = max(0, min(1, (dB + 60) / 60))

            // Exponential smoothing
            let coeff = normalized > smoothed[band] ? attackCoeff : releaseCoeff
            newSmoothed[band] = smoothed[band] + coeff * (normalized - smoothed[band])
        }

        let capturedSmoothed = newSmoothed
        let capturedPeaks = peakValues
        let capturedCounters = peakHoldCounters

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.smoothed = capturedSmoothed

            var newBands = [SpectrumBand](repeating: SpectrumBand(magnitude: 0, peak: 0), count: 10)
            for i in 0..<10 {
                let mag = capturedSmoothed[i]
                var peak = capturedPeaks[i]
                var holdCounter = capturedCounters[i]

                if mag >= peak {
                    peak = mag
                    holdCounter = self.peakHoldFrames
                } else if holdCounter > 0 {
                    holdCounter -= 1
                } else {
                    peak = max(mag, peak - self.peakDecayRate)
                }

                self.peakValues[i] = peak
                self.peakHoldCounters[i] = holdCounter
                newBands[i] = SpectrumBand(magnitude: mag, peak: peak)
            }
            self.bands = newBands
        }
    }
}
