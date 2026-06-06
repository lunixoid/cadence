import Foundation

struct AutoplaySnapshot: Codable, Equatable {
    var source: AutoplaySource
    var trackIDs: [UUID]
    var originalTrackIDs: [UUID]?
    var cursor: Int
}

struct PlaybackStateSnapshot: Codable, Equatable {
    var currentTrackID: UUID?
    var upNextTrackIDs: [UUID]
    var autoplay: AutoplaySnapshot?
    var historyTrackIDs: [UUID]
    var progress: TimeInterval
    var isPlaying: Bool
    var shuffleOn: Bool
    var repeatMode: RepeatMode
    var volume: Double
    var eqEnabled: Bool?
    var eqGains: [Double]?
}

@MainActor
final class PlaybackStateStore {
    private let storageKey = "cadence.playbackState"

    func save(_ snapshot: PlaybackStateSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func load() -> PlaybackStateSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(PlaybackStateSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    func makeSnapshot(
        from queue: PlaybackQueue,
        progress: TimeInterval,
        isPlaying: Bool,
        shuffleOn: Bool,
        repeatMode: RepeatMode,
        volume: Double,
        eqEnabled: Bool,
        eqGains: [Double]
    ) -> PlaybackStateSnapshot {
        PlaybackStateSnapshot(
            currentTrackID: queue.current?.id,
            upNextTrackIDs: queue.upNext.map(\.id),
            autoplay: queue.autoplay.map { ctx in
                AutoplaySnapshot(
                    source: ctx.source,
                    trackIDs: ctx.tracks.map(\.id),
                    originalTrackIDs: ctx.originalTracks.map(\.id),
                    cursor: ctx.cursor
                )
            },
            historyTrackIDs: queue.history.map(\.id),
            progress: progress,
            isPlaying: isPlaying,
            shuffleOn: shuffleOn,
            repeatMode: repeatMode,
            volume: volume,
            eqEnabled: eqEnabled,
            eqGains: eqGains
        )
    }

    func restoreQueue(from snapshot: PlaybackStateSnapshot, library: LibraryStore) -> PlaybackQueue? {
        guard let currentID = snapshot.currentTrackID,
              let current = library.track(for: currentID) else {
            return nil
        }

        let upNext = snapshot.upNextTrackIDs.compactMap { library.track(for: $0) }
        let history = snapshot.historyTrackIDs.compactMap { library.track(for: $0) }

        let autoplay: AutoplayContext?
        if let autoplaySnapshot = snapshot.autoplay {
            let tracks = autoplaySnapshot.trackIDs.compactMap { library.track(for: $0) }
            if tracks.isEmpty {
                autoplay = nil
            } else {
                let originalIDs = autoplaySnapshot.originalTrackIDs ?? autoplaySnapshot.trackIDs
                let originalTracks = originalIDs.compactMap { library.track(for: $0) }
                autoplay = AutoplayContext(
                    source: autoplaySnapshot.source,
                    tracks: tracks,
                    originalTracks: originalTracks.isEmpty ? tracks : originalTracks,
                    cursor: min(autoplaySnapshot.cursor, tracks.count)
                )
            }
        } else {
            autoplay = nil
        }

        return PlaybackQueue(
            current: current,
            upNext: upNext,
            autoplay: autoplay,
            history: history
        )
    }
}
