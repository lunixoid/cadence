import XCTest
@testable import Cadence

final class AudioRouteInterruptionPolicyTests: XCTestCase {

    func testOldDeviceUnavailablePauses() {
        XCTAssertTrue(
            AudioRouteInterruptionPolicy.shouldPauseForRouteChange(
                reasonRawValue: AudioRouteInterruptionPolicy.routeChangeOldDeviceUnavailable
            )
        )
    }

    func testNewDeviceAvailableDoesNotPause() {
        XCTAssertFalse(
            AudioRouteInterruptionPolicy.shouldPauseForRouteChange(
                reasonRawValue: AudioRouteInterruptionPolicy.routeChangeNewDeviceAvailable
            )
        )
    }

    func testCategoryChangeDoesNotPause() {
        XCTAssertFalse(
            AudioRouteInterruptionPolicy.shouldPauseForRouteChange(
                reasonRawValue: AudioRouteInterruptionPolicy.routeChangeCategoryChange
            )
        )
    }

    func testConfigChangeResumesWhenPlayingAndNotPausedOrInterrupted() {
        XCTAssertTrue(
            AudioRouteInterruptionPolicy.shouldPlayAfterConfigurationChange(
                isPlayerPlaying: true,
                isPaused: false,
                isInterrupted: false
            )
        )
    }

    func testConfigChangeDoesNotResumeWhenPaused() {
        XCTAssertFalse(
            AudioRouteInterruptionPolicy.shouldPlayAfterConfigurationChange(
                isPlayerPlaying: false,
                isPaused: true,
                isInterrupted: false
            )
        )
    }

    func testConfigChangeDoesNotResumeWhenInterrupted() {
        XCTAssertFalse(
            AudioRouteInterruptionPolicy.shouldPlayAfterConfigurationChange(
                isPlayerPlaying: true,
                isPaused: false,
                isInterrupted: true
            )
        )
    }

    func testConfigChangeDoesNotResumeWhenPlayerStoppedEvenIfNotPausedFlag() {
        XCTAssertFalse(
            AudioRouteInterruptionPolicy.shouldPlayAfterConfigurationChange(
                isPlayerPlaying: false,
                isPaused: false,
                isInterrupted: false
            )
        )
    }

    func testInterruptionResumeOnlyWhenWasPlayingAndShouldResume() {
        XCTAssertTrue(
            AudioRouteInterruptionPolicy.shouldResumeAfterInterruption(
                wasPlayingBeforeInterruption: true,
                shouldResume: true
            )
        )
        XCTAssertFalse(
            AudioRouteInterruptionPolicy.shouldResumeAfterInterruption(
                wasPlayingBeforeInterruption: true,
                shouldResume: false
            )
        )
        XCTAssertFalse(
            AudioRouteInterruptionPolicy.shouldResumeAfterInterruption(
                wasPlayingBeforeInterruption: false,
                shouldResume: true
            )
        )
    }
}
