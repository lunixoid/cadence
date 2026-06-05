import SwiftUI

struct PlaylistDetailView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(PlaybackController.self) private var playbackController

    let playlistID: UUID

    @State private var hoveredRow: UUID?

    private var playlist: Playlist? {
        playlistStore.playlist(for: playlistID)
    }

    private var tracks: [Track] {
        guard let playlist else { return [] }
        return libraryStore.filteredTracks(
            query: uiState.searchQuery,
            from: playlistStore.tracks(for: playlist, library: libraryStore)
        )
    }

    var body: some View {
        LibraryContentShell(title: playlist?.name ?? "Плейлист") {
            if tracks.isEmpty {
                EmptyLibraryStateView(message: "Плейлист пуст")
            } else {
                ScrollView {
                    HStack {
                        Button(action: { playbackController.play(tracks: tracks, startAt: 0) }) {
                            Label("Воспроизвести", systemImage: "play.fill")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 28)
                        .padding(.top, 12)
                        Spacer()
                    }

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
