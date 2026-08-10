import Foundation
import MediaPlayer

@MainActor
final class MediaRemoteService {
    private weak var controller: PlaybackController?
    private weak var favoritesStore: FavoritesStore?
    private var clientProvider: (() -> JellyfinClient?)?
    private var toggleFavorite: ((Track, JellyfinClient?) -> Void)?
    private var isConfigured = false
    private var isFavoritesConfigured = false

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

    func configureFavorites(
        favoritesStore: FavoritesStore,
        clientProvider: @escaping () -> JellyfinClient?,
        toggle: @escaping (Track, JellyfinClient?) -> Void
    ) {
        self.favoritesStore = favoritesStore
        self.clientProvider = clientProvider
        self.toggleFavorite = toggle

        guard !isFavoritesConfigured else {
            syncLikeCommandState()
            return
        }
        isFavoritesConfigured = true

        let likeCommand = MPRemoteCommandCenter.shared().likeCommand
        likeCommand.isEnabled = true
        likeCommand.localizedTitle = "Избранное"
        likeCommand.localizedShortTitle = "Избранное"
        likeCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.handleLikeCommand()
            }
            return .success
        }
        syncLikeCommandState()
    }

    func publishNowPlayingInfo() {
        guard let controller else { return }

        guard let track = controller.currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            syncLikeCommandState()
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
        syncLikeCommandState()
    }

    private func handleLikeCommand() {
        guard let controller,
              let track = controller.currentTrack,
              let toggleFavorite else {
            return
        }
        let client = clientProvider?()
        toggleFavorite(track, client)
        syncLikeCommandState()
        publishNowPlayingInfo()
    }

    private func syncLikeCommandState() {
        let likeCommand = MPRemoteCommandCenter.shared().likeCommand
        guard let track = controller?.currentTrack,
              let favoritesStore else {
            likeCommand.isActive = false
            return
        }
        likeCommand.isActive = favoritesStore.isFavorite(track: track)
    }
}
