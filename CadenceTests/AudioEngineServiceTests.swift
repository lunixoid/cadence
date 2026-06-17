import AVFoundation
import XCTest
@testable import Cadence

@MainActor
final class AudioEngineServiceTests: XCTestCase {

    private var sut: AudioEngineService!
    private var wavURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        wavURL = try makeSilentWAV(duration: 0.5)
        sut = AudioEngineService()
        do {
            try await sut.load(url: wavURL)
        } catch {
            try? FileManager.default.removeItem(at: wavURL)
            throw XCTSkip("AVAudioEngine could not start (no audio output): \(error)")
        }
    }

    override func tearDown() async throws {
        sut.stop()
        sut = nil
        try? FileManager.default.removeItem(at: wavURL)
        wavURL = nil
        try await super.tearDown()
    }

    // MARK: - Fix 3: natural completion fires onTrackFinished

    func testNaturalCompletionFiresOnTrackFinished() async throws {
        let exp = expectation(description: "onTrackFinished")
        exp.assertForOverFulfill = false
        sut.onTrackFinished = { exp.fulfill() }
        sut.play()
        await fulfillment(of: [exp], timeout: 2.5)
    }

    // MARK: - Fix 1: seek near end still completes (not immediate)

    func testSeekNearEndEventuallyCompletes() async throws {
        let dur = sut.duration()
        XCTAssertGreaterThan(dur, 0)
        let exp = expectation(description: "onTrackFinished after 99% seek")
        sut.onTrackFinished = { exp.fulfill() }
        sut.seek(to: dur * 0.99)
        sut.play()
        await fulfillment(of: [exp], timeout: 3.0)
    }

    // MARK: - Fix 1 + Fix 5: seek past duration clamps and completes

    func testSeekPastDurationClampsAndCompletes() async throws {
        let dur = sut.duration()
        XCTAssertGreaterThan(dur, 0)
        let exp = expectation(description: "onTrackFinished after out-of-bounds seek")
        sut.onTrackFinished = { exp.fulfill() }
        sut.seek(to: dur + 10.0)
        sut.play()
        await fulfillment(of: [exp], timeout: 3.0)
    }

    // MARK: - Fix 1 + Fix 2: seek to middle does NOT fire immediately

    func testSeekToMiddleDoesNotImmediatelyComplete() async throws {
        let dur = sut.duration()
        XCTAssertGreaterThan(dur, 0)
        var fired = false
        sut.onTrackFinished = { fired = true }
        sut.seek(to: dur * 0.5)
        sut.play()
        // 150 ms < remaining 250 ms of a 0.5 s track; should not have fired yet
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertFalse(fired,
            "onTrackFinished must not fire within 150 ms of seeking to 50% of a 0.5 s track")
        sut.pause()
    }

    // MARK: - Progress timer fires during playback

    func testProgressCallbackFires() async throws {
        let exp = expectation(description: "onProgress fires")
        exp.assertForOverFulfill = false
        sut.onProgress = { _, _ in exp.fulfill() }
        sut.play()
        await fulfillment(of: [exp], timeout: 1.0)
        sut.pause()
    }

    // MARK: - Fix 5: duration reflects actual file frame count

    func testDurationReflectsActualFileFrameCount() {
        XCTAssertEqual(sut.duration(), 0.5, accuracy: 0.01,
            "duration() should match the 0.5 s synthetic WAV within 10 ms")
    }

    // MARK: - currentTime advances after play

    func testCurrentTimeAdvancesAfterPlay() async throws {
        XCTAssertLessThanOrEqual(sut.currentTime(), 0.05, "should be near 0 before play")
        let exp = expectation(description: "currentTime > 0.1 s")
        sut.onProgress = { [weak self] time, _ in
            guard let self else { return }
            if time > 0.1 {
                exp.fulfill()
                self.sut.pause()
            }
        }
        sut.play()
        await fulfillment(of: [exp], timeout: 2.0)
    }

    // TODO: Fix 4 — progressive download loop-break test
    // Requires ProgressiveAudioAsset to be injectable via a protocol
    // (e.g. AudioAssetProtocol with bytesDownloaded/isComplete/waitUntilBuffered).
    // With a stub that reports isComplete=true but never increases availableChunkCount,
    // the scheduler previously looped forever; Fix 4 makes it break out and fire onTrackFinished.
}
