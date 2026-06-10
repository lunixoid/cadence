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
    private let stateStore = PlaybackStateStore()

    private var playbackQueue = PlaybackQueue()
    private var loadTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var prefetchedCache: (trackID: UUID, fileURL: URL)?

    var isPlaying = false
    var isLoading = false
    var shuffleOn = false
    var repeatMode: RepeatMode = .off
    var progress: TimeInterval = 0
    var duration: TimeInterval = 0
    var volume: Double = 72 {
        didSet {
            audioEngine.volume = volume
            persistState()
        }
    }

    var eqEnabled = true {
        didSet {
            audioEngine.setEQEnabled(eqEnabled)
            persistState()
        }
    }

    var eqGains: [Double] = EQPreset.rock.gains

    var currentTrack: Track? {
        playbackQueue.current
    }

    var playingTrackID: UUID? {
        currentTrack?.id
    }

    init(libraryStore: LibraryStore, recentStore: RecentStore) {
        self.libraryStore = libraryStore
        self.recentStore = recentStore

        mediaRemote.configure(controller: self)

        for (i, gain) in eqGains.enumerated() {
            audioEngine.setBandGain(at: i, gain: Float(gain))
        }

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

    func setEQGain(at index: Int, gain: Double) {
        guard index < eqGains.count else { return }
        eqGains[index] = gain
        audioEngine.setBandGain(at: index, gain: Float(gain))
        persistState()
    }

    func restoreSavedState() {
        guard let snapshot = stateStore.load() else { return }

        if let savedEnabled = snapshot.eqEnabled {
            eqEnabled = savedEnabled
            audioEngine.setEQEnabled(savedEnabled)
        }
        if let savedGains = snapshot.eqGains {
            eqGains = savedGains
            for (i, gain) in savedGains.enumerated() {
                audioEngine.setBandGain(at: i, gain: Float(gain))
            }
        }

        guard let queue = stateStore.restoreQueue(from: snapshot, library: libraryStore) else {
            return
        }

        playbackQueue = queue
        shuffleOn = snapshot.shuffleOn
        repeatMode = snapshot.repeatMode
        volume = snapshot.volume
        progress = snapshot.progress

        loadCurrentTrack(seekTo: snapshot.progress, shouldPlay: snapshot.isPlaying)
    }

    func play(tracks: [Track], startAt index: Int = 0, source: AutoplaySource = .adHoc, originalTracks: [Track]? = nil) {
        guard !tracks.isEmpty else { return }
        playbackQueue.beginSession(
            tracks: tracks,
            startAt: index,
            source: source,
            originalTracks: originalTracks
        )
        loadAndPlayCurrentTrack()
        persistState()
    }

    func playAlbum(_ album: Album, shuffled: Bool) {
        let tracks = libraryStore.tracks(for: album)
        guard !tracks.isEmpty else { return }
        shuffleOn = shuffled
        let orderedTracks = shuffled ? tracks.shuffled() : tracks
        play(tracks: orderedTracks, startAt: 0, source: .album(album.id), originalTracks: tracks)
    }

    func playTrack(_ track: Track) {
        if let albumTracks = libraryStore.tracks(forAlbumID: track.albumID).nilIfEmpty,
           let index = albumTracks.firstIndex(of: track) {
            play(tracks: albumTracks, startAt: index, source: .album(track.albumID))
            return
        }
        play(tracks: [track], startAt: 0, source: .none)
    }

    func playTrack(_ track: Track, in tracks: [Track], source: AutoplaySource) {
        guard let index = tracks.firstIndex(of: track) else {
            playTrack(track)
            return
        }
        play(tracks: tracks, startAt: index, source: source, originalTracks: tracks)
    }

    func togglePlayPause() {
        if !playbackQueue.hasActiveSession, let track = currentTrack {
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
        persistState()
    }

    func next() {
        guard playbackQueue.hasActiveSession else { return }

        guard let track = playbackQueue.consumeNext(repeatMode: repeatMode) else {
            stopPlayback()
            persistState()
            return
        }

        playLoadedTrack(track)
        persistState()
    }

    func previous() {
        guard playbackQueue.hasActiveSession else { return }

        if progress > 3 {
            seek(to: 0)
            return
        }

        guard let track = playbackQueue.consumePrevious() else {
            seek(to: 0)
            return
        }

        playLoadedTrack(track)
        persistState()
    }

    func seek(to time: TimeInterval) {
        progress = time
        audioEngine.seek(to: time)
        persistState()
    }

    func toggleShuffle() {
        shuffleOn.toggle()
        if shuffleOn {
            playbackQueue.shuffleRemainingAutoplay()
        } else {
            playbackQueue.restoreOriginalAutoplayOrder()
        }
        persistState()
    }

    func toggleRepeat() {
        repeatMode.cycle()
        persistState()
    }

    func playNext(_ track: Track) {
        guard playbackQueue.hasActiveSession else {
            playTrack(track)
            return
        }

        playbackQueue.insertPlayNext(track)
        persistState()
    }

    func addToQueue(_ track: Track) {
        guard playbackQueue.hasActiveSession else {
            playTrack(track)
            return
        }

        playbackQueue.appendToQueue(track)
        persistState()
    }

    var upNextTracks: [Track] {
        playbackQueue.upNext
    }

    func removeFromUpNext(at index: Int) {
        playbackQueue.removeFromUpNext(at: index)
        persistState()
    }

    func moveUpNextItem(from source: Int, to destination: Int) {
        playbackQueue.moveUpNextItem(from: source, to: destination)
        persistState()
    }

    func clearUpNext() {
        playbackQueue.clearUpNext()
        persistState()
    }

    func playUpNext(at index: Int) {
        guard playbackQueue.hasActiveSession else { return }
        guard let track = playbackQueue.jumpToUpNext(at: index) else { return }
        playLoadedTrack(track)
        persistState()
    }

    func autoplayPreviewTracks(limit: Int = 7) -> [Track] {
        playbackQueue.autoplayPreview(limit: limit)
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
        playbackQueue.beginSession(
            tracks: tracks,
            startAt: currentIndex,
            source: .album(tracks.first?.albumID ?? UUID())
        )
        self.isPlaying = isPlaying
        self.progress = progress
        self.duration = duration
    }
    #endif

    private func loadAndPlayCurrentTrack() {
        guard let track = currentTrack else { return }
        playLoadedTrack(track)
    }

    private func playLoadedTrack(_ track: Track) {
        loadTask?.cancel()
        prefetchTask?.cancel()
        prefetchTask = nil
        isLoading = true

        loadTask = Task {
            do {
                if track.fileURL.isFileURL {
                    try audioEngine.load(url: track.fileURL)
                } else if let cached = prefetchedCache, cached.trackID == track.id {
                    prefetchedCache = nil
                    try audioEngine.load(url: cached.fileURL)
                } else {
                    prefetchedCache = nil
                    try await audioEngine.loadRemote(url: track.fileURL, trackID: track.id)
                }
                guard !Task.isCancelled else { return }
                duration = audioEngine.duration()
                progress = 0
                audioEngine.play()
                isPlaying = true
                isLoading = false
                recentStore.record(track: track)
                mediaRemote.publishNowPlayingInfo()
                schedulePrefetch()
            } catch {
                guard !Task.isCancelled else { return }
                logger.error("Failed to load track: \(error.localizedDescription)")
                isLoading = false
                next()
            }
        }
    }

    private func schedulePrefetch() {
        prefetchTask?.cancel()
        guard let next = playbackQueue.peekNext(repeatMode: repeatMode),
              !next.fileURL.isFileURL,
              prefetchedCache?.trackID != next.id else { return }

        let url = next.fileURL
        let trackID = next.id

        prefetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let localURL = try await AudioCache.shared.localURL(for: url, trackID: trackID)
                guard !Task.isCancelled else { return }
                self.prefetchedCache = (trackID: trackID, fileURL: localURL)
            } catch {
                // Prefetch failed — next transition will download normally.
            }
        }
    }

    private func loadCurrentTrack(seekTo time: TimeInterval, shouldPlay: Bool) {
        guard let track = currentTrack else { return }

        loadTask?.cancel()
        isLoading = true

        loadTask = Task {
            do {
                if track.fileURL.isFileURL {
                    try audioEngine.load(url: track.fileURL)
                } else {
                    try await audioEngine.loadRemote(url: track.fileURL, trackID: track.id)
                }
                guard !Task.isCancelled else { return }

                duration = audioEngine.duration()
                progress = min(max(time, 0), duration)
                audioEngine.seek(to: progress)

                if shouldPlay {
                    audioEngine.play()
                    isPlaying = true
                } else {
                    audioEngine.pause()
                    isPlaying = false
                }

                isLoading = false
                mediaRemote.publishNowPlayingInfo()
                schedulePrefetch()
            } catch {
                guard !Task.isCancelled else { return }
                logger.error("Failed to restore track: \(error.localizedDescription)")
                stateStore.clear()
                playbackQueue = PlaybackQueue()
                isPlaying = false
                isLoading = false
                progress = 0
            }
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

    private func persistState() {
        let snapshot = stateStore.makeSnapshot(
            from: playbackQueue,
            progress: progress,
            isPlaying: isPlaying,
            shuffleOn: shuffleOn,
            repeatMode: repeatMode,
            volume: volume,
            eqEnabled: eqEnabled,
            eqGains: eqGains
        )
        stateStore.save(snapshot)
    }
}

private extension Array {
    var nilIfEmpty: Self? {
        isEmpty ? nil : self
    }
}
