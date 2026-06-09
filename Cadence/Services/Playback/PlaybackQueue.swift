import Foundation

enum AutoplaySource: Codable, Equatable {
    case album(UUID)
    case playlist(UUID)
    case library
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
        case .album, .playlist, .library, .adHoc:
            autoplay = AutoplayContext(
                source: source,
                tracks: tracks,
                originalTracks: canonical,
                cursor: clampedIndex + 1
            )
        }
    }

    private func unplayedFromContext(excludingUpNext: Bool = true) -> [Track] {
        guard let ctx = autoplay else { return [] }
        var playedIDs = Set(history.map(\.id))
        if let current {
            playedIDs.insert(current.id)
        }
        if excludingUpNext {
            playedIDs.formUnion(upNext.map(\.id))
        }
        return ctx.originalTracks.filter { !playedIDs.contains($0.id) }
    }

    private func forwardRemainingFromContext() -> [Track] {
        guard let ctx = autoplay, let current else { return [] }
        let playedIDs = Set(history.map(\.id) + [current.id])
        guard let currentIndex = ctx.originalTracks.firstIndex(of: current) else {
            return ctx.originalTracks.filter { !playedIDs.contains($0.id) }
        }
        return ctx.originalTracks
            .dropFirst(currentIndex + 1)
            .filter { !playedIDs.contains($0.id) }
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

    /// Jumps to a track in the explicit up-next list by index.
    mutating func jumpToUpNext(at index: Int) -> Track? {
        guard index >= 0, index < upNext.count else { return nil }
        if let current {
            history.append(current)
        }
        upNext.removeFirst(index)
        let track = upNext.removeFirst()
        current = track
        return track
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
        guard var ctx = autoplay else { return }
        var pool = unplayedFromContext()
        guard !pool.isEmpty else { return }
        pool.shuffle()
        ctx.tracks = pool
        ctx.cursor = 0
        autoplay = ctx
    }

    mutating func restoreOriginalAutoplayOrder() {
        guard var ctx = autoplay else { return }
        let remaining = forwardRemainingFromContext()
        ctx.tracks = remaining
        ctx.cursor = 0
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
