import Foundation
import MediaPlayer

@MainActor
final class MediaRemoteService {
    private weak var controller: PlaybackController?
    private var isConfigured = false

    func configure(controller: PlaybackController) {
        guard !isConfigured else {
            self.controller = controller
            return
        }
        isConfigured = true
        self.controller = controller

        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.controller?.togglePlayPause()
                self?.publishNowPlayingInfo()
            }
            return .success
        }

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let controller = self?.controller, !controller.isPlaying else { return }
                controller.togglePlayPause()
                self?.publishNowPlayingInfo()
            }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let controller = self?.controller, controller.isPlaying else { return }
                controller.togglePlayPause()
                self?.publishNowPlayingInfo()
            }
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.controller?.next()
                self?.publishNowPlayingInfo()
            }
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.controller?.previous()
                self?.publishNowPlayingInfo()
            }
            return .success
        }
    }

    func publishNowPlayingInfo() {
        guard let controller else { return }

        guard let track = controller.currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        let album = controller.album(forCurrentTrack: track)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: album?.title ?? "",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: controller.progress,
            MPMediaItemPropertyPlaybackDuration: max(controller.duration, 0),
            MPNowPlayingInfoPropertyPlaybackRate: controller.isPlaying ? 1.0 : 0.0,
        ]
    }
}
