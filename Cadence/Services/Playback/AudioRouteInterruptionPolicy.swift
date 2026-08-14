/// Pure policy for audio route / interruption handling (BUG16). Testable without notifications.
enum AudioRouteInterruptionPolicy {
    /// Matches `AVAudioSession.RouteChangeReason.oldDeviceUnavailable`.
    static let routeChangeOldDeviceUnavailable: UInt = 3
    /// Matches `AVAudioSession.RouteChangeReason.newDeviceAvailable`.
    static let routeChangeNewDeviceAvailable: UInt = 1
    /// Matches `AVAudioSession.RouteChangeReason.categoryChange`.
    static let routeChangeCategoryChange: UInt = 4

    static func shouldPauseForRouteChange(reasonRawValue: UInt) -> Bool {
        reasonRawValue == routeChangeOldDeviceUnavailable
    }

    static func shouldPlayAfterConfigurationChange(
        isPlayerPlaying: Bool,
        isPaused: Bool,
        isInterrupted: Bool
    ) -> Bool {
        isPlayerPlaying && !isPaused && !isInterrupted
    }

    static func shouldResumeAfterInterruption(
        wasPlayingBeforeInterruption: Bool,
        shouldResume: Bool
    ) -> Bool {
        wasPlayingBeforeInterruption && shouldResume
    }
}
