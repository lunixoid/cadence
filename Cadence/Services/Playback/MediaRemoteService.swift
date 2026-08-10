import CoreGraphics
import Foundation
import MediaPlayer

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class MediaRemoteService {
    private weak var controller: PlaybackController?
    private weak var favoritesStore: FavoritesStore?
    private var clientProvider: (() -> JellyfinClient?)?
    private var toggleFavorite: ((Track, JellyfinClient?) -> Void)?
    private var isConfigured = false
    private var isFavoritesConfigured = false

    private var artworkTrackID: UUID?
    private var cachedArtwork: MPMediaItemArtwork?
    private var artworkLoadGeneration = 0

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
            clearArtworkCache()
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            syncLikeCommandState()
            return
        }

        let album = controller.album(forCurrentTrack: track)

        if artworkTrackID != track.id {
            artworkTrackID = track.id
            cachedArtwork = nil
            loadArtwork(for: track, coverURL: album?.coverURL)
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: album?.title ?? "",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: controller.progress,
            MPMediaItemPropertyPlaybackDuration: max(controller.duration, 0),
            MPNowPlayingInfoPropertyPlaybackRate: controller.isPlaying ? 1.0 : 0.0,
        ]
        if artworkTrackID == track.id, let cachedArtwork {
            info[MPMediaItemPropertyArtwork] = cachedArtwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        syncLikeCommandState()
    }

    private func loadArtwork(for track: Track, coverURL: URL?) {
        artworkLoadGeneration += 1
        let generation = artworkLoadGeneration
        guard let coverURL else { return }

        Task { @MainActor in
            let cgImage = await ArtworkCache.shared.image(for: coverURL, maxWidth: 600)
            guard generation == artworkLoadGeneration,
                  controller?.currentTrack?.id == track.id,
                  let cgImage else {
                return
            }
            cachedArtwork = Self.makeArtwork(from: cgImage)
            artworkTrackID = track.id
            publishNowPlayingInfo()
        }
    }

    private func clearArtworkCache() {
        artworkLoadGeneration += 1
        artworkTrackID = nil
        cachedArtwork = nil
    }

    private static func makeArtwork(from cgImage: CGImage) -> MPMediaItemArtwork {
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        return MPMediaItemArtwork(boundsSize: size) { _ in
            #if canImport(UIKit)
            return UIImage(cgImage: cgImage)
            #elseif canImport(AppKit)
            return NSImage(cgImage: cgImage, size: size)
            #else
            return NSImage()
            #endif
        }
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
