import Foundation
import os.log

private let logger = Logger(subsystem: "dev.personal.cadence", category: "Playback")

@Observable
@MainActor
final class PlaybackController {
    private let audioEngine = AudioEngineService()
    private let libraryStore: LibraryStore
    private let recentStore: RecentStore
    private let mediaRemote = MediaRemoteService()

    private(set) var queue: [Track] = []
    private(set) var currentIndex: Int = -1
    private(set) var shuffleOrder: [Int] = []
    private(set) var shufflePosition: Int = 0

    var isPlaying = false
    var shuffleOn = false
    var repeatMode: RepeatMode = .off
    var progress: TimeInterval = 0
    var duration: TimeInterval = 0
    var volume: Double = 72 {
        didSet { audioEngine.volume = volume }
    }

    var currentTrack: Track? {
        guard currentIndex >= 0, currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    var playingTrackID: UUID? {
        currentTrack?.id
    }

    init(libraryStore: LibraryStore, recentStore: RecentStore) {
        self.libraryStore = libraryStore
        self.recentStore = recentStore
        self.volume = 72

        mediaRemote.configure(controller: self)

        audioEngine.onProgress = { [weak self] current, total in
            Task { @MainActor in
                self?.progress = current
                self?.duration = total
                self?.mediaRemote.publishNowPlayingInfo()
            }
        }

        audioEngine.onTrackFinished = { [weak self] in
            Task { @MainActor in
                self?.handleTrackFinished()
            }
        }
    }

    func play(tracks: [Track], startAt index: Int = 0) {
        guard !tracks.isEmpty else { return }
        let clampedIndex = min(max(index, 0), tracks.count - 1)
        queue = tracks
        currentIndex = clampedIndex
        rebuildShuffleOrder()
        loadAndPlayCurrentTrack()
    }

    func playAlbum(_ album: Album, shuffled: Bool) {
        let tracks = libraryStore.tracks(for: album)
        guard !tracks.isEmpty else { return }
        shuffleOn = shuffled
        if shuffled {
            play(tracks: tracks.shuffled(), startAt: 0)
        } else {
            play(tracks: tracks, startAt: 0)
        }
    }

    func playTrack(_ track: Track) {
        if let albumTracks = libraryStore.tracks(forAlbumID: track.albumID).nilIfEmpty {
            if let index = albumTracks.firstIndex(of: track) {
                play(tracks: albumTracks, startAt: index)
                return
            }
        }
        play(tracks: [track], startAt: 0)
    }

    func togglePlayPause() {
        if queue.isEmpty, let track = currentTrack {
            playTrack(track)
            return
        }

        if isPlaying {
            audioEngine.pause()
            isPlaying = false
        } else if currentTrack != nil {
            audioEngine.play()
            isPlaying = true
        }
        mediaRemote.publishNowPlayingInfo()
    }

    func next() {
        guard !queue.isEmpty else { return }

        if shuffleOn {
            advanceShuffle(forward: true)
        } else if currentIndex + 1 < queue.count {
            currentIndex += 1
            loadAndPlayCurrentTrack()
        } else if repeatMode == .queue {
            currentIndex = 0
            loadAndPlayCurrentTrack()
        } else {
            stopPlayback()
        }
    }

    func previous() {
        guard !queue.isEmpty else { return }

        if progress > 3 {
            seek(to: 0)
            return
        }

        if shuffleOn {
            advanceShuffle(forward: false)
        } else if currentIndex > 0 {
            currentIndex -= 1
            loadAndPlayCurrentTrack()
        } else if repeatMode == .queue {
            currentIndex = queue.count - 1
            loadAndPlayCurrentTrack()
        } else {
            seek(to: 0)
        }
    }

    func seek(to time: TimeInterval) {
        progress = time
        audioEngine.seek(to: time)
    }

    func toggleShuffle() {
        shuffleOn.toggle()
        rebuildShuffleOrder()
    }

    func toggleRepeat() {
        repeatMode.cycle()
    }

    func playNext(_ track: Track) {
        guard !queue.isEmpty else {
            play(tracks: [track], startAt: 0)
            return
        }

        let insertIndex = min(currentIndex + 1, queue.count)
        queue.insert(track, at: insertIndex)
        rebuildShuffleOrder()
    }

    func addToQueue(_ track: Track) {
        queue.append(track)
        rebuildShuffleOrder()
        if currentIndex < 0 {
            currentIndex = 0
            loadAndPlayCurrentTrack()
        }
    }

    func album(forCurrentTrack: Track? = nil) -> Album? {
        let track = forCurrentTrack ?? currentTrack
        guard let track else { return nil }
        return libraryStore.album(for: track.albumID)
    }

    #if DEBUG
    func loadPreviewState(
        tracks: [Track],
        currentIndex: Int,
        isPlaying: Bool,
        progress: TimeInterval,
        duration: TimeInterval
    ) {
        queue = tracks
        self.currentIndex = currentIndex
        self.isPlaying = isPlaying
        self.progress = progress
        self.duration = duration
    }
    #endif

    private func loadAndPlayCurrentTrack() {
        guard let track = currentTrack else { return }

        do {
            try audioEngine.load(url: track.fileURL)
            duration = audioEngine.duration()
            progress = 0
            audioEngine.play()
            isPlaying = true
            recentStore.record(track: track)
            mediaRemote.publishNowPlayingInfo()
        } catch {
            logger.error("Failed to load track: \(error.localizedDescription)")
            next()
        }
    }

    private func handleTrackFinished() {
        switch repeatMode {
        case .one:
            loadAndPlayCurrentTrack()
        case .off, .queue:
            next()
        }
    }

    private func stopPlayback() {
        audioEngine.stop()
        isPlaying = false
        progress = 0
        mediaRemote.publishNowPlayingInfo()
    }

    private func rebuildShuffleOrder() {
        shuffleOrder = Array(queue.indices)
        if shuffleOn {
            shuffleOrder.shuffle()
        }
        if let current = currentIndex >= 0 ? currentIndex : nil,
           let position = shuffleOrder.firstIndex(of: current) {
            shufflePosition = position
        } else {
            shufflePosition = 0
        }
    }

    private func advanceShuffle(forward: Bool) {
        guard !shuffleOrder.isEmpty else { return }

        if forward {
            if shufflePosition + 1 < shuffleOrder.count {
                shufflePosition += 1
            } else if repeatMode == .queue {
                shuffleOrder.shuffle()
                shufflePosition = 0
            } else {
                stopPlayback()
                return
            }
        } else if shufflePosition > 0 {
            shufflePosition -= 1
        } else if repeatMode == .queue {
            shuffleOrder.shuffle()
            shufflePosition = shuffleOrder.count - 1
        } else {
            seek(to: 0)
            return
        }

        currentIndex = shuffleOrder[shufflePosition]
        loadAndPlayCurrentTrack()
    }
}

private extension Array {
    var nilIfEmpty: Self? {
        isEmpty ? nil : self
    }
}
