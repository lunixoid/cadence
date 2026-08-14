import Foundation
import os.log

private let logger = Logger(subsystem: "dev.personal.cadence", category: "Playback")

@Observable
@MainActor
final class PlaybackController {
    private let audioEngine = AudioEngineService()
    private let libraryStore: LibraryStore
    private let recentStore: RecentStore
    private let offlineStore: OfflineStore
    private let mediaRemote = MediaRemoteService()
    private let stateStore = PlaybackStateStore()

    private var playbackQueue = PlaybackQueue()
    private var loadTask: Task<Void, Never>?
    private var loadSerialTask: Task<Void, Never>?
    private var pendingLoadTrack: Track?
    private var pendingLoadAutoplay = true
    private var prefetchTask: Task<Void, Never>?
    private var prefetchTrackID: UUID?
    private var prefetchedCache: (trackID: UUID, fileURL: URL)?
    private var activeLoadGeneration = 0

    private enum TrackLoadSource {
        case local(URL)
        case progressive(ProgressiveAudioAsset)
    }

    var isPlaying = false
    var isLoading = false
    var shuffleOn = false
    var repeatMode: RepeatMode = .off
    var progress: TimeInterval = 0
    var duration: TimeInterval = 0

    var eqEnabled = true {
        didSet {
            audioEngine.setEQEnabled(eqEnabled)
            persistState()
        }
    }

    var eqGains: [Double] = EQPreset.signature.gains
    var activeUserPresetID: UUID? = nil
    var userPresets: [UserEQPreset] = []
    private let userPresetStore = UserEQPresetStore()

    var spectrumAnalyzer: SpectrumAnalyzer { audioEngine.spectrumAnalyzer }

    var currentTrack: Track? {
        playbackQueue.current
    }

    var playingTrackID: UUID? {
        currentTrack?.id
    }

    init(libraryStore: LibraryStore, recentStore: RecentStore, offlineStore: OfflineStore) {
        self.libraryStore = libraryStore
        self.recentStore = recentStore
        self.offlineStore = offlineStore

        mediaRemote.configure(controller: self)
        userPresets = userPresetStore.load()

        for (i, gain) in eqGains.enumerated() {
            audioEngine.setBandGain(at: i, gain: Float(gain))
        }
        applyGlobalGain()

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

        audioEngine.onBuffering = { [weak self] isBuffering in
            Task { @MainActor in
                guard let self else { return }
                logger.info("Buffering: \(isBuffering ? "start" : "end")")
                if isBuffering {
                    self.isLoading = true
                } else {
                    self.isLoading = false
                }
            }
        }

        audioEngine.onDidStartPlayingBySystem = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = true
                self.isLoading = false
                self.mediaRemote.publishNowPlayingInfo()
                self.persistState()
            }
        }

        audioEngine.onDidPauseBySystem = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.isPlaying = false
                self.mediaRemote.publishNowPlayingInfo()
                self.persistState()
            }
        }

        audioEngine.onGaplessAdvance = { [weak self] nextDuration in
            Task { @MainActor in
                guard let self else { return }
                self.handleGaplessAdvance(nextDuration: nextDuration)
            }
        }
    }

    func configureFavoriteRemote(
        favoritesStore: FavoritesStore,
        clientProvider: @escaping @MainActor () -> JellyfinClient?,
        toggle: @escaping @MainActor (Track, JellyfinClient?) -> Void
    ) {
        mediaRemote.configureFavorites(
            favoritesStore: favoritesStore,
            clientProvider: clientProvider,
            toggle: toggle
        )
    }

    func refreshNowPlayingInfo() {
        mediaRemote.publishNowPlayingInfo()
    }

    func setEQGain(at index: Int, gain: Double) {
        guard index < eqGains.count else { return }
        eqGains[index] = gain
        activeUserPresetID = nil
        audioEngine.setBandGain(at: index, gain: Float(gain))
        applyGlobalGain()
        persistState()
    }

    func applyBuiltInPreset(_ preset: EQPreset) {
        guard preset != .custom else { return }
        activeUserPresetID = nil
        for (i, gain) in preset.gains.enumerated() {
            eqGains[i] = gain
            audioEngine.setBandGain(at: i, gain: Float(gain))
        }
        applyGlobalGain()
        persistState()
    }

    func applyUserPreset(_ preset: UserEQPreset) {
        activeUserPresetID = preset.id
        for (i, gain) in preset.gains.enumerated() {
            eqGains[i] = gain
            audioEngine.setBandGain(at: i, gain: Float(gain))
        }
        applyGlobalGain()
        persistState()
    }

    func saveCurrentAsUserPreset(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let preset = UserEQPreset(name: trimmed, gains: eqGains)
        userPresets.append(preset)
        activeUserPresetID = preset.id
        userPresetStore.save(userPresets)
    }

    func deleteUserPreset(id: UUID) {
        userPresets.removeAll { $0.id == id }
        if activeUserPresetID == id { activeUserPresetID = nil }
        userPresetStore.save(userPresets)
    }

    /// Lowers the EQ pre-amp by the largest positive band boost (plus 1 dB safety
    /// headroom) so boosted bands never push the signal past 0 dBFS and clip.
    /// Recomputed on every gain change, so it also protects manual "Custom" curves.
    private func applyGlobalGain() {
        let maxBoost = max(0, eqGains.max() ?? 0)
        audioEngine.setGlobalGain(maxBoost > 0 ? Float(-maxBoost - 1.0) : 0)
    }

    /// Returns `false` when a snapshot exists but the queue could not be resolved (library still empty).
    @discardableResult
    func restoreSavedState() -> Bool {
        guard let snapshot = stateStore.load() else { return true }

        if let savedEnabled = snapshot.eqEnabled {
            eqEnabled = savedEnabled
            audioEngine.setEQEnabled(savedEnabled)
        }
        if let savedGains = snapshot.eqGains {
            eqGains = savedGains
            for (i, gain) in savedGains.enumerated() {
                audioEngine.setBandGain(at: i, gain: Float(gain))
            }
            applyGlobalGain()
            activeUserPresetID = userPresets.first { $0.gains == savedGains }?.id
        }

        guard let queue = stateStore.restoreQueue(from: snapshot, library: libraryStore) else {
            return false
        }

        playbackQueue = queue
        shuffleOn = snapshot.shuffleOn
        repeatMode = snapshot.repeatMode
        progress = snapshot.progress

        loadCurrentTrack(seekTo: snapshot.progress, shouldPlay: false)
        return true
    }

    func persistStateNow() {
        persistState()
    }

    func play(tracks: [Track], startAt index: Int = 0, source: AutoplaySource = .adHoc, originalTracks: [Track]? = nil) {
        guard !tracks.isEmpty else { return }
        logger.info("Action: play \(tracks.count) track(s) startAt=\(index)")
        _ = beginLoadSession()
        playbackQueue.beginSession(
            tracks: tracks,
            startAt: index,
            source: source,
            originalTracks: originalTracks
        )
        if shuffleOn {
            playbackQueue.shuffleRemainingAutoplay()
        }
        loadAndPlayCurrentTrack()
        persistState()
    }

    func playAlbum(_ album: Album, shuffled: Bool) {
        let tracks = libraryStore.tracks(for: album)
        guard !tracks.isEmpty else { return }
        logger.info("Action: playAlbum \(tracks.count) tracks shuffled=\(shuffled)")
        if shuffled { shuffleOn = true }
        let startAt = shuffled ? Int.random(in: 0..<tracks.count) : 0
        play(tracks: tracks, startAt: startAt, source: .album(album.id), originalTracks: tracks)
    }

    func playTrack(_ track: Track) {
        logger.info("Action: playTrack '\(track.title)'")
        if let albumTracks = libraryStore.tracks(forAlbumID: track.albumID).nilIfEmpty,
           let index = albumTracks.firstIndex(of: track) {
            play(tracks: albumTracks, startAt: index, source: .album(track.albumID))
            return
        }
        play(tracks: [track], startAt: 0, source: .none)
    }

    func playTrack(_ track: Track, in tracks: [Track], source: AutoplaySource) {
        logger.info("Action: playTrack '\(track.title)' in context (\(tracks.count) tracks)")
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

        if isLoading {
            return
        }

        if isPlaying {
            logger.info("Action: togglePlayPause → pause")
            audioEngine.pause()
            isPlaying = false
        } else if currentTrack != nil {
            logger.info("Action: togglePlayPause → play")
            audioEngine.play()
            isPlaying = true
        }
        mediaRemote.publishNowPlayingInfo()
        persistState()
    }

    func next(autoplay: Bool? = nil) {
        guard playbackQueue.hasActiveSession else { return }
        let shouldAutoplay = autoplay ?? isPlaying

        guard let track = playbackQueue.consumeNext(repeatMode: repeatMode) else {
            logger.info("Action: next → end of queue, stopping")
            stopPlayback()
            persistState()
            return
        }

        logger.info("Action: next → '\(track.title)' autoplay=\(shouldAutoplay)")
        scheduleLoadedTrack(track, autoplay: shouldAutoplay)
    }

    func previous() {
        guard playbackQueue.hasActiveSession else { return }

        let prevProgress = progress
        let shouldAutoplay = isPlaying
        logger.info("Action: previous (progress=\(String(format: "%.1f", prevProgress))s)")
        if progress > 3 {
            seek(to: 0)
            return
        }

        guard let track = playbackQueue.consumePrevious() else {
            seek(to: 0)
            return
        }

        scheduleLoadedTrack(track, autoplay: shouldAutoplay)
    }

    /// Unconditional step to the previous queue track (cover swipe). No seek-on-progress.
    /// No-op when history is empty.
    @discardableResult
    func skipToPreviousTrack() -> Bool {
        guard playbackQueue.hasActiveSession else { return false }
        let shouldAutoplay = isPlaying

        guard let track = playbackQueue.consumePrevious() else {
            logger.info("Action: skipToPreviousTrack → no history")
            return false
        }

        logger.info("Action: skipToPreviousTrack → '\(track.title)' autoplay=\(shouldAutoplay)")
        scheduleLoadedTrack(track, autoplay: shouldAutoplay)
        return true
    }

    private func scheduleLoadedTrack(_ track: Track, autoplay: Bool = true) {
        pendingLoadTrack = track
        pendingLoadAutoplay = autoplay
        loadSerialTask?.cancel()

        loadSerialTask = Task { @MainActor in
            while let track = pendingLoadTrack {
                let autoplay = pendingLoadAutoplay
                pendingLoadTrack = nil
                await performOneLoad(track, autoplay: autoplay)
                guard !Task.isCancelled else { return }
                persistState()
            }
        }
    }

    func seek(to time: TimeInterval) {
        let fromTime = progress
        logger.info("Action: seek \(String(format: "%.2f", fromTime))s → \(String(format: "%.2f", time))s")
        progress = time
        audioEngine.seek(to: time)
        persistState()
    }

    func toggleShuffle() {
        shuffleOn.toggle()
        logger.info("Action: shuffle → \(self.shuffleOn)")
        if shuffleOn {
            playbackQueue.shuffleRemainingAutoplay()
        } else {
            playbackQueue.restoreOriginalAutoplayOrder()
        }
        persistState()
    }

    func toggleRepeat() {
        repeatMode.cycle()
        logger.info("Action: repeat → \(String(describing: self.repeatMode))")
        persistState()
    }

    func playNext(_ track: Track) {
        logger.info("Action: playNext '\(track.title)'")
        guard playbackQueue.hasActiveSession else {
            playTrack(track)
            return
        }

        playbackQueue.insertPlayNext(track)
        persistState()
    }

    func addToQueue(_ track: Track) {
        logger.info("Action: addToQueue '\(track.title)'")
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

    var previousQueueTrack: Track? {
        playbackQueue.peekPrevious()
    }

    var nextQueueTrack: Track? {
        playbackQueue.peekNext(repeatMode: repeatMode)
    }

    /// Neighbors for the Now Playing cover revolver: previous oldest→nearest, next nearest→further.
    func coverStripTracks(before: Int = 2, after: Int = 2) -> (previous: [Track], next: [Track]) {
        (
            playbackQueue.peekHistory(limit: before),
            playbackQueue.peekUpcoming(limit: after, repeatMode: repeatMode)
        )
    }

    func removeFromUpNext(at index: Int) {
        playbackQueue.removeFromUpNext(at: index)
        persistState()
    }

    func removeFromUpNext(trackID: UUID) {
        playbackQueue.removeFromUpNext(trackID: trackID)
        persistState()
    }

    func moveUpNextItem(from source: Int, to destination: Int) {
        playbackQueue.moveUpNextItem(from: source, to: destination)
        persistState()
    }

    func clearUpNext() {
        logger.info("Action: clearUpNext")
        playbackQueue.clearUpNext()
        persistState()
    }

    func playUpNext(at index: Int) {
        guard playbackQueue.hasActiveSession else { return }
        guard let track = playbackQueue.jumpToUpNext(at: index) else { return }
        scheduleLoadedTrack(track, autoplay: true)
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
        scheduleLoadedTrack(track, autoplay: true)
    }

    /// Cancels in-flight loads, stops audio, and returns a generation token for the new load.
    @discardableResult
    private func beginLoadSession(keepPrefetchFor trackIDs: Set<UUID> = []) -> Int {
        loadTask?.cancel()
        loadTask = nil

        if let prefetchTrackID, !trackIDs.contains(prefetchTrackID) {
            prefetchTask?.cancel()
            prefetchTask = nil
            self.prefetchTrackID = nil
        }

        activeLoadGeneration += 1
        audioEngine.stop()
        return activeLoadGeneration
    }

    private func isLoadGenerationCurrent(_ generation: Int) -> Bool {
        generation == activeLoadGeneration && !Task.isCancelled
    }

    private func resolveLoadSource(for track: Track) async throws -> TrackLoadSource {
        if track.fileURL.isFileURL {
            logger.info("Load source: local '\(track.title)'")
            return .local(track.fileURL)
        }

        if let offlineURL = offlineStore.localURL(for: track.id) {
            logger.info("Load source: offline '\(track.title)'")
            return .local(offlineURL)
        }

        if let cached = prefetchedCache, cached.trackID == track.id {
            prefetchedCache = nil
            if await AudioCache.shared.hasCachedFile(trackID: track.id) {
                logger.info("Load source: prefetch-hit '\(track.title)'")
                return .local(cached.fileURL)
            }
        } else {
            prefetchedCache = nil
        }

        if await AudioCache.shared.hasCachedFile(trackID: track.id),
           let cachedURL = AudioCache.cachedFileURL(trackID: track.id) {
            AudioCache.touch(cachedURL)
            logger.info("Load source: cache-hit '\(track.title)'")
            return .local(cachedURL)
        }

        let asset = try await AudioCache.shared.progressiveAsset(for: track.fileURL, trackID: track.id)
        if await asset.isComplete(), let cachedURL = AudioCache.cachedFileURL(trackID: track.id) {
            logger.info("Load source: cache-hit (completed) '\(track.title)'")
            return .local(cachedURL)
        }
        logger.info("Load source: progressive '\(track.title)'")
        return .progressive(asset)
    }

    private func loadTrackIntoEngine(_ source: TrackLoadSource, track: Track) async throws {
        switch source {
        case .local(let url):
            try await audioEngine.load(url: url)
        case .progressive(let asset):
            try await audioEngine.loadProgressive(asset: asset, expectedDuration: track.duration)
        }
    }

    private func prefetchTrackIDsToKeep(for track: Track) -> Set<UUID> {
        var ids: Set<UUID> = [track.id]
        if let nextID = playbackQueue.peekNext(repeatMode: repeatMode)?.id {
            ids.insert(nextID)
        }
        if let prefetchTrackID {
            ids.insert(prefetchTrackID)
        }
        return ids
    }

    private func performOneLoad(_ track: Track, autoplay: Bool) async {
        let generation = beginLoadSession(keepPrefetchFor: prefetchTrackIDsToKeep(for: track))
        isPlaying = false
        isLoading = true
        logger.info("Load start: '\(track.title)' gen=\(generation) autoplay=\(autoplay)")

        do {
            let source = try await resolveLoadSource(for: track)
            guard isLoadGenerationCurrent(generation) else {
                isLoading = false
                return
            }
            try await loadTrackIntoEngine(source, track: track)
            guard isLoadGenerationCurrent(generation) else {
                isLoading = false
                return
            }
            duration = audioEngine.duration()
            progress = 0
            if autoplay {
                audioEngine.play()
                isPlaying = true
            } else {
                audioEngine.pause()
                isPlaying = false
            }
            isLoading = false
            logger.info("Load done: '\(track.title)' duration=\(String(format: "%.1f", self.duration))s autoplay=\(autoplay)")
            recentStore.record(track: track)
            mediaRemote.publishNowPlayingInfo()
            schedulePrefetch()
        } catch is CancellationError {
            isLoading = false
        } catch {
            guard isLoadGenerationCurrent(generation) else { return }
            logger.error("Failed to load track: \(error.localizedDescription)")
            isLoading = false
            logger.info("Load failed, advancing to next track")
            next(autoplay: autoplay)
        }
    }

    private func schedulePrefetchAndPrepareGapless() {
        guard let next = playbackQueue.peekNext(repeatMode: repeatMode),
              repeatMode != .one else {
            audioEngine.cancelPreparedNext()
            return
        }

        let gaplessEnabled = Self.isGaplessEnabled

        if next.fileURL.isFileURL {
            if gaplessEnabled {
                prepareGapless(url: next.fileURL)
            } else {
                audioEngine.cancelPreparedNext()
            }
            return
        }

        if let offlineURL = offlineStore.localURL(for: next.id) {
            if gaplessEnabled {
                prepareGapless(url: offlineURL)
            } else {
                audioEngine.cancelPreparedNext()
            }
            return
        }

        if let cached = prefetchedCache, cached.trackID == next.id {
            if gaplessEnabled {
                prepareGapless(url: cached.fileURL)
            } else {
                audioEngine.cancelPreparedNext()
            }
            return
        }

        if prefetchTrackID == next.id, prefetchTask != nil {
            if !gaplessEnabled {
                audioEngine.cancelPreparedNext()
            }
            return
        }

        prefetchTask?.cancel()
        prefetchTrackID = next.id

        let url = next.fileURL
        let trackID = next.id

        prefetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let localURL = try await AudioCache.shared.localURL(for: url, trackID: trackID)
                guard !Task.isCancelled else { return }
                self.prefetchedCache = (trackID: trackID, fileURL: localURL)
                if self.prefetchTrackID == trackID {
                    self.prefetchTrackID = nil
                }
                if Self.isGaplessEnabled {
                    self.prepareGapless(url: localURL)
                } else {
                    self.audioEngine.cancelPreparedNext()
                }
            } catch {
                if self.prefetchTrackID == trackID {
                    self.prefetchTrackID = nil
                }
            }
        }
    }

    /// Matches `@AppStorage("cadence.gaplessEnabled")` default (`true` when key is absent).
    private static var isGaplessEnabled: Bool {
        if UserDefaults.standard.object(forKey: "cadence.gaplessEnabled") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "cadence.gaplessEnabled")
    }

    private func prepareGapless(url: URL) {
        guard Self.isGaplessEnabled else {
            audioEngine.cancelPreparedNext()
            return
        }
        Task {
            do {
                let accepted = try await audioEngine.prepareNextTrack(url: url)
                if accepted {
                    logger.info("Gapless: next track prepared")
                } else {
                    logger.info("Gapless: format mismatch, will use normal transition")
                }
            } catch {
                logger.info("Gapless: failed to prepare next track: \(error.localizedDescription)")
            }
        }
    }

    private func schedulePrefetch() {
        schedulePrefetchAndPrepareGapless()
    }

    private func loadCurrentTrack(seekTo time: TimeInterval, shouldPlay: Bool) {
        guard let track = currentTrack else { return }

        let generation = beginLoadSession(keepPrefetchFor: prefetchTrackIDsToKeep(for: track))
        isLoading = true

        loadTask = Task {
            do {
                let source = try await resolveLoadSource(for: track)
                guard isLoadGenerationCurrent(generation) else { return }

                try await loadTrackIntoEngine(source, track: track)
                guard isLoadGenerationCurrent(generation) else { return }

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
                guard isLoadGenerationCurrent(generation) else { return }
                logger.error("Failed to restore track: \(error.localizedDescription)")
                stateStore.clear()
                playbackQueue = PlaybackQueue()
                isPlaying = false
                isLoading = false
                progress = 0
            }
        }
    }

    private func handleGaplessAdvance(nextDuration: TimeInterval) {
        guard repeatMode != .one else { return }
        guard let track = playbackQueue.consumeNext(repeatMode: repeatMode) else { return }
        logger.info("Gapless advance → '\(track.title)'")
        progress = 0
        duration = nextDuration
        recentStore.record(track: track)
        mediaRemote.publishNowPlayingInfo()
        persistState()
        schedulePrefetchAndPrepareGapless()
    }

    private func handleTrackFinished() {
        let endedTitle = currentTrack?.title ?? "?"
        logger.info("Track end: '\(endedTitle)' repeatMode=\(String(describing: self.repeatMode))")
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
