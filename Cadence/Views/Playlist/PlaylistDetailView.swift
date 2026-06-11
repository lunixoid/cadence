import SwiftUI

struct PlaylistDetailView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(PlaybackController.self) private var playbackController

    let playlistID: UUID

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
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        Section(header: playlistHeader) {
                            ForEach(tracks) { track in
                                TrackRowView(
                                    track: track,
                                    isActive: playbackController.playingTrackID == track.id
                                )
                            }
                            Color.clear.frame(height: 24)
                        }
                    }
                }
            }
        }
    }

    private var playlistHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    playbackController.play(
                        tracks: tracks,
                        startAt: 0,
                        source: .playlist(playlistID),
                        originalTracks: tracks
                    )
                }) {
                    Label("Воспроизвести", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.top, 12)
                Spacer()
            }
            TrackListHeaderView()
        }
    }
}
