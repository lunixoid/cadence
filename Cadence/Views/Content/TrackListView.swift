import SwiftUI

struct TrackListView: View {
    @Environment(AppUIState.self) private var uiState
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackController.self) private var playbackController

    private var tracks: [Track] {
        libraryStore.filteredTracks(query: uiState.searchQuery, from: libraryStore.allTracks())
    }

    var body: some View {
        LibraryContentShell {
            if tracks.isEmpty {
                EmptyLibraryStateView(message: "Нет треков")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        Section(header: trackListHeader) {
                            ForEach(tracks) { track in
                                TrackRowView(
                                    track: track,
                                    isActive: playbackController.playingTrackID == track.id,
                                    isPlaying: playbackController.isPlaying,
                                    disambiguationLabel: libraryStore.disambiguationLabel(for: track),
                                    onPlay: { playbackController.playTrack(track) }
                                )
                            }
                            Color.clear.frame(height: 24)
                        }
                    }
                }
            }
        }
    }

    private var trackListHeader: some View {
        TrackListHeaderView()
    }
}

struct TrackListHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 40)
            Text("Название")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Альбом")
                .frame(width: 180, alignment: .leading)
            Image(systemName: "clock")
                .font(.system(size: 11))
                .frame(width: 60, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .semibold))
        .tracking(0.04 * 11)
        .textCase(.uppercase)
        .foregroundStyle(CadenceTheme.mutedText(for: colorScheme))
        .padding(.horizontal, 28)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }
}

