import SwiftUI

struct FavoritesView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(FavoritesStore.self) private var favoritesStore
    @Environment(PlaybackController.self) private var playbackController

    @State private var hoveredRow: UUID?

    private var tracks: [Track] {
        let source = libraryStore.allTracks().filter { favoritesStore.isFavorite(track: $0) }
        return libraryStore.filteredTracks(query: uiState.searchQuery, from: source)
    }

    var body: some View {
        LibraryContentShell {
            if tracks.isEmpty {
                EmptyLibraryStateView(message: "Нет избранного")
            } else {
                ScrollView {
                    TrackListHeaderView()
                    ForEach(tracks) { track in
                        TrackRowView(
                            track: track,
                            isActive: playbackController.playingTrackID == track.id,
                            isPlaying: playbackController.isPlaying,
                            isHovered: hoveredRow == track.id,
                            onPlay: { playbackController.playTrack(track) }
                        )
                        .onHover { hoveredRow = $0 ? track.id : nil }
                    }
                    Color.clear.frame(height: 24)
                }
            }
        }
    }
}

struct RecentView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(RecentStore.self) private var recentStore
    @Environment(PlaybackController.self) private var playbackController

    @State private var hoveredRow: UUID?

    private var tracks: [Track] {
        libraryStore.filteredTracks(query: uiState.searchQuery, from: recentStore.tracks(from: libraryStore))
    }

    var body: some View {
        LibraryContentShell {
            if tracks.isEmpty {
                EmptyLibraryStateView(message: "Нет недавних треков")
            } else {
                ScrollView {
                    TrackListHeaderView()
                    ForEach(tracks) { track in
                        TrackRowView(
                            track: track,
                            isActive: playbackController.playingTrackID == track.id,
                            isPlaying: playbackController.isPlaying,
                            isHovered: hoveredRow == track.id,
                            onPlay: { playbackController.playTrack(track) }
                        )
                        .onHover { hoveredRow = $0 ? track.id : nil }
                    }
                    Color.clear.frame(height: 24)
                }
            }
        }
    }
}

struct DownloadedView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackController.self) private var playbackController

    @State private var hoveredRow: UUID?

    private var tracks: [Track] {
        libraryStore.filteredTracks(query: uiState.searchQuery, from: libraryStore.allTracks())
    }

    var body: some View {
        LibraryContentShell {
            if tracks.isEmpty {
                EmptyLibraryStateView(message: "Нет скачанных треков")
            } else {
                ScrollView {
                    TrackListHeaderView()
                    ForEach(tracks) { track in
                        TrackRowView(
                            track: track,
                            isActive: playbackController.playingTrackID == track.id,
                            isPlaying: playbackController.isPlaying,
                            isHovered: hoveredRow == track.id,
                            onPlay: { playbackController.playTrack(track) }
                        )
                        .onHover { hoveredRow = $0 ? track.id : nil }
                    }
                    Color.clear.frame(height: 24)
                }
            }
        }
    }
}
