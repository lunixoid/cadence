import Foundation

enum AutoplaySource: Codable, Equatable {
    case album(UUID)
    case playlist(UUID)
    case adHoc
    case none
}

struct AutoplayContext: Equatable {
    var source: AutoplaySource
    var tracks: [Track]
    var originalTracks: [Track]
    var cursor: Int
}

struct PlaybackQueue: Equatable {
    var current: Track?
    var upNext: [Track] = []
    var autoplay: AutoplayContext?
    var history: [Track] = []

    var hasActiveSession: Bool {
        current != nil
    }

    mutating func beginSession(
        tracks: [Track],
        startAt index: Int,
        source: AutoplaySource,
        originalTracks: [Track]? = nil
    ) {
        let clampedIndex = min(max(index, 0), tracks.count - 1)
        let canonical = originalTracks ?? tracks
        current = tracks[clampedIndex]
        upNext = []
        history = []

        switch source {
        case .none:
            autoplay = tracks.count > 1
                ? AutoplayContext(
                    source: .adHoc,
                    tracks: tracks,
                    originalTracks: canonical,
                    cursor: clampedIndex + 1
                )
                : nil
        case .album, .playlist, .adHoc:
            autoplay = AutoplayContext(
                source: source,
                tracks: tracks,
                originalTracks: canonical,
                cursor: clampedIndex + 1
            )
        }
    }

    mutating func insertPlayNext(_ track: Track) {
        upNext.insert(track, at: 0)
    }

    mutating func appendToQueue(_ track: Track) {
        upNext.append(track)
    }

    mutating func removeFromUpNext(at index: Int) {
        guard index >= 0, index < upNext.count else { return }
        upNext.remove(at: index)
    }

    mutating func moveUpNextItem(from source: Int, to destination: Int) {
        guard source != destination,
              source >= 0, source < upNext.count,
              destination >= 0, destination < upNext.count else { return }
        let item = upNext.remove(at: source)
        upNext.insert(item, at: destination)
    }

    mutating func clearUpNext() {
        upNext.removeAll()
    }

    func autoplayPreview(limit: Int = 7) -> [Track] {
        guard let autoplay, autoplay.cursor < autoplay.tracks.count else { return [] }
        let upNextIDs = Set(upNext.map(\.id))
        return Array(
            autoplay.tracks
                .dropFirst(autoplay.cursor)
                .filter { !upNextIDs.contains($0.id) }
                .prefix(limit)
        )
    }

    mutating func shuffleRemainingAutoplay() {
        guard var ctx = autoplay, ctx.cursor < ctx.tracks.count else { return }
        let played = Array(ctx.tracks[..<ctx.cursor])
        var remaining = Array(ctx.tracks[ctx.cursor...])
        remaining.shuffle()
        ctx.tracks = played + remaining
        autoplay = ctx
    }

    mutating func restoreOriginalAutoplayOrder() {
        guard var ctx = autoplay, ctx.cursor <= ctx.originalTracks.count else { return }
        let played = Array(ctx.originalTracks[..<ctx.cursor])
        let remaining = Array(ctx.originalTracks[ctx.cursor...])
        ctx.tracks = played + remaining
        autoplay = ctx
    }

    /// Advances to the next track. Returns nil when playback should stop.
    mutating func consumeNext(repeatMode: RepeatMode) -> Track? {
        let nextTrack: Track?

        if !upNext.isEmpty {
            nextTrack = upNext.removeFirst()
        } else if let ctx = autoplay, ctx.cursor < ctx.tracks.count {
            nextTrack = ctx.tracks[ctx.cursor]
            autoplay?.cursor = ctx.cursor + 1
        } else if repeatMode == .queue, let ctx = autoplay, !ctx.tracks.isEmpty {
            nextTrack = ctx.tracks[0]
            autoplay?.cursor = min(1, ctx.tracks.count)
        } else {
            return nil
        }

        if let current {
            history.append(current)
        }
        current = nextTrack
        return nextTrack
    }

    /// Steps back using history. Returns nil when already at the beginning.
    mutating func consumePrevious() -> Track? {
        guard let previous = history.popLast() else { return nil }
        if let current {
            upNext.insert(current, at: 0)
        }
        current = previous
        return previous
    }
}
